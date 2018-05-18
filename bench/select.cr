# Plase call /spec/helpers.lua#setup before running this benchmark, so space with id 999 exists

require "../src/tarantool"
require "benchmark"

db = Tarantool::Connection.new("localhost", 3301)

COUNT = 100_000
channel = Channel(Tarantool::Response).new(COUNT)

puts Benchmark.measure {
  COUNT.times do |i|
    spawn do
      channel.send(db.select(999, 0, {1}, limit: 1))
    end
  end

  COUNT.times do
    channel.receive
  end
}
