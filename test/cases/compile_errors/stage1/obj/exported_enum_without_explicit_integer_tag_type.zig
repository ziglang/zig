const E = enum { one, two };
comptime {
    @export(E, .{ .name = "E" });
}
const e: E = .two;
comptime {
    @export(e, .{ .name = "e" });
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:13: error: exported enum without explicit integer tag type
// tmp.zig:7:13: error: exported enum value without explicit integer tag type
