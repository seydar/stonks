require './market.rb'

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
    `ruby /home/ari/servers/stonks/script/text_ari.rb buy #{buy.map {|b| b[:buy].ticker.symbol }}`
  end

  unless sell.empty?
    `ruby /home/ari/servers/stonks/script/text_ari.rb sell #{sell.map {|b| b[:sell].ticker.symbol }}`
  end
end

def uusi(txt); "<span id='future'>#{txt}</span>"; end
def money(num); "$%0.3f" % num; end
def perc(num); "%0.3f%%" % (num * 100); end

# download and save the latest information
# i acknowledge that this assumes that all tickers are updated at the same time
latest_bar = nyse[5].bars.last.date
unless Time.parse((Date.today - 1).to_s) <= latest_bar
  puts "downloading data after #{latest_bar}..."
  updates = Bar.download nyse, :after => latest_bar
  updates.merge! Bar.download([spy_ticker], :after => spy_ticker.bars.last.date)

  puts "\tsaving data..."
  stocks_updated = 0
  updates.each do |sym, bz|
    bz.each do |b|
      stocks_updated += 1

      unless b.date == Time.parse(Date.today.to_s) && Time.now < Time.parse('17:00')
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
<br/>
<div style='display: inline-block;'>
  <table>
    <tr>
      <th>Year</th>
      <th># of Buys</th>
      <th>Mean ROI</th>
      <th>SPY ROI</th>
    </tr>
    <tr>
      <td><a href="/files/stock_recs.2021.html">2021</a></td>
      <td>24</td>
      <td>-34.459%</td>
      <td>3.651%</td>
    </tr>
    <tr>
      <td><a href="/files/stock_recs.2020.html">2020</a></td>
      <td>99</td>
      <td>81.908%</td>
      <td>16.162%</td>
    </tr>
    <tr>
      <td><a href="/files/stock_recs.2019.html">2019</a></td>
      <td>11</td>
      <td>74.797%</td>
      <td>28.785%</td>
    </tr>
    <tr>
      <td><a href="/files/stock_recs.2018.html">2018</a></td>
      <td>5</td>
      <td>48.628%</td>
      <td>-7.013%</td>
    </tr>
    <tr>
      <td><a href="/files/stock_recs.2017.html">2017</a></td>
      <td>1</td>
      <td>-100.00%</td>
      <td>19.384%</td>
    </tr>
    <tr>
      <td><a href="/files/stock_recs.2016.html">2016</a></td>
      <td>9</td>
      <td>16.663%</td>
      <td>9.643</td>
    </tr>
    <tr>
      <td><a href="/files/stock_recs.2015.html">2015</a></td>
      <td>6</td>
      <td>12.530%</td>
      <td>-0.812%</td>
    </tr>
    <tr>
      <td><a href="/files/stock_recs.2014.html">2014</a></td>
      <td>3</td>
      <td>10.495%</td>
      <td>11.289%</td>
    </tr>
    <tr>
      <td><a href="/files/stock_recs.2013.html">2013</a></td>
      <td>2</td>
      <td>3.729%</td>
      <td>29.689%</td>
    </tr>
    <tr>
      <td><a href="/files/stock_recs.2012.html">2012</a></td>
      <td>5</td>
      <td>61.324%</td>
      <td>13.474%</td>
    </tr>
    <tr>
      <td><a href="/files/stock_recs.2011.html">2011</a></td>
      <td>4</td>
      <td>14.042%</td>
      <td>-0.199%</td>
    </tr>
    <tr>
      <td><a href="/files/stock_recs.2010.html">2010</a></td>
      <td>1</td>
      <td>-100.000%</td>
      <td>12.841%</td>
    </tr>
    <tr>
      <td><a href="/files/stock_recs.2009.html">2009</a></td>
      <td>18</td>
      <td>107.637%</td>
      <td>23.493%</td>
    </tr>
    <tr>
      <td><a href="/files/stock_recs.2008.html">2008</a></td>
      <td>49</td>
      <td>43.304%</td>
      <td>-37.735%</td>
    </tr>
  </table>
</div>
<div style='display: inline-block; vertical-align: top; padding-left: 20px;'>
  <br/>
  <br/>
  <p>
    a full explanation is available <b><a href="/files/stocks.html">here</a></b>
  </p>
  <br/>
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
</div>
<br/>
<center><h2>#{START.upcase} - #{FIN.upcase}</h2></center>
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

