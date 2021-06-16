class Account < Sequel::Model
  one_to_many :orders, :order => :date

  ALPACA_EP = "https://api.alpaca.markets"

  def client
    @client ||= Alpaca::Trade::Api::Client.new :endpoint => ALPACA_EP,
                                               :key_id => alpaca_id,
                                               :key_secret => alpaca_secret
  end

  def investment(bar, pxs: self.pieces)
    quantity_for_cash bar, :cash => (circulation / pxs.to_f)
  end

  def quantity_for_cash(bar, cash: circulation / self.pieces.to_f)
    (cash.to_f / bar.close).floor
  end

  def buy(bar, quantity: nil, cash: nil, dry: false)
    raise if quantity && cash # can only choose one

    # Sometime I might want to pass in a hash straight from the algorithm
    # without having to pluck out the bar
    bar = Hash === bar ? bar[:buy] : bar

    quantity ||= cash ? quantity_for_cash(bar, :cash => cash) : investment(bar)
    return [bar, quantity] if dry

    client.new_order :symbol => bar.ticker.symbol,
                     :qty    => quantity,
                     :side   => 'buy',
                     :type   => 'market',
                     :time_in_force => 'day'

    o   = Order.where(:account_id => id, :bought_id => bar.id).first
    o ||= Order.create :account_id => id,
                       :bought_id  => bar.id,
                       :quantity   => 0,
                       :date       => Time.now
    o.quantity += quantity
    o.save

    o
  end

  def sell(hash)
    order = orders.find {|o| o.bought == hash[:buy] }
    return nil unless order

    # Actually do the transaction
    client.close_position :symbol => hash[:sell].ticker.symbol,
                          :qty    => order.quantity

    # Add the profits to the circulation (for reinvestment)
    self.circulation += hash[:sell].close - h[:buy].open

    # Associate a sell bar with the order
    order.sold_id = hash[:sell].id
    order.save && order # `&& order` means we return the order if it succeeds
  end

  def reflecting_accurately?
    remote_status = client.positions
    local_status  = orders.inject({}) do |h, o|
      if o.sold
        h
      else
        h[o.bought.ticker.symbol] ||= 0
        h[o.bought.ticker.symbol]  += o.quantity
        h
      end
    end

    remote_status.all? {|p| local_status[p.symbol] == p.qty.to_i }
  end

  def complete!
    orders.filter {|o| o.incomplete? }.each {|o| o.complete! }
  end

  # 1. Get all buy signals
  # 2. Filter them to be the ones that are negative
  # 3. Buy them
  def rebalance!
    # 1. Get all buy signals
    sim    = simulate :year => (Time.now.year - 1)..Time.now.year

    # 2. Filter them to be the ones that are negative
    #
    # (obviously) only buy more of stocks which we haven't sold yet
    unsold = sim.results.filter {|h| h[:hold].nil? }

    # install some data so that we can better make our decisions
    unsold.each do |h|
      h[:latest] = h[:buy].ticker.latest_bar
      h[:ROI]    = h[:latest].change_from h[:buy]
      h[:hold]   = h[:latest].trading_days_from h[:buy]
    end

    # only buy stocks that are still down
    targets = unsold.filter {|h| h[:ROI] < 0 }

    # only buy stocks that have been held for < 100 days
    #
    # THIS IS ARBITRARILY CHOSEN (kinda). Eventually, if you hold
    # long enough, you just gotta give up. Maybe this should be based
    # off of the sell-signal's desired ROI.
    targets = targets.filter {|h| h[:hold] < 100 }

    # only buy stocks that are still available
    # (I'm sure Alpaca would prevent me from buying them anyways, but
    # I don't want to test their interlock)
    latest_date = targets.map    {|h| h[:latest].date }.max
    targets     = targets.filter {|h| h[:latest].date == latest_date }

    # 3. Buy them
    #
    # Limited investment per stock
    per_stock = client.account.cash / targets.size.to_f

    # Actually buy each stock
    targets.map do |target|
      # since the order thinks we're buying `target[:buy]`, but we want the
      # pricing to be based off of `target[:latest]`
      quantity = quantity_for_cash target[:latest], :cash => per_stock

      buy target, :quantity => quantity
    end
  end

end

class Order < Sequel::Model
  many_to_one :account
  many_to_one :bought, :class => Bar
  many_to_one :sold, :class => Bar

  def incomplete?
    !complete?
  end

  def complete?
    complete
  end

  def complete!
    return true if complete?

    self.bought = bought.next

    return false unless self.bought

    self.complete = true
    self.save
  end
end

