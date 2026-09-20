import { NavLink, Outlet } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { useAuth } from "../../auth/useAuth";
import { graphqlRequest } from "../../lib/graphqlClient";
import { DashboardContextDocument } from "../../graphql/generated/graphql";

const businessNavigation = [
  ["/app", "Overview", true], ["/app/orders", "Orders"], ["/app/conversations", "Conversations"],
  ["/app/products", "Products"], ["/app/settings", "Business setup"]
];

export function AppShell() {
  const { auth, logout } = useAuth();
  const contextQuery = useQuery({
    queryKey: ["dashboard-context"],
    queryFn: () => graphqlRequest(DashboardContextDocument),
    enabled: auth.actorType === "business_user"
  });
  const navigation = auth.actorType === "platform_administrator" ? [["/admin/businesses", "Businesses"]] : businessNavigation;
  const actor = contextQuery.data?.viewer || auth.actor;
  const business = contextQuery.data?.currentBusiness || auth.business;
  return <div className="app-layout">
    <aside className="sidebar">
      <div className="brand"><span>CC</span><div>ChatCart<small>Commerce console</small></div></div>
      <nav>{navigation.map(([to,label,end]) => <NavLink key={to} to={to} end={end} className={({isActive})=>isActive?"active":""}>{label}</NavLink>)}</nav>
      <div className="account"><strong>{actor?.name}</strong><small>{business?.name || "Platform administrator"}</small></div>
      <button type="button" className="button ghost" onClick={logout}>Sign out</button>
    </aside>
    <main className="main-content"><Outlet /></main>
  </div>;
}
