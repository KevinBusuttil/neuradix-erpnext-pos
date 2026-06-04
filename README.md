# NeuroPOS

An offline-capable Flutter point-of-sale app (Windows + Android) that replaces the
**Mobile POS** desk page in the [CCJ](https://github.com/KevinBusuttil/ccj) Frappe/ERPNext v15
app.

NeuroPOS is **online-first with a thin offline shim** backed by SQLite: the CCJ server
stays authoritative for catalogue, stock, totals and submission while online, and a local
SQLite layer keeps a draft, an outbound invoice queue, and a read-only catalogue snapshot
so a cashier can keep selling through a mid-shift network drop.

See [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md) for the full analysis and
roadmap, and [`docs/SETUP.md`](docs/SETUP.md) for first-time setup.

## Status

Phase 0 scaffold. The cross-platform Dart code (`lib/`) is hand-authored; the platform
runner folders (`android/`, `windows/`) are generated locally — see `docs/SETUP.md`.

## Quick start

```bash
# 1. Generate platform folders without touching lib/ (run once, locally):
flutter create . --platforms=windows,android --project-name neuropos

# 2. Fetch dependencies:
flutter pub get

# 3. Generate drift / riverpod code:
dart run build_runner build --delete-conflicting-outputs

# 4. Run:
flutter run -d windows      # or: flutter run -d <android-device>
```

## Architecture

```
lib/
  core/         config, DI, result types
  data/
    local/      drift database (queue / draft / snapshot)
    remote/     FrappeClient (dio)
    repositories/
  domain/
    models/     Item, Customer, Cart, Invoice, Payment, PosProfile
    pricing/    TaxEngine (offline fallback for ERPNext totals)
  sync/         SyncManager, connectivity, outbound queue flush
  features/     auth, opening, pos (catalog + cart), payment, orders, settings
```

## Server dependencies (CCJ)

- Reuses existing whitelisted methods: `get_items`, `get_stock_availability`,
  `compute_si_taxes`, `submit_sales_invoice`, etc.
- Adds (on the same branch in the `ccj` repo):
  - `custom_neuropos_uuid` field on Sales Invoice for **idempotent submit**.
  - `ccj.neuropos.snapshot.pull` for the offline-shim snapshot cache.
