defmodule NoteManager.KnowledgeBase.Changes.ExtractLinksFromNote do
  use Ash.Resource.Change

  alias NoteManager.KnowledgeBase.Note.ContentParser, as: Parser

  @relation_opts [
    type: :append_and_remove,
    on_no_match: :ignore
  ]

  @impl true
  def change(changeset, _opts, _context) do
    with {:ok, links} <- Parser.extract_links(changeset) do
      links
      |> Stream.map(&Map.new(id: &1))
      |> filter_self_id(changeset)
      |> Enum.to_list()
      |> then(&Ash.Changeset.manage_relationship(changeset, :neighbors, &1, @relation_opts))
    end
  end

  defp filter_self_id(list, changeset) do
    case Ash.Changeset.get_data(changeset, :id) do
      nil -> list
      self_id -> Stream.reject(list, fn %{id: id} -> id == self_id end)
    end
  end
end
