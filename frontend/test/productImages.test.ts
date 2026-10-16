import assert from "node:assert/strict";
import test from "node:test";
import { safeProductImageUrl } from "../src/lib/productImages.ts";
import { productImageMessages } from "../src/locales/productImages.ts";

test("allows HTTPS image links including signed query parameters", () => {
  const url = "https://cdn.example.com/product.jpg?signature=test&width=500";
  assert.equal(safeProductImageUrl(url), url);
});

test("blocks unsafe schemes, credentials, custom ports and local literals", () => {
  for (const url of [undefined, "", "not a URL", "http://cdn.example.com/a.jpg", "javascript:alert(1)",
    "data:image/png;base64,AAAA", "https://user:secret@cdn.example.com/a.jpg", "https://cdn.example.com:8443/a.jpg",
    "https://127.0.0.1/a.jpg", "https://[::1]/a.jpg", "https://localhost/a.jpg", "https://images.local/a.jpg"]) {
    assert.equal(safeProductImageUrl(url), undefined, String(url));
  }
});

test("image messages support Bangla with an English fallback", () => {
  assert.equal(productImageMessages("bn").title, "পণ্যের ছবি");
  assert.equal(productImageMessages("unknown").title, "Product images");
  assert.equal(productImageMessages("en").imageAlt("Cotton Shirt"), "Cotton Shirt product image");
});
