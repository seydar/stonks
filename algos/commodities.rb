module Algorithms
  class Commodities < Simulator

    def initialize(stocks: nil, after: nil, before: nil)
      super(:stocks => stocks, :after => after, :before => before)

    end
  end
end

