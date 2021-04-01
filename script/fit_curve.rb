require './market.rb'
require './script/helpers.rb'
require 'pry'

####################
# Informational output is sent to STDERR because this program is meant
# to be piped into a file for later processing.
####################
data = (2018..2020).map do |year|
  simulate :year => year, :folder => 'rank', :drop => -0.2
end
data = data.map {|res| res.map {|r| r[:buy] } }.flatten

ass = Assessor.new
ass.holding = data

0.00.step(:to => 0.1, :by => 0.005) do |m|
  m = -m

  0.step(:to => 6, :by => 0.1) do |b|
    STDERR.puts "m = #{m}, b = #{b}"

    ass.sell_when do |original, today|
      days_held = today.trading_days_from original
      
      sell_point = [m * days_held + b, 0].max
    
      today.change_from(original) >= sell_point
    end
    sells = ass.assess_sells

    sells.each do |h|
      h[:max] = if h[:hold]
                  h[:buy].max_rise_over(h[:hold] + 30)
                else
                  [nil, -1]
                end
    end
    
    # filter out the crazy stocks that'll throw off the value
    sells = sells.filter {|h| h[:ROI] < 6 }
    
    # why don't i just use `#median` instead of `#mean`?
    size       = sells.size
    max_roi    = sells.map {|h| h[:max][1] }
    max_roi  &&= max_roi.mean
    mean_roi   = sells.map {|h| h[:ROI] }
    mean_roi &&= mean_roi.mean
    prof       = profit sells, :pieces => 30, :reinvest => true
    
    puts [ARGV[0].to_i, m, b, size, max_roi, mean_roi, prof[:cash]].join(",")
  end
end
