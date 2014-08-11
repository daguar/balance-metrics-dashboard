require 'twilio-ruby'
require 'sinatra'
require 'time'
require 'rack/ssl'

use Rack::SSL unless settings.environment == :development
use Rack::Auth::Basic, "Restricted Area" do |username, password|
  username == ENV['USERNAME'] and password == ENV['PASSWORD']
end

get '/' do
  client = Twilio::REST::Client.new(ENV['TWILIO_BALANCE_PROD_SID'], ENV['TWILIO_BALANCE_PROD_AUTH'])
  @inbound_messages = client.account.messages.list.select { |m| m.direction == 'inbound' }
  @inbound_calls = client.account.calls.list.select { |m| m.direction == 'inbound' }
  erb :index
end

