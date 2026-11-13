import test from "node:test";
import assert from "node:assert/strict";
import { automationMessages } from "../src/locales/automation.js";

test("automation messages support the configured Bengali language and English fallback", () => {
  assert.equal(automationMessages("bengali").pause, "সব চ্যাটে AI বন্ধ করুন");
  assert.equal(automationMessages("bn").paused, automationMessages("bengali").paused);
  assert.equal(automationMessages("banglish").pause, "Pause AI for all chats");
  assert.match(automationMessages().help, /existing|this business/);
});
