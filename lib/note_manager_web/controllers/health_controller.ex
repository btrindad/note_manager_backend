defmodule NoteManagerWeb.HealthController do
  use NoteManagerWeb, :controller

  def check(conn, _params) do
    json(conn, %{status: "ok", message: "Note Manager API is running"})
  end
end
