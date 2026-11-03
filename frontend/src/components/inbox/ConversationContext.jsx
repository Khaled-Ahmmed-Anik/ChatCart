import { useId, useState } from "react";
import { Link } from "react-router-dom";
import { CONTEXT_TABS, REVIEW_LABELS, formatMessageTime } from "../../lib/inbox";
import { formatCurrency } from "../../lib/formatCurrency";
import { EmptyState } from "../ui/Feedback";

export function ConversationContext({ conversation, canManage, busy, onAction, reviewDraft, onReviewDraft }) {
  const [tab, setTab] = useState("Order");
  const prefix = useId();
  const context = conversation.inbox_context;
  const order = context?.order;
  const customer = context?.customer;
  const quality = conversation.quality;
  const review = reviewDraft || { label: quality?.review?.label || "successful", notes: quality?.review?.notes || "" };

  function selectTab(event, index) {
    let next;
    if (event.key === "ArrowRight") next = (index + 1) % CONTEXT_TABS.length;
    if (event.key === "ArrowLeft") next = (index + CONTEXT_TABS.length - 1) % CONTEXT_TABS.length;
    if (event.key === "Home") next = 0;
    if (event.key === "End") next = CONTEXT_TABS.length - 1;
    if (next !== undefined) { event.preventDefault(); setTab(CONTEXT_TABS[next]); document.getElementById(`${prefix}-tab-${next}`)?.focus(); }
  }

  return <aside className="inbox-context" aria-label="Conversation context">
    <div className="inbox-tabs" role="tablist" aria-label="Conversation details">{CONTEXT_TABS.map((name, index) =>
      <button key={name} type="button" id={`${prefix}-tab-${index}`} role="tab" aria-selected={tab === name} aria-controls={`${prefix}-panel-${index}`} tabIndex={tab === name ? 0 : -1} onKeyDown={(event) => selectTab(event, index)} onClick={() => setTab(name)}>{name}</button>
    )}</div>
    <section className="inbox-context-panel" id={`${prefix}-panel-0`} role="tabpanel" aria-labelledby={`${prefix}-tab-0`} hidden={tab !== "Order"} tabIndex={0}>
      <h2>{order?.pricing === "recorded" ? "Recorded order" : "Order in progress"}</h2>
      {!context ? <EmptyState title="Order context unavailable" description="Refresh after updating the backend." /> : order ? <>
        <p><span className={`status ${order.status}`}>{order.status.replaceAll("_", " ")}</span></p>
        {order.number && <strong>{order.number}</strong>}
        <ul className="inbox-order-items">{order.items.map((item, index) => <li key={index}><div><strong>{item.quantity} × {item.product_name}</strong>{item.variant_name && <small>{item.variant_name}</small>}</div><span>{formatCurrency(item.total, order.currency)}</span></li>)}</ul>
        {!order.items.length && <p className="muted">No complete items captured yet.</p>}
        <dl className="inbox-fields"><div><dt>{order.pricing === "recorded" ? "Recorded subtotal" : "Estimated items subtotal"}</dt><dd>{formatCurrency(order.subtotal, order.currency)}</dd></div>
          {order.pricing === "recorded" && <><div><dt>Recorded delivery</dt><dd>{formatCurrency(order.delivery_charge, order.currency)}</dd></div><div><dt>Recorded total</dt><dd>{formatCurrency(order.total, order.currency)}</dd></div></>}
        </dl>
        <p className="inbox-note">{order.pricing === "recorded" ? "Historical order values—not a new quote or proof of payment." : "Current catalogue prices. Delivery and other charges are not included. This is not a confirmed quote."}</p>
        <p className="inbox-note">Read-only. Editing and customer reconfirmation will be added separately.</p>
        <Link to="/app/orders">View orders</Link>
      </> : <EmptyState title="No order captured" description="Items appear here as the buyer builds an order." />}
    </section>
    <section className="inbox-context-panel" id={`${prefix}-panel-1`} role="tabpanel" aria-labelledby={`${prefix}-tab-1`} hidden={tab !== "Customer"} tabIndex={0}>
      <h2>Customer details</h2><p className="inbox-note">Last captured in this conversation. Not independently verified.</p>
      <dl className="inbox-fields">{[["Name", customer?.name || conversation.customer_name], ["Phone", customer?.phone], ["Address", customer?.address], ["First seen", formatMessageTime(customer?.first_seen_at)]].map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{value || "Not captured"}</dd></div>)}</dl>
      <h3>Orders in this conversation</h3>
      {context ? <><p>{context.recorded_order_count} recorded {context.recorded_order_count === 1 ? "order" : "orders"}</p>
        <ul className="inbox-history">{context.recent_orders.map((item) => <li key={item.id}><strong>{item.number}</strong><span>{formatCurrency(item.total, item.currency)}</span><small>{item.status.replaceAll("_", " ")} · {formatMessageTime(item.confirmed_at)}</small></li>)}</ul>
        {context.recorded_order_count > context.recent_orders.length && <p className="inbox-note">Showing the latest {context.recent_orders.length} orders.</p>}</> : <p className="muted">Customer context is unavailable. Refresh after updating the backend.</p>}
    </section>
    <section className="inbox-context-panel" id={`${prefix}-panel-2`} role="tabpanel" aria-labelledby={`${prefix}-tab-2`} hidden={tab !== "Review"} tabIndex={0}>
      <p className="eyebrow">Internal only · not sent to buyer</p><h2>Conversation review</h2>
      {quality ? <>
        <p className="inbox-quality"><strong>{quality.score}/100</strong><span className="status">{quality.grade?.replaceAll("_", " ")}</span></p>
        <p className="inbox-note">Automatic signals help review; they are not a verified customer outcome.</p>
        <p className="inbox-note">{quality.flags?.length ? quality.flags.join(", ").replaceAll("_", " ") : "No automatic quality issues detected."}</p>
        <form onSubmit={(event) => { event.preventDefault(); onAction("review", Object.fromEntries(new FormData(event.currentTarget))); }}>
          <label>Outcome<select name="label" value={review.label} onChange={(event) => onReviewDraft({ ...review, label: event.target.value })} disabled={!canManage || busy}>{Object.entries(REVIEW_LABELS).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
          <label>Private reviewer note<textarea name="notes" value={review.notes} onChange={(event) => onReviewDraft({ ...review, notes: event.target.value })} disabled={!canManage || busy} /></label>
          {canManage && <button disabled={busy}>Save review</button>}
        </form>
        <h3>Was the automated reply helpful?</h3>
        {canManage && <div className="actions"><button className="button secondary small" disabled={busy} onClick={() => onAction("feedback", { rating: "helpful" })}>Helpful</button><button className="button secondary small" disabled={busy} onClick={() => onAction("feedback", { rating: "unhelpful" })}>Not helpful</button></div>}
        {quality.customer_feedback && <p role="status">Saved feedback: {quality.customer_feedback.rating}</p>}
        {!canManage && <p className="inbox-note">Your role can view reviews but cannot change them.</p>}
      </> : <p className="muted">Review data is unavailable.</p>}
    </section>
  </aside>;
}
