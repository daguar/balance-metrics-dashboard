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
  @phone_number_hash = Hash.new
  client.account.incoming_phone_numbers.list.each do |number|
    funnel_name = number.friendly_name
    funnel_name.slice!('balance-')
    @phone_number_hash[number.phone_number] = funnel_name
  end
  @successful_outbound_balance_texts = client.account.messages.list.select do |m|
    m.body.include?("Hi! Your food stamp balance is") && !m.to.include?("471446") && !m.to.include?("109902770")
  end
  @inbound_messages = client.account.messages.list.select { |m| m.direction == 'inbound' }
  @inbound_calls = client.account.calls.list.select { |m| m.direction == 'inbound' }
  erb :index
end

