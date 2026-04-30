defmodule NoteManager.KnowledgeBaseGenerator do
  use Ash.Generator

  alias NoteManager.KnowledgeBase.Note

  def note(opts \\ []) do
    changeset_generator(Note, :create,
      overrides: opts,
      defaults: [
        content: StreamData.repeatedly(fn -> Faker.Markdown.markdown() end)
      ]
    )
  end
end
