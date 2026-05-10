# Custom Postgrex types to add vector support to Ash

Postgrex.Types.define(
  NoteManager.PostgrexTypes,
  [AshPostgres.Extensions.Vector] ++ Ecto.Adapters.Postgres.extensions(),
  []
)
