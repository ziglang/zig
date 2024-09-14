export fn entry() void {
    foo(452) catch |err| switch (err) {
        error.Foo...error.Bar => {},
        else => {},
    };
}
fn foo(x: i32) !void {
    switch (x) {
        0...10 => return error.Foo,
        11...20 => return error.Bar,
        else => {},
    }
}

// error
// backend=llvm
// target=native
//
// :2:34: error: ranges not allowed when switching on type 'error{Foo,Bar}'
// :3:18: note: range here
