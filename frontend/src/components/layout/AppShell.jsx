import { NavLink, Outlet } from "react-router-dom";
import { useAuth } from "../../auth/useAuth";

const businessNavigation = [
  ["/app", "Overview", true], ["/app/orders", "Orders"], ["/app/conversations", "Conversations"],
  ["/app/products", "Products"], ["/app/settings", "Business setup"]
];

export function AppShell() {
  const { auth, logout } = useAuth();
  const navigation = auth.actorType === "platform_administrator" ? [["/admin/businesses", "Businesses"]] : businessNavigation;
  return <div className="app-layout">
    <aside className="sidebar">
      <div className="brand"><span>CC</span><div>ChatCart<small>Commerce console</small></div></div>
      <nav>{navigation.map(([to,label,end]) => <NavLink key={to} to={to} end={end} className={({isActive})=>isActive?"active":""}>{label}</NavLink>)}</nav>
      <div className="account"><strong>{auth.actor?.name}</strong><small>{auth.business?.name || "Platform administrator"}</small></div>
      <button type="button" className="button ghost" onClick={logout}>Sign out</button>
    </aside>
    <main className="main-content"><Outlet /></main>
  </div>;
}
