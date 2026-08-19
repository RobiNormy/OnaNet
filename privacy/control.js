import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const API = 'https://api.onanet.app';
const titles = {
  dashboard: 'Dashboard', verification: 'Verification queue', providers: 'Providers',
  users: 'Users', reports: 'Reports', packages: 'Packages', coverage: 'Coverage zones',
  subscriptions: 'Subscriptions', invoices: 'Invoices', revenue: 'Revenue',
};
const KES_PER_USD = 130;
const PLAN_USD = { free: 0, growth: 1500 / KES_PER_USD, pro: 2500 / KES_PER_USD };
const state = { supabase: null, session: null, data: {}, view: 'dashboard', search: '', selected: new Set() };

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];
const escapeHtml = (value) => String(value ?? '').replace(/[&<>'"]/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[char]);
const lower = (value) => String(value ?? '').toLowerCase();
const date = (value) => value ? new Intl.DateTimeFormat('en-KE', { dateStyle: 'medium' }).format(new Date(value)) : '—';
const money = (value) => new Intl.NumberFormat('en-KE', { style: 'currency', currency: 'KES', maximumFractionDigits: 0 }).format(Number(value || 0));
const usd = (value) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(Number(value || 0));
const initials = (value) => String(value || 'OnaNet').split(/\s+/).slice(0, 2).map((part) => part[0]).join('').toUpperCase();
const safeUrl = (value) => { try { const url = new URL(String(value)); return ['http:', 'https:'].includes(url.protocol) ? url.href : '#'; } catch { return '#'; } };
const list = (key) => Array.isArray(state.data[key]) ? state.data[key] : [];
const status = (value) => `<span class="status ${escapeHtml(lower(value).replaceAll(' ', '-'))}">${escapeHtml(value || 'unknown')}</span>`;

async function initialise() {
  const configResponse = await fetch(`${API}/auth/public-config`);
  if (!configResponse.ok) throw new Error('Control configuration is unavailable.');
  const config = await configResponse.json();
  state.supabase = createClient(config.supabase_url, config.supabase_publishable_key, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
  });
  const { data } = await state.supabase.auth.getSession();
  if (data.session) await enterApp(data.session, true);
  state.supabase.auth.onAuthStateChange((_event, session) => { state.session = session; });
}

async function enterApp(session, silent = false) {
  state.session = session;
  try {
    await api('/auth/session', {
      method: 'POST',
      body: JSON.stringify({ token: session.access_token }),
    });
    await loadSnapshot();
    $('#auth-shell').hidden = true;
    $('#app-shell').hidden = false;
    renderIdentity();
    render();
  } catch (error) {
    await state.supabase.auth.signOut();
    state.session = null;
    if (!silent) throw error;
  }
}

async function api(path, options = {}) {
  const token = state.session?.access_token;
  if (!token) throw new Error('Your admin session has expired. Sign in again.');
  const response = await fetch(`${API}${path}`, {
    ...options,
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, ...(options.headers || {}) },
  });
  const body = await response.json().catch(() => ({}));
  if (response.status === 401) {
    await signOut(false);
    throw new Error('Your session expired. Sign in again.');
  }
  if (!response.ok) throw new Error(body.detail || 'The control action could not be completed.');
  return body;
}

async function loadSnapshot() {
  setLoading(true);
  try { state.data = await api('/admin/snapshot'); }
  finally { setLoading(false); }
}

function setLoading(value, title = 'Loading control data…') {
  $('#loading-bar').hidden = !value;
  $('#refresh-button').disabled = value;
  setBusyOverlay(value, title);
}

function setBusyOverlay(value, title = 'Working…') {
  $('#busy-title').textContent = title;
  $('#busy-overlay').hidden = !value;
}

function setButtonBusy(button, value, label = 'Working…') {
  if (!button) return;
  if (value) {
    button.dataset.idleLabel = button.textContent;
    button.disabled = true;
    button.classList.add('button-busy');
    button.replaceChildren(Object.assign(document.createElement('span'), { className: 'spinner' }), document.createTextNode(label));
    return;
  }
  button.disabled = false;
  button.classList.remove('button-busy');
  button.textContent = button.dataset.idleLabel || button.textContent;
  delete button.dataset.idleLabel;
}

function renderIdentity() {
  const admin = state.data.admin || {};
  $('#admin-name').textContent = admin.name || 'Administrator';
  $('#admin-email-label').textContent = admin.email || '';
  $('#admin-avatar').textContent = initials(admin.name || admin.email).slice(0, 1);
}

function pageIntro(title, description, action = '') {
  return `<div class="page-intro"><div><h2>${escapeHtml(title)}</h2><p>${escapeHtml(description)}</p></div>${action}</div>`;
}

function emptyState(label) {
  return `<div class="empty-state"><strong>Nothing to review</strong><p>${escapeHtml(label)}</p></div>`;
}

function render() {
  $('#page-title').textContent = titles[state.view];
  $$('.nav-item').forEach((item) => item.classList.toggle('active', item.dataset.view === state.view));
  state.selected.clear();
  const views = { dashboard: renderDashboard, verification: renderVerification, providers: renderProviders, users: renderUsers, reports: renderReports, packages: renderPackages, coverage: renderCoverage, subscriptions: renderSubscriptions, invoices: renderInvoices, revenue: renderRevenue };
  $('#content').innerHTML = views[state.view]();
  bindViewActions();
}

function renderDashboard() {
  const users = list('users'); const providers = list('providers'); const documents = list('documents'); const reports = list('reports');
  const pendingDocs = documents.filter((item) => item.status === 'pending');
  const openReports = reports.filter((item) => item.status === 'open' || item.status === 'investigating');
  const verified = providers.filter((item) => item.is_verified).length;
  const recent = [...providers].sort((a, b) => new Date(b.created_at) - new Date(a.created_at)).slice(0, 5);
  return `${pageIntro('Good to see you.', 'A live view of trust, safety and platform operations.')}
    <div class="stats-grid">
      ${statCard('Total users', users.length, `${users.filter((u) => u.status === 'active').length} active accounts`)}
      ${statCard('Providers', providers.length, `${verified} verified`)}
      ${statCard('Verification queue', pendingDocs.length, pendingDocs.length ? 'Needs attention' : 'Queue is clear')}
      ${statCard('Open reports', openReports.length, `${reports.filter((r) => r.status === 'resolved').length} resolved`)}
    </div>
    <div class="dashboard-grid">
      <section class="panel"><div class="panel-head"><div><h3>Provider verification queue</h3><p>Newest applications and documents</p></div><button class="action-link" data-go="verification">View queue</button></div><div class="panel-body queue-list">
        ${pendingDocs.length ? pendingDocs.slice(0, 6).map((doc) => `<div class="queue-item"><span class="mini-avatar">${escapeHtml(initials(doc.provider_name))}</span><div class="queue-item-main"><strong>${escapeHtml(doc.provider_name)}</strong><small>${escapeHtml(doc.document_type)} · ${date(doc.created_at)}</small></div>${status(doc.status)}</div>`).join('') : emptyState('New provider documents will appear here.')}
      </div></section>
      <section class="panel"><div class="panel-head"><div><h3>Recent providers</h3><p>Latest platform registrations</p></div></div><div class="panel-body">
        ${recent.length ? recent.map((provider) => `<div class="activity-row"><span class="activity-dot"></span><div><strong>${escapeHtml(provider.provider_name)}</strong><small>${escapeHtml(provider.primary_city || 'Location pending')}</small></div><time>${date(provider.created_at)}</time></div>`).join('') : emptyState('Provider registrations will appear here.')}
      </div></section>
    </div>`;
}

function statCard(label, value, meta) { return `<article class="stat-card"><span class="stat-label">${escapeHtml(label)}</span><div class="stat-value">${escapeHtml(value)}</div><span class="stat-meta">${escapeHtml(meta)}</span></article>`; }

function toolbar(placeholder, filters = '') {
  return `<div class="toolbar"><input class="toolbar-search" data-view-search type="search" value="${escapeHtml(state.search)}" placeholder="${escapeHtml(placeholder)}">${filters}<div class="bulk-bar" id="bulk-bar" hidden><strong><span id="selected-count">0</span> selected</strong><button class="action-link" data-bulk="ban">Ban</button><button class="action-link danger" data-bulk="delete">Delete</button></div></div>`;
}

function renderVerification() {
  const query = lower(state.search);
  const docs = list('documents').filter((doc) => !query || lower(`${doc.provider_name} ${doc.document_type} ${doc.owner_email}`).includes(query));
  return `${pageIntro('Verification queue', 'Inspect provider documents and make a clear approval decision.')}${toolbar('Search provider, owner or document')}
    <div class="table-panel">${docs.length ? `<table class="data-table"><thead><tr><th>Provider</th><th>Document</th><th>Government check</th><th>Submitted</th><th>Status</th><th>Actions</th></tr></thead><tbody>${docs.map((doc) => `<tr><td><strong>${escapeHtml(doc.provider_name)}</strong><small>${escapeHtml(doc.owner_email)}</small></td><td><strong>${escapeHtml(doc.document_type)}</strong><small><a class="document-link" href="${escapeHtml(safeUrl(doc.file_url))}" target="_blank" rel="noopener">Open secure document ↗</a></small></td><td>${kraCheckSummary(doc)}</td><td>${date(doc.created_at)}</td><td>${status(doc.status)}</td><td><div class="row-actions">${doc.document_type === 'kra_pin' ? `<button class="action-link" data-action="check-kra-pin" data-id="${doc.id}" data-name="${escapeHtml(doc.provider_name)}">Check KRA PIN</button>` : ''}<button class="action-link" data-action="approve-document" data-id="${doc.id}">Approve</button><button class="action-link danger" data-action="reject-provider" data-provider="${doc.provider_id}" data-name="${escapeHtml(doc.provider_name)}">Reject with reason</button></div></td></tr>`).join('')}</tbody></table>` : emptyState('No matching verification documents.')}</div>`;
}

function kraCheckSummary(doc) {
  if (doc.document_type !== 'kra_pin') return '<span class="subtle">Not applicable</span>';
  if (!doc.kra_checked_at) return status('not checked');
  const result = doc.kra_is_valid && lower(doc.kra_pin_status) === 'active' ? 'valid' : 'attention';
  return `<div class="government-check">${status(result)}<strong>${escapeHtml(doc.kra_taxpayer_name || doc.kra_message || 'No taxpayer name')}</strong><small>${escapeHtml([doc.kra_pin_masked, doc.kra_taxpayer_type, doc.kra_pin_status, doc.kra_environment].filter(Boolean).join(' · '))}<br>Checked ${date(doc.kra_checked_at)}</small></div>`;
}

function renderProviders() {
  const query = lower(state.search);
  const rows = list('providers').filter((p) => !query || lower(`${p.provider_name} ${p.business_name} ${p.email} ${p.primary_city}`).includes(query));
  return `${pageIntro('Providers', 'Moderate provider businesses, verification and account status.')}${toolbar('Search providers')}
    <div class="table-panel">${rows.length ? `<table class="data-table"><thead><tr><th>Provider</th><th>Location</th><th>Plan</th><th>Network</th><th>Verification</th><th>Status</th><th>Actions</th></tr></thead><tbody>${rows.map((p) => `<tr><td><strong>${escapeHtml(p.provider_name)}</strong><small>${escapeHtml(p.email)}</small></td><td>${escapeHtml(p.primary_city || '—')}</td><td>${status(p.subscription_tier)}</td><td>${p.package_count} packages<small>${p.coverage_count} coverage zones</small></td><td>${status(p.is_verified ? 'verified' : 'pending')}</td><td>${status(p.status)}</td><td><div class="row-actions">${p.is_verified ? '' : `<button class="action-link" data-action="approve-provider" data-id="${p.id}" data-name="${escapeHtml(p.provider_name)}">Verify</button>`}<button class="action-link" data-action="moderate-provider" data-id="${p.id}" data-name="${escapeHtml(p.provider_name)}">Moderate</button></div></td></tr>`).join('')}</tbody></table>` : emptyState('No matching providers.')}</div>`;
}

function renderUsers() {
  const query = lower(state.search);
  const rows = list('users').filter((u) => !query || lower(`${u.first_name} ${u.last_name} ${u.email} ${u.role}`).includes(query));
  return `${pageIntro('Users', 'Manage OnaNet accounts, access and safety actions.')}${toolbar('Search name, email or role')}
    <div class="table-panel">${rows.length ? `<table class="data-table"><thead><tr><th class="check-cell"></th><th>User</th><th>Role</th><th>Joined</th><th>Profile</th><th>Status</th><th>Actions</th></tr></thead><tbody>${rows.map((u) => `<tr><td class="check-cell"><input type="checkbox" data-select-user value="${u.id}" aria-label="Select ${escapeHtml(u.email)}"></td><td><strong>${escapeHtml(`${u.first_name || ''} ${u.last_name || ''}`.trim() || 'Unnamed user')}</strong><small>${escapeHtml(u.email)}</small></td><td>${status(u.role)}</td><td>${date(u.created_at)}</td><td>${u.is_profile_complete ? 'Complete' : 'Incomplete'}<small>${u.ticket_count || 0} requests</small></td><td>${status(u.status)}</td><td><div class="row-actions">${u.status === 'banned' ? `<button class="action-link" data-action="unban-user" data-id="${u.id}">Unban</button>` : `<button class="action-link" data-action="ban-user" data-id="${u.id}" data-name="${escapeHtml(u.email)}">Ban</button>`}${u.role !== 'admin' ? `<button class="action-link" data-action="promote-user" data-id="${u.id}" data-name="${escapeHtml(u.email)}">Promote</button><button class="action-link danger" data-action="delete-user" data-id="${u.id}" data-name="${escapeHtml(u.email)}">Delete</button>` : ''}</div></td></tr>`).join('')}</tbody></table>` : emptyState('No matching users.')}</div>`;
}

function renderReports() {
  const query = lower(state.search);
  const rows = list('reports').filter((r) => !query || lower(`${r.reporter_name} ${r.reported_name} ${r.details} ${r.provider_name}`).includes(query));
  return `${pageIntro('Reports', 'Investigate customer reports and take proportionate action.')}${toolbar('Search reports')}
    <div class="table-panel">${rows.length ? `<table class="data-table"><thead><tr><th>Reported account</th><th>Reporter</th><th>Details</th><th>Created</th><th>Status</th><th>Actions</th></tr></thead><tbody>${rows.map((r) => `<tr><td><strong>${escapeHtml(r.reported_name || r.provider_name)}</strong><small>${escapeHtml(r.report_type)}</small></td><td>${escapeHtml(r.reporter_name)}</td><td><small>${escapeHtml(r.details || 'No details supplied')}</small></td><td>${date(r.created_at)}</td><td>${status(r.status)}</td><td><div class="row-actions"><button class="action-link" data-action="report-action" data-id="${r.id}" data-name="${escapeHtml(r.reported_name)}">Take action</button></div></td></tr>`).join('')}</tbody></table>` : emptyState('No matching reports.')}</div>`;
}

function renderPackages() {
  const query = lower(state.search); const rows = list('packages').filter((p) => !query || lower(`${p.name} ${p.package_name} ${p.provider_name}`).includes(query));
  return `${pageIntro('Packages', 'Review package availability across the marketplace.')}${toolbar('Search packages or providers')}<div class="table-panel">${rows.length ? `<table class="data-table"><thead><tr><th>Package</th><th>Provider</th><th>Speed</th><th>Price</th><th>Status</th><th>Action</th></tr></thead><tbody>${rows.map((p) => `<tr><td><strong>${escapeHtml(p.package_name || p.name || 'Package')}</strong></td><td>${escapeHtml(p.provider_name)}</td><td>${escapeHtml(p.speed || '—')}</td><td>${money(p.price)}</td><td>${status(p.is_available === false ? 'unavailable' : 'available')}</td><td><button class="action-link" data-action="package-availability" data-id="${p.id}" data-available="${p.is_available !== false}">${p.is_available === false ? 'Restore' : 'Hide'}</button></td></tr>`).join('')}</tbody></table>` : emptyState('No matching packages.')}</div>`;
}

function renderCoverage() {
  const query = lower(state.search); const rows = list('coverage_zones').filter((c) => !query || lower(`${c.area_name} ${c.city} ${c.provider_name}`).includes(query));
  return `${pageIntro('Coverage zones', 'See where providers currently advertise service.')}${toolbar('Search area, city or provider')}<div class="table-panel">${rows.length ? `<table class="data-table"><thead><tr><th>Area</th><th>Provider</th><th>City / county</th><th>Radius</th><th>Coordinates</th></tr></thead><tbody>${rows.map((c) => `<tr><td><strong>${escapeHtml(c.area_name)}</strong></td><td>${escapeHtml(c.provider_name)}</td><td>${escapeHtml(c.city || c.county || '—')}</td><td>${escapeHtml(c.radius_km ? `${c.radius_km} km` : '—')}</td><td><small>${escapeHtml(c.latitude ?? '—')}, ${escapeHtml(c.longitude ?? '—')}</small></td></tr>`).join('')}</tbody></table>` : emptyState('No matching coverage zones.')}</div>`;
}

function renderSubscriptions() {
  const query = lower(state.search); const rows = list('providers').filter((p) => !query || lower(`${p.provider_name} ${p.subscription_tier}`).includes(query));
  return `${pageIntro('Subscriptions', 'Control provider plans while Google Play Billing is integrated.')}${toolbar('Search provider or plan')}<div class="table-panel">${rows.length ? `<table class="data-table"><thead><tr><th>Provider</th><th>Current plan</th><th>Expires</th><th>Customers</th><th>Change plan</th></tr></thead><tbody>${rows.map((p) => `<tr><td><strong>${escapeHtml(p.provider_name)}</strong><small>${escapeHtml(p.email)}</small></td><td>${status(p.subscription_tier)}</td><td>${date(p.subscription_expires_at)}</td><td>${p.customer_count || 0}</td><td><button class="action-link" data-action="change-plan" data-id="${p.id}" data-name="${escapeHtml(p.provider_name)}" data-plan="${escapeHtml(p.subscription_tier)}">Manage plan</button></td></tr>`).join('')}</tbody></table>` : emptyState('No matching subscriptions.')}</div>`;
}

function renderInvoices() {
  const query = lower(state.search); const rows = list('invoices').filter((i) => !query || lower(`${i.invoice_number} ${i.provider_name} ${i.status}`).includes(query));
  return `${pageIntro('Invoices', 'Track provider billing records and reminders.')}${toolbar('Search invoice or provider')}<div class="table-panel">${rows.length ? `<table class="data-table"><thead><tr><th>Invoice</th><th>Provider</th><th>Plan</th><th>Amount</th><th>Due</th><th>Status</th><th>Actions</th></tr></thead><tbody>${rows.map((i) => `<tr><td><strong>${escapeHtml(i.invoice_number)}</strong><small>${escapeHtml(i.period || '')}</small></td><td>${escapeHtml(i.provider_name)}</td><td>${status(i.plan)}</td><td>${money(i.amount)}</td><td>${date(i.due_date)}</td><td>${status(i.status)}</td><td><div class="row-actions">${i.status !== 'paid' ? `<button class="action-link" data-action="invoice-paid" data-id="${i.id}">Mark paid</button><button class="action-link" data-action="invoice-remind" data-id="${i.id}">Remind</button>` : ''}</div></td></tr>`).join('')}</tbody></table>` : emptyState('No matching invoices.')}</div>`;
}

function renderRevenue() {
  const providers = list('providers');
  const invoices = list('invoices');
  const paidProviders = providers.filter((provider) => ['growth', 'pro'].includes(lower(provider.subscription_tier)));
  const mrr = paidProviders.reduce((total, provider) => total + (PLAN_USD[lower(provider.subscription_tier)] || 0), 0);
  const arr = mrr * 12;
  const collectedKes = invoices.filter((invoice) => lower(invoice.status) === 'paid').reduce((total, invoice) => total + Number(invoice.amount || 0), 0);
  const collectedUsd = collectedKes / KES_PER_USD;
  const planData = ['free', 'growth', 'pro'].map((plan) => {
    const count = providers.filter((provider) => lower(provider.subscription_tier) === plan).length;
    return { plan, count, revenue: count * PLAN_USD[plan] };
  });
  const maxRevenue = Math.max(...planData.map((item) => item.revenue), 1);
  const typeTotals = {};
  paidProviders.forEach((provider) => {
    const type = provider.provider_type || 'local_provider';
    typeTotals[type] = (typeTotals[type] || 0) + (PLAN_USD[lower(provider.subscription_tier)] || 0);
  });
  const recentPaid = invoices.filter((invoice) => lower(invoice.status) === 'paid').slice(0, 7);
  return `${pageIntro('Revenue', 'Recurring revenue and collections shown in US dollars.')}
    <div class="revenue-note"><strong>Current reporting basis:</strong> MRR and ARR are estimates derived from active provider plan assignments using Growth at ${usd(PLAN_USD.growth)} and Pro at ${usd(PLAN_USD.pro)} per month (KES converted at ${KES_PER_USD}:1). Collected revenue uses paid invoice records. Google Play Billing transaction data will replace these estimates when its server notifications are connected.</div>
    <div class="stats-grid">
      ${statCard('Estimated MRR', usd(mrr), `${paidProviders.length} paid providers`)}
      ${statCard('Estimated ARR', usd(arr), 'MRR × 12 months')}
      ${statCard('Collected revenue', usd(collectedUsd), `${invoices.filter((i) => lower(i.status) === 'paid').length} paid invoices`)}
      ${statCard('Average revenue', usd(paidProviders.length ? mrr / paidProviders.length : 0), 'per paid provider / month')}
    </div>
    <div class="revenue-grid">
      <section class="panel"><div class="panel-head"><div><h3>Monthly recurring revenue by plan</h3><p>Current active plan assignments</p></div><strong>${usd(mrr)} MRR</strong></div><div class="panel-body plan-bars">
        ${planData.map((item) => `<div><div class="plan-bar-head"><span>${escapeHtml(item.plan[0].toUpperCase() + item.plan.slice(1))} · ${item.count} providers</span><strong>${usd(item.revenue)}</strong></div><progress class="plan-progress" max="100" value="${Math.max(item.revenue / maxRevenue * 100, item.count ? 3 : 0).toFixed(1)}">${usd(item.revenue)}</progress></div>`).join('')}
      </div></section>
      <section class="panel"><div class="panel-head"><div><h3>Revenue by provider type</h3><p>Estimated monthly contribution</p></div></div><div class="panel-body revenue-list">
        ${Object.keys(typeTotals).length ? Object.entries(typeTotals).sort((a, b) => b[1] - a[1]).map(([type, value]) => `<div class="revenue-row"><div><strong>${escapeHtml(type.replaceAll('_', ' '))}</strong><small>${providers.filter((p) => p.provider_type === type && ['growth', 'pro'].includes(lower(p.subscription_tier))).length} paid providers</small></div><strong>${usd(value)}</strong></div>`).join('') : emptyState('Paid-provider revenue will appear here.')}
      </div></section>
    </div>
    <section class="panel revenue-recent"><div class="panel-head"><div><h3>Recent collected invoices</h3><p>Paid billing records converted to USD</p></div><strong>${usd(collectedUsd)} total</strong></div><div class="panel-body revenue-list">
      ${recentPaid.length ? recentPaid.map((invoice) => `<div class="revenue-row"><div><strong>${escapeHtml(invoice.provider_name)}</strong><small>${escapeHtml(invoice.invoice_number)} · ${date(invoice.created_at)}</small></div><strong>${usd(Number(invoice.amount || 0) / KES_PER_USD)}</strong></div>`).join('') : emptyState('No paid invoices have been recorded yet.')}
    </div></section>`;
}

function bindViewActions() {
  $('[data-view-search]')?.addEventListener('input', (event) => { state.search = event.target.value; render(); requestAnimationFrame(() => $('[data-view-search]')?.focus()); });
  $$('[data-go]').forEach((button) => button.addEventListener('click', () => setView(button.dataset.go)));
  $$('[data-select-user]').forEach((box) => box.addEventListener('change', () => { box.checked ? state.selected.add(box.value) : state.selected.delete(box.value); updateBulkBar(); }));
  $$('[data-action]').forEach((button) => button.addEventListener('click', () => handleAction(button)));
  $$('[data-bulk]').forEach((button) => button.addEventListener('click', () => handleBulk(button.dataset.bulk)));
  $$('.document-link').forEach((link) => link.addEventListener('click', () => {
    const idleLabel = link.textContent;
    link.classList.add('opening');
    link.replaceChildren(Object.assign(document.createElement('span'), { className: 'spinner' }), document.createTextNode('Opening document…'));
    setTimeout(() => { link.classList.remove('opening'); link.textContent = idleLabel; }, 3000);
  }));
}

function updateBulkBar() { const bar = $('#bulk-bar'); if (!bar) return; bar.hidden = state.selected.size === 0; $('#selected-count').textContent = state.selected.size; }

async function handleAction(button) {
  const { action, id, provider, name, available, plan } = button.dataset;
  if (action === 'check-kra-pin') return kraPinAction({ id, name });
  if (action === 'approve-document') return execute(() => api(`/admin/documents/${id}`, { method: 'PATCH', body: JSON.stringify({ status: 'approved' }) }), 'Document approved.');
  if (action === 'approve-provider') return confirmAction({ title: `Verify ${name}?`, description: 'All provider documents will be approved and the verified badge will become visible.', confirm: 'Verify provider', run: () => api(`/admin/providers/${id}/verification`, { method: 'POST', body: JSON.stringify({ action: 'approve' }) }), success: 'Provider verified successfully.' });
  if (action === 'reject-provider') return reasonAction({ title: `Reject ${name}?`, description: 'Explain what must be corrected before the provider submits verification again.', confirm: 'Reject verification', run: (reason) => api(`/admin/providers/${provider}/verification`, { method: 'POST', body: JSON.stringify({ action: 'reject', reason }) }), success: 'Verification rejected and provider notified.' });
  if (action === 'moderate-provider') return selectAction({ title: `Moderate ${name}`, description: 'Choose the provider’s marketplace status.', label: 'Provider status', options: [['approved', 'Approved'], ['suspended', 'Suspended'], ['banned', 'Banned']], reason: true, confirm: 'Save status', run: ({ value, reason }) => api(`/admin/providers/${id}/moderation`, { method: 'PATCH', body: JSON.stringify({ status: value, reason }) }), success: 'Provider status updated.' });
  if (action === 'ban-user') return reasonAction({ title: `Ban ${name}?`, description: 'The reason is recorded for the moderation team.', confirm: 'Ban account', run: (reason) => api(`/admin/users/${id}/moderation`, { method: 'POST', body: JSON.stringify({ action: 'ban', reason }) }), success: 'User account banned.' });
  if (action === 'unban-user') return execute(() => api(`/admin/users/${id}/moderation`, { method: 'POST', body: JSON.stringify({ action: 'unban' }) }), 'User account restored.');
  if (action === 'promote-user') return confirmAction({ title: `Promote ${name}?`, description: 'This grants full access to OnaNet Control. Only promote trusted team members.', confirm: 'Promote to admin', run: () => api(`/admin/users/${id}/role`, { method: 'POST', body: JSON.stringify({ action: 'promote_admin' }) }), success: 'User promoted to administrator.' });
  if (action === 'delete-user') return reasonAction({ title: `Permanently delete ${name}?`, description: 'This removes the profile and Supabase login. This action cannot be undone.', confirm: 'Delete account', danger: true, run: (reason) => api(`/admin/users/${id}/delete`, { method: 'POST', body: JSON.stringify({ action: 'delete', reason }) }), success: 'Account deleted successfully.' });
  if (action === 'report-action') return selectAction({ title: `Resolve report about ${name}`, description: 'Choose a proportionate moderation action and record your reasoning.', label: 'Action', options: [['investigate', 'Investigate'], ['warn', 'Warn provider'], ['suspend', 'Suspend provider'], ['ban', 'Ban provider'], ['dismiss', 'Dismiss report']], reason: true, confirm: 'Apply action', run: ({ value, reason }) => api(`/admin/reports/${id}/action`, { method: 'POST', body: JSON.stringify({ action: value, reason }) }), success: 'Report action applied.' });
  if (action === 'package-availability') return execute(() => api(`/admin/packages/${id}`, { method: 'PATCH', body: JSON.stringify({ action: 'availability', value: available === 'true' ? 'false' : 'true' }) }), available === 'true' ? 'Package hidden.' : 'Package restored.');
  if (action === 'change-plan') return selectAction({ title: `Change ${name} plan`, description: `Current plan: ${plan}.`, label: 'Plan', options: [['free', 'Free'], ['growth', 'Growth'], ['pro', 'Pro']], confirm: 'Update plan', run: ({ value }) => api(`/admin/subscriptions/${id}/action`, { method: 'POST', body: JSON.stringify({ action: value === 'free' ? 'downgrade' : 'upgrade', value }) }), success: 'Subscription updated.' });
  if (action === 'invoice-paid') return execute(() => api(`/admin/invoices/${id}/action`, { method: 'POST', body: JSON.stringify({ action: 'paid' }) }), 'Invoice marked as paid.');
  if (action === 'invoice-remind') return execute(() => api(`/admin/invoices/${id}/action`, { method: 'POST', body: JSON.stringify({ action: 'remind' }) }), 'Invoice reminder created.');
}

function kraPinAction({ id, name }) {
  openModal({
    kicker: 'Government verification',
    title: `Check ${name} with KRA`,
    description: 'Enter the PIN exactly as shown on the submitted certificate. This check does not approve the provider automatically.',
    fields: '<div class="modal-fields"><label for="kra-pin">KRA PIN</label><input id="kra-pin" maxlength="11" autocomplete="off" autocapitalize="characters" placeholder="A123456789Z"><small class="field-help">The full PIN is sent securely to KRA and is not retained by OnaNet.</small></div>',
    confirm: 'Check KRA PIN',
    onConfirm: () => {
      const kraPin = $('#kra-pin').value.trim().toUpperCase();
      if (!/^[AP][0-9]{9}[A-Z]$/.test(kraPin)) return modalError('Enter a valid KRA PIN, for example A123456789Z.');
      executeModal(
        () => api(`/admin/documents/${id}/kra-pin-check`, { method: 'POST', body: JSON.stringify({ kra_pin: kraPin }) }),
        'KRA PIN check completed.'
      );
    },
  });
}

async function handleBulk(action) {
  const users = list('users').filter((user) => state.selected.has(user.id) && user.role !== 'admin');
  if (!users.length) return toast('Select at least one non-admin account.', true);
  const title = action === 'delete' ? `Delete ${users.length} accounts?` : `Ban ${users.length} accounts?`;
  reasonAction({ title, description: 'The same moderation reason will be recorded for every selected account.', confirm: action === 'delete' ? 'Delete selected' : 'Ban selected', danger: action === 'delete', run: async (reason) => { for (const user of users) await api(`/admin/users/${user.id}/${action === 'delete' ? 'delete' : 'moderation'}`, { method: 'POST', body: JSON.stringify({ action, reason }) }); }, success: `${users.length} accounts ${action === 'delete' ? 'deleted' : 'banned'}.` });
}

function openModal({ kicker = 'Confirm action', title, description, fields = '', confirm = 'Confirm', danger = false, onConfirm }) {
  $('#modal-kicker').textContent = kicker; $('#modal-title').textContent = title; $('#modal-description').textContent = description; $('#modal-fields').innerHTML = fields;
  $('#modal-error').hidden = true; $('#modal-confirm').textContent = confirm; $('#modal-confirm').className = danger ? 'danger-button' : 'primary-button'; $('#modal-backdrop').hidden = false;
  $('#modal-confirm').onclick = onConfirm; requestAnimationFrame(() => $('#modal-fields input, #modal-fields select, #modal-confirm')?.focus());
}

function closeModal() { $('#modal-backdrop').hidden = true; $('#modal-confirm').onclick = null; }
function confirmAction({ title, description, confirm, run, success, danger = false }) { openModal({ title, description, confirm, danger, onConfirm: () => executeModal(run, success) }); }
function reasonAction({ title, description, confirm, run, success, danger = false }) { openModal({ title, description, confirm, danger, fields: '<div class="modal-fields"><label for="action-reason">Reason</label><textarea id="action-reason" minlength="5" placeholder="Write a clear reason (at least 5 characters)"></textarea></div>', onConfirm: () => { const reason = $('#action-reason').value.trim(); if (reason.length < 5) return modalError('Enter a clear reason of at least 5 characters.'); executeModal(() => run(reason), success); } }); }
function selectAction({ title, description, label, options, reason = false, confirm, run, success }) { const optionHtml = options.map(([value, text]) => `<option value="${escapeHtml(value)}">${escapeHtml(text)}</option>`).join(''); openModal({ title, description, confirm, fields: `<div class="modal-fields"><label for="action-select">${escapeHtml(label)}</label><select id="action-select">${optionHtml}</select>${reason ? '<label for="action-reason">Reason or internal note</label><textarea id="action-reason" placeholder="Add context for this decision"></textarea>' : ''}</div>`, onConfirm: () => executeModal(() => run({ value: $('#action-select').value, reason: $('#action-reason')?.value.trim() || null }), success) }); }
function modalError(message) { $('#modal-error').textContent = message; $('#modal-error').hidden = false; }

async function executeModal(run, success) {
  const button = $('#modal-confirm');
  const label = $('#modal-kicker').textContent === 'Government verification' ? 'Checking with KRA…' : 'Saving…';
  setButtonBusy(button, true, label);
  $('#modal-cancel').disabled = true;
  $('#modal-close').disabled = true;
  try { await run(); closeModal(); await loadSnapshot(); renderIdentity(); render(); toast(success); }
  catch (error) { modalError(error.message); }
  finally { setButtonBusy(button, false); $('#modal-cancel').disabled = false; $('#modal-close').disabled = false; }
}

async function execute(run, success) {
  setLoading(true, 'Saving changes…');
  try { await run(); await loadSnapshot(); renderIdentity(); render(); toast(success); }
  catch (error) { toast(error.message, true); }
  finally { setLoading(false); }
}

function toast(message, error = false) { const item = document.createElement('div'); item.className = `toast${error ? ' error' : ''}`; item.textContent = message; $('#toast-stack').append(item); setTimeout(() => item.remove(), 4300); }
function setView(view) { state.view = view; state.search = ''; $('#sidebar').classList.remove('open'); render(); }

async function signOut(askForConfirmation = true) {
  if (askForConfirmation) {
    openModal({
      kicker: 'Secure session',
      title: 'Sign out of OnaNet Control?',
      description: 'Your administrator session will end on this device. You can sign in again at any time.',
      confirm: 'Sign out',
      onConfirm: async () => {
        const button = $('#modal-confirm');
        setButtonBusy(button, true, 'Signing out…');
        $('#modal-cancel').disabled = true;
        $('#modal-close').disabled = true;
        try {
          await signOut(false);
          closeModal();
        } catch (error) {
          modalError(error.message || 'Could not sign out. Try again.');
        } finally {
          setButtonBusy(button, false);
          $('#modal-cancel').disabled = false;
          $('#modal-close').disabled = false;
        }
      },
    });
    return;
  }
  await state.supabase.auth.signOut();
  state.session = null;
  state.data = {};
  $('#app-shell').hidden = true;
  $('#auth-shell').hidden = false;
}

$('#login-form').addEventListener('submit', async (event) => {
  event.preventDefault(); const button = event.submitter; const error = $('#login-error'); error.hidden = true; $('#login-notice').hidden = true; setButtonBusy(button, true, 'Signing in…');
  try {
    const { data, error: authError } = await state.supabase.auth.signInWithPassword({ email: $('#admin-email').value.trim(), password: $('#admin-password').value });
    if (authError) throw authError; await enterApp(data.session);
  } catch (failure) { await state.supabase.auth.signOut(); error.textContent = failure.message.includes('Admin access') ? 'This account is not authorised for OnaNet Control.' : failure.message; error.hidden = false; }
  finally { setButtonBusy(button, false); }
});
$('#toggle-password').addEventListener('click', () => { const input = $('#admin-password'); input.type = input.type === 'password' ? 'text' : 'password'; $('#toggle-password').textContent = input.type === 'password' ? 'Show' : 'Hide'; });
$('#forgot-password').addEventListener('click', async () => {
  const emailInput = $('#admin-email');
  const email = emailInput.value.trim();
  const error = $('#login-error');
  const notice = $('#login-notice');
  error.hidden = true;
  notice.hidden = true;
  if (!email || !emailInput.checkValidity()) {
    error.textContent = 'Enter your admin email address first.';
    error.hidden = false;
    emailInput.focus();
    return;
  }
  const button = $('#forgot-password');
  button.disabled = true;
  button.textContent = 'Sending reset link…';
  try {
    const { error: resetError } = await state.supabase.auth.resetPasswordForEmail(email, {
      redirectTo: 'https://onanet.app/reset-password',
    });
    if (resetError) throw resetError;
    notice.textContent = 'If that email belongs to an OnaNet account, a secure password-reset link has been sent.';
    notice.hidden = false;
  } catch (failure) {
    error.textContent = failure.message || 'The reset link could not be sent. Try again shortly.';
    error.hidden = false;
  } finally {
    button.disabled = false;
    button.textContent = 'Forgot password?';
  }
});
$('#main-nav').addEventListener('click', (event) => { const button = event.target.closest('[data-view]'); if (button) setView(button.dataset.view); });
$('#refresh-button').addEventListener('click', () => execute(async () => { await loadSnapshot(); }, 'Control data refreshed.'));
$('#global-search').addEventListener('input', (event) => { state.search = event.target.value; render(); });
$('#menu-button').addEventListener('click', () => $('#sidebar').classList.toggle('open'));
$('#signout-button').addEventListener('click', () => signOut());
$('#modal-close').addEventListener('click', closeModal); $('#modal-cancel').addEventListener('click', closeModal);
$('#modal-backdrop').addEventListener('click', (event) => { if (event.target === $('#modal-backdrop')) closeModal(); });
document.addEventListener('keydown', (event) => { if (event.key === 'Escape') { closeModal(); $('#sidebar').classList.remove('open'); } });

initialise().catch((error) => { $('#login-error').textContent = error.message; $('#login-error').hidden = false; });
