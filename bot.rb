require 'discordrb'
require 'dotenv'
require 'langchain'
require 'openai'
require 'http'
Dotenv.load

class Bot
  def initialize
    @llm = Langchain::LLM::OpenAI.new(
      api_key: ENV["OPENAI_API_KEY"],
      default_options: { temperature: 0.7, chat_completion_model_name: "gpt-4o" }
    )

    @bot = Discordrb::Bot.new token: ENV['BOT_TOKEN'],
                              client_id: ENV['CLIENT_ID'],
                              intents: [:server_messages]

    @bot.message(with_text: 'Ping!') do |event|
      handle_ping(event)
    end

    @bot.message(start_with: 'bot: ') do |event|
      handle_chat(event)
    end

    @bot.message(start_with: 'llama: ') do |event|
      handle_llama(event)
    end
  end

  def run
    @bot.run
  end

  private

  def handle_ping(event)
    p "received message: #{event.message.content}"
    event.respond 'Pong!'
  end

  def handle_chat(event)
    messages = [
      { role: "system", content: "You are a helpful assistant." },
      { role: "user", content: event.message.content.gsub("bot: ", "") }
    ]
    response = @llm.chat(messages: messages)
    chat_completion = response.chat_completion

    chat_completion.scan(/.{1,2000}\b/m).each do |chunk|
      event.respond chunk
    end
  end

  def handle_llama(event)
    response = HTTP.auth("Bearer #{ENV['REPLICATE_API_TOKEN']}")
                   .headers(content_type: 'application/json', prefer: 'wait')
                   .post("https://api.replicate.com/v1/models/meta/meta-llama-3-8b-instruct/predictions",
                         json: { input: { prompt: event.message.content.gsub("llama: ", "") } })

    if response.status.success?
      result = response.parse
      if result['output']
        result['output'].join.scan(/.{1,2000}\b/m).each do |chunk|
          event.respond chunk
        end
      else
        event.respond "Error: No output in response"
      end
    else
      event.respond "Error: #{response.status}"
    end
  end
end

# Run the bot if this file is executed, but not when it is required
# helpful for testing
if __FILE__ == $0
  bot = Bot.new
  bot.run
end
