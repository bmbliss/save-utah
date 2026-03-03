# Issues & Accountability Scorecards

**Status:** Implemented
**Version:** 1.0
**Last Updated:** 2026-03-02

---

## 1. Overview

### 1.1 Purpose

The Issues system is Save Utah's core differentiating feature. It curates hot-button policy issues (immigration, SAVE Act, insider trading, etc.), links them to bills, and auto-generates accountability scorecards showing which representatives voted with the people and who sold them out. Contact info is shown inline so citizens can take immediate action.

### 1.2 Goals

- Enable editorial-driven issue pages with aggressive, populist tone
- Auto-generate accountability scorecards from existing Vote data
- Provide one-click contact (phone/email) directly from the scorecard
- Sort representatives worst-offenders-first for maximum impact
- Mobile-friendly with horizontally scrollable scorecard tables

### 1.3 Non-Goals

- User-submitted issues or voting
- Real-time vote tracking
- Automated issue creation from bill data

### 1.4 Related Specifications

- [Data Model](./data-model.md) — Issue and IssueBill schemas
- [Representatives System](./representatives-system.md) — Representative model and phone_numbers helper
- [Bills System](./bills-system.md) — Bill model and associations
- [Frontend System](./frontend-system.md) — Tailwind theme and layout patterns

---

## 2. Data Model

### 2.1 Issue

Represents a curated policy topic with editorial stance labels.

**File:** `app/models/issue.rb`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `bigint` | PK, auto | Primary key |
| `name` | `string` | NOT NULL, UNIQUE | Issue title (e.g., "End Insider Trading by Members of Congress") |
| `slug` | `string` | UNIQUE | FriendlyId slug from name |
| `description` | `text` | | Editorial description — aggressive, populist tone |
| `stance_label` | `string` | NOT NULL | Green label for aligned votes (e.g., "Protect Taxpayers") |
| `against_label` | `string` | NOT NULL | Red label for opposing votes (e.g., "Funded Illegal Benefits") |
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

### 2.2 IssueBill

Join model linking issues to bills with the "popular position" — what the people want.

**File:** `app/models/issue_bill.rb`

```ruby
enum :popular_position, { yes: 0, no: 1 }
```

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `bigint` | PK, auto | Primary key |
| `issue_id` | `bigint` | FK, NOT NULL | Reference to issue |
| `bill_id` | `bigint` | FK, NOT NULL | Reference to bill |
| `popular_position` | `integer` | NOT NULL, DEFAULT 0 | What the people want: yes (0) or no (1) |
| `sort_order` | `integer` | DEFAULT 0 | Display ordering |

**Unique Index:** `(issue_id, bill_id)` — one bill per issue

---

## 3. Scoring Logic

### 3.1 Accountability Score

The `Issue#accountability_score(representative, votes_lookup:)` method computes per-rep scores:

```
For each issue_bill:
  1. Look up the rep's vote on that bill
  2. If no vote → count as no_vote
  3. If vote.position matches issue_bill.popular_position → aligned
  4. Otherwise → against

Score = (aligned / (aligned + against)) * 100
  - no_vote is excluded from the denominator
  - Returns nil if rep never voted on any bill in the issue
```

### 3.2 Vote Alignment

A vote is "aligned" when:
- `issue_bill.popular_position == :yes` AND `vote.position == :yes`
- `issue_bill.popular_position == :no` AND `vote.position == :no`

All other vote positions (abstain, not_voting, present) count as "against."

### 3.3 CSS Color Coding

| Alignment | CSS Classes | Meaning |
|-----------|-------------|---------|
| Aligned | `bg-green-100 text-green-800` | Voted with the people |
| Against | `bg-red-100 text-red-800` | Sold you out |
| No Vote | `bg-gray-100 text-gray-400` | Didn't show up |

Score color: green if >= 50%, red if < 50%.

---

## 4. Controller

**File:** `app/controllers/issues_controller.rb`

### 4.1 Index

```ruby
@issues = Issue.active.ordered
```

### 4.2 Show (Blast Page)

The show action performs efficient data loading to prevent N+1 queries:

1. Load issue by friendly slug
2. Load issue_bills with eager-loaded bills
3. **Build votes lookup hash:** `{ [rep_id, bill_id] => vote }` — single query
4. **Collect representatives** from vote data
5. **Pre-compute scores** for each rep using the votes lookup
6. **Sort worst-first** — lowest score first, nil scores last
7. Load related action scripts

---

## 5. Views

### 5.1 Issues Index (`app/views/issues/index.html.erb`)

- Navy hero banner: "The Issues That Matter"
- 2-column grid of issue cards (1-col on mobile)

### 5.2 Issue Card Partial (`app/views/shared/_issue_card.html.erb`)

Reusable on both index and homepage. Shows:
- Icon + name
- Description preview (line-clamp-3)
- Bill count badge
- "View Scorecard" CTA
- Hover: border turns utah-red

### 5.3 Blast Page (`app/views/issues/show.html.erb`)

The core feature — four sections:

1. **Hero** — Navy background, icon, issue name, editorial description, stance/against badges
2. **Related Bills** — Grid of bills with popular position badges ("The People Want: Vote YES")
3. **Accountability Scorecard Table** — horizontally scrollable table with:
   - Sticky rep name column on mobile
   - Vote cells per bill (green/red/gray)
   - Score column (percentage, color-coded)
   - Contact column (tel: links, mailto: with pre-filled subject)
4. **Take Action** — Related action scripts

### 5.4 Accountability Row Partial (`app/views/shared/_accountability_row.html.erb`)

One table row per representative:
- Photo/initials + name (linked) + party badge
- Vote cells using `issue.vote_alignment_css`
- Score display (font-black, color-coded)
- Phone numbers via `representative.phone_numbers` helper
- Email link with pre-filled subject line

---

## 6. Navigation Integration

- **Desktop navbar:** "Issues" link positioned first (before Representatives)
- **Mobile menu:** "Issues" link first
- **Footer:** "Issues & Scorecards" in Navigate section
- **Homepage:** "Issues That Matter" section between hero and featured officials (limit 4)

---

## 7. Seed Data

Four issues with aggressive editorial descriptions:

| Issue | Icon | Stance Label | Against Label |
|-------|------|-------------|---------------|
| Stop Taxpayer Benefits to Illegal Immigrants | :no_entry: | Protect Taxpayers | Funded Illegal Benefits |
| No Driver's Licenses for Illegal Aliens (SAVE Act) | :ballot_box: | Protect the Ballot Box | Enabled Illegal Voting Risk |
| End Insider Trading by Members of Congress | :moneybag: | Banned Congressional Trading | Protected Insider Profits |
| No AI Data Centers Without Electric Bill Protections | :zap: | Protected Ratepayers | Let Big Tech Raise Your Bills |

Sample bills are linked to issues for demo purposes.

---

## 8. Performance Considerations

- **Votes lookup hash** built in controller prevents N+1 in scorecard table
- **Pre-computed scores** avoid redundant calculations in the view
- **Eager loading** on issue_bills → bills and votes → representative
- **Index on `(issue_id, bill_id)`** ensures fast join lookups
