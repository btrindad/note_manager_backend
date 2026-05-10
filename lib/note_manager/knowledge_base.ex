defmodule NoteManager.KnowledgeBase do
  use Ash.Domain,
    otp_app: :note_manager

  resources do
    resource NoteManager.KnowledgeBase.Note do
      define :new_note, action: :create
      define :destroy_note, action: :destroy
      define :update_note, action: :update
      define :list_notes, action: :read
      define :get_note_by_id, action: :read, get_by: :id

      define :search, action: :search
    end
  end
end
