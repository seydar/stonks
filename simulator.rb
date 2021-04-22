class Simulator
  attr_accessor :results
  attr_accessor :assessor
  attr_accessor :stocks
  attr_accessor :after
  attr_accessor :before

  def initialize(stocks:  nil,
                 after:   nil,
                 before:  nil)
    @stocks = stocks
    @after  = after
    @before = before
    @assessor = Assessor.new
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

  def holding=(val)
    @assessor.holding = val
  end
end

Dir['./algos/*.rb'].each {|f| require f }

