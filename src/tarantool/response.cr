require "msgpack"

module Tarantool
  # A response sent by Tarantool. It should not be initialized manually.
  #
  # See [Tarantool docs](https://tarantool.io/en/doc/1.9/dev_guide/internals_index.html#response-packet-structure) to know more about responses.
  #
  # Example:
  #
  # ```
  # response = db.select(999, 0, {1})
  # if response.success?
  #   puts response.body.data
  # end
  # # => [[1, "hello world"]]
  # ```
  struct Response
    # A header of a `Response` sent by Tarantool. It should not be initialized manually.
    struct Header
      @code : ResponseCode?
      @sync : UInt64?
      @schema_id : UInt32?

      # The header's `ResponseCode`.
      def code
        @code.not_nil! # According to Tarantoll docs, it cannot be nil
      end

      # A sync number. Used to know which request does this particular response belongs to.
      def sync
        @sync.not_nil! # According to Tarantoll docs, it cannot be nil
      end

      # An actual schema ID.
      def schema_id
        @schema_id.not_nil! # According to Tarantoll docs, it cannot be nil
      end

      # :nodoc:
      protected def initialize(unpacker : MessagePack::Unpacker)
        unpacker.read_hash.each do |key, value|
          case key
          when Key::Code.to_u8
            @code = value.as(UInt32) == 0x00_u32 ? ResponseCode::OK : ResponseCode::Error
          when Key::Sync.to_u8
            @sync = value.as(UInt64)
          when Key::SchemaID.to_u8
            @schema_id = value.as(UInt32)
          else
            raise "Unexpected header key #{key}"
          end
        end
      end
    end

    # A header of a `Response` sent by Tarantool. It should not be initialized manually.
    struct Body
      @data : Array(MessagePack::Type)?

      # The body's data. It's usually an array of arrays.
      def data
        @data.not_nil! # According to Tarantoll docs, it cannot be nil
      end

      # :nodoc:
      protected def initialize(unpacker : MessagePack::Unpacker)
        @data = unpacker.read_hash[Key::Data.to_u8].as(Array)
      end
    end

    # The response's header.
    getter header : Header

    @body : Body?

    # The response's body, safe way. Use it when you're not sure if it's present.
    #
    # ```
    # p response.body?.try &.data
    # ```
    def body?
      @body
    end

    # An alias for `body?.not_nil!`. Use it when you're sure if the body is present.
    #
    # ```
    # if response.success?
    #   p response.body.data
    # end
    # ```
    def body
      @body.not_nil!
    end

    # An error if any. The body is likely to be empty in this case.
    getter error : String?

    # Alias of `error.nil?`.
    def success?
      error.nil?
    end

    # :nodoc:
    def initialize(unpacker : MessagePack::Unpacker)
      @header = Header.new(unpacker)

      if @header.code == ResponseCode::Error
        error = unpacker.read_hash
        @error = error[Key::Error.to_u8].as(String)
      else
        # Body is optional in the successful Tarantool response, therefore #body can be nil
        # Otherwise, it must have #body#data attribute
        token = unpacker.prefetch_token
        if token.type == :HASH && token.size > 0_i64 && !token.used
          @body = Body.new(unpacker)
        else
          unpacker.read_hash # Read response body, but do not set #body attribute
        end
      end
    end
  end
end
