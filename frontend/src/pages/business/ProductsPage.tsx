import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { DataTable } from "../../components/ui/DataTable";
import { ErrorState, LoadingState } from "../../components/ui/Feedback";
import { Modal } from "../../components/ui/Modal";
import { PageHeader } from "../../components/ui/PageHeader";
import { Panel } from "../../components/ui/Panel";
import { ApproveDashboardProductImportDocument, ArchiveDashboardProductDocument, DashboardProductsDocument, PreviewDashboardProductImportDocument, SaveDashboardProductDocument, type DashboardProductsQuery, type ProductInput } from "../../graphql/generated/graphql";
import { graphqlRequest } from "../../lib/graphqlClient";
import { parseProductAttributes, formatProductAttributes } from "../../lib/productAttributes";

type Product = DashboardProductsQuery["products"][number];
type Variant = Product["variants"][number];
type VariantDraft = Omit<Variant, "id"> & { id?: string };
type ComboDraft = { id?: string; componentProductId: string; quantity: number; selectionGroup?: string; required: boolean; position: number };
const blankVariant = (): VariantDraft => ({ name: "", size: "", sku: "", price: "", stockQuantity: 0, active: true, position: 0 });

export function ProductsPage() {
  const [editing, setEditing] = useState<Product | null>(null);
  const [open, setOpen] = useState(false);
  const [variants, setVariants] = useState<VariantDraft[]>([]);
  const [comboItems, setComboItems] = useState<ComboDraft[]>([]);
  const [importOpen, setImportOpen] = useState(false);
  const [importDraft, setImportDraft] = useState<{id:string; extractedData:unknown; errors:string[]} | null>(null);
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
  const archive = useMutation({mutationFn: async ({id,permanent}:{id:string;permanent:boolean}) => {
    const result=await graphqlRequest(ArchiveDashboardProductDocument,{id,permanent}); const payload=result.archiveProduct;
    if(!payload||payload.errors.length)throw new Error(payload?.errors.join(", ")||"Unable to remove product"); return payload;
  },onSuccess:()=>client.invalidateQueries({queryKey:["products"]})});
  const previewImport=useMutation({mutationFn:async(url:string)=>{const result=await graphqlRequest(PreviewDashboardProductImportDocument,{url});const payload=result.previewProductImport;if(!payload?.draft)throw new Error(payload?.errors.join(", ")||"Import failed");return {id:payload.draft.id,extractedData:payload.draft.extractedData,errors:payload.errors};},onSuccess:setImportDraft});
  const approveImport=useMutation({mutationFn:async(draftId:string)=>{const result=await graphqlRequest(ApproveDashboardProductImportDocument,{draftId});const payload=result.approveProductImport;if(!payload?.product||payload.errors.length)throw new Error(payload?.errors.join(", ")||"Approval failed");return payload.product;},onSuccess:()=>{client.invalidateQueries({queryKey:["products"]});setImportOpen(false);setImportDraft(null);}});
  if (query.isLoading) return <LoadingState />;
  if (query.isError) return <ErrorState error={query.error} />;

  const edit = (product: Product) => { setEditing(product); setVariants(product.variants); setComboItems(product.comboItems.map(item=>({id:item.id,componentProductId:item.componentProduct.id,quantity:item.quantity,selectionGroup:item.selectionGroup||undefined,required:item.required,position:item.position}))); setOpen(true); };
  const updateVariant = (index: number, values: Partial<VariantDraft>) => setVariants(current => current.map((item, itemIndex) => itemIndex === index ? { ...item, ...values } : item));
  const columns = [
    { key: "name", label: "Product", render: (row: Product) => <div><strong>{row.name}</strong><small>{row.shortDescription || row.description || "No description"}</small></div> },
    { key: "price", label: "Price", render: (row: Product) => row.variants.length ? `${Math.min(...row.variants.map(v => Number(v.price)))}–${Math.max(...row.variants.map(v => Number(v.price)))} BDT` : `${row.price} BDT` },
    { key: "stockQuantity", label: "Stock", render: (row: Product) => row.variants.length ? row.variants.reduce((sum, variant) => sum + variant.stockQuantity, 0) : row.stockQuantity },
    { key: "variants", label: "Options", render: (row: Product) => row.variants.length || "Single" },
    { key: "active", label: "Visibility", render: (row: Product) => <span className={`status ${row.active ? "active" : "cancelled"}`}>{row.active ? "Active" : "Inactive"}</span> },
    { key: "actions", label: "", render: (row: Product) => <div className="actions"><button className="button secondary small" onClick={() => edit(row)}>Edit</button><button className="button secondary small" onClick={()=>archive.mutate({id:row.id,permanent:false})}>Archive</button><button className="button secondary small" onClick={()=>window.confirm(`Permanently delete ${row.name}?`)&&archive.mutate({id:row.id,permanent:true})}>Delete</button></div> }
  ];

  function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const values = Object.fromEntries(new FormData(form));
    const productAttributes = parseProductAttributes(String(values.product_attributes || ""));
    save.mutate({ id: editing?.id, input: {
      name: String(values.name), price: String(values.price), stockQuantity: Number(values.stock_quantity),
      description: String(values.description || ""), shortDescription: String(values.short_description || ""),
      category: String(values.category || ""), benefits: String(values.benefits || ""),
      usageInstructions: String(values.usage_instructions || ""), suitableFor: String(values.suitable_for || ""),
      productAttributes, tags: String(values.tags || ""), active: (form.elements.namedItem("active") as HTMLInputElement).checked,
      productType: String(values.product_type), stockStrategy: String(values.stock_strategy),
      aliases: String(values.aliases||"").split(",").map(value=>value.trim()).filter(Boolean),
      sourceUrl: String(values.source_url||""),
      variants: variants.filter(variant => variant.name && variant.price !== "").map((variant, position) => ({ ...variant, position })),
      comboItems: comboItems.filter(item=>item.componentProductId).map((item,position)=>({...item,position}))
    } });
  }

  return <>
    <PageHeader title="Products" description="The catalog, variants, combos, aliases, and verified facts used for recommendations." actions={<><button className="button secondary" onClick={()=>{setImportDraft(null);setImportOpen(true)}}>Import from URL</button><button onClick={() => { setEditing(null); setVariants([]); setComboItems([]); setOpen(true); }}>Add product</button></>} />
    <Panel><DataTable columns={columns} rows={query.data!.products} emptyMessage="Add a product to start taking orders." /></Panel>
    <Modal title={editing ? "Edit product" : "Add product"} open={open} onClose={() => { setOpen(false); setEditing(null); }}>
      <form key={editing?.id || "new"} onSubmit={submit}>
        <label>Product name<input name="name" defaultValue={editing?.name} required /></label>
        <label>Aliases <small>Comma-separated English, Bangla, or Banglish names</small><input name="aliases" defaultValue={editing?.aliases.join(", ")||""} placeholder="Club, TheClub, ক্লাব" /></label>
        <div className="form-grid"><label>Product type<select name="product_type" defaultValue={editing?.productType||"standard"}><option value="standard">Standard product</option><option value="fixed_combo">Fixed combo</option><option value="configurable_combo">Configurable combo</option></select></label><label>Stock strategy<select name="stock_strategy" defaultValue={editing?.stockStrategy||"independent"}><option value="independent">Independent stock</option><option value="component_derived">Derived from components</option><option value="manual">Manual availability</option></select></label></div>
        <div className="form-grid"><label>Category<input name="category" defaultValue={editing?.category || ""} placeholder="Fragrance" /></label><label>Tags<input name="tags" defaultValue={editing?.tags || ""} placeholder="oud, woody, premium" /></label><label>Base price<input name="price" type="number" min="0" step="0.01" defaultValue={editing?.price} required /></label><label>Base stock<input name="stock_quantity" type="number" min="0" defaultValue={editing?.stockQuantity} required /></label></div>
        <label>Short description<textarea name="short_description" defaultValue={editing?.shortDescription || ""} /></label>
        <label>Long description<textarea name="description" defaultValue={editing?.description || ""} /></label>
        <div className="form-grid"><label>Benefits<textarea name="benefits" defaultValue={editing?.benefits || ""} /></label><label>Suitable for<textarea name="suitable_for" defaultValue={editing?.suitableFor || ""} /></label></div>
        <label>Usage instructions<textarea name="usage_instructions" defaultValue={editing?.usageInstructions || ""} /></label>
        <label>Product attributes <small>One key=value per line. Separate multiple values with |. Used to match customer preferences.</small><textarea name="product_attributes" defaultValue={formatProductAttributes((editing?.productAttributes as Record<string,unknown>) || {})} placeholder={"material=cotton\ncolor=blue | white\npurpose=office"} /></label>
        <div className="variant-heading"><div><strong>Sizes and variants</strong><small>Variant price and stock override the base values.</small></div><button type="button" className="button secondary small" onClick={() => setVariants(current => [...current, blankVariant()])}>Add variant</button></div>
        <div className="variant-list">{variants.map((variant,index) => <div className="variant-row" key={variant.id || index}><input aria-label="Variant name" placeholder="Name" value={variant.name} onChange={event => updateVariant(index,{name:event.target.value})}/><input aria-label="Variant size" placeholder="Size (6 ml)" value={variant.size || ""} onChange={event => updateVariant(index,{size:event.target.value})}/><input aria-label="Variant price" placeholder="Price" type="number" min="0" value={variant.price} onChange={event => updateVariant(index,{price:event.target.value})}/><input aria-label="Variant stock" placeholder="Stock" type="number" min="0" value={variant.stockQuantity} onChange={event => updateVariant(index,{stockQuantity:Number(event.target.value)})}/><button type="button" className="button secondary small" onClick={() => setVariants(current => current.filter((_,i) => i !== index))}>Remove</button></div>)}</div>
        <div className="variant-heading"><div><strong>Combo components</strong><small>Add the products included in a fixed or configurable combo.</small></div><button type="button" className="button secondary small" onClick={()=>setComboItems(current=>[...current,{componentProductId:"",quantity:1,required:true,position:current.length}])}>Add component</button></div>
        <div className="variant-list">{comboItems.map((item,index)=><div className="combo-row" key={item.id||index}><select value={item.componentProductId} onChange={event=>setComboItems(current=>current.map((entry,i)=>i===index?{...entry,componentProductId:event.target.value}:entry))}><option value="">Choose product</option>{query.data!.products.filter(product=>product.id!==editing?.id).map(product=><option key={product.id} value={product.id}>{product.name}</option>)}</select><input aria-label="Component quantity" type="number" min="1" value={item.quantity} onChange={event=>setComboItems(current=>current.map((entry,i)=>i===index?{...entry,quantity:Number(event.target.value)}:entry))}/><input aria-label="Selection group" placeholder="Selection group (optional)" value={item.selectionGroup||""} onChange={event=>setComboItems(current=>current.map((entry,i)=>i===index?{...entry,selectionGroup:event.target.value}:entry))}/><button type="button" className="button secondary small" onClick={()=>setComboItems(current=>current.filter((_,i)=>i!==index))}>Remove</button></div>)}</div>
        <label>Source URL<input name="source_url" type="url" defaultValue={editing?.sourceUrl||""}/></label>
        <label className="checkbox"><input name="active" type="checkbox" defaultChecked={editing?.active ?? true} />Visible to customers</label>
        {save.error && <p className="form-error">{save.error.message}</p>}
        <div className="form-actions"><button type="button" className="button secondary" onClick={() => setOpen(false)}>Cancel</button><button disabled={save.isPending}>{save.isPending ? "Saving…" : "Save product"}</button></div>
      </form>
    </Modal>
    <Modal title="Import product from URL" open={importOpen} onClose={()=>setImportOpen(false)}>{!importDraft?<form onSubmit={event=>{event.preventDefault();previewImport.mutate(String(new FormData(event.currentTarget).get("url")))}}><label>Public product URL<input name="url" type="url" required placeholder="https://example.com/product/..."/></label>{previewImport.error&&<p className="form-error">{previewImport.error.message}</p>}<div className="form-actions"><button disabled={previewImport.isPending}>{previewImport.isPending?"Reading product…":"Create review preview"}</button></div></form>:<div className="import-preview"><p className="muted">Review the extracted data. The imported product will remain inactive until you verify its prices, stock, variants, and content.</p><pre>{JSON.stringify(importDraft.extractedData,null,2)}</pre>{importDraft.errors.map(error=><p className="form-error" key={error}>{error}</p>)}{approveImport.error&&<p className="form-error">{approveImport.error.message}</p>}<div className="form-actions"><button className="button secondary" onClick={()=>setImportDraft(null)}>Back</button><button disabled={approveImport.isPending} onClick={()=>approveImport.mutate(importDraft.id)}>{approveImport.isPending?"Importing…":"Approve draft"}</button></div></div>}</Modal>
  </>;
}
