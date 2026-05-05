defmodule NoteManager.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @embedding_module Application.compile_env(
                      :note_manager,
                      :embedding_module,
                      NoteManager.LlmAdapter.Local
                    )

  @impl true
  def start(_type, _args) do
    children =
      [
        NoteManagerWeb.Telemetry,
        NoteManager.Repo,
        {DNSCluster, query: Application.get_env(:note_manager, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: NoteManager.PubSub},
        llm_application(@embedding_module),
        # Start a worker by calling: NoteManager.Worker.start_link(arg)
        # {NoteManager.Worker, arg},
        # Start to serve requests, typically the last entry
        NoteManagerWeb.Endpoint
      ]
      |> Enum.reject(fn
        nil -> true
        _ -> false
      end)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NoteManager.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NoteManagerWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp llm_application(nil), do: nil
  defp llm_application(:local), do: llm_application(NoteManager.LlmAdapter.Local)

  defp llm_application(model_info) when is_binary(model_info),
    do: {NoteManager.LlmAdapter.Local, model: model_info}

  defp llm_application(module) when is_atom(module), do: module
end
