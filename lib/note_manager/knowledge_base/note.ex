defmodule NoteManager.KnowledgeBase.Note do
  use Ash.Resource,
    otp_app: :note_manager,
    domain: NoteManager.KnowledgeBase,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAi, AshJsonApi.Resource, AshOban]

  alias NoteManager.KnowledgeBase.Changes.ExtractLinksFromNote, as: ExtractLinks

  json_api do
    type "note"
  end

  vectorize do
    full_text do
      text fn note ->
        note.content
      end

      used_attributes [:content]
      name :embedding
    end

    strategy :ash_oban
    ash_oban_trigger_name :embed_note_trigger

    embedding_model Application.compile_env(
                      :note_manager,
                      :embedding_module,
                      NoteManager.LlmAdapter.Local
                    )
  end

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

  oban do
    triggers do
      trigger :embed_note_trigger do
        action :ash_ai_update_embeddings
        queue :note_embedding_queue
        worker_read_action :read
        worker_module_name __MODULE__.AshOban.Worker.UpdateEmbeddings
        scheduler_module_name __MODULE__.AshOban.Worker.UpdateEmbeddings
        scheduler_cron false
        list_tenants NoteManager.ListTenants
        max_attempts 3
      end
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:content]

      pipe_through :update_graph, where: changing(:content)
    end

    update :update do
      primary? true
      accept [:content]

      change fn changeset, _ ->
        if Ash.Changeset.changing_attribute?(changeset, :content) do
          Ash.Changeset.change_attribute(changeset, :embedding, nil)
        else
          changeset
        end
      end

      pipe_through :update_graph
      require_atomic? false
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
      public? true
    end

    timestamps()
  end

  relationships do
    many_to_many :neighbors, NoteManager.KnowledgeBase.Note do
      through NoteManager.KnowledgeBase.NoteLink

      source_attribute_on_join_resource :source_note_id
      destination_attribute_on_join_resource :target_note_id
      writable? true
    end
  end

  pipelines do
    pipeline :update_graph do
      change ExtractLinks
    end
  end

  calculations do
    calculate :embedding_complete?, :boolean, expr(not is_nil(embedding))
  end
end
