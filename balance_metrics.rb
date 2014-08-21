require 'twilio-ruby'
require 'sinatra'
require 'time'
require 'rack/ssl'
require 'date'
require 'time'
require 'plotly'
require 'pry'

if settings.environment != :development
  use Rack::SSL unless settings.environment == :development
  use Rack::Auth::Basic, "Restricted Area" do |username, password|
    username == ENV['USERNAME'] and password == ENV['PASSWORD']
  end
end

get '/' do
  # Get raw stats
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
  @inbound_messages = all_messages.select { |m| m.direction == 'inbound' }
  all_calls = process_multipage_list(client.account.calls.list, Array.new)
  @inbound_calls = all_calls.select { |m| m.direction == 'inbound' }

  # Let's make some chartsz!!
  plotly = PlotLy.new(ENV['PLOTLY_USERNAME'], ENV['PLOTLY_API_KEY'])

  # Get data for totals
  @balance_dates = []
  @successful_outbound_balance_texts.each do |sms|
    @balance_dates << Date.parse(sms.date_sent).to_date
  end

  @balance_hash = Hash[@balance_dates.group_by {|x| x}.map {|k,v| [k,v.count]}]
  y = @balance_hash.values.reverse
  sum = 0
  @y_cumulative = y.map { |i| sum += i }
  total_trace = {
    'name' => 'Total successful checks',
    'x' => @balance_hash.keys.map { |d| d.strftime }.reverse,
    'y' => @y_cumulative
  }

  # Get data by phone number
  @data = [total_trace]

  # Get source > msg hash
  source_hash = @successful_outbound_balance_texts.group_by { |sms| sms.from }
  source_hash.keys.each do | source | # Loop through each source
    @date_array = []
    source_hash[source].each do | sms |
      @date_array << Date.parse(sms.date_sent).to_date
    end
    @source_date_hash = Hash[@date_array.group_by {|x| x}.map {|k,v| [k,v.count]}]
    y = @source_date_hash.values.reverse
    sum = 0
    @y_cumulative = y.map { |i| sum += i }

  trace = {
    'name' => @phone_number_hash[source],
    'x' => @source_date_hash.keys.map { |d| d.strftime }.reverse,
    'y' => @y_cumulative
  }

  @data << trace
  end

  layout = {
    style: { type: 'scatter' },
    layout: {
      title: 'Balance Metrics'
    },
    world_readable: true
  }

  @chart_url = ""
  plotly.plot(data = @data, layout = layout) do |response|
    @chart_url = response['url']
  end

  # Render index
  erb :index
end

helpers do
  # def cumulative_sum(array)
  #   sum = 0
  #   array.map{|x| sum += x}
  # end

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