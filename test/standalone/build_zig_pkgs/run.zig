const std = @import("std");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);

    const expect_fail = blk: {
        if (std.mem.eql(u8, args[1], "fail")) break :blk true;
        if (std.mem.eql(u8, args[1], "pass")) break :blk false;
        std.debug.panic("unexpected first arg '{s}'", .{args[1]});
    };
    const expected_output = args[2];
    const child = try std.ChildProcess.init(args[3..], std.heap.page_allocator);
    defer child.deinit();
    child.stderr_behavior = .Pipe;
    try child.spawn();
    const stderr = try child.stderr.?.reader().readAllAlloc(std.heap.page_allocator, std.math.maxInt(usize));
    errdefer {
        // if we fail, dump the stderr we captured
        std.io.getStdErr().writeAll(stderr) catch @panic("failed to dump stderr in errdefer");
    }
    const passed = switch (try child.wait()) {
        .Exited => |e| e == 0,
        else => false,
    };

    if (passed) {
        if (expect_fail) return error.ZigBuildUnexpectedlyPassed;
    } else {
        if (!expect_fail) return error.ZigBuildFailed;
    }
    _ = std.mem.indexOf(u8, stderr, expected_output) orelse {
        std.debug.print("Error: did not get expected output '{s}':\n", .{expected_output});
        return error.UnexpectedOutput;
    };
}
