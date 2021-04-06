require './market.rb'
require './script/helpers.rb'
require 'upsert'
require 'pry'

start  = ARGV[0] ? Date.parse(ARGV[0]) : Date.today
finish = Date.today

trie = Hash.new {|h, k| h[k] = {} }

start.upto finish do |date|
  puts date
  date = Time.parse date.to_s

  # {Ticker ID => [Rank, Value]}
  rankings = Ticker.rankings :stocks => NYSE, :date => date
  rankings.each do |tid, (rank, value)|
    trie[tid][date] = {:rank => rank, :value => value}
  end
end

bars = DB[:bars].select(:id, :ticker_id, :date)
                .where(:date => Time.parse(start.to_s)..Time.parse(finish.to_s))
                .all

num = 0
DB.synchronize do |conn|
  Upsert.batch(conn, :bars) do |upsert|
    bars.each do |bar|
      rank = trie[bar[:ticker_id]][bar[:date]]
      next unless rank
      upsert.row({:id => bar[:id]}, :rank       => rank[:rank],
                                    :rank_value => rank[:value])
      num += 1
    end
  end
end

puts "#{num} rows across #{finish - start} days update"

binding.pry

