# Tarantool

[![Built with Crystal](https://img.shields.io/badge/built%20with-crystal-000000.svg?style=flat-square)](https://crystal-lang.org/)
[![Build status](https://img.shields.io/travis/vladfaust/tarantool-crystal/master.svg?style=flat-square)](https://travis-ci.org/vladfaust/tarantool-crystal)
[![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg?style=flat-square)](https://vladfaust.com/tarantool-crystal)
[![Releases](https://img.shields.io/github/release/vladfaust/tarantool-crystal.svg?style=flat-square)](https://github.com/vladfaust/tarantool-crystal/releases)
[![Awesome](https://github.com/vladfaust/awesome/blob/badge-flat-alternative/media/badge-flat-alternative.svg)](https://github.com/veelenga/awesome-crystal)
[![vladfaust.com](https://img.shields.io/badge/style-.com-lightgrey.svg?longCache=true&style=flat-square&label=vladfaust&colorB=0a83d8)](https://vladfaust.com)
[![Patrons count](https://img.shields.io/badge/dynamic/json.svg?label=patrons&url=https://www.patreon.com/api/user/11296360&query=$.included[0].attributes.patron_count&style=flat-square&colorB=red&maxAge=86400)](https://www.patreon.com/vladfaust)

The Tarantool driver for Crystal.

[![Become Patron](https://vladfaust.com/img/patreon-small.svg)](https://www.patreon.com/vladfaust)

## About

[Tarantool](https://tarantool.io/) is a super-fast NoSQL* in-memory database. [Crystal](https://crystal-lang.org/) is a super-fast compiled language. Take both.

\* *It is planned to fully support SQL in version 2, which is currently in alpha*

## Benchmarks

Recent benchmarking of 100k `select` requests on a single 0.90Ghz CPU core with Tarantool running on the same machine via Docker:

```
$ crystal bench/select.cr --release
  1.530000   1.070000   2.600000 (  2.597737)
```

Resulting performance is **38.4k RPS**, averaging in **26μs** per request.

## Funding

This is one of my commerical projects. It's MIT licensed; bugs are fixed for free but features and support are paid (drop me an email at mail@vladfaust.com). I still accept pull requests though.

This shard has been initially sponsored by [to.click](https://to.click).

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  tarantool:
    github: vladfaust/tarantool-crystal
    version: ~> 0.1.0
```

This shard follows [Semantic Versioning 2.0.0](https://semver.org/), so see [releases](https://github.com/vladfaust/tarantool-crystal/releases) and change the `version` accordingly.

## Usage

After you [installed and run Tarantool](https://tarantool.io/en/doc/1.9/book/getting_started/index.html) and setup your schema, do:

```crystal
require "tarantool"

db = Tarantool::Connection.new("localhost", 3301) # Initiate the connection
db.parse_schema # Save current box schema to db instance
db.insert(:examples, {1, "hello"}) # Insert "hello" tuple
db.update(:examples, :primary, {1}, {"=", 1, "hello world"}) # Replace "hello" with "hello world"
db.select(:examples, :name, {"hello world"}).body.data # => [[1, "hello world"]]
```

All `Tarantool::Connection#*` requests are *synchronous*, they will be waiting until the response is received. However, a single Tarantool instance itself is capable of handling lots of simultaneous connections, so for the best perfomance consider running requests in multiple fibers:

```crystal
32.times do
  spawn do
    db.ping # All 32 pings are executed concurrently
  end
end
```

## Testing

1. Run `docker run --name mytarantool -d -p 3301:3301 -v /var/lib/docker/volumes/tarantool:/var/lib/tarantool tarantool/tarantool:1`
2. Connect to tarantool via console (`docker exec -i -t mytarantool console`) and apply schema found in `/spec/schema.lua`
3. `crystal spec`

## Contributing

1. Fork it ( https://github.com/vladfaust/tarantool/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [@vladfaust](https://github.com/vladfaust) Vlad Faust - creator, maintainer
