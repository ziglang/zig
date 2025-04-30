comptime {
    const E = @Enum(u1, .exhaustive, &.{ "f0", "f1", "f2" }, &.{ 0, 1, 2 });
    _ = E;
}

// error
//
// :2:72: error: type 'u1' cannot represent integer value '2'
