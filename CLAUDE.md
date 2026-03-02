# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Save Utah — a civic engagement platform tracking Utah elected officials (state + federal), their voting records, and giving citizens tools to take action (call scripts, contact info). No user auth, no admin panel — public information site.

## Tech Stack

- **Ruby 4.0.1** / **Rails 8.1.1** (importmaps, Propshaft, Tailwind 4)
- **PostgreSQL 17**
- **Tailwind CSS** via `tailwindcss-rails` gem with Utah-inspired color palette
- **Pagy 43** for pagination (uses `Pagy::Method` include, `Pagy::OPTIONS` for config — NOT the old `Pagy::Backend`/`Pagy::DEFAULT` API)

## Common Commands

```bash
bin/dev                          # Start dev server (Rails + Tailwind watcher)
bin/rails db:migrate             # Run migrations
bin/rails db:seed                # Seed sample data (idempotent)
bin/rails tailwindcss:build      # Compile Tailwind CSS
rake import:all                  # Full data import (all APIs)
rake import:federal_members      # Congress.gov — Utah federal delegation
rake import:state_legislators    # Utah Legislature API — state reps
rake import:federal_bills        # Congress.gov — federal bills
rake import:state_bills          # Utah Legislature API — state bills
rake import:federal_votes        # Congress.gov — House votes
rake import:state_votes          # Utah Legislature API — floor votes
```

## Architecture

- **Models**: Representative, Bill, Vote (join), ActionScript, FeaturedItem (polymorphic)
- **Controllers**: PagesController (home/about), RepresentativesController, BillsController
- **Services**: `app/services/{congress_gov,utah_legislature,open_states}/` — API clients + importers
- **Views**: Tailwind-styled, partials in `app/views/shared/`

## Key Patterns

- Models use `friendly_id` for SEO slugs (`/representatives/spencer-cox`)
- Importers follow `find_or_initialize_by(external_id) → assign_attributes → save`
- Ruby 4.0 has frozen string literals by default — use `.dup` when mutating strings
- Enums use Rails 8 positional integer style (`enum :position_type, { us_senator: 0, ... }`)

## Specs Workflow

The `specs/` directory contains detailed specification documents for all major systems. **Always** follow this workflow:

1. **Before starting any task**: Read relevant specs in `specs/` for context before making changes. Cross-reference the specs index (`specs/README.md`) to identify which specs relate to your work.
2. **During implementation**: Ensure your changes align with the documented architecture, data models, and patterns described in the specs.
3. **After completing a task**: Evaluate whether any specs need to be created or updated to reflect the changes. If the task introduced new models, controllers, services, views, or changed existing behavior documented in a spec, update the relevant spec(s) using the spec skill.

### Current Specs

- `specs/architecture.md` — Overall system architecture
- `specs/data-model.md` — Database schema and model relationships
- `specs/representatives-system.md` — Representatives feature
- `specs/bills-system.md` — Bills feature
- `specs/data-import-system.md` — API import services and rake tasks
- `specs/action-scripts-system.md` — Action scripts / call scripts
- `specs/frontend-system.md` — Tailwind, layouts, shared partials

## API Keys Required

- `CONGRESS_GOV_API_KEY` — free at api.congress.gov
- `UTAH_LEGISLATURE_TOKEN` — from glen.le.utah.gov
- `OPENSTATES_API_KEY` — free at openstates.org
