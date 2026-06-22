/**
 * Portfolio/demo seed — populates a separate "DEMO" organization with fake
 * data and the recruiter-facing demo accounts. Safe to run against the
 * public showcase database; never touches real org data from seed.ts.
 *
 * Usage: tsx prisma/seed.demo.ts
 */
import { PrismaClient, FuelType, VehicleType, VehicleStatus, UserRole } from "@prisma/client";
import bcrypt from "bcrypt";

const prisma = new PrismaClient();

const DEMO_ORG_CODE = "DEMO";
const DEMO_PASSWORD = "Demo@1234";

async function main() {
  const org = await prisma.organization.upsert({
    where: { code: DEMO_ORG_CODE },
    update: {},
    create: { code: DEMO_ORG_CODE, name: "Demo Fleet Co." },
  });

  const operations = await prisma.department.upsert({
    where: { organizationId_name: { organizationId: org.id, name: "Operations" } },
    update: {},
    create: { organizationId: org.id, name: "Operations" },
  });

  const finance = await prisma.department.upsert({
    where: { organizationId_name: { organizationId: org.id, name: "Finance" } },
    update: {},
    create: { organizationId: org.id, name: "Finance" },
  });

  const passwordHash = await bcrypt.hash(DEMO_PASSWORD, 10);

  const admin = await prisma.user.upsert({
    where: { email: "admin@example.com" },
    update: { role: UserRole.SUPER_ADMIN, isApproved: true, isActive: true },
    create: {
      organizationId: org.id,
      email: "admin@example.com",
      passwordHash,
      role: UserRole.SUPER_ADMIN,
      fullName: "Demo Admin",
      isApproved: true,
      departmentId: operations.id,
    },
  });

  await prisma.user.upsert({
    where: { email: "manager@example.com" },
    update: { role: UserRole.FLEET_MANAGER, isApproved: true, isActive: true },
    create: {
      organizationId: org.id,
      email: "manager@example.com",
      passwordHash,
      role: UserRole.FLEET_MANAGER,
      fullName: "Demo Fleet Manager",
      isApproved: true,
      departmentId: operations.id,
    },
  });

  const driverProfileDate = new Date("2026-01-01T00:00:00Z");
  const driver = await prisma.user.upsert({
    where: { email: "driver@example.com" },
    update: {
      role: UserRole.DRIVER,
      isApproved: true,
      isActive: true,
      profileCompletedAt: driverProfileDate,
    },
    create: {
      organizationId: org.id,
      email: "driver@example.com",
      passwordHash,
      role: UserRole.DRIVER,
      fullName: "Demo Driver",
      isApproved: true,
      departmentId: operations.id,
      employeeId: "DEMO-001",
      homeAddress: "Kimironko, Kigali",
      homeLat: -1.9346,
      homeLng: 30.1106,
      workSiteName: "Demo HQ",
      workSiteLat: -1.9536,
      workSiteLng: 30.0936,
      fuelType: FuelType.DIESEL,
      monthlyFuelStipendRwf: 150000,
      monthlyBudgetRwf: 400000,
      workingDaysPerMonth: 22,
      profileCompletedAt: driverProfileDate,
    },
  });

  const vehicle = await prisma.vehicle.upsert({
    where: { plateNumber: "DEMO 001 A" },
    update: {},
    create: {
      organizationId: org.id,
      plateNumber: "DEMO 001 A",
      make: "Toyota",
      model: "Hilux",
      year: 2023,
      vehicleType: VehicleType.PICKUP,
      fuelType: FuelType.DIESEL,
      tankCapacityL: 80,
      currentFuelL: 55,
      odometerKm: 12500,
      fuelEfficiencyKmpl: 10,
      status: VehicleStatus.ACTIVE,
      assignedDriverId: driver.id,
    },
  });

  await prisma.fuelPrice.upsert({
    where: {
      organizationId_fuelType_effectiveDate: {
        organizationId: org.id,
        fuelType: FuelType.PETROL,
        effectiveDate: new Date("2026-01-01"),
      },
    },
    update: {},
    create: {
      organizationId: org.id,
      fuelType: FuelType.PETROL,
      priceRwf: 1520,
      effectiveDate: new Date("2026-01-01"),
      setById: admin.id,
    },
  });

  await prisma.fuelPrice.upsert({
    where: {
      organizationId_fuelType_effectiveDate: {
        organizationId: org.id,
        fuelType: FuelType.DIESEL,
        effectiveDate: new Date("2026-01-01"),
      },
    },
    update: {},
    create: {
      organizationId: org.id,
      fuelType: FuelType.DIESEL,
      priceRwf: 1450,
      effectiveDate: new Date("2026-01-01"),
      setById: admin.id,
    },
  });

  const settings: Array<[string, string, string]> = [
    ["FUEL_BUFFER_PERCENT", "20", "Buffer percentage applied on top of base monthly fuel requirement"],
    ["DEFAULT_WORKING_DAYS", "22", "Default working days per month used in fuel allocation calculations"],
    ["ROAD_DISTANCE_FACTOR", "1.3", "Multiplier applied to straight-line (haversine) distance to approximate road distance"],
    ["REQUIRE_LOGIN_OTP", "false", "Whether OTP verification is required on every login"],
  ];

  for (const [key, value, description] of settings) {
    const existing = await prisma.systemSetting.findFirst({
      where: { organizationId: null, key },
    });
    if (!existing) {
      await prisma.systemSetting.create({
        data: { organizationId: null, key, value, description },
      });
    }
  }

  await prisma.vehicle.update({
    where: { id: vehicle.id },
    data: { status: VehicleStatus.ACTIVE },
  });

  console.log("Demo seed complete.");
  console.log("admin@example.com / manager@example.com / driver@example.com");
  console.log(`Password for all demo accounts: ${DEMO_PASSWORD}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
