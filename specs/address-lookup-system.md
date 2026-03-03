# Address Lookup System

**Status:** Implemented
**Version:** 1.0
**Last Updated:** 2026-03-03

---

## 1. Overview

### 1.1 Purpose

"Find Your Representatives" feature that lets visitors enter a Utah street address and instantly see their specific elected officials — US Senators, US House Rep, State Senator, State House Rep, and statewide executives — displayed inline on the homepage via Turbo Frame.

### 1.2 Goals

- Map a visitor's address to congressional + state legislative districts
- Query the database for matching Utah representatives
- Display results inline without a full page reload (Turbo Frame)
- Handle errors gracefully (invalid address, non-Utah, API down)
- Cache district lookups for 24 hours to reduce API calls

### 1.3 Non-Goals

- Storing user addresses or location data
- Automatic geolocation (GPS/browser-based)
- Lookups for states other than Utah
- Persistent "my reps" session (lookup is stateless)

### 1.4 Related Specifications

- [Representatives System](./representatives-system.md) — Rep card partial reused for results
- [Data Model](./data-model.md) — Representative model with `state` and `district` columns
- [Data Import System](./data-import-system.md) — CensusGeocoder service + `state` field in member importer
- [Frontend System](./frontend-system.md) — Stimulus controller for loading state, Turbo Frame pattern
- [Architecture](./architecture.md) — System-level overview with Census Geocoder in service layer

---

## 2. Architecture

### 2.1 Flow Diagram

```
┌─────────────────┐     ┌───────────────────┐     ┌──────────────────────┐
│  Homepage Form  │────▶│ LookupsController │────▶│ CensusGeocoder::     │
│  (Turbo Frame)  │     │   #create         │     │  DistrictLookup      │
└─────────────────┘     └───────────────────┘     └──────────┬───────────┘
                                │                             │
                                │                             ▼
                                │                  ┌──────────────────────┐
                                │                  │ CensusGeocoder::     │
                                │                  │   Client             │
                                │                  │   (Faraday → Census) │
                                │                  └──────────┬───────────┘
                                │                             │ HTTP GET
                                │                             ▼
                                │                  ┌──────────────────────┐
                                │                  │ US Census Geocoder   │
                                │                  │ geocoding.geo.       │
                                │                  │  census.gov          │
                                │                  └──────────────────────┘
                                │
                                │  Districts → DB query
                                ▼
                        ┌───────────────────┐
                        │  Turbo Frame      │
                        │  Response         │
                        │  (rep cards or    │
                        │   error message)  │
                        └───────────────────┘
```

### 2.2 Directory Structure

```
app/
├── services/
│   └── census_geocoder/
│       ├── client.rb              # Faraday client for Census Geocoder API
│       └── district_lookup.rb     # Business logic: address → districts → reps
├── controllers/
│   └── lookups_controller.rb      # Single #create action
├── views/
│   └── lookups/
│       ├── _form.html.erb         # Address input + submit button
│       └── create.html.erb        # Turbo Frame response (results or error)
└── javascript/
    └── controllers/
        └── address_lookup_controller.js  # Loading state Stimulus controller
```

---

## 3. API — US Census Geocoder

**Base URL:** `https://geocoding.geo.census.gov/geocoder`
**Docs:** https://geocoding.geo.census.gov/geocoder/Geocoding_Services_API.html
**Auth:** None required (free, open API)
**Rate Limits:** Not documented; no throttling observed

### 3.1 Client

**File:** `app/services/census_geocoder/client.rb`

Inherits from `ApiClient`. Single method:

| Method | Endpoint | Params | Returns |
|--------|----------|--------|---------|
| `geocode(address)` | `GET /geographies/onelineaddress` | `address`, `benchmark=Public_AR_Current`, `vintage=Current_Current`, `format=json` | Full JSON with `result.addressMatches[].geographies` |

**Timeouts:** 15s read, 10s open (Census API can be slow).

### 3.2 Response Structure

The Census API returns geographies keyed by layer name. Relevant layers:

| Layer Key | District Field | Example Value | Maps To |
|-----------|----------------|---------------|---------|
| `"119th Congressional Districts"` | `CD119` | `"02"` | `Representative.us_representative` with `district: "2"` |
| `"2024 State Legislative Districts - Upper"` | `SLDU` | `"009"` | `Representative.state_senator` with `district: "9"` |
| `"2024 State Legislative Districts - Lower"` | `SLDL` | `"022"` | `Representative.state_representative` with `district: "22"` |
| Any layer | `STATE` | `"49"` | Utah FIPS code — used for state validation |

**Note:** Layer key names include session/year numbers (e.g., "119th", "2024") that change over time. The lookup uses `String#include?` matching rather than exact key comparison.

---

## 4. District Lookup Service

**File:** `app/services/census_geocoder/district_lookup.rb`

### 4.1 Public Interface

```ruby
CensusGeocoder::DistrictLookup.new.call("350 N State St, Salt Lake City, UT 84103")
# => [<Representative>, <Representative>, ...]
```

### 4.2 Processing Steps

1. **Validate** — blank address raises `InvalidAddressError`
2. **Cache check** — `Rails.cache.fetch("district_lookup/normalized_address", expires_in: 24.hours)`
3. **API call** — `CensusGeocoder::Client#geocode(address)`
4. **Match check** — empty `addressMatches` raises `InvalidAddressError`
5. **State validation** — extract FIPS code from any geography layer; `!= "49"` raises `OutsideUtahError`
6. **Parse districts** — extract `CD*`, `SLDU`, `SLDL` values, strip leading zeros
7. **Query DB** — find matching active Utah representatives

### 4.3 Database Query

```ruby
reps = Representative.active.where(state: "UT")

# Always included (statewide):
senators   = reps.where(position_type: :us_senator)
executives = reps.executives

# Matched by district:
house_rep     = reps.where(position_type: :us_representative, district: cd)
state_senator = reps.where(position_type: :state_senator,     district: sldu)
state_rep     = reps.where(position_type: :state_representative, district: sldl)
```

Results are combined in order: Senators → House Rep → State Senator → State Rep → Executives.

### 4.4 Error Classes

| Error | When | User Message |
|-------|------|--------------|
| `InvalidAddressError` | Blank input or no address match from Census | "Please enter an address." / "We couldn't find that address." |
| `OutsideUtahError` | State FIPS code is not `49` (Utah) | "That address doesn't appear to be in Utah." |
| `ApiClient::ApiError` | Census API down or error | "We couldn't look up that address right now. Please try again later." |

---

## 5. Controller

**File:** `app/controllers/lookups_controller.rb`

### 5.1 Route

```ruby
post "lookup", to: "lookups#create"
```

### 5.2 Create Action

```ruby
def create
  @address = params[:address].to_s.strip
  @representatives = CensusGeocoder::DistrictLookup.new.call(@address)
rescue CensusGeocoder::DistrictLookup::OutsideUtahError => e
  @error = e.message
rescue CensusGeocoder::DistrictLookup::InvalidAddressError => e
  @error = e.message
rescue ApiClient::ApiError => e
  Rails.logger.error("[LookupsController] Census Geocoder error: #{e.message}")
  @error = "Something went wrong looking up your address. Please try again later."
end
```

Renders `lookups/create.html.erb` (Turbo Frame response) in all cases.

---

## 6. Views

### 6.1 Form Partial

**File:** `app/views/lookups/_form.html.erb`

```
┌────────────────────────────────────────────────────────────┐
│ ┌──────────────────────────────────────────┐ ┌───────────┐│
│ │ Enter your Utah address...               │ │Find My    ││
│ │ (text input, required)                   │ │  Reps     ││
│ └──────────────────────────────────────────┘ └───────────┘│
└────────────────────────────────────────────────────────────┘
```

- `form_with url: lookup_path, method: :post`
- `data: { turbo_frame: "rep-lookup" }` — targets the Turbo Frame
- `data: { controller: "address-lookup" }` — Stimulus loading state
- Pre-fills `value` with submitted address on re-render

### 6.2 Results View

**File:** `app/views/lookups/create.html.erb`

Wrapped in `<turbo-frame id="rep-lookup">`. Contains:

1. **Re-rendered form** (pre-filled with `@address`)
2. **Error message** (if `@error` present) — red alert box
3. **Results** (if `@representatives` present) — grouped into sections:

```
┌────────────────────────────────────────────┐
│  ● Your Federal Representatives            │
│  ┌────────────┐ ┌────────────┐            │
│  │ Rep Card   │ │ Rep Card   │ ...        │
│  └────────────┘ └────────────┘            │
│                                            │
│  ● Your State Legislators                  │
│  ┌────────────┐ ┌────────────┐            │
│  │ Rep Card   │ │ Rep Card   │            │
│  └────────────┘ └────────────┘            │
│                                            │
│  ● Statewide Executives                   │
│  ┌────────────┐ ┌────────────┐ ...        │
│  │ Rep Card   │ │ Rep Card   │            │
│  └────────────┘ └────────────┘            │
└────────────────────────────────────────────┘
```

4. **"Data importing" message** (if districts found but no reps match) — amber alert box

**Result grouping logic:**
- Federal: `representative.level_federal?`
- State Legislators: `state_senator?` or `state_representative?`
- Executives: `governor?`, `lt_governor?`, `attorney_general?`, `state_auditor?`, `state_treasurer?`

### 6.3 Turbo Frame Pattern

The homepage contains an empty Turbo Frame:

```erb
<%# In pages/home.html.erb %>
<turbo-frame id="rep-lookup">
  <%= render "lookups/form" %>
</turbo-frame>
```

The form submits to `POST /lookup` with `data-turbo-frame="rep-lookup"`. The response (`create.html.erb`) also wraps its content in `<turbo-frame id="rep-lookup">`, so Turbo swaps only the frame content — no full page reload.

**Link navigation:** Rep card links inside the frame use `data-turbo-frame="_top"` to ensure clicking a result navigates to the full rep show page rather than trying to render it inside the frame.

---

## 7. Stimulus Controller

**File:** `app/javascript/controllers/address_lookup_controller.js`

Handles loading state during form submission:

| Event | Action |
|-------|--------|
| `turbo:submit-start` | Disable button, change text to "Looking up...", add `opacity-60 cursor-wait` |
| `turbo:submit-end` | Restore original button text, re-enable, remove opacity classes |

**Targets:** `button`, `input`

---

## 8. Homepage Integration

**File:** `app/views/pages/home.html.erb`

The "Find Your Representatives" section is inserted **between** the blast hero (`<% end %>`) and the "Other Issues" section. It is **always visible** (not gated by `@hot_issue`).

```
┌─────────────────────────────────────────┐
│  BLAST HERO (if @hot_issue)             │
│  SCRIPT TABS                            │
│  SENATOR CARDS                          │
│  SHARE CTA                              │
├─────────────────────────────────────────┤
│  FIND YOUR REPRESENTATIVES (always)     │  ← New section
│  bg-gray-50, max-w-4xl                  │
│  H2 + subtitle + Turbo Frame with form  │
├─────────────────────────────────────────┤
│  OTHER ISSUES (if any)                  │
│  WHY SAVE UTAH                          │
└─────────────────────────────────────────┘
```

---

## 9. Data Requirements — `state` Column

The lookup filters representatives by `state: "UT"` to avoid showing non-Utah federal reps that exist in the database from vote imports.

**Migration:** `db/migrate/20260303165905_add_state_to_representatives.rb`

- Adds `state` (string) column to `representatives`
- Backfills all state-level reps and executives with `"UT"`
- Adds index on `state`

**Importer update:** `CongressGov::MemberImporter` now extracts `stateCode` from the member's current term data (e.g., `"UT"`) and sets it on the `state` field.

See [Data Model spec](./data-model.md) for full column details.

---

## 10. Error Handling

| Scenario | Detection | User Experience |
|----------|-----------|-----------------|
| Empty address | HTML `required` + server-side blank check | "Please enter an address." |
| Invalid/gibberish address | Census returns empty `addressMatches` | "We couldn't find that address. Please enter a valid Utah street address." |
| Non-Utah address | State FIPS ≠ `49` | "That address doesn't appear to be in Utah." |
| Census API down | `ApiClient::ApiError` caught in controller | "Something went wrong looking up your address. Please try again later." + `Rails.logger.error` |
| District found, no reps in DB | `@representatives` empty but `@address` present | "We found your districts but don't have matching representatives in our database yet." |

---

## 11. Caching

District lookups are cached in `Rails.cache` with 24-hour TTL:

```ruby
cache_key = "district_lookup/#{address.downcase.gsub(/\s+/, '_')}"
Rails.cache.fetch(cache_key, expires_in: 24.hours) { fetch_districts(address) }
```

Only the district hash is cached (e.g., `{ cd: "2", sldu: "9", sldl: "22" }`), not the representative records. This means rep data updates (new imports) are reflected immediately while avoiding redundant API calls for the same address.

---

## 12. Design Decisions

### 12.1 Why US Census Geocoder Instead of Google Civic API?

Google shut down the Civic Information API's `representatives` endpoint on April 30, 2025. The Census Geocoder is free, requires no API key, and returns the exact district data we need (congressional + state legislative).

**Trade-offs:**
- Pro: Free, no API key, authoritative government source, includes all district types
- Con: Can be slow (1-3s response times), no SLA, response format includes session-specific key names that may change

### 12.2 Why Turbo Frame Instead of Full Page?

The lookup is a quick, contextual interaction — the user enters an address and immediately sees results. A Turbo Frame keeps them on the homepage with the form and results inline, avoiding a jarring page navigation for a simple query.

### 12.3 Why Cache Districts but Not Reps?

District boundaries change rarely (every 10 years after redistricting). Caching the district-to-address mapping for 24 hours is safe and reduces Census API calls. But representative records may change more frequently (new imports, updated contact info), so the DB query runs fresh each time.

### 12.4 Why Filter by `state: "UT"`?

The database contains non-Utah federal representatives imported via vote records (e.g., a Texas rep who voted on the same bill as a Utah rep). The `state` column distinguishes Utah's delegation from other states' members sharing the same district numbers.

---

## 13. Future Enhancements

- [ ] Autocomplete/suggestion for address input
- [ ] Browser geolocation as an alternative to manual address entry
- [ ] Cache warming for common Utah cities
- [ ] Show district map visualization alongside results
- [ ] Direct "call" and "text" action buttons on lookup results (not just links to show pages)

---

## 14. Implementation Notes

- Census Geocoder client: `app/services/census_geocoder/client.rb`
- District lookup service: `app/services/census_geocoder/district_lookup.rb`
- Controller: `app/controllers/lookups_controller.rb`
- Form partial: `app/views/lookups/_form.html.erb`
- Results view: `app/views/lookups/create.html.erb`
- Stimulus controller: `app/javascript/controllers/address_lookup_controller.js`
- Route: `POST /lookup` → `lookups#create`
- Migration: `db/migrate/20260303165905_add_state_to_representatives.rb`
