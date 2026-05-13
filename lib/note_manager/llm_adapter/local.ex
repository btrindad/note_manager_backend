defmodule NoteManager.LlmAdapter.Local do
  use AshAi.EmbeddingModel

  require Logger

  @default_model "thenlper/gte-small"
  @default_dim 384

  def child_spec(opts \\ []) do
    Logger.debug("Launching local model with: #{__MODULE__}")

    serving_opts =
      [batch_timeout: 100, batch_size: 1]
      |> Keyword.merge(Application.get_env(:note_manager, Nx.Serving, []))
      |> Keyword.put(:serving, serving(opts))
      |> Keyword.put(:name, __MODULE__)

    {Nx.Serving, serving_opts}
    |> Supervisor.child_spec([])
  end

  @impl true
  def dimensions(opts \\ []) do
    opts
    |> ensure_list()
    |> Keyword.get(
      :dimensions,
      Application.get_env(:note_manager, :embedding_size, @default_dim)
    )
  end

  @impl true
  def generate(texts, opts \\ []) do
    Logger.debug("#{__MODULE__}: embedding request received")

    with joined <- maybe_join(texts),
         {:ok, embedding} <- get_embedding(joined, opts) do
      {:ok, [convert_to_vector(embedding)]}
    end
  end

  defp maybe_join(text) when is_binary(text), do: text
  defp maybe_join(texts) when is_list(texts), do: Enum.join(texts, "\n")

  defp get_embedding(input, opts) do
    opts
    |> ensure_list()
    |> Keyword.get(:serving, __MODULE__)
    |> Nx.Serving.batched_run(input)
    |> Map.fetch(:embedding)
    |> case do
      {:ok, embedding} -> {:ok, embedding}
      :error -> {:error, :embedding_failed}
    end
  end

  defp ensure_list(nil), do: []
  defp ensure_list(list) when is_list(list), do: list

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
    {model_info, tokenizer, opts} = load_model(opts)

    opts =
      Application.get_env(:note_manager, __MODULE__, [])
      |> Keyword.merge(opts)

    Bumblebee.Text.text_embedding(model_info, tokenizer, opts)
  end

  def load_model(opts \\ []) do
    {model_name, opts} = Keyword.pop(opts, :model, @default_model)

    {:ok, model_info} = Bumblebee.load_model({:hf, model_name})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, model_name})

    {model_info, tokenizer, opts}
  end
end
