# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Conversation::MessageHistoryBuilderService do
  subject(:service) { described_class.new(conversation: conversation) }

  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  describe '#perform' do
    # Test 1 — Conversación pequeña (10 mensajes)
    context 'with a small conversation (10 messages)' do
      before do
        10.times do |i|
          create(:message, conversation: conversation, account: account,
                           content: "Message #{i + 1}",
                           message_type: (i.even? ? :incoming : :outgoing),
                           created_at: (10 - i).minutes.ago)
        end
      end

      it 'preserves all 10 messages in the context' do
        history = service.perform
        expect(history.size).to eq(10)
        expect(history.first[:content]).to eq('Message 1')
        expect(history.last[:content]).to eq('Message 10')
      end
    end

    # Test 2 — Conversación larga (100+ mensajes)
    context 'with a long conversation (100+ messages)' do
      before do
        105.times do |i|
          create(:message, conversation: conversation, account: account,
                           content: "Old message #{i + 1}",
                           message_type: :incoming,
                           created_at: (110 - i).minutes.ago)
        end
      end

      it 'uses only the configured sliding window limit (default: 25)' do
        history = service.perform
        expect(history.size).to eq(described_class::DEFAULT_HISTORY_LIMIT)
        expect(history.size).to eq(25)
        # Should contain the latest 25 messages (messages 81 to 105)
        expect(history.first[:content]).to eq('Old message 81')
        expect(history.last[:content]).to eq('Old message 105')
      end

      it 'allows overriding the window limit via custom parameter' do
        custom_service = described_class.new(conversation: conversation, limit: 15)
        history = custom_service.perform
        expect(history.size).to eq(15)
        expect(history.first[:content]).to eq('Old message 91')
        expect(history.last[:content]).to eq('Old message 105')
      end
    end

    # Test 3 — Orden cronológico estricto (created_at ASC, id ASC)
    context 'with chronological ordering' do
      before do
        50.times do |i|
          create(:message, conversation: conversation, account: account,
                           content: "Ordered message #{i + 1}",
                           message_type: :incoming,
                           created_at: (60 - i).minutes.ago)
        end
      end

      it 'ensures context messages strictly maintain oldest to newest order' do
        history = service.perform
        extracted_contents = history.pluck(:content)
        expected_contents = (26..50).map { |n| "Ordered message #{n}" }

        expect(extracted_contents).to eq(expected_contents)
      end
    end

    # Test 4 & Query Count Regression Test — Attachments N+1 elimination
    context 'when messages have various attachments' do
      before do
        30.times do |i|
          msg = create(:message, conversation: conversation, account: account,
                                 content: "Attachment message #{i + 1}",
                                 message_type: :incoming,
                                 created_at: (40 - i).minutes.ago)

          case i % 4
          when 0
            attachment = msg.attachments.build(account_id: account.id, file_type: :image, external_url: 'https://example.com/img.jpg')
            attachment.save!
          when 1
            attachment = msg.attachments.build(account_id: account.id, file_type: :audio)
            attachment.save!
          when 2
            attachment = msg.attachments.build(account_id: account.id, file_type: :file)
            attachment.save!
          end
        end
      end

      it 'does not execute N+1 queries when building message history' do
        conversation.reload

        # Preload and build history within a bounded query budget
        queries_count = 0
        subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, _start, _finish, _id, payload|
          sql = payload[:sql].to_s
          queries_count += 1 unless sql.include?('SCHEMA') || sql.include?('SHOW ')
        end

        history = service.perform

        ActiveSupport::Notifications.unsubscribe(subscriber)

        expect(history.size).to eq(25)
        # Bounded query count: strictly bounded <= 12 (independent of total message count)
        expect(queries_count).to be <= 12
      end
    end

    # Test 5 — Imágenes
    context 'with image attachments' do
      let(:msg) { create(:message, conversation: conversation, account: account, content: 'Look at this photo', message_type: :incoming) }

      before do
        attachment = msg.attachments.build(account_id: account.id, file_type: :image, external_url: 'https://example.com/cat.jpg')
        attachment.save!
      end

      it 'correctly includes image multimodal structure' do
        history = service.perform
        msg_hash = history.first
        expect(msg_hash[:role]).to eq('user')
        expect(msg_hash[:content]).to be_an(Array)
        expect(msg_hash[:content]).to include({ type: 'text', text: 'Look at this photo' })
        expect(msg_hash[:content]).to include({ type: 'image_url', image_url: { url: 'https://example.com/cat.jpg' } })
      end
    end

    # Test 6 — Audio
    context 'with audio attachments' do
      let(:msg) { create(:message, conversation: conversation, account: account, content: nil, message_type: :incoming) }
      let(:audio_attachment) do
        attachment = msg.attachments.build(account_id: account.id, file_type: :audio)
        attachment.save!
        attachment
      end

      before do
        allow(Messages::AudioTranscriptionService).to receive(:new).with(audio_attachment).and_return(
          instance_double(Messages::AudioTranscriptionService, perform: { success: true, transcriptions: 'Audio voice inquiry' })
        )
      end

      it 'correctly includes transcribed audio content' do
        audio_attachment # trigger creation
        history = service.perform
        msg_hash = history.first
        expect(msg_hash[:content]).to eq('Audio voice inquiry')
      end
    end

    # Test 7 — Otros archivos
    context 'with generic file attachments' do
      let(:msg) { create(:message, conversation: conversation, account: account, content: 'Here is the brochure', message_type: :incoming) }

      before do
        attachment = msg.attachments.build(account_id: account.id, file_type: :file)
        attachment.save!
      end

      it 'includes generic attachment placeholder' do
        history = service.perform
        msg_hash = history.first
        expect(msg_hash[:content]).to be_an(Array)
        expect(msg_hash[:content]).to include({ type: 'text', text: 'Here is the brochure' })
        expect(msg_hash[:content]).to include({ type: 'text', text: 'User has shared an attachment' })
      end
    end

    # Test 8 — Captain agent context generation
    context 'with Captain assistant responses' do
      let(:captain_assistant) { create(:captain_assistant, account: account) }

      before do
        create(:message, conversation: conversation, account: account,
                         content: 'Hello, need help', message_type: :incoming)
        create(:message, conversation: conversation, account: account,
                         sender: captain_assistant, sender_type: 'Captain::Assistant',
                         content: 'Hello! How can I assist you today?', message_type: :outgoing,
                         additional_attributes: { agent_name: 'Captain Bot' })
      end

      it 'generates valid roles, content and agent_name metadata for Captain' do
        history = service.perform
        expect(history.size).to eq(2)
        expect(history[0][:role]).to eq('user')
        expect(history[0][:content]).to eq('Hello, need help')
        expect(history[1][:role]).to eq('assistant')
        expect(history[1][:content]).to eq('Hello! How can I assist you today?')
        expect(history[1][:agent_name]).to eq('Captain Bot')
      end
    end

    # Test 9 — Conversación sin mensajes
    context 'with an empty conversation' do
      it 'returns an empty array without raising any error' do
        expect(service.perform).to eq([])
      end
    end

    # Test 10 — Mensaje único
    context 'with a single message' do
      before do
        create(:message, conversation: conversation, account: account,
                         content: 'Sole message', message_type: :incoming)
      end

      it 'returns exactly one message in context' do
        history = service.perform
        expect(history.size).to eq(1)
        expect(history.first).to eq({ role: 'user', content: 'Sole message' })
      end
    end

    # Resolution marker preservation
    context 'with conversation resolution activity messages' do
      before do
        create(:message, conversation: conversation, account: account,
                         content: 'Help requested', message_type: :incoming, created_at: 10.minutes.ago)
        create(:message, conversation: conversation, account: account,
                         message_type: :activity,
                         content_attributes: { activity: { type: 'conversation_status_changed', status: 'resolved' } },
                         created_at: 5.minutes.ago)
        create(:message, conversation: conversation, account: account,
                         content: 'Follow-up inquiry', message_type: :incoming, created_at: 1.minute.ago)
      end

      it 'preserves resolution boundaries within the sliding window' do
        history = service.perform
        expect(history.size).to eq(3)
        expect(history[1]).to eq({ role: 'assistant', content: described_class::RESOLUTION_MARKER })
      end
    end
  end
end
