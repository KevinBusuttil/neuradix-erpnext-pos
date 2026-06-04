# NeuroPOS — Implementation Plan

A Flutter application (Windows + Android) that replaces the **Mobile POS** in the
CCJ app (a custom Frappe/ERPNext v15 app). NeuroPOS reproduces all Mobile POS
functionality and is **online-first with a thin offline shim** backed by SQLite
(replacing the current brittle `localStorage` layer).

- **Target repos / branch:** `KevinBusuttil/neuradix-erpnext-pos` (Flutter app) and
  `KevinBusuttil/ccj` (server endpoints), both on `claude/wonderful-fermi-slGgV`.
- **Status:** planning. This document is committed first; code scaffolding follows
  on approval.

---

## 1. Analysis of the existing CCJ Mobile POS

The Mobile POS is a custom **Frappe Desk Page** at `ccj/ccj/page/mobile_pos/`, a
fork of ERPNext v15's standard `point_of_sale` page, re-namespaced under
`ccj.MobilePOS` and extended for CC&J (Malta 18% VAT, RRP/ex-VAT display, credit
sales, a lightweight offline layer). Roughly 5,200 lines of jQuery/Frappe JS plus
~600 lines of Python.

### 1.1 Component map (the screens to re-create in Flutter)

| Module | Lines | Responsibility |
|---|---|---|
| `pos_controller.js` | 989 | Orchestrator. Owns the in-memory Sales Invoice `frm`, opening/closing entry flow, cart-update logic, stock checks, returns, tax recompute |
| `pos_item_cart.js` | 1,453 | Cart UI, customer selector, numpad, discounts, totals, offline draft/queue glue |
| `pos_item_selector.js` | 403 | Item grid, search, barcode scanning (`onscan.js`) |
| `pos_item_details.js` | 490 | Per-line editor: qty, rate, UOM, discount, warehouse, serial/batch, ex-VAT rate |
| `pos_payment.js` | 399 | Payment modes, numpad, change calc, submit |
| `pos_past_order_summary.js` | 424 | Receipt view, print, email, return/edit/delete |
| `pos_past_order_list.js` | 125 | Recent orders search list |
| `pos_number_pad.js` | 59 | Reusable numpad widget |
| `pos_offline-lite.js` | 237 | `localStorage` draft autosave + offline order queue |
| `mobile_pos.py` | 524 | Server API: item search, price, opening entry, taxes, `submit_sales_invoice` |

### 1.2 Key behaviours that drive the Flutter design

- **Document model:** builds a standard **Sales Invoice** (NOT POS Invoice) with
  `is_pos = 0` and a custom flag **`custom_is_mobile_pos = 1`**. Submitted via
  `frm.savesubmit()` online, or queued and POSTed to `submit_sales_invoice` offline.
- **Server-authoritative totals:** online, taxes/totals come from `compute_si_taxes`
  (runs ERPNext's `calculate_taxes_and_totals` server-side). Offline it falls back to
  a crude `calculate_totals_offline()` that does **not** compute VAT properly — a known
  weakness NeuroPOS fixes with a proper Dart tax engine fallback.
- **VAT:** Malta 18% baked in as `/ 1.18` for ex-VAT display. Proper VAT codes resolved
  server-side via `ccj.utils.vat_codes` from Item Tax Templates.
- **Payment normalization:** `submit_sales_invoice` re-derives `paid_amount`, detects
  **credit sales** (zero payment / "Credit" mode / Debtors account → invoice left
  outstanding), and handles returns and overpayment/change.
- **`CustomSalesInvoice` override** relaxes qty-sign validation for mobile POS, sets
  Sales Person from the logged-in user, and populates RRP fields.
- **Offline today is shallow:** only `localStorage` for a single draft + a FIFO submit
  queue. No catalogue, prices, stock, or customers are cached, so the item grid, search,
  and customer lookup are dead without a network. NeuroPOS replaces this shim with SQLite.

### 1.3 Server endpoints the POS depends on

**CCJ custom** (`ccj.ccj.page.mobile_pos.mobile_pos`): `get_items`,
`search_for_serial_or_batch_or_barcode_number`, `item_group_query`,
`get_pos_profile_data`, `compute_si_taxes`, `submit_sales_invoice`,
`get_past_order_list`, `set_customer_info`.

**ERPNext core:** `check_opening_entry`, `create_opening_voucher`,
`get_stock_availability`, `make_sales_return`, `get_pos_reserved_serial_nos`,
`get_loyalty_program_details_with_points`, `pos_profile_query`, `scan_barcode`.

### 1.4 Relevant custom fields

- Sales Invoice: `custom_is_mobile_pos`, `custom_order_source`, `payment_method`,
  `custom_paid_by`, `custom_invoice_barcode`, `custom_printed`, `custom_admin_remarks`.
- Sales Invoice Item: `custom_rrp`, `custom_rrp_inc_vat`.
- POS Profile: `allow_uom_change`, `allow_posting_without_payments`.
- Customer: `custom_allow_credit`, `custom_loyalty_card_no`, `custom_show_on_pos`, etc.

### 1.5 Out of scope for v1 (deferred)

Adjacent mobile features that live in separate Desk pages and share the field context
but are **not** part of NeuroPOS v1:
- `ccj/ccj/api/customer_payment.py` — collect against outstanding invoices (custom
  **Customer Payment** doctype).
- `ccj/ccj/api/delivery_route.py` — scan a Sales Invoice onto a **Delivery Route**.

The SQLite schema and sync layer are designed so these can be added later without rework.

---

## 2. Architecture decisions

| Decision | Choice |
|---|---|
| Scope (v1) | **POS sell flow only.** Customer Payment and Delivery Route deferred. |
| Connectivity | **Online-first with a thin offline shim.** Server stays authoritative. |
| Server sync API | Keep `custom_neuropos_uuid` on Sales Invoice for **idempotent submit**; add one lightweight `neuropos.snapshot.pull` for the shim cache. Live reads reuse existing `get_items` / `get_stock_availability`. |
| Tax/totals | Online uses `compute_si_taxes` (authoritative). A **Dart `TaxEngine` port** of ERPNext's calc is the **offline fallback only**, validated by a parity harness. |

### 2.1 Online-first model

**Primary path (online):** the app talks live to the CCJ server for item
grid/search, stock availability, customer lookup, totals (`compute_si_taxes`), and
submit (`frm.savesubmit` / `submit_sales_invoice`).

**SQLite shim (only things persisted locally):**
- **Outbound invoice queue** — robust replacement for the `localStorage` queue;
  survives restart, carries an idempotency UUID, auto-flushes on reconnect.
- **Current draft** — replaces the `pos_draft_v1` localStorage draft (autosave/restore).
- **Last-seen snapshot cache** — lightweight read-only copy of catalogue + prices +
  customers + POS profile from the last successful online session, so a mid-shift
  network drop still allows browse + cart + queue. A snapshot, not a delta-sync mirror.
- **Offline `TaxEngine`** — used only when the server is unreachable.

---

## 3. Flutter project architecture

**Stack:** Flutter (Windows + Android), Dart 3, SQLite via **drift** (typed, reactive,
migrations), **Riverpod** state management, **dio** HTTP, feature-first layering.

```
lib/
  core/            # config, di, theme, errors, result types
  data/
    local/         # drift db: daos, tables, migrations (queue/draft/snapshot)
    remote/        # FrappeClient (dio): auth, REST + custom methods
    repositories/  # CatalogRepo, CustomerRepo, InvoiceRepo, SyncRepo
  domain/
    models/        # Item, Customer, Cart, Invoice, Payment, TaxLine...
    pricing/       # TaxEngine (ERPNext port), DiscountEngine, RoundingEngine
    services/      # OpeningEntryService, StockService, BarcodeService
  features/
    auth/  opening/  catalog/  cart/  item_details/
    payment/  orders/  sync/  settings/
  sync/            # SyncManager, queue, conflict, connectivity
```

### 3.1 Frappe connectivity
- Auth: token (`api_key:api_secret`) preferred over session (longevity offline).
  Stored via `flutter_secure_storage`.
- Existing whitelisted methods reused via `/api/method/...`; bulk reads via
  `/api/resource/...`.

---

## 4. SQLite schema (thin shim)

Online-first means the local DB only holds the shim — not a full catalogue mirror.

```
-- outbound + draft (the heart of the shim)
invoices(local_uuid PK, server_name, customer, posting_date, status,
         is_return, return_against, doc_json, totals_json,
         sync_state[draft|queued|syncing|synced|error], error_msg, created_at)
invoice_items(local_uuid, idx, item_code, qty, uom, conversion_factor,
              rate, price_list_rate, discount_percentage, amount, warehouse,
              batch_no, serial_no)
invoice_payments(local_uuid, mode_of_payment, type, amount)
invoice_taxes(local_uuid, idx, description, rate, tax_amount, account_head)

-- read-only snapshot cache (graceful degradation only)
snap_items(item_code PK, item_name, description, stock_uom, image,
           is_stock_item, has_batch_no, has_serial_no, item_group)
snap_item_uoms(item_code, uom, conversion_factor)
snap_item_barcodes(barcode PK, item_code, uom)
snap_item_prices(item_code, price_list, uom, batch_no, rate, currency)
snap_item_tax(item_code, tax_template, rate, vat_code)   -- for offline TaxEngine
snap_stock(item_code, warehouse, actual_qty, updated_at) -- advisory
snap_customers(name PK, customer_name, mobile_no, email_id, customer_group,
               loyalty_program, allow_credit)
pos_profile(name PK, json)
modes_of_payment(name, type, default_account)

-- bookkeeping
sync_log(id, entity, action, status, at, detail)
settings(key PK, value)   -- token, site_url, last_snapshot_at, device_id
```

drift's reactive streams drive automatic UI refresh for cart/queue; migrations are
versioned.

---

## 5. Feature-parity checklist (CCJ Mobile POS -> NeuroPOS)

- [ ] POS Opening Entry check/create (per user, balances per mode of payment)
- [ ] POS Profile load (warehouse, price list, customer groups, allowed-edit flags:
      rate/discount/UOM, hide_images, auto_add_item, hide_unavailable_items)
- [ ] Item grid with stock indicator pill (green/orange/red), price + ex-VAT (RRP) line
- [ ] Search by name/code/custom POS search fields; barcode/serial/batch scan
      (HID scanner + camera)
- [ ] Customer selector filtered by allowed customer groups; inline edit
      email/mobile/loyalty; recent transactions
- [ ] Add to cart, qty +/- , numpad-driven qty & discount entry
- [ ] Item details: rate (if allowed), UOM + conversion factor, line discount (value<->%),
      warehouse, actual_qty, ex-VAT rate, serial/batch selection (incl. auto-select &
      batch splitting)
- [ ] Cart-level additional discount (% on Grand Total)
- [ ] Tax/total engine (online: compute_si_taxes; offline: Dart TaxEngine fallback)
- [ ] Stock availability checks + negative-stock setting
- [ ] Payment screen: multiple modes, change calc, credit sale detection, complete order
- [ ] Returns (make_sales_return equivalent), edit draft, delete draft
- [ ] Receipt summary, print (thermal/A4), email receipt
- [ ] Recent orders list + search
- [ ] Save-as-draft / restore pending order
- [ ] Thin offline shim: SQLite draft + outbound queue + snapshot cache + auto-flush
      on reconnect + idempotent submit
- [ ] POS Closing Entry
- [ ] Multi-currency display, loyalty points redemption

---

## 6. Server work in `ccj` (Phase 0)

1. **Custom field** `custom_neuropos_uuid` (Data, unique) on Sales Invoice — client
   generates a UUID per invoice so retried submits are idempotent (added to fixtures).
2. **`submit_sales_invoice`** — accept and dedupe on `custom_neuropos_uuid`: if an SI
   already exists with that UUID, return it instead of inserting a duplicate.
3. **`neuropos/snapshot.py` -> `pull(pos_profile)`** — one lightweight whitelisted
   method returning the snapshot payload (items + uoms + barcodes + prices + item tax +
   stock + customers + pos profile + modes of payment) for the offline shim cache.

No other CCJ server changes are required for parity; live reads reuse `get_items`,
`get_stock_availability`, `compute_si_taxes`, etc.

---

## 7. Phased delivery plan

**Phase 0 - Foundations**
Flutter scaffold (Windows + Android), drift DB (queue/draft/snapshot tables),
Riverpod, `FrappeClient` with auth, settings/device-id, CI.
`ccj`: add `custom_neuropos_uuid` + `neuropos.snapshot.pull` + idempotent submit.

**Phase 1 - Online catalog + cart**
Live item grid/search/stock, customer select, cart, item details (qty/UOM/discount/
warehouse/serial-batch).

**Phase 2 - Totals + payment + submit**
Online `compute_si_taxes`, payment modes + change + credit detection, build SI JSON,
submit online. *Milestone: end-to-end online sale.*

**Phase 3 - Thin offline shim**
SQLite draft + outbound queue + snapshot cache + reconnect auto-flush + Dart
`TaxEngine` fallback. Parity harness: feed identical carts to `compute_si_taxes` and
assert the Dart engine matches to the cent. *Milestone: graceful mid-shift offline.*

**Phase 4 - Orders, returns, receipts**
Recent orders, summary, returns, draft edit/delete, printing (esc/pos + PDF), email.

**Phase 5 - Hardening & packaging**
Serial/batch edge cases, loyalty, error UX, perf, packaging (MSIX/installer + signed
APK), field testing.

*Indicative total ~ 8-10 weeks for one developer (reduced from offline-first by ~2-3
weeks), parallelizable.*

---

## 8. Key risks / decisions

- **Tax-engine fidelity** (offline fallback) — mitigate with the automated parity test
  harness before enabling offline submit.
- **Stock truth offline** — cached `actual_qty` is advisory; concurrent multi-device
  sales can oversell. Policy: warn-only offline, server-final-check on sync.
- **Submission idempotency** — `custom_neuropos_uuid` prevents duplicates on flaky
  networks.
- **Serial/batch offline** — server reserves serials; v1 may restrict serialized items
  to online-only.
- **Auth longevity** — token over session for long offline periods.

---

## 9. Next steps

1. Approve this plan.
2. Scaffold the Flutter project + drift shim schema + `FrappeClient` skeleton in
   `neuradix-erpnext-pos`.
3. Add `custom_neuropos_uuid` + `neuropos.snapshot.pull` + idempotent submit in `ccj`.
4. Build Phase 1/2 (online sell flow) as the first vertical slice.
