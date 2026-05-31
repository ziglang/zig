const Tag = @Enum(u2, .exhaustive, &.{ "signed", "unsigned", "arst" }, &.{ 0, 1, 2 });
const Tagged = @Union(.auto, Tag, &.{ "signed", "unsigned" }, &.{ i32, u32 }, &@splat(.{}));
export fn entry() void {
    var tagged = Tagged{ .signed = -1 };
    tagged = .{ .unsigned = 1 };
}

// error
//
// :2:35: error: 1 enum fields missing in union
// :1:13: note: field 'arst' missing, declared here
// :1:13: note: enum declared here
