const std = @import("std");

pub fn main() !void {
    const in_args = try std.process.argsAlloc(std.heap.page_allocator);

    const expect_pass = blk: {
        if (std.mem.eql(u8, in_args[1], "expect-pass")) break :blk true;
        std.debug.assert(std.mem.eql(u8, in_args[1], "expect-fail"));
        break :blk false;
    };

    const zig_exe = in_args[2];
    var out_args = std.ArrayList([]const u8).init(std.heap.page_allocator);
    try out_args.append(zig_exe);
    try out_args.append("build");
    try out_args.append("--pkg-begin");
    try out_args.append("androidbuild");
    try out_args.append("androidbuild.zig");
    try out_args.append("--pkg-end");
    for (in_args[3..]) |cmd_arg| {
        try out_args.append(cmd_arg);
    }

    const child = try std.ChildProcess.init(out_args.items, std.heap.page_allocator);
    defer child.deinit();

    // redirect stderr so it doesn't show up in the test log
    child.stderr_behavior = .Pipe;
    errdefer {
        if (child.stderr) |stderr| {
            const err = stderr.reader().readAllAlloc(std.heap.page_allocator, std.math.maxInt(usize)) catch unreachable;
            std.io.getStdErr().writeAll(err) catch unreachable;
        }
    }

    const passed = switch (try child.spawnAndWait()) {
        .Exited => |e| e == 0,
        else => false,
    };
    if (passed) {
        if (expect_pass) return;
        return error.ZigBuildUnexpectedlyPassed;
    }
    if (expect_pass) {
        return error.ZigBuildFailed;
    }
}
