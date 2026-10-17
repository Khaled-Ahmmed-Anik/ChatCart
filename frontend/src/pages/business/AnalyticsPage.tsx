import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { ErrorState, LoadingState, EmptyState } from "../../components/ui/Feedback";
import { PageHeader } from "../../components/ui/PageHeader";
import { Panel } from "../../components/ui/Panel";
import { Icon } from "../../components/ui/Icon";
import { RecentOrders } from "../../components/home/RecentOrders";
import { DashboardAnalyticsDocument } from "../../graphql/generated/graphql";
import { graphqlRequest } from "../../lib/graphqlClient";
import { apiRequest } from "../../lib/apiClient";
import { formatCurrency } from "../../lib/formatCurrency";
import { asObject, asBreakdown, ordersNeedingReview, rankedProducts, type BreakdownData } from "../../lib/homeAnalytics";

type AttentionConversation = { id: number; needs_attention: boolean };

function Breakdown({ title, data }: { title: string; data: BreakdownData }) {
  return <Panel title={title}><div className="breakdown">
    {Object.entries(data).map(([key, value]) => <div key={key}><span>{key.replaceAll("_", " ")}</span><strong>{value}</strong></div>)}
    {!Object.keys(data).length && <p className="muted">No data yet.</p>}
  </div></Panel>;
}

export function AnalyticsPage() {
  const query = useQuery({ queryKey: ["analytics"], queryFn: () => graphqlRequest(DashboardAnalyticsDocument) });
  // The shell owns polling; Home observes the same cache without another timer.
  const conversations = useQuery<AttentionConversation[]>({
    queryKey: ["conversations"], queryFn: () => apiRequest("/api/conversations")
  });
  const data = query.data?.analytics;
  const handoverData = asObject(data?.handovers);
  const qualityData = asObject(data?.conversationQuality);
  const handoverPerformance = asBreakdown(handoverData);
  const qualitySummary = asBreakdown(qualityData);
  const waiting = conversations.data?.filter((conversation) => conversation.needs_attention).length;
  const reviewCount = data ? ordersNeedingReview(data.ordersByStatus) : undefined;
  const products = rankedProducts(data?.topProducts);
  const metrics = data ? [
    { label: "Order value", value: formatCurrency(data.revenue, query.data!.currentBusiness.currency), description: "Excludes cancelled orders; not collected payments." },
    { label: "Orders", value: data.confirmedOrders, description: "All recorded orders, including cancelled orders." },
    { label: "Buyers who chatted", value: data.uniqueCustomers, description: `${data.repeatCustomers} repeat ordering customers.` },
    { label: "Chats that ordered", value: `${data.conversationToOrderRate}%`, description: "Chats with an order record, including cancelled orders." }
  ] : [];
  const secondaryMetrics: Array<[string, string | number]> = data ? [
    ["Conversations", data.conversations], ["Repeat customers", data.repeatCustomers],
    ["Repeat rate", `${data.repeatCustomerRate}%`],
    ["Average order", formatCurrency(data.averageOrderValue, query.data!.currentBusiness.currency)],
    ["Takeovers", handoverPerformance.total ?? 0], ["Waiting for seller", handoverPerformance.waiting_now ?? 0],
    ["Chat quality", qualitySummary.average_score ?? "—"], ["Needs review", qualitySummary.needs_review ?? 0]
  ] : [];

  return <div className="home-page">
    <PageHeader eyebrow="Your shop at a glance" title="Home" description="See what needs your attention, then get back to your buyers." actions={<span className="home-period">All time</span>} />
    <section className="home-actions" aria-label="Shop actions">
      <article className={`home-action ${waiting ? "needs-attention" : ""}`}>
        <span className="eyebrow">Needs you</span><Icon name="inbox" />
        {conversations.isError ? <><h2>Inbox status unavailable</h2><button className="button secondary small" onClick={() => conversations.refetch()}>Retry Inbox status</button></> :
          <><h2>{waiting === undefined ? "Checking conversations…" : waiting ? `${waiting} ${waiting === 1 ? "chat needs" : "chats need"} a reply` : "No chats waiting for you"}</h2>
            <p>The assistant hands conversations over when a seller is needed.</p></>}
        <Link to="/app/conversations">Open Inbox <span aria-hidden="true">→</span></Link>
      </article>
      <article className="home-action">
        <span className="eyebrow">Orders</span><Icon name="orders" />
        <h2>{reviewCount === undefined ? "Review your orders" : `${reviewCount} ${reviewCount === 1 ? "order" : "orders"} to review`}</h2>
        <p>Confirmed orders and orders awaiting revision. Review their next steps.</p>
        <Link to="/app/orders">See orders <span aria-hidden="true">→</span></Link>
      </article>
      <article className="home-action">
        <span className="eyebrow">Shop information</span><Icon name="settings" />
        <h2>Keep your assistant informed</h2><p>Check delivery details, payment methods, policies and channels.</p>
        <Link to="/app/settings">Open shop settings <span aria-hidden="true">→</span></Link>
      </article>
    </section>

    <section aria-label="Business performance">
      <div className="home-section-heading"><h2>Business performance</h2><span className="muted">All time · no date filter applied</span></div>
      {query.isPending ? <LoadingState /> : query.isError && !data ? <ErrorState error={query.error} onRetry={() => query.refetch()} /> : <>
        {query.isError && <p className="knowledge-notice" role="status">Couldn’t refresh analytics. Showing the last loaded values. <button className="button secondary small" onClick={() => query.refetch()}>Retry analytics</button></p>}
        <div className="metrics home-metrics">{metrics.map(({ label, value, description }) => <Panel className="metric" key={label}><span>{label}</span><strong>{value}</strong><small>{description}</small></Panel>)}</div>
      </>}
    </section>

    <div className="home-main-grid">
      <RecentOrders />
      <Panel title="Most ordered products" actions={<Link to="/app/products">View products</Link>}>
        <p className="home-panel-description">All-time units across recorded orders, including cancelled orders.</p>
        {query.isPending ? <LoadingState /> : query.isError && !data ? <ErrorState error={query.error} onRetry={() => query.refetch()} /> : products.length ?
          <ol className="home-product-ranking">{products.map(({ name, quantity }) => <li key={name}><div><strong>{name}</strong><span>{quantity} {quantity === 1 ? "unit" : "units"}</span></div><meter min={0} max={products[0].quantity} value={quantity} aria-label={`${name}: ${quantity} units`} /></li>)}</ol> :
          <EmptyState title="See what buyers choose" description="Product rankings appear after orders are recorded." />}
      </Panel>
    </div>

    {data && <details className="home-details"><summary>Detailed analytics <span>Customer retention, order breakdowns and conversation quality</span></summary>
      <div className="metrics">{secondaryMetrics.map(([label, value]) => <Panel className="metric" key={label}><span>{label}</span><strong>{value}</strong></Panel>)}</div>
      <div className="content-grid">
        <Breakdown title="Orders by status" data={asBreakdown(data.ordersByStatus)} />
        <Breakdown title="Orders by channel" data={asBreakdown(data.ordersByChannel)} />
        <Breakdown title="Top products · all recorded units" data={asBreakdown(data.topProducts)} />
        <Breakdown title="Seller takeover performance" data={handoverPerformance} />
        <Breakdown title="Takeover reasons" data={asBreakdown(handoverData.reasons)} />
        <Breakdown title="Conversation quality" data={qualitySummary} />
        <Breakdown title="Review labels" data={asBreakdown(qualityData.review_labels)} />
        <Breakdown title="Abandoned checkout stages" data={asBreakdown(qualityData.abandoned_checkout_stages)} />
      </div>
    </details>}
  </div>;
}
