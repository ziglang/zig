export fn entry() void {
    foo(452) catch |err| switch (err) {
        error.Foo => {},
    };
}
fn foo(x: i32) !void {
    switch (x) {
        0 ... 10 => return error.Foo,
        11 ... 20 => return error.Bar,
        21 ... 30 => return error.Baz,
        else => {},
    }
}

// error not handled in switch
//
// tmp.zig:2:26: error: error.Baz not handled in switch
// tmp.zig:2:26: error: error.Bar not handled in switch
