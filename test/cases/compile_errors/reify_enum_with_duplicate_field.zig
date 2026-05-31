export fn entry() void {
    _ = @Enum(u32, .nonexhaustive, &.{ "A", "A" }, &.{ 0, 1 });
}

// error
//
// :2:36: error: duplicate enum field 'A'
// :2:36: note: other field here
