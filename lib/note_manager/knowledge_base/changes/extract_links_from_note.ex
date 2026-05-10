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
      |> Enum.map(&Map.new(id: &1))
      |> then(&Ash.Changeset.manage_relationship(changeset, :neighbors, &1, @relation_opts))
    end
  end
end
