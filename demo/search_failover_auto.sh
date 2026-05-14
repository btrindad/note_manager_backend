#!/usr/bin/env bash
set -euo pipefail

# Interactive automatic search-failover demo.
#
# Usage: run the script, type the search query when prompted, then watch the
# demo run: it starts a slow search, kills the node running that session,
# waits for Horde to respawn the session on a survivor, resubmits the search
# and prints results. The killed container is restarted at the end.

SESSION="search-${USER:-demo}-$(date +%s)"
DELAY_MS=${DELAY_MS:-15000}   # how long the initial search should run (ms)
KILL_AFTER_SEC=${KILL_AFTER_SEC:-3} # how many seconds to wait before killing owner

ALL_API=(note_manager_backend-api-1 note_manager_backend-api-2 note_manager_backend-api-3)

pick_driver() {
  for c in "${ALL_API[@]}"; do
    if docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null | grep -q true; then
      echo "$c"; return
    fi
  done
}

rpc() {
  local driver="$1"; shift
  docker exec "$driver" /app/bin/note_manager rpc "$1"
}

escape_elixir_string() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  printf '%s' "$value"
}

container_for_node() {
  local node="$1"
  local ip
  ip=$(echo "$node" | sed -E 's/.*@(.+)/\1/')
  for c in "${ALL_API[@]}"; do
    local cip
    cip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$c" 2>/dev/null)
    [[ "$cip" == "$ip" ]] && { echo "$c"; return; }
  done
}

echo
echo "Interactive automatic search failover demo"
echo "Session id will be: $SESSION"
echo
read -rp "Type your search query: " QUERY
echo
echo "Using query: '$QUERY'"

DRIVER=$(pick_driver)
if [[ -z "$DRIVER" ]]; then
  echo "No running API containers found (expected names: ${ALL_API[*]})." >&2
  exit 1
fi

echo "Using driver container: $DRIVER"

echo "\n>>> Starting a slow search (delay ${DELAY_MS} ms) on session $SESSION"
SESSION_ESCAPED=$(escape_elixir_string "$SESSION")
QUERY_ESCAPED=$(escape_elixir_string "$QUERY")
START_SEARCH_CODE=$(cat <<EOF
{:ok, pid} = NoteManager.Queries.QueryServer.search("$SESSION_ESCAPED", "$QUERY_ESCAPED", $DELAY_MS, 0.6)
IO.inspect({pid, :erlang.node(pid)}, label: "owner")
EOF
)
OUT=$(rpc "$DRIVER" "$START_SEARCH_CODE")
echo "$OUT"

OWNER_NODE=$(echo "$OUT" | grep -oE 'note_manager@[0-9.]+' | head -1 || true)
if [[ -z "$OWNER_NODE" ]]; then
  echo "Could not determine owner node from RPC output. Aborting." >&2
  exit 1
fi
TARGET=$(container_for_node "$OWNER_NODE")
echo
echo "QueryServer owner BEAM node: $OWNER_NODE"
echo "Owner container: ${TARGET:-(unknown)}"

# choose a witness different from the target
WITNESS=""
for c in "${ALL_API[@]}"; do
  [[ "$c" != "$TARGET" ]] && { WITNESS="$c"; break; }
done
if [[ -z "$WITNESS" ]]; then
  echo "No witness container available (need at least 2 running API containers)." >&2
  exit 1
fi
echo "Witness container: $WITNESS"

echo "\n>>> Waiting ${KILL_AFTER_SEC}s before killing owner to ensure search is in-flight..."
sleep $KILL_AFTER_SEC

echo "\n>>> Killing owner container: $TARGET"
docker kill "$TARGET"
echo "Killed $TARGET at $(date +%T)"

# if our driver was the killed container, switch to witness
if [[ "$DRIVER" == "$TARGET" ]]; then
  DRIVER="$WITNESS"
  echo "driver switched to $DRIVER because owner was killed"
fi

echo "\n>>> Sleep a few seconds for Horde to detect the failure and respawn..."
sleep 4

echo "\n>>> From witness ($WITNESS) calling find_or_start for same session"
FIND_OR_START_CODE=$(cat <<EOF
IO.inspect(Node.list(), label: "surviving_peers")
{:ok, pid} = NoteManager.Queries.QueryServer.find_or_start("$SESSION_ESCAPED")
IO.inspect({pid, :erlang.node(pid)}, label: "new owner (different node, same session)")
IO.inspect(NoteManager.Queries.QueryServer.snapshot("$SESSION_ESCAPED"), label: "snapshot")
EOF
)
rpc "$WITNESS" "$FIND_OR_START_CODE"

echo "\n>>> Resubmitting search from witness (no artificial delay)"
RESUBMIT_CODE=$(cat <<EOF
{:ok, pid} = NoteManager.Queries.QueryServer.search("$SESSION_ESCAPED", "$QUERY_ESCAPED", 0, 0.6)
IO.inspect({pid, :erlang.node(pid)}, label: "executor")
EOF
)
rpc "$WITNESS" "$RESUBMIT_CODE"

echo "\n>>> Waiting a moment for the resumed search to finish..."
sleep 3

echo "\n>>> Snapshot & top hits from witness"
SNAPSHOT_CODE=$(cat <<EOF
snap = NoteManager.Queries.QueryServer.snapshot("$SESSION_ESCAPED")
IO.puts("")
IO.puts("  status:      #{snap.status}")
IO.puts("  query:       #{snap.query}")
IO.puts("  result count: #{length(snap.results || [])}")
IO.puts("  duration:    #{snap.finished_at - snap.started_at} ms")
IO.puts("")
IO.puts("  top hits:")
for r <- Enum.take(snap.results || [], 4) do
  snippet = r.content |> String.slice(0, 60) |> String.replace(~r/\s+/, " ") |> String.trim_leading("# ")
  IO.puts("    - " <> snippet)
end
EOF
)
rpc "$WITNESS" "$SNAPSHOT_CODE"

echo "\n>>> Restarting previously killed container: $TARGET"
docker start "$TARGET"
echo "Waiting for rejoin..."
sleep 12
REJOIN_CODE=$(cat <<EOF
IO.inspect(Node.list(), label: "peers_restored")
EOF
)
rpc "$WITNESS" "$REJOIN_CODE"

echo "\n>>> Demo complete. Session: $SESSION"
