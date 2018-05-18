module Tarantool
  struct Response
    class Error < Exception
      def initialize(response : Response)
        super(response.error)
      end
    end
  end
end
