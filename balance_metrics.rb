require 'twilio-ruby'
require 'sinatra'
require 'time'
require 'rack/ssl'

if settings.environment != :development
  use Rack::SSL unless settings.environment == :development
  use Rack::Auth::Basic, "Restricted Area" do |username, password|
    username == ENV['USERNAME'] and password == ENV['PASSWORD']
  end
end

get '/' do
  client = Twilio::REST::Client.new(ENV['TWILIO_BALANCE_PROD_SID'], ENV['TWILIO_BALANCE_PROD_AUTH'])
  @successful_transcriptions = client.account.transcriptions.list.select do |t|
    t.transcription_text.include?("Your food stamp balance is")
  end
  # Subtract Dave's initial text
  @real_transcriptions_count = @successful_transcriptions.count - 1
  @inbound_messages = client.account.messages.list.select { |m| m.direction == 'inbound' }
  @inbound_calls = client.account.calls.list.select { |m| m.direction == 'inbound' }
  erb :index
end

