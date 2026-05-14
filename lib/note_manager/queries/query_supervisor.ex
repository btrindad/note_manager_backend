defmodule NoteManager.Queries.QuerySupervisor do
  @moduledoc """
  Cluster-aware DynamicSupervisor (via Horde) for `QueryServer` processes.

  One QueryServer is started lazily per session token by
  `QueryServer.find_or_start/1`. Horde redistributes child processes across
  cluster members when nodes join or leave, so a query keeps running even if
  the node that originally owned it crashes.
  """

  def child_spec(_arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end

  def start_link do
    Horde.DynamicSupervisor.start_link(
      name: __MODULE__,
      strategy: :one_for_one,
      distribution_strategy: Horde.UniformDistribution,
      members: :auto,
      process_redistribution: :active
    )
  end
end
