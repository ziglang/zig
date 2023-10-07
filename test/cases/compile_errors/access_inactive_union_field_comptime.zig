const Enum = enum(u32) { b, a };
const TaggedUnion = union(Enum) {
    b: []const u8,
    a: []const u8,
};
pub export fn entry() void {
    const result = TaggedUnion{ .b = "b" };
    _ = result.b;
    _ = result.a;
}
pub export fn entry1() void {
    const result = TaggedUnion{ .b = "b" };
    _ = &result.b;
    _ = &result.a;
}

// error
// backend=stage2
// target=native
//
// :9:15: error: access of union field 'a' while field 'b' is active
// :2:21: note: union declared here
// :14:16: error: access of union field 'a' while field 'b' is active
// :2:21: note: union declared here
