require 'discordrb'
require 'dotenv'
require 'langchain'
require 'openai'
require_relative '../bot'

RSpec.describe Bot do
  let(:bot_instance) { Bot.new }
  let(:event) { instance_double('Discordrb::Events::MessageEvent', message: message) }
  let(:message) { instance_double('Discordrb::Message', content: 'Ping!') }

  before do
    allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('fake_openai_api_key')
    allow(ENV).to receive(:[]).with('BOT_TOKEN').and_return('fake_bot_token')
    allow(ENV).to receive(:[]).with('CLIENT_ID').and_return('fake_client_id')
  end

  describe '#initialize' do
    it 'initializes the bot and LLM' do
      expect(bot_instance.instance_variable_get(:@llm)).to be_a(Langchain::LLM::OpenAI)
      expect(bot_instance.instance_variable_get(:@bot)).to be_a(Discordrb::Bot)
    end
  end

  describe '#handle_ping' do
    it 'responds with Pong!' do
      allow(event).to receive(:respond)
      expect(event).to receive(:respond).with('Pong!')
      bot_instance.send(:handle_ping, event)
    end
  end

  describe '#handle_chat' do
    let(:response) { 'Hello! How can I help you today' }
    let(:chat_response) { instance_double('Langchain::LLM::OpenAI::ChatResponse', chat_completion: response) }
    let(:llm) { instance_double('Langchain::LLM::OpenAI', chat: chat_response) }

    before do
      allow(bot_instance).to receive(:llm).and_return(llm)
      allow(bot_instance.instance_variable_get(:@llm)).to receive(:chat).and_return(chat_response)
      allow(event).to receive(:respond)
    end

    it 'responds with the chat completion' do
      expect(event).to receive(:respond).with('Hello! How can I help you today')
      bot_instance.send(:handle_chat, event)
    end

    context 'when the response is longer than 2000 characters' do
      let(:response) { ('abcdef ' * 286) }

      it 'chunks the response and sends multiple messages' do
        expect(event).to receive(:respond).with('abcdef ' * 285).ordered
        expect(event).to receive(:respond).with('abcdef').ordered
        bot_instance.send(:handle_chat, event)
      end
    end
  end
end
