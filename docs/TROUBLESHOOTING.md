# Troubleshooting

## `ssl-renewal doctor` fails on main

Check:

- `certbot` installed
- `dns-cloudflare` plugin installed
- token file exists and has mode `600`
- certificate files exist in configured `CERT_DIR`
- certbot timer exists

## Cloudflare auth failures

Common causes:

- wrong token value
- missing token permissions (`DNS Edit`, `Zone Read`)
- token scoped to wrong zone

## Node deploy failures

Check from main:

```bash
ssh user@node1.example.com "hostname"
```

If SSH fails, fix trust onboarding first.

Check node nginx config:

```bash
ssh user@node1.example.com "nginx -t"
```

## Nginx reload blocked after deploy

`deploy-certs.sh` intentionally requires `nginx -t` before reload. Fix invalid node config and re-run deploy.

## Deferred token setup not completed

If install skipped token entry, update:

```bash
nano /root/.secrets/certbot/cloudflare.ini
ssl-renewal issue
```
