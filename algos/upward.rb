module Algorithms
  class Upward < Simulator
    attr_accessor :m
    attr_accessor :b

    FOLDER = "upward"

    DEFAULTS = {:m    => 0.0,
                :b    => 0.5,
                :rise => 0.25}

    # This should prolly be turned into an instance method,
    # but I'm not sure what the refactoring of script/helpers.rb
    # would then look like.
    # TODO ^^^
    def self.cache_name(**kwargs)
      opts = DEFAULTS.merge kwargs

      "data/#{FOLDER}/" +
      "#{opts[:year]}" +
      "_r#{opts[:rise]}" +
      "_m#{opts[:m]}" +
      "_b#{opts[:b]}" +
      ".sim"
    end

    def description
      "algorithm: Upward\n" +
      "\tyear: #{@after.year} - #{@before.year}\n"
      "\trise: #{@rise}"
    end

    # `#cache_name` needs to become an instance method. This is stupid
    # and ugly with the references to DEFAULTS. Shipmate, these *are* the
    # defaults.
    # TODO ^^^
    def initialize(stocks:  nil,
                   after:   nil,
                   before:  nil,
                   rise:    DEFAULTS[:rise],
                   rank:    60,
                   m:       DEFAULTS[:m],
                   b:       DEFAULTS[:b],
                   **extra)
      super(:stocks => stocks,
            :after => after,
            :before => before)

      @m = m
      @b = b
      @rise = rise

      assessor.buy_when :history => 2 do |history|
        today     = history[-1]
        yesterday = history[-2]

        [today.change_from(yesterday) >= rise,
         today.change_from(today)     >= rise].any?
      end

      assessor.sell_when do |original, today|
        days_held = today.trading_days_from original
        
        sell_point = [@m * days_held + @b, 0].max
      
        today.change_from(original) >= sell_point
      end
    end
  end
end

