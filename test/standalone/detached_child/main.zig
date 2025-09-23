const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;

extern "kernel32" fn GetProcessId(Process: windows.HANDLE) callconv(windows.WINAPI) windows.DWORD;
extern "kernel32" fn GetConsoleProcessList(
    lpdwProcessList: [*]windows.DWORD,
    dwProcessCount: windows.DWORD,
) callconv(windows.WINAPI) windows.DWORD;

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
    try child.waitForSpawn();
    defer {
        _ = child.kill() catch {};
    }

    // Give the process some time to actually start doing something before
    // checking if it properly detached.
    var read_buffer: [1]u8 = undefined;
    if (try child.stdout.?.read(&read_buffer) != 1) {
        return error.OutputReadFailed;
    }

    switch (builtin.os.tag) {
        .windows => {
            const child_pid = GetProcessId(child.id);
            if (child_pid == 0) return error.GetProcessIdFailed;

            var proc_buffer: []windows.DWORD = undefined;
            var proc_count: windows.DWORD = 16;
            while (true) {
                proc_buffer = try gpa.alloc(windows.DWORD, proc_count);
                defer gpa.free(proc_buffer);

                proc_count = GetConsoleProcessList(proc_buffer.ptr, @min(proc_buffer.len, std.math.maxInt(windows.DWORD)));
                if (proc_count == 0) return error.ConsoleProcessListFailed;

                if (proc_count <= proc_buffer.len) {
                    for (proc_buffer[0..proc_count]) |proc| {
                        if (proc == child_pid) return error.ProcessAttachedToConsole;
                    }
                    break;
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
