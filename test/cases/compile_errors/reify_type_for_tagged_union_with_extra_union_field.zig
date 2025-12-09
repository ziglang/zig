const Tag = @Enum(u1, .exhaustive, &.{ "signed", "unsigned" }, &.{ 0, 1 });
const Tagged = @Union(.auto, Tag, &.{ "signed", "unsigned", "arst" }, &.{ i32, u32, f32 }, &@splat(.{}));
export fn entry() void {
    var tagged = Tagged{ .signed = -1 };
    tagged = .{ .unsigned = 1 };
}

// error
//
// :2:35: error: no field named 'arst' in enum 'tmp.Tag'
// :1:13: note: enum declared here
