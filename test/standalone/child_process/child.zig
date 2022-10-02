const std = @import("std");

// 42 is expected by parent; other values result in test failure
var exit_code: u8 = 42;

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const arena = arena_state.allocator();
    try run(arena);
    arena_state.deinit();
    std.process.exit(exit_code);
}

fn run(allocator: std.mem.Allocator) !void {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next() orelse unreachable; // skip binary name

    // test cmd args
    const hello_arg = "hello arg";
    const a1 = args.next() orelse unreachable;
    if (!std.mem.eql(u8, a1, hello_arg)) {
        testError("first arg: '{s}'; want '{s}'", .{ a1, hello_arg });
    }
    if (args.next()) |a2| {
        testError("expected only one arg; got more: {s}", .{a2});
    }

    // test stdout pipe; parent verifies
    try std.io.getStdOut().writer().writeAll("hello from stdout");

    // test stdin pipe from parent
    const hello_stdin = "hello from stdin";
    var buf: [hello_stdin.len]u8 = undefined;
    const stdin = std.io.getStdIn().reader();
    const n = try stdin.readAll(&buf);
    if (!std.mem.eql(u8, buf[0..n], hello_stdin)) {
        testError("stdin: '{s}'; want '{s}'", .{ buf[0..n], hello_stdin });
    }
}

fn testError(comptime fmt: []const u8, args: anytype) void {
    const stderr = std.io.getStdErr().writer();
    stderr.print("CHILD TEST ERROR: ", .{}) catch {};
    stderr.print(fmt, args) catch {};
    if (fmt[fmt.len - 1] != '\n') {
        stderr.writeByte('\n') catch {};
    }
    exit_code = 1;
}
