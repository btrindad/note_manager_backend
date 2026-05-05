defmodule NoteManager.LlmAdapter.Local do
  use AshAi.EmbeddingModel

  require Logger

  @default_model "thenlper/gte-small"
  @default_dim 384

  def child_spec(opts \\ []) do
    Logger.debug "Launching local model with: #{__MODULE__}"

    {
      Nx.Serving,
      serving: __MODULE__.serving(opts), name: __MODULE__, batch_size: 10, batch_timeout: 100
    }
    |> Supervisor.child_spec([])
  end

  @impl true
  def dimensions(opts) do
    opts
    |> Keyword.get(
      :dimensions,
      Application.get_env(:note_manager, :embedding_size, @default_dim)
    )
  end

  @impl true
  def generate(texts, opts) do
    Logger.debug "#{__MODULE__}: embedding request received"
    with joined <- maybe_join(texts),
         {:ok, embedding} <- get_embedding(joined, opts) do
      {:ok, [convert_to_vector(embedding)]}
    end
  end

  defp maybe_join(text) when is_binary(text), do: text
  defp maybe_join(texts) when is_list(texts), do: Enum.join(texts, "\n")

  defp get_embedding(input, opts) do
    opts
    |> Keyword.get(:serving, __MODULE__)
    |> Nx.Serving.batched_run(input)
    |> Map.fetch(:embedding)
    |> case do
      {:ok, embedding} -> {:ok, embedding}
      :error -> {:error, :embedding_failed}
    end
  end

  defp convert_to_vector(%Nx.Tensor{} = tensor) do
    tensor
    |> Nx.to_list()
  end
  defp convert_to_vector(list) when is_list(list), do: list

  @doc """
  Launch a local text embedding model as an Nx.Serving
  This can be used to run a model locally rather than
  using a remote API
  """
  def serving(opts \\ []) do
    model_name = Keyword.get(opts, :model, @default_model)

    {:ok, model_info} = Bumblebee.load_model({:hf, model_name})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, model_name})

    Bumblebee.Text.text_embedding(model_info, tokenizer)
  end
end
