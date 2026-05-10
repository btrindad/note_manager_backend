defmodule NoteManager.KnowledgeBase.NoteLink do
  alias NoteManager.KnowledgeBase.Note

  use Ash.Resource,
    otp_app: :note_manager,
    domain: NoteManager.KnowledgeBase,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "note_links"
    repo NoteManager.Repo

    references do
      reference :source_note, on_delete: :delete
      reference :target_note, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    timestamps()
  end

  relationships do
    belongs_to :source_note, Note do
      primary_key? true
      allow_nil? false
    end

    belongs_to :target_note, Note do
      primary_key? true
      allow_nil? false
    end
  end
end
