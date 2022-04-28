export fn entry() void {
    try foo(452) catch |err| switch (err) {
        error.A ... error.B => {},
        else => {},
    };
}
fn foo(x: i32) !void {
    switch (x) {
        0 ... 10 => return error.Foo,
        11 ... 20 => return error.Bar,
        else => {},
    }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:17: error: operator not allowed for errors
