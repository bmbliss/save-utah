# Data Import System

**Status:** Implemented
**Version:** 1.0
**Last Updated:** 2026-03-02

---

## 1. Overview

### 1.1 Purpose

Automated data pipeline that pulls elected official profiles, legislation, and voting records from three government APIs into the Save Utah database. All imports are idempotent and safe to re-run.

### 1.2 Goals

- Import Utah's full federal delegation from Congress.gov
- Import Utah state legislators from the Utah Legislature API
- Import bills and voting records from both levels
- Provide OpenStates as a fallback/supplementary source
- Make imports idempotent — re-running updates existing records instead of creating duplicates

### 1.3 Non-Goals

- Background job processing (rake tasks run synchronously for MVP)
- Webhook-based real-time updates
- Importing data for states other than Utah
- Storing raw API responses

### 1.4 API Documentation Links

- **Congress.gov API:** https://github.com/LibraryOfCongress/api.congress.gov/
- **Utah Legislature API:** https://le.utah.gov/data/developer.htm
- **OpenStates API v3:** https://docs.openstates.org/api-v3/

### 1.5 Related Specifications

- [Architecture](./architecture.md) — System-level overview
- [Data Model](./data-model.md) — Database schema the importers write to

---

## 2. Architecture

### 2.1 System Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                      Rake Tasks                               │
│  import:all  →  import:all_members  →  import:all_bills      │
│                                     →  import:all_votes      │
└──────────────────────┬───────────────────────────────────────┘
                       │ instantiates
                       ▼
┌──────────────────────────────────────────────────────────────┐
│                     Importers                                 │
│                                                               │
│  CongressGov::          UtahLegislature::    OpenStates::     │
│  ├─ MemberImporter      ├─ LegislatorImp     ├─ PeopleImp   │
│  ├─ BillImporter        ├─ BillImporter      ├─ BillImp     │
│  └─ VoteImporter        └─ VoteImporter      └─ VoteImp*    │
│                              (backup)         (*primary for  │
│                                                state votes)  │
│                                                               │
│  Each importer wraps a Client and maps API → Model            │
└──────────────────────┬───────────────────────────────────────┘
                       │ uses
                       ▼
┌──────────────────────────────────────────────────────────────┐
│                    API Clients                                │
│                                                               │
│  ApiClient (base)         Faraday HTTP + JSON parsing        │
│  ├─ CongressGov::Client   https://api.congress.gov/v3        │
│  ├─ UtahLeg::Client       https://glen.le.utah.gov           │
│  └─ OpenStates::Client    https://v3.openstates.org          │
└──────────────────────┬───────────────────────────────────────┘
                       │ HTTP GET
                       ▼
┌──────────────────────────────────────────────────────────────┐
│                   External APIs                               │
│  Congress.gov API    Utah Legislature API    OpenStates v3    │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 Directory Structure

```
app/services/
├── api_client.rb                    # Base class — Faraday, error handling, logging
├── congress_gov/
│   ├── client.rb                    # Congress.gov v3 API wrapper
│   ├── member_importer.rb           # Utah federal delegation
│   ├── bill_importer.rb             # Federal bills
│   └── vote_importer.rb             # House roll call votes
├── utah_legislature/
│   ├── client.rb                    # glen.le.utah.gov API wrapper
│   ├── legislator_importer.rb       # State legislators
│   ├── bill_importer.rb             # State bills
│   └── vote_importer.rb             # State floor votes
└── open_states/
    ├── client.rb                    # OpenStates v3 API wrapper
    ├── people_importer.rb           # Supplementary people data
    ├── bill_importer.rb             # Fallback bill data
    └── vote_importer.rb             # PRIMARY source for state votes

lib/tasks/
└── import.rake                      # Rake task definitions
```

---

## 3. Base API Client

**File:** `app/services/api_client.rb`

All service clients inherit from `ApiClient`, which provides:

```ruby
class ApiClient
  MAX_RETRIES = 3

  # Subclasses override:
  #   base_url          — API root URL
  #   configure_connection — custom Faraday middleware

  # Provides:
  #   connection         — configured Faraday instance
  #   get(path, params)  — HTTP GET with error handling + retry
  #   log(message)       — stdout logging for import progress
end
```

**Faraday Configuration:**
| Setting | Value |
|---------|-------|
| User-Agent | `"SaveUtah/1.0 (civic-engagement-platform)"` |
| Response format | JSON (auto-parsed) |
| Timeout | Default Faraday timeouts |

**Rate Limit Retry:**
On HTTP 429 (Too Many Requests), the client retries up to `MAX_RETRIES` (3) times with exponential backoff (2s, 4s, 8s). If all retries are exhausted, `RateLimitError` is raised.

**Error Classes:**

| Error | When Raised |
|-------|-------------|
| `ApiClient::RateLimitError` | HTTP 429 after 3 retries with backoff |
| `ApiClient::NotFoundError` | HTTP 404 response |
| `ApiClient::ApiError` | All other non-2xx responses (includes response body in message for debugging) |

---

## 4. API Clients

### 4.1 CongressGov::Client

**File:** `app/services/congress_gov/client.rb`
**Base URL:** `https://api.congress.gov/v3`
**Docs:** https://github.com/LibraryOfCongress/api.congress.gov/
**Auth:** `CONGRESS_GOV_API_KEY` appended as query parameter
**Rate Limit:** 5,000 requests/hour

| Method | Endpoint | Returns |
|--------|----------|---------|
| `utah_members(limit:)` | `GET /member/UT` | Array of sparse member objects (name, bioguideId, partyName, terms). Current + historical. |
| `member(bioguide_id)` | `GET /member/{id}` | Full member detail (firstName, lastName, phone, website, etc.) |
| `bills(congress, limit, offset)` | `GET /bill/{congress}` | Paginated bill list |
| `bill(congress, type, number)` | `GET /bill/{congress}/{type}/{number}` | Single bill detail |
| `bill_actions(congress, type, number)` | `GET /bill/{congress}/{type}/{number}/actions` | Bill action history |
| `house_votes(congress, session, limit, offset)` | `GET /house-vote/{congress}/{session}` | Paginated House roll call votes (key: `houseRollCallVotes`) |
| `house_vote(congress, session, roll)` | `GET /house-vote/{congress}/{session}/{roll}` | Single vote detail |
| `house_vote_members(congress, session, roll)` | `GET /house-vote/{congress}/{session}/{roll}/members` | Individual member votes for a roll call |

### 4.2 UtahLegislature::Client

**File:** `app/services/utah_legislature/client.rb`
**Base URL:** `https://glen.le.utah.gov`
**Docs:** https://le.utah.gov/data/developer.htm
**Auth:** `UTAH_LEGISLATURE_TOKEN` appended to URL **path** (not query param)
**Rate Limits:** Unknown (not documented; appears unrestricted in testing)

| Method | Endpoint | Returns |
|--------|----------|---------|
| `legislators` | `GET /legislators/{token}` | Array of legislator objects |
| `bills(session:)` | `GET /bills/{session}/billlist/{token}` | Sparse list (number, trackingID, updatetime, lastActionTime only) |
| `bill(session, number)` | `GET /bills/{session}/{number}/{token}` | Full bill detail (shortTitle, generalProvisions, actionHistoryList, etc.) |
| `bill_votes(session, number)` | Embedded in bill detail | Vote data (may be empty — use OpenStates as primary) |

### 4.3 OpenStates::Client

**File:** `app/services/open_states/client.rb`
**Base URL:** `https://v3.openstates.org`
**Docs:** https://docs.openstates.org/api-v3/
**Auth:** `OPENSTATES_API_KEY` in `X-API-KEY` header
**Role:** Supplementary/fallback source + PRIMARY for state votes

| Method | Endpoint | Returns |
|--------|----------|---------|
| `utah_people(chamber:)` | `GET /people?jurisdiction=Utah` | Array of people (chamber must be "upper" or "lower") |
| `person(id)` | `GET /people/{id}` | Single person detail |
| `utah_bills(session, page, per_page, include_votes:)` | `GET /bills?jurisdiction=Utah` | Paginated bills (pass `include_votes: true` for embedded vote data). **`per_page` capped at 20** (OpenStates max). Default: 20. |
| `bill(id, include_votes:)` | `GET /bills/{id}` | Single bill detail |

---

## 5. Importers

### 5.1 Import Pattern

All importers follow the same idempotent pattern:

```ruby
# 1. Fetch data from API
data = client.fetch_endpoint

# 2. For each record:
data.each do |api_record|
  # Find existing or create new
  model = Model.find_or_initialize_by(external_id: api_record["id"])

  # Map API fields to model attributes
  model.assign_attributes(
    field_a: api_record["fieldA"],
    field_b: normalize(api_record["fieldB"])
  )

  # Persist
  model.save!
end
```

### 5.2 Member/People Importers

#### CongressGov::MemberImporter

**File:** `app/services/congress_gov/member_importer.rb`

**Two-step fetch:** The list endpoint (`/member/UT`) returns sparse data (inverted `name`, `bioguideId`, `partyName`, `terms`). Imports all members (current + historical); `active` is set from `detail["currentMember"]`. A detail call (`/member/{bioguideId}`) is made for each member to get full fields.

| API Field (Detail) | Model Field | Transformation |
|-----------|-------------|----------------|
| `bioguideId` | `bioguide_id` | Direct |
| `firstName`, `lastName` | `first_name`, `last_name` | From detail response |
| `directOrderName` | `full_name` | Fallback to "firstName lastName" |
| `partyName` | `party` | Normalized |
| `terms.current.chamber` | `position_type` | "Senate" → `us_senator`, "House" → `us_representative` |
| `terms.current.district` | `district` | Direct |
| `depiction.imageUrl` | `photo_url` | Available on list and detail |
| `officialWebsiteUrl` | `website_url` | Detail only |
| `addressInformation.officePhone` | `phone` | Detail only |

**Fallback:** If detail lacks name fields, parses inverted `name` from list ("Lee, Mike" → first: "Mike", last: "Lee").

**Derived fields:**
- `level` → always `federal`
- `title` → "U.S. Senator" or "U.S. Representative, District N"
- `chamber` → "Senate" or "House"

#### UtahLegislature::LegislatorImporter

**File:** `app/services/utah_legislature/legislator_importer.rb`

| API Field | Model Field | Transformation |
|-----------|-------------|----------------|
| `id` | `utah_leg_id` | Short code like "PETERT" |
| `formatName` | `full_name` | Display order ("Thomas W. Peterson") |
| `fullName` | `first_name`, `last_name` | Parsed from inverted format ("Peterson, Thomas W.") |
| `house` | `position_type` | "S" → `state_senator`, "H" → `state_representative` |
| `district` | `district` | Direct |
| `party` | `party` | Normalized: "R" → "Republican", "D" → "Democrat" |
| `cell` / `workPhone` / `homePhone` | `phone` | First available |
| `email` | `email` | Direct |
| `image` | `photo_url` | Full URL to headshot |
| `address` | `office_address` | Direct |

#### OpenStates::PeopleImporter

**File:** `app/services/open_states/people_importer.rb`

- Supplementary source — tries to match existing records first
- Match by `openstates_id`, then falls back to name + level matching
- Primarily fills in missing contact info or photos

### 5.3 Bill Importers

#### CongressGov::BillImporter

**File:** `app/services/congress_gov/bill_importer.rb`

| API Field | Model Field | Transformation |
|-----------|-------------|----------------|
| `number` | `congress_bill_id` | Direct |
| `title` | `title` | Direct |
| `type` + `number` | `bill_number` | e.g., "HR 1234" |
| `type` | `chamber` | s/sres → "Senate", hr/hres → "House" |
| `latestAction.text` | `status` | Direct |
| `introducedDate` | `introduced_on` | Date parse |
| `latestAction.actionDate` | `last_action_on` | Date parse |

**Defaults:** `level: :federal`, `data_source: "congress_gov"`, `session_year` from congress number

#### UtahLegislature::BillImporter

**File:** `app/services/utah_legislature/bill_importer.rb`

**Two-step fetch:** The bill list endpoint returns sparse data (`number`, `trackingID`, `updatetime`, `lastActionTime` only). A detail call is made for each bill to get full fields (`shortTitle`, `generalProvisions`, `lastAction`, `actionHistoryList`, `billVersionList`, etc.).

| API Field (Detail) | Model Field | Transformation |
|-----------|-------------|----------------|
| `billNumber` | `bill_number` | Direct |
| — | `utah_bill_id` | `"#{session}-#{bill_number}"` |
| `shortTitle` | `title` | Direct |
| `generalProvisions` | `summary` | Direct |
| `billNumber` prefix | `chamber` | HB/HJR/HCR → "House", SB/SJR/SCR → "Senate" |
| `lastAction` | `status` | Direct |
| `lastActionDate` | `last_action_on` | Date parse |
| `billVersionList[].billDocs[].url` | `full_text_url` | Prefers enrolled, then introduced |

**Session name parsing:** "2025GS" → "2025 General Session", "2025S1" → "2025 Special Session"

### 5.4 Vote Importers

#### CongressGov::VoteImporter

**File:** `app/services/congress_gov/vote_importer.rb`

- **Paginates** through all House roll call votes (250 per page via `offset`)
- List uses `rollCallNumber` field (not `rollNumber`)
- **Member votes come from a SEPARATE endpoint** (`house_vote_members`), not embedded in vote detail
- Bill linkage uses top-level `legislationNumber`/`legislationType` from the list data
- **Auto-creates stub bills** when a vote references a bill not yet imported (title: "HR 1234 (details pending import)")
- Caches Utah reps by `bioguide_id` for fast lookup

**Position Normalization (field: `voteCast`):**
| API Value | Model Position |
|-----------|----------------|
| `"Aye"`, `"Yea"` | `yes` |
| `"Nay"`, `"No"` | `no` |
| `"Present"` | `present` |
| `"Not Voting"` | `not_voting` |

#### UtahLegislature::VoteImporter

**File:** `app/services/utah_legislature/vote_importer.rb`

- **Backup source** — Utah Legislature API may not have dedicated vote endpoints
- Vote data is embedded in bill detail JSON (if available)
- Caches state reps by `utah_leg_id`
- Iterates state bills, extracts vote arrays, creates Vote records

**Position Normalization:**
| API Value | Model Position |
|-----------|----------------|
| `"yea"`, `"yes"`, `"y"`, `"aye"` | `yes` |
| `"nay"`, `"no"`, `"n"` | `no` |
| `"absent"`, `"abs"` | `not_voting` |
| `"abstain"` | `abstain` |

#### OpenStates::VoteImporter

**File:** `app/services/open_states/vote_importer.rb`

- **PRIMARY source for state votes** (Utah Legislature API has no dedicated vote endpoints)
- Fetches bills with `include: "votes"` to get embedded vote data
- Each bill response contains `votes[]` with individual vote records
- **Targets completed sessions** — `DEFAULT_SESSIONS = ["2024", "2023"]` because OpenStates has no vote data for current/ongoing sessions
- Accepts `sessions:` (array of session identifiers) and `pages_per_session:` params
- 1-second delay between API pages to respect rate limits

**Bill Matching:**
1. Match by `openstates_bill_id` (if previously cross-referenced)
2. Match by exact `bill_number` + `level: :state`
3. **Normalize bill number:** converts OpenStates format (`"HB 1"`) to Utah Legislature format (`"HB0001"`) via `normalize_bill_number` — strips spaces, zero-pads the number to 4 digits

**Voter Matching:**
1. Match by `openstates_id` (OCD person ID) — preferred
2. Parse abbreviated voter name (`"Snider, C."` → last name + first initial) and match against Representatives by `last_name` + `first_name` initial
3. If only one rep with that last name, use them directly
4. **Backfills `openstates_id`** on matched Representatives for faster future lookups

**Position Normalization (field: `option`):**
| API Value | Model Position |
|-----------|----------------|
| `"yes"`, `"yea"`, `"aye"` | `yes` |
| `"no"`, `"nay"` | `no` |
| `"absent"`, `"excused"`, `"not voting"`, `"other"` | `not_voting` |
| `"abstain"` | `abstain` |
| `"present"` | `present` |

---

## 6. Rake Tasks

**File:** `lib/tasks/import.rake`

### 6.1 Task Hierarchy

```
import:all
├── import:all_members
│   ├── import:federal_members     (CongressGov::MemberImporter)
│   └── import:state_legislators   (UtahLegislature::LegislatorImporter)
├── import:all_bills
│   ├── import:federal_bills       (CongressGov::BillImporter)
│   └── import:state_bills         (UtahLegislature::BillImporter)
└── import:all_votes
    ├── import:federal_votes       (CongressGov::VoteImporter)
    └── import:state_votes         (OpenStates::VoteImporter)  ← changed from UtahLegislature

# Supplementary / Fallback (not included in import:all)
import:openstates_people           (OpenStates::PeopleImporter)
import:openstates_bills            (OpenStates::BillImporter)
import:openstates_votes            (OpenStates::VoteImporter — alias for state_votes)
import:utah_legislature_votes      (UtahLegislature::VoteImporter — backup if bill detail has votes)
```

### 6.2 Usage

```bash
# Full import (members → bills → votes, in order)
rake import:all

# Individual imports
rake import:federal_members
rake import:state_legislators
rake import:federal_bills
rake import:state_bills
rake import:federal_votes
rake import:state_votes

# Supplementary / Fallback
rake import:openstates_people
rake import:openstates_bills
rake import:openstates_votes           # alias for state_votes
rake import:utah_legislature_votes     # backup — if bill detail has votes
```

### 6.3 Import Order Dependency

```
Members MUST be imported before Votes (votes match by bioguide_id / openstates_id)
Bills SHOULD be imported before Votes (federal vote importer auto-creates stub bills if needed)
```

`import:all` enforces this order: members → bills → votes.

---

## 7. Configuration

### 7.1 Environment Variables

| Variable | Required | Default | Used By |
|----------|----------|---------|---------|
| `CONGRESS_GOV_API_KEY` | Yes (for federal imports) | — | `CongressGov::Client` |
| `UTAH_LEGISLATURE_TOKEN` | Yes (for state imports) | — | `UtahLegislature::Client` |
| `OPENSTATES_API_KEY` | Yes (for fallback imports) | — | `OpenStates::Client` |

### 7.2 Rate Limits

| API | Limit | Notes |
|-----|-------|-------|
| Congress.gov | 5,000 req/hr | Generous for batch imports |
| Utah Legislature | Unknown | Not documented; no throttling observed in testing |
| OpenStates | ~10 req/min (free tier), `per_page` max 20 | 1s delay between pages + retry-with-backoff handles this |

---

## 8. Error Handling

### 8.1 Error Types

| Error | Trigger | Handling |
|-------|---------|----------|
| `RateLimitError` | HTTP 429 (after 3 retries) | Retried 3× with exponential backoff (2s, 4s, 8s). If exhausted, raised and import aborts. |
| `NotFoundError` | HTTP 404 | Logged, record skipped |
| `ApiError` | Other non-2xx | Logged with details (includes API response body), record skipped |
| `ActiveRecord::RecordInvalid` | Validation failure | Logged, import continues |

### 8.2 Logging

All importers use `ApiClient#log` which writes to `$stdout`:
```
[CongressGov::MemberImporter] Importing 6 Utah members...
[CongressGov::MemberImporter] Saved: Mike Lee (us_senator)
[CongressGov::MemberImporter] Import complete: 6 members processed
```

---

## 9. Design Decisions

### 9.1 Why Rake Tasks Instead of Background Jobs?

For the MVP, synchronous rake tasks are simpler and sufficient. Data changes infrequently (daily at most), and imports complete in minutes.

**Future path:** Migrate to Solid Queue background jobs with scheduled execution via cron or Fly.io scheduled machines.

### 9.2 Why Three API Sources?

- **Congress.gov** — Authoritative source for federal data, but limited to federal scope
- **Utah Legislature** — Authoritative source for state data, but has aggressive rate limits
- **OpenStates** — Aggregates both levels, useful as fallback when primary sources are incomplete

### 9.3 Why Idempotent Imports?

`find_or_initialize_by` + `assign_attributes` means every import is safe to re-run. This eliminates the need for tracking "last imported" timestamps and allows manual re-imports when data issues are found.

---

## 10. Future Enhancements

- [ ] Move imports to Solid Queue background jobs
- [ ] Add cron scheduling (via `whenever` gem or Fly.io)
- [ ] Senate vote parsing (senate.gov XML, not yet in Congress.gov API)
- [ ] Historical session imports (past congresses and legislative sessions)
- [ ] Import progress tracking with database-stored timestamps
- [x] Retry logic with exponential backoff for rate-limited APIs

---

## 11. Implementation Notes

- Base client: `app/services/api_client.rb`
- Congress.gov services: `app/services/congress_gov/`
- Utah Legislature services: `app/services/utah_legislature/`
- OpenStates services: `app/services/open_states/`
- Rake tasks: `lib/tasks/import.rake`
