defmodule NoteManager.LlmAdapter.Dummy do
  use AshAi.EmbeddingModel

  require Logger

  @default_dim 384

  def child_spec(_opts \\ []), do: nil

  @impl true
  def dimensions(opts) do
    opts
    |> Keyword.get(
      :dimensions,
      Application.get_env(:note_manager, :embedding_size, @default_dim)
    )
  end

  @impl true
  def generate(_texts, opts) do
    Logger.debug("#{__MODULE__}: embedding request received")

    for(_ <- 1..dimensions(opts), do: :rand.normal())
    |> then(&{:ok, [&1]})
  end
end
