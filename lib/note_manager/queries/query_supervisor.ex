defmodule NoteManager.Queries.QuerySupervisor do
  @moduledoc """
  DynamicSupervisor for `NoteManager.Queries.QueryServer` processes.

  One QueryServer is started lazily per session token by
  `QueryServer.find_or_start/1` and terminates itself after an idle timeout.
  """

  use DynamicSupervisor

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
