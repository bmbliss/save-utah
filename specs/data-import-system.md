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

### 1.4 Related Specifications

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
│  ├─ BillImporter        ├─ BillImporter      └─ BillImp     │
│  └─ VoteImporter        └─ VoteImporter                     │
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
    └── bill_importer.rb             # Fallback bill data

lib/tasks/
└── import.rake                      # Rake task definitions
```

---

## 3. Base API Client

**File:** `app/services/api_client.rb`

All service clients inherit from `ApiClient`, which provides:

```ruby
class ApiClient
  # Subclasses override:
  #   base_url          — API root URL
  #   configure_connection — custom Faraday middleware

  # Provides:
  #   connection         — configured Faraday instance
  #   get(path, params)  — HTTP GET with error handling
  #   log(message)       — stdout logging for import progress
end
```

**Faraday Configuration:**
| Setting | Value |
|---------|-------|
| User-Agent | `"SaveUtah/1.0 (civic-engagement-platform)"` |
| Response format | JSON (auto-parsed) |
| Timeout | Default Faraday timeouts |

**Error Classes:**

| Error | When Raised |
|-------|-------------|
| `ApiClient::RateLimitError` | HTTP 429 response |
| `ApiClient::NotFoundError` | HTTP 404 response |
| `ApiClient::ApiError` | All other non-2xx responses |

---

## 4. API Clients

### 4.1 CongressGov::Client

**File:** `app/services/congress_gov/client.rb`
**Base URL:** `https://api.congress.gov/v3`
**Auth:** `CONGRESS_GOV_API_KEY` appended as query parameter
**Rate Limit:** 5,000 requests/hour

| Method | Endpoint | Returns |
|--------|----------|---------|
| `utah_members` | `GET /member?stateCode=UT&currentMember=true` | Array of member objects |
| `member(bioguide_id)` | `GET /member/{id}` | Single member detail |
| `bills(congress, limit, offset)` | `GET /bill/{congress}` | Paginated bill list |
| `bill(congress, type, number)` | `GET /bill/{congress}/{type}/{number}` | Single bill detail |
| `bill_actions(congress, type, number)` | `GET /bill/{congress}/{type}/{number}/actions` | Bill action history |
| `house_votes(congress, session, limit)` | `GET /house-vote/{congress}/{session}` | House roll call votes |
| `house_vote(congress, session, roll)` | `GET /house-vote/{congress}/{session}/{roll}` | Single vote detail |

### 4.2 UtahLegislature::Client

**File:** `app/services/utah_legislature/client.rb`
**Base URL:** `https://glen.le.utah.gov`
**Auth:** `UTAH_LEGISLATURE_TOKEN` appended to URL
**Rate Limits:** 1 request/hour (bills), 1 request/day (legislators)

| Method | Endpoint | Returns |
|--------|----------|---------|
| `legislators(year:)` | `GET /legislators` | Array of legislator objects |
| `legislator(id)` | `GET /legislator/{id}` | Single legislator detail |
| `bills(session:)` | `GET /bills/{session}` | Array of bill objects |
| `bill(session, number)` | `GET /bill/{session}/{number}` | Single bill with embedded votes |
| `bill_votes(session, number)` | Embedded in bill detail | Vote data |

### 4.3 OpenStates::Client

**File:** `app/services/open_states/client.rb`
**Base URL:** `https://v3.openstates.org`
**Auth:** `OPENSTATES_API_KEY` in `X-API-KEY` header
**Role:** Supplementary/fallback source

| Method | Endpoint | Returns |
|--------|----------|---------|
| `utah_people(chamber:)` | `GET /people?jurisdiction=Utah` | Array of people |
| `person(id)` | `GET /people/{id}` | Single person detail |
| `utah_bills(session, page, per_page)` | `GET /bills?jurisdiction=Utah` | Paginated bills |
| `bill(id)` | `GET /bills/{id}` | Single bill detail |

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

| API Field | Model Field | Transformation |
|-----------|-------------|----------------|
| `bioguideId` | `bioguide_id` | Direct |
| `name` | `first_name`, `last_name` | Split on space |
| `partyName` | `party` | Direct |
| `state` | — | Filtered to "Utah" |
| `terms.current.chamber` | `position_type` | "Senate" → `us_senator`, "House" → `us_representative` |
| `terms.current.district` | `district` | Direct |
| `depiction.imageUrl` | `photo_url` | Direct |

**Derived fields:**
- `level` → always `federal`
- `title` → "U.S. Senator" or "U.S. Representative, District N"
- `chamber` → "Senate" or "House"

#### UtahLegislature::LegislatorImporter

**File:** `app/services/utah_legislature/legislator_importer.rb`

| API Field | Model Field | Transformation |
|-----------|-------------|----------------|
| `id` | `utah_leg_id` | Direct |
| `firstName`, `lastName` | `first_name`, `last_name` | Direct |
| `house` | `position_type` | "s"/"senate" → `state_senator`, "h"/"house" → `state_representative` |
| `district` | `district` | Direct |
| `party` | `party` | Normalized: "r" → "Republican", "d" → "Democrat" |
| `phone`, `email` | `phone`, `email` | Direct |
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

| API Field | Model Field | Transformation |
|-----------|-------------|----------------|
| `billNumber` | `bill_number` | Direct |
| — | `utah_bill_id` | `"#{session}-#{bill_number}"` |
| `shortTitle` or `generalProvisions` | `title` | Direct |
| `billNumber` prefix | `chamber` | HB/HJR/HCR → "House", SB/SJR/SCR → "Senate" |
| `lastAction` | `status` | Direct |

**Session name parsing:** "2025GS" → "2025 General Session", "2025S1" → "2025 Special Session"

### 5.4 Vote Importers

#### CongressGov::VoteImporter

**File:** `app/services/congress_gov/vote_importer.rb`

- Fetches House roll call votes for a given congress/session
- Caches Utah reps by `bioguide_id` for fast lookup
- Links votes to bills by matching `congress_bill_id`

**Position Normalization:**
| API Value | Model Position |
|-----------|----------------|
| `"yea"`, `"aye"` | `yes` |
| `"nay"` | `no` |
| `"present"` | `present` |
| `"not voting"` | `not_voting` |

#### UtahLegislature::VoteImporter

**File:** `app/services/utah_legislature/vote_importer.rb`

- Vote data is embedded in bill detail JSON (no separate endpoint)
- Caches state reps by `utah_leg_id`
- Iterates state bills, extracts vote arrays, creates Vote records

**Position Normalization:**
| API Value | Model Position |
|-----------|----------------|
| `"yea"`, `"yes"`, `"y"`, `"aye"` | `yes` |
| `"nay"`, `"no"`, `"n"` | `no` |
| `"absent"`, `"abs"` | `not_voting` |
| `"abstain"` | `abstain` |

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
    └── import:state_votes         (UtahLegislature::VoteImporter)

# Supplementary (not included in import:all)
import:openstates_people           (OpenStates::PeopleImporter)
import:openstates_bills            (OpenStates::BillImporter)
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

# Supplementary
rake import:openstates_people
rake import:openstates_bills
```

### 6.3 Import Order Dependency

```
Members MUST be imported before Votes
Bills MUST be imported before Votes
(Votes link to both by external ID)
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
| Utah Legislature | 1 req/hr (bills), 1 req/day (legislators) | Very restrictive — imports may be slow |
| OpenStates | Varies by tier | Free tier sufficient for Utah-only data |

---

## 8. Error Handling

### 8.1 Error Types

| Error | Trigger | Handling |
|-------|---------|----------|
| `RateLimitError` | HTTP 429 | Logged, import continues with next record |
| `NotFoundError` | HTTP 404 | Logged, record skipped |
| `ApiError` | Other non-2xx | Logged with details, record skipped |
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
- [ ] Retry logic with exponential backoff for rate-limited APIs

---

## 11. Implementation Notes

- Base client: `app/services/api_client.rb`
- Congress.gov services: `app/services/congress_gov/`
- Utah Legislature services: `app/services/utah_legislature/`
- OpenStates services: `app/services/open_states/`
- Rake tasks: `lib/tasks/import.rake`
