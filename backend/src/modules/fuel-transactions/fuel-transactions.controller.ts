import { asyncHandler } from "../../lib/asyncHandler";
import { UnauthorizedError } from "../../lib/errors";
import * as transactionsService from "./fuel-transactions.service";
import { ListTransactionsQuery } from "./fuel-transactions.validators";

export const list = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const result = await transactionsService.listTransactions(req.user, req.query as unknown as ListTransactionsQuery);
  res.status(200).json(result);
});

export const getById = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const transaction = await transactionsService.getTransactionById(req.user, req.params.id);
  res.status(200).json({ data: transaction });
});

export const create = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const transaction = await transactionsService.createTransaction(req.user, req.body);
  res.status(201).json({ data: transaction });
});
