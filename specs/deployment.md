# Deployment Guide — Save Utah on Digital Ocean with Kamal 2

Step-by-step instructions to deploy Save Utah to a single Digital Ocean Droplet using Kamal 2, PostgreSQL in Docker, and GitHub Container Registry.

**Architecture:** One $6/mo Droplet running the Rails app (Puma + Thruster) and PostgreSQL as a Kamal accessory, both in Docker containers. No external database service needed for MVP.

**Estimated monthly cost:** $6 (just the Droplet)

---

## Prerequisites

Before you start, make sure you have:

- A [Digital Ocean](https://www.digitalocean.com/) account
- A [GitHub](https://github.com/) account
- SSH key pair on your local machine (`~/.ssh/id_rsa` or `~/.ssh/id_ed25519`)
- The Save Utah repo cloned locally with `bundle install` completed
- Docker Desktop installed and running on your Mac
- Domain: **gosaveutah.org** (with access to DNS settings at your registrar)

---

## Step 1: Create a Digital Ocean Droplet

1. Log into [Digital Ocean](https://cloud.digitalocean.com/)
2. Click **Create** > **Droplets**
3. Configure:
   - **Region:** San Francisco (SFO3) — closest to Utah
   - **Image:** Ubuntu 24.04 LTS
   - **Size:** Basic, Regular, $6/mo (1 vCPU, 1 GB RAM, 25 GB SSD)
   - **Authentication:** Select your SSH key (or add one)
   - **Hostname:** `save-utah` (or whatever you want)
4. Click **Create Droplet**
5. Copy the **IP address** once it's created (e.g., `164.90.xxx.xxx`)

### Point your domain to the Droplet

Log into wherever you bought `gosaveutah.org` (Namecheap, GoDaddy, Cloudflare, etc.) and set these DNS records:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | `@` | `YOUR_DROPLET_IP` | 300 |
| A | `www` | `YOUR_DROPLET_IP` | 300 |

DNS propagation can take a few minutes to a few hours. You can check if it's working with:

```bash
dig gosaveutah.org +short
```

It should return your Droplet IP. Don't worry if it's not ready yet — the deploy will still work via IP, and SSL will provision once DNS propagates.

---

## Step 2: Create a GitHub Personal Access Token

Kamal needs this to push/pull Docker images from GitHub Container Registry (ghcr.io).

1. Go to [GitHub Settings > Developer Settings > Personal Access Tokens > Tokens (classic)](https://github.com/settings/tokens)
2. Click **Generate new token (classic)**
3. Configure:
   - **Note:** `kamal-save-utah`
   - **Expiration:** 90 days (or longer)
   - **Scopes:** Check `write:packages` and `read:packages`
4. Click **Generate token**
5. **Copy the token immediately** — you won't see it again

---

## Step 3: Get Your Rails Master Key

Your master key is already generated and lives at `config/master.key`. You need the value for deployment.

```bash
cat config/master.key
```

Copy the output (a hex string like `abc123def456...`).

> This file is gitignored and should NEVER be committed. It decrypts `config/credentials.yml.enc`.

---

## Step 4: Update `config/deploy.yml`

This file is committed to git — and that's fine. **No secrets go in here.** It only contains:
- Your GitHub username (public info)
- Your Droplet IP (public info)
- The **names** of secrets (e.g., `KAMAL_REGISTRY_PASSWORD`) — not the actual values

The actual secret values live in `.kamal/secrets` (Step 5), which is gitignored and never committed. Think of it like how `.env` works: your code references `ENV["SECRET"]` but the value lives in `.env`.

Replace **only these two placeholders** with your actual (non-secret) values:
- `YOUR_GITHUB_USERNAME` — your GitHub username (e.g., `brendanbliss`)
- `YOUR_DROPLET_IP` — the IP from Step 1 (e.g., `164.90.123.45`)

```yaml
# Name of your application
service: save_utah

# Container image name — your GitHub username + app name
image: YOUR_GITHUB_USERNAME/save_utah

# Deploy to these servers
servers:
  web:
    - YOUR_DROPLET_IP

# Enable SSL via Let's Encrypt — Kamal proxy handles it automatically
# Requires DNS to be pointed at the Droplet IP first (Step 1)
proxy:
  ssl: true
  host: gosaveutah.org

# GitHub Container Registry
registry:
  server: ghcr.io
  username: YOUR_GITHUB_USERNAME
  password:
    - KAMAL_REGISTRY_PASSWORD        # <-- this is a NAME, not a value
                                     #     the actual token lives in .kamal/secrets

# Environment variables injected into the app container
env:
  secret:                            # <-- these are NAMES that Kamal looks up
    - RAILS_MASTER_KEY               #     in .kamal/secrets at deploy time
    - SAVE_UTAH_DATABASE_PASSWORD
  clear:                             # <-- these are plain values, not secrets
    SOLID_QUEUE_IN_PUMA: true
    DB_HOST: save_utah-db

# Persistent storage
volumes:
  - "save_utah_storage:/rails/storage"

# Asset bridging between deploys
asset_path: /rails/public/assets

# PostgreSQL as a Kamal accessory (runs on the same Droplet)
accessories:
  db:
    image: postgres:17
    host: YOUR_DROPLET_IP
    port: "127.0.0.1:5432:5432"
    env:
      clear:
        POSTGRES_DB: save_utah_production
        POSTGRES_USER: save_utah
      secret:
        - SAVE_UTAH_DATABASE_PASSWORD  # <-- same NAME, looked up from .kamal/secrets

    directories:
      - data:/var/lib/postgresql/data

# Build for AMD64 (Digital Ocean Droplets)
builder:
  arch: amd64

# Useful aliases
aliases:
  console: app exec --interactive --reuse "bin/rails console"
  shell: app exec --interactive --reuse "bash"
  logs: app logs -f
  dbc: app exec --interactive --reuse "bin/rails dbconsole --include-password"
```

---

## Step 5: Configure `.kamal/secrets` (the actual secret values)

This is your `.env` equivalent for Kamal. It stores the **actual passwords and tokens** and is **already gitignored** (the `.kamal/` directory is in `.gitignore`). This file never leaves your machine — Kamal reads it locally and injects the values into containers over SSH at deploy time.

Create the directory if it doesn't exist:

```bash
mkdir -p .kamal
```

Generate a strong database password:

```bash
openssl rand -hex 32
```

Create/edit `.kamal/secrets` with these contents:

```
KAMAL_REGISTRY_PASSWORD=ghp_YOUR_GITHUB_TOKEN_HERE
RAILS_MASTER_KEY=YOUR_MASTER_KEY_HERE
SAVE_UTAH_DATABASE_PASSWORD=THE_PASSWORD_YOU_JUST_GENERATED
```

**Replace the values (right side of `=` only):**
- `ghp_YOUR_GITHUB_TOKEN_HERE` — the GitHub PAT from Step 2
- `YOUR_MASTER_KEY_HERE` — the value from `cat config/master.key`
- `THE_PASSWORD_YOU_JUST_GENERATED` — the output of `openssl rand -hex 32`

> **How it connects:** When `deploy.yml` says `secret: - RAILS_MASTER_KEY`, Kamal looks up `RAILS_MASTER_KEY` in this file, reads the value, and passes it to the container as an environment variable. The secret name is committed; the secret value is not.

---

## Step 6: Update `config/database.yml` (Production)

The production database config needs to connect to the Postgres container via `DB_HOST`. The current config uses `SAVE_UTAH_DATABASE_PASSWORD` which is already set. Just make sure the production section uses the `DB_HOST` env var:

The existing `database.yml` production section should work as-is because Rails auto-merges `DATABASE_URL` when present. But since we're using explicit config, verify the production block includes a host line:

```yaml
production:
  primary: &primary_production
    <<: *default
    database: save_utah_production
    host: <%= ENV.fetch("DB_HOST", "localhost") %>
    username: save_utah
    password: <%= ENV["SAVE_UTAH_DATABASE_PASSWORD"] %>
  cache:
    <<: *primary_production
    database: save_utah_production_cache
    migrations_paths: db/cache_migrate
  queue:
    <<: *primary_production
    database: save_utah_production_queue
    migrations_paths: db/queue_migrate
  cable:
    <<: *primary_production
    database: save_utah_production_cable
    migrations_paths: db/cable_migrate
```

The key addition is `host: <%= ENV.fetch("DB_HOST", "localhost") %>` so the Rails container can reach the Postgres container via Docker networking.

### Also: Enable SSL in `config/environments/production.rb`

Since we're deploying with a domain and SSL from the start, uncomment these three lines:

```ruby
config.assume_ssl = true
config.force_ssl = true
config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }
```

This tells Rails that Kamal's proxy is terminating SSL in front of it, and to redirect all HTTP requests to HTTPS. The health check endpoint (`/up`) is excluded so Kamal can still reach it over plain HTTP internally.

---

## Step 7: Deploy

Make sure Docker Desktop is running, then:

### First-time setup (installs Docker on the Droplet, starts accessories, deploys the app):

```bash
bin/kamal setup
```

This will:
1. SSH into your Droplet and install Docker
2. Log into ghcr.io with your token
3. Build the Docker image locally (takes 3-5 min first time)
4. Push the image to ghcr.io
5. Start the PostgreSQL accessory container
6. Start the Rails app container
7. Run `db:prepare` (creates the database and runs migrations)
8. Start the Kamal proxy (handles HTTP routing)

### Seed the database:

```bash
bin/kamal app exec "bin/rails db:seed"
```

### Verify it's running:

```bash
# Check the app is healthy
curl https://gosaveutah.org/up

# View logs
bin/kamal logs

# Open Rails console
bin/kamal console
```

Visit `https://gosaveutah.org` in your browser — you should see the blast homepage with 19 senator cards.

> **If DNS hasn't propagated yet**, you can test via IP: `curl http://YOUR_DROPLET_IP/up`. SSL won't work until DNS is pointed correctly, but the app will still be running.

---

## Subsequent Deploys

After the initial setup, deploy new changes with:

```bash
bin/kamal deploy
```

This builds a new image, pushes it, and performs a zero-downtime rolling restart.

---

## Common Operations

```bash
# View app logs (streaming)
bin/kamal logs

# Rails console
bin/kamal console

# SSH into the container
bin/kamal shell

# Database console
bin/kamal dbc

# Run a rake task
bin/kamal app exec "bin/rails import:all"

# Restart the app (no rebuild)
bin/kamal app boot

# Check deployment status
bin/kamal details
```

---

## Troubleshooting

### Build fails with "no space left on device"
The 25GB SSD can fill up with old Docker images. Clean up:
```bash
bin/kamal app exec "docker system prune -af"
```

### App can't connect to database
Check the DB accessory is running:
```bash
bin/kamal accessory details db
bin/kamal accessory logs db
```

Restart it if needed:
```bash
bin/kamal accessory reboot db
```

### "Permission denied" SSH errors
Make sure your SSH key is added to the Droplet and to your local SSH agent:
```bash
ssh-add ~/.ssh/id_ed25519
ssh root@YOUR_DROPLET_IP  # test manually
```

### Container keeps crashing
Check logs for errors:
```bash
bin/kamal logs --since 5m
```

Common issues:
- Missing `RAILS_MASTER_KEY` — check `.kamal/secrets`
- Database not ready — the entrypoint runs `db:prepare` but Postgres might not be up yet. Redeploy and it should work.

### Need to run migrations manually
```bash
bin/kamal app exec "bin/rails db:migrate"
```

---

## Architecture Diagram

```
        gosaveutah.org
              │
              ▼ DNS A record
┌─────────────────────────────────────────────┐
│              Digital Ocean Droplet          │
│              Ubuntu 24.04 ($6/mo)           │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │         kamal-proxy                 │    │
│  │  Let's Encrypt SSL (auto-renewed)   │    │
│  │         Port 80 / 443              │    │
│  └──────────────┬──────────────────────┘    │
│                 │                            │
│  ┌──────────────▼──────────────────────┐    │
│  │      save_utah (Rails app)          │    │
│  │   Puma + Thruster + Solid Queue     │    │
│  │         Port 3000 (internal)        │    │
│  └──────────────┬──────────────────────┘    │
│                 │ DB_HOST=save_utah-db       │
│  ┌──────────────▼──────────────────────┐    │
│  │     save_utah-db (PostgreSQL 17)    │    │
│  │         Port 5432 (internal)        │    │
│  │   Volume: data:/var/lib/postgres    │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  Volume: save_utah_storage:/rails/storage   │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│         GitHub Container Registry           │
│            ghcr.io (free)                   │
│   Stores Docker images between deploys      │
└─────────────────────────────────────────────┘
```

---

## Cost Summary

| Resource | Cost |
|----------|------|
| DO Droplet (1GB RAM) | $6/mo |
| gosaveutah.org domain | ~$10/yr |
| GitHub Container Registry | Free |
| Let's Encrypt SSL | Free |
| **Total** | **~$6/mo + $10/yr** |

Upgrade to a 2GB Droplet ($12/mo) if you see memory pressure. Check with:
```bash
ssh root@YOUR_DROPLET_IP free -h
```
