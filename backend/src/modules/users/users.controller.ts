import { asyncHandler } from "../../lib/asyncHandler";
import { UnauthorizedError } from "../../lib/errors";
import * as usersService from "./users.service";
import { ListUsersQuery } from "./users.validators";

export const list = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const result = await usersService.listUsers(req.user, req.query as unknown as ListUsersQuery);
  res.status(200).json(result);
});

export const getById = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const user = await usersService.getUserById(req.user, req.params.id);
  res.status(200).json({ data: user });
});

export const create = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const user = await usersService.createUser(req.user, req.body);
  res.status(201).json({ data: user });
});

export const update = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const user = await usersService.updateUser(req.user, req.params.id, req.body);
  res.status(200).json({ data: user });
});

export const approve = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const user = await usersService.approveUser(req.user, req.params.id);
  res.status(200).json({ data: user });
});

export const remove = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  await usersService.deleteUser(req.user, req.params.id);
  res.status(204).send();
});

export const updateLocation = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const user = await usersService.updateLocation(req.user, req.params.id, req.body);
  res.status(200).json({ data: user });
});

export const updateStipend = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const user = await usersService.updateStipend(req.user, req.params.id, req.body);
  res.status(200).json({ data: user });
});

export const getStipendHistory = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const result = await usersService.getStipendHistory(req.user, req.params.id, req.query as unknown as ListUsersQuery);
  res.status(200).json(result);
});

export const completeProfile = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const user = await usersService.completeProfile(req.user, req.body);
  res.status(200).json({ data: user });
});
