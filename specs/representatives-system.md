# Representatives System

**Status:** Implemented
**Version:** 1.0
**Last Updated:** 2026-03-02

---

## 1. Overview

### 1.1 Purpose

Public-facing feature for browsing and viewing Utah elected officials — from the governor and state legislators to the federal congressional delegation. Supports filtering, search, pagination, and detailed profile views with voting records and action scripts.

### 1.2 Goals

- Display all active Utah officials in a searchable, filterable index
- Provide detailed profile pages with contact info, voting records, and action scripts
- Support SEO-friendly URLs via FriendlyId slugs
- Enable citizens to quickly find and contact their representatives

### 1.3 Non-Goals

- Editing or managing representative data (admin panel)
- District-based "find my rep" lookup (future enhancement)
- Representative comparison views (future enhancement)

### 1.4 Related Specifications

- [Data Model](./data-model.md) — Representative model schema
- [Data Import System](./data-import-system.md) — How rep data is imported
- [Action Scripts System](./action-scripts-system.md) — Call/email scripts linked to reps
- [Frontend System](./frontend-system.md) — Tailwind styling, layout, components

---

## 2. Routes

```ruby
resources :representatives, only: [:index, :show]
```

| Method | Path | Action | Description |
|--------|------|--------|-------------|
| GET | `/representatives` | `index` | Filterable, paginated list |
| GET | `/representatives/:id` | `show` | Detail page (`:id` accepts FriendlyId slugs) |

**URL Examples:**
- `/representatives` — all officials
- `/representatives?level=federal` — federal delegation
- `/representatives?party=Republican&chamber=Senate` — Republican senators
- `/representatives?search=cox` — search by name
- `/representatives/spencer-cox` — governor's detail page

---

## 3. Controller

**File:** `app/controllers/representatives_controller.rb`

### 3.1 Index Action

```
GET /representatives
```

**Query Parameters:**

| Param | Type | Values | Default |
|-------|------|--------|---------|
| `level` | string | `"federal"`, `"state"` | All levels |
| `chamber` | string | `"Senate"`, `"House"` | All chambers |
| `party` | string | `"Republican"`, `"Democrat"`, `"Independent"` | All parties |
| `search` | string | Free text | None |
| `page` | integer | Page number | 1 |

**Filter Logic (applied sequentially):**

```
1. Start with Representative.active.alphabetical
2. If level param present    → .where(level: params[:level])
3. If chamber param present  → .by_chamber(params[:chamber])
4. If party param present    → .by_party(params[:party])
5. If search param present   → .where("full_name ILIKE ?", "%#{params[:search]}%")
6. Paginate with Pagy        → pagy(@representatives) — 20 per page
```

**SEO:** Sets meta tags for title, description, keywords.

### 3.2 Show Action

```
GET /representatives/:id
```

**Data loaded:**
- `@representative` — `Representative.friendly.find(params[:id])`
- `@votes` — `representative.votes.recent.includes(:bill).limit(20)`
- `@action_scripts` — `representative.action_scripts.active.ordered`

**SEO:** Dynamic meta tags with representative name, title, and party.

---

## 4. Views

### 4.1 Index Page

**File:** `app/views/representatives/index.html.erb`

```
┌─────────────────────────────────────────────────────────────┐
│  H1: "Utah's Elected Officials"                             │
│  Subtitle: "Track and contact your representatives"          │
├─────────────────────────────────────────────────────────────┤
│  FILTER BAR                                                  │
│  ┌──────────┐ ┌─────────┐ ┌─────────┐ ┌──────────────────┐ │
│  │ Level ▼  │ │Chamber▼ │ │ Party ▼ │ │ Search by name   │ │
│  └──────────┘ └─────────┘ └─────────┘ └──────────────────┘ │
│  [Filter] [Clear]                                            │
├─────────────────────────────────────────────────────────────┤
│  RESULTS GRID (3-col lg, 2-col sm, 1-col xs)                │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │  Rep Card    │ │  Rep Card    │ │  Rep Card    │        │
│  │  (partial)   │ │  (partial)   │ │  (partial)   │        │
│  └──────────────┘ └──────────────┘ └──────────────┘        │
│  ... more cards ...                                          │
├─────────────────────────────────────────────────────────────┤
│  PAGINATION (Pagy offset JS nav)                             │
└─────────────────────────────────────────────────────────────┘
```

**Filter implementation:** Standard HTML `<form>` with `GET` method — no JavaScript required. Dropdowns submit as query parameters.

### 4.2 Show Page

**File:** `app/views/representatives/show.html.erb`

```
┌─────────────────────────────────────────────────────────────┐
│  ← Back to Representatives                                   │
├─────────────────────────────────────────────────────────────┤
│  PROFILE HEADER                                              │
│  ┌────────┐                                                  │
│  │ Photo  │  Full Name                                       │
│  │ or     │  Title                                           │
│  │Initials│  [Party Badge] [Level Badge] [District Badge]    │
│  └────────┘                                                  │
├─────────────────────────────────────────────────────────────┤
│  CONTACT INFO (grid)                                         │
│  Phone: (801) 555-0100 (tel: link)                          │
│  Email: rep@utah.gov (mailto: link)                         │
│  Website: https://... (external link)                       │
├──────────────────────────────────┬──────────────────────────┤
│  VOTING RECORD TABLE            │  ACTION SCRIPTS SIDEBAR   │
│                                  │                          │
│  Bill Title  | Date | Position   │  Script Card 1           │
│  ─────────────────────────────   │  Script Card 2           │
│  HB 245      | 2/15 | Yea ●     │                          │
│  SB 89       | 2/10 | Nay ●     │                          │
│  HR 5678     | 1/30 | Yea ●     │                          │
│  ...                             │                          │
└──────────────────────────────────┴──────────────────────────┘
```

**Vote position colors:**
- Yea — green badge (`text-green-700 bg-green-100`)
- Nay — red badge (`text-red-700 bg-red-100`)
- Abstain — yellow badge
- Not Voting — gray badge
- Present — blue badge

### 4.3 Rep Card Partial

**File:** `app/views/shared/_rep_card.html.erb`

```
┌──────────────────────────────────────────┐
│  ┌────┐  Full Name                       │
│  │Photo│  Title                           │
│  │ 56px│  [Party] [Level] [District]      │
│  └────┘  Phone: (801) 555-0100           │
└──────────────────────────────────────────┘
```

- Entire card is wrapped in `link_to` to the rep's show page
- Photo falls back to initials circle (first letter of first + last name)
- Party badge is color-coded: Republican = red, Democrat = blue, Independent = purple
- Hover state: shadow elevation + slight scale

---

## 5. Pagination

Uses **Pagy 43** with the new API:

```ruby
# Controller (via Pagy::Method include in ApplicationController)
@pagy, @representatives = pagy(@representatives)

# View
pagy(:offset, @pagy).series_nav_js
```

**Config:** `Pagy::OPTIONS[:limit] = 20` (set in `config/initializers/pagy.rb`)

---

## 6. SEO

### 6.1 FriendlyId Slugs

```ruby
# Model
extend FriendlyId
friendly_id :full_name, use: :slugged

# Controller
Representative.friendly.find(params[:id])
# Accepts: "spencer-cox", "mike-lee", or integer ID
```

### 6.2 Meta Tags

| Page | Title | Description |
|------|-------|-------------|
| Index | "Utah's Elected Officials" | "Browse and contact Utah's state and federal..." |
| Show | "Gov. Spencer Cox - Save Utah" | "View voting record and contact info for..." |

---

## 7. Design Decisions

### 7.1 Why ILIKE for Search?

Simple case-insensitive substring matching on `full_name` is sufficient for the current dataset (~75 officials). No need for pg_search or tsvector.

**Future path:** If search needs grow (full-text across titles, bios), add `pg_search` gem with `tsvector` index.

### 7.2 Why a Single Index for All Levels?

Rather than separate pages for federal vs. state officials, a single index with filters keeps the UX simple and lets users compare across levels.

### 7.3 Why Limit 20 Votes on Show?

Utah has ~75 active officials. Showing all votes for a prolific legislator could be hundreds of records. Limiting to 20 recent votes keeps the page fast; a "view all" feature can be added later.

---

## 8. Implementation Notes

- Controller: `app/controllers/representatives_controller.rb`
- Index view: `app/views/representatives/index.html.erb`
- Show view: `app/views/representatives/show.html.erb`
- Card partial: `app/views/shared/_rep_card.html.erb`
- Model: `app/models/representative.rb`
