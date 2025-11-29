const Tag = @Enum(u2, .exhaustive, &.{ "signed", "unsigned" }, &.{ 0, 1 });
const Extern = @Union(.@"extern", Tag, &.{ "signed", "unsigned" }, &.{ i32, u32 }, &@splat(.{}));

export fn entry() void {
    const tagged: Extern = .{ .signed = -1 };
    _ = tagged;
}

// error
//
// :2:35: error: extern union does not support enum tag type
