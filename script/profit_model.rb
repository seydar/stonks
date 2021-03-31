require 'pry'
require './market.rb'
require './script/helpers.rb'

if ARGV[0] == "all"
  res = (2017..2020).map {|y| simulate :year => y, :folder => "#{ARGV[1]}_sim", :drop => -0.3 }
                    .inject {|s, v| s + v }
else
  res = simulate :year => ARGV[0], :folder => "#{ARGV[1]}_sim", :drop => -0.3
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

cash       = 15.0
investment = 1.0
skip_no_re = []
history_no_re = timeline.inject([cash]) do |tally, trade|
  if trade[:action] == :sell && skip_no_re.include?(trade[:original])
    # nothing
  elsif trade[:action] == :buy && tally.last - investment < 0
    skip_no_re << trade[:stock]
  else

    if trade[:action] == :buy
      puts "buying #{trade[:stock].ticker.symbol} for #{investment}"
      tally << tally.last - investment
    else
      puts "selling #{trade[:stock].ticker.symbol} at #{(trade[:ROI] * 100).round(3)}% ($#{investment.round 3} => $#{(investment * (1 + trade[:ROI])).round(3)})"
      tally << tally.last + investment * (1 + trade[:ROI])
    end
    puts "\tcash: #{tally.last.round 3}"
  end

  tally
end

################
# Reinvesting dividends
#
# This requires an assumption of efficacy, which leads us to the answer of
# how much money is required (what's the deepest in the hole we'll go). If I
# am investing $10K into this schema, when I get returns, I am now investing
# e.g. $12K into it. I was assuming I'd have to buy 10 stocks before getting
# a return, so now instead of $1K/stock, I can invest $1.2K/stock.
puts "REINVEST"

circulation = 15.0
pieces      = 10.0
investment  = Hash.new {|h, k| h[k] = circulation / pieces }
skip_re = []

history_re = timeline.inject([circulation]) do |tally, trade|
  if trade[:action] == :sell && skip_re.include?(trade[:original])
    # nothing
  elsif trade[:action] == :buy && tally.last - investment[trade[:stock]] < 0
    skip_re << trade[:stock]
  else

    if trade[:action] == :buy
      puts "buying #{trade[:stock].ticker.symbol} for #{investment[trade[:stock]]}"
      tally << tally.last - investment[trade[:stock]]
    else
      puts "selling #{trade[:stock].ticker.symbol} at #{(trade[:ROI] * 100).round(3)}% ($#{investment[trade[:original]].round(3)} => $#{(investment[trade[:original]] * (1 + trade[:ROI])).round(3)})"
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

