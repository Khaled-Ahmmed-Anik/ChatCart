import { useQuery } from "@tanstack/react-query";
import { ErrorState, LoadingState } from "../../components/ui/Feedback";
import { PageHeader } from "../../components/ui/PageHeader";
import { Panel } from "../../components/ui/Panel";
import { DashboardAnalyticsDocument } from "../../graphql/generated/graphql";
import { graphqlRequest } from "../../lib/graphqlClient";

type BreakdownData = Record<string, string | number>;
type JsonObject = Record<string, unknown>;

function asObject(value: unknown): JsonObject {
  return value && typeof value === "object" && !Array.isArray(value) ? value as JsonObject : {};
}

function asBreakdown(value: unknown): BreakdownData {
  return Object.fromEntries(
    Object.entries(asObject(value)).filter((entry): entry is [string, string | number] =>
      typeof entry[1] === "string" || typeof entry[1] === "number"
    )
  );
}

function Breakdown({ title, data }: { title: string; data: BreakdownData }) {
  return <Panel title={title}><div className="breakdown">
    {Object.entries(data).map(([key, value]) => <div key={key}><span>{key.replaceAll("_", " ")}</span><strong>{value}</strong></div>)}
    {!Object.keys(data).length && <p className="muted">No data yet.</p>}
  </div></Panel>;
}

export function AnalyticsPage() {
  const query = useQuery({
    queryKey: ["analytics"],
    queryFn: () => graphqlRequest(DashboardAnalyticsDocument)
  });
  if (query.isLoading) return <LoadingState />;
  if (query.isError) return <ErrorState error={query.error} />;

  const data = query.data!.analytics;
  const handoverData = asObject(data.handovers);
  const qualityData = asObject(data.conversationQuality);
  const handoverPerformance = asBreakdown(handoverData);
  const handoverReasons = asBreakdown(handoverData.reasons);
  const qualitySummary = asBreakdown(qualityData);
  const reviewLabels = asBreakdown(qualityData.review_labels);
  const abandonedCheckoutStages = asBreakdown(qualityData.abandoned_checkout_stages);
  const metrics: Array<[string, string | number]> = [
    ["Conversations", data.conversations],
    ["Confirmed orders", data.confirmedOrders],
    ["Chat → order", `${data.conversationToOrderRate}%`],
    ["Revenue", `${data.revenue} BDT`],
    ["Unique customers", data.uniqueCustomers],
    ["Repeat customers", data.repeatCustomers],
    ["Repeat rate", `${data.repeatCustomerRate}%`],
    ["Average order", `${data.averageOrderValue} BDT`],
    ["Takeovers", handoverPerformance.total ?? 0],
    ["Waiting for seller", handoverPerformance.waiting_now ?? 0],
    ["Chat quality", qualitySummary.average_score ?? "—"],
    ["Needs review", qualitySummary.needs_review ?? 0]
  ];

  return <>
    <PageHeader title="Overview" description="A clear view of conversations turning into revenue." />
    <div className="metrics">{metrics.map(([label, value]) => <Panel className="metric" key={label}><span>{label}</span><strong>{value}</strong></Panel>)}</div>
    <div className="content-grid">
      <Breakdown title="Orders by status" data={asBreakdown(data.ordersByStatus)} />
      <Breakdown title="Orders by channel" data={asBreakdown(data.ordersByChannel)} />
      <Breakdown title="Top products" data={asBreakdown(data.topProducts)} />
      <Breakdown title="Seller takeover performance" data={handoverPerformance} />
      <Breakdown title="Takeover reasons" data={handoverReasons} />
      <Breakdown title="Conversation quality" data={qualitySummary} />
      <Breakdown title="Review labels" data={reviewLabels} />
      <Breakdown title="Abandoned checkout stages" data={abandonedCheckoutStages} />
    </div>
  </>;
}
