const std = @import("std");

pub fn main() !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer if (gpa_state.deinit() == .leak) @panic("leaks were detected");
    const gpa = gpa_state.allocator();
    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();
    _ = args.next() orelse unreachable; // skip executable name
    const sleep_seconds = try std.fmt.parseInt(u32, args.next() orelse unreachable, 0);

    const stdout = std.io.getStdOut();
    _ = try stdout.write("started");

    const end_time = std.time.timestamp() + sleep_seconds;
    while (std.time.timestamp() < end_time) {
        std.time.sleep(@max(end_time - std.time.timestamp(), 0) * 1_000_000_000);
    }
}
