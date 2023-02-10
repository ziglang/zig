export fn entry() void {
    foo(452) catch |err| switch (err) {
        error.Foo => {},
        error.Bar => {},
        error.Foo => {},
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
// :5:9: error: duplicate switch value
// :3:9: note: previous value here
