module Algorithms
  class Stocks < Simulator
    attr_accessor :m
    attr_accessor :b
  
    def initialize(stocks:  nil,
                   drop:   -0.2,
                   rank:    60,
                   m:      -0.02,
                   b:       5.2,
                   after:   nil,
                   before:  nil)
      super(:stocks => stocks,
            :after => after,
            :before => before)
      @m = m
      @b = b
  
      assessor.buy_when :history => 2 do |history|
        today     = history[-1]
        yesterday = history[-2]
      
        [[today.change_from(yesterday) <= drop,
          today.change_from(today)     <= drop].any?,
  
         today.rank <= rank
        ].all?
      end
      
      # for ROI: m = -0.03, b = 3.0
      # for $$$: m = -0.02, b = 5.2
      #      or: m = -0.00, b = 0.6
      #      (those two average roughly the same from 2008-2020)
      #
      # honestly i've done a terrible job of evaluating the different
      # sell signals
      #
      # TODO suck less
      assessor.sell_when do |original, today|
        days_held = today.trading_days_from original
        
        sell_point = [@m * days_held + @b, 0].max
      
        today.change_from(original) >= sell_point
      end
    end
  end
end

