# SSL Renewal Toolkit

Centralized SSL/TLS certificate automation for one **main server** and multiple **node servers**.

- Main server issues and renews certificates with Certbot + Cloudflare DNS challenge.
- Node servers receive renewed certificates over SSH and use them in Nginx.
- Nodes do **not** renew locally.

This repository keeps the existing Bash workflow and improves safety, docs, and installation UX.

---

## Quick Install

Repository:

- `https://github.com/indie-master/SSL-Renewal`

### Main server

**curl method**

```bash
curl -fsSL https://raw.githubusercontent.com/indie-master/SSL-Renewal/main/bootstrap.sh | bash -s -- https://github.com/indie-master/SSL-Renewal.git main
```

**wget method**

```bash
wget -qO- https://raw.githubusercontent.com/indie-master/SSL-Renewal/main/bootstrap.sh | bash -s -- https://github.com/indie-master/SSL-Renewal.git main
```

**Manual method**

```bash
git clone https://github.com/indie-master/SSL-Renewal.git
cd SSL-Renewal
chmod +x install.sh
sudo ./install.sh main
```

### Node server

**curl method**

```bash
curl -fsSL https://raw.githubusercontent.com/indie-master/SSL-Renewal/main/bootstrap.sh | bash -s -- https://github.com/indie-master/SSL-Renewal.git node
```

**Manual method**

```bash
git clone https://github.com/indie-master/SSL-Renewal.git
cd SSL-Renewal
chmod +x install.sh
sudo ./install.sh node
```

### After install

```bash
ssl-renewal help
ssl-renewal doctor
ssl-renewal cloudflare-help
ssl-renewal issue
ssl-renewal deploy
ssl-renewal dry-run
```

> Warning: Always review `bootstrap.sh` before running remote shell commands:
> `https://github.com/indie-master/SSL-Renewal/blob/main/bootstrap.sh`

---

## Architecture

```text
                           +----------------------+
                           |   Cloudflare DNS     |
                           |  API Token (main)    |
                           +----------+-----------+
                                      |
                                      | dns-01 challenge
                                      v
+----------------------+      +----------------------+      +----------------------+
| Main server          | SSH  | Node 1               | ...  | Node N               |
| - certbot issue      +----->| - receives cert      |      | - receives cert      |
| - renew hook deploy  |      | - nginx -t && reload |      | - nginx -t && reload |
| - optional telegram  |      | - local renew off    |      | - local renew off    |
+----------+-----------+      +----------------------+      +----------------------+
           |
           v
 /etc/letsencrypt/renewal-hooks/deploy/ssl-renewal-deploy.sh
 triggers deploy-certs.sh after successful renewals
```

---

## Repository layout

- `install.sh` — interactive installer for `main` and `node`
- `scripts/ssl-renewal` — CLI entrypoint
- `scripts/lib.sh` — shared helpers and validations
- `scripts/deploy-certs.sh` — sync certs to nodes and reload Nginx safely
- `scripts/node-prep.sh` — disable local renewal on nodes
- `scripts/node-nginx-patch.sh` — preview/apply nginx cert path rewrites
- `scripts/disable-renew-on-nodes.sh` — remote renewal disable from main
- `scripts/telegram-notify.sh` — optional Telegram notification sender
- `smoke-test.sh` — shell syntax smoke checks

---

## Prerequisites

- Ubuntu/Debian (apt-based)
- Root access
- Nginx on nodes
- SSH connectivity from main to nodes
- Cloudflare-managed DNS for your zone

Installed automatically by `install.sh`:

- `curl`, `openssh-client`, `openssh-server`, `rsync`, `jq`, `snapd`
- `certbot` (snap)
- `certbot-dns-cloudflare` plugin

---

## GitHub-first bootstrap

### Option A: clone + install (recommended)

```bash
git clone <YOUR_REPO_URL> ssl-renewal
cd ssl-renewal
chmod +x install.sh
sudo ./install.sh main
```

### Option B: short bootstrap (review before running)

```bash
bash -c 'set -euo pipefail; tmp=$(mktemp -d); cd "$tmp"; git clone <YOUR_REPO_URL> repo; cd repo; chmod +x install.sh; sudo ./install.sh main'
```

> Security note: Always review scripts before executing bootstrap one-liners.


### Option C: helper bootstrap script

```bash
chmod +x bootstrap.sh
./bootstrap.sh <YOUR_REPO_URL> main
```

---

## Installation

## 1) Main server install

```bash
sudo ./install.sh main
```

Installer flow:

1. Installs dependencies
2. Installs Certbot + Cloudflare plugin
3. Collects:
   - primary domain (example: `example.com`)
   - DNS propagation wait seconds
   - target cert path for nodes
   - optional regional wildcard prefixes (example: `region1,region2`)
4. Cloudflare token onboarding (immediate or deferred)
5. Node list entry (`user@host` per line)
6. Optional SSH key bootstrap with `ssh-copy-id`
7. Optional Telegram setup
8. Installs deploy hook in `/etc/letsencrypt/renewal-hooks/deploy/`
9. Optionally issues certificate and deploys to nodes

## 2) Node install

```bash
sudo ./install.sh node
```

Installer flow:

1. Writes node role config
2. Prepares cert target path
3. Disables local certbot timers/hooks
4. Optionally patches nginx certificate paths

---

Required permissions:

Required minimum permissions:

- `Zone -> DNS -> Edit`
- `Zone -> Zone -> Read`

Token file location on main:

```bash
/root/.secrets/certbot/cloudflare.ini
```

Required permissions:

```bash
chmod 600 /root/.secrets/certbot/cloudflare.ini
```

### Flow A: token provided during install

Choose **yes** when installer asks `Add Cloudflare API Token now?`.

### Flow B: token added after install

Choose **no** during install; placeholder file will be created and installation continues.

Then set token later:

```bash
sudo nano /root/.secrets/certbot/cloudflare.ini
# dns_cloudflare_api_token = <REAL_TOKEN>

ssl-renewal cloudflare-help
ssl-renewal doctor
ssl-renewal issue
```

---

## SSH onboarding for nodes

Installer behavior on main:

- Generates `/root/.ssh/id_ed25519` if missing
- Optionally runs `ssh-copy-id` for each node
- If automatic deployment fails (e.g., password auth disabled), installer:
  - prints the public key
  - prints manual `authorized_keys` instructions
  - continues without crashing

Manual method:

```bash
# On main
cat /root/.ssh/id_ed25519.pub

# On each node (as target user)
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo '<PASTE_PUBLIC_KEY_HERE>' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

---

## CLI usage

```bash
ssl-renewal help
ssl-renewal doctor
ssl-renewal status
ssl-renewal start
ssl-renewal stop
ssl-renewal restart
ssl-renewal reload
ssl-renewal enable
ssl-renewal disable
ssl-renewal issue
ssl-renewal dry-run
ssl-renewal deploy
ssl-renewal notify-test
ssl-renewal edit-config
ssl-renewal paths
ssl-renewal patch-nginx
ssl-renewal patch-nginx --apply
ssl-renewal disable-node-renew
ssl-renewal cloudflare-help
```

---

## Operational workflow

1. Issue/renew cert on main (`ssl-renewal issue`)
2. Certbot deploy hook triggers `deploy-certs.sh` after renewals
3. Main copies `fullchain.pem` + `privkey.pem` to nodes
4. Node validates `nginx -t` before reload
5. Optional Telegram message sent with success/failure summary

---

## First-run checklist

1. `ssl-renewal doctor`
2. `ssl-renewal status`
3. `ssl-renewal dry-run`
4. `ssl-renewal deploy`
5. Validate Nginx on nodes

---

## Troubleshooting

See `docs/TROUBLESHOOTING.md`.

---

## Security notes

- Keep Cloudflare token only on main server.
- Keep `config.env` and Cloudflare credentials at mode `600`.
- Prefer dedicated SSH deploy user with limited rights where possible.
- Do not commit secrets or real infrastructure names to Git.

---

## Upgrade / rollback / uninstall

See `docs/OPERATIONS.md`.
