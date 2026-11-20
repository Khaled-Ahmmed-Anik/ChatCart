export const PRODUCT_MEDIA_KEY = "catalogue_media";
export const PRODUCT_LINKS_KEY = "reference_urls";
export const MAX_PRODUCT_MEDIA = 12;
export const MAX_MEDIA_ATTACHMENTS = 3;
export const MAX_MEDIA_VARIANT_LENGTH = 100;
export type ProductMedia = { url: string; kind: "image" | "video"; authenticity: "actual" | "promotional"; variant?: string };
export function readProductMedia(attributes: Record<string, unknown>): ProductMedia[] {
  const value = attributes[PRODUCT_MEDIA_KEY];
  return Array.isArray(value) ? value.filter((item): item is ProductMedia => Boolean(item && typeof item === "object" && typeof item.url === "string" && ["image", "video"].includes(item.kind) && ["actual", "promotional"].includes(item.authenticity) && (item.variant == null || typeof item.variant === "string"))) : [];
}
export function ordinaryProductAttributes(attributes: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(attributes).filter(([key]) => ![PRODUCT_MEDIA_KEY, PRODUCT_LINKS_KEY].includes(key)));
}
