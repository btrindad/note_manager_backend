defmodule NoteManagerWeb.UserSocket do
  @moduledoc """
  Socket transport for the JSON-RPC-over-WebSocket query interface.

  For the demo, the client passes a `session_token` query param. The token is
  stored in `socket.assigns` and used as the topic suffix for `QueryChannel`.
  This is intentionally hackable — production should swap this for
  `Phoenix.Token.verify/4` against the user's session.
  """

  use Phoenix.Socket

  channel "query:*", NoteManagerWeb.QueryChannel

  @impl true
  def connect(%{"session_token" => token}, socket, _connect_info)
      when is_binary(token) and byte_size(token) >= 8 do
    {:ok, assign(socket, :session_token, token)}
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.session_token}"
end
