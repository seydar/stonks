require 'pry'
require './market.rb'

START = "1 jan #{ARGV[0] || 2020}"
FIN   = ARGV[0] ? "31 dec #{ARGV[0]}" : Date.today.strftime("%d %M %Y")

nyse = Ticker.where(:exchange => 'NYSE').all
if File.exists? "#{ARGV[0]}.sim"
  res = open("#{ARGV[0]}.sim", "r") {|f| Marshal.load f.read }
elsif ARGV[0] == "all"
  res = (2018..2021).map {|y| open("#{y}.sim", "r") {|f| Marshal.load f.read } }
                    .inject {|s, v| s + v }
else
  sim  = Simulator.new :stocks => nyse, :after => START, :before => FIN
  res  = sim.run
  open("#{ARGV[0]}.sim", "w") {|f| f.write Marshal.dump(res) }
end

timeline = res.map do |h|
  o = [{:action => :buy, :stock => h[:buy]}]
  o << {:action   => :sell,
        :stock    => h[:sell],
        :original => h[:buy],
        :ROI      => h[:ROI]} if h[:sell]
  o
end.flatten(1).sort_by {|r| r[:stock].date }

#################
# Static investment
#
# No reinvesting dividends to increase profits
# (the literal `1` below would be replaced by a growing figure)
puts "NO REINVEST"

cash       = 6.0
investment = 0.8
skip = []
running_total = timeline.inject([cash]) do |tally, trade|
  if trade[:action] == :sell && skip.include?(trade[:original])
    # nothing
  elsif trade[:action] == :buy && tally.last - investment < 0
    skip << trade[:stock]
  else

    if trade[:action] == :buy
      puts "buying #{trade[:stock].symbol} for #{investment}"
      tally << tally.last - investment
    else
      puts "selling #{trade[:stock].symbol} at #{(trade[:ROI] * 100).round(3)}% ($#{investment.round 3} => $#{(investment * (1 + trade[:ROI])).round(3)})"
      tally << tally.last + investment * (1 + trade[:ROI])
    end
    puts "\tcash: #{tally.last.round 3}"
  end

  tally
end

money_required = running_total.min.abs
efficacy = money_required / res.size.to_f
max_gains = running_total.last / running_total.first

################
# Reinvesting dividends
#
# This requires an assumption of efficacy, which leads us to the answer of
# how much money is required (what's the deepest in the hole we'll go). If I
# am investing $10K into this schema, when I get returns, I am now investing
# e.g. $12K into it. I was assuming I'd have to buy 10 stocks before getting
# a return, so now instead of $1K/stock, I can invest $1.2K/stock.
puts "REINVEST"

circulation = 4.0
pieces      = 5.0
investment  = Hash.new {|h, k| h[k] = circulation / pieces }
skip = []

running_reinvest = timeline.inject([circulation]) do |tally, trade|
  if trade[:action] == :sell && skip.include?(trade[:original])
    # nothing
  elsif trade[:action] == :buy && tally.last - investment[trade[:stock]] < 0
    skip << trade[:stock]
  else

    if trade[:action] == :buy
      puts "buying #{trade[:stock].symbol} for #{investment[trade[:stock]]}"
      tally << tally.last - investment[trade[:stock]]
    else
      puts "selling #{trade[:stock].symbol} at #{(trade[:ROI] * 100).round(3)}% ($#{investment[trade[:original]].round(3)} => $#{(investment[trade[:original]] * (1 + trade[:ROI])).round(3)})"
      profit = investment[trade[:original]] * trade[:ROI]
      tally << tally.last + investment[trade[:original]] + profit
      circulation += profit
    end

    puts "\tcash: #{tally.last.round 3}"
    puts "\tcirculation: #{circulation.round 3}"
  end

  tally
end

binding.pry

