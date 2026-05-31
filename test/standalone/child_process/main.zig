const std = @import("std");

pub fn main() !void {
    // make sure safety checks are enabled even in release modes
    var gpa_state = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer if (gpa_state.deinit() != .ok) {
        @panic("found memory leaks");
    };
    const gpa = gpa_state.allocator();

    var it = try std.process.argsWithAllocator(gpa);
    defer it.deinit();
    _ = it.next() orelse unreachable; // skip binary name
    const child_path, const needs_free = child_path: {
        const child_path = it.next() orelse unreachable;
        const cwd_path = it.next() orelse break :child_path .{ child_path, false };
        // If there is a third argument, it is the current CWD somewhere within the cache directory.
        // In that case, modify the child path in order to test spawning a path with a leading `..` component.
        break :child_path .{ try std.fs.path.relative(gpa, cwd_path, child_path), true };
    };
    defer if (needs_free) gpa.free(child_path);

    var threaded: std.Io.Threaded = .init(gpa);
    defer threaded.deinit();
    const io = threaded.io();

    var child = std.process.Child.init(&.{ child_path, "hello arg" }, gpa);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    const child_stdin = child.stdin.?;
    try child_stdin.writeAll("hello from stdin"); // verified in child
    child_stdin.close();
    child.stdin = null;

    const hello_stdout = "hello from stdout";
    var buf: [hello_stdout.len]u8 = undefined;
    var stdout_reader = child.stdout.?.readerStreaming(io, &.{});
    const n = try stdout_reader.interface.readSliceShort(&buf);
    if (!std.mem.eql(u8, buf[0..n], hello_stdout)) {
        testError("child stdout: '{s}'; want '{s}'", .{ buf[0..n], hello_stdout });
    }

    switch (try child.wait()) {
        .Exited => |code| {
            const child_ok_code = 42; // set by child if no test errors
            if (code != child_ok_code) {
                testError("child exit code: {d}; want {d}", .{ code, child_ok_code });
            }
        },
        else => |term| testError("abnormal child exit: {}", .{term}),
    }
    if (parent_test_error) return error.ParentTestError;

    // Check that FileNotFound is consistent across platforms when trying to spawn an executable that doesn't exist
    const missing_child_path = try std.mem.concat(gpa, u8, &.{ child_path, "_intentionally_missing" });
    defer gpa.free(missing_child_path);
    try std.testing.expectError(error.FileNotFound, std.process.Child.run(.{ .allocator = gpa, .argv = &.{missing_child_path} }));
}

var parent_test_error = false;

fn testError(comptime fmt: []const u8, args: anytype) void {
    var stderr_writer = std.fs.File.stderr().writer(&.{});
    const stderr = &stderr_writer.interface;
    stderr.print("PARENT TEST ERROR: ", .{}) catch {};
    stderr.print(fmt, args) catch {};
    if (fmt[fmt.len - 1] != '\n') {
        stderr.writeByte('\n') catch {};
    }
    parent_test_error = true;
}
