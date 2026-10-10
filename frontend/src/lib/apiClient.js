import { API_URL } from "./apiBaseUrl";

export class ApiError extends Error {
  constructor(message, status, details) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.details = details;
  }
}

export async function apiRequest(path, options = {}) {
  const token = localStorage.getItem("chatcart_session_token");
  const headers = new Headers(options.headers);
  if (token) headers.set("Authorization", `Bearer ${token}`);
  if (options.body && !(options.body instanceof FormData)) headers.set("Content-Type", "application/json");

  const response = await fetch(`${API_URL}${path}`, { ...options, headers });
  if (!response.ok) {
    const details = await response.json().catch(() => ({}));
    if (response.status === 401 && !path.includes("/auth/")) {
      localStorage.removeItem("chatcart_session_token");
      localStorage.removeItem("chatcart_auth");
      window.dispatchEvent(new Event("chatcart:unauthorized"));
    }
    const validationMessage = Object.values(details.errors || {}).flat().join(", ");
    throw new ApiError(details.error || validationMessage || `Request failed (${response.status})`, response.status, details);
  }
  if (response.status === 204) return null;
  return response.json();
}

export async function downloadFile(path, filename) {
  const token = localStorage.getItem("chatcart_session_token");
  const response = await fetch(`${API_URL}${path}`, { headers: { Authorization: `Bearer ${token}` } });
  if (!response.ok) throw new ApiError("Download failed", response.status);
  const url = URL.createObjectURL(await response.blob());
  const link = document.createElement("a");
  link.href = url; link.download = filename; link.click();
  URL.revokeObjectURL(url);
}
