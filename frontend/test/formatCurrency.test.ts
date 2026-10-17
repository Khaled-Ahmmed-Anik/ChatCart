import test from "node:test";
import assert from "node:assert/strict";
import { formatCurrency } from "../src/lib/formatCurrency.ts";

test("rounds display amounts without exposing decimal precision", () => {
  assert.equal(formatCurrency("1153.3333333333333333", "BDT"), "BDT\u00a01,153.33");
  assert.equal(formatCurrency("1450.0", "BDT"), "BDT\u00a01,450.00");
  assert.equal(formatCurrency(0, "BDT"), "BDT\u00a00.00");
});

test("uses the requested business currency and its fraction digits", () => {
  assert.equal(formatCurrency("12.345", "usd"), "USD\u00a012.35");
  assert.equal(formatCurrency("1450.5", "JPY"), "JPY\u00a01,451");
});

test("invalid amounts and currency configuration do not crash the dashboard", () => {
  for (const value of ["", "bad", Infinity, NaN]) assert.equal(formatCurrency(value, "BDT"), "—");
  assert.equal(formatCurrency("100", "invalid"), "—");
});
