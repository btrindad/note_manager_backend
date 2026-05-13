defmodule NoteManager.KnowledgeBase.Note do
  use Ash.Resource,
    otp_app: :note_manager,
    domain: NoteManager.KnowledgeBase,
    data_layer: AshPostgres.DataLayer,
    extensions: AshAi

  postgres do
    table "notes"
    repo NoteManager.Repo

    custom_statements do
      statement :vector_idx do
        up "CREATE INDEX vector_idx ON notes USING hnsw (embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64)"
        down "DROP INDEX vector_idx;"
      end
    end
  end

  vectorize do
    full_text do
      text fn note ->
        note.content
      end

      used_attributes [:content]
      name :embedding
    end

    strategy :after_action

    embedding_model Application.compile_env(
                      :note_manager,
                      :embedding_module,
                      NoteManager.LlmAdapter.Local
                    )
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

    read :search do
      argument :query, :ci_string do
        description "search notes by content"
        constraints allow_empty?: false
      end

      argument :threshold, :float do
        description "cosine distance cutoff (0=identical, 2=opposite). Lower = stricter."
        default 0.10
        constraints min: 0.0, max: 2.0
      end

      prepare {NoteManager.KnowledgeBase.Preparations.VectorSearch,
               search_attribute: :embedding, threshold_argument: :threshold}

      pagination offset?: true, default_limit: 15
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      allow_nil? false
      constraints allow_empty?: false
    end

    timestamps()
  end
end
