# Routine: Update Customers (KashFlow → Supabase Delta Sync)

## Setup instructions

1. Go to https://claude.ai/code/routines → **New routine**
2. Name: **Update Customers**
3. Model: **Claude Sonnet 4.6** (fast, cheap, plenty capable for this)
4. Repositories: none required
5. Connectors to enable:
   - **Mysql Writer** (Dave's MySQL MCP — for reading brainbox_candy)
   - **Supabase** (for writing to the CRM project)
6. Triggers:
   - **API** (for the CRM button to call) — this generates the endpoint URL and bearer token
   - **Scheduled** (optional, weekday mornings) — 07:00 daily, so the data is fresh when you start work
7. Paste the prompt below into the prompt field and save.

## Prompt (copy-paste exactly)

```
You are performing a KashFlow → Supabase customer delta sync for the Brainbox Candy Trade CRM. Work silently and efficiently. Report only the final summary.

# Context
- MySQL database: brainbox_candy (via Mysql Writer MCP). Customers live in `customers` table.
- Supabase project: ypfwecopdsielnouxwzv. Customers live in `customers` table.
- The two tables are linked by KashFlow Code (KF code). Example: KRIS09, FEWI01.
- Only sync rows where Code does NOT start with '*' (those are permanently excluded).

# CRM-OWNED columns — NEVER touch these
pipeline_stage, hidden, assigned_to, tags, mailerlite_id, last_contacted_at,
notes (unless the row is brand new), ml_any_subscribed, ml_group_names,
mailerlite_subscribed, mailerlite_status, mailerlite_subscriber_id,
mailerlite_group_names, mailerlite_refreshed_at

# KashFlow-owned columns — sync these
kf_code (from Code), company_name (from Name), address_1-4, postcode,
country_name, phone (from Telephone), mobile, website, payment_terms,
discount, source (from customer_sources lookup table), store_type (from ExtraText1),
vat_number (from VATNumber), customer_notes (from Notes),
delivery_address_1-4, delivery_postcode

# Steps

## Step 1 — Determine sync mode
Read Supabase sync_state for key='kashflow_customer_last_sync' and key='kashflow_customer_last_full_sweep'.

- If last_sync IS NULL → **full sweep** mode (first run)
- If today is Sunday AND last_full_sweep < today → **full sweep** mode
- Otherwise → **delta** mode

## Step 2 — Pull MySQL data
- **Delta mode**: `WHERE (Updated >= '<last_sync - 1 day>' OR Created >= '<last_sync - 1 day>') AND Code NOT LIKE '*%'`
- **Full sweep**: `WHERE Code NOT LIKE '*%'`

Map columns:
- Code → kf_code
- Name → company_name
- Telephone → phone
- Address1-4 → address_1-4, etc.
- VATNumber → vat_number
- Notes → customer_notes (preserve CRM notes; only use for brand-new records)
- ExtraText1 → store_type
- Look up source name by joining to customer_sources on id

## Step 3 — Fetch existing Supabase rows
Select only kf_code + the KashFlow-owned columns for the KF codes returned in step 2. Use IN(...) in chunks of 500 if needed.

## Step 4 — Compare and apply
For each MySQL row:
- If no matching Supabase row by kf_code → INSERT new record with status='prospect' (leave CRM-owned columns at defaults)
- If matching row exists → compare each KashFlow-owned column. If any differ, build an UPDATE payload with ONLY changed columns. Write updated_at = now().
- If no differences → skip (counts as unchanged)

## Step 5 — Log the run
INSERT into customer_sync_log:
- triggered_by: 'routine' (or 'routine-cron' if scheduled)
- filename: 'kashflow-delta-' || sync_mode || '-' || now_iso
- total_rows: count of MySQL rows considered
- created_count, updated_count, unchanged_count, error_count
- duration_ms
- changes_summary: array of {kf_code, changed_fields:[...]} — cap at 200 entries
- errors: array — cap at 50

## Step 6 — Update sync_state
UPDATE sync_state SET value_ts = now(), updated_at = now()
  WHERE key = 'kashflow_customer_last_sync';

If this was a full sweep, also update 'kashflow_customer_last_full_sweep'.

## Step 7 — Final narrative summary
Return a concise narrative:

Mode: [delta | full sweep]
Rows considered: X
  → Updated: Y  (brief list of the most notable field changes)
  → New: Z  (brief list of company names)
  → Unchanged: W
  → Errors: E
Duration: N seconds.

Observations: 
[Anything worth flagging — e.g. "3 customers changed country — worth checking VAT status", "1 new customer in Germany, store_type unpopulated", "Fenwick Bond Street payment_terms changed from 30 to 45 days". Keep it short. If nothing notable, say "Nothing unusual."]

# Error handling
- If MySQL is unreachable: log to customer_sync_log with error_count=0 and errors=[{top_level:"MySQL unreachable"}], do NOT update sync_state. Return the error clearly.
- If any individual row fails to write: record in errors array, continue with rest. Only treat as total failure if >10% of rows error.
- Never retry destructive operations. Log and move on.

# Output format
End your response with exactly this block (so the CRM button can parse it):

--- RESULT JSON ---
{
  "mode": "delta" or "full",
  "rows_considered": N,
  "created": N,
  "updated": N,
  "unchanged": N,
  "errors": N,
  "duration_ms": N,
  "narrative": "..."
}
--- END RESULT ---
```

## Notes

- First run will be a full sweep (~6,300 rows). Expect 30-60 seconds.
- Subsequent delta runs typically process 20-60 rows in under 10 seconds.
- Sunday runs automatically trigger a full sweep.
- The routine is idempotent — running it twice does nothing the second time.

## What to do with the API endpoint

Once created, the routine has:
- Endpoint: `https://...` (copy from routine config)
- Bearer token: `rtn_...` (copy from routine config)

Paste both into Supabase app_settings so the CRM button can call it:

```sql
INSERT INTO app_settings(key, value) VALUES
  ('update_customers_routine_endpoint', 'https://...'),
  ('update_customers_routine_token', 'rtn_...')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();
```
