defmodule NoteManagerWeb.AshJsonApiRouter do
  use AshJsonApi.Router,
    domains: [NoteManager.KnowledgeBase],
    open_api: "/open_api"
end
