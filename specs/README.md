# Save Utah Specifications

Design documentation for the Save Utah civic engagement platform — tracking Utah elected officials, their voting records, and providing citizens with tools to take action.

## System Architecture

| Spec | Code | Purpose |
|------|------|---------|
| [architecture.md](./architecture.md) | [app/](../app/) | System architecture, data flow, deployment roadmap |

## Data Layer

| Spec | Code | Purpose |
|------|------|---------|
| [data-model.md](./data-model.md) | [app/models/](../app/models/), [db/schema.rb](../db/schema.rb) | Database schema, models, enums, associations, indexes |
| [data-import-system.md](./data-import-system.md) | [app/services/](../app/services/), [lib/tasks/](../lib/tasks/) | API clients, importers, rake tasks, error handling |

## Features

| Spec | Code | Purpose |
|------|------|---------|
| [representatives-system.md](./representatives-system.md) | [app/controllers/representatives_controller.rb](../app/controllers/representatives_controller.rb), [app/views/representatives/](../app/views/representatives/) | Representative listing, filtering, search, detail pages |
| [bills-system.md](./bills-system.md) | [app/controllers/bills_controller.rb](../app/controllers/bills_controller.rb), [app/views/bills/](../app/views/bills/) | Bill listing, filtering, vote breakdowns, editorial summaries |
| [issues-system.md](./issues-system.md) | [app/controllers/issues_controller.rb](../app/controllers/issues_controller.rb), [app/views/issues/](../app/views/issues/) | Issue scorecards, accountability scoring, blast pages |
| [action-scripts-system.md](./action-scripts-system.md) | [app/models/action_script.rb](../app/models/action_script.rb), [app/views/shared/_script_card.html.erb](../app/views/shared/_script_card.html.erb) | Call/email scripts with template placeholders |

## Frontend

| Spec | Code | Purpose |
|------|------|---------|
| [frontend-system.md](./frontend-system.md) | [app/views/](../app/views/), [app/assets/tailwind/](../app/assets/tailwind/), [app/javascript/](../app/javascript/) | Tailwind theme, layout, partials, Stimulus, SEO |
