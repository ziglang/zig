export fn entry() void {
    var e = error.Foo;
    @panic(e);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:12: error: expected type '[]const u8', found 'error{Foo}'
