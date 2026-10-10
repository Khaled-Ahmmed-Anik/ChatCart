import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "../../auth/useAuth";
import { apiRequest } from "../../lib/apiClient";
import { ErrorState, LoadingState } from "../../components/ui/Feedback";
import { PageHeader } from "../../components/ui/PageHeader";
import { Panel } from "../../components/ui/Panel";

function KnowledgeStatus({ status }) {
  const cards = [
    ["Active sources", status.active],
    ["Manual FAQs", status.by_source?.manual || 0],
    ["Embedded", status.embedded],
    ["Awaiting embedding", status.awaiting_embedding]
  ];
  return <div className="metrics knowledge-metrics">
    {cards.map(([label, value]) => <Panel key={label} className="metric"><span>{label}</span><strong>{value}</strong></Panel>)}
  </div>;
}

function ManualKnowledgeForm({ document, onSaved, onCancel }) {
  const mutation = useMutation({
    mutationFn: (payload) => apiRequest(document ? `/api/knowledge_documents/${document.id}` : "/api/knowledge_documents", {
      method: document ? "PATCH" : "POST",
      body: JSON.stringify({ knowledge_document: payload })
    }),
    onSuccess: onSaved
  });

  function submit(event) {
    event.preventDefault();
    const form = event.currentTarget;
    const values = Object.fromEntries(new FormData(form));
    values.active = form.elements.active.checked;
    mutation.mutate(values);
  }

  return <form key={document?.id || "new"} onSubmit={submit} className="knowledge-form">
    <label>Question or topic<input name="title" defaultValue={document?.title || ""} required placeholder="Do you offer gift wrapping?" /></label>
    <label>Approved answer<textarea name="content" defaultValue={document?.content || ""} required placeholder="Yes. Gift wrapping is available for…" /></label>
    <label className="checkbox"><input name="active" type="checkbox" defaultChecked={document?.active ?? true} />Available to the assistant</label>
    {mutation.error && <p className="form-error">{mutation.error.message}</p>}
    <div className="form-actions">
      {document && <button type="button" className="button secondary" onClick={onCancel}>Cancel</button>}
      <button disabled={mutation.isPending}>{mutation.isPending ? "Saving…" : document ? "Save FAQ" : "Add FAQ"}</button>
    </div>
  </form>;
}

function RetrievalPreview() {
  const [query, setQuery] = useState("");
  const preview = useMutation({
    mutationFn: (value) => apiRequest(`/api/knowledge_documents/preview?query=${encodeURIComponent(value)}`)
  });

  function submit(event) {
    event.preventDefault();
    preview.mutate(query);
  }

  return <Panel title="Assistant knowledge preview">
    <p className="muted">Test what the assistant can retrieve before a customer asks.</p>
    <form onSubmit={submit} className="preview-query">
      <label>Customer question<input value={query} onChange={(event) => setQuery(event.target.value)} required placeholder="How long does delivery take?" /></label>
      <button disabled={preview.isPending}>{preview.isPending ? "Searching…" : "Test retrieval"}</button>
    </form>
    {preview.error && <p className="form-error">{preview.error.message}</p>}
    {preview.data && <div className="knowledge-results">
      {preview.data.results.length === 0 && <p className="muted">No matching knowledge found. Add an FAQ or improve the source information.</p>}
      {preview.data.results.map((result) => <article key={result.citation.knowledge_document_id}>
        <strong>{result.citation.title}</strong>
        <span className="status">{result.citation.source_type.replaceAll("_", " ")}</span>
        <p>{result.content}</p>
        <small>Match score: {result.score}</small>
      </article>)}
    </div>}
  </Panel>;
}

export function KnowledgePage() {
  const { auth } = useAuth();
  const client = useQueryClient();
  const [editing, setEditing] = useState(null);
  const documents = useQuery({ queryKey: ["knowledge-documents"], queryFn: () => apiRequest("/api/knowledge_documents") });
  const status = useQuery({ queryKey: ["knowledge-status"], queryFn: () => apiRequest("/api/knowledge_documents/status") });
  const canManage = ["owner", "admin"].includes(auth.actor?.role);
  const refresh = () => {
    client.invalidateQueries({ queryKey: ["knowledge-documents"] });
    client.invalidateQueries({ queryKey: ["knowledge-status"] });
    setEditing(null);
  };
  const sync = useMutation({ mutationFn: () => apiRequest("/api/knowledge_documents/sync", { method: "POST" }), onSuccess: refresh });
  const remove = useMutation({
    mutationFn: (id) => apiRequest(`/api/knowledge_documents/${id}`, { method: "DELETE" }), onSuccess: refresh
  });
  const reindex = useMutation({
    mutationFn: (id) => apiRequest(`/api/knowledge_documents/${id}/reindex`, { method: "POST" }), onSuccess: refresh
  });

  if (documents.isLoading || status.isLoading) return <LoadingState />;
  if (documents.error || status.error) return <ErrorState error={documents.error || status.error} />;
  const manualDocuments = documents.data.filter((document) => document.source_type === "manual");

  function deleteDocument(document) {
    if (window.confirm(`Delete “${document.title}”?`)) remove.mutate(document.id);
  }

  return <>
    <PageHeader title="Business knowledge" description="Control the approved facts and FAQs used to ground assistant answers."
      actions={canManage && <button onClick={() => sync.mutate()} disabled={sync.isPending}>{sync.isPending ? "Syncing…" : "Sync product & policy facts"}</button>} />
    <KnowledgeStatus status={status.data} />
    {!status.data.embeddings_enabled && <p className="knowledge-notice">Semantic embeddings are off. Keyword retrieval remains active and free.</p>}
    <div className="content-grid knowledge-grid">
      <Panel title={editing ? "Edit manual FAQ" : "Add manual FAQ"}>
        {canManage ? <ManualKnowledgeForm document={editing} onSaved={refresh} onCancel={() => setEditing(null)} />
          : <p className="muted">Only owners and administrators can change approved knowledge.</p>}
      </Panel>
      <RetrievalPreview />
    </div>
    <Panel title="Knowledge sources">
      <div className="table-wrap"><table><thead><tr><th>Source</th><th>Title</th><th>Index state</th><th>Updated</th><th></th></tr></thead>
        <tbody>{documents.data.map((document) => <tr key={document.id}>
          <td><span className="status">{document.source_type.replaceAll("_", " ")}</span></td>
          <td><strong>{document.title}</strong><small>{document.content.slice(0, 120)}{document.content.length > 120 ? "…" : ""}</small></td>
          <td><span className={`status ${document.active ? "active" : "disabled"}`}>{document.active ? document.embedded ? "embedded" : "keyword ready" : "inactive"}</span></td>
          <td>{new Date(document.updated_at).toLocaleString()}</td>
          <td><div className="actions">
            {canManage && <button className="button small secondary" onClick={() => reindex.mutate(document.id)}>Re-index</button>}
            {canManage && document.editable && <button className="button small secondary" onClick={() => setEditing(document)}>Edit</button>}
            {canManage && document.editable && <button className="button small danger" onClick={() => deleteDocument(document)}>Delete</button>}
          </div></td>
        </tr>)}</tbody></table></div>
      {manualDocuments.length === 0 && <p className="muted">No manual FAQs yet. Add common customer questions above.</p>}
    </Panel>
  </>;
}
