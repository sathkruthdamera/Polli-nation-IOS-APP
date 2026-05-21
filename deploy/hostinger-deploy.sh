#!/usr/bin/env bash
set -euo pipefail

SERVER_HOST="${SERVER_HOST:-srv1663121.hstgr.cloud}"
SERVER_USER="${SERVER_USER:-root}"
REMOTE_DIR="${REMOTE_DIR:-/opt/pollination}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.simple.yml}"

if [[ ! -f .env ]]; then
  echo "Missing .env. Copy .env.example to .env. Government-only mode needs no API keys." >&2
  exit 1
fi

ssh "${SERVER_USER}@${SERVER_HOST}" "mkdir -p ${REMOTE_DIR}"
rsync -az --delete \
  --exclude 'PolliNation.xcodeproj' \
  --exclude 'PolliNation' \
  --exclude 'PolliNationWidget' \
  backend docker-compose.simple.yml docker-compose.traefik.yml .env \
  "${SERVER_USER}@${SERVER_HOST}:${REMOTE_DIR}/"
ssh "${SERVER_USER}@${SERVER_HOST}" "cd ${REMOTE_DIR} && docker compose -f ${COMPOSE_FILE} up -d --build && docker compose -f ${COMPOSE_FILE} ps"
