# enterno-oss-samples

> **Sysadmin and web-ops scripts that accompany the how-to guides at
> [enterno.io/how-to](https://enterno.io/how-to).** Tested on current
> Debian 12 / Ubuntu 22.04 LTS; all are idempotent — run them twice and
> you'll still end up with the same result.

[![enterno.io](https://img.shields.io/badge/docs-enterno.io-5b8af8)](https://enterno.io)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](./LICENSE)

## Why this repo exists

Each script here is a "one-file incarnation" of a guide on enterno.io.
The guide explains **why** you should do the thing; the script is
**how** to do it without copy-pasting 40 terminal commands from a blog
post that drifts out of date the moment it's published.

If you spot something wrong — open an issue or a PR. Better yet, reach
out at [enterno.io/contact](https://enterno.io/contact) and we'll tune
the matching guide.

## What's here

| Script | Matching guide | What it does |
|--------|----------------|--------------|
| [`scripts/ssh-hardening.sh`](./scripts/ssh-hardening.sh) | [SSH hardening](https://enterno.io/s/how-to-ssh-hardening) | Disable password + root login, force public-key auth, enable fail2ban sshd jail |
| [`scripts/letsencrypt-wildcard.sh`](./scripts/letsencrypt-wildcard.sh) | [Let's Encrypt wildcard cert](https://enterno.io/s/how-to-lets-encrypt-wildcard) | Issue `*.example.com` via DNS-01 with certbot, wire nginx auto-renew |
| [`scripts/backup-postgres.sh`](./scripts/backup-postgres.sh) | [PostgreSQL backups](https://enterno.io/s/how-to-postgresql-backups) | Daily pg_dump with 7-day rotation and S3 offsite copy |
| [`scripts/setup-fail2ban.sh`](./scripts/setup-fail2ban.sh) | [Setup fail2ban](https://enterno.io/s/how-to-setup-fail2ban) | Install + basic jails (sshd, nginx-bad-bot, nginx-limit-req) |
| [`scripts/install-ssl-nginx.sh`](./scripts/install-ssl-nginx.sh) | [Install SSL on nginx](https://enterno.io/s/how-to-install-ssl-nginx) | Bootstrap nginx with Let's Encrypt + HTTP/2 + HSTS + OCSP stapling |

## Usage

```bash
# Clone
git clone https://github.com/enterno-io/enterno-oss-samples.git
cd enterno-oss-samples/scripts

# Read before running
cat ssh-hardening.sh

# Dry-run
sudo DRY_RUN=1 ./ssh-hardening.sh

# Real run
sudo ./ssh-hardening.sh
```

Every script:

- Requires `sudo` / root.
- Bails out with a clear error if a required tool is missing.
- Honours `DRY_RUN=1` to echo commands without executing.
- Takes a backup (`.bak-<date>`) of any file it rewrites.

## Related tools

If you need to **continuously** verify the things these scripts set up —
SSL expiry, nginx headers, fail2ban bans, DNS propagation — the tools
at [enterno.io](https://enterno.io) (SSL checker, Security Scanner,
Heartbeat monitor, DNS Lookup) run the same checks on a schedule with
alerts to Telegram / Slack / Email. 20 monitors free forever.

Free one-off checks that pair well with these scripts:

| After running… | Verify with |
|---|---|
| `install-ssl-nginx.sh` / `letsencrypt-wildcard.sh` | [SSL certificate checker](https://enterno.io/en/ssl) — chain, expiry, protocols |
| `ssh-hardening.sh` / `setup-fail2ban.sh` | [Port scanner](https://enterno.io/en/port-scanner) — confirm only 22/80/443 are open |
| any nginx change | [Security headers scanner](https://enterno.io/en/security) — HSTS, CSP, cookies graded A–F |
| DNS / domain moves | [DNS lookup](https://enterno.io/en/dns) + [subdomain finder](https://enterno.io/en/subdomain-enum) (CT-log search, a fast [crt.sh alternative](https://enterno.io/en/s/alternatives-crt-sh)) |
| mail server setup | [Email deliverability check](https://enterno.io/en/email-check) — SPF, DKIM, DMARC, blacklists |

## Contributing

Pull requests welcome — please include:

1. A short description of what broke / what you're adding.
2. A link to the matching how-to page (or propose one if missing).
3. Tested on `uname -a` + distro version.

## License

[MIT](./LICENSE) — use it, fork it, ship it in your own ops playbook.
