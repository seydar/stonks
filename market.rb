# stocks.rb
require 'pp'
require 'yaml'
require 'open-uri'
require 'alpaca/trade/api'
require './db.rb'
require './assessor.rb'
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


# sell the shares after so-many days
def profits(market_turns, rise: 2)
  num = market_turns.size
  times = market_turns.map {|b| b.time_to_rise_norm(rise) }
  fails = times.count -1
  [((num - fails) * rise.to_f - fails) / num, fails, (num - fails), times.mean]
end

# 0.1.step(:to => 3.0, :by => 0.1).map do |x|
#   [x] + profts(mses[0.12], :rise => x)
# end
#
# => [[0.1, 0.045000000000000005, 2, 38, 30.175],
#     [0.2, 0.08, 4, 36, 42.55],
#     [0.30000000000000004, 0.17, 4, 36, 45.175],
#     [0.4, 0.225, 5, 35, 46.275],
#     [0.5, 0.275, 6, 34, 49.8],
#     [0.6, 0.32, 7, 33, 48.425],
#     [0.7000000000000001, 0.4025, 7, 33, 49.35],
#     [0.8, 0.44000000000000006, 8, 32, 48.475],
#     [0.9, 0.52, 8, 32, 51.775],
#     [1.0, 0.6, 8, 32, 56.275],
#     [1.1, 0.6275000000000001, 9, 31, 57.175],
#     [1.2000000000000002, 0.6500000000000001, 10, 30, 56.725],
#     [1.3000000000000003, 0.7250000000000002, 10, 30, 61.2],
#     [1.4000000000000001, 0.8000000000000002, 10, 30, 61.775],
#     [1.5000000000000002, 0.8125000000000002, 11, 29, 62.425],
#     [1.6, 0.8200000000000001, 12, 28, 69.125],
#     [1.7000000000000002, 0.8900000000000002, 12, 28, 69.35],
#     [1.8000000000000003, 0.8900000000000002, 13, 27, 64.9],
#     [1.9000000000000001, 0.9575000000000001, 13, 27, 65.325],
#     [2.0, 1.025, 13, 27, 69.65],
#     [2.1, 1.0925, 13, 27, 70.475],
#     [2.2, 1.1600000000000001, 13, 27, 70.925],
#     [2.3000000000000003, 1.2275000000000003, 13, 27, 74.0],
#     [2.4000000000000004, 1.2950000000000004, 13, 27, 77.2],
#     [2.5000000000000004, 1.3625000000000003, 13, 27, 77.575],
#     [2.6, 1.4300000000000002, 13, 27, 78.375],
#     [2.7, 1.4975, 13, 27, 79.4],
#     [2.8000000000000003, 1.5650000000000002, 13, 27, 79.675],
#     [2.9000000000000004, 1.5350000000000001, 14, 26, 76.975],
#     [3.0, 1.5, 15, 25, 72.125]]
