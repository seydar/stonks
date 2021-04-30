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
end

Dir['./algos/*.rb'].each {|f| require f }

Algorithm = eval("Algorithms::#{CONFIG[:algorithm]}")

