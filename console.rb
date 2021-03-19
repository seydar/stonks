require 'pry'
require './market.rb'

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

  buy   = spy_ticker.bars.filter {|b| b.time == debut }[0]
  sell  = spy_ticker.bars.filter {|b| b.time == fin }[0]
  (sell.close / buy.close) - 1
end

binding.pry

