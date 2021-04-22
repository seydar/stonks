module Algorithms
  class Upward < Simulator
    def initialize(stocks:  nil,
                   after:   nil,
                   before:  nil,
                   rise:    0.1,
                   rank:    60,
                   m:      -0.02,
                   b:       5.2)
      super(:stocks => stocks,
            :after => after,
            :before => before)

      @m = m
      @b = b

      assessor.buy_when :history => 2 do |history|
        today     = history[-1]
        yesterday = history[-2]

        [today.change_from(yesterday) >= rise,
         today.change_from(today)     >= rise].any?
      end

      assessor.sell_when do |original, today|
        days_held = today.trading_days_from original
        
        sell_point = [@m * days_held + @b, 0].max
      
        today.change_from(original) >= sell_point
      end
    end
  end
end

