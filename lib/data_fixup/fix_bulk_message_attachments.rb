module DataFixup::FixBulkMessageAttachments
  def self.run
    ConversationBatch.find_each(:include => :root_conversation_message) do |batch|
      root_message = batch.root_conversation_message 
      next unless root_message.has_attachments?
      messages = ConversationMessage.find(batch.conversation_message_ids)
      messages.each do |message|
        message.attachments = root_message.attachments
      end
    end
  end
end