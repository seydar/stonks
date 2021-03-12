require 'pry'
require 'alpaca/trade/api'

Alpaca::Trade::Api.configure do |config|
  config.endpoint   = "https://api.alpaca.markets"
  config.key_id     = "AKM406CX3NH9IO9PGC55"
  config.key_secret = "6NC5iRohh75TkdC6NBvOy2pEKhvYbnBPGPGaRFnM"
end

# time is in days
# fraction is the percentage of change
def change(bars, time, percentage)
  scan = bars.each_cons(time)
  scan.each do |period|
    change = (period[-1].close - period[0].open) / period[0].open
    change.abs > percentage.abs && change.sign == percentage.sign
  end
end

def changes(bars, time)
  scan = bars.each_cons(time)
  p scan.size
  scan.map do |period|
    change = (period[-1].close - period[0].open) / period[0].open
  end
end


client = Alpaca::Trade::Api::Client.new
bars = client.bars("day", ["GME"])['GME']

binding.pry

