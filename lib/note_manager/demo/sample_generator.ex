defmodule NoteManager.Demo.SampleGenerator do
  @url "https://en.wikipedia.org/wiki/Special:Random"
  @max_length 2_000

  alias NoteManager.KnowledgeBase, as: KG

  def generate_note(opts \\ []) do
    url = Keyword.get(opts, :url, @url)
    max_length = Keyword.get(opts, :max_length, @max_length)

    with {:ok, article} <- fetch_article(url),
         {:ok, parsed} <- Floki.parse_document(article),
         {:ok, %{content: body}} <- extract_body(parsed) do
      body
      |> String.slice(0, max_length)
    end
  end

  def save_notes(count, opts \\ []) when is_integer(count) and count > 0 do
    0..count
    |> Stream.map(fn _ -> generate_note(opts) end)
    |> Stream.map(fn content -> %{content: content} end)
    |> Ash.bulk_create!(KG.Note, :create, batch_size: 10)
  end

  defp fetch_article(url) do
    case Req.get(url) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, response} -> {:error, "Encountered response code #{response.status}"}
    end
  end

  defp extract_body(parsed) do
    parsed
    |> Floki.find("#content")
    |> Floki.raw_html()
    |> HtmlToMarkdown.convert()
  end
end
