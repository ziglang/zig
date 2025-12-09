export fn entry() void {
    _ = @Enum(u32, .nonexhaustive, &.{ "A", "B" }, &.{ 10, 10 });
}

// error
//
// :2:52: error: enum tag value 10 already taken
// :2:52: note: other enum tag value here
