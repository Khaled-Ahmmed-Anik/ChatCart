import { useCallback, useEffect, useMemo, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { apiRequest } from "../lib/apiClient";
import { AuthContext } from "./auth-context";

const STORAGE_KEY = "chatcart_auth";

function storedAuth() {
  try { return JSON.parse(localStorage.getItem(STORAGE_KEY)) || null; } catch { return null; }
}

export function AuthProvider({ children }) {
  const [auth, setAuth] = useState(storedAuth);
  const queryClient = useQueryClient();

  useEffect(() => {
    const handleUnauthorized = () => { queryClient.clear(); setAuth(null); };
    window.addEventListener("chatcart:unauthorized", handleUnauthorized);
    return () => window.removeEventListener("chatcart:unauthorized", handleUnauthorized);
  }, [queryClient]);

  const login = useCallback(async ({ level, email, password }) => {
    const result = await apiRequest(`/auth/${level === "admin" ? "admin/" : ""}login`, {
      method: "POST", body: JSON.stringify({ email, password })
    });
    const nextAuth = { token: result.token, actorType: result.actor_type,
      actor: result.user || result.administrator, business: result.business || null };
    localStorage.setItem("chatcart_session_token", result.token);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(nextAuth));
    setAuth(nextAuth);
    return nextAuth;
  }, []);

  const logout = useCallback(async () => {
    await apiRequest("/auth/logout", { method: "DELETE" }).catch(() => null);
    localStorage.removeItem("chatcart_session_token"); localStorage.removeItem(STORAGE_KEY);
    queryClient.clear(); setAuth(null);
  }, [queryClient]);

  const value = useMemo(() => ({ auth, login, logout }), [auth, login, logout]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
