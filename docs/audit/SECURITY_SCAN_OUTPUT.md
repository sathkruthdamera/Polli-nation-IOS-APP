## security_scan.py output

```text
[PASS] required files
[PASS] python compile
[PASS] secret scan
[PASS] government-only provider scan
[PASS] iOS privacy
[PASS] backend hardening
[PASS] URL validator logic

Summary: 7 checks run, 0 findings
```

## backend runtime smoke

```text
health_status 200
sources_status 200
allowlisted_nws_url https://api.weather.gov/gridpoints/HGX/65,97
blocked_url_ok 502
blocked_url_ok 502
blocked_url_ok 502
rate_limit_request_1 200
rate_limit_request_2 429
rate_limit_request_3 429
```
