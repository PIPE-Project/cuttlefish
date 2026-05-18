# ![Cuttlefish](https://raw.github.com/mlandauer/cuttlefish/master/app/assets/images/cuttlefish_80x48.png) Cuttlefish

Cuttlefish is a self-hosted transactional email server. Your app sends email to it via SMTP; it relays through Postfix, tracks opens/clicks/bounces, and provides a web UI and GraphQL API.

This is a fork of [openaustralia/cuttlefish](https://github.com/openaustralia/cuttlefish), updated for modern infrastructure and made portable for anyone to self-host — not just OpenAustralia Foundation.

* Original project site: [cuttlefish.io](https://cuttlefish.io)

---

## Features

* Send email from your app over SMTP and get delivery tracking for free
* Web UI to browse sent mail, view content, and monitor delivery status
* Real-time open, click, bounce, and hard-block tracking
* Automatic DKIM signing per application
* Deny list management (hard bounces never retried)
* Multiple apps, each with their own SMTP credentials
* GraphQL API for everything the UI can do
* Web callbacks on delivery success or failure
* One-click IP reputation check

---

## Tech stack

| Component | Version |
|-----------|---------|
| Ruby | 3.3.5 |
| Rails | 7.1 |
| PostgreSQL | 16 |
| Redis | 7 |
| Sidekiq | 7 |
| Postfix | latest |
| Nginx + Passenger | latest |

---

## Development

The only dependency for local development is Docker and Docker Compose.

**1. Create the database:**

```bash
docker compose run web bundle exec rake db:create db:schema:load
```

**2. (Optional) Load seed data** — creates a site admin with email `joy@smart-unlimited.com` and password `password`:

```bash
docker compose run web bundle exec rake db:seed
```

**3. Start all services:**

```bash
docker compose up
```

**4. Open the app:**

* Web UI: http://localhost:3000
* Mailcatcher (catches all outbound mail in dev): http://localhost:1080

Log in with `joy@smart-unlimited.com` / `password` if you seeded the database.

**5. Run the tests:**

```bash
docker compose exec web rake
```

---

## Production setup

Production uses Ansible to provision a fresh Ubuntu 24.04 server, then `deploy.sh` to deploy the app.

### Prerequisites

* A fresh Ubuntu 24.04 VPS with root SSH access
* Python 3 on your local machine
* A domain name pointed at the server IP
* The server's IP must have a matching reverse DNS (PTR) record for good mail deliverability

### Step 1 — Configure your inventory

```bash
cp provisioning/hosts.example provisioning/hosts
```

Edit `provisioning/hosts` and replace `your-server-ip-or-hostname` with your server's IP or hostname.

### Step 2 — Configure your domain and options

Edit `provisioning/group_vars/all` and set `cuttlefish_domain` to your domain (e.g. `mail.example.com`). Other options in that file are documented inline.

### Step 3 — Create your secrets file

```bash
cp provisioning/group_vars/secrets.yml.example provisioning/group_vars/secrets.yml
```

Edit `secrets.yml` and fill in all required values. Generate Rails secrets with:

```bash
rails secret
# or: openssl rand -hex 64
```

`secrets.yml` is gitignored and must never be committed.

### Step 4 — Provision the server

```bash
./provision_production.sh --ask-pass
```

Use `--ask-pass` the first time (root password login). On subsequent runs it will use the SSH key added during provisioning.

Optional environment variables:

* `TAGS` — comma-separated tags to run only specific tasks
* `SKIP_TAGS` — comma-separated tags to skip
* `START_AT_TASK` — task name to start from

### Step 5 — Deploy the application

```bash
./deploy.sh your-server-ip-or-hostname
```

This SSHes as the `deploy` user, pulls the latest code, installs gems, runs migrations, precompiles assets, and restarts Passenger.

On first run it will clone the repository. Subsequent deploys are fast.

### Step 6 — DNS records

Once the app is running, add these DNS records for your sending domain:

* **SPF**: `v=spf1 ip4:YOUR_SERVER_IP -all`
* **PTR (reverse DNS)**: set in your VPS control panel to match your domain
* **DKIM**: each app in the UI has its own DKIM key — add the public key as a TXT record when prompted

---

## Clobbering provisioning artefacts

To reset the Ansible virtualenv and downloaded roles:

```bash
./provision_production.sh clobber
```

Run this after changing `provisioning/requirements.txt`, `provisioning/requirements.yml`, or your Python version.

---

## Deploying updates

```bash
./deploy.sh your-server-ip-or-hostname
```

There is no migration auto-detection — migrations run on every deploy (idempotent). If you need to roll back, SSH to the server and use `git checkout` in `/srv/www/current`.

---

## Screenshots

![Sign up](https://raw.github.com/mlandauer/cuttlefish/master/app/assets/images/screenshots/1.png)
![Dashboard](https://raw.github.com/mlandauer/cuttlefish/master/app/assets/images/screenshots/2.png)
![Email](https://raw.github.com/mlandauer/cuttlefish/master/app/assets/images/screenshots/3.png)

---

## Changes from upstream

This fork makes the following changes relative to [openaustralia/cuttlefish](https://github.com/openaustralia/cuttlefish):

### Stack modernisation

| Component | Upstream | This fork |
|-----------|----------|-----------|
| Ruby | 3.0.6 | 3.3.5 |
| Rails | 6.1 | 7.1 |
| PostgreSQL | 13 | 16 |
| Redis | 4.0+ | 7 |
| Sidekiq | 5.1 | 7 |
| GraphQL gem | 1.12 | 1.13.x |

### Ansible provisioning rewrite

The provisioning playbook was substantially rewritten:

* **Ubuntu 24.04 (noble)** — updated from Ubuntu 16.04/20.04. PostgreSQL APT source updated to noble-pgdg; deprecated `apt_key` + keyserver replaced with `get_url` + `/etc/apt/keyrings/`.
* **Portable configuration** — all hardcoded OpenAustralia Foundation values (domain, certbot email, GitHub SSH users) have been replaced with variables in `group_vars/all` and `group_vars/secrets.yml`.
* **Secrets file** — secrets are now in `group_vars/secrets.yml` (gitignored). A `secrets.yml.example` template is provided so new deployments know exactly what to fill in.
* **`hosts` is gitignored** — `hosts.example` is provided instead, so server IPs and hostnames are never accidentally committed.
* **New Relic is optional** — controlled by `new_relic_enabled: false` in `group_vars/all`. Previously it was an always-on dependency.
* **Modern nginx TLS** — dropped TLSv1 and TLSv1.1, added TLSv1.3, updated cipher suite.
* **Ansible version check relaxed** — from `== 2.15` to `>= 2.15`.

### `deploy.sh` replaces Capistrano 2

The original deployment method used Capistrano 2, which is unmaintained and requires a Ruby/Bundler installation on the control machine. This fork replaces it with `deploy.sh` — a plain shell script that SSHes to the server and runs standard git/bundle/rake commands. No Capistrano, no Gemfile required on the deploying machine.

---

## Known limitations

* **Capistrano 2 config still present** — `config/deploy.rb` and `Capfile` remain for reference but are not used. `deploy.sh` is the supported deployment method.
* **Postfix log parsing is fragile** — `CuttlefishLogDaemon` uses regex on syslog output. A Postfix or OS upgrade that changes log format can silently break bounce detection.
* **Single-server only** — email content is cached on the local filesystem. Horizontal scaling would require refactoring.
* **DKIM keys never rotate** — keys live in the database indefinitely. Manual rotation requires updating the DB record and DNS.

---

## How to contribute

If you find what looks like a bug:

* Check the [GitHub issue tracker](http://github.com/mlandauer/cuttlefish/issues/)
  to see if anyone else has reported issue.
* If you don't see anything, create an issue with information on how to reproduce it.

If you want to contribute an enhancement or a fix:

* Fork the project on GitHub.
* Make your changes with tests.
* Commit the changes without making changes to any files that aren't related to your enhancement or fix.
* Send a pull request.
