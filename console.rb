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

sell = proc do |bought, bar|

  days = (bar.time - bought.time) / SPANS['day']

  if    days > 90
    return true if bar.change_from(bought) >= 0.5
    return true if bar.change_from(bar.history[-2]) >= 0.5
  elsif days > 45
    return true if bar.change_from(bought) >= 0.5
    return true if bar.change_from(bar.history[-2]) >= 0.5
  elsif days > 20
    return true if bar.change_from(bought) >= 0.5
    return true if bar.change_from(bar.history[-2]) >= 0.5
  elsif days > 10
    return true if bar.change_from(bought) >= 0.5
    return true if bar.change_from(bar.history[-2]) >= 0.5
  else
    return true if bar.change_from(bought) >= 0.5
    return true if bar.change_from(bar.history[-2]) >= 0.5
  end

end

@data = market_turns nyse, :drop   => -0.25,
                           :after  => "1 jan #{ARGV[0] || 2019}",
                           :before => "31 dec #{ARGV[1] || 2019}"

@data.each {|b| b.ticker.normalize! }
@data = @data.map {|b| b.refresh }

rises = @data.map {|b| [b, b.max_rise_over(90)] }

filters = 1_000_000.step(:by => 100_000, :to => 10_000_000).map do |i|
  [i, rises.filter {|r| r[0].volumes.mean > i }.map {|r| r[1][1] }.mean]
end

goods = rises.filter {|r| r[0].volumes.mean > 7_700_000 }
goods.each {|g| g << g[0].time_to_rise(g[1][1]) }

binding.pry
