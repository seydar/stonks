require 'pry'
require './market.rb'

def time
  start  = Time.now
  result = yield
  [Time.now - start, result]
end

drop = -0.3
nyse = Ticker.where(:exchange => 'NYSE').all
spy_ticker = Ticker.where(:symbol => 'SPY').first

#@data = market_turns nyse, :drop  => drop

solid = proc { @data.filter {|b| not b.before_split?(:days => 64) } }
r2s   = proc {|x| solid[].filter {|b| b.rsquared >= x } }
mses  = proc {|x| solid[].filter {|b| b.mse <= x } }
vols  = proc {|xs, v| xs.filter {|b| b.ticker.volume(:at => b).mean >= v } }
dates = proc {|xs, debut, fin| restrict_dates(xs, debut, fin) }
spy   = proc do |debut, fin|
  debut = debut.is_a?(Time) ? debut : Time.parse(debut.to_s)
  fin   = fin.is_a?(Time) ? fin : Time.parse(fin.to_s)

  buy  = spy_ticker.bars.filter {|b| b.time == debut }[0]
  sell = spy_ticker.bars.filter {|b| b.time == fin }[0]
  (sell.close / buy.close) - 1
end

#@data = market_turns nyse, :drop   => -0.25,
#                           :after  => "1 jan #{ARGV[0] || 2019}",
#                           :before => "31 dec #{ARGV[1] || 2019}"
#
#@data.each {|b| b.ticker.normalize! }
#@data = @data.map {|b| b.refresh }
#
#rises = @data.map {|b| [b, b.max_rise_over(90)] }
#
#filters = 1_000_000.step(:by => 100_000, :to => 10_000_000).map do |i|
#  [i, rises.filter {|r| r[0].volumes.mean > i }.map {|r| r[1][1] }.mean]
#end
#
#goods = rises.filter {|r| r[0].volumes.mean > 7_700_000 }
#goods.each {|g| g << g[0].time_to_rise(g[1][1]) }

assessor = Assessor.new
assessor.buy_when :history => 2 do |history|
  today     = history[-1]
  yesterday = history[-2]

  today.change_from(yesterday) <= -0.3 #or
    #today.change_from(today)   <= -0.3
end

assessor.sell_when do |ticker, original|
  today = ticker.history[-1]
  days_held = today.date - original.date

  today.change_from(original) >= sell_point(days_held)
end

#assessor.assess nyse, :after  => '1 jan 2019',
#                      :before => '31 dec 2019'

binding.pry
