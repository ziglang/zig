export fn foo1() void {
    const a: *[1]u8 = undefined;
    var b: []u8 = a;
    _ = b;
}
export fn foo2() void {
    comptime {
        var a: *[1]u8 = undefined;
        var b: []u8 = a;
        _ = b;
    }
}
export fn foo3() void {
    comptime {
        const a: *[1]u8 = undefined;
        var b: []u8 = a;
        _ = b;
    }
}

// issue #2687: coerce from undefined array pointer to slice
//
// tmp.zig:3:19: error: use of undefined value here causes undefined behavior
// tmp.zig:9:23: error: use of undefined value here causes undefined behavior
// tmp.zig:16:23: error: use of undefined value here causes undefined behavior
