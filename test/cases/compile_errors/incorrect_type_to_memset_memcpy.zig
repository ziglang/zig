pub export fn entry() void {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    const slice: []u8 = &buf;
    const a: u32 = 1234;
    @memcpy(slice.ptr, @as([*]const u8, @ptrCast(&a)));
}
pub export fn entry1() void {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    const ptr: *u8 = &buf[0];
    @memcpy(ptr, 0);
}
pub export fn entry2() void {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    const ptr: *u8 = &buf[0];
    @memset(ptr, 0);
}
pub export fn non_matching_lengths() void {
    var buf1: [5]u8 = .{ 1, 2, 3, 4, 5 };
    var buf2: [6]u8 = .{ 1, 2, 3, 4, 5, 6 };
    @memcpy(&buf2, &buf1);
}
pub export fn memset_const_dest_ptr() void {
    const buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    @memset(&buf, 1);
}
pub export fn memcpy_const_dest_ptr() void {
    const buf1: [5]u8 = .{ 1, 2, 3, 4, 5 };
    var buf2: [5]u8 = .{ 1, 2, 3, 4, 5 };
    @memcpy(&buf1, &buf2);
}
pub export fn memset_array() void {
    const buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    @memcpy(buf, 1);
}

// error
// backend=stage2
// target=native
//
// :5:5: error: unknown @memcpy length
// :5:18: note: destination type '[*]u8' provides no length
// :5:24: note: source type '[*]const u8' provides no length
// :10:13: error: type '*u8' is not an indexable pointer
// :10:13: note: operand must be a slice, a many pointer or a pointer to an array
// :15:13: error: type '*u8' is not an indexable pointer
// :15:13: note: operand must be a slice, a many pointer or a pointer to an array
// :20:5: error: non-matching @memcpy lengths
// :20:13: note: length 6 here
// :20:20: note: length 5 here
// :24:13: error: cannot memset constant pointer
// :29:13: error: cannot memcpy to constant pointer
// :33:13: error: type '[5]u8' is not an indexable pointer
// :33:13: note: operand must be a slice, a many pointer or a pointer to an array
