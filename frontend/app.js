const state = {
  baseUrl: localStorage.getItem("chatcart_api_url") || "http://localhost:3000",
  token: localStorage.getItem("chatcart_api_token") || "",
  actorType: localStorage.getItem("chatcart_actor_type") || "",
  business: null,
  view: "overview"
};

const $ = (selector) => document.querySelector(selector);
const el = (tag, text, className) => {
  const node = document.createElement(tag);
  if (text !== undefined) node.textContent = text;
  if (className) node.className = className;
  return node;
};

async function api(path, options = {}) {
  const response = await fetch(`${state.baseUrl}${path}`, {
    ...options,
    headers: { Authorization: `Bearer ${state.token}`, "Content-Type": "application/json", ...(options.headers || {}) }
  });
  if (!response.ok) {
    const body = await response.json().catch(() => ({}));
    throw new Error(body.error || Object.values(body.errors || {}).flat().join(", ") || `Request failed (${response.status})`);
  }
  if (response.status === 204) return null;
  return response.json();
}

function flash(message, error = false) {
  $("#flash").textContent = message;
  $("#flash").className = error ? "danger" : "";
  setTimeout(() => { if ($("#flash").textContent === message) $("#flash").textContent = ""; }, 3500);
}

async function connect() {
  if (state.actorType === "platform_administrator") {
    await api("/admin/businesses");
    state.business = { name: "ChatCart Platform" };
    state.view = "businesses";
  } else {
    state.business = await api("/api/business");
    state.view = "overview";
  }
  localStorage.setItem("chatcart_api_url", state.baseUrl);
  localStorage.setItem("chatcart_api_token", state.token);
  localStorage.setItem("chatcart_actor_type", state.actorType);
  $("#connection-panel").hidden = true;
  $("#workspace").hidden = false;
  $("#business-badge").textContent = state.business.name;
  configureNavigation();
  await render();
}

function configureNavigation() {
  const items = state.actorType === "platform_administrator"
    ? [["businesses", "Businesses"]]
    : [["overview", "Overview"], ["orders", "Orders"], ["conversations", "Conversations"], ["products", "Products"], ["settings", "Business setup"]];
  const navigation = $("#navigation"); navigation.replaceChildren();
  items.forEach(([view, label]) => { const button=el("button",label); button.dataset.view=view; button.classList.toggle("active",view===state.view); navigation.append(button); });
}

async function render() {
  $("#page-title").textContent = state.view[0].toUpperCase() + state.view.slice(1);
  $("#view").replaceChildren($("#loading").content.cloneNode(true));
  try {
    await ({ businesses: renderBusinesses, overview: renderOverview, orders: renderOrders,
      conversations: renderConversations, products: renderProducts, settings: renderSettings })[state.view]();
  } catch (error) {
    $("#view").replaceChildren(el("div", error.message, "panel danger"));
  }
}

async function renderOverview() {
  const data = await api("/api/analytics");
  const root = el("div");
  const cards = el("div", undefined, "cards");
  [["Conversations", data.conversations], ["Confirmed orders", data.confirmed_orders],
    ["Chat → order", `${data.conversation_to_order_rate}%`], ["Revenue", `${data.revenue} BDT`],
    ["Unique customers", data.unique_customers], ["Repeat customers", data.repeat_customers],
    ["Repeat rate", `${data.repeat_customer_rate}%`], ["Average order", `${data.average_order_value} BDT`]
  ].forEach(([label, value]) => { const card = el("div", undefined, "panel metric"); card.append(el("span", label), el("strong", value)); cards.append(card); });
  root.append(cards);
  const grid = el("div", undefined, "grid");
  grid.append(keyValuePanel("Orders by status", data.orders_by_status), keyValuePanel("Orders by channel", data.orders_by_channel), keyValuePanel("Top products", data.top_products));
  $("#view").replaceChildren(root, grid);
}

async function renderBusinesses() {
  const businesses = await api("/admin/businesses");
  const panel = el("div", undefined, "panel"); const toolbar = el("div", undefined, "toolbar"); toolbar.append(el("h2", "Businesses"));
  const add = el("button", "Add business"); add.onclick = businessDialog; toolbar.append(add); panel.append(toolbar);
  panel.append(table(["Business", "Slug", "Category", "Status", "Created"], businesses.map(business => [
    business.name, business.slug, business.category || "—", business.status, new Date(business.created_at).toLocaleDateString()
  ])));
  $("#view").replaceChildren(panel);
}

function businessDialog() {
  const dialog=document.createElement("dialog"); const body=el("div",undefined,"dialog-body"); body.append(el("h2","Add a business"));
  const form=el("form"); form.innerHTML=`<div class="form-grid"><label>Business name<input name="name" required></label><label>Slug<input name="slug" pattern="[a-z0-9-]+" required></label><label>Category<input name="category" required></label><label>Default language<select name="default_language"><option>banglish</option><option>english</option><option>bengali</option></select></label></div><h3>Business owner</h3><div class="form-grid"><label>Name<input name="owner_name" required></label><label>Email<input name="owner_email" type="email" required></label><label class="wide">Temporary password<input name="owner_password" type="password" minlength="12" required></label></div><button>Create business</button>`;
  form.onsubmit=async event=>{event.preventDefault(); const values=Object.fromEntries(new FormData(form)); const payload={business:{name:values.name,slug:values.slug,category:values.category,default_language:values.default_language,timezone:"Asia/Dhaka",currency:"BDT"},owner:{name:values.owner_name,email:values.owner_email,password:values.owner_password}}; await api("/admin/businesses",{method:"POST",body:JSON.stringify(payload)}); dialog.close();dialog.remove();flash("Business and owner created");render();};
  body.append(form);dialog.append(body);document.body.append(dialog);dialog.showModal();
}

function keyValuePanel(title, values) {
  const panel = el("div", undefined, "panel"); panel.append(el("h2", title));
  const list = el("div", undefined, "list");
  Object.entries(values || {}).forEach(([key, value]) => { const row = el("div", undefined, "list-item"); row.append(el("span", key), el("strong", value)); list.append(row); });
  if (!list.children.length) list.append(el("p", "No data yet.", "muted")); panel.append(list); return panel;
}

async function renderOrders() {
  const orders = await api("/api/orders");
  const panel = el("div", undefined, "panel");
  const toolbar = el("div", undefined, "toolbar"); toolbar.append(el("h2", "Confirmed sales"));
  const exportButton = el("button", "Export CSV", "secondary"); exportButton.onclick = exportOrders; toolbar.append(exportButton); panel.append(toolbar);
  panel.append(table(["Order", "Customer", "Channel", "Items", "Total", "Status"], orders.map(order => [
    order.number, `${order.customer_name}\n${order.phone}`, order.channel,
    order.items.map(item => `${item.quantity} × ${item.product_name}`).join(", "), `${order.total} ${order.currency}`, order.status
  ])));
  $("#view").replaceChildren(panel);
}

async function exportOrders() {
  const response = await fetch(`${state.baseUrl}/api/orders/export`, { headers: { Authorization: `Bearer ${state.token}` } });
  if (!response.ok) return flash("CSV export failed", true);
  const link = document.createElement("a"); link.href = URL.createObjectURL(await response.blob()); link.download = `orders-${new Date().toISOString().slice(0,10)}.csv`; link.click(); URL.revokeObjectURL(link.href);
}

async function renderConversations() {
  const conversations = await api("/api/conversations");
  const panel = el("div", undefined, "panel"); panel.append(el("h2", "Customer conversations"));
  const list = el("div", undefined, "list");
  conversations.forEach(conversation => {
    const row = el("div", undefined, "list-item");
    const info = el("div"); info.append(el("strong", `${conversation.channel} · ${conversation.external_customer_id}`), el("div", `${conversation.message_count} messages · ${conversation.status}`, "muted"));
    const action = el("button", conversation.status === "handed_over" ? "Resume AI" : "Take over", "secondary");
    action.onclick = async () => { await api(`/api/conversations/${conversation.id}/${conversation.status === "handed_over" ? "resume" : "handover"}`, { method:"POST" }); flash("Conversation updated"); render(); };
    row.append(info, action); list.append(row);
  });
  if (!conversations.length) list.append(el("p", "No conversations yet.", "muted")); panel.append(list); $("#view").replaceChildren(panel);
}

async function renderProducts() {
  const products = await api("/api/products");
  const panel = el("div", undefined, "panel"); const toolbar = el("div", undefined, "toolbar"); toolbar.append(el("h2", "Product catalog"));
  const add = el("button", "Add product"); add.onclick = () => productDialog(); toolbar.append(add); panel.append(toolbar);
  panel.append(table(["Product", "Price", "Stock", "Active", ""], products.map(product => [
    product.name, `${product.price} BDT`, product.stock_quantity, product.active ? "Yes" : "No", actionButton("Edit", () => productDialog(product))
  ])));
  $("#view").replaceChildren(panel);
}

function productDialog(product = {}) {
  const dialog = document.createElement("dialog"); const body = el("div", undefined, "dialog-body"); body.append(el("h2", product.id ? "Edit product" : "Add product"));
  const form = el("form"); form.innerHTML = `<label>Name<input name="name" required></label><div class="form-grid"><label>Price<input name="price" type="number" min="0" step="0.01" required></label><label>Stock<input name="stock_quantity" type="number" min="0" required></label></div><label>Description<textarea name="description"></textarea></label><label>Tags<input name="tags"></label><label><input name="active" type="checkbox"> Active</label><button>Save product</button>`;
  ["name","price","stock_quantity","description","tags"].forEach(key => { form.elements[key].value = product[key] ?? ""; }); form.elements.active.checked = product.active ?? true;
  form.onsubmit = async event => { event.preventDefault(); const values = Object.fromEntries(new FormData(form)); values.active = form.elements.active.checked; await api(`/api/products${product.id ? `/${product.id}` : ""}`, { method:product.id ? "PATCH" : "POST", body:JSON.stringify({ product:values }) }); dialog.close(); dialog.remove(); flash("Product saved"); render(); };
  body.append(form); dialog.append(body); document.body.append(dialog); dialog.showModal();
}

async function renderSettings() {
  const [policy, channels, delivery] = await Promise.all([api("/api/business_policy"), api("/api/channel_connections"), api("/api/delivery_integration")]);
  const root = el("div", undefined, "grid");
  root.append(settingsForm("Business profile", state.business, ["name","category","default_language","timezone","currency"], "/api/business", "business"));
  root.append(settingsForm("Sales and delivery information", policy, ["payment_methods","cash_on_delivery","delivery_charges","delivery_areas","delivery_time","return_policy","additional_information"], "/api/business_policy", "business_policy"));
  root.append(settingsForm("Delivery integration", delivery, ["provider","endpoint_url","api_key","active"], "/api/delivery_integration", "delivery_integration"));
  const channelPanel = el("div", undefined, "panel"); const channelToolbar = el("div", undefined, "toolbar"); channelToolbar.append(el("h2", "Connected channels")); const addChannel = el("button", "Connect channel", "secondary"); addChannel.onclick = channelDialog; channelToolbar.append(addChannel); channelPanel.append(channelToolbar);
  const list = el("div", undefined, "list"); channels.forEach(channel => list.append(el("div", `${channel.channel}: ${channel.display_name || channel.external_account_id} · ${channel.status}`, "list-item"))); if (!channels.length) list.append(el("p", "Connect channels through the API during onboarding.", "muted")); channelPanel.append(list); root.append(channelPanel);
  $("#view").replaceChildren(root);
}

function channelDialog() {
  const dialog = document.createElement("dialog"); const body = el("div", undefined, "dialog-body"); body.append(el("h2", "Connect a sales channel"));
  const form = el("form"); form.innerHTML = `<label>Channel<select name="channel"><option value="facebook">Messenger</option><option value="instagram">Instagram</option><option value="whatsapp">WhatsApp</option></select></label><label>Page / account ID<input name="external_account_id" required></label><label>Display name<input name="display_name"></label><label>Access token<input name="access_token" type="password" required autocomplete="off"></label><label>Webhook verify token<input name="verify_token" type="password" autocomplete="off"></label><button>Connect channel</button>`;
  form.onsubmit = async event => { event.preventDefault(); const values=Object.fromEntries(new FormData(form)); await api("/api/channel_connections", { method:"POST", body:JSON.stringify({ channel_connection:values }) }); dialog.close(); dialog.remove(); flash("Channel connected"); render(); };
  body.append(form); dialog.append(body); document.body.append(dialog); dialog.showModal();
}

function settingsForm(title, values, fields, path, rootKey) {
  const panel = el("div", undefined, "panel"); panel.append(el("h2", title)); const form = el("form");
  fields.forEach(field => { const label = el("label", field.replaceAll("_", " ")); const input = field === "active" ? document.createElement("input") : (field.includes("policy") || field.includes("information") ? document.createElement("textarea") : document.createElement("input")); input.name = field; if (field === "active") { input.type="checkbox"; input.checked=Boolean(values[field]); } else input.value=values[field] ?? ""; label.append(input); form.append(label); });
  form.append(el("button", "Save changes")); form.onsubmit = async event => { event.preventDefault(); const payload = Object.fromEntries(new FormData(form)); if (form.elements.active) payload.active = form.elements.active.checked; await api(path, { method:"PATCH", body:JSON.stringify({ [rootKey]:payload }) }); flash(`${title} saved`); }; panel.append(form); return panel;
}

function table(headers, rows) {
  if (!rows.length) return el("div", "Nothing to show yet.", "empty"); const wrapper=el("div"); wrapper.style.overflowX="auto"; const node=el("table"); const head=el("thead"); const headerRow=el("tr"); headers.forEach(value=>headerRow.append(el("th",value))); head.append(headerRow); const body=el("tbody"); rows.forEach(values=>{const row=el("tr"); values.forEach(value=>{const cell=el("td"); if(value instanceof Node) cell.append(value); else { cell.textContent=value; cell.style.whiteSpace="pre-line"; } row.append(cell);});body.append(row);});node.append(head,body);wrapper.append(node);return wrapper;
}
function actionButton(label, handler) { const button=el("button",label,"secondary"); button.onclick=handler; return button; }

$("#connection-form").onsubmit = async event => {
  event.preventDefault(); state.baseUrl=$("#api-url").value.replace(/\/$/,"");
  try {
    const level=$("#account-level").value; const response=await fetch(`${state.baseUrl}/auth/${level === "admin" ? "admin/" : ""}login`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({email:$("#login-email").value,password:$("#login-password").value})});
    const result=await response.json(); if(!response.ok) throw new Error(result.error || "Sign in failed"); state.token=result.token; state.actorType=result.actor_type; await connect();
  } catch(error) { flash(error.message,true); }
};
$("#navigation").onclick = event => { const button=event.target.closest("button[data-view]"); if(!button)return; state.view=button.dataset.view; document.querySelectorAll("nav button").forEach(item=>item.classList.toggle("active",item===button)); render(); };
$("#disconnect").onclick = async () => { await api("/auth/logout",{method:"DELETE"}).catch(()=>{}); localStorage.removeItem("chatcart_api_token");localStorage.removeItem("chatcart_actor_type");location.reload(); };
$("#api-url").value=state.baseUrl; if(state.token){ connect().catch(()=>{localStorage.removeItem("chatcart_api_token");localStorage.removeItem("chatcart_actor_type");}); }
