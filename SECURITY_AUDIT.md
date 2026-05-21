# Polli-Nation Security and Pentest Check Report

## Scope

Checked the current gov-only Polli-Nation iOS app, WidgetKit extension, FastAPI backend, Docker deployment files, and preview artifacts.

## Result

Status: **PASS with hardening applied**

The current repository version contains only the government-data provider path. It does not include paid/non-government provider code, committed `.env` files, pasted credentials, or provider API keys.

## Security changes applied before publishing

- Removed wildcard CORS default. Backend CORS is disabled unless `ALLOWED_ORIGINS` is explicitly configured.
- Added NOAA/NWS forecast-grid URL allowlist validation so backend follows only `https://api.weather.gov/...` URLs returned by the government API.
- Added lightweight in-memory rate limiting for backend API routes.
- Hardened Docker runtime:
  - non-root `appuser`
  - read-only container filesystem
  - `/tmp` tmpfs
  - all Linux capabilities dropped
  - `no-new-privileges:true`
  - healthcheck added
  - local-only port binding in `docker-compose.simple.yml`
- Added `.gitignore` and `.dockerignore` for local secrets, signing assets, Xcode user files, Python caches, and runtime files.
- Added dependency-free `scripts/security_scan.py` and GitHub Actions workflow.
- Added `SECURITY.md` with production security guidance.

## Checks performed

| Area | Check | Status |
|---|---|---|
| Secrets | API-key, token, private-key, password-pattern scan across text files | PASS |
| Known pasted secrets | Exact-value scan for previously shared sensitive values | PASS |
| Provider boundary | Verified no non-government provider implementation remains | PASS |
| Backend syntax | Python compile check | PASS |
| Backend SSRF control | NOAA/NWS forecast URL host allowlist validation | PASS |
| Backend rate limit | API route rate limiting smoke test | PASS |
| Backend CORS | No wildcard default CORS | PASS |
| Docker hardening | Non-root, read-only, dropped caps, no-new-privileges, healthcheck | PASS |
| iOS privacy | Uses When-In-Use location permission only | PASS |
| iOS network posture | No broad App Transport Security bypass | PASS |
| Widget privacy | Widget reads only shared report data from App Group | PASS |
| CI | GitHub Actions security check workflow added | PASS |

## Local scan output

See `docs/audit/SECURITY_SCAN_OUTPUT.md`.

## Limitations

- Full Xcode build/signing was not run in this Linux environment because Xcode is unavailable here.
- Live NOAA/NWS endpoint integration depends on internet access and U.S. coordinate coverage.
- This is a safe local application/backend assessment. No destructive network testing was performed against the VPS.

## Production recommendations

- Rotate any VPS password or provider key that was shared in chat before using this publicly.
- Configure HTTPS before setting `POLLEN_BACKEND_BASE_URL` in Xcode.
- Use a non-root VPS deploy user with SSH keys.
- Keep `ALLOWED_ORIGINS` empty unless a browser frontend needs CORS.
- Add branch protection and require the `Security Checks` GitHub Action before merging future changes.
