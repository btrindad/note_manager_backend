defmodule NoteManager.NoteWikiParsingTest do
  use NoteManager.DataCase, async: true

  alias NoteManager.KnowledgeBase.Note.ContentParser
  alias NoteManager.KnowledgeBase, as: KG

  @moduletag :focus

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

    lone_note = """
      # Standalone Note
      
      This is a valid note that contains no links 
    """

    [linked_note: note_with_links, target_note: existing_note, standalone_note: lone_note]
  end

  describe "parsing content" do
    test "extracts all valid UUIDs in Wiki Links", %{
      linked_note: content,
      target_note: %KG.Note{id: target_id}
    } do
      assert {:ok, links} = ContentParser.extract_links(content)

      assert length(links) == 2
      assert Enum.member?(links, target_id)
    end

    test "returns an empty list with no links", %{standalone_note: content} do
      assert {:ok, []} = ContentParser.extract_links(content)
    end
  end

  describe "saving a note with links" do
    test "saves outgoing links to other notes", %{
      linked_note: content,
      target_note: %{id: target_id}
    } do
      assert {:ok, %KG.Note{neighbors: neigh}} =
               KG.new_note(%{content: content}, load: [neighbors: :id])

      assert length(neigh) == 1
      assert [%KG.Note{id: ^target_id}] = neigh
    end

    test "saves notes with no links", %{standalone_note: content} do
      assert {:ok, %KG.Note{neighbors: []}} =
               KG.new_note(%{content: content}, load: [neighbors: :id])
    end
  end
end
