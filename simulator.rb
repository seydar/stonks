require './assessor.rb'

class Simulator
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

  # TODO rebuild all caches in the commented-out format
  def cache_name
    vars = instance_variables - [:@after, :@before, :@stocks, :@assessor]

    #"data/#{self.class::FOLDER}/" +
    #"#{[after.year.to_s, before.year.to_s].uniq.join "-"}_"+ 
    #"#{after.to_i}-#{before.to_i}_" +
    #vars.sort.map {|v| v.to_s[1] + instance_variable_get(v).to_s }.join("_") +
    #".sim"

    "data/#{self.class::FOLDER}/" +
    "#{[after.year.to_s, before.year.to_s].uniq.join "-"}_" +
    vars.map {|v| v.to_s[1] + instance_variable_get(v).to_s }.join("_") +
    ".sim"
  end

  def assess_buys
    @assessor.assess_buys @stocks, :after  => @after,
                                   :before => @before
  end

  def assess_sells
    @assessor.assess_sells
  end

  def run
    assess_buys
    assess_sells
  end

  def results
    @assessor.results
  end

  def results=(val)
    @assessor.results = val
  end

  def holding
    @assessor.holding
  end

  def holding=(val)
    @assessor.holding = val
  end

  # Maybe `h[:hold]` should always be filled out?
  # Same with `h[:latest]`?
  def still_negative
    unsold = results.filter {|h| h[:sold] == nil }

    ticks = unsold.map {|h| h[:buy].ticker }
    #latests = Bar.where(:ticker => ticks)
    #             .order(Sequel.desc(:date))
    #             .group(:ticker_id)
    #             .all
    latests = ticks.map do |t|
      [t, Bar.where(:ticker => t)
             .order(Sequel.desc(:date))
             .first]
    end.to_h

    unsold.each do |h|
      h[:latest] = latests[h[:buy].ticker]
      h[:ROI] = h[:latest].change_from h[:buy]
      h[:hold] = h[:latest].trading_days_from h[:buy]
    end

    unsold.filter {|h| h[:ROI] < 0 }
  end
end

Dir['./algos/*.rb'].each {|f| require f }

Algorithm = eval("Algorithms::#{CONFIG[:algorithm]}")

