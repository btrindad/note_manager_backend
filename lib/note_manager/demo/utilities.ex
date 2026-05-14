defmodule NoteManager.Demo.Utilties do
  alias NoteManager.KnowledgeBase.Note

  require Ash.Query

  @doc """
  A utility function that returns the query for
  notes that do not yet have an embedding. This
  returns an Ash.Query struct can be used to
  chain into other queries
  """
  def get_pending_notes do
    Note
    |> Ash.Query.filter(embedding_complete? == false)
  end
end
