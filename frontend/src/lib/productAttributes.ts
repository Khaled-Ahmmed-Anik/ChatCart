export function parseProductAttributes(text: string): Record<string, unknown> {
  return Object.fromEntries(text.split("\n").filter(line => line.includes("=")).map(line => {
    const separator = line.indexOf("=");
    const key = line.slice(0, separator).trim();
    const value = line.slice(separator + 1).trim();
    if (/^[\[{]/.test(value)) {
      try { return [key, JSON.parse(value)]; } catch { /* Preserve non-JSON text. */ }
    }
    const options = value.split("|").map(option => option.trim()).filter(Boolean);
    return [key, options.length > 1 ? options : value];
  }).filter(([key]) => Boolean(key)));
}

export function formatProductAttributes(attributes: Record<string, unknown>): string {
  return Object.entries(attributes).map(([key, value]) => {
    const formatted = Array.isArray(value) && value.every(item => typeof item === "string")
      ? value.join(" | ") : value !== null && typeof value === "object" ? JSON.stringify(value) : value;
    return `${key}=${formatted}`;
  }).join("\n");
}
