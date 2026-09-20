import { useQuery } from "@tanstack/react-query";
import { ErrorState, LoadingState } from "../../components/ui/Feedback";
import { PageHeader } from "../../components/ui/PageHeader";
import { Panel } from "../../components/ui/Panel";
import { DashboardAnalyticsDocument } from "../../graphql/generated/graphql";
import { graphqlRequest } from "../../lib/graphqlClient";

type BreakdownData = Record<string, string | number>;

function asBreakdown(value: unknown): BreakdownData {
  return value && typeof value === "object" && !Array.isArray(value) ? value as BreakdownData : {};
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
  const metrics: Array<[string, string | number]> = [
    ["Conversations", data.conversations],
    ["Confirmed orders", data.confirmedOrders],
    ["Chat → order", `${data.conversationToOrderRate}%`],
    ["Revenue", `${data.revenue} BDT`],
    ["Unique customers", data.uniqueCustomers],
    ["Repeat customers", data.repeatCustomers],
    ["Repeat rate", `${data.repeatCustomerRate}%`],
    ["Average order", `${data.averageOrderValue} BDT`]
  ];

  return <>
    <PageHeader title="Overview" description="A clear view of conversations turning into revenue." />
    <div className="metrics">{metrics.map(([label, value]) => <Panel className="metric" key={label}><span>{label}</span><strong>{value}</strong></Panel>)}</div>
    <div className="content-grid">
      <Breakdown title="Orders by status" data={asBreakdown(data.ordersByStatus)} />
      <Breakdown title="Orders by channel" data={asBreakdown(data.ordersByChannel)} />
      <Breakdown title="Top products" data={asBreakdown(data.topProducts)} />
    </div>
  </>;
}
