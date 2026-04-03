# SSL Renewal

Centralized wildcard certificate issuance and deployment for a main server + Nginx nodes.

Developer: **Indie_Master**  
GitHub: https://github.com/indie-master

## What it does

- issues a wildcard certificate on the **main** server with Certbot + Cloudflare DNS
- stores certs at:

```bash
/etc/letsencrypt/live/domain.com/
```

- pushes `fullchain.pem` and `privkey.pem` to all nodes over SSH
- reloads nginx on nodes only after `nginx -t`
- disables local renewal timers on nodes
- optionally sends Telegram notifications
- provides a unified CLI:

```bash
ssl-renewal help
ssl-renewal doctor
ssl-renewal status
ssl-renewal issue
ssl-renewal dry-run
ssl-renewal deploy
ssl-renewal edit-config
ssl-renewal patch-nginx --apply
ssl-renewal disable-node-renew
```

## Roles

### Main server

Run:

```bash
chmod +x install.sh
./install.sh main
```

The installer will:

- install dependencies
- install Certbot + `dns-cloudflare`
- ask for the main domain
- ask for regional wildcard zones like `de,msk,sk,us`
- ask for Cloudflare token
- ask for node list
- optionally attempt SSH key deployment to nodes
- optionally enable Telegram notifications
- issue the certificate
- install the deploy hook
- optionally push certs to nodes

### Node

Run on each node:

```bash
chmod +x install.sh
./install.sh node
```

The installer will:

- prepare `/etc/letsencrypt/live/<domain>/`
- disable local Certbot renew timers
- optionally patch nginx `ssl_certificate` paths
- keep the node ready to receive certs from main

## Recommended domain set

Example for your case:

- `domain.com`
- `*.domain.comu`
- `*.de.domain.com`
- `*.msk.domain.com`
- `*.sk.domain.com`
- `*.us.domain.com`

The script builds this from the primary domain plus a comma-separated region list.

## Telegram

When enabled, Telegram gets notifications about:

- successful deploy
- partial deploy failures

## Notes

- the GitHub connector available in this environment can write to existing accessible repositories, but it does **not** expose repository creation. This package is provided ready to upload to a new repo manually, or I can push it into an existing repo you specify.


## Cloudflare API Token

Для main-сервера нужен Cloudflare API Token. Скрипт `install.sh` теперь умеет:
- показать краткую инструкцию по получению токена,
- принять токен сразу во время установки,
- или пропустить этот шаг и сохранить placeholder в `/root/.secrets/certbot/cloudflare.ini`.

Минимальные права токена:
- Zone -> DNS -> Edit
- Zone -> Zone -> Read

Если токен не внесён во время установки, позже сделай так:

```bash
nano /root/.secrets/certbot/cloudflare.ini
ssl-renewal doctor
ssl-renewal issue
ssl-renewal deploy
```

Быстрая подсказка:

```bash
ssl-renewal cloudflare-help
```
