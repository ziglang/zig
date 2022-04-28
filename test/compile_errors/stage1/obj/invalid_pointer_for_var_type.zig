extern fn ext() usize;
var bytes: [ext()]u8 = undefined;
export fn f() void {
    for (bytes) |*b, i| {
        b.* = @as(u8, i);
    }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:13: error: unable to evaluate constant expression
