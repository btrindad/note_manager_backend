defmodule NoteManager.GraphDbClient do
  def send_query() do
    []
    |> Keyword.merge(Application.get_env(:note_manager, __MODULE__, []))
    |> Req.request()
  end
end
