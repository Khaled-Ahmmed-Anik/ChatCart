import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiRequest } from "../../lib/apiClient";
import { ErrorState, LoadingState } from "../../components/ui/Feedback";
import { PageHeader } from "../../components/ui/PageHeader";
import { Panel } from "../../components/ui/Panel";

function SettingsForm({ title, data, path, root, fields }) {
  const mutation = useMutation({
    mutationFn: (payload) => apiRequest(path, { method: "PATCH", body: JSON.stringify({ [root]: payload }) })
  });

  function submit(event) {
    event.preventDefault();
    const form = event.currentTarget;
    const values = Object.fromEntries(new FormData(form));
    if (form.elements.active) values.active = form.elements.active.checked;
    mutation.mutate(values);
  }

  return <Panel title={title}>
    <form onSubmit={submit}>
      {fields.map((field) => <label key={field.name} className={field.full ? "full" : ""}>
        {field.label}
        {field.type === "textarea" ? <textarea name={field.name} defaultValue={data?.[field.name]} />
          : field.type === "checkbox" ? <input name={field.name} type="checkbox" defaultChecked={Boolean(data?.[field.name])} />
            : field.options ? <select name={field.name} defaultValue={data?.[field.name]}>
              {field.options.map((option) => <option key={option} value={option}>{option}</option>)}
            </select>
              : <input name={field.name} type={field.type || "text"} defaultValue={data?.[field.name]} />}
      </label>)}
      {mutation.error && <p className="form-error">{mutation.error.message}</p>}
      {mutation.isSuccess && <p className="form-success">Saved successfully.</p>}
      <button disabled={mutation.isPending}>{mutation.isPending ? "Saving…" : "Save changes"}</button>
    </form>
  </Panel>;
}

export function SettingsPage() {
  const client = useQueryClient();
  const business = useQuery({ queryKey: ["business"], queryFn: () => apiRequest("/api/business") });
  const policy = useQuery({ queryKey: ["policy"], queryFn: () => apiRequest("/api/business_policy") });
  const delivery = useQuery({ queryKey: ["delivery"], queryFn: () => apiRequest("/api/delivery_integration") });
  const channels = useQuery({ queryKey: ["channels"], queryFn: () => apiRequest("/api/channel_connections") });
  const addChannel = useMutation({
    mutationFn: (payload) => apiRequest("/api/channel_connections", {
      method: "POST", body: JSON.stringify({ channel_connection: payload })
    }),
    onSuccess: () => client.invalidateQueries({ queryKey: ["channels"] })
  });
  if ([business, policy, delivery, channels].some((query) => query.isLoading)) return <LoadingState />;
  const error = [business, policy, delivery, channels].find((query) => query.isError)?.error;
  if (error) return <ErrorState error={error} />;

  function connect(event) {
    event.preventDefault();
    const form = event.currentTarget;
    addChannel.mutate(Object.fromEntries(new FormData(form)), { onSuccess: () => form.reset() });
  }

  const businessFields = [
    { name: "name", label: "Business name" }, { name: "category", label: "Category" },
    { name: "default_language", label: "Default language", options: ["banglish", "english", "bengali"] },
    { name: "timezone", label: "Timezone" }, { name: "currency", label: "Currency" },
    { name: "usd_exchange_rate", label: "BDT per USD (optional)", type: "number" }
  ];
  const policyFields = [
    "payment_methods", "cash_on_delivery", "delivery_charges", "delivery_areas", "delivery_time",
    "return_policy", "authenticity_statement", "discount_policy", "trial_policy", "trust_information",
    "bulk_order_policy"
  ].map((name) => ({ name, label: name.replaceAll("_", " "), type: "textarea" }));

  return <>
    <PageHeader title="Business setup" description="Control the facts, policies and integrations used by your sales assistant." />
    <div className="content-grid settings-grid">
      <SettingsForm title="Business profile" data={business.data} path="/api/business" root="business" fields={businessFields} />
      <SettingsForm title="Sales information" data={policy.data} path="/api/business_policy" root="business_policy" fields={policyFields} />
      <SettingsForm title="Delivery integration" data={delivery.data} path="/api/delivery_integration" root="delivery_integration" fields={[
        { name: "provider", label: "Provider", options: ["manual", "webhook"] },
        { name: "endpoint_url", label: "Endpoint URL", type: "url" },
        { name: "api_key", label: "API key", type: "password" },
        { name: "active", label: "Enable delivery submission", type: "checkbox" }
      ]} />
      <Panel title="Sales channels">
        <div className="channel-list">{channels.data.map((connection) => <div key={connection.id}>
          <span><strong>{connection.display_name || connection.external_account_id}</strong><small>{connection.channel}</small></span>
          <span className={`status ${connection.status}`}>{connection.status}</span>
        </div>)}</div>
        <form onSubmit={connect}>
          <h3>Connect a channel</h3>
          <label>Channel<select name="channel"><option value="facebook">Messenger</option><option value="instagram">Instagram</option><option value="whatsapp">WhatsApp</option></select></label>
          <label>Page or account ID<input name="external_account_id" required /></label>
          <label>Display name<input name="display_name" /></label>
          <label>Access token<input name="access_token" type="password" required /></label>
          <label>Verify token<input name="verify_token" type="password" /></label>
          {addChannel.error && <p className="form-error">{addChannel.error.message}</p>}
          <button disabled={addChannel.isPending}>Connect channel</button>
        </form>
      </Panel>
    </div>
  </>;
}
