const std = @import("std");
export fn entry1() void {
    _ = @as([*c]u8, @as(u65, std.math.maxInt(u65)));
}
export fn entry2() void {
    _ = @as([*c]u8, std.math.maxInt(u65));
}

// error
// backend=stage2
// target=native
//
// :3:21: error: expected type '[*c]u8', found 'u65'
// :3:21: note: unsigned 64-bit int cannot represent all possible unsigned 65-bit values
// :6:36: error: expected type '[*c]u8', found 'comptime_int'
