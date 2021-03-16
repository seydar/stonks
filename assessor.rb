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

    bars   = Bar.where(:time => debut..fin, :ticker_id => tids)
              .order(:ticker_id, Sequel.asc(:time))
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

        if day_deltas.any? {|v| v > 4 }
          false
        else
          buy? history
        end
      end.map {|history| history.last }
    end

  end

  def assess_sells
    @holding.map {|stock| sell? stock.ticker, stock }
  end

  def assess(tickers, opts={})
    assess_buys tickers, opts
    assess_sells
  end
end

def sell_point(days_held, drop=120.0)
  [2.0 - days_held / drop, 0].max
end


