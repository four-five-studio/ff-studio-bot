require 'discordrb'
require 'dotenv'
Dotenv.load

bot = Discordrb::Bot.new token: ENV['BOT_TOKEN'],
  client_id: ENV['CLIENT_ID'],
  intents: [:server_messages]

puts "This bot's invite URL is #{bot.invite_url}"

bot.message(with_text: 'Ping!') do |event|
  p "received message: #{event.message.content}"
  event.respond 'Pong!'
end

bot.run
