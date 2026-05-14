#!/usr/bin/env bash
# Quick read-only snapshot of the BEAM cluster + Horde state.
# Run any time during the demo to show "where is everything now."

set -e

API="${API_CONTAINER:-note_manager_backend-api-1}"

echo "==================================================="
echo "  Docker containers"
echo "==================================================="
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' \
  | grep -E 'note_manager_backend|NAMES'

echo
echo "==================================================="
echo "  BEAM cluster (asked from $API)"
echo "==================================================="
docker exec "$API" /app/bin/note_manager rpc '
  IO.inspect(Node.self(), label: "self")
  IO.inspect(Node.list(), label: "peers")
  IO.puts("")
  IO.puts("Horde Registry members:")
  for m <- Horde.Cluster.members(NoteManager.Queries.Registry), do: IO.inspect(m)
  IO.puts("")
  IO.puts("Horde QuerySupervisor members:")
  for m <- Horde.Cluster.members(NoteManager.Queries.QuerySupervisor), do: IO.inspect(m)
  IO.puts("")
  active = NoteManager.Queries.Registry |> Horde.Registry.select([{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}])
  IO.puts("Active QueryServers (#{length(active)}):")
  for {session, pid} <- active, do: IO.puts("  #{session} -> #{inspect(pid)} on #{:erlang.node(pid)}")
'
