import { Request, Response, NextFunction } from "express";
import { PermissionType } from "@prisma/client";
import * as service from "./permissions.service";

export async function list(req: Request, res: Response, next: NextFunction) {
  try {
    const data = await service.listPermissions(req.user!, req.params.id);
    res.json({ data });
  } catch (err) {
    next(err);
  }
}

export async function grant(req: Request, res: Response, next: NextFunction) {
  try {
    const data = await service.grantPermission(req.user!, req.params.id, req.body);
    res.status(201).json({ data });
  } catch (err) {
    next(err);
  }
}

export async function revoke(req: Request, res: Response, next: NextFunction) {
  try {
    await service.revokePermission(req.user!, req.params.id, req.params.permission as PermissionType);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
}
