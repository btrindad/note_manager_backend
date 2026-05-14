#!/usr/bin/env bash
# Scripted failover demo. Designed to be paste-able into a live presentation.
#
# Flow:
#   1. Show the 3-node BEAM cluster.
#   2. Start a QueryServer keyed by a session token.
#   3. Show which node owns it.
#   4. Kill that node.
#   5. Show that Horde respawned the QueryServer on a surviving node.
#   6. Restart the killed node and show the cluster re-form.

set -e

SESSION="${SESSION:-demo-session-$(date +%s)}"
ALL_API=(note_manager_backend-api-1 note_manager_backend-api-2 note_manager_backend-api-3)
DRIVER="${ALL_API[0]}"

pause() { echo; read -rp "  [press enter to continue] " _; echo; }

banner() {
  echo
  echo "==================================================="
  echo "  $1"
  echo "==================================================="
}

rpc() {
  docker exec "$DRIVER" /app/bin/note_manager rpc "$1"
}

# Find the container whose container-IP matches the given Erlang node IP.
container_for_node() {
  local node="$1"
  local ip
  ip=$(echo "$node" | sed -E 's/.*@(.+)/\1/')
  for c in "${ALL_API[@]}"; do
    local cip
    cip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$c" 2>/dev/null)
    if [[ "$cip" == "$ip" ]]; then echo "$c"; return; fi
  done
  echo ""
}

# ---------- 1. show cluster ----------
banner "STEP 1  /  3-node BEAM cluster"
rpc 'IO.inspect({Node.self(), Node.list()}, label: "cluster")'
pause

# ---------- 2. start a QueryServer ----------
banner "STEP 2  /  Start QueryServer for session: $SESSION"
OUT=$(rpc "
  {:ok, pid} = NoteManager.Queries.QueryServer.find_or_start(\"$SESSION\")
  IO.inspect({pid, :erlang.node(pid)}, label: \"owner\")
")
echo "$OUT"
OWNER_NODE=$(echo "$OUT" | grep -oE 'note_manager@[0-9.]+' | head -1)
TARGET=$(container_for_node "$OWNER_NODE")
echo
echo ">> Owner node: $OWNER_NODE"
echo ">> That maps to docker container: $TARGET"
pause

# ---------- 3. KILL the owning node ----------
if [[ -z "$TARGET" ]]; then
  echo "Could not map node to container. Bailing."
  exit 1
fi

banner "STEP 3  /  docker kill $TARGET"
docker kill "$TARGET"
echo ">> killed at $(date +%H:%M:%S)"

# If the driver itself was killed, switch to a survivor.
if [[ "$TARGET" == "$DRIVER" ]]; then
  for c in "${ALL_API[@]}"; do
    if [[ "$c" != "$TARGET" ]] && docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null | grep -q true; then
      DRIVER="$c"; break
    fi
  done
  echo ">> switched driver to $DRIVER"
fi

sleep 4

# ---------- 4. show Horde respawned it ----------
banner "STEP 4  /  Horde respawned the QueryServer"
rpc "
  IO.inspect(Node.list(), label: \"peers_after_kill\")
  {:ok, pid} = NoteManager.Queries.QueryServer.find_or_start(\"$SESSION\")
  IO.inspect({pid, :erlang.node(pid)}, label: \"owner_now\")
"
pause

# ---------- 5. restart killed node ----------
banner "STEP 5  /  Restart $TARGET, cluster heals"
docker start "$TARGET"
echo ">> waiting for it to rejoin..."
sleep 12
rpc 'IO.inspect(Node.list(), label: "peers_restored")'
echo
echo ">> demo complete."
