const Tag = @Enum(undefined, .exhaustive, &.{}, &.{});
export fn entry() void {
    _ = @as(Tag, @enumFromInt(0));
}

// error
//
// :1:19: error: use of undefined value here causes illegal behavior
