import bcrypt from "bcrypt";
import { Prisma, User, UserRole } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { AUTH } from "../../config/constants";
import { ConflictError, ForbiddenError, NotFoundError } from "../../lib/errors";
import { buildPaginatedResult, parsePagination } from "../../lib/pagination";
import { AuthenticatedUser } from "../../types/auth";
import { accountApprovedTemplate, accountCreatedTemplate, sendImmediateEmail } from "../notifications/email.service";
import { emit } from "../notifications/notification-dispatcher";
import { revokeAllSessions } from "../auth/session.service";
import { recomputeAllocationForDriver } from "../fuel-allocation/allocation.hooks";
import {
  CreateUserInput,
  ListUsersQuery,
  UpdateLocationInput,
  UpdateStipendInput,
  UpdateUserInput,
} from "./users.validators";

const PUBLIC_USER_SELECT = {
  id: true,
  email: true,
  fullName: true,
  phone: true,
  avatarUrl: true,
  role: true,
  isApproved: true,
  isActive: true,
  organizationId: true,
  departmentId: true,
  employeeId: true,
  homeAddress: true,
  homeLat: true,
  homeLng: true,
  workSiteName: true,
  workSiteLat: true,
  workSiteLng: true,
  fuelType: true,
  monthlyFuelStipendRwf: true,
  monthlyBudgetRwf: true,
  workingDaysPerMonth: true,
  profileCompletedAt: true,
  createdAt: true,
  updatedAt: true,
} satisfies Prisma.UserSelect;

/** Roles other than SUPER_ADMIN may only see/manage driver accounts. */
function isRestrictedToDrivers(role: UserRole): boolean {
  return role === UserRole.FLEET_MANAGER || role === UserRole.FINANCE_OFFICER;
}

export async function listUsers(actor: AuthenticatedUser, query: ListUsersQuery) {
  const pagination = parsePagination(query);

  const where: Prisma.UserWhereInput = {
    organizationId: actor.organizationId,
    deletedAt: null,
  };

  if (isRestrictedToDrivers(actor.role)) {
    where.role = UserRole.DRIVER;
  } else if (query.role) {
    where.role = query.role;
  }

  if (query.departmentId) where.departmentId = query.departmentId;
  if (query.isApproved !== undefined) where.isApproved = query.isApproved;
  if (query.isActive !== undefined) where.isActive = query.isActive;

  if (query.search) {
    where.OR = [
      { fullName: { contains: query.search, mode: "insensitive" } },
      { email: { contains: query.search, mode: "insensitive" } },
      { employeeId: { contains: query.search, mode: "insensitive" } },
    ];
  }

  const [data, total] = await Promise.all([
    prisma.user.findMany({
      where,
      select: PUBLIC_USER_SELECT,
      orderBy: { createdAt: "desc" },
      skip: pagination.skip,
      take: pagination.take,
    }),
    prisma.user.count({ where }),
  ]);

  return buildPaginatedResult(data, total, pagination);
}

export async function getUserById(actor: AuthenticatedUser, id: string) {
  if (actor.role === UserRole.DRIVER && actor.id !== id) {
    throw new ForbiddenError("You can only access your own profile");
  }

  const user = await prisma.user.findFirst({
    where: { id, organizationId: actor.organizationId, deletedAt: null },
    select: PUBLIC_USER_SELECT,
  });
  if (!user) throw new NotFoundError("User not found");

  if (isRestrictedToDrivers(actor.role) && user.role !== UserRole.DRIVER) {
    throw new ForbiddenError("You can only access driver accounts");
  }

  return user;
}

export async function createUser(actor: AuthenticatedUser, input: CreateUserInput) {
  if (isRestrictedToDrivers(actor.role) && input.role !== UserRole.DRIVER) {
    throw new ForbiddenError("You can only create driver accounts");
  }

  const existing = await prisma.user.findUnique({ where: { email: input.email } });
  if (existing) throw new ConflictError("An account with this email already exists");

  const passwordHash = await bcrypt.hash(input.password, AUTH.BCRYPT_ROUNDS);
  const isApproved = input.isApproved ?? true;

  const user = await prisma.user.create({
    data: {
      organizationId: actor.organizationId,
      email: input.email,
      passwordHash,
      role: input.role,
      isApproved,
      fullName: input.fullName,
      phone: input.phone,
      employeeId: input.employeeId,
      departmentId: input.departmentId,
      homeAddress: input.homeAddress,
      homeLat: input.homeLat,
      homeLng: input.homeLng,
      workSiteName: input.workSiteName,
      workSiteLat: input.workSiteLat,
      workSiteLng: input.workSiteLng,
      fuelType: input.fuelType,
      monthlyFuelStipendRwf: input.monthlyFuelStipendRwf,
      monthlyBudgetRwf: input.monthlyBudgetRwf,
      workingDaysPerMonth: input.workingDaysPerMonth,
    },
    select: PUBLIC_USER_SELECT,
  });

  if (isApproved) {
    await sendImmediateEmail(user.email, accountApprovedTemplate(user.fullName));
  } else {
    await sendImmediateEmail(user.email, accountCreatedTemplate(user.fullName));
  }

  return user;
}

export async function updateUser(actor: AuthenticatedUser, id: string, input: UpdateUserInput) {
  const target = await loadManageableUser(actor, id);

  if (input.role && actor.role !== UserRole.SUPER_ADMIN) {
    throw new ForbiddenError("Only a super admin can change user roles");
  }

  if (input.workingDaysPerMonth !== undefined && actor.role === UserRole.DRIVER) {
    throw new ForbiddenError("Working days can only be set by Super Admin or Fleet Manager");
  }

  const data: Prisma.UserUncheckedUpdateInput = {
    fullName: input.fullName,
    phone: input.phone,
    employeeId: input.employeeId,
    departmentId: input.departmentId,
    role: input.role,
    fuelType: input.fuelType,
    workingDaysPerMonth: input.workingDaysPerMonth,
    isActive: input.isActive,
  };

  const user = await prisma.user.update({ where: { id: target.id }, data, select: PUBLIC_USER_SELECT });

  if (input.isActive === false) {
    await revokeAllSessions(user.id);
  }

  if (input.workingDaysPerMonth !== undefined && user.role === UserRole.DRIVER) {
    await recomputeAllocationForDriver(user.id, "working_days_changed", actor.id).catch(() => {});
  }

  return user;
}

export async function approveUser(actor: AuthenticatedUser, id: string) {
  const target = await loadManageableUser(actor, id);

  const user = await prisma.user.update({
    where: { id: target.id },
    data: { isApproved: true },
    select: PUBLIC_USER_SELECT,
  });

  await sendImmediateEmail(user.email, accountApprovedTemplate(user.fullName));
  await emit("account_approved", [user.id], {});

  return user;
}

export async function deleteUser(actor: AuthenticatedUser, id: string): Promise<void> {
  const target = await loadManageableUser(actor, id);

  await prisma.user.update({
    where: { id: target.id },
    data: { deletedAt: new Date(), isActive: false },
  });

  await revokeAllSessions(target.id);
}

export async function updateLocation(actor: AuthenticatedUser, id: string, input: UpdateLocationInput) {
  if (actor.role === UserRole.DRIVER && actor.id !== id) {
    throw new ForbiddenError("You can only update your own location");
  }
  const target = await loadManageableUser(actor, id, { allowSelf: true });

  const user = await prisma.user.update({
    where: { id: target.id },
    data: {
      homeAddress: input.homeAddress,
      homeLat: input.homeLat,
      homeLng: input.homeLng,
      workSiteName: input.workSiteName,
      workSiteLat: input.workSiteLat,
      workSiteLng: input.workSiteLng,
    },
    select: PUBLIC_USER_SELECT,
  });

  await recomputeAllocationForDriver(user.id, "location_changed", actor.id);

  return user;
}

export async function updateStipend(actor: AuthenticatedUser, id: string, input: UpdateStipendInput) {
  const target = await loadManageableUser(actor, id, { requireDriver: true });

  const user = await prisma.$transaction(async (tx) => {
    const previousAmount = target.monthlyFuelStipendRwf;

    const updated = await tx.user.update({
      where: { id: target.id },
      data: {
        monthlyFuelStipendRwf: input.monthlyFuelStipendRwf,
        monthlyBudgetRwf: input.monthlyBudgetRwf,
      },
      select: PUBLIC_USER_SELECT,
    });

    await tx.stipendHistory.create({
      data: {
        userId: target.id,
        previousAmount,
        newAmount: input.monthlyFuelStipendRwf,
        changedById: actor.id,
        reason: input.reason,
      },
    });

    return updated;
  });

  await emit("stipend_updated", [user.id], { newAmount: user.monthlyFuelStipendRwf.toFixed(2) });
  await recomputeAllocationForDriver(user.id, "stipend_changed", actor.id);

  return user;
}

export async function getStipendHistory(actor: AuthenticatedUser, id: string, query: ListUsersQuery) {
  await loadManageableUser(actor, id, { allowSelf: true });

  const pagination = parsePagination(query);

  const [data, total] = await Promise.all([
    prisma.stipendHistory.findMany({
      where: { userId: id },
      orderBy: { changedAt: "desc" },
      skip: pagination.skip,
      take: pagination.take,
      include: { changedBy: { select: { id: true, fullName: true, role: true } } },
    }),
    prisma.stipendHistory.count({ where: { userId: id } }),
  ]);

  return buildPaginatedResult(data, total, pagination);
}

export async function completeProfile(actor: AuthenticatedUser, input: UpdateLocationInput) {
  if (actor.role !== UserRole.DRIVER) {
    throw new ForbiddenError("Only drivers need to complete a driver profile");
  }

  if (!input.homeLat || !input.homeLng || !input.workSiteLat || !input.workSiteLng) {
    throw new ForbiddenError("Home and work GPS coordinates are required to complete your profile");
  }

  const user = await prisma.user.update({
    where: { id: actor.id },
    data: {
      homeAddress: input.homeAddress,
      homeLat: input.homeLat,
      homeLng: input.homeLng,
      workSiteName: input.workSiteName,
      workSiteLat: input.workSiteLat,
      workSiteLng: input.workSiteLng,
      profileCompletedAt: new Date(),
    },
    select: PUBLIC_USER_SELECT,
  });

  await recomputeAllocationForDriver(user.id, "location_changed", actor.id);

  return user;
}

interface ManageableUserOptions {
  /** Allow the actor to operate on their own record even if not normally manageable. */
  allowSelf?: boolean;
  /** Require the target user to be a DRIVER (e.g. stipend management). */
  requireDriver?: boolean;
}

/** Loads a target user, enforcing the SA-full / FM+FO-drivers-only RBAC rule. */
async function loadManageableUser(actor: AuthenticatedUser, id: string, options: ManageableUserOptions = {}): Promise<User> {
  const target = await prisma.user.findFirst({ where: { id, organizationId: actor.organizationId, deletedAt: null } });
  if (!target) throw new NotFoundError("User not found");

  if (options.requireDriver && target.role !== UserRole.DRIVER) {
    throw new ForbiddenError("This action is only available for driver accounts");
  }

  if (options.allowSelf && actor.id === target.id) {
    return target;
  }

  if (actor.role === UserRole.SUPER_ADMIN) {
    return target;
  }

  if (isRestrictedToDrivers(actor.role) && target.role === UserRole.DRIVER) {
    return target;
  }

  throw new ForbiddenError("You do not have permission to manage this user");
}
