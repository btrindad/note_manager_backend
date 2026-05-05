defmodule NoteManager.LlmAdapter.Local do
  use AshAi.EmbeddingModel

  @impl true
  def dimensions(_opts) do
    3072
  end

  @impl true
  def generate(texts, opts) do
    
  end
end
