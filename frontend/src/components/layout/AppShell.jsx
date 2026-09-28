import { useEffect, useRef, useState } from "react";
import { NavLink, Outlet } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { useAuth } from "../../auth/useAuth";
import { apiRequest } from "../../lib/apiClient";
import { graphqlRequest } from "../../lib/graphqlClient";
import { DashboardContextDocument } from "../../graphql/generated/graphql";
import { pollInterval } from "../../lib/polling";

const businessNavigation = [
  ["/app", "Overview", true], ["/app/orders", "Orders"], ["/app/conversations", "Conversations"],
  ["/app/products", "Products"], ["/app/settings", "Business setup"]
];

function playHandoverSound() {
  const AudioContext = window.AudioContext || window.webkitAudioContext;
  if (!AudioContext) return;
  const context = new AudioContext();
  const oscillator = context.createOscillator();
  const gain = context.createGain();
  oscillator.type = "sine";
  oscillator.frequency.setValueAtTime(660, context.currentTime);
  oscillator.frequency.setValueAtTime(880, context.currentTime + 0.16);
  gain.gain.setValueAtTime(0.0001, context.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.16, context.currentTime + 0.02);
  gain.gain.exponentialRampToValueAtTime(0.0001, context.currentTime + 0.36);
  oscillator.connect(gain);
  gain.connect(context.destination);
  oscillator.start();
  oscillator.stop(context.currentTime + 0.38);
  oscillator.addEventListener("ended", () => context.close());
}

export function AppShell() {
  const { auth, logout } = useAuth();
  const [alertsEnabled, setAlertsEnabled] = useState(() => localStorage.getItem("chatcart_handover_alerts") === "enabled");
  const knownHandovers = useRef(null);
  const contextQuery = useQuery({
    queryKey: ["dashboard-context"],
    queryFn: () => graphqlRequest(DashboardContextDocument),
    enabled: auth.actorType === "business_user"
  });
  const conversationsQuery = useQuery({
    queryKey: ["conversations"],
    queryFn: () => apiRequest("/api/conversations"),
    enabled: auth.actorType === "business_user",
    refetchInterval: pollInterval,
    refetchIntervalInBackground: false
  });
  const conversations = conversationsQuery.data || [];
  const handovers = conversations.filter((conversation) => conversation.needs_attention);

  useEffect(() => {
    const currentIds = new Set(handovers.map((conversation) => conversation.id));
    if (knownHandovers.current === null) {
      knownHandovers.current = currentIds;
      return;
    }
    const newlyHandedOver = handovers.filter((conversation) => !knownHandovers.current.has(conversation.id));
    knownHandovers.current = currentIds;
    if (!alertsEnabled || newlyHandedOver.length === 0) return;

    playHandoverSound();
    if (typeof Notification !== "undefined" && Notification.permission === "granted") {
      new Notification("ChatCart seller response needed", {
        body: `${newlyHandedOver.length} conversation${newlyHandedOver.length === 1 ? "" : "s"} waiting for takeover.`
      });
    }
  }, [handovers, alertsEnabled]);

  async function enableAlerts() {
    if (typeof Notification !== "undefined" && Notification.permission === "default") {
      await Notification.requestPermission();
    }
    localStorage.setItem("chatcart_handover_alerts", "enabled");
    setAlertsEnabled(true);
    playHandoverSound();
  }

  const navigation = auth.actorType === "platform_administrator" ? [["/admin/businesses", "Businesses"]] : businessNavigation;
  const actor = contextQuery.data?.viewer || auth.actor;
  const business = contextQuery.data?.currentBusiness || auth.business;

  return <div className="app-layout">
    <aside className="sidebar">
      <div className="brand"><span>CC</span><div>ChatCart<small>Commerce console</small></div></div>
      <nav>{navigation.map(([to, label, end]) => <NavLink key={to} to={to} end={end} className={({ isActive }) => isActive ? "active" : ""}>
        <span>{label}</span>
        {to === "/app/conversations" && handovers.length > 0 && <strong className="nav-alert-count">{handovers.length}</strong>}
      </NavLink>)}</nav>
      {auth.actorType === "business_user" && <button type="button" className={`alert-toggle ${alertsEnabled ? "enabled" : ""}`} onClick={enableAlerts}>
        {alertsEnabled ? "🔔 Takeover alerts on" : "🔕 Enable takeover alerts"}
      </button>}
      <div className="account"><strong>{actor?.name}</strong><small>{business?.name || "Platform administrator"}</small></div>
      <button type="button" className="button ghost" onClick={logout}>Sign out</button>
    </aside>
    <main className="main-content"><Outlet /></main>
  </div>;
}
