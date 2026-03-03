# Save Utah — Architecture

**Status:** Implemented
**Version:** 1.0
**Last Updated:** 2026-03-02

---

## 1. Overview

### 1.1 Purpose

Public-facing civic engagement platform that tracks Utah elected officials (state + federal), their voting records, and provides citizens with tools to take action (call scripts, contact info, vote breakdowns).

### 1.2 Goals

- Track all Utah elected officials at state and federal levels
- Display voting records linked to specific bills
- Provide actionable call/email scripts for citizen engagement
- Pull data from official government APIs automatically

### 1.3 Non-Goals

- User authentication or accounts
- Admin panel or CMS
- Real-time WebSocket updates
- Campaign donations or fundraising

---

## 2. Architecture

### 2.1 System Diagram

```
┌──────────────────────────────────────────────────────┐
│                    External APIs                      │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐  │
│  │ Congress.gov │ │ Utah Leg API │ │  OpenStates  │  │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘  │
└─────────┼────────────────┼────────────────┼──────────┘
          │                │                │
          ▼                ▼                ▼
┌──────────────────────────────────────────────────────┐
│              Service Layer (app/services/)            │
│  congress_gov/       utah_legislature/   open_states/ │
│  ├─ client.rb        ├─ client.rb        ├─ client   │
│  ├─ member_importer  ├─ legislator_imp   ├─ people   │
│  ├─ bill_importer    ├─ bill_importer    └─ bill_imp │
│  └─ vote_importer    └─ vote_importer                │
└──────────────────────┬───────────────────────────────┘
                       │ rake import:*
                       ▼
┌──────────────────────────────────────────────────────┐
│                PostgreSQL Database                    │
│  representatives ── votes ── bills ── issue_bills     │
│  action_scripts   featured_items   issues            │
└──────────────────────┬───────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│               Rails Controllers                       │
│  PagesController    RepresentativesController         │
│  (home, about)      (index, show + filters)           │
│                     BillsController                   │
│                     (index, show + vote breakdown)     │
│                     IssuesController                  │
│                     (index, show/blast + scorecard)    │
└──────────────────────┬───────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│           Views (Tailwind 4 + ERB)                    │
│  layouts/application  pages/home  pages/about         │
│  representatives/     bills/      issues/             │
│  shared/_partials (cards, scorecard rows)             │
└──────────────────────────────────────────────────────┘
```

### 2.2 Directory Structure

```
app/
├── controllers/
│   ├── application_controller.rb
│   ├── pages_controller.rb
│   ├── representatives_controller.rb
│   ├── bills_controller.rb
│   └── issues_controller.rb
├── models/
│   ├── representative.rb        # friendly_id, enums, scopes
│   ├── bill.rb                  # friendly_id, vote_summary
│   ├── vote.rb                  # join table, position enum
│   ├── action_script.rb         # render_script with placeholders
│   ├── featured_item.rb         # polymorphic homepage curation
│   ├── issue.rb                 # curated policy topics with scoring
│   └── issue_bill.rb            # join table with popular_position
├── services/
│   ├── api_client.rb            # Base Faraday HTTP client
│   ├── congress_gov/            # Federal data (3 importers)
│   ├── utah_legislature/        # State data (3 importers)
│   └── open_states/             # Fallback data (2 importers)
└── views/
    ├── layouts/application.html.erb
    ├── pages/                   # home, about
    ├── representatives/         # index, show
    ├── bills/                   # index, show
    ├── issues/                  # index, show (blast page)
    └── shared/                  # _rep_card, _bill_card, _script_card, _issue_card, _accountability_row
```

---

## 3. Data Model

```
┌─────────────────┐       ┌─────────┐       ┌─────────────────┐
│ Representative   │──┐    │  Vote   │    ┌──│      Bill       │
│                  │  └───▶│ (join)  │◀───┘  │                 │
│ position_type    │       │ position│       │ bill_number     │
│ level (fed/state)│       │ voted_on│       │ level           │
│ party, district  │       └─────────┘       │ editorial_summ  │
│ phone, email     │                         │ featured        │
│ slug (friendly)  │                         │ slug (friendly) │
└────────┬─────────┘                         └────────┬────────┘
         │                                            │
         │ has_many                          has_many  │
         ▼                                            ▼
┌─────────────────┐                      ┌─────────────────┐
│  ActionScript   │                      │  FeaturedItem   │
│ script_template │                      │ (polymorphic)   │
│ action_type     │                      │ section (enum)  │
│ [REP_NAME] etc  │                      │ hero/spotlight/ │
└─────────────────┘                      │ recent_actions  │
                                         └─────────────────┘

┌─────────────────┐       ┌───────────┐
│     Issue       │──┐    │ IssueBill │    ┌──── Bill
│                 │  └───▶│  (join)   │◀───┘
│ name, slug      │       │ popular_  │
│ stance_label    │       │  position │
│ against_label   │       │ sort_order│
│ icon            │       └───────────┘
└─────────────────┘
```

---

## 4. Data Flow

### 4.1 Import Pipeline

1. **Rake task** triggers importer (e.g., `rake import:federal_members`)
2. **Service client** makes authenticated HTTP request to external API
3. **Importer** iterates results, runs `find_or_initialize_by(external_id)`
4. **`assign_attributes`** maps API fields → model fields
5. **`save!`** persists to PostgreSQL (idempotent — safe to re-run)

### 4.2 Request Flow

1. User hits `/representatives` or `/bills`
2. Controller applies filters (level, chamber, party, search)
3. Pagy paginates the result set
4. View renders cards using shared partials
5. SEO meta tags set per-page via `meta-tags` gem

---

## 5. Configuration

### 5.1 Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `CONGRESS_GOV_API_KEY` | For imports | Congress.gov API key (5K req/hr) |
| `UTAH_LEGISLATURE_TOKEN` | For imports | Utah Legislature developer token |
| `OPENSTATES_API_KEY` | For imports | OpenStates API key (fallback) |

---

## 6. Next Steps

### Phase 2 — Production Readiness

- [ ] **Fly.io deployment** — fly.toml, secrets, production database, `fly deploy`
- [ ] **Run real imports** — populate with live data from all 3 APIs
- [ ] **Error monitoring** — add Sentry or similar for production error tracking
- [ ] **Cron schedule** — automate `rake import:all` via cron or Fly.io scheduled machines

### Phase 3 — Enhanced UX

- [ ] **Turbo Frames** — filter reps/bills without full page reload
- [ ] **Full-text search** — pg_search gem or PostgreSQL `tsvector` for better search
- [ ] **District lookup** — "Find my rep" by address/zip using Google Civic API
- [ ] **Email notifications** — let users subscribe to bill updates (requires auth)

### Phase 4 — Scale & Performance

- [ ] **Solid Queue** — move imports to background jobs instead of rake tasks
- [ ] **Caching** — fragment caching on rep cards, bill cards, vote tables
- [ ] **Senate votes** — parse senate.gov XML files (not in Congress.gov API yet)
- [ ] **Historical data** — import past sessions/congresses for voting history trends

### Phase 5 — Engagement

- [ ] **Shareable vote cards** — OG image generation for social sharing
- [ ] **Bill tracking** — bookmark bills (cookie-based, no auth needed)
- [ ] **Comparison views** — side-by-side voting record comparison between reps
- [ ] **Data exports** — CSV/JSON download of voting records
