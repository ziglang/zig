fn getSize() usize {
    return 2;
}
pub fn expectEqual(expected: anytype, _: @TypeOf(expected)) !void {}
pub export fn entry() void {
    try expectEqual(2, getSize());
}

// error
// backend=stage2
// target=native
//
// :6:31: error: unable to resolve comptime value
// :6:31: note: argument to parameter with comptime-only type must be comptime-known
