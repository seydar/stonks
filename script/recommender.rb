require './market.rb'

START = "1 jan #{ARGV[0] || 2021}"
FIN   = ARGV[0] ? "31 dec #{ARGV[0]}" : Date.today.strftime("%d %b %Y")
KIND  = ARGV[0] || "2021"

nyse = Ticker.where(:exchange => 'NYSE').all
spy_ticker = Ticker.where(:symbol => 'SPY').first

spy = proc do |debut, fin|
  buy  = spy_ticker.bars.sort_by {|b| (debut - b.time).abs }.first
  sell = spy_ticker.bars.sort_by {|b| (fin - b.time).abs }.first

  (sell.close / buy.close) - 1
end

def text_ari(buy: [], sell: [])
  unless buy.empty?
    `ruby /home/ari/servers/stocks/text_ari.rb buy #{buy.map {|b| b[:buy].ticker.symbol }}`
  end

  unless sell.empty?
    `ruby /home/ari/servers/stocks/text_ari.rb sell #{sell.map {|b| b[:sell].ticker.symbol }}`
  end
end

def uusi(txt); "<span id='future'>#{txt}</span>"; end
def money(num); "$%0.3f" % num; end
def perc(num); "%0.3f%%" % (num * 100); end

# download and save the latest information
# i acknowledge that this assumes that all tickers are updated at the same time
unless Time.parse((Date.today - 1).to_s) == nyse[5].bars.last.time
  puts "downloading data after #{nyse[5].bars.last.time}..."
  updates = Bar.download nyse, :after => nyse[5].bars.last.time
  updates.merge! Bar.download([spy_ticker], :after => spy_ticker.bars.last.time)

  puts "\tsaving data..."
  stocks_updated = 0
  updates.each do |sym, bz|
    bz.each do |b|
      stocks_updated += 1

      unless b.time == Time.parse(Date.today.to_s) && Time.now < Time.parse('17:00')
        b.save sym, 'day'
      end
    end
  end
  puts "\t#{stocks_updated} stocks updated"
end

sim = Simulator.new :stocks => nyse, :after => START, :before => FIN
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

rows = results.sort_by {|r| r[:buy].date }.reverse.map do |rec|
  buy = rec[:buy]
  latest = buy.ticker.bars.last
  latest_roi = (latest.close / buy.open) - 1

  symbol     = "<a href='https://finance.yahoo.com/quote/" +
                 "#{buy.ticker.symbol}'>#{buy.ticker.symbol}</a>"
  vol_avg    = buy.volumes(:prior => 5).mean.round(0)
  buy_date   = buy.date == Date.today ? uusi(buy.date.strftime("%Y-%m-%d")) : buy.date.strftime("%Y-%m-%d")
  buy_price  = buy.date == Date.today ? uusi(money(buy.close)) : money(buy.open)
  days_held  = rec[:hold] ? rec[:hold] : Date.today - buy.date
  roi_thresh = perc([-0.05 * days_held + 4.6, 0].max)
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
  <a href='/files/stock_recs.2021.html'>2021</a> |
  <a href='/files/stock_recs.2020.html'>2020</a> |
  <a href='/files/stock_recs.2019.html'>2019</a> |
  <a href='/files/stock_recs.2018.html'>2018</a>
</p>
<p>
  <div id='reasons'>
    buy when:
    <br/>
    <ul>
      <li>30% price drop in 2 days</li>
      <li>Trading volume > 10,000,000 trades/day</li>
    </ul>

    sell when:
    <br/>
    <ul>
      <li>(fraction, not a percentage) ROI > -0.05 * trading_days_held + 4.6</li>
    </ul>
  </div>
</p>
<p>prices may be adjusted to reflect a split/reverse-split that occurred after that date</p>
<p>drop occurs on one day, buy the next morning. prior 5 days is including the day of the drop</p>
<p><span id='future'>blue</span> figures are taken from the latest closing prices, since the threshold to sell has not yet been reached</p>
<br/>
<p>SPY ROI for #{START.upcase} - #{FIN.upcase}: #{uusi(perc(spy[Time.parse(START), Time.parse(FIN)]))}</p>
<p>mean ROI for trades shown: #{uusi(mean_ROI)}</p>
<p>mean ROI if you were to also sell everything you're still holding: #{uusi(liquidated_ROI)}</p>
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
fname = "/home/ari/servers/default/public/files/stock_recs.#{KIND}.html"
open(fname, "w") {|f| f.write out }
puts "file made @ #{fname}"

