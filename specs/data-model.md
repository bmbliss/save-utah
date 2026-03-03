# Data Model

**Status:** Implemented
**Version:** 1.1
**Last Updated:** 2026-03-03

---

## 1. Overview

### 1.1 Purpose

Defines the PostgreSQL database schema powering Save Utah — seven tables that track elected officials, legislation, voting records, policy issues with accountability scorecards, citizen action scripts, and homepage curation.

### 1.2 Goals

- Represent Utah officials at both state and federal levels with a single `Representative` model
- Link representatives to bills through a `Vote` join table with position tracking
- Support actionable call/email scripts with template rendering
- Enable flexible homepage curation via polymorphic `FeaturedItem`
- Curate policy issues and generate accountability scorecards from vote data

### 1.3 Non-Goals

- User accounts or authentication tables
- Admin/CMS tables
- Audit logs or versioning (e.g., PaperTrail)

### 1.4 Related Specifications

- [Architecture](./architecture.md) — System-level overview
- [Data Import System](./data-import-system.md) — How data flows into these models
- [Representatives System](./representatives-system.md) — How reps are queried and displayed
- [Bills System](./bills-system.md) — How bills are queried and displayed
- [Issues System](./issues-system.md) — Issue scorecards and accountability scoring

---

## 2. Entity Relationship Diagram

```
┌─────────────────────┐          ┌───────────────┐          ┌─────────────────────┐
│   Representative    │          │     Vote      │          │       Bill          │
│                     │──── 1:N ──│   (join)     │── N:1 ───│                     │
│ id                  │          │ id            │          │ id                  │
│ first_name          │          │ representative│          │ title               │
│ last_name           │          │   _id (FK)    │          │ bill_number         │
│ full_name           │          │ bill_id (FK)  │          │ slug                │
│ slug                │          │ position      │          │ summary             │
│ title               │          │   (enum)      │          │ editorial_summary   │
│ position_type (enum)│          │ voted_on      │          │ full_text_url       │
│ level (enum)        │          │ data_source   │          │ status              │
│ chamber             │          └───────────────┘          │ level (enum)        │
│ party               │                                     │ chamber             │
│ district            │                                     │ session_year        │
│ photo_url           │                                     │ session_name        │
│ phone, email        │                                     │ featured            │
│ phone_mobile        │          ┌───────────────┐          │ introduced_on       │
│ phone_work          │          │ ActionScript  │          │ last_action_on      │
│ phone_home          │── 1:N ───│               │── N:1 ───│ congress_bill_id    │
│ website_url         │          │ id            │          │ utah_bill_id        │
│ twitter_handle      │          │ title         │          │ openstates_bill_id  │
│ facebook_url        │          │ script_template│         │ data_source         │
│ office_address      │          │ context       │          └─────────────────────┘
│ active              │          │ action_type   │                    │
│ bioguide_id         │          │   (enum)      │                    │
│ utah_leg_id         │          │ representative│                    │
│ openstates_id       │          │   _id (FK?)   │                    │
└─────────────────────┘          │ bill_id (FK?) │          ┌─────────────────────┐
         │                       │ active        │          │   FeaturedItem      │
         │                       │ featured      │          │   (polymorphic)     │
         │                       │ sort_order    │          │                     │
         │                       └───────────────┘          │ id                  │
         │                                                  │ featurable_type     │
         └───────────── 1:N (polymorphic) ─────────────────│ featurable_id       │
                                                            │ headline            │
                                                            │ description         │
                                                            │ section (enum)      │
                                                            │ sort_order          │
                                                            │ active              │
                                                            └─────────────────────┘

┌─────────────────────┐          ┌───────────────┐
│       Issue         │          │   IssueBill   │
│                     │──── 1:N ──│   (join)     │── N:1 ──── Bill
│ id                  │          │ id            │
│ name                │          │ issue_id (FK) │
│ slug                │          │ bill_id (FK)  │
│ description         │          │ popular_      │
│ stance_label        │          │   position    │
│ against_label       │          │   (enum)      │
│ active              │          │ sort_order    │
│ sort_order          │          └───────────────┘
│ icon                │
└─────────────────────┘
```

---

## 3. Models

### 3.1 Representative

The core model for Utah elected officials — covers executives, state legislators, and federal delegation in a single table.

**File:** `app/models/representative.rb`

```ruby
# Enums (Rails 8 positional integer style)
enum :position_type, {
  us_senator: 0, us_representative: 1,
  state_senator: 2, state_representative: 3,
  governor: 4, lt_governor: 5,
  attorney_general: 6, state_auditor: 7, state_treasurer: 8
}

enum :level, { federal: 0, state: 1 }, prefix: true
# Enables: level_federal?, level_state?
```

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `bigint` | PK, auto | Primary key |
| `first_name` | `string` | NOT NULL | First name |
| `last_name` | `string` | NOT NULL | Last name |
| `full_name` | `string` | NOT NULL | Auto-set via `before_validation` callback |
| `slug` | `string` | UNIQUE | FriendlyId slug (e.g., `spencer-cox`) |
| `title` | `string` | | Display title (e.g., "U.S. Senator", "State Representative, District 5") |
| `position_type` | `integer` | NOT NULL | Enum — role within government |
| `level` | `integer` | NOT NULL | Enum — `federal` (0) or `state` (1) |
| `chamber` | `string` | | "Senate" or "House" (null for executives) |
| `party` | `string` | NOT NULL | "Republican", "Democrat", "Independent", etc. |
| `district` | `string` | | District number or null for statewide offices |
| `photo_url` | `string` | | URL to official headshot |
| `phone` | `string` | | Primary/office phone number |
| `phone_mobile` | `string` | | Mobile phone number |
| `phone_work` | `string` | | Work phone number |
| `phone_home` | `string` | | Home phone number |
| `email` | `string` | | Primary email address |
| `website_url` | `string` | | Official website URL |
| `twitter_handle` | `string` | | Twitter/X handle (without @) |
| `facebook_url` | `string` | | Facebook profile URL |
| `office_address` | `text` | | Office mailing address |
| `state` | `string` | indexed | Two-letter state code (e.g., "UT"). Used to filter Utah reps from non-Utah reps in the database. |
| `active` | `boolean` | DEFAULT true | Currently in office |
| `bioguide_id` | `string` | UNIQUE (conditional) | Congress.gov Biographical Directory ID |
| `utah_leg_id` | `string` | UNIQUE (conditional) | Utah Legislature API ID |
| `openstates_id` | `string` | UNIQUE (conditional) | OpenStates API ID |

**Associations:**
- `has_many :votes, dependent: :destroy`
- `has_many :bills, through: :votes`
- `has_many :action_scripts, dependent: :nullify`
- `has_many :featured_items, as: :featurable, dependent: :destroy`

**Scopes:**
| Scope | Query | Usage |
|-------|-------|-------|
| `active` | `where(active: true)` | Filter to current officials |
| `federal` | `where(level: :federal)` | Federal delegation only |
| `state_level` | `where(level: :state)` | State officials only |
| `senators` | `where(position_type: [:us_senator, :state_senator])` | All senators |
| `representatives` | `where(position_type: [:us_representative, :state_representative])` | All reps |
| `executives` | `where(position_type: [:governor, :lt_governor, ...])` | Statewide executives |
| `by_chamber(c)` | `where(chamber: c)` | Filter by chamber |
| `by_party(p)` | `where(party: p)` | Filter by party |
| `alphabetical` | `order(:last_name, :first_name)` | Sort A-Z |

**Key Methods:**
| Method | Returns | Example |
|--------|---------|---------|
| `display_name` | `"#{title} #{full_name}"` | "Governor Spencer Cox" |
| `party_abbrev` | First letter or "I" for Independent | "R", "D", "I" |
| `short_label` | `"Sen. #{full_name} (#{party_abbrev})"` | "Sen. Mike Lee (R)" |
| `phone_numbers` | Array of `{ label:, number: }` hashes | All non-blank phone fields |

**Indexes:**
- `slug` — unique
- `position_type`, `level`, `party`, `active` — query filters
- `bioguide_id`, `utah_leg_id`, `openstates_id` — unique conditional (WHERE NOT NULL)

---

### 3.2 Bill

Represents a piece of legislation at the state or federal level.

**File:** `app/models/bill.rb`

```ruby
enum :level, { federal: 0, state: 1 }, prefix: true
```

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `bigint` | PK, auto | Primary key |
| `title` | `string` | | Bill title |
| `bill_number` | `string` | | e.g., "HR 1234", "HB 245", "SB 89" |
| `slug` | `string` | UNIQUE | FriendlyId slug |
| `summary` | `text` | | Official summary from API |
| `editorial_summary` | `text` | | Plain-language "Why This Matters" explanation |
| `full_text_url` | `string` | | URL to full bill text |
| `status` | `string` | | Current status (e.g., "In Committee", "Passed House") |
| `level` | `integer` | | Enum — `federal` (0) or `state` (1) |
| `chamber` | `string` | | "Senate" or "House" |
| `session_year` | `integer` | | e.g., 2025, 2026 |
| `session_name` | `string` | | e.g., "119th Congress", "2025 General Session" |
| `featured` | `boolean` | DEFAULT false | Show on homepage |
| `introduced_on` | `date` | | Date bill was introduced |
| `last_action_on` | `date` | | Date of most recent action |
| `congress_bill_id` | `string` | UNIQUE (conditional) | Congress.gov ID |
| `utah_bill_id` | `string` | UNIQUE (conditional) | Utah Legislature ID (format: `{session}-{number}`) |
| `openstates_bill_id` | `string` | | OpenStates ID |
| `data_source` | `string` | | Origin: "congress_gov", "utah_legislature", "openstates", "seed" |

**Associations:**
- `has_many :votes, dependent: :destroy`
- `has_many :representatives, through: :votes`
- `has_many :action_scripts, dependent: :nullify`
- `has_many :featured_items, as: :featurable, dependent: :destroy`
- `has_many :issue_bills, dependent: :destroy`
- `has_many :issues, through: :issue_bills`

**Scopes:**
| Scope | Query | Usage |
|-------|-------|-------|
| `federal` | `where(level: :federal)` | Federal bills |
| `state_level` | `where(level: :state)` | State bills |
| `featured` | `where(featured: true)` | Homepage featured |
| `by_session(year)` | `where(session_year: year)` | Filter by year |
| `by_status(s)` | `where(status: s)` | Filter by status |
| `by_chamber(c)` | `where(chamber: c)` | Filter by chamber |
| `recent` | `order(last_action_on: :desc)` | Most recent first |
| `with_votes` | `joins(:votes).distinct` | Only bills with recorded votes |

**Key Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `vote_summary` | `{yes: N, no: N, abstain: N, not_voting: N}` | Aggregated vote counts |
| `has_editorial?` | `boolean` | Whether `editorial_summary` is present |

---

### 3.3 Vote

Join model linking representatives to bills with their voting position.

**File:** `app/models/vote.rb`

```ruby
enum :position, { yes: 0, no: 1, abstain: 2, not_voting: 3, present: 4 }
```

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `bigint` | PK, auto | Primary key |
| `representative_id` | `bigint` | FK, NOT NULL | Reference to representative |
| `bill_id` | `bigint` | FK, NOT NULL | Reference to bill |
| `position` | `integer` | NOT NULL | Enum — yes/no/abstain/not_voting/present |
| `voted_on` | `date` | | Date the vote was cast |
| `data_source` | `string` | | Origin API |

**Validations:**
- `position` — presence required
- `representative_id` — unique scoped to `bill_id` (one vote per rep per bill)

**Scopes:**
| Scope | Query |
|-------|-------|
| `recent` | `order(voted_on: :desc)` |
| `yes_votes` | `where(position: :yes)` |
| `no_votes` | `where(position: :no)` |

**Key Methods:**
| Method | Returns | Example |
|--------|---------|---------|
| `position_label` | Human-readable label | "Yea", "Nay", "Abstain", "Not Voting", "Present" |
| `position_css_class` | Tailwind classes | `"text-green-700 bg-green-100"` for yes |

**CSS Class Mapping:**

| Position | CSS Classes |
|----------|-------------|
| `yes` | `text-green-700 bg-green-100` |
| `no` | `text-red-700 bg-red-100` |
| `abstain` | `text-yellow-700 bg-yellow-100` |
| `not_voting` | `text-gray-700 bg-gray-100` |
| `present` | `text-blue-700 bg-blue-100` |

---

### 3.4 ActionScript

Call/email scripts that citizens can use to contact their representatives.

**File:** `app/models/action_script.rb`

```ruby
enum :action_type, { call: 0, email: 1 }
```

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `bigint` | PK, auto | Primary key |
| `title` | `string` | NOT NULL | Script title (e.g., "Call Senator Lee About Great Salt Lake") |
| `script_template` | `text` | NOT NULL | Template with placeholders |
| `context` | `text` | | Why this action matters |
| `action_type` | `integer` | NOT NULL | Enum — `call` (0) or `email` (1) |
| `representative_id` | `bigint` | FK (nullable) | Optional link to specific rep |
| `bill_id` | `bigint` | FK (nullable) | Optional link to specific bill |
| `active` | `boolean` | DEFAULT true | Currently shown |
| `featured` | `boolean` | DEFAULT false | Show on homepage |
| `sort_order` | `integer` | DEFAULT 0 | Display ordering |

**Template Placeholders:**

The `render_script` method replaces these tokens in `script_template`:

| Placeholder | Replaced With | Source |
|-------------|---------------|--------|
| `[REP_NAME]` | `representative.full_name` | Representative |
| `[REP_PHONE]` | `representative.phone` | Representative |
| `[REP_TITLE]` | `representative.title` | Representative |
| `[REP_EMAIL]` | `representative.email` | Representative |
| `[BILL_NUMBER]` | `bill.bill_number` | Bill |
| `[BILL_TITLE]` | `bill.title` | Bill |

**Implementation Note:** Uses `.dup` on the template string before `gsub!` because Ruby 4.0 freezes string literals by default.

---

### 3.5 FeaturedItem

Polymorphic model for curating homepage content sections.

**File:** `app/models/featured_item.rb`

```ruby
enum :section, { hero: 0, spotlight: 1, recent_actions: 2 }
```

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `bigint` | PK, auto | Primary key |
| `featurable_type` | `string` | NOT NULL | Polymorphic type ("Representative" or "Bill") |
| `featurable_id` | `bigint` | NOT NULL | Polymorphic ID |
| `headline` | `string` | NOT NULL | Display headline |
| `description` | `text` | | Short description |
| `section` | `integer` | NOT NULL | Enum — where to display |
| `sort_order` | `integer` | DEFAULT 0 | Display ordering within section |
| `active` | `boolean` | DEFAULT true | Currently shown |

**Section Types:**
| Section | Integer | Usage |
|---------|---------|-------|
| `hero` | 0 | Top-of-page hero carousel (limit 3) |
| `spotlight` | 1 | Featured officials grid (limit 4) |
| `recent_actions` | 2 | Recent legislative actions |

**Scopes:**
| Scope | Query |
|-------|-------|
| `active` | `where(active: true)` |
| `ordered` | `order(:sort_order)` |
| `heroes` | `active.where(section: :hero).ordered` |
| `spotlights` | `active.where(section: :spotlight).ordered` |
| `recent` | `active.where(section: :recent_actions).ordered` |

---

### 3.6 Issue

Represents a curated policy topic with editorial stance labels for accountability scorecards.

**File:** `app/models/issue.rb`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `bigint` | PK, auto | Primary key |
| `name` | `string` | NOT NULL, UNIQUE | Issue title |
| `slug` | `string` | UNIQUE | FriendlyId slug from name |
| `description` | `text` | | Editorial description (aggressive tone) |
| `stance_label` | `string` | NOT NULL | Green label for aligned votes |
| `against_label` | `string` | NOT NULL | Red label for opposing votes |
| `active` | `boolean` | DEFAULT true | Show on site |
| `sort_order` | `integer` | DEFAULT 0 | Display ordering |
| `icon` | `string` | | Emoji for visual identity |

**Associations:**
- `has_many :issue_bills, dependent: :destroy`
- `has_many :bills, through: :issue_bills`

**Scopes:**
| Scope | Query |
|-------|-------|
| `active` | `where(active: true)` |
| `ordered` | `order(:sort_order, :name)` |

**Key Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `accountability_score(rep, votes_lookup:)` | `{ aligned:, against:, no_vote:, total:, score: }` | Per-rep scoring |
| `vote_alignment_css(vote, ib)` | CSS classes | Green/red/gray based on alignment |
| `vote_alignment_label(vote, ib)` | String | stance_label or against_label |

---

### 3.7 IssueBill

Join model linking issues to bills with the "popular position."

**File:** `app/models/issue_bill.rb`

```ruby
enum :popular_position, { yes: 0, no: 1 }
```

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `bigint` | PK, auto | Primary key |
| `issue_id` | `bigint` | FK, NOT NULL | Reference to issue |
| `bill_id` | `bigint` | FK, NOT NULL | Reference to bill |
| `popular_position` | `integer` | NOT NULL, DEFAULT 0 | What the people want |
| `sort_order` | `integer` | DEFAULT 0 | Display ordering |

**Validations:**
- `issue_id` — unique scoped to `bill_id`
- `popular_position` — presence required

**Key Methods:**
| Method | Returns | Example |
|--------|---------|---------|
| `popular_position_label` | "Vote YES" or "Vote NO" | Display helper |

---

## 4. Database Indexes

### 4.1 Representatives

| Index | Columns | Options |
|-------|---------|---------|
| `index_representatives_on_slug` | `slug` | `unique: true` |
| `index_representatives_on_position_type` | `position_type` | |
| `index_representatives_on_level` | `level` | |
| `index_representatives_on_party` | `party` | |
| `index_representatives_on_active` | `active` | |
| `index_representatives_on_state` | `state` | |
| `index_representatives_on_bioguide_id` | `bioguide_id` | `unique: true, where: "bioguide_id IS NOT NULL"` |
| `index_representatives_on_utah_leg_id` | `utah_leg_id` | `unique: true, where: "utah_leg_id IS NOT NULL"` |
| `index_representatives_on_openstates_id` | `openstates_id` | `unique: true, where: "openstates_id IS NOT NULL"` |

### 4.2 Bills

| Index | Columns | Options |
|-------|---------|---------|
| `index_bills_on_slug` | `slug` | `unique: true` |
| `index_bills_on_level` | `level` | |
| `index_bills_on_session_year` | `session_year` | |
| `index_bills_on_featured` | `featured` | |
| `index_bills_on_status` | `status` | |
| `index_bills_on_congress_bill_id` | `congress_bill_id` | `unique: true, where: "congress_bill_id IS NOT NULL"` |
| `index_bills_on_utah_bill_id` | `utah_bill_id` | `unique: true, where: "utah_bill_id IS NOT NULL"` |

### 4.3 Votes

| Index | Columns | Options |
|-------|---------|---------|
| `index_votes_on_representative_id` | `representative_id` | |
| `index_votes_on_bill_id` | `bill_id` | |
| `index_votes_on_rep_and_bill` | `[representative_id, bill_id]` | `unique: true` |

### 4.4 Issues

| Index | Columns | Options |
|-------|---------|---------|
| `index_issues_on_slug` | `slug` | `unique: true` |
| `index_issues_on_active` | `active` | |
| `index_issues_on_sort_order` | `sort_order` | |

### 4.5 IssueBills

| Index | Columns | Options |
|-------|---------|---------|
| `index_issue_bills_on_issue_id` | `issue_id` | |
| `index_issue_bills_on_bill_id` | `bill_id` | |
| `index_issue_bills_on_issue_and_bill` | `[issue_id, bill_id]` | `unique: true` |

---

## 5. Seed Data

**File:** `db/seeds.rb` (idempotent — safe to re-run)

| Category | Count | Details |
|----------|-------|---------|
| Executives | 5 | Governor, Lt. Governor, AG, Auditor, Treasurer |
| Federal Delegation | 6 | 2 Senators + 4 House Reps (Districts 1-4) |
| Bills | 4 | 2 federal + 2 state, 3 featured |
| Votes | 8 | Sample votes linking reps to bills |
| Action Scripts | 4 | 3 call scripts + 1 email script |
| Featured Items | 4 | Spotlight items for 4 reps |
| Issues | 4 | Hot-button policy topics with editorial descriptions |
| Issue-Bill Links | 3 | Sample bill-to-issue associations |

---

## 6. Design Decisions

### 6.1 Why a Single Representative Table?

All Utah officials (governor, state legislators, federal delegation) share the same table with a `position_type` enum to differentiate roles.

**Alternatives considered:**
1. Separate tables per role (FederalRep, StateLegislator, Executive) — Rejected: too much duplication, harder to query across levels
2. STI (Single Table Inheritance) — Rejected: minimal behavior differences don't warrant subclasses

**Trade-offs:**
- Pro: Simple queries across all levels, single index page, consistent associations
- Con: Some columns unused for certain types (e.g., executives have no `chamber`)

### 6.2 Why Polymorphic FeaturedItem?

Allows curating both representatives and bills on the homepage from a single model.

**Alternatives considered:**
1. Boolean `featured` columns on each model — Rejected: no headline/description, no section control, no ordering
2. Separate FeaturedRep/FeaturedBill tables — Rejected: duplicated logic

### 6.3 Why Optional FKs on ActionScript?

Scripts can be general-purpose (no rep or bill), linked to a specific rep, linked to a specific bill, or both. Optional foreign keys with `dependent: :nullify` ensure scripts survive if a rep or bill is deleted.

---

## 7. Implementation Notes

- Schema file: `db/schema.rb`
- Migrations: `db/migrate/20260302170709_create_representatives.rb` through `20260302170743_create_featured_items.rb`, plus `20260303165905_add_state_to_representatives.rb`
- Models: `app/models/*.rb`
- Seeds: `db/seeds.rb`
