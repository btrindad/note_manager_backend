defmodule NoteManager.Queries.QueryServer do
  @moduledoc """
  Per-session GenServer that owns the lifecycle of an in-flight knowledge-base
  query. Decoupled from the WebSocket: the socket may drop and rejoin freely
  while this process keeps running and accumulates the result.

  State transitions are broadcast on the `Phoenix.PubSub` topic
  `"query:<session_token>"` so any channel subscriber (current or future) can
  pick them up. A rejoining client gets the current snapshot via `snapshot/1`
  and replays from there.
  """

  use GenServer, restart: :transient

  alias Phoenix.PubSub

  @registry NoteManager.Queries.Registry
  @pubsub NoteManager.PubSub
  @idle_timeout_ms :timer.minutes(10)

  defstruct [
    :session_token,
    :status,
    :query,
    :results,
    :error,
    :started_at,
    :finished_at,
    :task_ref
  ]

  # --- Public API ---

  def start_link(session_token) when is_binary(session_token) do
    GenServer.start_link(__MODULE__, session_token, name: via(session_token))
  end

  @doc """
  Look up or start a QueryServer for the given session token.
  """
  def find_or_start(session_token) do
    case Registry.lookup(@registry, session_token) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        DynamicSupervisor.start_child(
          NoteManager.Queries.QuerySupervisor,
          {__MODULE__, session_token}
        )
        |> case do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          other -> other
        end
    end
  end

  @doc """
  Kick off a new search. Supersedes any in-flight search for the same session.

  `delay_ms` is a demo knob that makes the task sleep before doing the real
  search — useful for testing fault tolerance (close tab, reopen mid-flight).
  """
  def search(session_token, query, delay_ms \\ 0) when is_binary(query) do
    with {:ok, pid} <- find_or_start(session_token) do
      GenServer.cast(pid, {:search, query, delay_ms})
      {:ok, pid}
    end
  end

  @doc """
  Get the current state as a map suitable for pushing to a client on join.
  """
  def snapshot(session_token) do
    case Registry.lookup(@registry, session_token) do
      [{pid, _}] -> GenServer.call(pid, :snapshot)
      [] -> %{status: "idle", query: nil, results: nil, error: nil}
    end
  end

  def topic(session_token), do: "query:#{session_token}"

  # --- GenServer callbacks ---

  @impl true
  def init(session_token) do
    state = %__MODULE__{
      session_token: session_token,
      status: :idle,
      results: nil
    }

    {:ok, state, @idle_timeout_ms}
  end

  @impl true
  def handle_cast({:search, query, delay_ms}, state) do
    # If a task is in flight, drop it on the floor — the new query supersedes.
    state =
      case state.task_ref do
        nil -> state
        ref ->
          Process.demonitor(ref, [:flush])
          %{state | task_ref: nil}
      end

    task =
      Task.Supervisor.async_nolink(
        NoteManager.Queries.TaskSupervisor,
        fn -> run_query(query, delay_ms) end
      )

    new_state = %{
      state
      | status: :running,
        query: query,
        results: nil,
        error: nil,
        started_at: System.system_time(:millisecond),
        finished_at: nil,
        task_ref: task.ref
    }

    broadcast(new_state)
    {:noreply, new_state, @idle_timeout_ms}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, to_payload(state), state, @idle_timeout_ms}
  end

  @impl true
  def handle_info({ref, result}, %{task_ref: ref} = state) do
    Process.demonitor(ref, [:flush])

    new_state =
      case result do
        {:ok, results} ->
          %{
            state
            | status: :complete,
              results: results,
              finished_at: System.system_time(:millisecond),
              task_ref: nil
          }

        {:error, reason} ->
          %{
            state
            | status: :error,
              error: inspect(reason),
              finished_at: System.system_time(:millisecond),
              task_ref: nil
          }
      end

    broadcast(new_state)
    {:noreply, new_state, @idle_timeout_ms}
  end

  # Stale task result (a search was superseded). Ignore.
  def handle_info({_ref, _result}, state) do
    {:noreply, state, @idle_timeout_ms}
  end

  # Task crashed.
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{task_ref: ref} = state) do
    new_state = %{
      state
      | status: :error,
        error: "task crashed: #{inspect(reason)}",
        finished_at: System.system_time(:millisecond),
        task_ref: nil
    }

    broadcast(new_state)
    {:noreply, new_state, @idle_timeout_ms}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state, @idle_timeout_ms}
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  # --- Internals ---

  defp via(session_token), do: {:via, Registry, {@registry, session_token}}

  defp run_query(query, delay_ms) do
    if is_integer(delay_ms) and delay_ms > 0, do: Process.sleep(delay_ms)

    case NoteManager.KnowledgeBase.search(%{query: query}) do
      {:ok, page} -> {:ok, serialize_page(page)}
      %Ash.Page.Offset{} = page -> {:ok, serialize_page(page)}
      results when is_list(results) -> {:ok, Enum.map(results, &serialize_note/1)}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp serialize_page(%{results: results}), do: Enum.map(results, &serialize_note/1)
  defp serialize_page(results) when is_list(results), do: Enum.map(results, &serialize_note/1)

  defp serialize_note(%{id: id, content: content, inserted_at: inserted_at}) do
    %{id: id, content: content, inserted_at: inserted_at}
  end

  defp serialize_note(other), do: %{raw: inspect(other)}

  defp broadcast(state) do
    PubSub.broadcast(@pubsub, topic(state.session_token), {:query_state, to_payload(state)})
  end

  defp to_payload(state) do
    %{
      status: Atom.to_string(state.status),
      query: state.query,
      results: state.results,
      error: state.error,
      started_at: state.started_at,
      finished_at: state.finished_at
    }
  end
end
