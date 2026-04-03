# Cloudflare Token Setup

## Where to create token

1. Sign in to Cloudflare.
2. Open **My Profile** -> **API Tokens**.
3. Click **Create Token**.
4. Use template **Edit zone DNS** or build custom token.

## Minimum permissions

- `Zone -> DNS -> Edit`
- `Zone -> Zone -> Read`

## Zone scope

Set `Zone Resources` to your specific zone (for example `example.com`).

## File location on main server

```bash
/root/.secrets/certbot/cloudflare.ini
```

Expected content:

```ini
dns_cloudflare_api_token = <YOUR_TOKEN>
```

Permissions:

```bash
chmod 600 /root/.secrets/certbot/cloudflare.ini
```

## Validate token

```bash
ssl-renewal doctor
ssl-renewal issue
```

If `issue` succeeds with DNS challenge, token is valid.
