require 'pry'
require './market.rb'

class Array
  def median
    sort[size / 2]
  end
end

def time
  start  = Time.now
  result = yield
  [Time.now - start, result]
end

nyse = Ticker.where(:exchange => 'NYSE').all
spy_ticker = Ticker.where(:symbol => 'SPY').first

spy = proc do |debut, fin|
  debut = debut.is_a?(Time) ? debut : Time.parse(debut.to_s)
  fin   = fin.is_a?(Time) ? fin : Time.parse(fin.to_s)

  buy  = spy_ticker.bars.sort_by {|b| (debut - b.time).abs }.first
  sell = spy_ticker.bars.sort_by {|b| (fin - b.time).abs }.first

  (sell.close / buy.close) - 1
end

binding.pry

