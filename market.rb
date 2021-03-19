# stocks.rb
require 'pp'
require 'yaml'
require 'open-uri'
require 'alpaca/trade/api'
require './db.rb'
require './assessor.rb'
require './simulator.rb'
require 'statistics'
require 'histogram/array'

# Configure the Alpaca API
Alpaca::Trade::Api.configure do |config|
  config.endpoint   = "https://api.alpaca.markets"
  config.key_id     = "AKM406CX3NH9IO9PGC55"
  config.key_secret = "6NC5iRohh75TkdC6NBvOy2pEKhvYbnBPGPGaRFnM"
end

class Alpaca::Trade::Api::Client
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

CLIENT = Alpaca::Trade::Api::Client.new

SPANS  = {'day'   => 86400,
          '15min' => 900,
          '5min'  => 300,
          'min'   => 60}

class Array
  def median
    sort[size / 2]
  end
end

######
# TODO how do i define stock volatility? generally, it assumes a stable mean,
# but what happens when the mean is stably trending upwardss?
######

##############################################################
# How do we define what a precipitous drop in stock price is?
#
# {-100..-0.3 => 48,
#  -0.3..-0.2 => 155,
#  -0.2..-0.1 => 1589,
#  -0.1.. 0   => 106486,
#   0  .. 0.1 => 116388,
#   0.1.. 0.2 => 3102,
#   0.2.. 0.3 => 453,
#   0.3.. 100 => 242}
#
# These are across the NYSE, with an average of 70 days of data per stock.
# So over 70 days, how many trades do I want to take place?
# In theory, if I sell after making 10% back on the stocks
##############################################################

