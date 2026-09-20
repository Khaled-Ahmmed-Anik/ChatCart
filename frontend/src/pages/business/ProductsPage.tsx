import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { DataTable } from "../../components/ui/DataTable";
import { ErrorState, LoadingState } from "../../components/ui/Feedback";
import { Modal } from "../../components/ui/Modal";
import { PageHeader } from "../../components/ui/PageHeader";
import { Panel } from "../../components/ui/Panel";
import { DashboardProductsDocument, SaveDashboardProductDocument, type DashboardProductsQuery, type ProductInput } from "../../graphql/generated/graphql";
import { graphqlRequest } from "../../lib/graphqlClient";

type Product = DashboardProductsQuery["products"][number];
type Variant = Product["variants"][number];
type VariantDraft = Omit<Variant, "id"> & { id?: string };
const blankVariant = (): VariantDraft => ({ name: "", size: "", sku: "", price: "", stockQuantity: 0, active: true, position: 0 });

export function ProductsPage() {
  const [editing, setEditing] = useState<Product | null>(null);
  const [open, setOpen] = useState(false);
  const [variants, setVariants] = useState<VariantDraft[]>([]);
  const client = useQueryClient();
  const query = useQuery({ queryKey: ["products"], queryFn: () => graphqlRequest(DashboardProductsDocument, { first: 100 }) });
  const save = useMutation({
    mutationFn: async ({ id, input }: { id?: string; input: ProductInput }) => {
      const result = await graphqlRequest(SaveDashboardProductDocument, { id, input });
      const payload = result.saveProduct;
      if (!payload || payload.errors.length) throw new Error(payload?.errors.join(", ") || "Unable to save product");
      return payload.product;
    },
    onSuccess: () => { client.invalidateQueries({ queryKey: ["products"] }); setOpen(false); setEditing(null); }
  });
  if (query.isLoading) return <LoadingState />;
  if (query.isError) return <ErrorState error={query.error} />;

  const edit = (product: Product) => { setEditing(product); setVariants(product.variants); setOpen(true); };
  const updateVariant = (index: number, values: Partial<VariantDraft>) => setVariants(current => current.map((item, itemIndex) => itemIndex === index ? { ...item, ...values } : item));
  const columns = [
    { key: "name", label: "Product", render: (row: Product) => <div><strong>{row.name}</strong><small>{row.shortDescription || row.description || "No description"}</small></div> },
    { key: "price", label: "Price", render: (row: Product) => row.variants.length ? `${Math.min(...row.variants.map(v => Number(v.price)))}–${Math.max(...row.variants.map(v => Number(v.price)))} BDT` : `${row.price} BDT` },
    { key: "stockQuantity", label: "Stock", render: (row: Product) => row.variants.length ? row.variants.reduce((sum, variant) => sum + variant.stockQuantity, 0) : row.stockQuantity },
    { key: "variants", label: "Options", render: (row: Product) => row.variants.length || "Single" },
    { key: "active", label: "Visibility", render: (row: Product) => <span className={`status ${row.active ? "active" : "cancelled"}`}>{row.active ? "Active" : "Inactive"}</span> },
    { key: "actions", label: "", render: (row: Product) => <button className="button secondary small" onClick={() => edit(row)}>Edit</button> }
  ];

  function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const values = Object.fromEntries(new FormData(form));
    const productAttributes = Object.fromEntries(String(values.product_attributes || "").split("\n").map(line => line.split("=").map(part => part.trim())).filter(parts => parts.length === 2 && parts[0]));
    save.mutate({ id: editing?.id, input: {
      name: String(values.name), price: String(values.price), stockQuantity: Number(values.stock_quantity),
      description: String(values.description || ""), shortDescription: String(values.short_description || ""),
      category: String(values.category || ""), benefits: String(values.benefits || ""),
      usageInstructions: String(values.usage_instructions || ""), suitableFor: String(values.suitable_for || ""),
      productAttributes, tags: String(values.tags || ""), active: (form.elements.namedItem("active") as HTMLInputElement).checked,
      variants: variants.filter(variant => variant.name && variant.price !== "").map((variant, position) => ({ ...variant, position }))
    } });
  }

  return <>
    <PageHeader title="Products" description="The catalog, variants, and verified facts used for recommendations." actions={<button onClick={() => { setEditing(null); setVariants([]); setOpen(true); }}>Add product</button>} />
    <Panel><DataTable columns={columns} rows={query.data!.products} emptyMessage="Add a product to start taking orders." /></Panel>
    <Modal title={editing ? "Edit product" : "Add product"} open={open} onClose={() => { setOpen(false); setEditing(null); }}>
      <form key={editing?.id || "new"} onSubmit={submit}>
        <label>Product name<input name="name" defaultValue={editing?.name} required /></label>
        <div className="form-grid"><label>Category<input name="category" defaultValue={editing?.category || ""} placeholder="Fragrance" /></label><label>Tags<input name="tags" defaultValue={editing?.tags || ""} placeholder="oud, woody, premium" /></label><label>Base price<input name="price" type="number" min="0" step="0.01" defaultValue={editing?.price} required /></label><label>Base stock<input name="stock_quantity" type="number" min="0" defaultValue={editing?.stockQuantity} required /></label></div>
        <label>Short description<textarea name="short_description" defaultValue={editing?.shortDescription || ""} /></label>
        <label>Long description<textarea name="description" defaultValue={editing?.description || ""} /></label>
        <div className="form-grid"><label>Benefits<textarea name="benefits" defaultValue={editing?.benefits || ""} /></label><label>Suitable for<textarea name="suitable_for" defaultValue={editing?.suitableFor || ""} /></label></div>
        <label>Usage instructions<textarea name="usage_instructions" defaultValue={editing?.usageInstructions || ""} /></label>
        <label>Additional facts <small>One key=value pair per line</small><textarea name="product_attributes" defaultValue={Object.entries((editing?.productAttributes as Record<string,string>) || {}).map(([key,value]) => `${key}=${value}`).join("\n")} placeholder={"longevity=8–10 hours\nfragrance_family=Woody"} /></label>
        <div className="variant-heading"><div><strong>Sizes and variants</strong><small>Variant price and stock override the base values.</small></div><button type="button" className="button secondary small" onClick={() => setVariants(current => [...current, blankVariant()])}>Add variant</button></div>
        <div className="variant-list">{variants.map((variant,index) => <div className="variant-row" key={variant.id || index}><input aria-label="Variant name" placeholder="Name" value={variant.name} onChange={event => updateVariant(index,{name:event.target.value})}/><input aria-label="Variant size" placeholder="Size (6 ml)" value={variant.size || ""} onChange={event => updateVariant(index,{size:event.target.value})}/><input aria-label="Variant price" placeholder="Price" type="number" min="0" value={variant.price} onChange={event => updateVariant(index,{price:event.target.value})}/><input aria-label="Variant stock" placeholder="Stock" type="number" min="0" value={variant.stockQuantity} onChange={event => updateVariant(index,{stockQuantity:Number(event.target.value)})}/><button type="button" className="button secondary small" onClick={() => setVariants(current => current.filter((_,i) => i !== index))}>Remove</button></div>)}</div>
        <label className="checkbox"><input name="active" type="checkbox" defaultChecked={editing?.active ?? true} />Visible to customers</label>
        {save.error && <p className="form-error">{save.error.message}</p>}
        <div className="form-actions"><button type="button" className="button secondary" onClick={() => setOpen(false)}>Cancel</button><button disabled={save.isPending}>{save.isPending ? "Saving…" : "Save product"}</button></div>
      </form>
    </Modal>
  </>;
}
