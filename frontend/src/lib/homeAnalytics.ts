export type BreakdownData = Record<string, string | number>;
export const RECENT_ORDER_LIMIT = 5;
export const TOP_PRODUCT_LIMIT = 5;

export function asObject(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};
}

export function asBreakdown(value: unknown): BreakdownData {
  return Object.fromEntries(Object.entries(asObject(value)).filter(
    (entry): entry is [string, string | number] => typeof entry[1] === "string" || typeof entry[1] === "number"
  ));
}

export function ordersNeedingReview(value: unknown): number {
  const counts = asObject(value);
  return ["confirmed", "revision_pending"].reduce((total, status) => {
    const count = Number(counts[status]);
    return total + (Number.isFinite(count) && count > 0 ? count : 0);
  }, 0);
}

export function rankedProducts(value: unknown) {
  return Object.entries(asBreakdown(value))
    .map(([name, quantity]) => ({ name, quantity: Number(quantity) }))
    .filter(({ quantity }) => Number.isFinite(quantity) && quantity > 0)
    .sort((a, b) => b.quantity - a.quantity || a.name.localeCompare(b.name))
    .slice(0, TOP_PRODUCT_LIMIT);
}
