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

    const argv = &.{""};
    var child = std.process.Child.init(argv, gpa);
    child.stdin_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    child.detached = true;
    child.pgid = if (builtin.os.tag == .windows) void{} else try std.posix.getsid(0);
    defer {
        _ = child.kill() catch {};
    }

    if (child.spawn()) {
        if (child.waitForSpawn()) {
            return error.SpawnSilencedError;
        } else |_| {}
    } else |_| {}

    child = std.process.Child.init(&.{ child_path, "30" }, gpa);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Inherit;

    // this spawn should succeed and return without an error
    try child.spawn();
}
