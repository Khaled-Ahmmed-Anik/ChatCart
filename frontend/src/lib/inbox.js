export const INBOX_FILTERS = [
  { value: "all", label: "All" },
  { value: "needs_you", label: "Needs you" },
  { value: "assistant", label: "Assistant" }
];

export const CONTEXT_TABS = ["Order", "Customer", "Review"];
export const MANAGING_ROLES = ["owner", "admin", "sales_agent"];
export const REVIEW_LABELS = {
  successful: "Successful", abandoned: "Abandoned", confusing: "Confusing",
  needs_follow_up: "Needs follow-up", incorrect_reply: "Incorrect reply"
};
export const HANDOVER_REASONS = {
  customer_requested_human: "Customer requested a person", repeated_complaint: "Repeated complaint",
  repeated_confusion: "Repeated unresolved questions", refund_or_replacement: "Refund or replacement request",
  processed_order_change: "Processed order needs changing", delivery_dispute: "Delivery dispute",
  damaged_or_wrong_product: "Damaged or incorrect product", seller_takeover: "Taken over by seller"
};

export function customerName(conversation) {
  return conversation?.customer_name || ({ facebook: "Messenger customer", instagram: "Instagram customer", whatsapp: "WhatsApp customer" }[conversation?.channel]) || "Customer";
}

export function needsAttention(conversation) {
  return Boolean(conversation.needs_attention || conversation.status === "handed_over");
}

export function matchesConversation(conversation, search = "", filter = "all") {
  if (filter === "needs_you" && !needsAttention(conversation)) return false;
  if (filter === "assistant" && conversation.status !== "active") return false;
  const normalize = (value) => String(value).normalize("NFKC").toLowerCase().replace(/[\s()+-]/g, "");
  const text = [customerName(conversation), conversation.customer_phone || "", conversation.external_customer_id, conversation.channel].join(" ");
  return normalize(text).includes(normalize(search));
}

export function formatMessageTime(value) {
  if (!value) return "";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "" : date.toLocaleString([], { dateStyle: "medium", timeStyle: "short" });
}
