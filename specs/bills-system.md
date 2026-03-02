# Bills System

**Status:** Implemented
**Version:** 1.0
**Last Updated:** 2026-03-02

---

## 1. Overview

### 1.1 Purpose

Public-facing feature for browsing and viewing Utah legislation — both state bills and federal bills relevant to Utah. Supports filtering, search, pagination, detailed bill views with vote breakdowns, editorial summaries, and action scripts.

### 1.2 Goals

- Display all imported bills in a searchable, filterable index
- Provide detailed bill pages with vote breakdowns by representative
- Surface "Why This Matters" editorial summaries for key bills
- Link bills to action scripts for citizen engagement

### 1.3 Non-Goals

- Bill text rendering (links to external full-text URLs)
- Bill amendment tracking
- Committee hearing schedules
- Bill status change notifications

### 1.4 Related Specifications

- [Data Model](./data-model.md) — Bill and Vote model schemas
- [Data Import System](./data-import-system.md) — How bill/vote data is imported
- [Representatives System](./representatives-system.md) — Rep profiles linked from vote tables
- [Action Scripts System](./action-scripts-system.md) — Call/email scripts linked to bills

---

## 2. Routes

```ruby
resources :bills, only: [:index, :show]
```

| Method | Path | Action | Description |
|--------|------|--------|-------------|
| GET | `/bills` | `index` | Filterable, paginated list |
| GET | `/bills/:id` | `show` | Detail page with vote breakdown |

**URL Examples:**
- `/bills` — all bills
- `/bills?level=state&year=2025` — 2025 state bills
- `/bills?chamber=Senate&search=public+lands` — senate bills matching search
- `/bills/hb-245-utah-clean-air-standards-act` — bill detail page

---

## 3. Controller

**File:** `app/controllers/bills_controller.rb`

### 3.1 Index Action

```
GET /bills
```

**Query Parameters:**

| Param | Type | Values | Default |
|-------|------|--------|---------|
| `level` | string | `"federal"`, `"state"` | All levels |
| `year` | integer | Session year (e.g., 2025) | All years |
| `status` | string | Any status string | All statuses |
| `chamber` | string | `"Senate"`, `"House"` | All chambers |
| `search` | string | Free text | None |
| `page` | integer | Page number | 1 |

**Filter Logic (applied sequentially):**

```
1. Start with Bill.all.recent (ordered by last_action_on DESC)
2. If level param present    → .where(level: params[:level])
3. If year param present     → .by_session(params[:year])
4. If status param present   → .by_status(params[:status])
5. If chamber param present  → .by_chamber(params[:chamber])
6. If search param present   → .where("title ILIKE :q OR bill_number ILIKE :q", q: "%#{search}%")
7. Paginate with Pagy        → pagy(@bills) — 20 per page
```

**SEO:** Sets meta tags for title and description.

### 3.2 Show Action

```
GET /bills/:id
```

**Data loaded:**
- `@bill` — `Bill.friendly.find(params[:id])`
- `@votes` — `bill.votes.includes(:representative).order("representatives.last_name")`
- `@vote_summary` — `bill.vote_summary` → `{yes: N, no: N, abstain: N, not_voting: N}`
- `@action_scripts` — `bill.action_scripts.active.ordered`

**SEO:** Dynamic meta tags — prefers `editorial_summary` over `summary` for description.

---

## 4. Views

### 4.1 Index Page

**File:** `app/views/bills/index.html.erb`

```
┌─────────────────────────────────────────────────────────────┐
│  H1: "Bills & Legislation"                                   │
│  Subtitle: "Track bills and voting records"                  │
├─────────────────────────────────────────────────────────────┤
│  FILTER BAR                                                  │
│  ┌──────────┐ ┌────────┐ ┌──────────┐ ┌──────────────────┐ │
│  │ Level ▼  │ │ Year ▼ │ │Chamber ▼ │ │ Search bills...   │ │
│  └──────────┘ └────────┘ └──────────┘ └──────────────────┘ │
│  [Filter] [Clear]                                            │
├─────────────────────────────────────────────────────────────┤
│  BILL LIST (single column, card per bill)                    │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Bill Card (partial)                                      ││
│  │ [HB 245] [State] [In Committee]                         ││
│  │ Utah Clean Air Standards Act                            ││
│  │ Summary text (truncated)...                             ││
│  │ Last action: Feb 15, 2026    Yea: 45  Nay: 12          ││
│  └─────────────────────────────────────────────────────────┘│
│  ... more bill cards ...                                     │
├─────────────────────────────────────────────────────────────┤
│  PAGINATION                                                  │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Show Page

**File:** `app/views/bills/show.html.erb`

```
┌─────────────────────────────────────────────────────────────┐
│  ← Back to Bills                                             │
├─────────────────────────────────────────────────────────────┤
│  BILL HEADER                                                 │
│  [HB 245] [State] [In Committee] [House]                    │
│  "Utah Clean Air Standards Act"                              │
│  Introduced: Jan 15, 2026  |  Last Action: Feb 15, 2026    │
├─────────────────────────────────────────────────────────────┤
│  WHY THIS MATTERS (gold background box)                      │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Editorial summary text explaining the bill's impact     ││
│  │ in plain language...                                    ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│  OFFICIAL SUMMARY                                            │
│  Official summary text from the API...                      │
│                                                              │
│  [Read Full Text →] (link to full_text_url)                 │
├──────────────────────────────────┬──────────────────────────┤
│  VOTE BREAKDOWN                  │  ACTION SCRIPTS SIDEBAR   │
│                                  │                          │
│  Summary Bar:                    │  Script Card 1           │
│  Yea: 45 | Nay: 12 | Abs: 2    │  Script Card 2           │
│  Not Voting: 3                   │                          │
│                                  │                          │
│  Visual Bar:                     │                          │
│  [████████████░░░░░░░]          │                          │
│   green      red gray            │                          │
│                                  │                          │
│  Vote Table:                     │                          │
│  Representative | Party | Vote   │                          │
│  ──────────────────────────────  │                          │
│  Rep. Blake Moore | R    | Yea   │                          │
│  Sen. Mike Lee    | R    | Nay   │                          │
│  ...                             │                          │
└──────────────────────────────────┴──────────────────────────┘
```

### 4.3 Bill Card Partial

**File:** `app/views/shared/_bill_card.html.erb`

```
┌─────────────────────────────────────────────────────────────┐
│  [HB 245] [State] [In Committee]                             │
│  Utah Clean Air Standards Act                                │
│  Summary text (truncated to ~150 chars)...                   │
│  Last action: Feb 15, 2026          Yea: 45 ● | Nay: 12 ●  │
└─────────────────────────────────────────────────────────────┘
```

- Entire card is a link to the bill's show page
- Prefers `editorial_summary` over `summary` for the truncated text
- Vote summary mini-display: green count for yes, red count for no

### 4.4 Vote Breakdown Details

**Summary Bar:** Four colored counters showing aggregate vote counts.

**Visual Stacked Bar:** Horizontal bar proportionally divided by vote position:
- Green segment = yes votes
- Red segment = no votes
- Yellow segment = abstain
- Gray segment = not voting

**Vote Table:** Full list of representatives who voted, sorted alphabetically by last name. Each row links to the representative's show page.

---

## 5. Vote Summary Method

**File:** `app/models/bill.rb`

```ruby
def vote_summary
  counts = votes.group(:position).count
  {
    yes: counts.fetch("yes", 0),
    no: counts.fetch("no", 0),
    abstain: counts.fetch("abstain", 0),
    not_voting: counts.fetch("not_voting", 0)
  }
end
```

Returns a hash used by both the show page and the bill card partial.

---

## 6. Editorial Summaries

The `editorial_summary` field provides plain-language "Why This Matters" context for bills, separate from the official `summary`. This is the primary differentiator for citizen engagement — translating legislative jargon into understandable impact statements.

**Display logic:**
- Show page: Displayed in a gold-background callout box if present
- Bill card: Preferred over `summary` for the truncated preview text
- SEO: Used for meta description when available

**Content source:** Manually authored or AI-assisted (not imported from APIs).

---

## 7. Design Decisions

### 7.1 Why Search Across Both Title and Bill Number?

Citizens may search by either "clean air" (topic) or "HB 245" (bill number). The `ILIKE` query checks both columns.

### 7.2 Why Show All Votes on the Detail Page?

Unlike the representative show page (which limits to 20 recent votes), bill detail pages show all votes. Utah bills typically have one floor vote with ~75 legislators voting, which is a manageable dataset.

### 7.3 Why Editorial Summaries Are Separate?

Keeping `editorial_summary` separate from `summary` preserves the official summary's integrity while allowing human-written context. This also enables conditional display — the gold callout box only appears when an editorial exists.

---

## 8. Implementation Notes

- Controller: `app/controllers/bills_controller.rb`
- Index view: `app/views/bills/index.html.erb`
- Show view: `app/views/bills/show.html.erb`
- Card partial: `app/views/shared/_bill_card.html.erb`
- Model: `app/models/bill.rb`
- Vote model: `app/models/vote.rb`
