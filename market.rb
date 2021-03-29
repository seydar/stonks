CONFIG = YAML.load File.read("config.yml")

require 'open-uri'
require 'alpaca/trade/api'
require 'alphavantagerb'
require './db.rb'
require './assessor.rb'
require './simulator.rb'
require 'statistics'
require 'histogram/array'

# Configure the Alpaca API
Alpaca::Trade::Api.configure do |config|
  config.endpoint   = "https://api.alpaca.markets"
  config.key_id     = "AKYX3PV15W7C6IVMFV7L"
  config.key_secret = "7lztPWuYcZFynkrun9RPhPcpmkC1iWztrGKZnIEW"
end

ALP_CLIENT = Alpaca::Trade::Api::Client.new
AV_CLIENT  = Alphavantage::Client.new :key => "GI387ZJ0874WXW5S"

class Alpaca::Trade::Api::Client
  # This takes care of the issue where I was not able to provide other options
  # to the GET request. Now, I can specify "before" and "after" IAW the API.
  def bars(timeframe, symbols, opts={})
    opts[:limit] ||= 100
    opts[:symbols] = symbols.join(',')

    validate_timeframe(timeframe)
    response = get_request(data_endpoint, "v1/bars/#{timeframe}", opts)
    json = JSON.parse(response.body)
    json.keys.each_with_object({}) do |symbol, hash|
      hash[symbol] = json[symbol].map { |bar| Alpaca::Trade::Api::Bar.new(bar) }
    end
  end 
end

##############################################################
# How do we define what a precipitous drop in stock price is?
#
# {-100..-0.3 => 99,
#  -0.3..-0.2 => 243,
#  -0.2..-0.1 => 2532,
#  -0.1.. 0   => 267752,
#   0  .. 0.1 => 309317,
#   0.1.. 0.2 => 3218,
#   0.2.. 0.3 => 377,
#   0.3.. 100 => 151}
#
# This is across the NYSE from 1 JAN 2019 to 31 DEC 2019.
##############################################################

