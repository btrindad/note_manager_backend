defmodule NoteManager.KnowledgeBaseGenerator do
  use Ash.Generator

  alias NoteManager.KnowledgeBase.Note

  def note(opts \\ []) do
    seed_generator(
      %Note{
        content: content(),
        embedding: embedding()
      },
      overrides: opts
    )
  end

  def note_with_embedding(opts \\ []) do
    changeset_generator(Note, :create,
      defaults: [
        content: content()
      ],
      overrides: opts
    )
  end

  defp content do
    StreamData.repeatedly(fn -> "Sample note\n" <> Faker.Markdown.markdown() end)
  end

  defp embedding do
    StreamData.float(min: -1.0, max: 1.0)
    |> StreamData.list_of(length: Application.get_env(:note_manager, :embedding_size, 384))
  end
end
