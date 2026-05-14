#!/usr/bin/env bash
# Continuous traffic generator. Run in a side terminal while chaos_demo.sh
# kills a node — audience sees that the failure is invisible to the client.

URL="${URL:-http://localhost:4000/api/json/swaggerui}"
INTERVAL="${INTERVAL:-0.5}"

ok=0
fail=0
i=0

trap 'echo; echo "totals: ok=$ok fail=$fail"; exit 0' INT

while true; do
  i=$((i + 1))
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$URL")
  ts=$(date +%H:%M:%S)
  if [[ "$code" == "200" ]]; then
    ok=$((ok + 1))
    printf "  %s  req#%-4d  HTTP %s  ok=%d fail=%d\n" "$ts" "$i" "$code" "$ok" "$fail"
  else
    fail=$((fail + 1))
    printf "  %s  req#%-4d  HTTP %s  ok=%d fail=%d  <-- FAILURE\n" "$ts" "$i" "$code" "$ok" "$fail"
  fi
  sleep "$INTERVAL"
done
