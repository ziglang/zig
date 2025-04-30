const Tag = @Enum(u1, .exhaustive, &.{ "signed", "unsigned" }, &.{ 0, 1 });
const Tagged = @Union(.auto, Tag, &.{}, &.{}, &.{});
export fn entry() void {
    const tagged: Tagged = undefined;
    _ = tagged;
}

// error
//
// :2:35: error: 2 enum fields missing in union
// :1:13: note: field 'signed' missing, declared here
// :1:13: note: field 'unsigned' missing, declared here
// :1:13: note: enum declared here
