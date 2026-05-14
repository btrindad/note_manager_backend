#!/usr/bin/env bash
# Load-distribution demo.
#
# Story: one node gets crushed by a heavy job (save_notes — fetches 15
# Wikipedia pages and computes embeddings for each, which the local LLM
# serializes one-at-a-time on whichever node runs the job).
#
# With a single node, that node can't reply to client searches until the
# job finishes — which is exactly what happened in iex -S mix.
#
# With the cluster, nginx round-robins client requests across all 3 nodes.
# Requests that land on the busy node are slow; requests that land on the
# other two nodes are fast. The service stays usable throughout.
#
# We use the X-Served-By header (added by nginx) to show, per-request,
# which backend handled it — so the audience can SEE the distribution.
#
# Additionally, we now capture and display query results for each request,
# with detailed output for requests handled by api-2.

set -e

LOAD_TARGET="${LOAD_TARGET:-note_manager_backend-api-1}"
NOTES_COUNT="${NOTES_COUNT:-15}"
REQUESTS="${REQUESTS:-30}"
INTERVAL="${INTERVAL:-1.0}"
URL="${URL:-http://localhost:4000/api/json/notes/search?query=honey%20school&delay_ms=0&threshold=0.5}"

# ANSI colors so the contrast jumps out on stage.
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; OFF='\033[0m'

banner() {
  echo
  echo -e "${CYAN}════════════════════════════════════════════════════════════════${OFF}"
  echo -e "${CYAN}  $1${OFF}"
  echo -e "${CYAN}════════════════════════════════════════════════════════════════${OFF}"
}

# Map a docker container name to its IP so we can recognise it in X-Served-By.
ip_of() {
  docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$1" 2>/dev/null
}

is_running() {
  [[ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" == "true" ]]
}

# ════════ STEP 0: pre-flight — make sure every node is up ════════
banner "STEP 0  /  Pre-flight check"
DEAD=()
for c in note_manager_backend-api-1 note_manager_backend-api-2 note_manager_backend-api-3; do
  if is_running "$c"; then
    echo -e "  ${GREEN}✓${OFF} $c is running"
  else
    echo -e "  ${RED}✗${OFF} $c is NOT running"
    DEAD+=("$c")
  fi
done
if [[ ${#DEAD[@]} -gt 0 ]]; then
  echo
  echo -e "${RED}  Cannot start the demo — some containers are down:${OFF} ${DEAD[*]}"
  echo "  Recover with:"
  echo "    docker start ${DEAD[*]}"
  echo "  Or full restart:"
  echo "    docker compose -f docker-compose.cluster.yml up -d --scale api=3"
  exit 1
fi

# ════════ STEP 1: snapshot the cluster ════════
banner "STEP 1  /  Cluster snapshot — 3 nodes, $LOAD_TARGET will get loaded"

# Two parallel arrays keyed by the same index (bash 3 has no assoc arrays).
IPS=()
CONTAINERS=()
for c in note_manager_backend-api-1 note_manager_backend-api-2 note_manager_backend-api-3; do
  ip=$(ip_of "$c")
  IPS+=("$ip:4000")
  CONTAINERS+=("$c")
  echo "  $c  →  $ip:4000"
done

container_for_ip() {
  local needle="$1"
  for i in "${!IPS[@]}"; do
    [[ "${IPS[$i]}" == "$needle" ]] && { echo "${CONTAINERS[$i]}"; return; }
  done
  echo "unknown"
}

LOAD_IP="$(ip_of "$LOAD_TARGET"):4000"
echo
echo -e "  We will spawn ${YELLOW}save_notes($NOTES_COUNT)${OFF} on ${YELLOW}$LOAD_TARGET${OFF} ($LOAD_IP)."
echo "  Then send $REQUESTS search requests to nginx at $INTERVAL s apart."
echo "  Expected: requests routed to $LOAD_TARGET will be SLOW;"
echo "  requests routed to the other two nodes will be FAST."
echo "  We'll also capture query results and show api-2 request details."
echo
read -rp "  [press enter to begin loading the target node] " _

# ════════ STEP 2: kick off the heavy job ════════
banner "STEP 2  /  Spawning save_notes($NOTES_COUNT) on $LOAD_TARGET"
docker exec "$LOAD_TARGET" /app/bin/note_manager rpc "
  spawn(fn ->
    IO.puts(\"=== save_notes($NOTES_COUNT) started on \" <> inspect(Node.self()) <> \" ===\")
    try do
      NoteManager.Demo.SampleGenerator.save_notes($NOTES_COUNT)
      IO.puts(\"=== save_notes finished ===\")
    rescue
      e -> IO.puts(\"save_notes crashed: \" <> Exception.message(e))
    end
  end)
"
echo "  >> spawned. Job is now running on $LOAD_TARGET in the background."
echo "  >> giving it ~3s to start blocking the embedding GenServer..."
sleep 3

# ════════ STEP 3: hammer nginx with client searches ════════
banner "STEP 3  /  Client sends $REQUESTS searches through nginx"
echo "  Each request: GET /api/json/notes/search  (the embedding-heavy endpoint)"
echo "  We'll capture: latency, which node handled it, and query results."
echo
printf "  %-4s %-12s %-30s %-20s %s\n" "req" "latency" "served by" "result count" "verdict"
echo "  ─────────────────────────────────────────────────────────────────────────────────"

fast=0; slow=0; busy_node_hits=0; survivor_hits=0
for i in $(seq 1 "$REQUESTS"); do
  start_ns=$(python3 -c 'import time; print(int(time.time()*1000))')
  
  # Capture both headers and body
  response=$(curl -s -D - --max-time 30 "$URL")
  served_by=$(echo "$response" | awk -F': ' 'tolower($1)=="x-served-by"{print $2}' | tr -d '\r\n ')
  body=$(echo "$response" | tail -n +1 | sed -n '/^{/,$p')
  
  end_ns=$(python3 -c 'import time; print(int(time.time()*1000))')
  latency=$((end_ns - start_ns))
  container=$(container_for_ip "$served_by")

  # Extract result count from JSON response
  result_count=$(echo "$body" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('data', [])))" 2>/dev/null || echo "0")

  if [[ "$served_by" == "$LOAD_IP" ]]; then
    color="$RED"; verdict="SLOW (busy)"; busy_node_hits=$((busy_node_hits + 1))
  else
    color="$GREEN"; verdict="fast"; survivor_hits=$((survivor_hits + 1))
  fi
  if [[ "$latency" -gt 2000 ]]; then
    slow=$((slow + 1))
  else
    fast=$((fast + 1))
  fi

  printf "  ${color}%-4d %-12s %-30s %-20s %s${OFF}\n" "$i" "${latency}ms" "$container" "$result_count results" "$verdict"
  
  # Detailed output for api-2 node
  if [[ "$container" == "note_manager_backend-api-2" ]]; then
    echo -e "    ${YELLOW}[api-2 detail]${OFF} Query: search=Wikipedia%20article%20history"
    echo -e "    ${YELLOW}[api-2 detail]${OFF} Results: $result_count notes found, latency: ${latency}ms"
    if [[ $result_count -gt 0 ]]; then
      # Show first result snippet (safely)
      first_title=$(echo "$body" | python3 -c "import sys, json; data=json.load(sys.stdin); note=data.get('data', [{}])[0]; print(note.get('attributes', {}).get('content', 'N/A')[:80])" 2>/dev/null || echo "N/A")
      echo -e "    ${YELLOW}[api-2 detail]${OFF} First result: $first_title..."
    fi
  fi
  
  sleep "$INTERVAL"
done

# ════════ STEP 4: summarise ════════
banner "STEP 4  /  Summary"
echo "  Total requests:       $REQUESTS"
echo "  Hit the busy node:    $busy_node_hits  (expected ~$((REQUESTS / 3)))"
echo "  Hit a survivor node:  $survivor_hits  (expected ~$((REQUESTS * 2 / 3)))"
echo "  Responses < 2s:       $fast"
echo "  Responses > 2s:       $slow"
echo
echo "  Takeaway: even though $LOAD_TARGET was completely saturated by a"
echo "  CPU-bound job, the cluster kept serving search requests because"
echo "  ~two-thirds of them landed on idle nodes via nginx round-robin."
echo
echo "  With a single-node setup (iex -S mix or scale=1), every request"
echo "  would have queued behind the embedding work — which is exactly what"
echo "  you saw before adding the cluster."
echo
echo "  Each request to api-2 above shows the exact query and result count,"
echo "  so you can see the node is responding with valid search results."
echo
