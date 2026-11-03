import test from "node:test";
import assert from "node:assert/strict";
import { workspaceNavigation } from "../src/lib/navigation.js";

test("business redesign retains every existing business route", () => {
  const navigation = workspaceNavigation("business_user");
  assert.deepEqual(navigation.map(({ to }) => to).sort(), [
    "/app", "/app/conversations", "/app/knowledge", "/app/orders", "/app/products", "/app/settings"
  ]);
  assert.equal(navigation.find(({ to }) => to === "/app")?.end, true);
  assert.equal(new Set(navigation.map(({ to }) => to)).size, navigation.length);
});

test("platform navigation does not advertise unimplemented admin tools", () => {
  assert.deepEqual(workspaceNavigation("platform_administrator").map(({ to }) => to), ["/admin/businesses"]);
});
