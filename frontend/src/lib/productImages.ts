export function safeProductImageUrl(value: string | undefined): string | undefined {
  if (!value) return undefined;
  try {
    const url = new URL(value);
    const host = url.hostname.toLowerCase();
    if (url.protocol !== "https:" || url.username || url.password || url.port ||
        !host.includes(".") || /^[\d.]+$/.test(host) || host.startsWith("[") ||
        [".localhost", ".local", ".internal"].some(suffix => host.endsWith(suffix))) return undefined;
    return url.href;
  } catch {
    return undefined;
  }
}
