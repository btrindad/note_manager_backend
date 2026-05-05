defmodule NoteManager.LlmAdapter.LocalTest do
  use ExUnit.Case, async: true

  alias NoteManager.LlmAdapter.Local, as: LocalLLM

  setup_all do
    start_supervised!(LocalLLM)
    :ok
  end

  describe "dimensions/1" do
    test "returns the expected embedding size" do
      assert LocalLLM.dimensions([]) == 384
    end

    test "accepts an optional override" do
      assert LocalLLM.dimensions(dimensions: 2048) == 2048
    end
  end

  describe "generate/2" do
    setup do
      [sample_input: ["abc", "123"]]
    end

    test "returns an okay tuple with a single vector in a list", %{sample_input: input} do
      assert {:ok, [[num | _] = vector]} = LocalLLM.generate(input, [])

      assert is_float(num)
      assert length(vector) == 384
    end
  end
end
