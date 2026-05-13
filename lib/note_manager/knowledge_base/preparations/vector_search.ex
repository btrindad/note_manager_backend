defmodule NoteManager.KnowledgeBase.Preparations.VectorSearch do
  use Ash.Resource.Preparation

  @embedding_module Application.compile_env(
                      :note_manager,
                      :embedding_module,
                      NoteManager.LlmAdapter.Local
                    )

  @options_schema NimbleOptions.new!(
                    input_argument: [
                      type: :atom,
                      default: :query,
                      doc: "The name of the argument to use as the search value"
                    ],
                    search_attribute: [
                      type: :atom,
                      default: :embedding,
                      doc: "The name of the vector column to search against"
                    ],
                    embedding_opts: [
                      doc: "Options to pass to the underlying embedding module",
                      type: :keyword_list
                    ],
                    threshold_argument: [
                      type: :atom,
                      doc:
                        "Name of the query argument that supplies a per-call threshold. Falls back to :threshold below when the argument is absent."
                    ],
                    threshold: [
                      doc:
                        "Fallback similarity threshold when no per-call argument is provided. Only records strictly below this distance are returned.",
                      default: 0.10,
                      type: :float
                    ]
                  )

  import Ash.Expr

  @impl true
  def init(opts) do
    case NimbleOptions.validate(opts, @options_schema) do
      {:ok, options} -> {:ok, options}
      {:error, validation_error} -> {:error, Exception.message(validation_error)}
    end
  end

  @impl true
  def prepare(query, opts, _context) do
    input_attr = query.arguments[opts[:input_argument]]
    search_field = opts[:search_attribute]
    threshold = resolve_threshold(query, opts)

    Ash.Query.before_action(query, fn query ->
      with {:ok, [search_vector]} <-
             @embedding_module.generate([input_attr], opts[:embedding_opts]) do
        query
        |> Ash.Query.filter(
          vector_cosine_distance(^ref(search_field), ^search_vector) < ^threshold
        )
        |> Ash.Query.sort({
          calc(vector_cosine_distance(^ref(search_field), ^search_vector), type: :float),
          :asc
        })
      end
    end)
  end

  defp resolve_threshold(query, opts) do
    case opts[:threshold_argument] do
      nil -> opts[:threshold]
      arg_name -> query.arguments[arg_name] || opts[:threshold]
    end
  end
end
