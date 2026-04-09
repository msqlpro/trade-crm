-- ─────────────────────────────────────────────
-- CRM: Event Types
-- ─────────────────────────────────────────────
CREATE TABLE crm_event_types (
  id          serial PRIMARY KEY,
  name        text NOT NULL UNIQUE,
  colour      text DEFAULT '#6366f1',
  icon        text DEFAULT '📋',
  created_at  timestamptz DEFAULT now()
);

INSERT INTO crm_event_types (name, colour, icon) VALUES
  ('Brochure Sent',      '#3b82f6', '📮'),
  ('Voucher Posted',     '#f59e0b', '🎟️'),
  ('Sales Call',         '#10b981', '📞'),
  ('Email Campaign',     '#8b5cf6', '📧'),
  ('Trade Show',         '#ef4444', '🏪'),
  ('Sample Sent',        '#06b6d4', '📦'),
  ('Visit',              '#f97316', '🤝'),
  ('Note',               '#6b7280', '📝');

-- ─────────────────────────────────────────────
-- CRM: Customers (synced from KashFlow)
-- ─────────────────────────────────────────────
CREATE TABLE crm_customers (
  id                serial PRIMARY KEY,
  kashflow_id       text UNIQUE,
  company_name      text NOT NULL,
  contact_name      text,
  email             text,
  phone             text,
  address_line1     text,
  address_line2     text,
  town              text,
  county            text,
  postcode          text,
  country           text DEFAULT 'UK',
  account_status    text DEFAULT 'active',
  total_spend       numeric(10,2) DEFAULT 0,
  last_order_date   date,
  notes             text,
  kashflow_synced_at timestamptz,
  created_at        timestamptz DEFAULT now(),
  updated_at        timestamptz DEFAULT now()
);

CREATE INDEX idx_crm_customers_kashflow_id  ON crm_customers(kashflow_id);
CREATE INDEX idx_crm_customers_company_name ON crm_customers(company_name);
CREATE INDEX idx_crm_customers_postcode     ON crm_customers(postcode);
CREATE INDEX idx_crm_customers_status       ON crm_customers(account_status);

-- ─────────────────────────────────────────────
-- CRM: Campaigns
-- ─────────────────────────────────────────────
CREATE TABLE crm_campaigns (
  id              serial PRIMARY KEY,
  name            text NOT NULL,
  event_type_id   integer REFERENCES crm_event_types(id),
  campaign_date   date NOT NULL,
  description     text,
  mailer_id       text,
  recipient_count integer DEFAULT 0,
  created_by      text,
  created_at      timestamptz DEFAULT now()
);

-- ─────────────────────────────────────────────
-- CRM: Contact Events
-- ─────────────────────────────────────────────
CREATE TABLE crm_contact_events (
  id              serial PRIMARY KEY,
  customer_id     integer NOT NULL REFERENCES crm_customers(id) ON DELETE CASCADE,
  event_type_id   integer NOT NULL REFERENCES crm_event_types(id),
  campaign_id     integer REFERENCES crm_campaigns(id),
  event_date      date NOT NULL,
  notes           text,
  logged_by       text,
  created_at      timestamptz DEFAULT now()
);

CREATE INDEX idx_crm_events_customer ON crm_contact_events(customer_id);
CREATE INDEX idx_crm_events_date     ON crm_contact_events(event_date);
CREATE INDEX idx_crm_events_campaign ON crm_contact_events(campaign_id);

-- ─────────────────────────────────────────────
-- RLS
-- ─────────────────────────────────────────────
ALTER TABLE crm_event_types    ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm_customers      ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm_campaigns      ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm_contact_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users only" ON crm_event_types    FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated users only" ON crm_customers      FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated users only" ON crm_campaigns      FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated users only" ON crm_contact_events FOR ALL TO authenticated USING (true) WITH CHECK (true);
