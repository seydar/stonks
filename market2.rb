# stocks.rb
require 'pp'
require 'alphavantagerb'
require './db.rb'
require './assessor.rb'
require 'statistics'
require 'histogram/array'

# Configure the AlphaVantage API
CLIENT = Alphavantage::Client.new :key => "GI387ZJ0874WXW5S"

SPANS  = {'day'   => 86400,
          '15min' => 900,
          '5min'  => 300,
          'min'   => 60}

class Array
  def median
    sort[size / 2]
  end
end

######
# TODO how do i define stock volatility? generally, it assumes a stable mean,
# but what happens when the mean is stably trending upwardss?
######

##############################################################
# How do we define what a precipitous drop in stock price is?
#
# {-100..-0.3 => 48,
#  -0.3..-0.2 => 155,
#  -0.2..-0.1 => 1589,
#  -0.1.. 0   => 106486,
#   0  .. 0.1 => 116388,
#   0.1.. 0.2 => 3102,
#   0.2.. 0.3 => 453,
#   0.3.. 100 => 242}
#
# These are across the NYSE, with an average of 70 days of data per stock.
# So over 70 days, how many trades do I want to take place?
# In theory, if I sell after making 10% back on the stocks
##############################################################

