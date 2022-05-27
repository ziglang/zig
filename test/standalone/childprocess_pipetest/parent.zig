const builtin = @import("builtin");
const std = @import("std");
const ChildProcess = std.ChildProcess;
const math = std.math;
const os = std.os;
const windows = os.windows;

fn testPipeInfo(self: *ChildProcess) ChildProcess.SpawnError!void {
    const windowsPtrDigits: usize = std.math.log10(math.maxInt(usize));
    const otherPtrDigits: usize = std.math.log10(math.maxInt(u32)) + 1; // +1 for sign
    if (self.extra_streams) |extra_streams| {
        for (extra_streams) |*extra| {
            const size = comptime size: {
                if (builtin.target.os.tag == .windows) {
                    break :size windowsPtrDigits;
                } else {
                    break :size otherPtrDigits;
                }
            };
            var buf = comptime [_]u8{0} ** size;
            var s_chpipe_h: []u8 = undefined;
            std.debug.assert(extra.direction == .parent_to_child);
            const handle = handle: {
                if (builtin.target.os.tag == .windows) {
                    // handle is *anyopaque and there is no other way to cast
                    break :handle @ptrToInt(extra.*.input.?.handle);
                } else {
                    break :handle extra.*.input.?.handle;
                }
            };
            s_chpipe_h = std.fmt.bufPrint(
                buf[0..],
                "{d}",
                .{handle},
            ) catch unreachable;
            try self.stdin.?.writer().writeAll(s_chpipe_h);
            try self.stdin.?.writer().writeAll("\n");
        }
    }
}

pub fn main() !void {
    const testing = std.testing;
    // TODO add proper allocator with cleaning up at end
    // we cant rely on the testing allocator doing the leak check for us
    const alloc = testing.allocator;
    const child_binary = "child";
    var child_process = ChildProcess.init(
        &[_][]const u8{child_binary},
        alloc,
    );
    child_process.stdin_behavior = .Pipe;
    var extra_streams = [_]ChildProcess.ExtraStream{
        .{
            .direction = .parent_to_child,
            .input = null,
            .output = null,
        },
    };
    child_process.extra_streams = &extra_streams;

    try child_process.spawn(testPipeInfo);
    try std.testing.expect(child_process.extra_streams.?[0].input == null);
    if (builtin.target.os.tag == .windows) {
        var handle_flags = windows.DWORD;
        try windows.GetHandleInformation(child_process.extra_streams.?[0].output.?.handle, &handle_flags);
        std.debug.assert(handle_flags & windows.HANDLE_FLAG_INHERIT != 0);
    } else {
        const fcntl_flags = try os.fcntl(child_process.extra_streams.?[0].output.?.handle, os.F.GETFD, 0);
        try std.testing.expect((fcntl_flags & os.FD_CLOEXEC) != 0);
    }

    const extra_str_wr = child_process.extra_streams.?[0].output.?.writer();
    try extra_str_wr.writeAll("test123\x17"); // ETB = \x17
    const ret_val = try child_process.wait();
    try testing.expectEqual(ret_val, .{ .Exited = 0 });
}
