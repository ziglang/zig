export fn foo1() void {
    var bytes = [_]u8{ 1, 2 };
    const word: u16 = @bitCast(u16, bytes[0..]);
    _ = word;
}
export fn foo2() void {
    var bytes: []const u8 = &[_]u8{ 1, 2 };
    const word: u16 = @bitCast(u16, bytes);
    _ = word;
}

// error
// backend=stage2
// target=native
//
// :3:42: error: cannot @bitCast from '*[2]u8'
// :3:42: note: use @intFromPtr to cast to 'u16'
// :8:37: error: cannot @bitCast from '[]const u8'
// :8:37: note: use @intFromPtr to cast to 'u16'
