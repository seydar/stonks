class Simulator
  attr_accessor :results
  attr_accessor :assessor
  attr_accessor :stocks
  attr_accessor :after
  attr_accessor :before
  attr_accessor :m
  attr_accessor :b

  def initialize(stocks:  nil,
                 drop:   -0.2,
                 rank:    60,
                 m:      -0.02,
                 b:       5.2,
                 after:   nil,
                 before:  nil)
    @stocks = stocks
    @after  = after
    @before = before
    @m      = m
    @b      = b

    @assessor = Assessor.new
    @assessor.buy_when :history => 2 do |history|
      today     = history[-1]
      yesterday = history[-2]
    
      [[today.change_from(yesterday) <= drop,
        today.change_from(today)     <= drop].any?,

       today.rank <= rank
      ].all?
    end
    
    # for ROI: m = -0.02, b = 5.2
    # for $$$: m = -0.03, b = 3.0
    #      or: m = -0.00, b = 0.6
    #
    # honestly i've done a terrible job of evaluating the different
    # sell signals
    #
    # TODO suck less
    @assessor.sell_when do |original, today|
      days_held = today.trading_days_from original
      
      sell_point = [@m * days_held + @b, 0].max
    
      today.change_from(original) >= sell_point
    end
  end

  def assess_buys
    @assessor.assess_buys @stocks, :after  => @after,
                                   :before => @before
  end

  def assess_sells
    @results = @assessor.assess_sells
  end

  def run
    assess_buys
    assess_sells
  end

  def holding
    @assessor.holding
  end
end

