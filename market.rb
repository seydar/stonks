require 'yaml'
Dir.chdir File.dirname(File.expand_path(__FILE__))
CONFIG = YAML.load File.read("config.yml")

require 'open-uri'
require 'alpaca/trade/api'
require 'alphavantagerb'
require './db.rb'
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

  def stock_bars(symbol, opts={})
    opts[:limit] ||= 100
    opts[:timeframe] ||= '1Day'

    response = get_request(data_endpoint, "v2/stocks/#{symbol}/bars", opts)
    json = JSON.parse(response.body)
    p json
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

module Market
  module Stock
    extend self

    CLOSE = "16:00" # closing time of the markets
    DELAY = 15 * 60 # how long to wait (in sec) before grabbing data

    # Alpaca download but don't install
    def download(tickers, opts={})
      span = opts.delete(:span) || 'day'

      opts.each do |k, v| 
        if [String, Date, DateTime, Time].include? v.class
          opts[k] = DateTime.parse(v.to_s).to_s
        end
      end

      # `CLIENT.bars` returns a hash, so this will also merge them all
      # into one. key collision will only happen if the key is duplicated
      # in the `ticker` argument.
      symbols = tickers.map {|t| t.symbol }
      data = symbols.each_slice(50).map do |ticks|
        ALP_CLIENT.bars span, ticks, opts
      end.inject({}) {|h, v| h.merge v }

      # strip out any bar that could be from today's incomplete data
      data.each do |sym, bars|
        bars.delete_if do |bar|
          bar.date == Time.parse(Date.today.to_s) &&
          Time.now < (Time.parse(CLOSE) + DELAY)
        end
      end
    end

    def install(tickers, opts={})
      return {} if opts[:after] == Time.parse(Date.today.to_s)
      return {} if opts[:after] == Time.parse(Date.today.to_s) - 1.day &&
                   Time.now < (Time.parse(CLOSE) + DELAY)

      updates = download tickers, opts
      updates.map {|sym, bars| [sym, bars.map {|b| b.save sym, 'day' }] }.to_h
    end

    # can only do one stock at a time
    # AlphaVantage
    def download_stock(ticker, after: '1900-01-01', before: Date.today.strftime("%Y-%m-%d"))
      stock  = AV_CLIENT.stock :symbol => ticker.symbol
      series = stock.timeseries :outputsize => 'full'

      bars = series.output['Time Series (Daily)']
      bars = bars.filter {|k, bar| k > after && k < before }

      insertion = bars.map do |k, bar|
        {:date   => Time.parse(k),
         :open   => bar['1. open'].to_f,
         :high   => bar['2. high'].to_f,
         :low    => bar['3. low'].to_f,
         :close  => bar['4. close'].to_f,
         :volume => bar['5. volume'].to_i,
         :span   => 'day',
         :ticker_id => ticker.id
        }
      end
      #DB[:bars].multi_insert insertion
    end

    def install_stock(stock, **kwargs)
      DB[:bars].multi_insert stock, **kwargs
    end
  end

  module Futures
    def download(future: nil, after: '1900-01-01', before: Date.today.strftime("%Y-%m-%d"))
      url = "https://query1.finance.yahoo.com/v7/finance/download/" +
            "#{future.ymbol}?" +
            "period1=#{after.to_i}&" +
            "period2=#{before.to_i}&" +
            "interval=1d&events=history&includeAdjustedClose=true"
      user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_2_3) " +
                   "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 " +
                   "Safari/605.1.15"
      data = URI.open(url, "User-Agent" => user_agent) do |site|
        site.read
      end

      data.split("\n").map {|line| line.split "," }.map do |line|
        {:date  => Time.parse(line[0]),
         :open  => line[1].to_f,
         :high  => line[2].to_f,
         :low   => line[3].to_f,
         :close => line[5].to_f,
         :volume => line[6].to_f}
      end
    end
  end
end

