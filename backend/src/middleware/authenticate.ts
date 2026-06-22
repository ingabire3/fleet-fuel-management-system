import { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { env } from "../config/env";
import { UnauthorizedError } from "../lib/errors";
import { AccessTokenPayload } from "../types/auth";

/** Verifies the JWT access token from the Authorization header and attaches `req.user`. */
export function authenticate(req: Request, _res: Response, next: NextFunction): void {
  const header = req.headers.authorization;

  if (!header || !header.startsWith("Bearer ")) {
    throw new UnauthorizedError("Missing or invalid Authorization header");
  }

  const token = header.slice("Bearer ".length);

  try {
    const payload = jwt.verify(token, env.JWT_ACCESS_SECRET) as AccessTokenPayload;
    req.user = {
      id: payload.sub,
      role: payload.role,
      organizationId: payload.organizationId,
      sessionId: payload.sessionId,
    };
    next();
  } catch {
    throw new UnauthorizedError("Invalid or expired access token");
  }
}
