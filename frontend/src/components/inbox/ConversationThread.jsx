import { useEffect, useRef } from "react";
import { customerName, HANDOVER_REASONS, formatMessageTime } from "../../lib/inbox";

const NEAR_BOTTOM_PX = 80;

export function ConversationThread({ conversation, canManage, draft, onDraft, onReply, onAction, busy, actionError, actionSuccess, onBack }) {
  const scrollRef = useRef(null);
  const nearBottom = useRef(true);
  const messages = conversation.messages || [];
  const lastId = messages.at(-1)?.id;
  const handedOver = conversation.status === "handed_over";
  const canSend = canManage && handedOver && conversation.channel === "facebook";

  useEffect(() => {
    const element = scrollRef.current;
    if (element && nearBottom.current) element.scrollTop = element.scrollHeight;
  }, [lastId]);

  return <section className="inbox-thread" aria-label="Conversation transcript">
    <header className="inbox-thread-header">
      <button type="button" className="button secondary small inbox-back" onClick={onBack}>← Chats</button>
      <div className="inbox-identity"><h2>{customerName(conversation)}</h2><small>{conversation.channel} · ID {conversation.external_customer_id}</small></div>
      {canManage && <button type="button" className="button secondary small" disabled={busy || actionError} onClick={() => onAction(handedOver ? "resume" : "handover")}>{handedOver ? "Hand back to assistant" : "Take over"}</button>}
    </header>
    {handedOver && <aside className="inbox-takeover" role="status"><strong>{canManage ? "You can reply. The assistant is paused in this chat." : "A seller is needed. The assistant is paused in this chat."}</strong>
      <span>{HANDOVER_REASONS[conversation.handover_reason] || "Seller response needed"}</span>
      <small>Automation resumes only when this conversation is handed back.</small>
      {(conversation.handover_summary?.active_order || conversation.handover_summary?.recent_topics?.length) && <details>
        <summary>Handover context</summary>
        {conversation.handover_summary.active_order && <p>Order at handover: {[conversation.handover_summary.active_order.quantity, conversation.handover_summary.active_order.product, conversation.handover_summary.active_order.status].filter(Boolean).join(" · ")}</p>}
        {Array.isArray(conversation.handover_summary.recent_topics) && <p>Recent topics: {conversation.handover_summary.recent_topics.join(", ").replaceAll("_", " ")}</p>}
      </details>}
    </aside>}
    <div className="inbox-messages" ref={scrollRef} onScroll={() => { const element = scrollRef.current; nearBottom.current = element.scrollHeight - element.scrollTop - element.clientHeight < NEAR_BOTTOM_PX; }}>
      {messages.length ? messages.map((message) => <article key={message.id} className={`inbox-message ${message.sender_type}`}>
        <small>{message.sender_type === "customer" ? customerName(conversation) : message.sender_type === "seller" ? "Seller" : "Assistant"}</small>
        <p>{message.content || "[Attachment]"}</p>
        {message.created_at && <time dateTime={message.created_at}>{formatMessageTime(message.created_at)}</time>}
      </article>) : <p className="state">No messages in this conversation yet.</p>}
    </div>
    <div className="inbox-composer">
      <button className="inbox-latest" type="button" onClick={() => { nearBottom.current = true; scrollRef.current.scrollTop = scrollRef.current.scrollHeight; }}>Jump to latest ↓</button>
      {actionError && <p className="form-error" role="alert">Couldn’t complete this action. Your draft is kept. Refresh the conversation before trying again to avoid a duplicate reply.</p>}
      {actionSuccess && <p className="form-success" role="status">{actionSuccess}</p>}
      {canSend ? <form onSubmit={(event) => { event.preventDefault(); onReply(); }}>
        <label htmlFor="seller-reply">Reply to {customerName(conversation)}</label>
        <div><textarea id="seller-reply" value={draft} disabled={busy} onChange={(event) => onDraft(event.target.value)} placeholder="Write your reply…" required /><button disabled={busy || actionError || !draft.trim()}>{busy ? "Saving…" : "Send reply"}</button></div>
      </form> : <p className="muted">{!canManage ? "Your role has read-only access to this conversation." : !handedOver ? "Take over to send a personal reply." : "Sending seller replies from this Inbox is currently supported for Messenger only."}</p>}
    </div>
  </section>;
}
