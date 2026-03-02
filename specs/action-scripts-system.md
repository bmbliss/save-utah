# Action Scripts System

**Status:** Implemented
**Version:** 1.0
**Last Updated:** 2026-03-02

---

## 1. Overview

### 1.1 Purpose

Provides ready-to-use call and email scripts that citizens can use when contacting their elected officials. Scripts support template placeholders that are dynamically replaced with representative and bill data at render time.

### 1.2 Goals

- Lower the barrier to civic engagement with pre-written scripts
- Support both phone call and email action types
- Allow scripts to be linked to specific representatives, bills, or both
- Enable homepage curation of featured scripts
- Handle Ruby 4.0 frozen string literals safely during template rendering

### 1.3 Non-Goals

- Click-to-call or email-sending functionality (links to `tel:` and `mailto:`)
- Script creation by end users
- Analytics or tracking of script usage
- A/B testing of script effectiveness

### 1.4 Related Specifications

- [Data Model](./data-model.md) — ActionScript model schema
- [Representatives System](./representatives-system.md) — Scripts displayed on rep show pages
- [Bills System](./bills-system.md) — Scripts displayed on bill show pages
- [Frontend System](./frontend-system.md) — Script card partial styling

---

## 2. Architecture

### 2.1 Data Flow

```
┌──────────────────┐     ┌──────────────────┐
│   ActionScript   │     │  Representative   │
│                  │     │                   │
│ script_template  │─ ─ ─│ full_name         │
│ [REP_NAME]       │     │ phone             │
│ [REP_PHONE]      │     │ title             │
│ [BILL_NUMBER]    │     │ email             │
│                  │     └──────────────────┘
│ render_script()  │
│     ↓            │     ┌──────────────────┐
│ "Hello, my name  │     │      Bill        │
│  is..., I'm      │─ ─ ─│                  │
│  calling about   │     │ bill_number       │
│  HB 245..."      │     │ title             │
└──────────────────┘     └──────────────────┘
```

### 2.2 Template Rendering

```ruby
def render_script(representative: nil, bill: nil)
  # .dup required — Ruby 4.0 freezes string literals by default
  output = script_template.dup

  if representative
    output.gsub!("[REP_NAME]", representative.full_name)
    output.gsub!("[REP_PHONE]", representative.phone.to_s)
    output.gsub!("[REP_TITLE]", representative.title.to_s)
    output.gsub!("[REP_EMAIL]", representative.email.to_s)
  end

  if bill
    output.gsub!("[BILL_NUMBER]", bill.bill_number.to_s)
    output.gsub!("[BILL_TITLE]", bill.title.to_s)
  end

  output
end
```

---

## 3. Template Placeholders

| Placeholder | Replaced With | Example Output |
|-------------|---------------|----------------|
| `[REP_NAME]` | `representative.full_name` | "Spencer Cox" |
| `[REP_PHONE]` | `representative.phone` | "(801) 538-1000" |
| `[REP_TITLE]` | `representative.title` | "Governor" |
| `[REP_EMAIL]` | `representative.email` | "governor@utah.gov" |
| `[BILL_NUMBER]` | `bill.bill_number` | "HB 245" |
| `[BILL_TITLE]` | `bill.title` | "Utah Clean Air Standards Act" |

**Behavior when data is missing:** If a representative or bill is not provided, placeholders remain in the output as-is (e.g., `[REP_NAME]`). The `.to_s` call on nil values produces an empty string, preventing NoMethodErrors.

---

## 4. Script Template Examples

### 4.1 Call Script

```
Hello, my name is [YOUR NAME] and I'm a constituent from [YOUR CITY].
I'm calling to urge [REP_TITLE] [REP_NAME] to support [BILL_NUMBER],
the [BILL_TITLE]. This bill is important because it would protect
Utah's air quality and public health. Thank you for your time.
```

### 4.2 Email Script

```
Subject: Please Support [BILL_NUMBER] — [BILL_TITLE]

Dear [REP_TITLE] [REP_NAME],

As your constituent, I'm writing to urge you to support [BILL_NUMBER].
[Additional context about why this matters...]

Thank you for your service,
[YOUR NAME]
[YOUR ADDRESS]
```

---

## 5. Display Locations

### 5.1 Homepage

Featured scripts appear in a 2-column grid in the "Take Action" section.

**Query:** `ActionScript.active.featured.ordered.includes(:representative, :bill).limit(4)`

### 5.2 Representative Show Page

Scripts linked to the specific representative appear in a sidebar.

**Query:** `@representative.action_scripts.active.ordered`

### 5.3 Bill Show Page

Scripts linked to the specific bill appear in a sidebar.

**Query:** `@bill.action_scripts.active.ordered`

---

## 6. Script Card Partial

**File:** `app/views/shared/_script_card.html.erb`

```
┌──────────────────────────────────────────┐
│  ┌──┐  Script Title                      │
│  │📞│  "Call Senator Lee About..."       │
│  └──┘                                    │
│                                          │
│  Context (truncated):                    │
│  "The Great Salt Lake is facing..."      │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │ Rendered script template           │  │
│  │ (sand-light background box)        │  │
│  │ "Hello, my name is..., I'm        │  │
│  │  calling Senator Mike Lee..."      │  │
│  └────────────────────────────────────┘  │
│                                          │
│  [📞 Call Now: (202) 555-0100]          │
└──────────────────────────────────────────┘
```

**Icon colors:**
- Call scripts → red circle icon
- Email scripts → blue circle icon

**"Call Now" button:** Only shown when `action_type == "call"` AND the linked representative has a phone number. Links to `tel:{phone}`.

---

## 7. Scopes

| Scope | Query | Usage |
|-------|-------|-------|
| `active` | `where(active: true)` | Only show active scripts |
| `featured` | `where(featured: true)` | Homepage featured scripts |
| `calls` | `where(action_type: :call)` | Call scripts only |
| `emails` | `where(action_type: :email)` | Email scripts only |
| `ordered` | `order(:sort_order)` | Manual display ordering |

---

## 8. Design Decisions

### 8.1 Why Template Placeholders Instead of ERB?

Simple bracket-delimited placeholders (`[REP_NAME]`) are:
- Safe — no code execution, no injection risk
- Readable — non-technical users can understand and author templates
- Predictable — finite set of known tokens, easy to document

ERB templates would introduce security risks (arbitrary code execution) and complexity for what is fundamentally a mail-merge use case.

### 8.2 Why Optional Foreign Keys?

Scripts can exist in three relationship states:
1. **General** — no rep or bill (applies broadly)
2. **Rep-specific** — linked to one representative
3. **Bill-specific** — linked to one bill
4. **Both** — linked to a specific rep AND bill

Using `dependent: :nullify` on the Representative/Bill side means deleting a rep or bill doesn't delete the script — it just clears the FK, making the script general-purpose.

### 8.3 Why `.dup` in render_script?

Ruby 4.0 freezes all string literals by default. Without `.dup`, calling `gsub!` on `script_template` would raise a `FrozenError`. The `.dup` creates a mutable copy for safe in-place replacement.

---

## 9. Implementation Notes

- Model: `app/models/action_script.rb`
- Card partial: `app/views/shared/_script_card.html.erb`
- Seed data: `db/seeds.rb` (4 sample scripts)
- Displayed in: `pages/home`, `representatives/show`, `bills/show`
