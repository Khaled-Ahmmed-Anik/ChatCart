import { useId, useState } from "react";
import { ProductImage } from "./ProductImage";
import { safeProductImageUrl } from "../../lib/productImages";
import { productImageMessages } from "../../locales/productImages";

type Props = { value: string[]; onChange: (urls: string[]) => void; productName: string; language?: string };

export function ProductImagesField({ value, onChange, productName, language }: Props) {
  const [draft, setDraft] = useState("");
  const [error, setError] = useState("");
  const id = useId();
  const text = productImageMessages(language);

  function addImage() {
    const url = draft.trim();
    if (!safeProductImageUrl(url)) { setError(text.invalid); return; }
    if (value.includes(url)) { setError(text.duplicate); return; }
    onChange([...value, url]);
    setDraft("");
    setError("");
  }

  return <fieldset className="product-images-field">
    <legend>{text.title}</legend>
    <p id={`${id}-help`} className="muted">{text.help}</p>
    <div className="product-image-entry">
      <label htmlFor={id}>{text.url}<input id={id} type="url" value={draft}
        aria-describedby={`${id}-help${error ? ` ${id}-error` : ""}`} aria-invalid={Boolean(error)}
        onChange={event => { setDraft(event.target.value); setError(""); }}
        onKeyDown={event => { if (event.key === "Enter") { event.preventDefault(); addImage(); } }}
        placeholder="https://example.com/product.jpg" /></label>
      <button type="button" className="button secondary" onClick={addImage}>{text.add}</button>
    </div>
    {error && <p id={`${id}-error`} role="alert" className="form-error">{error}</p>}
    <ul className="product-image-gallery">{value.map((url, index) => <li key={`${url}-${index}`}>
      <ProductImage url={url} productName={productName} language={language} />
      <span className="product-image-url">{url}</span>
      {index === 0 ? <strong>{text.cover}</strong> : <button type="button" className="button secondary small"
        onClick={() => onChange([url, ...value.filter((_, position) => position !== index)])}>{text.makeCover}</button>}
      <button type="button" className="button secondary small" onClick={() => onChange(value.filter((_, position) => position !== index))}>{text.remove}</button>
    </li>)}</ul>
  </fieldset>;
}
