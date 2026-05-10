defmodule NoteManager.NoteWikiParsingTest do
  use NoteManager.DataCase, async: true

  alias NoteManager.KnowledgeBase.Note.ContentParser
  alias NoteManager.KnowledgeBase, as: KG

  @moduletag :focus

  require Ash.Query

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

  describe "deleting a note with links" do
    setup %{linked_note: content} do
      [note: generate(note(content: content))]
    end

    test "does not delete connected notes", %{note: note, target_note: %{id: target_id}} do
      assert :ok = KG.destroy_note(note)

      assert {:ok, %KG.Note{id: ^target_id}} =
               Ash.get(KG.Note, target_id, not_found_error?: false)
    end

    test "deletes source connections from the join table", %{note: note} do
      assert :ok = KG.destroy_note(note)

      assert 0 ==
               KG.NoteLink
               |> Ash.Query.new()
               |> Ash.Query.filter(source_note_id == ^note.id)
               |> Ash.count!()
    end

    test "deletes destination connections from the join table", %{target_note: target} do
      assert :ok = KG.destroy_note(target)

      assert 0 ==
               KG.NoteLink
               |> Ash.Query.new()
               |> Ash.Query.filter(target_note_id == ^target.id)
               |> Ash.count!()
    end
  end

  describe "updating a note with links" do
    setup %{linked_note: content} do
      original = generate(note(content: content))
      new_target = generate(note())

      new_content = """
      # Updated Note

      These are the new contents of the original note but now they
      link to a new [[#{new_target.id}|destination]]
      """

      [note: original, new_target: new_target, updated_content: new_content]
    end

    test "original target is no longer connected to the note", %{
      note: note,
      updated_content: content,
      target_note: %{id: original_target_id}
    } do
      assert {:ok, %KG.Note{neighbors: neigh}} =
               KG.update_note(note, %{content: content}, load: :neighbors)

      refute neigh
             |> Enum.map(& &1.id)
             |> Enum.member?(original_target_id)

      assert 0 ==
               KG.NoteLink
               |> Ash.Query.filter(target_note_id == ^original_target_id)
               |> Ash.count!()
    end

    test "new target is connected to the note", %{
      note: note,
      updated_content: content,
      new_target: %{id: new_target_id}
    } do
      assert {:ok, %KG.Note{neighbors: neigh}} =
               KG.update_note(note, %{content: content}, load: :neighbors)

      assert length(neigh) == 1
      assert [%KG.Note{id: ^new_target_id}] = neigh
    end
  end

  describe "note linking to itself" do
    setup do
      original = generate(note())

      updated_content = """
      # Self linked Note

      This note is going to try and write a link
      to [[#{original.id}|itself]]. 
      """

      [note: original, content: updated_content]
    end

    test "links to self are ignored", %{note: note, content: content} do
      assert {:ok, %KG.Note{neighbors: neigh}} = KG.update_note(note, %{content: content})

      assert length(neigh) == 0
    end
  end
end
