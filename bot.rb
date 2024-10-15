require 'discordrb'
require 'dotenv'
require 'langchain'
require 'openai'
Dotenv.load

llm = Langchain::LLM::OpenAI.new(
  api_key: ENV["OPENAI_API_KEY"],
  default_options: { temperature: 0.7, chat_completion_model_name: "gpt-4o" }
)

bot = Discordrb::Bot.new token: ENV['BOT_TOKEN'],
  client_id: ENV['CLIENT_ID'],
  intents: [:server_messages]

puts "This bot's invite URL is #{bot.invite_url}"

bot.message(with_text: 'Ping!') do |event|
  p "received message: #{event.message.content}"
  event.respond 'Pong!'
end

bot.message(start_with: 'bot: ') do |event|
  messages = [
    { role: "system", content: "You are a helpful assistant." },
    { role: "user", content: event.message.content.gsub("bot: ", "") }
  ]
  response = llm.chat(messages: messages)
  chat_completion = response.chat_completion

  chat_completion.scan(/.{1,2000}\b/m).each do |chunk|
    event.respond chunk
  end
end

bot.run
