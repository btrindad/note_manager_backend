defmodule NoteManager.KnowledgeBase.Note do
  use Ash.Resource,
    otp_app: :note_manager,
    domain: NoteManager.KnowledgeBase,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "notes"
    repo NoteManager.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :text do
      allow_nil? false
    end

    attribute :embedding, :vector
    timestamps()
  end
end
