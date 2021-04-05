require './market.rb'
require './script/helpers.rb'
require 'erb'

spy_ticker = Ticker.where(:symbol => 'SPY').first

spy = proc do |debut, fin|
  buy  = spy_ticker.bars.sort_by {|b| (debut - b.date).abs }.first
  sell = spy_ticker.bars.sort_by {|b| (fin - b.date).abs }.first

  (sell.close / buy.close) - 1
end

years = {}
(2008..2021).each do |year|
  years[year] = simulate :year => year, :drop => -0.2, :folder => 'rank'
  years[year].each do |h|
    sell_date = h[:sell] ? h[:sell].date : h[:buy].ticker.bars.last.date
    h[:spy] = spy[h[:buy].date, sell_date]
  end
end

years.each do |year, data|
  out = {:year   => year,
         :num    => data.size,
         :mean   => data.map {|r| r[:ROI] }.mean,
         :median => data.map {|r| r[:ROI] }.median,
         :stddev => data.map {|r| r[:ROI] }.standard_deviation,
         :spy    => data.map {|r| r[:spy] }.mean,
         :sp500  => spy[Time.parse("1 jan #{year}"), Time.parse("31 dec #{year}")]
        }
  out[:sharpe] = out[:mean] / out[:stddev]

  years[year] = out
end

out = ERB.new(File.read("views/summary.erb")).result

open("views/summary.html", "w") {|f| f.write out }

