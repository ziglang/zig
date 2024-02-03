export fn a() void {
    const E = enum {};
    var e: E = undefined;
    _ = &e;
    _ = @intFromEnum(e);
}

comptime {
    const E = union(enum(u16)) {
        a: u32,
        b: u32,
    };
    const e: E = undefined;
    _ = @intFromEnum(e);
}

// error
// backend=stage2
// target=native
//
// :14:22: error: use of undefined value here causes undefined behavior
// :5:22: error: cannot use @intFromEnum on empty enum 'tmp.a.E'
