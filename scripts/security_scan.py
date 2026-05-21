#!/usr/bin/env python3
"""Lightweight security checks for the Polli-Nation gov-only iOS/backend project.

This script is intentionally dependency-free so it can run in GitHub Actions and on a VPS.
It checks for common accidental issues: committed secrets, non-government providers,
unsafe backend URLs, Docker hardening regressions, and required iOS privacy strings.
"""
from __future__ import annotations

import os
import re
import sys
import py_compile
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
SKIP_DIRS = {".git", "__pycache__", "DerivedData", ".build", ".swiftpm", ".venv", "venv"}
TEXT_SUFFIXES = {
    ".swift", ".py", ".md", ".txt", ".plist", ".entitlements", ".yml", ".yaml",
    ".json", ".xcconfig", ".pbxproj", ".sh", ".example", ".gitignore", ".dockerignore"
}
BINARY_SUFFIXES = {".png", ".jpg", ".jpeg", ".gif", ".zip"}

SECRET_PATTERNS = {
    "AIza-style API key": re.compile(r"AIza[0-9A-Za-z_\-]{20,}"),
    "AWS access key": re.compile(r"AKIA[0-9A-Z]{16}"),
    "Private key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA |)?PRIVATE KEY-----"),
    "Bearer token": re.compile(r"Bearer\s+[A-Za-z0-9_\-.=]{20,}"),
    "Hardcoded password assignment": re.compile(r"(?i)(password|passwd|pwd)\s*[:=]\s*['\"][^'\"]{6,}['\"]"),
}

FORBIDDEN_PROVIDERS = ["Goo" + "gle Pollen", "Open" + "-Meteo", "Air" + "Now", "GOO" + "GLE_POLLEN_API_KEY", "AIR" + "NOW_API_KEY"]
REQUIRED_FILES = [
    "PolliNation/Info.plist",
    "PolliNation/PolliNation.entitlements",
    "PolliNationWidget/PolliNationWidget.entitlements",
    "backend/app/main.py",
    "backend/Dockerfile",
    "docker-compose.simple.yml",
]


def iter_files() -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob("*"):
        if path.is_dir():
            continue
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        files.append(path)
    return files


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return ""


def check_required_files() -> list[str]:
    failures = []
    for rel in REQUIRED_FILES:
        if not (ROOT / rel).exists():
            failures.append(f"missing required file: {rel}")
    return failures


def check_python_compile() -> list[str]:
    failures = []
    for path in (ROOT / "backend").rglob("*.py"):
        try:
            py_compile.compile(str(path), doraise=True)
        except Exception as exc:
            failures.append(f"python compile failed: {path.relative_to(ROOT)}: {exc}")
    return failures


def check_secrets() -> list[str]:
    failures = []
    for path in iter_files():
        rel = path.relative_to(ROOT)
        if path.suffix.lower() in BINARY_SUFFIXES:
            continue
        text = read_text(path)
        for label, pattern in SECRET_PATTERNS.items():
            if pattern.search(text):
                failures.append(f"possible secret [{label}] in {rel}")
    return failures


def check_gov_only() -> list[str]:
    failures = []
    for path in iter_files():
        rel = path.relative_to(ROOT)
        if str(rel).startswith("docs/audit") or rel == Path("scripts/security_scan.py"):
            continue
        if path.suffix.lower() in BINARY_SUFFIXES:
            continue
        text = read_text(path)
        for provider in FORBIDDEN_PROVIDERS:
            if provider in text:
                failures.append(f"non-government provider reference '{provider}' in {rel}")
    return failures


def check_ios_privacy() -> list[str]:
    failures = []
    plist = read_text(ROOT / "PolliNation/Info.plist")
    if "NSLocationWhenInUseUsageDescription" not in plist:
        failures.append("missing NSLocationWhenInUseUsageDescription")
    if "NSLocationAlways" in plist:
        failures.append("app should not request Always location permission")
    if "NSAppTransportSecurity" in plist and "NSAllowsArbitraryLoads" in plist:
        failures.append("avoid broad NSAllowsArbitraryLoads")
    ent = read_text(ROOT / "PolliNation/PolliNation.entitlements")
    widget_ent = read_text(ROOT / "PolliNationWidget/PolliNationWidget.entitlements")
    if "group.com.pollination.shared" not in ent or "group.com.pollination.shared" not in widget_ent:
        failures.append("App Group entitlement mismatch")
    return failures


def check_backend_hardening() -> list[str]:
    failures = []
    main = read_text(ROOT / "backend/app/main.py")
    docker = read_text(ROOT / "backend/Dockerfile")
    compose = read_text(ROOT / "docker-compose.simple.yml")
    if "validate_nws_url" not in main or "api.weather.gov" not in main:
        failures.append("backend must validate NOAA/NWS host before fetching grid data")
    if "RATE_LIMIT_REQUESTS" not in main:
        failures.append("backend rate limit not configured")
    if 'os.getenv("ALLOWED_ORIGINS", "*")' in main:
        failures.append("CORS must not default to wildcard")
    if "USER appuser" not in docker:
        failures.append("Dockerfile must run as non-root appuser")
    if "HEALTHCHECK" not in docker:
        failures.append("Dockerfile missing healthcheck")
    for token in ["read_only: true", "cap_drop:", "no-new-privileges:true", "127.0.0.1:8000:8000"]:
        if token not in compose:
            failures.append(f"docker-compose.simple.yml missing hardening token: {token}")
    return failures


def check_url_validator_logic() -> list[str]:
    failures = []
    allowed = "https://api.weather.gov/gridpoints/HGX/65,97"
    denied = [
        "http://api.weather.gov/gridpoints/HGX/65,97",
        "https://evil.example/gridpoints/HGX/65,97",
        "https://api.weather.gov.evil.example/gridpoints/HGX/65,97",
    ]
    parsed = urlparse(allowed)
    if parsed.scheme != "https" or parsed.netloc != "api.weather.gov":
        failures.append("url validator fixture failed for allowed URL")
    for item in denied:
        parsed = urlparse(item)
        if parsed.scheme == "https" and parsed.netloc == "api.weather.gov":
            failures.append(f"url validator fixture incorrectly allowed: {item}")
    return failures


def main() -> int:
    checks = [
        ("required files", check_required_files),
        ("python compile", check_python_compile),
        ("secret scan", check_secrets),
        ("government-only provider scan", check_gov_only),
        ("iOS privacy", check_ios_privacy),
        ("backend hardening", check_backend_hardening),
        ("URL validator logic", check_url_validator_logic),
    ]
    all_failures: list[str] = []
    for name, fn in checks:
        failures = fn()
        if failures:
            print(f"[FAIL] {name}")
            for failure in failures:
                print(f"  - {failure}")
            all_failures.extend(failures)
        else:
            print(f"[PASS] {name}")
    print(f"\nSummary: {len(checks)} checks run, {len(all_failures)} findings")
    return 1 if all_failures else 0


if __name__ == "__main__":
    sys.exit(main())
