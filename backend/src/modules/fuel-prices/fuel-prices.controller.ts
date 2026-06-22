import { asyncHandler } from "../../lib/asyncHandler";
import { UnauthorizedError } from "../../lib/errors";
import * as fuelPricesService from "./fuel-prices.service";
import { ListFuelPricesQuery } from "./fuel-prices.validators";

export const list = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const result = await fuelPricesService.listFuelPrices(req.user, req.query as unknown as ListFuelPricesQuery);
  res.status(200).json(result);
});

export const create = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const fuelPrice = await fuelPricesService.createFuelPrice(req.user, req.body);
  res.status(201).json({ data: fuelPrice });
});
