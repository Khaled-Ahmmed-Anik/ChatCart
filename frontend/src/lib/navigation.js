export const BUSINESS_NAVIGATION = [
  { to: "/app", label: "Home", icon: "home", end: true },
  { to: "/app/conversations", label: "Inbox", icon: "inbox" },
  { to: "/app/orders", label: "Orders", icon: "orders" },
  { to: "/app/products", label: "Products", icon: "products" },
  { to: "/app/knowledge", label: "Knowledge", icon: "knowledge" },
  { to: "/app/settings", label: "Shop settings", icon: "settings" }
];

export const PLATFORM_NAVIGATION = [{ to: "/admin/businesses", label: "Shops", icon: "shops" }];

export function workspaceNavigation(actorType) {
  return actorType === "platform_administrator" ? PLATFORM_NAVIGATION : BUSINESS_NAVIGATION;
}
