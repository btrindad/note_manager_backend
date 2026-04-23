defmodule NoteManager.KnowledgeBase do
  use Ash.Domain,
    otp_app: :note_manager

  resources do
    resource NoteManager.KnowledgeBase.Note
  end
end
