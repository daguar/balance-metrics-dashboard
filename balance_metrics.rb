require 'twilio-ruby'
require 'sinatra'
require 'time'
require 'rack/ssl'
require 'date'
require 'time'

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
    @phone_number_hash[number.phone_number] = funnel_name
  end
  all_messages = process_multipage_list(client.account.messages.list, Array.new)
  @successful_outbound_balance_texts = all_messages.select do |m|
    m.body.include?("Hi! Your food stamp balance is") && !m.to.include?("471446") && !m.to.include?("109902770")
  end
  @phone_numbers_with_a_successful_balance_check = @successful_outbound_balance_texts.map do |m|
    m.to
  end
  @number_of_unique_phone_numbers_with_a_successful_balance_check = @phone_numbers_with_a_successful_balance_check.uniq.count
  @number_of_phone_numbers_with_more_than_one_balance_check = @phone_numbers_with_a_successful_balance_check.group_by{|i| i}.map{|k,v| [k, v.count] }.select { |arr| arr[1] > 1 }.count
  @percent_of_users_with_more_than_one_success = (@number_of_phone_numbers_with_more_than_one_balance_check.to_f / @number_of_unique_phone_numbers_with_a_successful_balance_check.to_f) * 100
  @inbound_messages = all_messages.select { |m| m.direction == 'inbound' }
  erb :index
end

helpers do
  def process_multipage_list(list, return_array)
    list.each do |item|
      return_array << item
    end
    if list.next_page != []
      process_multipage_list(list.next_page, return_array)
    else
      return return_array
    end
  end
end
