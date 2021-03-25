class Simulator
  attr_accessor :results
  attr_accessor :assessor
  attr_accessor :stocks
  attr_accessor :after
  attr_accessor :before
  attr_accessor :m
  attr_accessor :b

  def initialize(stocks: nil,
                 drop: -0.3,
                 vol: 10_000_000,
                 m: -0.05,
                 b: 4.6,
                 after: nil,
                 before: nil)
    @stocks = stocks
    @after  = after
    @before = before
    @m      = m
    @b      = b

    @assessor = Assessor.new
    @assessor.buy_when :history => 5 do |history|
      today     = history[-1]
      yesterday = history[-2]
    
      [[today.change_from(yesterday) <= drop,
        today.change_from(today)     <= drop].any?,

       history.map {|b| b.volume }.mean >= vol
      ].all?
    end
    
    # drop = -0.3, vol > 10M, m = -0.05, b = 4.6
    @assessor.sell_when do |original, today|
      days_held = today.trading_days_from original
      
      sell_point = [@m * days_held + @b, 0].max
    
      today.change_from(original) >= sell_point
    end
  end

  def run
    @assessor.assess_buys @stocks, :after  => @after,
                                   :before => @before
    puts "holdings determined"
    assess_sells
  end

  def assess_sells
    @results = @assessor.assess_sells
  end
end

