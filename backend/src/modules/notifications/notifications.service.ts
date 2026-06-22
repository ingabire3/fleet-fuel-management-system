import { Prisma } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { NotFoundError } from "../../lib/errors";
import { buildPaginatedResult, parsePagination } from "../../lib/pagination";
import { AuthenticatedUser } from "../../types/auth";
import { ListNotificationsQuery } from "./notifications.validators";

export async function listNotifications(actor: AuthenticatedUser, query: ListNotificationsQuery) {
  const pagination = parsePagination(query);

  const where: Prisma.NotificationWhereInput = { userId: actor.id };
  if (query.isRead !== undefined) where.isRead = query.isRead;
  if (query.category) where.category = query.category;

  const [data, total, unreadCount] = await Promise.all([
    prisma.notification.findMany({
      where,
      orderBy: { createdAt: "desc" },
      skip: pagination.skip,
      take: pagination.take,
    }),
    prisma.notification.count({ where }),
    prisma.notification.count({ where: { userId: actor.id, isRead: false } }),
  ]);

  return { ...buildPaginatedResult(data, total, pagination), unreadCount };
}

export async function markAsRead(actor: AuthenticatedUser, id: string) {
  const notification = await prisma.notification.findFirst({ where: { id, userId: actor.id } });
  if (!notification) throw new NotFoundError("Notification not found");

  return prisma.notification.update({
    where: { id: notification.id },
    data: { isRead: true, readAt: new Date() },
  });
}

export async function markAllAsRead(actor: AuthenticatedUser): Promise<void> {
  await prisma.notification.updateMany({
    where: { userId: actor.id, isRead: false },
    data: { isRead: true, readAt: new Date() },
  });
}
