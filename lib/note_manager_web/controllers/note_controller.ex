defmodule NoteManagerWeb.NoteController do
  use NoteManagerWeb, :controller

  def index(conn, _params) do
    json(conn, %{notes: [], message: "No notes yet"})
  end

  def create(conn, params) do
    json(conn, %{created: true, note: params})
  end

  def show(conn, %{"id" => id}) do
    json(conn, %{id: id, title: "Sample Note", content: "This is a sample note"})
  end

  def update(conn, %{"id" => id} = params) do
    json(conn, %{updated: true, id: id, note: params})
  end

  def delete(conn, %{"id" => id}) do
    json(conn, %{deleted: true, id: id})
  end
end
