export fn entry() void {
    foo(452) catch |err| switch (err) {
        error.Foo => {},
    };
}
fn foo(x: i32) !void {
    switch (x) {
        0...10 => return error.Foo,
        11...20 => return error.Bar,
        21...30 => return error.Baz,
        else => {},
    }
}

// error
// backend=llvm
// target=native
//
// :2:26: error: switch must handle all possibilities
// :2:26: note: unhandled error value: 'error.Bar'
// :2:26: note: unhandled error value: 'error.Baz'
