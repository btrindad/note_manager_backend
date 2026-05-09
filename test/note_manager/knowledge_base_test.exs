defmodule NoteManager.KnowledgeBaseTest do
  use NoteManager.DataCase, async: true

  alias NoteManager.KnowledgeBase, as: KG
  alias NoteManager.KnowledgeBase.Note

  setup do
    [
      simple_note:
        """
        # Sample Title
          
        Note body goes here supporting

        * Markdown content
        * Listing
        * and eventually linking 

        ```elixir
        sample_code.(arg1, arg2)
        ```
        """
        |> String.trim()
    ]
  end

  describe "KnowledgeBase.new_note" do
    setup %{simple_note: content} do
      [params: %{content: content}]
    end

    test "saves the new note to the database", %{params: params} do
      original_count = Ash.count!(Note)
      assert {:ok, %Note{id: id}} = KG.new_note(params)
      new_count = Ash.count!(Note)

      assert new_count == original_count + 1

      note = Ash.get!(Note, id)

      for {key, val} <- params do
        assert {:ok, val} == Map.fetch(note, key)
      end
    end
  end

  describe "KnowledgeBase.destroy_note" do
    setup do
      [note: generate(note())]
    end

    test "deletes the note from the database", %{note: note} do
      assert :ok = KG.destroy_note(note)

      assert {:error, _} = Ash.get(Note, note.id)
    end
  end

  describe "KnowledgeBase.update_note" do
    setup %{simple_note: content} do
      [note: generate(note()), params: %{content: content}]
    end

    test "saves the new content to the database", %{note: note, params: update_params} do
      assert {:ok, _} = KG.update_note(note, update_params)

      saved_note = Ash.get!(Note, note.id)

      assert saved_note.content == update_params.content
      assert saved_note.content != note.content
    end
  end

  describe "search/1" do
    setup do
      generate_many(note(), 3)

      [
        sample_note: generate(note(content: "Programming Languages like Elixir are so cool"))
      ]
    end

    @tag :acceptance
    test "returns notes with matching text", %{sample_note: note} do
      assert {:ok, note_list} = KG.search(%{query: "language"})

      assert Enum.any?(note_list, fn %Note{id: note_id} -> note_id == note.id end)
    end

    @tag :acceptance
    @tag :focus
    test "returns notes with semantic similarity", %{sample_note: note} do
      assert {:ok, note_list} = KG.search(%{query: "writing code"})

      assert Enum.any?(note_list.results, fn %Note{id: note_id} -> note_id == note.id end)
    end
  end
end
