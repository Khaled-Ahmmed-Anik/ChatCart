import test from "node:test";
import assert from "node:assert/strict";
import { requestFetch } from "../src/lib/requestFetch.js";

test("requests have a timeout signal and mutations are never automatically replayed", async () => {
  const original = globalThis.fetch;
  let calls = 0;
  globalThis.fetch = async (_input, options) => {
    calls += 1;
    assert.ok(options?.signal);
    throw new DOMException("Timed out", "TimeoutError");
  };
  try {
    await assert.rejects(requestFetch("https://example.test", { method: "POST" }), /check whether it was saved/);
    assert.equal(calls, 1);
  } finally {
    globalThis.fetch = original;
  }
});
