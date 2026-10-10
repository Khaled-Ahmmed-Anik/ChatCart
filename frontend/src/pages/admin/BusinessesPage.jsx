import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiRequest } from "../../lib/apiClient";
import { DataTable } from "../../components/ui/DataTable";
import { ErrorState, LoadingState } from "../../components/ui/Feedback";
import { Modal } from "../../components/ui/Modal";
import { PageHeader } from "../../components/ui/PageHeader";
import { Panel } from "../../components/ui/Panel";

const STATUS_ACTIONS = {
  active: ["suspended", "disabled"],
  suspended: ["active", "disabled"],
  disabled: ["active"],
};

const STATUS_LABELS = {
  active: "Reactivate",
  suspended: "Suspend",
  disabled: "Disable",
};

export function BusinessesPage() {
  const [createOpen, setCreateOpen] = useState(false);
  const [statusChange, setStatusChange] = useState(null);
  const client = useQueryClient();
  const query = useQuery({ queryKey: ["businesses"], queryFn: () => apiRequest("/admin/businesses") });
  const create = useMutation({
    mutationFn: (payload) => apiRequest("/admin/businesses", { method: "POST", body: JSON.stringify(payload) }),
    onSuccess: () => {
      client.invalidateQueries({ queryKey: ["businesses"] });
      setCreateOpen(false);
    },
  });
  const updateStatus = useMutation({
    mutationFn: ({ business, status }) => apiRequest(`/admin/businesses/${business.id}`, {
      method: "PATCH",
      body: JSON.stringify({ business: { status } }),
    }),
    onSuccess: () => {
      client.invalidateQueries({ queryKey: ["businesses"] });
      setStatusChange(null);
    },
  });

  if (query.isLoading) return <LoadingState />;
  if (query.isError) return <ErrorState error={query.error} />;

  const columns = [
    { key: "name", label: "Business", render: (row) => <div><strong>{row.name}</strong><small>{row.slug}</small></div> },
    { key: "category", label: "Category" },
    { key: "default_language", label: "Language" },
    { key: "status", label: "Status", render: (row) => <span className={`status ${row.status}`}>{row.status}</span> },
    { key: "created_at", label: "Created", render: (row) => new Date(row.created_at).toLocaleDateString() },
    {
      key: "actions",
      label: "Actions",
      render: (row) => <div className="actions">{STATUS_ACTIONS[row.status].map((status) => (
        <button
          className={status === "disabled" ? "button danger small" : "button secondary small"}
          key={status}
          onClick={() => setStatusChange({ business: row, status })}
          type="button"
        >
          {STATUS_LABELS[status]}
        </button>
      ))}</div>,
    },
  ];

  function submit(event) {
    event.preventDefault();
    const values = Object.fromEntries(new FormData(event.currentTarget));
    create.mutate({
      business: {
        name: values.name,
        slug: values.slug,
        category: values.category,
        default_language: values.default_language,
        timezone: "Asia/Dhaka",
        currency: "BDT",
      },
      owner: { name: values.owner_name, email: values.owner_email, password: values.owner_password },
    });
  }

  const stopsAccess = statusChange?.status !== "active";

  return <>
    <PageHeader
      eyebrow="Platform administration"
      title="Businesses"
      description="Create and control isolated merchant workspaces."
      actions={<button onClick={() => setCreateOpen(true)}>Add business</button>}
    />
    <Panel>
      <DataTable columns={columns} rows={query.data} emptyMessage="Create the first business workspace." />
    </Panel>
    <Modal title="Create business" open={createOpen} onClose={() => setCreateOpen(false)}>
      <form onSubmit={submit}>
        <div className="form-grid">
          <label>Business name<input name="name" required /></label>
          <label>URL slug<input name="slug" pattern="[a-z0-9-]+" required /></label>
          <label>Category<input name="category" required /></label>
          <label>Default language<select name="default_language"><option value="banglish">Banglish</option><option value="english">English</option><option value="bengali">Bengali</option></select></label>
        </div>
        <h3>First owner</h3>
        <div className="form-grid">
          <label>Name<input name="owner_name" required /></label>
          <label>Email<input name="owner_email" type="email" required /></label>
          <label className="full">Temporary password<input name="owner_password" type="password" minLength="12" required /></label>
        </div>
        {create.error && <p className="form-error">{create.error.message}</p>}
        <div className="form-actions">
          <button type="button" className="button secondary" onClick={() => setCreateOpen(false)}>Cancel</button>
          <button disabled={create.isPending}>{create.isPending ? "Creating…" : "Create business"}</button>
        </div>
      </form>
    </Modal>
    <Modal
      title={`${STATUS_LABELS[statusChange?.status] || "Change"} business`}
      open={Boolean(statusChange)}
      onClose={() => setStatusChange(null)}
    >
      <p>
        {stopsAccess
          ? `${STATUS_LABELS[statusChange?.status]} ${statusChange?.business.name}? All business users will be signed out immediately and automated messaging will stop. Existing data will be retained.`
          : `Reactivate ${statusChange?.business.name}? Users must sign in again; previously revoked sessions will remain invalid.`}
      </p>
      {updateStatus.error && <p className="form-error">{updateStatus.error.message}</p>}
      <div className="form-actions">
        <button type="button" className="button secondary" onClick={() => setStatusChange(null)}>Cancel</button>
        <button
          type="button"
          className={statusChange?.status === "disabled" ? "button danger" : "button"}
          disabled={updateStatus.isPending}
          onClick={() => updateStatus.mutate(statusChange)}
        >
          {updateStatus.isPending ? "Updating…" : "Confirm"}
        </button>
      </div>
    </Modal>
  </>;
}
