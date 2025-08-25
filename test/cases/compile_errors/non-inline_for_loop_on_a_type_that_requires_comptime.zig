const Foo = struct {
    name: []const u8,
    T: type,
};
export fn entry() void {
    const xx: [2]Foo = .{ .{ .name = "", .T = u8 }, .{ .name = "", .T = u8 } };
    for (xx) |f| {
        _ = f;
    }
}

// error
// backend=stage2
// target=native
//
// :7:10: error: values of type '[2]tmp.Foo' must be comptime-known, but index value is runtime-known
// :3:8: note: struct requires comptime because of this field
// :3:8: note: types are not available at runtime
