export fn entry() void {
    var e = error.Foo;
    @panic(e);
}

// error
// backend=stage2
// target=native
//
// :3:12: error: expected type '[]const u8', found 'error{Foo}'
