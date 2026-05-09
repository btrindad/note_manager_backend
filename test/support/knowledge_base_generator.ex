defmodule NoteManager.KnowledgeBaseGenerator do
  use Ash.Generator

  alias NoteManager.KnowledgeBase.Note

  def note(opts \\ []) do
    changeset_generator(Note, :create,
      defaults: [
        content: StreamData.repeatedly(fn -> "Sample note\n" <> Faker.Markdown.markdown() end)
      ],
      overrides: opts
    )
  end
end
