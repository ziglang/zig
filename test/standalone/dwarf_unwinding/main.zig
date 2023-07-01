const std = @import("std");
const debug = std.debug;
const testing = std.testing;

noinline fn frame4(expected: *[4]usize, unwound: *[4]usize) void {
    expected[0] = @returnAddress();

    var context: debug.StackTraceContext = undefined;
    testing.expect(debug.getContext(&context)) catch @panic("failed to getContext");

    var debug_info = debug.getSelfDebugInfo() catch @panic("failed to openSelfDebugInfo");
    var it = debug.StackIterator.initWithContext(null, debug_info, &context) catch @panic("failed to initWithContext");
    defer it.deinit();

    for (unwound) |*addr| {
        if (it.next()) |return_address| addr.* = return_address;
    }
}

noinline fn frame3(expected: *[4]usize, unwound: *[4]usize) void {
    expected[1] = @returnAddress();
    frame4(expected, unwound);
}

fn frame2(expected: *[4]usize, unwound: *[4]usize) callconv(.C) void {
    frame3(expected, unwound);
}

extern fn frame0(
    expected: *[4]usize,
    unwound: *[4]usize,
    frame_2: *const fn (expected: *[4]usize, unwound: *[4]usize) callconv(.C) void,
) void;

pub fn main() !void {
    var expected: [4]usize = undefined;
    var unwound: [4]usize = undefined;
    frame0(&expected, &unwound, &frame2);
    try testing.expectEqual(expected, unwound);
}
