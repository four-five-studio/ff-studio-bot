require 'discordrb'
require 'dotenv'
require 'langchain'
require 'openai'
require 'http'
require_relative '../bot'

RSpec.describe Bot do
  let(:bot_instance) { Bot.new }
  let(:event) { instance_double('Discordrb::Events::MessageEvent', message: message) }
  let(:message) { instance_double('Discordrb::Message', content: 'Ping!') }

  before do
    allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('fake_openai_api_key')
    allow(ENV).to receive(:[]).with('BOT_TOKEN').and_return('fake_bot_token')
    allow(ENV).to receive(:[]).with('CLIENT_ID').and_return('fake_client_id')
    allow(ENV).to receive(:[]).with('REPLICATE_API_TOKEN').and_return('fake_replicate_api_token')
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

  describe '#handle_llama' do
    let(:response_body) { { 'output' => ['Llama response'] }.to_json }
    let(:http_response) { instance_double('HTTP::Response', status: status, parse: JSON.parse(response_body)) }
    let(:status) { instance_double('HTTP::Response::Status', success?: true) }

    before do
      allow(HTTP).to receive(:auth).and_return(HTTP)
      allow(HTTP).to receive(:headers).and_return(HTTP)
      allow(HTTP).to receive(:post).and_return(http_response)
      allow(event).to receive(:respond)
    end

    it 'responds with the llama output' do
      expect(event).to receive(:respond).with('Llama response')
      bot_instance.send(:handle_llama, event)
    end

    context 'when the response is longer than 2000 characters' do
      let(:response_body) { { 'output' => Array.new(286, 'abcdef ') }.to_json }

      it 'chunks the response and sends multiple messages' do
        expect(event).to receive(:respond).with('abcdef ' * 285).ordered
        expect(event).to receive(:respond).with('abcdef').ordered
        bot_instance.send(:handle_llama, event)
      end
    end

    context 'when the response does not contain output' do
      let(:response_body) { {}.to_json }

      it 'responds with an error message' do
        expect(event).to receive(:respond).with('Error: No output in response')
        bot_instance.send(:handle_llama, event)
      end
    end

    context 'when the response status is not successful' do
      let(:status) { instance_double('HTTP::Response::Status', success?: false) }

      it 'responds with an error message' do
        expect(event).to receive(:respond).with("Error: #{status}")
        bot_instance.send(:handle_llama, event)
      end
    end
  end
end
