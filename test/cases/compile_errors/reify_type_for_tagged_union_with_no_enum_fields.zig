const Tag = @Enum(u0, .exhaustive, &.{}, &.{});
const Tagged = @Union(.auto, Tag, &.{ "signed", "unsigned" }, &.{ i32, u32 }, &@splat(.{}));
export fn entry() void {
    const tagged: Tagged = undefined;
    _ = tagged;
}

// error
//
// :2:35: error: no field named 'signed' in enum 'tmp.Tag'
// :1:13: note: enum declared here
