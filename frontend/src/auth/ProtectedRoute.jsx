import { Navigate, useLocation } from "react-router-dom";
import { useAuth } from "./useAuth";

export function ProtectedRoute({ actorType, children }) {
  const { auth } = useAuth();
  const location = useLocation();
  if (!auth) return <Navigate to="/login" replace state={{ from: location }} />;
  if (actorType && auth.actorType !== actorType) {
    return <Navigate to={auth.actorType === "platform_administrator" ? "/admin/businesses" : "/app"} replace />;
  }
  return children;
}
