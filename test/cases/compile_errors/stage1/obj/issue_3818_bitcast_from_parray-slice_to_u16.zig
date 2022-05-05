export fn foo1() void {
    var bytes = [_]u8{1, 2};
    const word: u16 = @bitCast(u16, bytes[0..]);
    _ = word;
}
export fn foo2() void {
    var bytes: []const u8 = &[_]u8{1, 2};
    const word: u16 = @bitCast(u16, bytes);
    _ = word;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:42: error: unable to @bitCast from pointer type '*[2]u8'
// tmp.zig:8:32: error: destination type 'u16' has size 2 but source type '[]const u8' has size 16
