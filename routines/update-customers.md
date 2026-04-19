# Routine: Update Customers (KashFlow → Supabase Delta Sync)

**Last revised: 19 April 2026** — switched source from `customers` to `five_minute_customers` (cleaner, geocoded), updated asterisk handling to preserve prefix, added lat/lng/formatted_address/territorial_protection.

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
