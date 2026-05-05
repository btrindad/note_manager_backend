defmodule NoteManager.LlmAdapter.Local do
  use AshAi.EmbeddingModel

  def child_spec(opts \\ []) do
    {
      Nx.Serving,
      serving: __MODULE__.serving(opts),
      name: __MODULE__,
      batch_size: 10,
      batch_timeout: 100 # ms 
    }
    |> Supervisor.child_spec([])
  end

  @impl true
  def dimensions(_opts) do
    3072
  end

  @impl true
  def generate(texts, opts) do
    texts
    |> maybe_join()
    |> get_embedding(opts)
  end

  defp maybe_join(text) when is_binary(text), do: text
  defp maybe_join(texts) when is_list(texts), do: Enum.join(texts, "\n")

  defp get_embedding(input, opts) do
    opts
    |> Keyword.get(:serving, __MODULE__)
    |> Nx.Serving.batched_run(input)
  end

  @doc """
  Launch a local text embedding model as an Nx.Serving
  This can be used to run a model locally rather than
  using a remote API
  """
  def serving(opts \\ []) do
    model_name = Keyword.get(opts, :model, "intfloat/e5-large")

    {:ok, model_info} = Bumblebee.load_model({:hf, model_name})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, model_name})

    Bumblebee.Text.text_embedding(model_info, tokenizer)
  end
end
