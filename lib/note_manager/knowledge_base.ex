defmodule NoteManager.KnowledgeBase do
  use Ash.Domain, otp_app: :note_manager, extensions: [AshJsonApi.Domain]

  json_api do
    routes do
      base_route "/notes", NoteManager.KnowledgeBase.Note do
        get :read, name: "get_note", description: "Find a single note by its ID"

        post :create, name: "new_note", description: "Create a new note"

        delete :destroy, name: "delete_note", description: "Delete a single note"

        index :search,
          route: "/search",
          name: "search_notes",
          description: "Look for a set of notes based on a query or note contents"
      end
    end
  end

  resources do
    resource NoteManager.KnowledgeBase.Note do
      define :new_note, action: :create
      define :destroy_note, action: :destroy
      define :update_note, action: :update
      define :list_notes, action: :read
      define :get_note_by_id, action: :read, get_by: :id

      define :search, action: :search
    end

    resource NoteManager.KnowledgeBase.NoteLink
  end
end
