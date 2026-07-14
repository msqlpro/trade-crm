# Routine: Update Customers (KashFlow → Supabase Delta Sync)

**Last revised: 14 Jul 2026** — MAJOR: Step 6.6 is now **diff-only**. It previously rewrote the six spend fields for all ~4,166 invoiced customers on EVERY run, regardless of whether anything had changed. That took ~45 minutes of tool calls per run and generated ~8,000 junk audit_log records nightly (audit_log had reached 1.3 GB / 97% of the database, pushing the project over its Supabase storage limit). It now reads the aggregate, reads the current Supabase values, compares in memory, and writes only the customers whose figures actually differ — typically tens, not thousands. Also fixed Step 5: it was writing to `created_count` / `updated_count` / `unchanged_count` / `error_count` / `total_rows`, none of which exist on `customer_sync_log` (real columns: `rows_inserted` / `rows_updated` / `rows_unchanged` / `errors` / `rows_checked`), which is why `duration_ms` and the counts were coming back null/0. Step 6.7 is now diff-aware too.

**Last revised: 26 Jun 2026** — added Step 6.7: every run, refresh `last_invoice_date` / `last_invoice_number` / `last_invoice_permalink` for customers in the **Ordered** pipeline stage, from their latest non-quote invoice (any paid status). Feeds the dashboard "Reorder Call List" so the 5-week reminder resets on ANY new order, paid or not. Scoped to the tiny Ordered set so it always completes (Step 6.6's full paged refresh was leaving later-alphabet customers stale). New Supabase columns: `last_invoice_date date`, `last_invoice_number integer`, `last_invoice_permalink text`.

**Previously revised: 29 May 2026** — added Step 6.6: nightly refresh of order/spend figures (last_order_date, first_invoiced, invoice_count, all_time_spend, last_12m_spend, prior_12m_spend) computed live from the `invoice` table (ex-VAT Net, quotes excluded, rolling 12m windows). Previously these were a stale one-off April upload.

**Previously revised: 19 April 2026** — switched source from `customers` to `five_minute_customers` (cleaner, geocoded), updated asterisk handling to preserve prefix, added lat/lng/formatted_address/territorial_protection.

## Setup instructions

1. Go to https://claude.ai/code/routines → open the existing **Update Customers** routine (or **New routine** if not yet created).
2. Name: **Update Customers**
3. Model: **Claude Sonnet 4.6** (fast, cheap, plenty capable).
4. Repositories: none required.
5. Connectors to enable:
   - **Mysql Writer** (Dave's MCP — for reading `brainbox_candy`)
   - **Supabase** (for writing to the CRM project `ypfwecopdsielnouxwzv`)
6. Triggers:
   - **API** (for the CRM button to call) — generates the endpoint URL and bearer token
   - **Scheduled** (optional) — 07:00 daily (GMT+1), so data is fresh when you start
7. Replace the entire prompt field with the contents of `update-customers-PROMPT-ONLY.txt` and save.
8. If routine already exists and you're just updating the prompt, do NOT regenerate the API endpoint/token — reuse the existing ones in `app_settings`.

## After saving

If this is a first-time create (not an update):
1. Copy the API trigger endpoint URL and bearer token.
2. In Supabase SQL editor, upsert into `app_settings`:

```sql
INSERT INTO app_settings (key, value) VALUES
  ('update_customers_routine_endpoint', '<ENDPOINT_URL>'),
  ('update_customers_routine_token', '<BEARER_TOKEN>')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
```

The Supabase edge function `trigger-routine` reads these at call time.

## What changed vs the first version

| Aspect | v1 (18 Apr) | v2 (19 Apr, current) |
|---|---|---|
| Source table | `brainbox_candy.customers` (raw, 7,831 rows) | `brainbox_candy.five_minute_customers` (cleaned + geocoded, ~7,077 rows) |
| Single-asterisk (`*`) | Excluded by `Code NOT LIKE '*%'` | Imported but force `hidden=true, status='inactive'` (defensive) |
| Double-asterisk (`**`) | Not handled | Set `territorial_protection=true`, keep prefix in name |
| lat/lng | Not synced | Populated from Dave's geocoding |
| formatted_address | Not synced | Populated |
| Delta cursor | `Updated >= X OR Created >= X` | `last_updated >= X` (single column, cleaner) |
| Address mapping | `Address1-4` | `Street_Address`, `Street_Address_2_Town`, `Town`, `Town_County` |
| Store type | `ExtraText1` | `Store_Type` (direct column) |
