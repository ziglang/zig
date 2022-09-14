pub fn panic(comptime msg: []const u8, error_return_trace: ?*builtin.StackTrace, _: ?usize) noreturn {
    _ = msg; _ = error_return_trace;
    while (true) {}
}
const builtin = @import("std").builtin;

// error
// backend=stage1
// target=native
//
// error: expected type 'fn([]const u8, ?*std.builtin.StackTrace, ?usize) noreturn', found 'fn([]const u8,anytype,anytype) anytype'
// note: only one of the functions is generic
