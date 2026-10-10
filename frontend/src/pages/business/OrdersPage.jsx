import { useQuery } from "@tanstack/react-query";
import { apiRequest, downloadFile } from "../../lib/apiClient";
import { DataTable } from "../../components/ui/DataTable";
import { ErrorState, LoadingState } from "../../components/ui/Feedback";
import { PageHeader } from "../../components/ui/PageHeader";
import { Panel } from "../../components/ui/Panel";

export function OrdersPage() {
  const query = useQuery({ queryKey: ["orders"], queryFn: () => apiRequest("/api/orders") });
  if (query.isLoading) return <LoadingState />;
  if (query.isError) return <ErrorState error={query.error} />;
  const columns = [
    { key: "number", label: "Order", render: row => <div><strong>{row.number}</strong><small>{new Date(row.confirmed_at).toLocaleString()}</small></div> },
    { key: "customer", label: "Customer", render: row => <div>{row.customer_name}<small>{row.phone}</small></div> },
    { key: "channel", label: "Channel" },
    { key: "items", label: "Items", render: row => <div>{row.items.map((item, index) => <div key={`${item.product_id}-${item.product_variant_id}-${index}`}>
      {item.quantity} × {item.product_name}{item.variant_name ? ` — ${item.variant_name}` : ""}
    </div>)}</div> },
    { key: "total", label: "Total", render: row => `${row.total} ${row.currency}` },
    { key: "status", label: "Status", render: row => <span className={`status ${row.status}`}>{row.status.replaceAll("_", " ")}</span> },
  ];
  return <>
    <PageHeader title="Orders" description="Confirmed orders captured from customer conversations." actions={
      <button className="button secondary" onClick={() => downloadFile("/api/orders/export", `orders-${new Date().toISOString().slice(0, 10)}.csv`)}>Export CSV</button>
    } />
    <Panel><DataTable columns={columns} rows={query.data} emptyMessage="Confirmed customer orders will appear here." /></Panel>
  </>;
}
