# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     NoteManager.Repo.insert!(%NoteManager.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias NoteManager.KnowledgeBase, as: KG

NoteManager.Repo.delete_all(KG.Note)

%Ash.BulkResult{status: :success, records: [sample | _]} =
  [
    """
    # Note 1

    This is a note about Cars 
    """,
    """
    # Note 2

    So long, and thanks for all the fish
    """,
    """
    # Note 3

    This is a note about Trucks 
    """
  ]
  |> Enum.map(&%{content: &1})
  |> Ash.bulk_create!(KG.Note, :create, return_records?: true, return_notifications?: false)

Ash.create!(
  KG.Note,
  %{
    content: """
    An otherwise unrelated note that links to
    an existing one: [[#{sample.id}]]
    """
  }
)
