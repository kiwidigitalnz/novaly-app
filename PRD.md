# Modular Multi‑Tenant SaaS Base – Product Requirements Document (PRD)


## 1 · Executive Overview & Vision

Build a **single base application** that any business can sign up to, which then “snap‑on” optional modules (e.g. Health & Safety, Tasks, HR). Each customer (company) operates in its own workspace, may enable/disable modules, and pays only for what it uses. A **super‑admin** workspace controls global operations, billing, support and platform telemetry.

> *Skip six months of plumbing and launch your vertical SaaS in a week—multi‑tenant, role‑based, fully billed, with plug‑in modules you evolve in separate repos.*

---

## 2 · Objectives & Success Metrics

| Objective                            | **Primary KPI**                          | Target @ 12 months |
| ------------------------------------ | ---------------------------------------- | ------------------ |
| Frictionless self‑service onboarding | Time‑to‑first‑value (TTFV)               | < 10 min           |
| Revenue scalability via modules      | ARPU expansion %                         | > 40 % upgrades    |
| Operational efficiency               | Support tickets / active company / month | < 0.3              |
| Platform reliability                 | 99.9 % monthly uptime, p95 API < 300 ms  | pass               |
| Developer velocity                   | Lead time to prod (merge→deploy)         | < 30 min           |

---

## 3 · Personas & Core Use‑Cases

| Persona                    | Key Goals                                                                    | Representative Story                                                                                             |
| -------------------------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| **Company Admin (Emma)**   | Set up workspace, invite team, choose modules, manage billing                | “I created an account, added my logo, enabled Tasks & H\&S, and invited five foremen—all before lunch.”          |
| **Company User (Kiri)**    | Consume modules, receive notifications, chat with colleagues                 | “I switch from HQ to our new subsidiary and instantly see only that subsidiary’s tasks.”                         |
| **Super‑User (Richard)**   | Oversee all companies, intervene, adjust subscriptions, view platform health | “A Xero webhook failed for one client; I jumped into their workspace, re‑authorised, and verified invoice sync.” |
| **Third‑Party Dev (Alex)** | Ship plug‑in modules, earn rev‑share                                         | “I scaffolded a PPE Tracking module, published v1.0, and enabled it for beta testers—all via CLI.”               |

---

## 4 · Assumptions & Constraints

* Supabase Postgres + Edge Functions are core and cannot be swapped mid‑project.
* Stripe is the single source of truth for billing.
* Kiwi Digital will provide design tokens & brand assets up‑front.
* MVP is English‑only, NZ GST inclusive; i18n is architecturally prepared but not translated.
* Mobile experience is PWA‑first; native wrapper deferred.

---

## 5 · Technical Stack

| Layer             | Choice                                                          | Rationale                                                     |
| ----------------- | --------------------------------------------------------------- | ------------------------------------------------------------- |
| **Frontend**      | React 18, Vite, TypeScript, ShadCN (Radix UI + Tailwind)        | Accessible, composable, fast hot‑reload                       |
| **State / Data**  | React‑Query + Zod, Supabase JS client                           | Suspense‑ready, cache invalidation, runtime schema validation |
| **Backend API**   | Supabase Edge Functions (Deno) + PostgREST + Row‑Level‑Security | Zero‑ops, horizontally scalable                               |
| **Realtime**      | Supabase Realtime channels                                      | Built‑in WebSocket multiplexing                               |
| **Auth**          | Supabase Auth (JWT) + optional SAML adapters                    | Social, magic‑link, SSO friendliness                          |
| **Emails**        | Resend (SMTP fallback)                                          | Reliable, templated                                           |
| **Payments**      | Stripe (Billing + Customer Portal, metered usage)               | Handles proration, tax                                        |
| **Infra as Code** | Supabase CLI + GitHub Actions                                   | Repeatable environments                                       |
| **Testing**       | Vitest, Playwright, Storybook, OpenTelemetry traces in tests    | Shift‑left quality                                            |
| **Observability** | Logflare, Grafana Cloud, Sentry                                 | Correlate FE ↔ BE issues                                      |

---

## 6 · Architecture Layers & Responsibilities

```
┌───────────────┐        ┌───────────────────────┐
│ React 18 PWA  │  ←→    │ Supabase Edge Gateway │  ←→  Postgres (RLS)
│ (Tailwind UI) │ fetch  │   Auth, RLS headers   │
└───────────────┘        └───────────────────────┘
        ↑ WS                                ↑
        │                                   │
 ┌──────────────────┐               ┌─────────────────┐
 │ Supabase RT Chan │ ←──────────── │ Stripe Webhooks │
 └──────────────────┘               └─────────────────┘
```

*Edge Functions* act as our **BFF** (Backend‑for‑Frontend): encapsulate S3 uploads, 3rd‑party OAuth dances, Stripe calls, module hooks.
Modules live in separate packages but compile into the same Edge runtime (dynamic import).

---

## 7 · Non‑Functional Requirements (NFRs)

| Area              | Requirement                                                                         |
| ----------------- | ----------------------------------------------------------------------------------- |
| **Performance**   | p95 < 300 ms for any authenticated GET; dashboard FCP < 1 500 ms on mid‑tier mobile |
| **Scalability**   | 10 000 companies × 1 000 users each without RLS degradation (index `company_id`)    |
| **Security**      | OWASP Top‑10, RLS isolation, weekly dependency scanning, annual pen‑test            |
| **Availability**  | 99.9 % per month, HA Postgres, multi‑AZ S3 for assets                               |
| **Accessibility** | WCAG 2.2 AA                                                                         |
| **Compliance**    | NZ Privacy Act, optional EU GDPR add‑on, PCI‑DSS SAQ A                              |
| **Observability** | Traces 95 % coverage, error budgets, PagerDuty alerts                               |

---

## 8 · Feature‑by‑Feature Breakdown (Part 1)

### 8.1 Authentication & Registration

| Item                 | Detail                                                                                                                                                          |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **User Stories**     | 1. *Visitor* signs up → becomes **Company Admin** of a new company.2. *Invited teammate* accepts email invite, sets password and lands in the sender’s company. |
| **Flow**             | `/register` → `supabase.auth.signUp()` → Edge Function `post_signup()` trigger (creates company, member link, Stripe customer) → Resend welcome email.          |
| **DB Tables**        | `companies`, `company_members`, `invitations`.                                                                                                                  |
| **RLS**              | Only service role may insert into `companies`. Users can `select` their own `company_members`.                                                                  |
| **UI Components**    | `<AuthCard>`, `<PasswordStrengthMeter>`, `<MagicLinkOption>`.                                                                                                   |
| **Analytics Events** | `signup_started`, `signup_complete`, `invite_sent`, `invite_accepted`.                                                                                          |
| **Security Notes**   | Rate‑limit sign‑ups per IP, reCAPTCHA Enterprise, hashed email in logs.                                                                                         |

### 8.2 Workspace (Company) Selector & Tenancy Switching

| Item               | Detail                                                                                                                                |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| **User Story**     | *Multi‑company user* switches workspaces via sidebar; app remembers last selection.                                                   |
| **Component**      | `<CompanySelector>` – Combobox lists companies; search by name.                                                                       |
| **State Handling** | Selected `company_id` stored in `localStorage` + React context; `supabase.auth.refreshSession({ data: { company_id }})` embeds claim. |
| **URL Design**     | Friendly slug `/c/:companySlug/...` for deep links (301 on mismatch).                                                                 |
| **Edge Guard**     | Middleware validates `jwt.claim.company_id` vs route; 403 if mismatch.                                                                |
| **Example**        | Emma toggles subsidiaries; dashboard logo & metrics refresh in < 500 ms without full reload.                                          |

### 8.3 Roles & Permissions *(outline)*

* Roles: **admin**, **user**, **super\_admin**; module‑specific roles permitted.
* `permissions` lookup table drives UI HOCs (`<HasPermission perm="settings:billing"/>`).
* Super‑admin bypasses RLS via service key but UI still honours module state.

---

### 8.4 User Management & Team Invitations

| Item                 | Detail                                                                                                                                                                                                             |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **User Stories**     | 1. *Admin* views list of members, roles, statuses (active / pending).2. *Admin* can invite via email, CSV bulk, or shareable link.3. *Admin* can deactivate, reactivate, or transfer ownership.                    |
| **Flow**             | Settings → *Team* tab → `<InviteDrawer>` collects email + role → Edge Fn `create_invitation()` inserts token + Resend template → recipient clicks → `accept_invite()` → joins `company_members` with pre‑set role. |
| **Edge Validations** | Max seats vs subscription, domain allow‑list, duplicate check.                                                                                                                                                     |
| **UI Components**    | `<MemberTable>`, `<RoleBadge>`, `<InviteForm>`, `<DeactivateModal>`.                                                                                                                                               |
| **Bulk Import**      | CSV → Parse → Show preview diff → Confirm → batch Edge call.                                                                                                                                                       |
| **Audit Trail**      | `member_events` table (invited, accepted, role\_changed, deactivated) for SOC 2.                                                                                                                                   |

---

### 8.5 Integrations (Settings ► Integrations)

| Integration          | Auth Method                    | Stored Data                                 | Key Edge Function                          |
| -------------------- | ------------------------------ | ------------------------------------------- | ------------------------------------------ |
| **Xero**             | OAuth 2.0 PKCE                 | `access_token`, `refresh_token`, tenant\_id | `xero_oauth_callback()` + webhook listener |
| **Dropbox**          | OAuth 2.0                      | token, account\_id                          | `dropbox_connect()`                        |
| **Google Workspace** | OAuth + Domain‑wide delegation | token, scopes                               | `google_drive_upload()`                    |
| **Zapier**           | API key issued per company     | secret, enabled\_modules                    | `zapier_trigger_event()`                   |
| **Mailchimp**        | OAuth                          | token, audience\_id                         | `mailchimp_sync_subs()`                    |

*Integration credentials stored encrypted (****`pgp_sym_encrypt`**\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*) and scoped by ********************`company_id`********************.*  Admin UI shows *status*, *last sync*, *re‑authorise* button.

---

### 8.6 Billing & Subscriptions

| Item                      | Detail                                                                                                                                                                              |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Pricing Model**         | Base fee + per‑enabled‑module add‑ons + per user fees (metered usage). Base fee to include first User.                                                                              |
| **Stripe Objects**        | *Customer*, *Subscription*, *Price*, *UsageRecord*, *Invoice*.                                                                                                                      |
| **Self‑Service Screens**  | `<PlanPicker>` (toggle modules), `<PaymentMethodCard>`, `<InvoiceHistory>`.                                                                                                         |
| **Flow**                  | Company toggles module → Edge Fn `update_subscription()` calls Stripe API (proration) → updates `company_modules` & `subscriptions` tables → fires *billing\_updated* notification. |
| **Super‑Admin Overrides** | Coupon creation, comp credit, manual invoice.                                                                                                                                       |
| **Fail‑Grace**            | If invoice fails → Stripe retries → webhook marks `delinquent_at`, app displays banner, modules enter **read‑only** grace mode (14 days) before suspension.                         |

---

### 8.7 Real‑Time Messaging

| Aspect              | Implementation                                                                                  |
| ------------------- | ----------------------------------------------------------------------------------------------- |
| **Data Model**      | `conversations`, `messages`, `conversation_members` (for group).  All rows carry `company_id`.  |
| **Transport**       | Supabase *Realtime* channel per `conversation_id`; clients subscribe on mount.                  |
| **Features**        | Typing indicator (presence), file attachments (S3 pre‑signed), emoji reactions, unread counter. |
| **Offline Support** | IndexedDB queue; upon reconnect, `sync_pending_messages()` Edge Fn.                             |
| **Notifications**   | Emits `message:new` → in‑app toast; optional email digest for mentions.                         |
| **Security**        | RLS ensures membership; message body encrypted at rest (optional PGP).                          |

---

### 8.8 Product Feedback Hub (Bug Reports · Feature Requests · Road‑map · Changelog)

| Element               | Detail                                                                                                                           |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| **Tables**            | `bug_reports`, `feature_requests`, `roadmap_items`, `changelog_entries` (module + company scoped).                               |
| **Submission Flow**   | Floating *Feedback* button (opens `<FeedbackModal>`).  Post inserts, triggers notification to super‑admin Slack channel.         |
| **Road‑map Board**    | Kanban statuses: *Planned* • *In Dev* • *Beta* • *Released*.  Public read‑only per company.                                      |
| **Changelog Feed**    | Markdown entries, rendered via `<ChangelogDrawer>` & `/changelog` page.  Users can mark *read*; first unread pops tooltip badge. |
| **Super‑Admin Tools** | Merge duplicates, link bug → release, post ETA, push entry to email digest.                                                      |

---

### 8.9 Notification System

| Channel             | Transport             | User Controls                     |
| ------------------- | --------------------- | --------------------------------- |
| **In‑App**          | Context + Supabase RT | Toggle per event type             |
| **Email**           | Resend templated      | Immediate or digest (daily 07:00) |
| **Push** *(future)* | Service Worker + FCM  | Opt‑in browser prompt             |

*`notifications`*\* table stores: id, user\_id, type, payload, seen, delivered\_channels.\*  Edge helper `emitNotification(userIds[], type, payload)` is used by core and modules.

---

### 8.10 Company Dashboard & Personalisation

| Widget                 | Data Source                                                    | Notes                                               |
| ---------------------- | -------------------------------------------------------------- | --------------------------------------------------- |
| *Logo & Name*          | `companies.logo_url`                                           | S3 public; fallback letters avatar                  |
| *Quick Stats*          | Edge Fn `get_dashboard_metrics(company_id)` caches 60 s        | Tasks due, incidents open, revenue (if Xero linked) |
| *Recent Activity*      | `activity_log` view                                            | Combines messages, bug updates, module events       |
| *Changelog Highlights* | `changelog_entries` where created\_at > last\_seen             | dismissible                                         |
| *Custom Widgets*       | Module packages can **inject** via `registerDashboardWidget()` | e.g., H\&S incidents graph                          |

Responsive grid (Tailwind `grid-cols-[minmax(0,1fr)] md:grid-cols-2 xl:grid-cols-4`).  Dark‑mode compatible.

---

## 9 · Super‑Admin Console & Platform Operations (Part 3)

### 9.1 Super‑Admin Dashboard

| Widget                | Purpose                                               | Data Source                                                |
| --------------------- | ----------------------------------------------------- | ---------------------------------------------------------- |
| **Platform Summary**  | Active companies, MRR, ARPU, churn rate               | Materialised view `vw_platform_metrics` (refreshed 10 min) |
| **Service Health**    | p95 latency, error rate, DB CPU, Realtime connections | Grafana Cloud API → Edge proxy                             |
| **Recent Incidents**  | Last 10 errors grouped by root-cause hash             | `error_logs` table (Sentry webhook)                        |
| **Upcoming Renewals** | Companies renewing in next 7 days                     | `subscriptions` joined Stripe forecast                     |
| **New Signup Feed**   | Stream of newly created companies                     | `company_events` → Supabase RT channel                     |

Dashboard route: `/admin` guarded by `role=super_admin`.  Uses **cards grid** + **Grafana shared-image** embed for real‑time charts.

---

### 9.2 Global Clients Table

| Column                 | Notes                                   |
| ---------------------- | --------------------------------------- |
| Company Name (logo)    | click‑through to impersonate            |
| Plan & Enabled Modules | pills list; hover shows version         |
| Users                  | count + *admin* badge tooltip           |
| Status                 | active • delinquent • trial • suspended |
| MRR                    | real‑time from Stripe event store       |

Filters: *status*, *module*, *creation date*, *search*.  Bulk actions: send email, suspend, apply coupon.

Impersonation = Button `Log in as`.  Calls Edge Fn `generate_impersonation_jwt(company_id, admin_user_id)`; token expires in 30 min and is auditable in `impersonation_events`.

---

### 9.3 Subscription & Billing Controls

* View raw Stripe objects inside modal with “Open in Stripe” link.
* Create manual invoice / credit note.
* Toggle grandfathered pricing flag.
* Secure — requires TOTP re‑auth every 30 min.

---

### 9.4 Support Centre

* Zendesk/Intercom iframe for ticket context.
* One‑click set a company to **debug mode** (increases logging, captures SQL timings) — auto‑reverts in 2 hours.
* Trigger password reset or email verification resend.

---

### 9.5 Data & Maintenance Jobs

| Job                                        | Schedule    | Edge Fn                 |
| ------------------------------------------ | ----------- | ----------------------- |
| Clear expired invites                      | daily 03:00 | `cron_clear_invites.ts` |
| Rotate encrypted integration tokens (90 d) | weekly      | `cron_rotate_tokens.ts` |
| Rebuild analytics views                    | hourly      | `cron_refresh_views.ts` |

Jobs managed by Supabase *Scheduled Functions*; status surfaces in admin **Jobs** tab with history & success rate heat‑map.

---

## 10 · Module SDK & Developer Workflow

### 10.1 Module Manifest (`module.json`)

```json
{
  "slug": "health-safety",
  "name": "Health & Safety",
  "version": "1.2.0",
  "sidebar": { "icon": "hard-hat", "order": 30 },
  "billing": { "base_price_cents": 5000 },
  "db_migrations": ["001_init.sql", "002_add_incidents.sql"],
  "permissions": {
    "admin": ["*"] ,
    "user": ["view", "submit"]
  }
}
```

*Kept at repository root; validated at build.*

### 10.2 Scaffolding CLI (`create-module`)

```bash
npx create-module ppe-tracker
✔ Add default SQL migration?  … yes
✔ Create React route/page?   … yes
✔ Add Cypress template?      … yes
```

Generates:

```
modules/ppe-tracker/
  ├─ module.json
  ├─ sql/001_init.sql
  ├─ edge/index.ts            # REST/GraphQL handlers
  ├─ ui/Routes.tsx            # exported lazy routes
  ├─ ui/DashboardWidget.tsx   # optional
  └─ tests/
```

### 10.3 Build & Publish

* **Package**: `npm pack` → private registry `@kiwidigital/module-*`.
* **CI**: Vitest, ESLint, Cypress run in module repo; contract tests import `@base/app-test-harness`.
* **Publishing Process**:

  1. Bump semver & tag.
  2. GitHub Actions publishes artefact, updates **Marketplace** metadata table.
  3. Base‑app CI fetches enabled modules, applies migrations, redeploys Edge bundle.

---

## 11 · Marketplace

| Feature               | Detail                                                                                            |
| --------------------- | ------------------------------------------------------------------------------------------------- |
| **Listing page**      | Public `/marketplace` pulls from `modules_catalogue` table; cards show badge *beta* / *verified*. |
| **Enable flow**       | Company Admin clicks *Enable* → modal shows price → confirms → `update_subscription()` Edge call. |
| **Revenue Share**     | Modules have `revenue_share_pct`; Stripe Connect transfers payout monthly.                        |
| **Approval Workflow** | New module = *pending*; Super‑admin reviews security checklist, assigns badge.                    |
| **Kill Switch**       | Super‑admin can *disable* module globally; base app flags `force_disabled` → module routes 503.   |

**Developer Docs** page auto‑generates from manifest schema; examples provided.

---

## 12 · Observability & Incident Management

| Layer                | Tool                           | Key Dashboards / Alerts                 |
| -------------------- | ------------------------------ | --------------------------------------- |
| **Frontend**         | Sentry + Web Vitals            | JS errors > 0.3 % users                 |
| **Edge Functions**   | Logflare (structured JSON)     | p95 latency, error rate > 2 %           |
| **Database**         | Postgres /pg\_stat\_statements | slow queries > 500 ms                   |
| **Realtime**         | Grafana Cloud Prometheus       | active WS connections, dropped msgs     |
| **Background Jobs**  | Cron status table              | failure > 0, runtime > 2× avg           |
| **Synthetic Checks** | Checkly                        | login, new company create, payment flow |

*Incident Response Playbook* stored in repo; “status page” auto‑updates via supersede commit.

---

## 13 · API Catalogue (Preview)

| Endpoint                   | Method   | Scope   | Description                                 |
| -------------------------- | -------- | ------- | ------------------------------------------- |
| `/v1/companies`            | GET/POST | admin   | List or create companies (super‑admin only) |
| `/v1/modules/:slug/enable` | POST     | admin   | Enable a module for company                 |
| `/v1/messages`             | GET/POST | member  | List / send messages in conversation        |
| `/v1/webhooks/xero`        | POST     | service | Receive Xero events                         |
| `/v1/marketplace/modules`  | GET      | public  | List available modules                      |

OpenAPI spec auto‑generated from Zod schemas; SDKs produced via `openapi-generator` (TS, Python).

---

## 14 · Open Questions & Next Tasks (Track in Jira)

1. **Impersonation audit** — store request diff? ✅ design ready
2. **Encrypted message bodies** — PGP vs AES‑GCM? 🔲 decide
3. Module versioning policy — semantic or date‑based? 🔲 decide
4. Multi‑currency support for Stripe pricing — USD first, EUR next. 🔲 backlog

---

## 15 · Example Plug‑in Module – **Health & Safety (H\&S)**

### 15.1 Purpose & Outcomes

| Goal                                        | Benefit to Customers                                |
| ------------------------------------------- | --------------------------------------------------- |
| Centralise hazard registers & incident logs | Compliance with NZ Health & Safety at Work Act 2015 |
| Mobile‑friendly on‑site inspections         | Faster data capture, offline‑first                  |
| Real‑time risk notifications                | Reduce time to remediation                          |
| Produce automatic monthly H\&S report PDF   | Board reporting in one click                        |

---

### 15.2 Domain Model

| Table                 | Fields (pk ➜ bold)                                                                                                            | Notes                                     |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| **hs\_hazards**       | **id**, company\_id (FK), title, description, location, risk\_level (enum), created\_by, created\_at, status (open/mitigated) | Indexed on (company\_id, status)          |
| **hs\_incidents**     | **id**, company\_id, title, occurred\_at (timestamptz), severity (enum), description, reported\_by, status, created\_at       | Images stored in `hs_incident_files` (S3) |
| **hs\_actions**       | **id**, incident\_id (FK), assignee\_user\_id, due\_date, completed\_at, notes                                                | Triggers emit notification on assignment  |
| **hs\_inspections**   | **id**, company\_id, scheduled\_at, inspector\_id, outcome (pass/fail), notes, form\_json                                     | Flexible form JSONB                       |
| **hs\_risk\_ratings** | **id**, company\_id, label, colour\_hex, level (int)                                                                          | Company‑specific risk matrix              |

**RLS Policy Example**

```sql
CREATE POLICY "company‑isolation" ON hs_incidents
  USING ( company_id = current_setting('app.current_company')::uuid );
```

---

### 15.3 Edge API End‑points

| Path                               | Verb     | Auth   | Description                                  |
| ---------------------------------- | -------- | ------ | -------------------------------------------- |
| `/modules/hs/hazards`              | GET/POST | member | List / create hazards                        |
| `/modules/hs/hazards/:id`          | PATCH    | admin  | Update status, risk\_level                   |
| `/modules/hs/incidents`            | GET/POST | member | Report incidents                             |
| `/modules/hs/incidents/:id/assign` | POST     | admin  | Create action & assign user                  |
| `/modules/hs/report/monthly`       | GET      | admin  | Generate PDF summary (returns presigned URL) |

Edge functions live in module repo `edge/hs/*.ts`.  Use Zod schemas for validation; errors bubble as 422.

---

### 15.4 React UI Routes

| Route                      | Component                | Permission |
| -------------------------- | ------------------------ | ---------- |
| `/hs`                      | `<HSDashboard />`        | *user*     |
| `/hs/hazards`              | `<HazardList />`         | *user*     |
| `/hs/hazards/:id`          | `<HazardDetail />`       | *user*     |
| `/hs/incidents`            | `<IncidentList />`       | *user*     |
| `/hs/incidents/:id`        | `<IncidentDetail />`     | *user*     |
| `/hs/settings/risk-matrix` | `<RiskMatrixSettings />` | *admin*    |

Dashboard widget registered via:

```ts
registerDashboardWidget('hs-incidents-graph', HSDashboardWidget, 20);
```

---

### 15.5 Notifications & Permissions

* New incident → emits `hs.incident.reported` → Notifies **admin** users via web & optionally email.
* Action assignment → direct notification to assignee.
* Custom `hs_viewer` role example:

```sql
insert into permissions (module, role, action) values ('hs', 'viewer', 'read');
```

---

### 15.6 DB Migration Snippet

`sql/001_init.sql`:

```sql
-- Hazards
create table hs_hazards (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  title text not null,
  description text,
  location text,
  risk_level text check (risk_level in ('Low','Medium','High','Critical')),
  status text default 'open',
  created_by uuid references users(id),
  created_at timestamptz default now()
);
-- RLS setup
alter table hs_hazards enable row level security;
```

Second migration `002_add_incidents.sql` adds incidents/actions tables; migrations auto‑run on first enable.

---

### 15.7 Tests & QA

* **Vitest**: unit tests for calculation helpers (risk matrix).
* **Cypress**: end‑to‑end create hazard → mitigate flow.
* **Playwright**: visual regression of incident form.
* **Contract Test**: Ensure API conforms to `openapi.yaml`.

---

## 16 · Core Data Dictionary (Excerpt)

> *Full CSV export maintained in `/docs/data_dictionary.csv`; below is an excerpt of high‑impact tables.*

| Table                | Column               | Type                   | Description                         |
| -------------------- | -------------------- | ---------------------- | ----------------------------------- |
| **users**            | id                   | uuid (PK)              | Supabase Auth UID                   |
|                      | email                | citext                 | Unique login email                  |
|                      | name                 | text                   | Display name                        |
|                      | avatar\_url          | text                   | S3 path                             |
|                      | default\_company\_id | uuid                   | FK companies(id)                    |
| **companies**        | id                   | uuid (PK)              | Tenant identifier                   |
|                      | name                 | text                   | Company legal name                  |
|                      | slug                 | text unique            | URL slug                            |
|                      | logo\_url            | text                   | Branding                            |
|                      | stripe\_customer\_id | text                   | Billing ref                         |
| **company\_members** | user\_id             | uuid (PK,Fk users)     |                                     |
|                      | company\_id          | uuid (PK,Fk companies) |                                     |
|                      | role                 | text                   | enum('admin','user','super\_admin') |
|                      | joined\_at           | timestamptz            |                                     |
| **modules**          | id                   | uuid (PK)              |                                     |
|                      | slug                 | text unique            | npm package name                    |
|                      | latest\_version      | semver                 |                                     |
| **company\_modules** | company\_id          | uuid (PK)              |                                     |
|                      | module\_id           | uuid (PK)              |                                     |
|                      | enabled              | bool                   |                                     |
|                      | billing\_plan        | text                   | price id                            |
| **notifications**    | id                   | uuid (PK)              |                                     |
|                      | user\_id             | uuid                   | recipient                           |
|                      | type                 | text                   | e.g., 'message.new'                 |
|                      | payload              | jsonb                  | details                             |
|                      | seen                 | bool                   |                                     |
|                      | delivered\_channels  | text\[]                | \['web','email']                    |

*(Complete dictionary includes 40+ tables with indexes, FKs, RLS policies.)*

---

## 17 · Extensibility Hooks & Lifecycle Events

### 17.1 Module Lifecycle

| Hook                                    | When Called                  | Signature                                         |
| --------------------------------------- | ---------------------------- | ------------------------------------------------- |
| `onEnable(company_id)`                  | Company admin enables module | Async → run migrations, seed defaults             |
| `onDisable(company_id)`                 | Admin disables               | Cleanup cron jobs, revoke claims                  |
| `onUpgrade(company_id, fromVer, toVer)` | Version bump                 | Run incremental SQL, emit `module.upgraded` event |

Implement by exporting these functions in `index.ts` of each module; loader detects and executes.

### 17.2 Event Bus

* Global helper `emitEvent(type, payload[, company_id])` inserts into `events` table and notifies listeners (PG NOTIFY).
* Base app listens for selected events to pipe into **notifications** or **webhooks**.

### 17.3 Dashboard & Sidebar Injection

```ts
registerSidebarLink({
  module: 'hs',
  label: 'Health & Safety',
  icon: 'hard-hat',
  path: '/hs',
  order: 30
});
```

Links auto‑filtered by `company_modules.enabled` and user role.

### 17.4 Background Jobs

Modules may ship `jobs/*.ts` implementing `schedule = '0 3 * * *'` (CRON).  Base job runner discovers at runtime.

---

## 18 · Notification & Webhook Event Types (Master List)

| Event Code                   | Producer      | Default Recipients   | Description                   |
| ---------------------------- | ------------- | -------------------- | ----------------------------- |
| `message.new`                | Messaging     | conversation members | New chat message              |
| `hs.incident.reported`       | H\&S          | company admins       | Incident submitted            |
| `hs.action.assigned`         | H\&S          | assignee             | Corrective action assigned    |
| `billing.updated`            | Billing       | company admins       | Plan or payment method change |
| `module.upgraded`            | Module loader | company admins       | Module version updated        |
| `integration.token.expiring` | Scheduler     | admins               | 7‑day token expiry notice     |

Webhook deliveries sign each payload using HMAC SHA‑256 with company‑defined secret.

---

## 19 · Operations, Quality Assurance, Roll‑out & Risk Register


### 19.1 Environments & Branching Strategy

| Environment    | Branch           | Purpose                                   | Deployment Frequency |
| -------------- | ---------------- | ----------------------------------------- | -------------------- |
| **Local**      | feature/\*       | Dev box w/ Supabase CLI                   | continuous           |
| **Preview**    | PR‑generated     | Vercel Preview + separate Supabase schema | on every PR          |
| **Staging**    | `develop`        | Full stack mirror incl. Stripe test mode  | 5–10 × daily         |
| **Canary**     | `main` (flagged) | Subset of production users (5 %)          | on merge to main     |
| **Production** | `main`           | All customers                             | weekly or as needed  |

Supabase migrations run via `supabase db push` guarded by **`migra diff`** check to prevent accidental drops.  Canary traffic split leverages Supabase *branching* + Vercel `x-supabase-branch` header override.

---

### 19.2 CI / CD Pipeline (GitHub Actions)

1. **Lint & Type‑check** (`pnpm lint && pnpm typecheck`).
2. **Unit tests** (Vitest) – minimum 90 % lines coverage gate.
3. **Module contract tests** – run for all modules changed in PR.
4. **Build artefacts** – `pnpm build` (Vite) + Edge Functions bundle.
5. **Security scan** – `npm audit`, `trivy fs`, `gitleaks` on repo.
6. **Docker image** – multi‑arch build; push to GHCR.
7. **Deploy Preview** – Vercel preview & Supabase temporary branch.
8. **E2E tests** – Playwright on preview URL.
9. **Auto‑merge label** – if all green + approvals.
10. **Staging promotion** – `develop` branch push triggers Supabase staging project + Vercel staging site.

Release notes auto‑generated from PR labels (`feat`, `fix`, `perf`) and appended to **changelog\_entries** table on tag.

---

### 19.3 Testing Matrix

| Layer                     | Tooling                                     | Owner              | Frequency    |
| ------------------------- | ------------------------------------------- | ------------------ | ------------ |
| **Unit**                  | Vitest                                      | Devs               | every commit |
| **Integration (Edge↔DB)** | Vitest + Supabase Test Containers           | Devs               | PR           |
| **Contract / API**        | Dredd vs OpenAPI                            | Platform team      | nightly      |
| **UI Component**          | Storybook + Chromatic                       | Design system team | PR           |
| **E2E Smoke**             | Playwright (login, company switch, payment) | QA                 | on merge     |
| **Performance**           | k6 scripted (100 VU x 5 min)                | DevOps             | weekly       |
| **Accessibility**         | axe‑core GitHub action                      | Devs               | PR           |
| **Security**              | OWASP ZAP baseline, Dependabot              | SecOps             | weekly       |

Quality gates: *all* tests passing + coverage ≥ threshold + p95 latency ≤ 20 % regression window before deploy to production.

---

### 19.4 Release & Rollback

1. **Feature flags** (GrowthBook table) dark‑launch major features.
2. **Blue/Green** deploy supported via Vercel immutable builds + Supabase branches.
3. **Automated smoke tests** executed post‑deploy; webhook blocks promotion if failures.
4. **Rollback** is `vercel alias` shift + Supabase `revert branch` within 1 min (no DB migration) or `migrate:down` scripted when schema changes needed.

---

### 19.5 Backup & Disaster Recovery

| Asset                   | Technique                                      | RPO     | RTO             |
| ----------------------- | ---------------------------------------------- | ------- | --------------- |
| **Postgres**            | WAL + daily dump to S3 (cross‑region)          | < 5 min | < 30 min        |
| **S3 user uploads**     | Versioned bucket, replication to second region | 15 min  | 1 h             |
| **Edge Functions code** | Git tags + GHCR images retained                | n/a     | deploy < 10 min |

Quarterly **DR drill**: restore staging from latest prod backup, run smoke suite, sign‑off.

---

### 19.6 Compliance & Audit

* **SOC 2 Type II** roadmap – controls mapped, evidence collected via Drata.
* **PCI‑DSS SAQ A** – Stripe handles card data; quarterly ASV scan on frontend domain.
* **GDPR** – DPA template, Right‑to‑be‑Forgotten workflow, EU data processing register.
* **NZ Privacy Act** – Appointed Privacy Officer; incident report procedure within 72 h.

Annual penetration test with CREST‑certified vendor; remediation tracked in Jira.

---

### 19.7 Monitoring & Alerting

| Signal                      | Threshold          | Alert Channel   |
| --------------------------- | ------------------ | --------------- |
| **p95 API latency**         | > 400 ms for 5 min | PagerDuty Sev‑2 |
| **Error rate (Edge)**       | > 1 %              | PagerDuty Sev‑2 |
| **Stripe webhook failures** | any                | Slack #billing  |
| **DB CPU**                  | > 80 % 15 min      | PagerDuty Sev‑3 |
| **Cron job missed**         | 2 consecutive      | Slack #ops      |
| **SSL cert expiring**       | < 14 days          | Email Ops       |

Runbooks stored in `/runbooks/*.md`; pager rotation uses OpsGenie.

---

### 19.8 Risk Register

| # | Category   | Risk                                       | Likelihood | Impact   | Mitigation                                                |
| - | ---------- | ------------------------------------------ | ---------- | -------- | --------------------------------------------------------- |
| 1 | Tech debt  | Growing module surface slows core upgrades | Medium     | High     | Quarterly refactor budget; enforce design system usage    |
| 2 | Billing    | Stripe outage / API change                 | Low        | High     | Fallback to metered buffer, manual invoice script         |
| 3 | Security   | Token leakage via mis‑scoped RLS           | Low        | Critical | Automated RLS tests, static analysis (SQLFluff)           |
| 4 | Compliance | Late GDPR deletion                         | Medium     | Medium   | Automated 30‑day deletion job, audit log                  |
| 5 | Scale      | Realtime channel fan‑out cost spike        | Medium     | Medium   | Use presence sharding, switch to Elixir Phoenix if needed |
| 6 | People     | Bus factor on module SDK maintainer        | Low        | Medium   | Cross‑train, documentation, CODEOWNERS                    |

Risks reviewed monthly; new items logged after each retro.

---

### 19.9 Roll‑out Plan & Timeline

| Phase                        | Duration  | Milestones                                                             | Exit Criteria                                                      |
| ---------------------------- | --------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------ |
| **0 • Foundations**          | Month 1‑2 | Auth, Companies, RLS, Module loader skeleton                           | Unit & integration tests pass; basic H\&S module scaffold compiles |
| **1 • Private Alpha**        | Month 3   | 3 pilot companies (internal) use Base + Messaging                      | No P0 bugs for 2 weeks; average TTFV < 15 min                      |
| **2 • Beta (Early Access)**  | Month 4‑5 | Enable Billing, Integrations, Notifications; add 20 external companies | Churn < 10 %; payment success ≥ 95 %                               |
| **3 • General Availability** | Month 6   | Marketplace launch, SOC 2 audit in progress                            | Ops SLA met for 4 weeks, risk level ≤ 3 per register               |
| **4 • Expansion**            | Month 7+  | Mobile wrapper, AI assistants, multi‑currency                          | Revenue > NZ\$100k MRR, NPS ≥ 45                                   |

Regular *Go/No‑Go* checkpoints at each phase gate with full checklist.

---

### 19.10 Documentation & Training

* **Developer Docs** – JSDoc, Storybook, OpenAPI, Module SDK guide.
* **Admin Guides** – PDF + Loom videos for company admins (billing, roles, integrations).
* **Support Playbooks** – Templated responses, triage trees.
* **Change Management** – Changelog entries auto‑email to company admins and publish in‑app banner.

---

### 19.11 Open Items & Future Enhancements

| Idea                                          | Status       |
| --------------------------------------------- | ------------ |
| Automated cost observability (Kubecost‑style) | backlog      |
| Terraform provider for enterprise infra       | design draft |
| Multi‑AZ Postgres read replicas               | scheduled Q4 |
| AI anomaly detection on logs                  | research     |