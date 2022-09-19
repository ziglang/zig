pub export fn entry() void {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    var slice: []u8 = &buf;
    const a: u32 = 1234;
    @memcpy(slice, @ptrCast([*]const u8, &a), 4);
}
pub export fn entry1() void {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    var ptr: *u8 = &buf[0];
    @memcpy(ptr, 0, 4);
}

// error
// backend=stage2
// target=native
//
// :5:13: error: expected type '[*]u8', found '[]u8'
// :10:13: error: expected type '[*]u8', found '*u8'
// :10:13: note: a single pointer cannot cast into a many pointer
