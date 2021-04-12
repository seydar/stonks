class Account < Sequel::Model
  one_to_many :orders, :order => :date

  def client
    @client ||= Alpaca::Trade::Api.new :endpoint => "https://api.alpaca.markets",
                                       :key_id => alpaca_id,
                                       :key_secret => alpaca_secret
  end

  def investment(bar)
    ((circulation / 50.0) / bar.close).floor
  end

  def buy(bar)
    qty = investment stock
    client.new_order :symbol => stock.symbol,
                     :qty    => qty,
                     :side   => 'buy',
                     :type   => 'market',
                     :time_in_force => 'day'

    Order.create :account_id => id,
                 :bought_id  => bar.id,
                 :quantity   => qty,
                 :date       => Time.now
  end

  def sell(hash)
    # Actually do the transaction
    client.close_position :symbol => hash[:sell].ticker.symbol,
                          :qty    => order.quantity

    # Associate a sell bar with the order
    order = orders.find {|o| o.bought == hash[:buy] }
    order.sold_id = hash[:sell].id
    order.save
  end
end

class Order < Sequel::Model
  many_to_one :account
end

