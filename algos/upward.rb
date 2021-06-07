module Algorithms
  class Upward < Simulator
    attr_accessor :m
    attr_accessor :b

    FOLDER = "upward"

    def initialize(stocks:  nil,
                   after:   nil,
                   before:  nil,
                   rise:    10,
                   rank:    60,
                   m:      -0.02,
                   b:       5.2,
                   **extra)
      super(:stocks => stocks,
            :after => after,
            :before => before)
      @m = m
      @b = b
      @rise = rise

      assessor.buy_when :history => 2 do |history|
        today     = history[-1]
        yesterday = history[-2]

        ratio = today.volume.to_f / yesterday.volume

        ratio >= @rise && ratio <= 2 * @rise
      end

      assessor.sell_when do |original, today|
        days_held = today.trading_days_from original
        
        sell_point = [@m * days_held + @b, 0].max
      
        today.change_from(original) >= sell_point
      end
    end
  end
end

