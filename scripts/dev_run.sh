#!/usr/bin/env bash
#
# Build Panergo against the backend running on this Mac.
#
# The address is resolved here, at build time, rather than by the phone at
# runtime. A .local name would be tidier, but iOS only resolves one after the
# user grants the local-network permission, and when that prompt does not appear
# every request fails silently. Resolving on the Mac sidesteps the gate entirely
# while still surviving the laptop moving networks — rerun this and the new
# address is baked in.
set -euo pipefail

PORT="${PANERGO_PORT:-8080}"

# The interface actually carrying traffic, not a guess at en0.
IP="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}' \
      | xargs -I{} ipconfig getifaddr {} 2>/dev/null || true)"
[ -z "$IP" ] && IP="$(ipconfig getifaddr en0 2>/dev/null || true)"

if [ -z "$IP" ]; then
  echo "No LAN address found — is this Mac on Wi-Fi?" >&2
  exit 1
fi

BASE="http://$IP:$PORT"

# Fail before a 60-second build rather than after it.
if ! curl -sf -o /dev/null --max-time 5 "$BASE/actuator/health"; then
  echo "Backend is not answering at $BASE" >&2
  echo "Start it with: docker compose up -d" >&2
  exit 1
fi

echo "Backend: $BASE"

# Default to `run`; `build` needs a target, so `dev_run.sh build` means ios.
if [ $# -eq 0 ]; then
  set -- run
elif [ "$1" = "build" ] && [ $# -eq 1 ]; then
  set -- build ios --release
fi

# The shared links point at the same Mac while panergo.cm is not serving, so
# a link copied out of the app opens in a browser instead of going nowhere.
# Override with PANERGO_SHARE_BASE_URL once the domain is live.
SHARE="${PANERGO_SHARE_BASE_URL:-$BASE}"
echo "Share links: $SHARE"

exec flutter "$@" \
  --dart-define=PANERGO_API_BASE_URL="$BASE" \
  --dart-define=PANERGO_SHARE_BASE_URL="$SHARE"
