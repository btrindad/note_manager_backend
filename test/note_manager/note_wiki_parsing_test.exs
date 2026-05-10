defmodule NoteManager.NoteWikiParsingTest do
  use NoteManager.DataCase, async: true

  alias NoteManager.KnowledgeBase, as: KG

  setup do
    existing_note = generate(note())

    note_with_links = """
      # Example Note

      This is an example note that exercises some critical features
      like links to [real source](https://google.com) and links to
      other [[notes|#{existing_note.id}]]. Non existant uuids are
      ignored [[#{Ecto.UUID.generate()}]].
    """

    [note_content: note_with_links, target_note: existing_note]
  end

  test "saves outgoing links to other notes", %{note_content: content, target_note: target} do
    assert {:ok, %KG.Note{outgoing_neighbors: neigh}} = KG.new_note(%{content: content})

    assert length(neigh) == 1
    assert neigh == [target.id]
  end
end
