import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { DataTable } from "../../components/ui/DataTable";
import { ErrorState, LoadingState } from "../../components/ui/Feedback";
import { Modal } from "../../components/ui/Modal";
import { PageHeader } from "../../components/ui/PageHeader";
import { Panel } from "../../components/ui/Panel";
import {
  DashboardProductsDocument,
  SaveDashboardProductDocument,
  type DashboardProductsQuery,
  type ProductInput
} from "../../graphql/generated/graphql";
import { graphqlRequest } from "../../lib/graphqlClient";

type Product = DashboardProductsQuery["products"][number];

export function ProductsPage() {
  const [editing, setEditing] = useState<Product | null>(null);
  const [open, setOpen] = useState(false);
  const client = useQueryClient();
  const query = useQuery({
    queryKey: ["products"],
    queryFn: () => graphqlRequest(DashboardProductsDocument, { first: 100 })
  });
  const save = useMutation({
    mutationFn: async ({ id, input }: { id?: string; input: ProductInput }) => {
      const result = await graphqlRequest(SaveDashboardProductDocument, { id, input });
      const payload = result.saveProduct;
      if (!payload || payload.errors.length) throw new Error(payload?.errors.join(", ") || "Unable to save product");
      return payload.product;
    },
    onSuccess: () => {
      client.invalidateQueries({ queryKey: ["products"] });
      setOpen(false);
      setEditing(null);
    }
  });
  if (query.isLoading) return <LoadingState />;
  if (query.isError) return <ErrorState error={query.error} />;

  const edit = (product: Product) => { setEditing(product); setOpen(true); };
  const columns = [
    { key: "name", label: "Product", render: (row: Product) => <div><strong>{row.name}</strong><small>{row.description || "No description"}</small></div> },
    { key: "price", label: "Price", render: (row: Product) => `${row.price} BDT` },
    { key: "stockQuantity", label: "Stock" },
    { key: "active", label: "Visibility", render: (row: Product) => <span className={`status ${row.active ? "active" : "cancelled"}`}>{row.active ? "Active" : "Inactive"}</span> },
    { key: "actions", label: "", render: (row: Product) => <button className="button secondary small" onClick={() => edit(row)}>Edit</button> }
  ];

  function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const values = Object.fromEntries(new FormData(form));
    save.mutate({
      id: editing?.id,
      input: {
        name: String(values.name),
        price: String(values.price),
        stockQuantity: Number(values.stock_quantity),
        description: String(values.description || ""),
        tags: String(values.tags || ""),
        active: (form.elements.namedItem("active") as HTMLInputElement).checked
      }
    });
  }

  return <>
    <PageHeader title="Products" description="The catalog and facts used during sales conversations." actions={<button onClick={() => { setEditing(null); setOpen(true); }}>Add product</button>} />
    <Panel><DataTable columns={columns} rows={query.data!.products} emptyMessage="Add a product to start taking orders." /></Panel>
    <Modal title={editing ? "Edit product" : "Add product"} open={open} onClose={() => { setOpen(false); setEditing(null); }}>
      <form key={editing?.id || "new"} onSubmit={submit}>
        <label>Product name<input name="name" defaultValue={editing?.name} required /></label>
        <div className="form-grid">
          <label>Price<input name="price" type="number" min="0" step="0.01" defaultValue={editing?.price} required /></label>
          <label>Stock quantity<input name="stock_quantity" type="number" min="0" defaultValue={editing?.stockQuantity} required /></label>
        </div>
        <label>Description<textarea name="description" defaultValue={editing?.description || ""} /></label>
        <label>Tags<input name="tags" defaultValue={editing?.tags || ""} /></label>
        <label className="checkbox"><input name="active" type="checkbox" defaultChecked={editing?.active ?? true} />Visible to customers</label>
        {save.error && <p className="form-error">{save.error.message}</p>}
        <div className="form-actions"><button type="button" className="button secondary" onClick={() => setOpen(false)}>Cancel</button><button disabled={save.isPending}>{save.isPending ? "Saving…" : "Save product"}</button></div>
      </form>
    </Modal>
  </>;
}
