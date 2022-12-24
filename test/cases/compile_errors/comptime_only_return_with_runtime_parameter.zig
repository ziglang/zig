const std = @import("std");

export fn entry() void {
    _ = this_crashes_stage1("Hello World", .{});
}

fn this_crashes_stage1(comptime format: []const u8, args: anytype) comptime_int {
    std.log.warn(format, args);
    return 0;
}
