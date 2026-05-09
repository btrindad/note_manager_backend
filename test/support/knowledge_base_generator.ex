defmodule NoteManager.KnowledgeBaseGenerator do
  use Ash.Generator

  alias NoteManager.KnowledgeBase.Note

  @dim_size Application.compile_env(:note_manager, :embedding_size, 384)

  def note(opts \\ []) do
    seed_generator(
      %Note{
        content: StreamData.repeatedly(fn -> "Sample note\n" <> Faker.Markdown.markdown() end),
        embedding:
          StreamData.float(min: 0.0, max: 1.0)
          |> StreamData.list_of(length: @dim_size)
          |> StreamData.map(fn list ->
            {:ok, vector} = Ash.Vector.new(list)
            vector
          end)
      },
      overrides: opts
    )
  end
end
