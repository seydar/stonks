require '/home/ari/servers/stocks/market.rb'
#require "../auberge.rb"

nyse = Ticker.where(:exchange => 'NYSE').all
spy_ticker = Ticker.where(:symbol => 'SPY').first

spy = proc do |debut, fin|
  buy  = spy_ticker.bars.sort_by {|b| (debut - b.time).abs }.first
  sell = spy_ticker.bars.sort_by {|b| (fin - b.time).abs }.first

  (sell.close / buy.close) - 1
end

# download and save the latest information
# i acknowledge that this assumes that all tickers are updated at the same time
unless Time.parse((Date.today - 1).to_s) == nyse[5].bars.last.time
  puts "downloading data..."
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

# find the stocks that have had a downturn
drop = -0.3
data = market_turns nyse, :drop  => drop,
                          :after => Time.parse("1 april 2020")

weekdays = 64 # 90 days, including weekends
mse  = 0.12
rise = 2.0
days = (weekdays * 7.0 / 5).floor # includes weekends
recs = data.filter {|b| b.mse <= mse }.reverse

# text me
new_recs = recs.filter {|b| b.time == Time.parse(Date.today.to_s) }
if new_recs.size > 0
  #Auberge::Phone.sms :to => "16037297097", :body => "invest in #{new_recs.map {|b| b.ticker.symbol }.join ', '}"
  `ruby /home/ari/servers/stocks/text_ari.rb #{new_recs.map {|b| b.ticker.symbol }}`
end

rows = recs.map do |rec|
  bz = rec.ticker.bars
  buy_bar_i  = bz.index(rec) + 1
  buy_bar    = bz[buy_bar_i] # buy the next morning
  buy_bar  ||= rec # yes it's a little wrong, but oh well
  wait_time  = buy_bar.time_to_rise rise # rise by 200%, tripling in price

  if buy_bar.before_split? :days => wait_time
    puts "normalizing #{rec.ticker.symbol}"
    rec.ticker.normalize!
    rec = bz[buy_bar_i - 1]
    wait_time = buy_bar.time_to_rise rise # rise by 200%, tripling in price
  end

  sell_bar   = wait_time == -1 ? bz[-1] : bz[buy_bar_i + wait_time]
  sell_date  = sell_bar.time
  sell_price = "$%0.3f" % sell_bar.close
  sell_roi   = "%0.3f%%" % ((100 * sell_bar.close / buy_bar.open) - 100)
  market_roi = "%0.3f%%" % (100 * spy[buy_bar.time, sell_date]) # i'm repeating myself but i don't care

  #if wait_time == -2 #buy_bar.before_split? :days => wait_time
  #  sell_price = "<span id='split'>split</span>"
  #  sell_roi   = sell_price
  #  market_roi = sell_price
  #end

  if wait_time == -1
    sell_price = "<span id='future'>#{sell_price}</span>"
    sell_roi   = "<span id='future'>#{sell_roi}</span>"
    market_roi = "<span id='future'>#{market_roi}</span"
  end

  symbol = "<a href='https://finance.yahoo.com/quote/#{rec.ticker.symbol}'>#{rec.ticker.symbol}</a>"

  [symbol,
   rec.mse.round(5),
   rec.rsquared.round(5),
   buy_bar.time.strftime("%Y-%m-%d"),
   "$%0.3f" % buy_bar.open,
   sell_date.strftime("%Y-%m-%d"),
   wait_time,
   sell_price,
   sell_roi,
   market_roi]
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
      <li>30% price drop in 2 days</li>
      <li>MSE <= 0.12 on a regression of the prior 10 days</li>
    </ul>
  </div>
</p>
<p>drop occurs on one day, buy the next morning. prior 10 days is in reference to before the drop</p>
<p><b>sell only when the price has tripled (200% growth)</b></p>
<p><span id='future'>blue</span> figures are taken from the latest closing prices, since the price has not yet tripled</p>
<br/>
<table>
  <tr>
    <th><b>Symbol</b></th>
    <th><b>10-Day MSE</b></th>
    <th><b>10-Day R^2</b></th>
    <th><b>Buy Date</b></th>
    <th><b>Buy Price</b></th>
    <th><b>Sell Date</b></th>
    <th><b>Time to Rise</b></th>
    <th><b>Sell Price</b></th>
    <th><b>Sell ROI</b></th>
    <th><b>Market ROI</b></th>
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

