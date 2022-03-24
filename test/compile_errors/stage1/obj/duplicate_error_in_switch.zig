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
        0 ... 10 => return error.Foo,
        11 ... 20 => return error.Bar,
        else => {},
    }
}

// duplicate error in switch
//
// tmp.zig:5:14: error: duplicate switch value: '@typeInfo(@typeInfo(@TypeOf(foo)).Fn.return_type.?).ErrorUnion.error_set.Foo'
// tmp.zig:3:14: note: other value here
