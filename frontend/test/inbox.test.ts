import test from "node:test";
import assert from "node:assert/strict";
import { matchesConversation, needsAttention, customerName, formatMessageTime, MANAGING_ROLES } from "../src/lib/inbox.js";

const active = { customer_name: "Khaled Anik", customer_phone: "01712345678", channel: "facebook", external_customer_id: "psid-123", status: "active", needs_attention: false };

test("search handles names phone formatting IDs and Bengali text", () => {
  for (const search of ["ANIK", "017 123-45678", "psid-123", "facebook", ""]) assert.equal(matchesConversation(active, search), true);
  assert.equal(matchesConversation(active, "unknown"), false);
  assert.equal(matchesConversation({ ...active, customer_name: "খালেদ" }, "খালেদ"), true);
});

test("filters keep closed conversations out of Assistant and classify handovers", () => {
  assert.equal(matchesConversation(active, "", "assistant"), true);
  assert.equal(matchesConversation(active, "", "needs_you"), false);
  assert.equal(matchesConversation({ ...active, status: "closed" }, "", "assistant"), false);
  assert.equal(matchesConversation({ ...active, status: "closed" }, "", "all"), true);
  assert.equal(needsAttention({ ...active, status: "handed_over" }), true);
});

test("identity and timestamps have honest missing-data fallbacks", () => {
  assert.equal(customerName({ channel: "facebook" }), "Messenger customer");
  assert.equal(customerName(null), "Customer");
  assert.equal(formatMessageTime(null), "");
  assert.equal(formatMessageTime("invalid"), "");
  assert.ok(!MANAGING_ROLES.includes("analyst"));
  assert.ok(!MANAGING_ROLES.includes("fulfilment_agent"));
});
