# Cloudflare Token Setup

## Where to create token

1. Sign in to Cloudflare.
2. Open **My Profile** -> **API Tokens**.
3. Click **Create Token**.
4. Use template **Edit zone DNS** or build custom token.

## Minimum permissions

The token must grant these permissions to every zone used by SSL Renewal:

- `Zone -> DNS -> Edit`
- `Zone -> Zone -> Read`

## Zone scope

Set `Zone Resources` to all zones that appear in `PRIMARY_DOMAIN` and `EXTRA_DOMAINS_CSV`. All domains in the certificate must be hosted in Cloudflare or otherwise accessible through the same token.

Example multi-domain certificate configuration:

```bash
PRIMARY_DOMAIN="example.com"
EXTRA_DOMAINS_CSV="example.net,example.org"
REGION_WILDCARDS_CSV="de,sk,us"
```

For this example, the same token needs DNS Edit and Zone Read access to:

- `example.com`
- `example.net`
- `example.org`

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

If `issue` succeeds with DNS challenge, token is valid for every requested zone.
