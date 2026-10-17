import { useState } from "react";
import { EmptyState } from "../ui/Feedback";
import { INBOX_FILTERS, customerName, needsAttention, matchesConversation } from "../../lib/inbox";

export function InboxList({ conversations, selectedId, onSelect }) {
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState("all");
  const visible = conversations.filter((conversation) => matchesConversation(conversation, search, filter));

  return <section className="inbox-list" aria-label="Customer conversations">
    <header><label htmlFor="inbox-search">Search chats</label><input id="inbox-search" type="search" placeholder="Name, phone or customer ID" value={search} onChange={(event) => setSearch(event.target.value)} />
      <div className="inbox-filters" aria-label="Conversation filters">{INBOX_FILTERS.map(({ value, label }) =>
        <button key={value} type="button" aria-pressed={filter === value} onClick={() => setFilter(value)}>{label}<small>{conversations.filter((conversation) => matchesConversation(conversation, "", value)).length}</small></button>
      )}</div>
    </header>
    <div className="inbox-list-scroll">
      {visible.length ? visible.map((conversation) => <button type="button" key={conversation.id} aria-current={selectedId === conversation.id ? "true" : undefined} className={`inbox-row ${selectedId === conversation.id ? "selected" : ""}`} onClick={() => onSelect(conversation.id)}>
        <span className="inbox-avatar" aria-hidden="true">{customerName(conversation).slice(0, 1)}</span>
        <span className="inbox-row-copy"><strong>{customerName(conversation)}</strong><small>{conversation.channel} · {conversation.message_count} messages</small>
          <span className={`status ${conversation.status}`}>{needsAttention(conversation) ? "Needs you" : conversation.status === "active" ? "Assistant" : "Closed"}</span>
        </span>
      </button>) : <EmptyState title={conversations.length ? "No matching chats" : "No chats yet"} description={conversations.length ? "Try a different search or filter." : "Buyer conversations will appear here when messages arrive."} actions={conversations.length ? <button className="button secondary small" onClick={() => { setSearch(""); setFilter("all"); }}>Clear filters</button> : null} />}
    </div>
  </section>;
}
