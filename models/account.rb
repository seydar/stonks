class Account < Sequel::Model
  one_to_many :orders, :order => :date

  ALPACA_EP = "https://api.alpaca.markets"

  def client
    @client ||= Alpaca::Trade::Api::Client.new :endpoint => ALPACA_EP,
                                               :key_id => alpaca_id,
                                               :key_secret => alpaca_secret
  end

  def investment(bar, pxs: self.pieces)
    quantity_for_cash :cash => (circulation / pxs.to_f)
  end

  def quantity_for_cash(bar, cash: circulation / self.pieces.to_f)
    (cash / bar.close).floor
  end

  def buy(bar, quantity: nil, cash: nil)
    raise if quantity && cash # can only choose one

    # Sometime I might want to pass in a hash straight from the algorithm
    # without having to pluck out the bar
    bar = Hash === bar ? bar[:buy] : bar

    quantity ||= cash ? quantity_for_cash(bar, :cash => cash) : investment(bar)
    client.new_order :symbol => bar.ticker.symbol,
                     :qty    => quantity,
                     :side   => 'buy',
                     :type   => 'market',
                     :time_in_force => 'day'

    Order.create :account_id => id,
                 :bought_id  => bar.id,
                 :quantity   => quantity,
                 :date       => Time.now
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
end

class Order < Sequel::Model
  many_to_one :account
  many_to_one :bought, :class => Bar
  many_to_one :sold, :class => Bar
end

