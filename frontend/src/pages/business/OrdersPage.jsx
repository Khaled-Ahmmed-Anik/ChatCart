import { useQuery } from "@tanstack/react-query";
import { apiRequest, downloadFile } from "../../lib/apiClient";
import { DataTable } from "../../components/ui/DataTable";
import { ErrorState, LoadingState } from "../../components/ui/Feedback";
import { PageHeader } from "../../components/ui/PageHeader";
import { Panel } from "../../components/ui/Panel";

export function OrdersPage(){const query=useQuery({queryKey:["orders"],queryFn:()=>apiRequest("/api/orders")});if(query.isLoading)return <LoadingState/>;if(query.isError)return <ErrorState error={query.error}/>;const columns=[{key:"number",label:"Order",render:r=><div><strong>{r.number}</strong><small>{new Date(r.confirmed_at).toLocaleString()}</small></div>},{key:"customer",label:"Customer",render:r=><div>{r.customer_name}<small>{r.phone}</small></div>},{key:"channel",label:"Channel"},{key:"items",label:"Items",render:r=>r.items.map(i=>`${i.quantity} × ${i.product_name}`).join(", ")},{key:"total",label:"Total",render:r=>`${r.total} ${r.currency}`},{key:"status",label:"Status",render:r=><span className={`status ${r.status}`}>{r.status.replaceAll("_"," ")}</span>}];return <><PageHeader title="Orders" description="Confirmed orders captured from customer conversations." actions={<button className="button secondary" onClick={()=>downloadFile("/api/orders/export",`orders-${new Date().toISOString().slice(0,10)}.csv`)}>Export CSV</button>}/><Panel><DataTable columns={columns} rows={query.data} emptyMessage="Confirmed customer orders will appear here."/></Panel></>}
