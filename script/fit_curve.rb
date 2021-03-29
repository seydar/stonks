require './market.rb'
require 'pry'

assessor = Assessor.new
assessor.buy_when :history => 5 do |history|
  today     = history[-1]
  yesterday = history[-2]

  [(today.change_from(yesterday) <= -0.3 or
    today.change_from(today)     <= -0.3),
   history.map {|b| b.volume }.mean >= 10_000_000
  ].all?
end

nyse = Ticker.where(:exchange => 'NYSE').all
assessor.assess_buys nyse, :after  => "1 jan #{ARGV[0]}",
                           :before => "31 dec #{ARGV[0]}"
STDERR.puts "holding #{assessor.holding.size}"

0.00.step(:to => 0.1, :by => 0.005) do |m|
  m = -m

  0.step(:to => 6, :by => 0.1) do |b|
    STDERR.puts "m = #{m}, b = #{b}"

    assessor.sell_when do |original, today|
      days_held = today.trading_days_from original
      
      sell_point = [m * days_held + b, 0].max
    
      today.change_from(original) >= sell_point
    end

    sells = assessor.assess_sells

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
    
    puts [ARGV[0].to_i, m, b, size, max_roi, mean_roi].join(",")
  end
end
