module Algorithms
  class VolatileDrop < Simulator
    attr_accessor :m
    attr_accessor :b
    attr_accessor :drop
    attr_accessor :rise # TODO get this out of here

    FOLDER = "volatile_drop"

    # use 30 pieces
    def initialize(stocks:  nil,
                   after:   nil,
                   before:  nil,
                   drop:   -0.2,
                   rank:    60,
                   m:      -0.03,
                   b:       3.0,
                   min:     0.4,
                   **extra)
      super(:stocks => stocks,
            :after  => after,
            :before => before)
      @drop = drop
      @m = m
      @b = b
  
      assessor.buy_when :history => 2 do |history|
        today     = history[-1]
        yesterday = history[-2]
      
        [[today.change_from(yesterday) <= drop,
          today.change_from(today)     <= drop].any?,
  
         today.rank <= rank,
         today.close >= min
        ].all?
      end
      
      # m = -0.03, b = 3.0
      assessor.sell_when do |original, today|
        days_held = today.trading_days_from original
        
        sell_point = [@m * days_held + @b, 0].max
      
        today.change_from(original) >= sell_point
      end
    end
  end
end

