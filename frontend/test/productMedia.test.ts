import assert from "node:assert/strict";
import test from "node:test";
import { ordinaryProductAttributes, readProductMedia } from "../src/lib/productMedia.ts";
import { productMediaMessages } from "../src/locales/productMedia.ts";

test("media is edited separately without destroying ordinary catalogue facts", () => {
  const media = { kind: "image", authenticity: "actual", url: "https://cdn.shop.test/photo.jpg", variant: "Black" };
  const attributes = { catalogue_media: [media], reference_urls: ["https://facebook.com/posts/1"], color: "black", catalogue_facts: { warranty: "One year" } };
  assert.deepEqual(readProductMedia(attributes), [media]);
  assert.deepEqual(ordinaryProductAttributes(attributes), { color: "black", catalogue_facts: { warranty: "One year" } });
  assert.equal(attributes.catalogue_media.length, 1);
});

test("malformed legacy metadata does not crash the media editor", () => {
  assert.deepEqual(readProductMedia({ catalogue_media: [null, "bad", {}, { kind: "image", authenticity: "invented", url: "a" }] }), []);
  assert.deepEqual(readProductMedia({ catalogue_media: "bad" }), []);
  assert.equal(productMediaMessages("bn").image, "ছবি");
  assert.equal(productMediaMessages("unknown").image, "Photo");
});
