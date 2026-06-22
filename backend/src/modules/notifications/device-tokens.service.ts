import { prisma } from "../../config/prisma";
import { AuthenticatedUser } from "../../types/auth";
import { RegisterDeviceTokenInput } from "./notifications.validators";

export async function registerDeviceToken(actor: AuthenticatedUser, input: RegisterDeviceTokenInput) {
  return prisma.deviceToken.upsert({
    where: { userId_deviceId: { userId: actor.id, deviceId: input.deviceId } },
    update: {
      token: input.token,
      deviceType: input.deviceType,
      deviceName: input.deviceName,
      lastUsedAt: new Date(),
      isActive: true,
      deletedAt: null,
    },
    create: {
      userId: actor.id,
      deviceId: input.deviceId,
      token: input.token,
      deviceType: input.deviceType,
      deviceName: input.deviceName,
    },
  });
}

export async function unregisterDeviceToken(actor: AuthenticatedUser, deviceId: string): Promise<void> {
  await prisma.deviceToken.updateMany({
    where: { userId: actor.id, deviceId },
    data: { isActive: false, deletedAt: new Date() },
  });
}
