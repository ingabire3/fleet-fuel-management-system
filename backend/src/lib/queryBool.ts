import { z } from "zod";

/**
 * z.coerce.boolean() uses JS Boolean() — Boolean('false') === true (non-empty string is truthy).
 * Use this instead for query-string boolean params: 'false'/'0' → false, 'true'/'1' → true.
 */
export const queryBool = z.preprocess(
  (v) => (v === "false" || v === "0" ? false : v === "true" || v === "1" ? true : v),
  z.boolean().optional()
);
