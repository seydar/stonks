module Algorithms
  class HoldFirst < Simulator
    attr_accessor :m
    attr_accessor :b

    FOLDER = "hold_first"

    DEFAULTS = {:m    =>  -0.02,
                :b    =>   5.2,
                :drop =>  -0.2}

    def self.cache_name(**kwargs)
      opts = DEFAULTS.merge kwargs

      "data/#{FOLDER}/" +
      "#{opts[:year]}" +
      "_d#{opts[:drop]}" +
      "_m#{opts[:m]}" +
      "_b#{opts[:b]}" +
      ".sim"
    end
  
    def initialize(stocks:  nil,
                   drop:   -0.2,
                   rank:    60,
                   m:      -0.02,
                   b:       5.2,
                   after:   nil,
                   before:  nil,
                   **extra)
      super(:stocks => stocks,
            :after => after,
            :before => before)
      @m = m
      @b = b
      @waiting_list = Hash.new {|h, k| h[k] = [] }
  
      assessor.buy_when :history => 2 do |history|
        today     = history[-1]
        yesterday = history[-2]
      
        if [[today.change_from(yesterday) <= drop,
             today.change_from(today)     <= drop].any?,
  
            today.rank <= rank
           ].all?
           @waiting_list[today.ticker] << today
        end


        ix = @waiting_list[today.ticker].find do |b|
          days_held = b.trading_days_from today
          buy_point = [-0.50 * days_held + 0.01, 0].min

          if buy_point == 0
            too_old = true
          end

          today.change_from(b) < buy_point
        end

        if ix
          @waiting_list[today.ticker].delete ix
          true
        end
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

