defmodule NoteManagerWeb.QueryChannel do
  @moduledoc """
  Channel for knowledge-base queries.

  Topic: `query:<session_token>` — must match the socket's assigned token.
  On join, the channel subscribes to the corresponding PubSub topic and pushes
  the current snapshot from `QueryServer`. Subsequent state changes arrive via
  PubSub and are forwarded to the client.

  Inbound events:
    - `"search"` with `%{"query" => string}` → kicks off (or supersedes) a query
    - `"cancel"` → drops any in-flight query

  Outbound events:
    - `"state"` with the current query state payload
  """

  use NoteManagerWeb, :channel

  alias NoteManager.Queries.QueryServer

  @impl true
  def join("query:" <> token, _params, socket) do
    if token == socket.assigns.session_token do
      send(self(), :after_join)
      {:ok, assign(socket, :session_token, token)}
    else
      {:error, %{reason: "token mismatch"}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    token = socket.assigns.session_token
    Phoenix.PubSub.subscribe(NoteManager.PubSub, QueryServer.topic(token))
    push(socket, "state", QueryServer.snapshot(token))
    {:noreply, socket}
  end

  def handle_info({:query_state, payload}, socket) do
    push(socket, "state", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("search", %{"query" => query} = params, socket) when is_binary(query) do
    delay_ms = clamp_delay(params["delay_ms"])
    threshold = parse_threshold(params["threshold"])

    case QueryServer.search(socket.assigns.session_token, query, delay_ms, threshold) do
      {:ok, _pid} -> {:reply, {:ok, %{accepted: true}}, socket}
      {:error, reason} -> {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  def handle_in("search", _params, socket) do
    {:reply, {:error, %{reason: "missing query"}}, socket}
  end

  defp clamp_delay(n) when is_integer(n) and n >= 0, do: min(n, 60_000)
  defp clamp_delay(_), do: 0

  defp parse_threshold(n) when is_float(n), do: n
  defp parse_threshold(n) when is_integer(n), do: n * 1.0
  defp parse_threshold(_), do: nil
end
