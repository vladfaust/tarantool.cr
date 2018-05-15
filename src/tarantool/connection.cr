require "socket"
require "logger"
require "base64"
require "msgpack"
require "time_format"

require "./response"

module Tarantool
  # A main class which holds a TCP connection to a Tarantool instance.
  #
  # It's interaction methods (`#ping`, `#select`, `#update` etc.) are synchronous and always return a `Response` instance (except for `#ping` which returns `Time`).
  class Connection
    @sync : UInt64 = 0_u64
    @channels = {} of UInt64 => Channel::Unbuffered(Response)
    @waiting_since = {} of UInt64 => Time

    # Initialize a new Tarantool connection.
    #
    # ```
    # db = Tarantool::Connection.new("localhost", 3301)
    # db.ping # => 00:00:00.000181477
    # ```
    def initialize(
      @host = "localhost",
      @port = 3301,
      @logger : Logger? = nil
    )
      @socket = TCPSocket.new(host, port)
      @open = true

      greeting = @socket.gets
      @logger.try &.info("Initiated connection with #{greeting}") # Tarantool Version

      @salt = Base64.decode_string(@socket.gets.not_nil!.strip)

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
    end

    # Close the connection.
    def close
      @open = false
      @channels.clear
    end

    # Ping Tarantool and return elapsed time.
    #
    # ```
    # db.ping # => 00:00:00.000181477
    # ```
    def ping
      Time.measure do
        send(CommandCode::Ping)
      end
    end

    # Send SELECT request.
    #
    # From Tarantool docs: "Find tuples matching the search pattern."
    #
    # ```
    # db.select(999, 0, {1}) # Select from space #999 by primary index (#0) value 1
    # ```
    def select(space_id : Int, index_id : Int, key : Tuple | Array, iterator : Iterator = Iterator::Equal, offset = 0, limit = 2 ** 30)
      send(CommandCode::Select, {
        Key::SpaceID.value  => space_id,
        Key::IndexID.value  => index_id,
        Key::Limit.value    => limit,
        Key::Offset.value   => offset,
        Key::Iterator.value => iterator.value,
        Key::Key.value      => key,
      })
    end

    # Send INSERT request.
    #
    # From Tarantool docs: "Inserts tuple into the space, if no tuple with same unique keys exists. Otherwise throw duplicate key error."
    #
    # ```
    # db.insert(999, {1, "vlad"}) # Insert into space #999 value {1, "vlad"}
    # ```
    def insert(space_id : Int, tuple : Tuple | Array)
      send(CommandCode::Insert, {
        Key::SpaceID.value => space_id,
        Key::Tuple.value   => tuple,
      })
    end

    # Send REPLACE request.
    #
    # From Tarantool docs: "Insert a tuple into the space or replace an existing one."
    #
    # ```
    # db.replace(999, {1, "faust"}) # Replace in space #999 value {1, "vlad"} with {1, "faust"} or insert if not exists
    # ```
    def replace(space_id : Int, tuple : Tuple | Array)
      send(CommandCode::Replace, {
        Key::SpaceID.value => space_id,
        Key::Tuple.value   => tuple,
      })
    end

    # Send UPDATE request.
    #
    # From Tarantool docs: "Update a tuple. It is an error to specify an argument of a type that differs from the expected type."
    #
    # ```
    # db.update(999, 0, {1}, [{":", 1, 0, 0, "vlad"}]) # Append "vlad" to "faust", resulting in "vladfaust"
    # ```
    def update(
      space_id : Int,
      index_id : Int,
      key : Tuple | Array,
      tuple : Array # It should really be named "ops"
    )
      send(CommandCode::Update, {
        Key::SpaceID.value => space_id,
        Key::IndexID.value => index_id,
        Key::Key.value     => key,
        Key::Tuple.value   => tuple,
      })
    end

    # Send DELETE request.
    #
    # From Tarantool docs: "Delete a tuple."
    #
    # ```
    # db.delete(999, 1, {"vladfaust"}) # Will delete the entry
    # ```
    def delete(space_id : Int, index_id : Int, key : Tuple | Array)
      send(CommandCode::Delete, {
        Key::SpaceID.value => space_id,
        Key::IndexID.value => index_id,
        Key::Key.value     => key,
      })
    end

    # Send CALL request.
    #
    # From Tarantool docs: "Call a stored function, returning an array of tuples."
    #
    # ```
    # db.call(:my_func)
    # ```
    def call(function : String | Symbol, args : Tuple | Array = [] of MessagePack::Type)
      send(CommandCode::Call, {
        Key::FunctionName.value => function,
        Key::Tuple.value        => args,
      })
    end

    # Send EVAL request.
    #
    # From Tarantool docs: "Evaulate Lua expression."
    #
    # ```
    # db.eval("local a, b = ... ; return a + b", {1, 2}) # Will return response with [3] in its body
    # ``
    def eval(expression : String, tuple : Tuple)
      send(CommandCode::Eval, {
        Key::Expression.value => expression,
        Key::Tuple.value      => tuple,
      })
    end

    # Send UPSERT request.
    #
    # From Tarantool docs: "Update tuple if it would be found elsewhere try to insert tuple. Always use primary index for key."
    #
    # ```
    # db.eval(999, {1, "vlad"}, ["=", 1, "vladfaust"]) # Insert {1, "vlad"} or replace its name with "vladfaust"
    # ```
    def upsert(space_id : Int, tuple : Tuple | Array, ops : Array)
      send(CommandCode::Upsert, {
        Key::SpaceID.value => space_id,
        Key::Tuple.value   => tuple,
        Key::Ops.value     => ops,
      })
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
