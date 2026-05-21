# Security Policy

## Supported build

The supported build in this repository is the government-only Polli-Nation iOS app and FastAPI backend.

## Secret handling

Do not commit:

- `.env`
- `Config/Secrets.xcconfig`
- Apple signing certificates, provisioning profiles, `.p8`, `.p12`, or private keys
- Any backend credentials, SSH passwords, tokens, or provider keys

This project does not require a pollen API key. The backend uses only NOAA/NWS public government endpoints.

## Reporting vulnerabilities

Open a private GitHub security advisory or send the maintainer a private message. Do not file public issues containing credentials, live tokens, or exploit details that would expose users.

## Production deployment guidance

- Use HTTPS for `POLLEN_BACKEND_BASE_URL`.
- Put the backend behind a reverse proxy such as Traefik, Caddy, or Nginx.
- Disable VPS root password login and use SSH keys.
- Keep CORS empty unless a browser-based frontend needs it.
- Set `NWS_USER_AGENT` to a real contact URL or email.
