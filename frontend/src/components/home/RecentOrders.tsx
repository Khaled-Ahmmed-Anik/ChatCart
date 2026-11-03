import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { apiRequest } from "../../lib/apiClient";
import { formatCurrency } from "../../lib/formatCurrency";
import { RECENT_ORDER_LIMIT } from "../../lib/homeAnalytics";
import { Panel } from "../ui/Panel";
import { EmptyState, ErrorState, LoadingState } from "../ui/Feedback";

type RecentOrder = {
  id: number; number: string; customer_name: string; total: string; currency: string; status: string;
  items: Array<{ product_name: string; variant_name?: string; quantity: number }>;
};

export function RecentOrders() {
  const query = useQuery<RecentOrder[]>({
    queryKey: ["orders", { limit: RECENT_ORDER_LIMIT }],
    queryFn: () => apiRequest(`/api/orders?limit=${RECENT_ORDER_LIMIT}`)
  });

  return <Panel title="Latest orders" actions={<Link to="/app/orders">View all orders</Link>}>
    {query.isPending ? <LoadingState /> : query.isError ?
      <ErrorState error={query.error} onRetry={() => query.refetch()} /> : query.data.length ?
        <ul className="home-order-list">{query.data.map((order) => <li key={order.id}>
          <span className="home-avatar" aria-hidden="true">{order.customer_name?.slice(0, 1) || "?"}</span>
          <div className="home-order-description"><strong>{order.customer_name}</strong><small>{order.number}</small>
            <p>{order.items.map((item) => `${item.quantity} × ${item.product_name}${item.variant_name ? ` · ${item.variant_name}` : ""}`).join("; ")}</p>
          </div>
          <div className="home-order-total"><strong>{formatCurrency(order.total, order.currency)}</strong>
            <span className={`status ${order.status}`}>{order.status.replaceAll("_", " ")}</span>
          </div>
        </li>)}</ul> : <EmptyState title="Your first order starts with a conversation" description="Orders confirmed by buyers will appear here." actions={<Link to="/app/conversations">Open Inbox</Link>} />}
  </Panel>;
}
