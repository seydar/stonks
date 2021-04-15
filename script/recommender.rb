require './market.rb'
require './script/helpers.rb'
require 'erb'

START = "1 jan #{ARGV[0] || 2021}"
FIN   = ARGV[0] ? "31 dec #{ARGV[0]}" : Date.today.strftime("%d %b %Y")
KIND  = ARGV[0] || "2021"

nyse = Ticker.where(:exchange => 'NYSE').all
spy_ticker = Ticker.where(:symbol => 'SPY').first

spy = proc do |debut, fin|
  buy  = spy_ticker.bars.sort_by {|b| (debut - b.date).abs }.first
  sell = spy_ticker.bars.sort_by {|b| (fin - b.date).abs }.first

  (sell.close / buy.close) - 1
end

def text_ari(buy: [], sell: [])
  unless buy.empty?
    `HOME=/home/ari; source /home/ari/.profile; ruby /home/ari/servers/stonks/script/text_ari.rb buy #{buy.map {|b| b[:buy].ticker.symbol }}`
  end

  unless sell.empty?
    `HOME=/home/ari; source /home/ari/.profile; ruby /home/ari/servers/stonks/script/text_ari.rb sell #{sell.map {|b| b[:sell].ticker.symbol }}`
  end
end

def uusi(txt); "<span id='future'>#{txt}</span>"; end
def money(num); "$%0.3f" % num; end
def perc(num); "%0.3f%%" % (num * 100); end

# download and save the latest information
# i acknowledge that this assumes that all tickers are updated at the same time
latest_bar = nyse[5].bars.last.date
unless Time.parse((Date.today - 1).to_s) < latest_bar
  puts "downloading data after #{latest_bar}..."
  updates = Bar.download nyse, :after => latest_bar
  updates.merge! Bar.download([spy_ticker], :after => spy_ticker.bars.last.date)

  puts "\tsaving data..."
  stocks_updated = 0
  updates.each do |sym, bz|
    bz.each do |b|
      unless b.date == Time.parse(Date.today.to_s) && Time.now < Time.parse('17:00')
        stocks_updated += 1
        b.save sym, 'day'
      end
    end
  end
  puts "\t#{stocks_updated} stocks updated"

  if stocks_updated > 0
    puts "building rankings..."
    `HOME=/home/ari; ruby script/build_rankings.rb #{latest_bar.strftime("%d %b %Y")}`
  end
end

# now a cache file will be produced for all of our hard work
results = simulate :year => KIND.to_i, :drop => -0.2, :force => true

# how well would we have done if we had just invested in SPY?
results.each do |h|
  sell_date = h[:sell] ? h[:sell].date : h[:buy].ticker.bars.last.date
  h[:spy] = spy[h[:buy].date, sell_date]
end

# could be the day after the deciding day, or it could be the deciding day (if
# there's no new bar after it, aka it's bleeding edge)
new_buys  = results.filter {|h| h[:buy].date >= latest_bar }
new_sells = results.filter {|h| h[:sell] && h[:sell].date >= latest_bar }
puts "buy:"
puts "\t#{new_buys.map {|t| t[:buy].ticker.symbol }.join ", "}"
puts "sell:"
puts "\t#{new_sells.map {|t| t[:buy].ticker.symbol }.join ", "}"

text_ari :buy => new_buys, :sell => new_sells

# <th><b>Symbol</b></th>
# <th><b>5-Day Trade Volume</b></th>
# <th><b>Buy Date</b></th>
# <th><b>Buy Price</b></th>
# <th><b>Days Held</b></th>
# <th><b>ROI Threshold</b></th>
# <th><b>Sell Date</b></th>
# <th><b>Sell Price</b></th>
# <th><b>Sell ROI</b></th>
# <th><b>SPY ROI</b></th>

# Just used for accessing some defaults. Should prolly move defaults
# to the config file
sim = Simulator.new

rows = results.sort_by {|r| r[:buy].date }.reverse.map do |rec|
  buy = rec[:buy]
  latest = buy.ticker.bars.last
  latest_roi = (latest.close / buy.open) - 1

  symbol     = "<a href='https://finance.yahoo.com/quote/" +
                 "#{buy.ticker.symbol}'>#{buy.ticker.symbol}</a>"
  vol_avg    = buy.volumes(:prior => 5).mean.round(0)
  buy_date   = buy.date == Date.today ? uusi(buy.date.strftime("%Y-%m-%d")) : buy.date.strftime("%Y-%m-%d")
  buy_price  = buy.date == Date.today ? uusi(money(buy.close)) : money(buy.open)
  days_held  = rec[:hold] ? rec[:hold] : buy.trading_days_from(latest)
  roi_thresh = perc([sim.m * days_held + sim.b, 0].max)
  days_held  = rec[:hold] ? days_held.to_i : uusi(days_held.to_i)
  roi_thresh = rec[:hold] ? roi_thresh : uusi(roi_thresh)
  sell_date  = rec[:sell] ? rec[:sell].date.strftime("%Y-%m-%d") : uusi("-")
  sell_price = rec[:sell] ? money(rec[:sell].close) : uusi(money(latest.close))
  sell_roi   = rec[:sell] ? perc(rec[:ROI]) : uusi(perc(latest_roi))
  spy_roi    = perc(rec[:spy])


  [symbol,
   vol_avg,
   buy_date,
   buy_price,
   days_held,
   roi_thresh,
   sell_date,
   sell_price,
   sell_roi,
   spy_roi]
end

mean_ROI       = perc(results.map {|r| r[:ROI] }.mean)
liquidated_ROI = results.map do |r|
  if r[:sell]
    r[:ROI]
  else
    (r[:buy].ticker.bars.last.close / r[:buy].open) - 1
  end
end.mean
liquidated_ROI = perc(liquidated_ROI)

out = ERB.new(File.read("views/table.erb")).result

#fname = "/home/ari/servers/default/public/files/stock_recs.#{KIND}.html"
fname = "views/stock_recs.#{KIND}.html"
open(fname, "w") {|f| f.write out }
puts "file made @ #{fname}"

