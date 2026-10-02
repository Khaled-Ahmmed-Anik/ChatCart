import { useEffect, useRef, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiRequest } from "../../lib/apiClient";
import { EmptyState, ErrorState, LoadingState } from "../../components/ui/Feedback";
import { PageHeader } from "../../components/ui/PageHeader";
import { Panel } from "../../components/ui/Panel";
import { pollInterval } from "../../lib/polling";

const reasonLabels = {
  customer_requested_human: "Customer requested a person",
  repeated_complaint: "Repeated complaint",
  repeated_confusion: "Repeated unresolved questions",
  refund_or_replacement: "Refund or replacement request",
  processed_order_change: "Processed order needs changing",
  delivery_dispute: "Delivery dispute",
  damaged_or_wrong_product: "Damaged or incorrect product",
  seller_takeover: "Taken over by seller"
};

const reviewLabels = {
  successful: "Successful",
  abandoned: "Abandoned",
  confusing: "Confusing",
  needs_follow_up: "Needs follow-up",
  incorrect_reply: "Incorrect reply"
};

export function ConversationsPage() {
  const [selectedId, setSelectedId] = useState(null);
  const messagesEndRef = useRef(null);
  const client = useQueryClient();
  const list = useQuery({
    queryKey: ["conversations"],
    queryFn: () => apiRequest("/api/conversations")
  });
  const detail = useQuery({
    queryKey: ["conversation", selectedId],
    queryFn: () => apiRequest(`/api/conversations/${selectedId}`),
    enabled: Boolean(selectedId),
    refetchInterval: selectedId ? pollInterval : false,
    refetchIntervalInBackground: false
  });
  const action = useMutation({
    mutationFn: ({ id, path, body }) => apiRequest(`/api/conversations/${id}/${path}`, {
      method: "POST",
      body: body ? JSON.stringify(body) : undefined
    }),
    onSuccess: () => {
      client.invalidateQueries({ queryKey: ["conversations"] });
      client.invalidateQueries({ queryKey: ["conversation", selectedId] });
    }
  });
  const selected = detail.data;

  useEffect(() => {
    if (selected?.messages?.length) messagesEndRef.current?.scrollIntoView({ block: "end" });
  }, [selected?.messages?.length, selectedId]);

  if (list.isLoading) return <LoadingState />;
  if (list.isError) return <ErrorState error={list.error} />;

  function reply(event) {
    event.preventDefault();
    const form = event.currentTarget;
    action.mutate(
      { id: selectedId, path: "reply", body: { content: new FormData(form).get("content") } },
      { onSuccess: () => form.reset() }
    );
  }

  function review(event) {
    event.preventDefault();
    const form = event.currentTarget;
    action.mutate({
      id: selectedId,
      path: "review",
      body: Object.fromEntries(new FormData(form))
    });
  }

  const handover = selected?.handover_summary;
  const attentionCount = list.data.filter((conversation) => conversation.needs_attention).length;

  return <>
    <PageHeader
      title="Conversations"
      description="Review customer context and step in when a human is needed."
      actions={attentionCount > 0 && <span className="attention-summary">{attentionCount} waiting for a seller</span>}
    />
    <div className="conversation-layout">
      <Panel className="conversation-list" title="Inbox">
        {list.data.length ? list.data.map((conversation) =>
          <button
            key={conversation.id}
            className={`conversation-row ${selectedId === conversation.id ? "selected" : ""} ${conversation.needs_attention ? "needs-attention" : ""}`}
            onClick={() => setSelectedId(conversation.id)}
          >
            <span>
              <strong>{conversation.external_customer_id}</strong>
              <small>{conversation.channel} · {conversation.message_count} messages</small>
              {conversation.needs_attention && <small className="attention-reason">
                {reasonLabels[conversation.handover_reason] || "Seller response needed"}
              </small>}
              {conversation.quality?.flags?.length > 0 && <small className="attention-reason">
                Quality {conversation.quality.score}/100 · {conversation.quality.flags.length} issue(s)
              </small>}
            </span>
            <span className={`status ${conversation.status}`}>
              {conversation.needs_attention ? "Needs reply" : conversation.status.replaceAll("_", " ")}
            </span>
          </button>
        ) : <EmptyState description="Customer conversations will appear here." />}
      </Panel>
      <Panel
        className="transcript"
        title={selected ? selected.external_customer_id : "Conversation"}
        actions={selected && <button
          className="button secondary small"
          disabled={action.isPending}
          onClick={() => action.mutate({ id: selected.id, path: selected.status === "handed_over" ? "resume" : "handover" })}
        >
          {selected.status === "handed_over" ? "Resume AI" : "Take over"}
        </button>}
      >
        {detail.isLoading && <p className="muted">Loading conversation…</p>}
        {selected ? <>
          {selected.status === "handed_over" && handover && <aside className="handover-summary urgent">
            <strong>Seller response required</strong>
            <span>Reason: {reasonLabels[handover.reason] || handover.reason.replaceAll("_", " ")}</span>
            {handover.active_order && <span>Order: {[handover.active_order.quantity, handover.active_order.product, handover.active_order.status].filter(Boolean).join(" · ")}</span>}
            {handover.recent_topics?.length > 0 && <span>Recent topics: {handover.recent_topics.join(", ").replaceAll("_", " ")}</span>}
          </aside>}
          <div className="messages">
            {selected.messages.map((message) => <article key={message.id} className={`message ${message.sender_type}`}>
              <small>{message.sender_type}</small>
              <p>{message.content}</p>
            </article>)}
            <div ref={messagesEndRef} />
          </div>
          <aside className="quality-review">
            <div>
              <strong>Conversation quality: {selected.quality.score}/100</strong>
              <span className={`status ${selected.quality.grade}`}>{selected.quality.grade.replaceAll("_", " ")}</span>
            </div>
            {selected.quality.flags.length > 0
              ? <small>Detected: {selected.quality.flags.join(", ").replaceAll("_", " ")}</small>
              : <small>No automatic quality issues detected.</small>}
            <form onSubmit={review}>
              <select name="label" defaultValue={selected.quality.review?.label || "successful"}>
                {Object.entries(reviewLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
              </select>
              <input name="notes" defaultValue={selected.quality.review?.notes || ""} placeholder="Optional review note" />
              <button className="button secondary small" disabled={action.isPending}>Save review</button>
            </form>
            <div className="feedback-actions">
              <span>Customer feedback:</span>
              <button className="button secondary small" onClick={() => action.mutate({ id: selected.id, path: "feedback", body: { rating: "helpful" } })}>Helpful</button>
              <button className="button secondary small" onClick={() => action.mutate({ id: selected.id, path: "feedback", body: { rating: "unhelpful" } })}>Not helpful</button>
              {selected.quality.customer_feedback && <small>Saved: {selected.quality.customer_feedback.rating}</small>}
            </div>
          </aside>
          {selected.status === "handed_over" && <form className="reply-form" onSubmit={reply}>
            <input name="content" placeholder="Write a seller reply…" required />
            <button disabled={action.isPending}>Send</button>
          </form>}
        </> : !detail.isLoading && <EmptyState title="Select a conversation" description="Choose a customer from the inbox to see the transcript." />}
      </Panel>
    </div>
  </>;
}
