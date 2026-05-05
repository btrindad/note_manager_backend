defmodule NoteManager.KnowledgeBase.Note do
  use Ash.Resource,
    otp_app: :note_manager,
    domain: NoteManager.KnowledgeBase,
    data_layer: AshPostgres.DataLayer,
    extensions: AshAi

  postgres do
    table "notes"
    repo NoteManager.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      allow_nil? false
    end

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:content]
    end

    update :update do
      primary? true
      accept [:content]
    end
  end

  vectorize do
    full_text do
      text(fn note ->
        note.content
      end)

      used_attributes [:content]
      name :embedding
    end

    strategy :after_action
    embedding_model Application.compile_env(:note_manager, :embedding_module, NoteManager.LlmAdapter.Local)
    # embedding_model Application.get_env(:note_manager, :embedding_module, NoteManager.LlmAdapter.Local)
  end
end
