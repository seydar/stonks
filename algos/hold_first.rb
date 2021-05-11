module Algorithms
  class HoldFirst < Simulator
    attr_accessor :m
    attr_accessor :b
    attr_accessor :h_m
    attr_accessor :h_b

    FOLDER = "hold_first"
  
    def initialize(stocks:  nil,
                   after:   nil,
                   before:  nil,
                   drop:   -0.2,
                   rank:    60,
                   m:      -0.02,
                   b:       5.2,
                   h_m:     0.01,
                   h_b:    -0.34,
                   **extra)
      super(:stocks => stocks,
            :after => after,
            :before => before)
      @m = m
      @b = b

      @h_m = h_m
      @h_b = h_b

      @waiting_list = Hash.new {|h, k| h[k] = [] }
      @buy_to_drop = {}
  
      assessor.buy_when :history => 2 do |history|
        today     = history[-1]
        yesterday = history[-2]
      
        too_old = []

        # Check to see if today is a day to buy
        drop_day = @waiting_list[today.ticker].find do |b|
          days_held = b.trading_days_from today
          buy_point = [@h_m * days_held + @h_b, 0].min

          # # this is here because I want to minimize calls to
          # # `#trading_days_from` since it makes a call to the DB
          # if buy_point == 0
          #   too_old << [today.ticker, b]
          # end

          today.change_from(b) <= buy_point
        end

        # Check to see if today should be added to the waiting list
        if [[today.change_from(yesterday) <= drop,
             today.change_from(today)     <= drop].any?,
  
            today.rank <= rank
           ].all?

           @waiting_list[today.ticker] << today
        end

        # # don't watch a stock forever. eventually, give up
        # too_old.each {|t, b| @waiting_list[t].delete b }

        # FIXME multiple days on the waiting list could be resolved within a
        # single day, but only one will get marked to be bought (the oldest
        # one)
        if drop_day
          # this list gets fuckered up because all the holdings are shifted by
          # a day to reflect buying on the *opening* price.
          @buy_to_drop[today] = drop_day
          @waiting_list[today.ticker].delete drop_day
          true
        else
          false
        end
      end
      
      assessor.sell_when do |original, today|
        days_held = today.trading_days_from @buy_to_drop[original]
        
        sell_point = [@m * days_held + @b, 0].max
      
        today.change_from(@buy_to_drop[original]) >= sell_point
      end
    end

    def assess_buys
      @assessor.assess_buys @stocks, :after  => @after,
                                     :before => @before

      # replace the keys in `@buy_to_drop` with those of the next day
      # as that is what happens to `@holding`
      keys = @buy_to_drop.keys.map do |key|
        bars  = Bar.where(:ticker => key.ticker,
                          :date => key.date..(key.date + 7.days))
                   .order(Sequel.asc(:date))
                   .all
        index = bars.index key
        [key, bars[index + 1] || key]
      end

      @buy_to_drop = keys.inject({}) do |h, (old, new)|
        h[new] = @buy_to_drop[old]
        h
      end

      holding
    end
  end
end

