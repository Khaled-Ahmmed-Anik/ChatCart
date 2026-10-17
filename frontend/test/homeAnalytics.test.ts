import test from "node:test";
import assert from "node:assert/strict";
import { asObject, asBreakdown, ordersNeedingReview, rankedProducts, TOP_PRODUCT_LIMIT } from "../src/lib/homeAnalytics.ts";

test("analytics breakdowns ignore null arrays and nested objects without crashing", () => {
  for (const value of [null, undefined, [], "bad", 5]) assert.deepEqual(asObject(value), {});
  assert.deepEqual(asBreakdown({ count: 4, text: "2", nested: {}, empty: null }), { count: 4, text: "2" });
});

test("review count uses only confirmed and revision-pending orders, not packed claims", () => {
  assert.equal(ordersNeedingReview({ confirmed: 3, revision_pending: 2, processing: 8, delivered: 9, cancelled: 7 }), 5);
  assert.equal(ordersNeedingReview({ confirmed: "4", revision_pending: "bad" }), 4);
  assert.equal(ordersNeedingReview({ confirmed: -1, revision_pending: Infinity }), 0);
  assert.equal(ordersNeedingReview(null), 0);
});

test("rankings are numerically sorted, bounded and omit invalid quantities", () => {
  const data = Object.fromEntries(Array.from({ length: 10 }, (_, index) => [`Product ${index}`, `${index + 1}`]));
  const result = rankedProducts({ ...data, invalid: "NaN", zero: 0, negative: -5, nested: {} });
  assert.equal(result.length, TOP_PRODUCT_LIMIT);
  assert.deepEqual(result[0], { name: "Product 9", quantity: 10 });
  assert.deepEqual(rankedProducts(undefined), []);
});
