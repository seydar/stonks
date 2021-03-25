class Assessor
  attr_accessor :buying_plan
  attr_accessor :selling_plan
  attr_accessor :history_requirement

  attr_accessor :holding

  def buy_when(history: 2, &b)
    @buying_plan = b
    @history_requirement = history
  end

  def sell_when(&b)
    @selling_plan = b
  end

  def buy?(ticker)
    buying_plan[ticker]
  end

  def sell?(ticker, original)
    selling_plan[ticker, original]
  end

  def assess_buys(tickers, opts={})
    tids = tickers.map {|t| t.id }

    debut  = opts[:after] || Time.parse('1 march 1900')
    debut  = debut.is_a?(Time) ? debut : Time.parse(debut.to_s)
    fin    = opts[:before] || Time.parse(Date.today.to_s)
    fin    = fin.is_a?(Time) ? fin : Time.parse(fin.to_s)

    bars   = Bar.where(:date => debut..fin, :ticker_id => tids)
                .order(:ticker_id, Sequel.asc(:date))
                .all
    groups = bars.group_by {|b| b.ticker_id }

    @holding = []

    # create groups of size `@history_requirement`, and then
    # pass that history to the checker
    # most recent bar is at -1, oldest bar is at 0
    groups.map do |ticker_id, bars|
      # assume the history is 
      histories = bars.each_cons history_requirement

      @holding += histories.filter do |history|

        # verify that the history is consecutive
        day_deltas = history.each_cons(2).map {|a, b| b.date - a.date }

        if day_deltas.any? {|v| v > 4.days }
          false
        else
          buy? history
        end
      end.map {|history| history.last }
    end

    # `@holding` currently references the days that a decision to buy is made
    # (using the day's closing price), but we don't *actually* buy until the
    # next morning. So we need to replace these stocks with the next day's
    # stock.
    # 
    # This is key because the `Bar#change_from` method operates on the opening
    # price of the earlier day.
    #
    # If it's `nil` because we're dealing with some HOT OF THE PRESS stock
    # recommendations, then... I don't really have a plan for that yet.
    # Then the stock doesn't exist. Send a text, whatever. I need to include
    # some notification system here.
    #
    # TODO include the notification system at this point.
    #
    # From here on out, we're dealing with *simulation*.
    @holding = @holding.map do |stock|
      index = stock.ticker.bars.index stock
      stock.ticker.bars[index + 1] || stock
    end
    @holding.each {|stock| stock.ticker.normalize! }
    @holding = @holding.map {|stock| stock.refresh }
  end

  def assess_sells
    sales = @holding.map do |stock|
      bars   = stock.ticker.bars
      orig_i = bars.index stock

      sell_bar = bars[orig_i..-1].find {|day| sell? stock, day }

      {:buy  => stock,
       :sell => sell_bar,
       :hold => sell_bar ? sell_bar.trading_days_from(stock)  : nil,
       :ROI  => sell_bar ? sell_bar.change_from(stock) : -1 }
    end
  end

  def assess(tickers, opts={})
    assess_buys tickers, opts
    assess_sells
  end
end

