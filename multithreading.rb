module Enumerable
  # Instead of constantly cycling each element into a new thread in the
  # queue, just split the enumerable into chunks and give each chunk its
  # own thread
  def parallel_map(threads: 4, &blk)
    groups = self.each_slice(self.size / threads)
    data = []

    groups.map do |group|
      Thread.new do
        data << group.map(&blk)
      end
    end.each {|t| t.join }

    data.flatten
  end
end

