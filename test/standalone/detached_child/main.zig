const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer if (gpa_state.deinit() == .leak) @panic("memory leak detected");
    const gpa = gpa_state.allocator();

    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();
    _ = args.next() orelse unreachable; // skip executable name
    const child_path = args.next() orelse unreachable;

    var child = std.process.Child.init(&.{ child_path, "30" }, gpa);
    child.stdin_behavior = .Ignore;
    child.stderr_behavior = .Inherit;
    child.stdout_behavior = .Pipe;
    child.detached = true;
    try child.spawn();
    defer {
        _ = child.kill() catch {};
    }

    switch (builtin.os.tag) {
        .windows => {
            const windows = std.os.windows;
            const child_pid = try windows.GetProcessId(child.id);

            // Give the process some time to actually start doing something.
            // If we check the process list immediately, we might be done before
            // the new process attaches to the console.
            var read_buffer: [1]u8 = undefined;
            try std.testing.expectEqual(1, try child.stdout.?.read(&read_buffer));

            var proc_buffer: [16]windows.DWORD = undefined;
            const proc_count = try windows.GetConsoleProcessList(&proc_buffer);
            if (proc_count > 16) @panic("process buffer is too small");

            for (proc_buffer[0..proc_count]) |proc| {
                if (proc == child_pid) {
                    return error.ProcessAttachedToConsole;
                }
            }
        },
        else => {
            const posix = std.posix;
            const current_sid = try posix.getsid(0);
            const child_sid = try posix.getsid(child.id);

            if (current_sid == child_sid) {
                return error.SameChildSession;
            }
        },
    }
}
