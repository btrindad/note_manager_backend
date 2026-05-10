defmodule NoteManager.NoteWikiParsingTest do
  use NoteManager.DataCase, async: true

  alias NoteManager.KnowledgeBase.Note.ContentParser
  alias NoteManager.KnowledgeBase, as: KG

  setup do
    existing_note = generate(note())

    note_with_links = """
      # Example Note

      This is an example note that exercises some critical features
      like links to [real source](https://google.com) and links to
      other [[#{existing_note.id}|note]]. Non existant uuids are
      ignored [[#{Ecto.UUID.generate()}]].

      UUIDs not in a wiki link are treated as content #{Ecto.UUID.generate()}
      and Wiki Links that do not contain UUIDs are also ignored like
      [[some other content 123|this]].
    """

    [note_content: note_with_links, target_note: existing_note]
  end

  describe "parsing content" do
    test "extracts all valid UUIDs in Wiki Links", %{
      note_content: content,
      target_note: %KG.Note{id: target_id}
    } do
      assert {:ok, links} = ContentParser.extract_links(content)

      assert length(links) == 2
      assert Enum.member?(links, target_id)
    end
  end

  # test "saves outgoing links to other notes", %{note_content: content, target_note: target} do
  #   assert {:ok, %KG.Note{outgoing_neighbors: neigh}} = KG.new_note(%{content: content})

  #   assert length(neigh) == 1
  #   assert neigh == [target.id]
  # end
end
