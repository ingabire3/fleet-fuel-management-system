import { NextFunction, Request, Response } from "express";
import { UserRole } from "@prisma/client";
import { ForbiddenError, UnauthorizedError } from "../lib/errors";

/** Restricts a route to the given roles. Must run after `authenticate`. */
export function authorize(...roles: UserRole[]) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    if (!req.user) {
      throw new UnauthorizedError();
    }
    if (!roles.includes(req.user.role)) {
      throw new ForbiddenError(`Requires one of roles: ${roles.join(", ")}`);
    }
    next();
  };
}
