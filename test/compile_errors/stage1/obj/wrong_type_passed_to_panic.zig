export fn entry() void {
    var e = error.Foo;
    @panic(e);
}

// wrong type passed to @panic
//
// tmp.zig:3:12: error: expected type '[]const u8', found 'error{Foo}'
