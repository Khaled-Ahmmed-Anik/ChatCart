import { safeProductImageUrl } from "../../lib/productImages";
import { productMediaMessages } from "../../locales/productMedia";
import { MAX_MEDIA_ATTACHMENTS } from "../../lib/productMedia";

export function MessageMedia({ attachments, language }: { attachments: unknown; language?: string }) {
  if (!Array.isArray(attachments)) return null;
  const text = productMediaMessages(language);
  return <div>{attachments.slice(0, MAX_MEDIA_ATTACHMENTS).map((item, index) => {
    if (!item || typeof item.url !== "string") return null;
    const url = safeProductImageUrl(item.url);
    if (!url) return null;
    if (item.type === "image") return <a key={index} href={url} target="_blank" rel="noreferrer"><img src={url} loading="lazy" referrerPolicy="no-referrer" alt={text.image} style={{ maxWidth: "100%", maxHeight: 240 }} /></a>;
    if (item.type === "video") return <video key={index} src={url} controls preload="none" aria-label={text.video} style={{ maxWidth: "100%", maxHeight: 240 }} />;
    return null;
  })}</div>;
}
