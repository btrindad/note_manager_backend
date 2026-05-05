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

    attribute :embedding, :vector
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
      text(&(&1.content))
    end

    strategy :after_action
    attributes(content: :embedding)
  end
end
