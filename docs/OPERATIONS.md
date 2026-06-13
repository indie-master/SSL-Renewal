# Operations, Upgrade, Rollback

## Normal operations

- Issue/renew now: `ssl-renewal issue`
- Test renewal flow: `ssl-renewal dry-run`
- Push current certs: `ssl-renewal deploy`
- Health check: `ssl-renewal doctor`

## Add a domain after install

1. Edit `/etc/ssl-renewal/config.env`.
2. Add the new domain to `EXTRA_DOMAINS_CSV`. For example:

   ```bash
   PRIMARY_DOMAIN="example.com"
   EXTRA_DOMAINS_CSV="example.net,example.org"
   ```

3. Ensure the Cloudflare token has `Zone -> DNS -> Edit` and `Zone -> Zone -> Read` access to every zone in `PRIMARY_DOMAIN` and `EXTRA_DOMAINS_CSV`.
4. Issue the expanded certificate:

   ```bash
   ssl-renewal issue
   ```

5. Deploy the updated certificate to nodes:

   ```bash
   ssl-renewal deploy
   ```

## Disable local renewals on nodes

From main:

```bash
ssl-renewal disable-node-renew
```

On a specific node:

```bash
/opt/ssl-renewal/node-prep.sh --disable-renew-only
```

## Upgrade process

1. Pull latest repository state.
2. Re-run installer on main and nodes as needed.
3. Validate using `doctor`, `status`, and `dry-run`.

## Rollback

- Keep backup of `/etc/ssl-renewal/config.env` before upgrades.
- For nginx path patch rollbacks, use backups from:
  - `/root/nginx-ssl-renewal-backup-<timestamp>/`
- Restore previous scripts in `/opt/ssl-renewal/` from backup or version control.

## Uninstall (manual)

1. Remove CLI symlink: `/usr/local/bin/ssl-renewal`
2. Remove app files: `/opt/ssl-renewal`
3. Remove config: `/etc/ssl-renewal`
4. Optionally remove certbot deploy hook:
   `/etc/letsencrypt/renewal-hooks/deploy/ssl-renewal-deploy.sh`
