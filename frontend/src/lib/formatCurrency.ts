export function formatCurrency(value: string | number, currency: string, locale = "en"): string {
  const amount = typeof value === "string" && !value.trim() ? NaN : Number(value);
  const code = currency.trim().toUpperCase();
  if (!Number.isFinite(amount) || !/^[A-Z]{3}$/.test(code)) return "—";

  return new Intl.NumberFormat(locale, { style: "currency", currency: code, currencyDisplay: "code" }).format(amount);
}
