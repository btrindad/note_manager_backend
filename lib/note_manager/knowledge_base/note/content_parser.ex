defmodule NoteManager.KnowledgeBase.Note.ContentParser do
  alias NoteManager.KnowledgeBase.Note

  @parsing_options [
    extension: [wikilinks_title_after_pipe: true]
  ]

  def extract_links(%Ash.Changeset{} = changeset) do
    Ash.Changeset.get_attribute(changeset, :content)
    |> extract_links()
  end

  def extract_links(%Note{content: content}), do: extract_links(content)

  def extract_links(markdown) when is_binary(markdown) do
    with {:ok, doc} <- MDEx.parse_document(markdown, @parsing_options) do
      doc
      |> retrieve_links()
      |> fetch_note_ids()
    end
  end

  defp retrieve_links(%MDEx.Document{} = doc) do
    doc[MDEx.WikiLink]
  end

  defp fetch_note_ids(nil), do: {:ok, []}

  defp fetch_note_ids(elements) do
    elements
    |> Enum.map(fn link -> link.url end)
    |> Enum.filter(fn url ->
      case Ecto.UUID.cast(url) do
        {:ok, _uuid} -> true
        :error -> false
      end
    end)
    |> Enum.to_list()
    |> then(&{:ok, &1})
  end
end
