const Tag = @Enum(bool, .nonexhaustive, &.{}, &.{});
export fn entry() void {
    _ = @as(Tag, @enumFromInt(0));
}

// error
//
// :1:19: error: tag type must be an integer type
