import { useState } from "react";
import { safeProductImageUrl } from "../../lib/productImages";
import { productImageMessages } from "../../locales/productImages";

type Props = { url?: string; productName: string; language?: string };

export function ProductImage({ url, productName, language }: Props) {
  const [failedUrl, setFailedUrl] = useState<string>();
  const source = safeProductImageUrl(url);
  const text = productImageMessages(language);
  if (!source || failedUrl === source) {
    return <span className="product-image-placeholder" role="img" aria-label={url ? text.unavailable : text.empty}>—</span>;
  }
  return <img className="product-image" src={source} alt={text.imageAlt(productName)}
    loading="lazy" decoding="async" referrerPolicy="no-referrer" onError={() => setFailedUrl(source)} />;
}
