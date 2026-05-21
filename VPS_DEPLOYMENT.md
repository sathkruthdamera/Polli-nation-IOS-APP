# Hostinger VPS Deployment

This backend is government-only. It needs no paid API key and no non-government fallback provider.

## Security defaults

- The Docker container runs as a non-root app user.
- The container filesystem is read-only with `/tmp` mounted as tmpfs.
- Linux capabilities are dropped and `no-new-privileges` is enabled.
- `docker-compose.simple.yml` binds to `127.0.0.1:8000` by default. Put Nginx/Traefik/Caddy in front of it for HTTPS.
- CORS is disabled by default because the native iOS app does not need browser CORS.
- A lightweight in-memory rate limit protects `/api/*` routes.

## Configure

```bash
cp .env.example .env
nano .env
```

Expected `.env`:

```bash
NWS_USER_AGENT=PolliNation/1.0 (https://your-domain.example; your-email@example.com)
CACHE_TTL_SECONDS=3600
RATE_LIMIT_REQUESTS=120
RATE_LIMIT_WINDOW_SECONDS=60
ALLOWED_ORIGINS=
```

Use a real contact URL or email in `NWS_USER_AGENT`.

## Deploy with local-only backend port

```bash
SERVER_HOST=srv1663121.hstgr.cloud \
SERVER_USER=root \
COMPOSE_FILE=docker-compose.simple.yml \
./deploy/hostinger-deploy.sh
```

Then place a TLS reverse proxy in front of `127.0.0.1:8000` and set the iOS build setting to the HTTPS URL:

```bash
POLLEN_BACKEND_BASE_URL = https://your-domain.example
```

## Deploy behind Traefik

Set this in `.env`:

```bash
API_HOST=your-domain.example
```

Then run:

```bash
SERVER_HOST=srv1663121.hstgr.cloud \
SERVER_USER=root \
COMPOSE_FILE=docker-compose.traefik.yml \
./deploy/hostinger-deploy.sh
```

## Verify on the server

```bash
curl http://127.0.0.1:8000/health
curl 'http://127.0.0.1:8000/api/pollen?lat=39.8283&lon=-98.5795&name=Current%20Location&subtitle=United%20States'
```

If SSH is blocked, enable SSH in Hostinger hPanel or run the deploy commands from the Hostinger browser terminal.

## Production checklist

- Rotate any VPS password that was shared in chat.
- Disable root password login after creating a sudo deploy user and SSH key.
- Use HTTPS for `POLLEN_BACKEND_BASE_URL`; iOS App Transport Security expects secure transport.
- Keep `.env` and `Config/Secrets.xcconfig` out of Git.
