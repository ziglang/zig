export fn entry() void {
    const e = error.Foo;
    @panic(e);
}

// error
//
// :3:12: error: expected type '[]const u8', found 'error{Foo}'
