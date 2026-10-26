import { useCallback, useEffect, useState } from "react";
import type { FormEvent, ReactNode } from "react";
import { Activity, ArrowDownLeft, ArrowUpRight, Boxes, ClipboardCheck, LayoutDashboard, Package, RefreshCw, Search, ShieldAlert, Truck, Warehouse } from "lucide-react";

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3000/api/v1";

type Product = { id: number; name: string; sku: string; category: string; active: boolean; description?: string };
type ReturnRecord = { id: number; return_number: string; product_id: number; quantity: number; reason: string; status: string; created_at: string; product?: { name: string; sku: string }; order_reference?: string };
type InventoryRow = { id: number; product: { id: number; name: string; sku: string }; bucket: string; quantity: number };
type Dashboard = { returns_total: number; awaiting_receipt: number; awaiting_inspection: number; awaiting_disposition: number; completed_returns: number; inventory: { sellable: number; quarantine: number; refurbishment: number; scrapped: number }; recent_returns: ReturnRecord[] };

type Tab = "Overview" | "Products" | "Returns" | "Inventory";
const nav: { label: Tab; icon: typeof LayoutDashboard }[] = [
  { label: "Overview", icon: LayoutDashboard },
  { label: "Products", icon: Package },
  { label: "Returns", icon: ArrowDownLeft },
  { label: "Inventory", icon: Warehouse }
];

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers: { "Content-Type": "application/json", ...(sessionStorage.getItem("restock_token") ? { Authorization: `Bearer ${sessionStorage.getItem("restock_token")}` } : {}), ...(init?.headers ?? {}) }
  });
  if (!response.ok) {
    const body = await response.json().catch(() => null);
    throw new Error(body?.error?.message ?? `Request failed (${response.status})`);
  }
  if (response.status === 204) return undefined as T;
  return response.json() as Promise<T>;
}

function StatusPill({ value }: { value: string }) {
  return <span className={`pill pill-${value}`}>{value.replaceAll("_", " ")}</span>;
}

export default function App() {
  const [tab, setTab] = useState<Tab>("Overview");
  const [token, setToken] = useState(() => sessionStorage.getItem("restock_token") ?? "");
  const [loginForm, setLoginForm] = useState({ email: "", password: "" });
  const [dashboard, setDashboard] = useState<Dashboard | null>(null);
  const [products, setProducts] = useState<Product[]>([]);
  const [returns, setReturns] = useState<ReturnRecord[]>([]);
  const [inventory, setInventory] = useState<InventoryRow[]>([]);
  const [search, setSearch] = useState("");
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState(false);
  const [showProductForm, setShowProductForm] = useState(false);
  const [showReturnForm, setShowReturnForm] = useState(false);
  const [showInspectionForm, setShowInspectionForm] = useState(false);
  const [showDispositionForm, setShowDispositionForm] = useState(false);
  const [selectedReturnId, setSelectedReturnId] = useState<number | null>(null);
  const [inspectionForm, setInspectionForm] = useState({ condition: "good", functional_status: "working", accessories_complete: true, issue_found: false, damage_notes: "", notes: "" });
  const [dispositionForm, setDispositionForm] = useState({ disposition_type: "restock", reason: "", notes: "" });
  const [productForm, setProductForm] = useState({ name: "", sku: "", category: "Electronics", description: "" });
  const [returnForm, setReturnForm] = useState({ product_id: "", quantity: "1", reason: "damaged", order_reference: "", customer_notes: "" });

  const loadData = useCallback(async () => {
    if (!sessionStorage.getItem("restock_token")) return;
    setError("");
    try {
      const [d, p, r, i] = await Promise.all([
        request<{ data: Dashboard }>("/dashboard"),
        request<{ data: Product[]; meta: { total: number } }>(`/products?q=${encodeURIComponent(search)}&per_page=100`),
        request<{ data: ReturnRecord[] }>(`/returns?q=${encodeURIComponent(search)}&per_page=100`),
        request<{ data: InventoryRow[] }>(`/inventory?q=${encodeURIComponent(search)}`)
      ]);
      setDashboard(d.data);
      setProducts(p.data);
      setReturns(r.data);
      setInventory(i.data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unable to load ReStock data.");
    }
  }, [search]);

  useEffect(() => { void loadData(); }, [loadData]);
  useEffect(() => {
    if (!notice) return;
    const timer = window.setTimeout(() => setNotice(""), 3500);
    return () => window.clearTimeout(timer);
  }, [notice]);

  async function login(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError("");
    try {
      const result = await request<{ data: { token: string } }>("/auth/login", { method: "POST", body: JSON.stringify(loginForm) });
      sessionStorage.setItem("restock_token", result.data.token);
      setToken(result.data.token);
      setLoginForm({ email: "", password: "" });
      await loadData();
    } catch (e) { setError(e instanceof Error ? e.message : "Sign in failed."); }
  }

  async function logout() {
    try { await request("/auth/logout", { method: "POST" }); } catch { /* Expired tokens are cleared locally as well. */ }
    sessionStorage.removeItem("restock_token"); setToken(""); setDashboard(null);
  }

  async function submitProduct(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true); setError("");
    try {
      await request("/products", { method: "POST", body: JSON.stringify({ product: productForm }) });
      setShowProductForm(false);
      setProductForm({ name: "", sku: "", category: "Electronics", description: "" });
      setNotice("Product created successfully.");
      await loadData();
    } catch (e) { setError(e instanceof Error ? e.message : "Could not create product."); }
    finally { setBusy(false); }
  }

  async function submitReturn(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true); setError("");
    try {
      await request("/returns", { method: "POST", body: JSON.stringify({ return: { ...returnForm, product_id: Number(returnForm.product_id), quantity: Number(returnForm.quantity) } }) });
      setShowReturnForm(false);
      setReturnForm({ product_id: "", quantity: "1", reason: "damaged", order_reference: "", customer_notes: "" });
      setNotice("Return registered. Sellable inventory has not changed.");
      await loadData();
    } catch (e) { setError(e instanceof Error ? e.message : "Could not register return."); }
    finally { setBusy(false); }
  }

  async function receiveReturn(id: number) {
    setBusy(true); setError("");
    try {
      await request(`/returns/${id}/receive`, { method: "POST" });
      setNotice("Return received. It has not been added to sellable inventory.");
      await loadData();
    } catch (e) { setError(e instanceof Error ? e.message : "Could not receive return."); }
    finally { setBusy(false); }
  }

  async function submitInspection(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (selectedReturnId === null) return;
    setBusy(true); setError("");
    try {
      const result = await request<{ data: { id: number } }>(`/returns/${selectedReturnId}/inspections`, { method: "POST", body: JSON.stringify({ inspection: inspectionForm }) });
      await request(`/returns/${selectedReturnId}/inspections/${result.data.id}/complete`, { method: "POST" });
      setShowInspectionForm(false); setSelectedReturnId(null);
      setNotice("Inspection completed. Choose an appropriate disposition next.");
      await loadData();
    } catch (e) { setError(e instanceof Error ? e.message : "Could not complete inspection."); }
    finally { setBusy(false); }
  }

  async function submitDisposition(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (selectedReturnId === null) return;
    setBusy(true); setError("");
    try {
      await request(`/returns/${selectedReturnId}/disposition`, { method: "POST", body: JSON.stringify({ disposition: dispositionForm }) });
      setShowDispositionForm(false); setSelectedReturnId(null);
      setNotice("Disposition recorded and inventory updated transactionally.");
      await loadData();
    } catch (e) { setError(e instanceof Error ? e.message : "Could not record disposition."); }
    finally { setBusy(false); }
  }

  const metrics = dashboard ? [
    { label: "Total returns", value: dashboard.returns_total, icon: ArrowDownLeft, note: "All recorded cases" },
    { label: "Awaiting receipt", value: dashboard.awaiting_receipt, icon: Truck, note: "Registered by the team" },
    { label: "Awaiting inspection", value: dashboard.awaiting_inspection, icon: ClipboardCheck, note: "Needs warehouse review" },
    { label: "Sellable units", value: dashboard.inventory.sellable, icon: Boxes, note: "Approved for sale" }
  ] : [];

  if (!token) return <div className="login-screen"><div className="login-card"><div className="brand-mark login-mark"><RefreshCw size={23} /></div><div className="eyebrow">RETURNS OPERATIONS</div><h1>Welcome to ReStock</h1><p>Sign in to manage returns, inspections, and inventory.</p>{error && <div className="alert alert-error">{error}</div>}<form className="form-stack login-form" onSubmit={login}><label>Email address<input type="email" required autoComplete="username" value={loginForm.email} onChange={e => setLoginForm({ ...loginForm, email: e.target.value })} placeholder="admin@example.com" /></label><label>Password<input type="password" required autoComplete="current-password" value={loginForm.password} onChange={e => setLoginForm({ ...loginForm, password: e.target.value })} placeholder="Your password" /></label><button className="button button-primary login-submit">Sign in</button></form><small className="login-hint">Use the administrator account configured in your local environment.</small></div></div>;

  return <div className="app-shell">
    <aside className="sidebar">
      <div className="brand"><div className="brand-mark"><RefreshCw size={21} /></div><div><strong>ReStock</strong><span>RETURNS OPERATIONS</span></div></div>
      <div className="workspace-label">WORKSPACE</div>
      <nav>{nav.map(item => <button key={item.label} className={tab === item.label ? "nav-item active" : "nav-item"} onClick={() => setTab(item.label)}><item.icon size={18} /><span>{item.label}</span>{item.label === "Returns" && dashboard?.awaiting_inspection ? <b>{dashboard.awaiting_inspection}</b> : null}</button>)}</nav>
      <div className="sidebar-bottom"><div className="system-status"><span className="status-dot" /><div><strong>System workspace</strong><small>API-connected demo</small></div></div><div className="user-chip"><div className="avatar">RS</div><div><strong>Warehouse team</strong><small>Local development</small></div></div></div>
    </aside>

    <main className="main">
      <header className="topbar"><div className="crumb">Operations <span>/</span> <strong>{tab}</strong></div><div className="top-actions"><div className="api-indicator"><span className="status-dot" /> Live data</div><button className="icon-button" title="Refresh data" onClick={() => void loadData()}><RefreshCw size={17} /></button><button className="button button-secondary" onClick={() => void logout()}>Sign out</button></div></header>
      <div className="page-content">
        <div className="page-heading"><div><div className="eyebrow">WAREHOUSE MANAGEMENT</div><h1>{tab === "Overview" ? "Operations overview" : tab}</h1><p>{tab === "Overview" ? "A clear view of returns, inspection work, and inventory health." : tab === "Products" ? "Manage the catalog of products eligible for returns." : tab === "Returns" ? "Track returned items from arrival through final disposition." : "Understand where every returned unit is held."}</p></div><div className="heading-actions"><button className="button button-secondary" onClick={() => void loadData()}><RefreshCw size={15} /> Refresh</button>{tab === "Products" && <button className="button button-primary" onClick={() => setShowProductForm(true)}>+ New product</button>}{tab === "Returns" && <button className="button button-primary" onClick={() => setShowReturnForm(true)}>+ Register return</button>}</div></div>

        {error && <div className="alert alert-error"><ShieldAlert size={18} /><span>{error}</span><button onClick={() => setError("")}>Dismiss</button></div>}
        {notice && <div className="alert alert-success"><Activity size={18} /><span>{notice}</span></div>}
        <div className="toolbar"><div className="search-box"><Search size={17} /><input aria-label="Search records" value={search} onChange={e => setSearch(e.target.value)} placeholder="Search products, SKUs, or return numbers..." /></div><span className="updated-label">Synced with API</span></div>

        {tab === "Overview" && <>
          <div className="metric-grid">{metrics.map(m => <div className="metric-card" key={m.label}><div className="metric-top"><span>{m.label}</span><div className="metric-icon"><m.icon size={18} /></div></div><div className="metric-value">{m.value}</div><div className="metric-note">{m.note}</div></div>)}</div>
          <div className="overview-grid"><section className="panel"><div className="panel-heading"><div><h2>Recent returns</h2><p>Latest activity across the workflow</p></div><button className="text-button" onClick={() => setTab("Returns")}>View all <ArrowUpRight size={15} /></button></div><ReturnTable rows={(dashboard?.recent_returns ?? []).filter(r => !search || [r.return_number, r.product?.name, r.product?.sku].some(v => v?.toLowerCase().includes(search.toLowerCase())))} onReceive={receiveReturn} onInspect={id => { setSelectedReturnId(id); setShowInspectionForm(true); }} onDisposition={id => { setSelectedReturnId(id); setShowDispositionForm(true); }} busy={busy} /></section>
          <section className="panel inventory-panel"><div className="panel-heading"><div><h2>Inventory health</h2><p>Units by disposition bucket</p></div><Boxes size={19} className="muted-icon" /></div><div className="inventory-stat"><span className="legend-dot sellable-dot" /><div><span>Sellable</span><strong>{dashboard?.inventory.sellable ?? "—"}</strong></div></div><div className="inventory-stat"><span className="legend-dot quarantine-dot" /><div><span>Quarantine</span><strong>{dashboard?.inventory.quarantine ?? "—"}</strong></div></div><div className="inventory-stat"><span className="legend-dot refurb-dot" /><div><span>Refurbishment</span><strong>{dashboard?.inventory.refurbishment ?? "—"}</strong></div></div><div className="inventory-stat"><span className="legend-dot scrap-dot" /><div><span>Scrapped</span><strong>{dashboard?.inventory.scrapped ?? "—"}</strong></div></div><div className="callout"><ShieldAlert size={17} /><p><strong>Safety rule</strong>Receiving a return never makes it sellable. Inspection and disposition come first.</p></div></section></div>
        </>}

        {tab === "Products" && <section className="panel"><div className="panel-heading"><div><h2>Product catalog</h2><p>{products.length} product records loaded</p></div></div><div className="table-wrap"><table><thead><tr><th>Product</th><th>SKU</th><th>Category</th><th>Status</th></tr></thead><tbody>{products.map(p => <tr key={p.id}><td><div className="product-cell"><div className="product-icon"><Package size={17} /></div><div><strong>{p.name}</strong><small>{p.description || "No description provided"}</small></div></div></td><td className="mono">{p.sku}</td><td>{p.category}</td><td><StatusPill value={p.active ? "active" : "inactive"} /></td></tr>)}</tbody></table>{products.length === 0 && <EmptyState title="No products found" text="Create a product or adjust your search." />}</div></section>}

        {tab === "Returns" && <section className="panel"><div className="panel-heading"><div><h2>Return queue</h2><p>Registration, receipt, inspection, and disposition status</p></div><div className="mini-count">{returns.length} cases</div></div><ReturnTable rows={returns} onReceive={receiveReturn} onInspect={id => { setSelectedReturnId(id); setShowInspectionForm(true); }} onDisposition={id => { setSelectedReturnId(id); setShowDispositionForm(true); }} busy={busy} /></section>}

        {tab === "Inventory" && <section className="panel"><div className="panel-heading"><div><h2>Inventory by disposition</h2><p>Only sellable units are eligible for sale</p></div><div className="mini-count">{inventory.length} buckets</div></div><div className="table-wrap"><table><thead><tr><th>Product</th><th>SKU</th><th>Inventory bucket</th><th>Quantity</th></tr></thead><tbody>{inventory.map(row => <tr key={row.id}><td><div className="product-cell"><div className="product-icon"><Boxes size={17} /></div><strong>{row.product.name}</strong></div></td><td className="mono">{row.product.sku}</td><td><StatusPill value={row.bucket} /></td><td><strong>{row.quantity}</strong></td></tr>)}</tbody></table>{inventory.length === 0 && <EmptyState title="Inventory is empty" text="Inventory is updated when a valid disposition is recorded." />}</div></section>}

        <footer className="page-footer"><span>ReStock <b>•</b> Reverse warehouse management</span><span>Prototype build · Backend API required</span></footer>
      </div>
    </main>

    {showProductForm && <Modal title="Create product" onClose={() => setShowProductForm(false)}><form className="form-stack" onSubmit={submitProduct}><label>Product name<input required value={productForm.name} onChange={e => setProductForm({ ...productForm, name: e.target.value })} placeholder="e.g. Wireless headphones" /></label><label>SKU<input required value={productForm.sku} onChange={e => setProductForm({ ...productForm, sku: e.target.value })} placeholder="e.g. AUD-001" /></label><label>Category<select value={productForm.category} onChange={e => setProductForm({ ...productForm, category: e.target.value })}>{["Electronics", "Clothing", "Home", "Audio", "Accessories", "Appliances", "Other"].map(v => <option key={v}>{v}</option>)}</select></label><label>Description<textarea value={productForm.description} onChange={e => setProductForm({ ...productForm, description: e.target.value })} rows={3} /></label><div className="modal-actions"><button type="button" className="button button-secondary" onClick={() => setShowProductForm(false)}>Cancel</button><button disabled={busy} className="button button-primary">{busy ? "Saving..." : "Create product"}</button></div></form></Modal>}

    {showInspectionForm && <Modal title="Inspect returned item" onClose={() => setShowInspectionForm(false)}><form className="form-stack" onSubmit={submitInspection}><label>Item condition<select value={inspectionForm.condition} onChange={e => setInspectionForm({ ...inspectionForm, condition: e.target.value })}>{["new", "like_new", "good", "fair", "damaged", "defective"].map(v => <option key={v} value={v}>{v.replaceAll("_", " ")}</option>)}</select></label><label>Functional status<select value={inspectionForm.functional_status} onChange={e => setInspectionForm({ ...inspectionForm, functional_status: e.target.value })}>{["working", "partially_working", "not_working", "not_tested"].map(v => <option key={v} value={v}>{v.replaceAll("_", " ")}</option>)}</select></label><label className="check-label"><input type="checkbox" checked={inspectionForm.accessories_complete} onChange={e => setInspectionForm({ ...inspectionForm, accessories_complete: e.target.checked })} /> Accessories complete</label><label className="check-label"><input type="checkbox" checked={inspectionForm.issue_found} onChange={e => setInspectionForm({ ...inspectionForm, issue_found: e.target.checked })} /> Issue found during inspection</label><label>Damage notes<textarea rows={2} value={inspectionForm.damage_notes} onChange={e => setInspectionForm({ ...inspectionForm, damage_notes: e.target.value })} /></label><label>Inspection notes<textarea rows={3} value={inspectionForm.notes} onChange={e => setInspectionForm({ ...inspectionForm, notes: e.target.value })} /></label><div className="callout"><ShieldAlert size={17} /><p>Completing the inspection does not change sellable inventory. A separate disposition decision is required.</p></div><div className="modal-actions"><button type="button" className="button button-secondary" onClick={() => setShowInspectionForm(false)}>Cancel</button><button disabled={busy} className="button button-primary">{busy ? "Saving..." : "Complete inspection"}</button></div></form></Modal>}

    {showDispositionForm && <Modal title="Choose disposition" onClose={() => setShowDispositionForm(false)}><form className="form-stack" onSubmit={submitDisposition}><label>Disposition<select value={dispositionForm.disposition_type} onChange={e => setDispositionForm({ ...dispositionForm, disposition_type: e.target.value })}>{[["restock", "Restock — adds sellable stock"], ["refurbish", "Refurbishment — non-sellable"], ["quarantine", "Quarantine — non-sellable"], ["scrap", "Scrap — non-sellable"]].map(([v, label]) => <option key={v} value={v}>{label}</option>)}</select></label><label>Decision reason<input required value={dispositionForm.reason} onChange={e => setDispositionForm({ ...dispositionForm, reason: e.target.value })} placeholder="Explain the decision" /></label><label>Notes<textarea rows={3} value={dispositionForm.notes} onChange={e => setDispositionForm({ ...dispositionForm, notes: e.target.value })} /></label><div className="callout"><ShieldAlert size={17} /><p>Restock is allowed only for eligible inspection results. The server enforces the rule and updates the inventory bucket transactionally.</p></div><div className="modal-actions"><button type="button" className="button button-secondary" onClick={() => setShowDispositionForm(false)}>Cancel</button><button disabled={busy} className="button button-primary">{busy ? "Saving..." : "Confirm disposition"}</button></div></form></Modal>}

    {showReturnForm && <Modal title="Register a return" onClose={() => setShowReturnForm(false)}><form className="form-stack" onSubmit={submitReturn}><label>Product<select required value={returnForm.product_id} onChange={e => setReturnForm({ ...returnForm, product_id: e.target.value })}><option value="">Select a product</option>{products.filter(p => p.active).map(p => <option key={p.id} value={p.id}>{p.name} · {p.sku}</option>)}</select></label><label>Quantity<input required type="number" min="1" step="1" value={returnForm.quantity} onChange={e => setReturnForm({ ...returnForm, quantity: e.target.value })} /></label><label>Return reason<select value={returnForm.reason} onChange={e => setReturnForm({ ...returnForm, reason: e.target.value })}>{[["damaged", "Damaged"], ["defective", "Defective"], ["incorrect_item", "Incorrect item"], ["unwanted", "Unwanted"], ["other", "Other"]].map(([v, label]) => <option key={v} value={v}>{label}</option>)}</select></label><label>Order reference<input value={returnForm.order_reference} onChange={e => setReturnForm({ ...returnForm, order_reference: e.target.value })} placeholder="Optional order number" /></label><label>Notes<textarea rows={3} value={returnForm.customer_notes} onChange={e => setReturnForm({ ...returnForm, customer_notes: e.target.value })} placeholder="Customer-reported issue..." /></label><div className="callout"><ShieldAlert size={17} /><p>Registration does not increase sellable inventory. The item must be received, inspected, and dispositioned.</p></div><div className="modal-actions"><button type="button" className="button button-secondary" onClick={() => setShowReturnForm(false)}>Cancel</button><button disabled={busy || products.filter(p => p.active).length === 0} className="button button-primary">{busy ? "Registering..." : "Register return"}</button></div></form></Modal>}
  </div>;
}

function ReturnTable({ rows, onReceive, onInspect, onDisposition, busy }: { rows: ReturnRecord[]; onReceive: (id: number) => void; onInspect: (id: number) => void; onDisposition: (id: number) => void; busy: boolean }) {
  return <div className="table-wrap"><table><thead><tr><th>Return</th><th>Product</th><th>Reason</th><th>Status</th><th>Quantity</th><th>Action</th></tr></thead><tbody>{rows.map(r => <tr key={r.id}><td><div className="return-id"><strong>{r.return_number}</strong><small>{new Date(r.created_at).toLocaleDateString()}</small></div></td><td><div className="product-cell"><div><strong>{r.product?.name ?? `Product #${r.product_id}`}</strong><small>{r.product?.sku ?? "SKU unavailable"}</small></div></div></td><td>{r.reason.replaceAll("_", " ")}</td><td><StatusPill value={r.status} /></td><td>{r.quantity}</td><td>{r.status === "registered" ? <button className="small-action" disabled={busy} onClick={() => onReceive(r.id)}>Receive item</button> : r.status === "received" || r.status === "inspection_in_progress" ? <button className="small-action" disabled={busy} onClick={() => onInspect(r.id)}>Inspect</button> : r.status === "inspected" ? <button className="small-action" disabled={busy} onClick={() => onDisposition(r.id)}>Disposition</button> : <span className="muted-text">—</span>}</td></tr>)}</tbody></table>{rows.length === 0 && <EmptyState title="No returns found" text="Register a return to begin tracking its journey." />}</div>;
}

function Modal({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  return <div className="modal-backdrop" role="presentation" onMouseDown={e => { if (e.target === e.currentTarget) onClose(); }}><section className="modal" role="dialog" aria-modal="true" aria-label={title}><div className="modal-heading"><h2>{title}</h2><button className="icon-button" aria-label="Close dialog" onClick={onClose}>×</button></div>{children}</section></div>;
}
function EmptyState({ title, text }: { title: string; text: string }) { return <div className="empty-state"><div className="empty-icon"><Package size={22} /></div><strong>{title}</strong><p>{text}</p></div>; }
