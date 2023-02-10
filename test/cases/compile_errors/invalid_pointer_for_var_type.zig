extern fn ext() usize;
var bytes: [ext()]u8 = undefined;
export fn f() void {
    for (bytes) |*b, i| {
        b.* = @as(u8, i);
    }
}

// error
// backend=stage2
// target=native
//
// :2:16: error: comptime call of extern function
