import Config
config :note_manager, Oban, testing: :manual
config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :note_manager, NoteManager.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "note_manager_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :note_manager, :embedding_module, NoteManager.LlmAdapter.Local

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :note_manager, NoteManagerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "LXPE/grqDCpeIuHcICGn8aoa2awJ4fJEyS+Hlr1yv/i3C2LvQA7USRquRUMD+dgp",
  server: false

# In test we don't send emails
config :note_manager, NoteManager.Mailer, adapter: Swoosh.Adapters.Test

config :note_manager, NoteManager.GraphDbClient, plug: {Req.Test, NoteManager.GraphDbClient}

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
