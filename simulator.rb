require './market.rb'

# nyse = Ticker.where(:exchange => 'NYSE').all
# spy_ticker = Ticker.where(:symbol => 'SPY').first
# 
# spy = proc do |debut, fin|
#   debut = debut.is_a?(Time) ? debut : Time.parse(debut.to_s)
#   fin   = fin.is_a?(Time) ? fin : Time.parse(fin.to_s)
# 
#   buy   = spy_ticker.bars.filter {|b| b.time == debut }[0]
#   sell  = spy_ticker.bars.filter {|b| b.time == fin }[0]
#   (sell.close / buy.close) - 1
# end

######################################

class Simulator
  attr_accessor :results
  attr_accessor :assessor
  attr_accessor :stocks
  attr_accessor :after
  attr_accessor :before

  def initialize(stocks: nil, drop: -0.3, vol: 10_000_000, after: nil, before: nil)
    raise "Stocks and dates must be provided to the simulator" unless stocks && after && before

    @stocks = stocks
    @after  = after
    @before = before

    @assessor = Assessor.new
    @assessor.buy_when :history => 5 do |history|
      today     = history[-1]
      yesterday = history[-2]
    
      [(today.change_from(yesterday) <= drop or
        today.change_from(today)     <= drop),
       history.map {|b| b.volume }.mean >= vol
      ].all?
    end
    
    # drop = -0.3, vol > 10M, m = -0.05, b = 7.5
    @assessor.sell_when do |original, today|
      days_held = today.trading_days_from original
      
      m = -0.05
      b = 7.5
      sell_point = [m * days_held + b, 0].max
    
      today.change_from(original) >= sell_point
    end
  end

  def run
    @assessor.assess_buys @stocks, :after  => @after,
                                   :before => @before
    @results = @assessor.assess_sells
  end
end



# # TODO this doesn't make any sense. the max rise over a fluctuating period
# # of time? i don't even know what this is measuring.
# sells.each {|h| h[:max] = h[:hold] ? h[:buy].max_rise_over(h[:hold]) : [nil, -1] }
# 
# # filter out the crazy stocks that'll throw off the value
# # why don't i just use `#median`?
# sells = sells.filter {|h| h[:ROI] < 6 }
# 
# size       = sells.size
# max_roi    = sells.map {|h| h[:max][1] }
# max_roi  &&= max_roi.mean
# mean_roi   = sells.map {|h| h[:ROI] }
# mean_roi &&= mean_roi.mean
# 
# p [ARGV[0].to_i, size, max_roi, mean_roi]
