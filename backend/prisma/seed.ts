import { PrismaClient, FuelType, VehicleType, VehicleStatus, UserRole } from "@prisma/client";
import bcrypt from "bcrypt";

const prisma = new PrismaClient();

const DEFAULT_ORG_CODE = "DEFAULT";
const DEMO_PASSWORD = "Passw0rd!";

async function main() {
  const org = await prisma.organization.upsert({
    where: { code: DEFAULT_ORG_CODE },
    update: {},
    create: { code: DEFAULT_ORG_CODE, name: "NPD Ltd Rwanda" },
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

  const superAdmin = await prisma.user.upsert({
    where: { email: "i.josianeintangotss@gmail.com" },
    update: {},
    create: {
      organizationId: org.id,
      email: "i.josianeintangotss@gmail.com",
      passwordHash,
      role: UserRole.SUPER_ADMIN,
      fullName: "Super Admin",
      isApproved: true,
      departmentId: operations.id,
    },
  });

  // Fleet Manager + Finance Officer combined — SUPER_ADMIN covers both approval stages
  await prisma.user.upsert({
    where: { email: "ingabirejosiane003@gmail.com" },
    update: { role: UserRole.SUPER_ADMIN },
    create: {
      organizationId: org.id,
      email: "ingabirejosiane003@gmail.com",
      passwordHash,
      role: UserRole.SUPER_ADMIN,
      fullName: "Fleet & Finance Manager",
      isApproved: true,
      departmentId: operations.id,
    },
  });

  // Deactivated — replaced by ingabirejosiane003@gmail.com above
  await prisma.user.upsert({
    where: { email: "music.therapyy3@gmail.com" },
    update: { isActive: false },
    create: {
      organizationId: org.id,
      email: "music.therapyy3@gmail.com",
      passwordHash,
      role: UserRole.FINANCE_OFFICER,
      fullName: "Finance Officer",
      isApproved: true,
      isActive: false,
      departmentId: finance.id,
    },
  });

  const vehicle = await prisma.vehicle.upsert({
    where: { plateNumber: "RAD 123 A" },
    update: {},
    create: {
      organizationId: org.id,
      plateNumber: "RAD 123 A",
      make: "Toyota",
      model: "Hilux",
      year: 2022,
      vehicleType: VehicleType.PICKUP,
      fuelType: FuelType.DIESEL,
      tankCapacityL: 80,
      currentFuelL: 60,
      odometerKm: 15000,
      fuelEfficiencyKmpl: 10,
      status: VehicleStatus.ACTIVE,
    },
  });

  const driverProfileDate = new Date("2026-01-01T00:00:00Z");
  const driver = await prisma.user.upsert({
    where: { email: "i.josianee3@gmail.com" },
    update: {
      isApproved: true,
      isActive: true,
      profileCompletedAt: driverProfileDate,
      homeLat: -1.9346,
      homeLng: 30.1106,
      homeAddress: "Kimironko, Kigali",
      workSiteLat: -1.9536,
      workSiteLng: 30.0936,
      workSiteName: "NPD Head Office",
      workingDaysPerMonth: 22,
    },
    create: {
      organizationId: org.id,
      email: "i.josianee3@gmail.com",
      passwordHash,
      role: UserRole.DRIVER,
      fullName: "John Driver",
      isApproved: true,
      departmentId: operations.id,
      employeeId: "EMP-001",
      homeAddress: "Kimironko, Kigali",
      homeLat: -1.9346,
      homeLng: 30.1106,
      workSiteName: "NPD Head Office",
      workSiteLat: -1.9536,
      workSiteLng: 30.0936,
      fuelType: FuelType.DIESEL,
      monthlyFuelStipendRwf: 150000,
      monthlyBudgetRwf: 400000,
      workingDaysPerMonth: 22,
      profileCompletedAt: driverProfileDate,
    },
  });

  await prisma.vehicle.update({
    where: { id: vehicle.id },
    data: { assignedDriverId: driver.id, status: VehicleStatus.ACTIVE },
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
      setById: superAdmin.id,
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
      setById: superAdmin.id,
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

  console.log("Seed complete.");
  console.log(`Demo password for all seeded users: ${DEMO_PASSWORD}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
