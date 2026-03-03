# Frontend System

**Status:** Implemented
**Version:** 1.1
**Last Updated:** 2026-03-03

---

## 1. Overview

### 1.1 Purpose

Defines the frontend architecture — Tailwind CSS theming with a Utah-inspired color palette, responsive layout system, shared partials, Hotwire/Stimulus interactions, SEO meta tags, and asset pipeline configuration.

### 1.2 Goals

- Consistent, accessible design across all pages using Tailwind utility classes
- Utah-inspired visual identity (red rock, navy, gold, sky, sage, sand)
- Mobile-first responsive layout with progressive enhancement
- Minimal JavaScript via Stimulus for interactive elements
- SEO-optimized with meta tags and FriendlyId slugs

### 1.3 Non-Goals

- Custom CSS framework or component library
- Complex client-side state management
- Server-side rendering of JavaScript components
- Dark mode (future enhancement)

### 1.4 Related Specifications

- [Architecture](./architecture.md) — System-level overview
- [Representatives System](./representatives-system.md) — Rep views
- [Bills System](./bills-system.md) — Bill views
- [Action Scripts System](./action-scripts-system.md) — Script card partial

---

## 2. Architecture

### 2.1 Asset Pipeline

```
┌─────────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Importmap-rails   │     │    Propshaft      │     │  Tailwind CSS   │
│   (JS modules)      │     │  (asset serving)  │     │  (via gem)      │
│                     │     │                   │     │                 │
│ app/javascript/     │     │ app/assets/       │     │ app/assets/     │
│ ├─ application.js   │     │ ├─ images/        │     │ tailwind/       │
│ └─ controllers/     │     │ └─ builds/        │     │ application.css │
└─────────────────────┘     └──────────────────┘     └─────────────────┘
```

**No Node.js or esbuild** — importmap-rails handles ESM imports natively.

### 2.2 Directory Structure

```
app/
├── assets/
│   ├── tailwind/
│   │   └── application.css       # Tailwind config + Utah color palette
│   ├── images/                   # Static images
│   └── builds/                   # Compiled CSS output
├── javascript/
│   ├── application.js            # Turbo + Stimulus entry point
│   └── controllers/
│       ├── application.js        # Stimulus app initialization
│       ├── index.js              # Eager controller loading
│       ├── mobile_nav_controller.js   # Hamburger toggle
│       ├── share_controller.js        # Web Share API + clipboard fallback
│       ├── address_lookup_controller.js # Loading state for rep lookup form
│       ├── clipboard_controller.js    # Copy-to-clipboard
│       ├── script_tabs_controller.js  # Call/text/email script tab switching
│       └── rep_card_controller.js     # Rep card interactions
└── views/
    ├── layouts/
    │   └── application.html.erb  # Main layout (navbar + footer)
    ├── pages/
    │   ├── home.html.erb         # Homepage
    │   └── about.html.erb        # About page
    ├── representatives/
    │   ├── index.html.erb        # Rep listing
    │   └── show.html.erb         # Rep detail
    ├── bills/
    │   ├── index.html.erb        # Bill listing
    │   └── show.html.erb         # Bill detail
    ├── lookups/
    │   ├── _form.html.erb        # Address lookup form partial
    │   └── create.html.erb       # Turbo Frame response (results/error)
    └── shared/
        ├── _rep_card.html.erb    # Representative card partial
        ├── _bill_card.html.erb   # Bill card partial
        └── _script_card.html.erb # Action script card partial
```

---

## 3. Color Palette

**File:** `app/assets/tailwind/application.css`

Utah-inspired theme defined as Tailwind 4 custom colors via `@theme`:

| Token | Hex | Inspiration | Primary Usage |
|-------|-----|-------------|---------------|
| `utah-red` | `#BF2C34` | Red rock, arches | CTAs, error states, Republican party badges |
| `utah-red-light` | `#D94F56` | | Hover states |
| `utah-red-dark` | `#8C1F25` | | Active states |
| `utah-navy` | `#1B2A4A` | Trust, authority | Navbar, footer, headings, body text |
| `utah-navy-light` | `#2D4470` | | Hover states |
| `utah-navy-dark` | `#111B30` | | Dark sections |
| `utah-gold` | `#D4A843` | Desert sunlight | Accent text, highlights, editorial callouts |
| `utah-gold-light` | `#E0C06A` | | Background highlights |
| `utah-gold-dark` | `#B08A2E` | | Emphasis |
| `utah-sky` | `#4A90D9` | Blue sky | Links, info badges, email icons |
| `utah-sky-light` | `#7AB3F0` | | Light accents |
| `utah-sky-dark` | `#2E6DB5` | | Hover states |
| `utah-sand` | `#F5F0E8` | Warm background | Page background (`body`) |
| `utah-sand-light` | `#FAF8F3` | | Card backgrounds |
| `utah-sand-dark` | `#E8DFD0` | | Borders, dividers |
| `utah-sage` | `#6B8F71` | Natural green | Success states, Yea votes, flash notices |
| `utah-sage-light` | `#8DB393` | | Light accents |
| `utah-sage-dark` | `#4F6E54` | | Emphasis |

**Typography:**
| Token | Value |
|-------|-------|
| `--font-display` | `"Inter", "system-ui", "sans-serif"` |
| `--font-body` | `"Inter", "system-ui", "sans-serif"` |

**Global body style:** `bg-utah-sand font-body text-utah-navy`

---

## 4. Layout

**File:** `app/views/layouts/application.html.erb`

### 4.1 Page Structure

```
┌─────────────────────────────────────────────────────────────┐
│  NAVBAR (sticky top, bg-utah-navy)                           │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ SAVEUTAH (logo)    Representatives  Bills  About     │   │
│  │ (white+red)        (nav links, white text)    [☰]    │   │
│  └──────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  FLASH MESSAGES (if any)                                     │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Notice (sage-green bg) or Alert (red bg)                ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  MAIN CONTENT (yield)                                        │
│  varies by page...                                           │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│  FOOTER (bg-utah-navy-dark, text-white)                      │
│  ┌──────────────────┬──────────────┬───────────────────┐    │
│  │ Brand & Mission  │ Quick Links  │ Data Sources      │    │
│  │ "Save Utah is a  │ Home         │ Congress.gov      │    │
│  │  nonpartisan..."  │ Representatives│ Utah Legislature │    │
│  │                  │ Bills        │ OpenStates        │    │
│  │                  │ About        │                   │    │
│  └──────────────────┴──────────────┴───────────────────┘    │
│  © 2026 Save Utah. All rights reserved.                      │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Navbar Details

- **Position:** Sticky top (`sticky top-0 z-50`)
- **Background:** `bg-utah-navy`
- **Logo:** "SAVE" (white) + "UTAH" (utah-red), bold, font-display
- **Nav Links:** White text, gold underline on hover
- **Mobile:** Hamburger icon (visible below `md` breakpoint), toggles `#mobile-menu`

### 4.3 Footer Details

- **Background:** `bg-utah-navy-dark`
- **Layout:** 3-column grid on desktop, stacked on mobile
- **Columns:** Brand/mission, Quick Links (internal), Data Sources (external links)
- **Copyright:** Centered below columns

---

## 5. Responsive Breakpoints

Uses Tailwind's default breakpoint system:

| Breakpoint | Min Width | Usage |
|------------|-----------|-------|
| Default | 0px | Single column, mobile-first |
| `sm` | 640px | 2-column grids |
| `md` | 768px | Show desktop nav, hide hamburger |
| `lg` | 1024px | 3-column grids, sidebar layouts |
| `xl` | 1280px | Max content width |

**Grid patterns:**
- Rep cards: `grid-cols-1 sm:grid-cols-2 lg:grid-cols-3`
- Action scripts: `grid-cols-1 md:grid-cols-2`
- Bill detail layout: `lg:grid-cols-3` (2 cols content + 1 col sidebar)

---

## 6. Shared Partials

### 6.1 Rep Card (`_rep_card.html.erb`)

```
┌──────────────────────────────────────────┐
│  ┌────┐  Full Name                       │
│  │ AZ │  Title                           │
│  │56px│  [Party] [Level] [District]      │
│  └────┘  📞 (801) 555-0100              │
└──────────────────────────────────────────┘
```

- Wrapped in `link_to` (entire card is clickable)
- Photo with initials fallback (first + last initial in colored circle)
- Party badge colors: Republican = `bg-red-100 text-red-700`, Democrat = `bg-blue-100 text-blue-700`, Independent = `bg-purple-100 text-purple-700`

### 6.2 Bill Card (`_bill_card.html.erb`)

```
┌──────────────────────────────────────────┐
│  [HB 245] [State] [In Committee]         │
│  Utah Clean Air Standards Act            │
│  Summary text (truncated)...             │
│  Feb 15, 2026       Yea: 45 | Nay: 12   │
└──────────────────────────────────────────┘
```

- Wrapped in `link_to`
- Prefers `editorial_summary` over `summary` for preview text
- Mini vote counts: green for yes, red for no

### 6.3 Script Card (`_script_card.html.erb`)

```
┌──────────────────────────────────────────┐
│  ● Script Title                          │
│  Context text (truncated)...             │
│  ┌────────────────────────────────────┐  │
│  │ Rendered script (sand-light bg)    │  │
│  └────────────────────────────────────┘  │
│  [Call Now: (801) 555-0100]              │
└──────────────────────────────────────────┘
```

- Icon: red circle for calls, blue circle for emails
- Script rendered in `bg-utah-sand-light` box
- "Call Now" button only shows for call scripts with a phone number

---

## 7. JavaScript / Stimulus

### 7.1 Entry Point

**File:** `app/javascript/application.js`

```javascript
import "@hotwired/turbo-rails"
import "controllers"
```

- Turbo handles page navigation (no full reloads)
- Controllers auto-loaded via `eagerLoadControllersFrom`

### 7.2 Mobile Nav Controller

**File:** `app/javascript/controllers/mobile_nav_controller.js`

| Element | Role |
|---------|------|
| Controller target | `#mobile-menu` |
| Action | `toggle()` — toggles `hidden` class |
| Trigger | Hamburger button (`data-action="click->mobile-nav#toggle"`) |

### 7.3 Share Controller

**File:** `app/javascript/controllers/share_controller.js`

Uses the Web Share API with a copy-to-clipboard fallback. Values (`title`, `text`, `url`) are passed via Stimulus values.

### 7.4 Address Lookup Controller

**File:** `app/javascript/controllers/address_lookup_controller.js`

Handles loading state for the "Find My Reps" form:

| Event | Action |
|-------|--------|
| `turbo:submit-start` | Disable button, text → "Looking up...", add `opacity-60 cursor-wait` |
| `turbo:submit-end` | Restore original text, re-enable, remove opacity classes |

### 7.5 Turbo Frames

The address lookup feature uses Turbo Frames for inline form submission and response. The homepage contains a `<turbo-frame id="rep-lookup">` that wraps the form. The form's `data-turbo-frame="rep-lookup"` attribute targets this frame, and the response (`lookups/create.html.erb`) wraps its content in a matching frame.

Rep card links inside the frame use `data: { turbo_frame: "_top" }` to break out of the frame for full-page navigation to rep show pages.

### 7.6 Pagination

Pagy's `series_nav_js` generates JavaScript-powered pagination links. No custom Stimulus controller needed.

---

## 8. SEO

### 8.1 Meta Tags

**Gem:** `meta-tags`
**Initializer:** `config/initializers/meta_tags.rb`

| Setting | Value |
|---------|-------|
| `title_limit` | 70 characters |
| `description_limit` | 160 characters |
| `keywords_limit` | 255 characters |

**Per-page meta tags set via `set_meta_tags` in controllers:**

| Page | Title | Description |
|------|-------|-------------|
| Home | "Save Utah — Hold Your Leaders Accountable" | Platform description |
| About | "About Save Utah" | Mission statement |
| Rep Index | "Utah's Elected Officials" | Browse/contact description |
| Rep Show | "{title} {name} — Save Utah" | Dynamic per-rep |
| Bill Index | "Bills & Legislation" | Browse/track description |
| Bill Show | "{bill_number}: {title} — Save Utah" | Dynamic per-bill |

### 8.2 FriendlyId Slugs

All public-facing URLs use human-readable slugs:
- `/representatives/spencer-cox` instead of `/representatives/1`
- `/bills/hb-245-utah-clean-air-standards-act` instead of `/bills/3`

### 8.3 Semantic HTML

- `<header>`, `<main>`, `<footer>` landmark elements
- `<nav>` for navigation
- `<h1>` through `<h3>` in logical hierarchy
- `<table>` with `<thead>`/`<tbody>` for vote records
- `<a>` elements with descriptive text (not "click here")

---

## 9. Homepage Sections

**File:** `app/views/pages/home.html.erb`

```
┌─────────────────────────────────────────────────────────────┐
│  HERO SECTION (gradient bg)                                  │
│  H1: "Hold Utah's Leaders Accountable" (gold accent)        │
│  Subtitle: "Track votes, contact reps, make your voice heard"│
│  [Find Your Representatives]  [View Bills & Votes]           │
├─────────────────────────────────────────────────────────────┤
│  FEATURED OFFICIALS (spotlight items or executives)          │
│  Grid of 4 rep cards                                         │
├─────────────────────────────────────────────────────────────┤
│  RECENT VOTES                                                │
│  5 most recent bills with votes (bill cards)                │
├─────────────────────────────────────────────────────────────┤
│  TAKE ACTION                                                 │
│  4 featured action script cards (2-col grid)                │
├─────────────────────────────────────────────────────────────┤
│  FIND YOUR REPRESENTATIVES (always visible)                  │
│  Address input + "Find My Reps" button (Turbo Frame)        │
│  Results: Federal reps / State legislators / Executives     │
├─────────────────────────────────────────────────────────────┤
│  WHY SAVE UTAH (navy bg section)                             │
│  Mission statement, nonpartisan commitment                  │
└─────────────────────────────────────────────────────────────┘
```

**Data loaded by PagesController#home:**
| Variable | Query |
|----------|-------|
| `@hero_items` | `FeaturedItem.heroes.includes(:featurable).limit(3)` |
| `@spotlight_items` | `FeaturedItem.spotlights.includes(:featurable).limit(4)` |
| `@recent_bills` | `Bill.with_votes.recent.limit(5)` |
| `@action_scripts` | `ActionScript.active.featured.ordered.includes(:representative, :bill).limit(4)` |

---

## 10. Design Decisions

### 10.1 Why Importmap Instead of esbuild?

The application has minimal JavaScript needs (one Stimulus controller for mobile nav). Importmap eliminates the Node.js build step entirely, simplifying deployment and development setup.

### 10.2 Why Tailwind 4 with Custom Theme?

Tailwind 4's `@theme` directive enables defining custom colors without a `tailwind.config.js` file. The Utah-inspired palette creates a distinctive visual identity without custom CSS.

### 10.3 Why No Dark Mode?

The Utah color palette (sand backgrounds, navy text) creates a warm, distinctive look that doesn't translate well to a simple dark mode inversion. A proper dark mode would require a separate palette design — added as a future enhancement.

### 10.4 Why Propshaft Over Sprockets?

Rails 8 default. Propshaft is simpler (no asset compilation, just fingerprinting and serving) and pairs well with importmap-rails and tailwindcss-rails.

---

## 11. Implementation Notes

- Tailwind config: `app/assets/tailwind/application.css`
- Layout: `app/views/layouts/application.html.erb`
- JS entry: `app/javascript/application.js`
- Stimulus controllers: `app/javascript/controllers/`
- Homepage: `app/views/pages/home.html.erb`
- About page: `app/views/pages/about.html.erb`
- Shared partials: `app/views/shared/`
- Meta tags config: `config/initializers/meta_tags.rb`
- Importmap config: `config/importmap.rb`
