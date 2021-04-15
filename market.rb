require 'yaml'
Dir.chdir File.dirname(File.expand_path(__FILE__))
CONFIG = YAML.load File.read("config.yml")

require 'open-uri'
require 'alpaca/trade/api'
require 'alphavantagerb'
require './db.rb'
require './assessor.rb'
require './simulator.rb'
#require 'statistics' # only used by the mse/r^2 methods which aren't currently in use. this package is in conflict with the kder package
require 'kder'
require 'histogram/array'

Alpaca::Trade::Api.configure do |config|
  config.endpoint   = "https://api.alpaca.markets"
  config.key_id     = CONFIG[:Alpaca][:ID]
  config.key_secret = CONFIG[:Alpaca][:secret]
end

ALP_CLIENT = Alpaca::Trade::Api::Client.new
AV_CLIENT  = Alphavantage::Client.new :key => CONFIG[:AV][:key]

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

  # Enabling me to use the "qty" query parameter. Playing it extra safe
  # by not even sending the parameter unless there's a specified number
  def close_position(symbol: nil, qty: nil)
    response = delete_request(endpoint,
                              "v2/positions/#{symbol}#{qty ? "?qty=#{qty}" : ""}")
    raise NoPositionForSymbol,
          JSON.parse(response.body)['message'] if response.status == 404

    Position.new(JSON.parse(response.body))
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

