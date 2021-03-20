require './market.rb'
#require "../auberge.rb"

nyse = Ticker.where(:exchange => 'NYSE').all
spy_ticker = Ticker.where(:symbol => 'SPY').first

spy = proc do |debut, fin|
  buy  = spy_ticker.bars.sort_by {|b| (debut - b.time).abs }.first
  sell = spy_ticker.bars.sort_by {|b| (fin - b.time).abs }.first

  (sell.close / buy.close) - 1
end

def text_ari(buy: [], sell: [])
  unless buy.empty?
    `ruby /home/ari/servers/stocks/text_ari.rb buy #{buy.map {|b| b.ticker.symbol }}`
  end

  unless sell.empty?
    `ruby /home/ari/servers/stocks/text_ari.rb sell #{sell.map {|b| b.ticker.symbol }}`
  end
end

def uusi(txt); "<span id='future'>#{txt}</span>"; end
def money(num); "$%0.3f" % num; end
def perc(num); "%0.3f%%" % (num * 100); end

# download and save the latest information
# i acknowledge that this assumes that all tickers are updated at the same time
unless Time.parse((Date.today - 1).to_s) == nyse[5].bars.last.time
  puts "downloading data after #{nyse[5].bars.last.time}..."
  updates = Bar.download nyse, :after => (nyse[5].bars.last.time - SPANS['day'])
  puts "\tsaving data..."
  updates.each do |sym, bz|
    bz.each do |b|
      unless b.time == Time.parse(Date.today.to_s) && Time.now < Time.parse('17:00')
        b.save sym, 'day'
      end
    end
  end
  puts "\tdone!"
end

sim = Simulator.new :stocks => nyse, :after => '1 jan 2020', :before => Time.now
results = sim.run

# how well would we have done if we had just invested in SPY?
results.each do |h|
  sell_date = h[:sell] ? h[:sell].time : h[:buy].ticker.bars.last.time
  h[:spy] = spy[h[:buy].time, sell_date]
end

# could be the day after the deciding day, or it could be the deciding day (if
# there's no new bar after it, aka it's bleeding edge)
new_buys  = results.filter {|h| h[:buy].date >= Date.today }
new_sells = results.filter {|h| h[:sell] && h[:sell].date == Date.today }

text_ari :buy => new_buys, :sell => new_sells

#  <th><b>Symbol</b></th>
#  <th><b>10-Day Trade Volume</b></th>
#  <th><b>Buy Date</b></th>
#  <th><b>Buy Price</b></th>
#  <th><b>Days Held</b></th>
#  <th><b>ROI Threshold</b></th>
#  <th><b>Sell Price</b></th>
#  <th><b>Sell ROI</b></th>
#  <th><b>SPY ROI</b></th>

rows = results.sort_by {|r| r[:buy].date }.reverse.map do |rec|
  buy = rec[:buy]
  latest = buy.ticker.bars.last
  latest_roi = (latest.close / buy.open) - 1

  symbol     = "<a href='https://finance.yahoo.com/quote/" +
                 "#{buy.ticker.symbol}'>#{buy.ticker.symbol}</a>"
  symbol    += "*" if buy.id == nil # it means the price is adjusted to reflect a stock split
  vol_avg    = buy.volumes(:prior => 10).mean.round(0)
  buy_date   = buy.date == Date.today ? uusi(buy.date.strftime("%Y-%m-%d")) : buy.date.strftime("%Y-%m-%d")
  buy_price  = buy.date == Date.today ? uusi(money(buy.close)) : money(buy.open)
  days_held  = rec[:hold] ? rec[:hold] : Date.today - buy.date
  roi_thresh = perc([-0.05 * days_held + 7.5, 0].max)
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

out = <<-END
<!DOCTYPE HTML>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>stonk ideas</title>
    <link rel="stylesheet" type="text/css" href="/style.css" media="screen">
  </head>
<body>
<p id='intro'>
  <b><a href="/">aribrown.com</a></b> |
  generated (<b><span id='future'>#{Date.today.strftime "%Y-%m-%d"}</b></future>)
  by a program
</p>
<hr/>
<p>
  <div id='reasons'>
    i'm looking for:
    <br/>
    <ul>
      <li>30% price drop in 3 days</li>
      <li>Trading volume > 10,000,000 trades/day</li>
    </ul>
  </div>
</p>
<p>* next to a stock symbol means the price is adjusted to reflect a split/reverse-split that occurred after that date</p>
<p>drop occurs on one day, buy the next morning. prior 10 days is in reference to before the drop</p>
<p><b>sell only when the price has tripled (200% growth)</b></p>
<p><span id='future'>blue</span> figures are taken from the latest closing prices, since the price has not yet tripled</p>
<br/>
<table>
  <tr>
    <th><b>Symbol</b></th>
    <th><b>10-Day Trade Volume</b></th>
    <th><b>Buy Date</b></th>
    <th><b>Buy Price</b></th>
    <th><b>Days Held</b></th>
    <th><b>ROI Threshold</b></th>
    <th><b>Sell Date</b></th>
    <th><b>Sell Price</b></th>
    <th><b>Sell ROI</b></th>
    <th><b>SPY ROI</b></th>
  </tr>
END

rows.each do |row|
  out << "<tr>"
  row.each {|col| out << "<td>#{col}</td>" }
  out << "</tr>"
end

out << "</table></body></html>"
open("/home/ari/servers/default/public/files/stock_recs.html", "w") {|f| f.write out }
puts "file made!"

