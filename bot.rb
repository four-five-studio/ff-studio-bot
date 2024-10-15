require 'discordrb'
require 'dotenv'
require 'langchain'
require 'openai'
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
end

# Run the bot if this file is executed, but not when it is required
# helpful for testing
if __FILE__ == $0
  bot = Bot.new
  bot.run
end
