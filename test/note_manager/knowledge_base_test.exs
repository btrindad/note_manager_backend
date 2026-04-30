defmodule NoteManager.KnowledgeBaseTest do
  use NoteManager.DataCase, async: true

  alias NoteManager.KnowledgeBase, as: KG
  alias NoteManager.KnowledgeBase.Note

  setup do
    [
      simple_note:  """
        # Sample Title
        
        Note body goes here supporting

        * Markdown content
        * Listing
        * and eventually linking 

        ```elixir
        sample_code.(arg1, arg2)
        ```
      """
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
        assert val == Map.fetch(note, key)
      end
    end
  end
end
