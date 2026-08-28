require './config/environment'
conversation = Conversation.last
params = ActionController::Parameters.new(
  content: "Test",
  message_type: "incoming",
  attachments: [
    ActionDispatch::Http::UploadedFile.new(
      tempfile: Tempfile.new('test'),
      filename: 'test.jpg',
      content_type: 'image/jpeg'
    )
  ]
)
mb = Messages::MessageBuilder.new(nil, conversation, params)
message = mb.perform
puts "Message saved: #{message.persisted?}"
puts "Attachments count: #{message.attachments.count}"
puts "Attachment persisted: #{message.attachments.first&.persisted?}"
