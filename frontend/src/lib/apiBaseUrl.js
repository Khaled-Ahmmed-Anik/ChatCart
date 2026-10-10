const configuredApiUrl = import.meta.env.VITE_API_URL?.trim();

export const API_URL = configuredApiUrl || (import.meta.env.PROD ? "" : "http://localhost:3000");

export function apiEndpoint(path) {
  if (API_URL) return `${API_URL}${path}`;
  return new URL(path, window.location.origin).toString();
}
