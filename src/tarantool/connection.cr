require "socket"
require "logger"
require "base64"
require "digest/sha1"
require "uri"
require "msgpack"
require "time_format"

require "./connection/*"
require "./response"

module Tarantool
  # A main class which holds a TCP connection to a Tarantool instance.
  #
  # Its interaction methods (`#ping`, `#select`, `#update` etc.) are synchronous and always return a `Response` instance (except for `#ping` which returns `Time`).
  #
  # It's recommended to call `#parse_schema` right after initialization.
  #
  # When `#parse_schema` is called, referencing spaces and indexes by their names (either strings or symbols) is allowed:
  #
  # ```
  # db.select(:examples, :primary, {1}) # Raises ArgumentError
  # db.parse_schema
  # db.select(:examples, :primary, {1})
  # ```
  class Connection
    include Requests

    @sync : UInt64 = 0_u64
    @channels = {} of UInt64 => Channel::Unbuffered(Response)
    @waiting_since = {} of UInt64 => Time
    @encoded_salt : String

    # Initialize a new Tarantool connection with string URI.
    #
    # ```
    # db = Tarantool::Connection.new("tarantool://admin:password@localhost:3301")
    # ```
    def initialize(uri : String, *, logger = nil)
      initialize(URI.parse(uri), logger: logger)
    end

    # Initialize a new Tarantool connection with URI.
    #
    # ```
    # uri = URI.parse("tarantool://localhost:3301")
    # db = Tarantool::Connection.new(uri)
    # ```
    def initialize(uri : URI, *, logger = nil)
      initialize(uri.host.not_nil!, uri.port.not_nil!, uri.user, uri.password, logger: logger)
    end

    # Initialize a new Tarantool connection.
    #
    # ```
    # db = Tarantool::Connection.new("localhost", 3301, "admin", "password", logger: Logger.new(STDOUT))
    # db.ping # => 00:00:00.000181477
    # ```
    def initialize(
      host : String,
      port : Int32,
      user : String? = nil,
      password : String = "",
      *,
      @logger : Logger? = nil
    )
      @socket = TCPSocket.new(host, port)
      @open = true

      greeting = @socket.gets
      @logger.try &.info("Initiated connection with #{greeting}") # Tarantool Version

      @encoded_salt = @socket.gets.not_nil![0...44]

      unpacker = MessagePack::Unpacker.new(@socket)

      spawn do
        slice = Bytes.new(5)

        while @open
          if @socket.read_fully?(slice)
            arrived_at = Time.now
            response = Response.new(unpacker)
            sync = response.header.sync

            @logger.try &.debug("[#{sync}] " + TimeFormat.auto(arrived_at - @waiting_since[sync].not_nil!).rjust(5) + " latency")

            @channels[sync]?.try &.send(response)
          end
        end

        @socket.close
      end

      if user && !(user == "guest" && password.empty?)
        authenticate(user, password)
      end
    end

    # Close the connection.
    def close
      @open = false
      @socket.close
      @channels.clear
    end

    alias Schema = Hash(String, NamedTuple(id: UInt16, indexes: Hash(String, UInt8)))

    # A small copy of current box schema containing spaces and their indexes.
    # Allows to use named spaces and indexes in requests.
    #
    # Updated by calling `#parse_schema`.
    #
    # You can also modify it yourself:
    # ```
    # db.schema["examples"] = {id: 999_u16, indexes: {"primary": 0_u8}}
    # ```
    getter schema : Schema = Schema.new

    # Parse current box schema. Allows to use named spaces and indexes in requests.
    # NOTE: This will fail if current user doesn't have execute access to "universe".
    def parse_schema
      eval("return box.space").body.data.first.as(Hash).keys.each do |space|
        indexes = eval("return box.space.#{space}.index").body.data.first

        if indexes.is_a?(Array)
          indexes = Hash(String, UInt8).new
        else
          indexes = indexes.as(Hash).reduce({} of String => UInt8) do |hash, (name, value)|
            if name.is_a?(String)
              hash[name.as(String)] = value.as(Hash)["id"].as(UInt8)
            end
            hash
          end
        end

        @schema[space.as(String)] = {
          id:      eval("return box.space.#{space}.id").body.data.first.as(UInt16),
          indexes: indexes,
        }
      end
    end

    # Send request to Tarantool. Always returns `Response`.
    protected def send(code, body = nil)
      sync = next_sync
      response = uninitialized Response

      @logger.try &.debug("[#{sync}] Sending #{code} command")

      elapsed = Time.measure do
        payload = form_request(code, sync, body)

        channel = @channels[sync] = Channel(Response).new
        @waiting_since[sync] = Time.now

        @socket.write(payload)
        response = channel.receive
      end

      @logger.try &.debug("[#{sync}] " + TimeFormat.auto(elapsed).rjust(5) + " elapsed")

      @channels.delete(sync)

      raise Response::Error.new(response) if response.error
      return response
    end

    protected def next_sync
      @sync += 1
    end

    protected def form_request(code, sync, body = nil)
      packer = MessagePack::Packer.new
      packer.write(0x01020304) # Related to endians
      packer.write({
        Key::Code.value => code.value,
        Key::Sync.value => sync,
      })
      packer.write(body)

      # Related to endians as well
      bytes = packer.to_slice
      size = bytes.size - 5
      bytes[4] = size.to_u8
      bytes[3] = (size >> 8).to_u8
      bytes[2] = (size >> 16).to_u8
      bytes[1] = (size >> 24).to_u8

      bytes
    end
  end
end
