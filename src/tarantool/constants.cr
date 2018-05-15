module Tarantool
  enum Key
    Code         = 0x00
    Sync         = 0x01
    SchemaID     = 0x05
    SpaceID      = 0x10
    IndexID      = 0x11
    Limit        = 0x12
    Offset       = 0x13
    Iterator     = 0x14
    Key          = 0x20
    Tuple        = 0x21
    FunctionName = 0x22
    Username     = 0x23
    Expression   = 0x27
    Ops          = 0x28
    Data         = 0x30
    Error        = 0x31
  end

  enum CommandCode
    Select      = 0x01
    Insert      = 0x02
    Replace     = 0x03
    Update      = 0x04
    Delete      = 0x05
    Call16      = 0x06
    Auth        = 0x07
    Eval        = 0x08
    Upsert      = 0x09
    Call        = 0x0a
    Ping        = 0x40
    Join        = 0x41
    Subscribe   = 0x42
    RequestVote = 0x43
  end

  enum ResponseCode
    OK    = 0x00
    Error = 0x01
  end

  enum Iterator
    Equal
    ReversedEqual
    All
    LessThan
    LessThanOrEqual
    GreaterThanOrEqual
    GreaterThan
    BitsAllSet
    BitsAnySet
    BitsAllNotSet
    RtreeOverlaps
    RtreeNeighbor
  end
end
