import { MAX_PRODUCT_MEDIA, MAX_MEDIA_VARIANT_LENGTH, type ProductMedia } from "../../lib/productMedia";
import { productMediaMessages } from "../../locales/productMedia";

type Props = { media: ProductMedia[]; onChange: (media: ProductMedia[]) => void; links: string; onLinksChange: (value: string) => void; language?: string };
export function ProductMediaFields({ media, onChange, links, onLinksChange, language }: Props) {
  const text = productMediaMessages(language);
  function update(index: number, values: Partial<ProductMedia>) { onChange(media.map((item, position) => position === index ? { ...item, ...values } : item)); }
  return <fieldset>
    <legend>{text.title}</legend><p className="muted">{text.help}</p>
    {media.map((item, index) => <div className="form-grid" key={index}>
      <label>{text.url}<input type="url" required value={item.url} onChange={event => update(index, { url: event.target.value })} /></label>
      <label>{text.kind}<select value={item.kind} onChange={event => update(index, { kind: event.target.value as ProductMedia["kind"] })}><option value="image">{text.image}</option><option value="video">{text.video}</option></select></label>
      <label>{text.authenticity}<select value={item.authenticity} onChange={event => update(index, { authenticity: event.target.value as ProductMedia["authenticity"] })}><option value="promotional">{text.promotional}</option><option value="actual">{text.actual}</option></select></label>
      <label>{text.variant}<input maxLength={MAX_MEDIA_VARIANT_LENGTH} value={item.variant || ""} placeholder={text.general} onChange={event => update(index, { variant: event.target.value })} /></label>
      <button type="button" className="button secondary" onClick={() => onChange(media.filter((_, position) => position !== index))}>{text.remove}</button>
    </div>)}
    <button type="button" className="button secondary" disabled={media.length >= MAX_PRODUCT_MEDIA} onClick={() => onChange([...media, { url: "", kind: "image", authenticity: "promotional" }])}>{text.add}</button>
    <label>{text.links}<small>{text.linksHelp}</small><textarea value={links} onChange={event => onLinksChange(event.target.value)} /></label>
  </fieldset>;
}
