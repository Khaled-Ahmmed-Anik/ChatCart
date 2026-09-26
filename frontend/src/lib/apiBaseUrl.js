const configuredApiUrl = import.meta.env.VITE_API_URL?.trim();

export const API_URL = configuredApiUrl || (import.meta.env.PROD ? "" : "http://localhost:3000");
