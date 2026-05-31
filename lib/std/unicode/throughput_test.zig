const std = @import("std");
const time = std.time;
const unicode = std.unicode;

const Timer = time.Timer;

const N = 1_000_000;

const KiB = 1024;
const MiB = 1024 * KiB;
const GiB = 1024 * MiB;

const ResultCount = struct {
    count: usize,
    throughput: u64,
};

fn benchmarkCodepointCount(buf: []const u8) !ResultCount {
    var timer = try Timer.start();

    const bytes = N * buf.len;

    const start = timer.lap();
    var i: usize = 0;
    var r: usize = undefined;
    while (i < N) : (i += 1) {
        r = try @call(
            .never_inline,
            std.unicode.utf8CountCodepoints,
            .{buf},
        );
    }
    const end = timer.read();

    const elapsed_s = @as(f64, @floatFromInt(end - start)) / time.ns_per_s;
    const throughput = @as(u64, @intFromFloat(@as(f64, @floatFromInt(bytes)) / elapsed_s));

    return ResultCount{ .count = r, .throughput = throughput };
}

pub fn main() !void {
    // Size of buffer is about size of printed message.
    var stdout_buffer: [0x100]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("short ASCII strings\n", .{});
    try stdout.flush();
    {
        const result = try benchmarkCodepointCount("abc");
        try stdout.print("  count: {:5} MiB/s [{d}]\n", .{ result.throughput / (1 * MiB), result.count });
    }

    try stdout.print("short Unicode strings\n", .{});
    try stdout.flush();
    {
        const result = try benchmarkCodepointCount("ŌŌŌ");
        try stdout.print("  count: {:5} MiB/s [{d}]\n", .{ result.throughput / (1 * MiB), result.count });
    }

    try stdout.print("pure ASCII strings\n", .{});
    try stdout.flush();
    {
        const result = try benchmarkCodepointCount("hello" ** 16);
        try stdout.print("  count: {:5} MiB/s [{d}]\n", .{ result.throughput / (1 * MiB), result.count });
    }

    try stdout.print("pure Unicode strings\n", .{});
    try stdout.flush();
    {
        const result = try benchmarkCodepointCount("こんにちは" ** 16);
        try stdout.print("  count: {:5} MiB/s [{d}]\n", .{ result.throughput / (1 * MiB), result.count });
    }

    try stdout.print("mixed ASCII/Unicode strings\n", .{});
    try stdout.flush();
    {
        const result = try benchmarkCodepointCount("Hyvää huomenta" ** 16);
        try stdout.print("  count: {:5} MiB/s [{d}]\n", .{ result.throughput / (1 * MiB), result.count });
    }
    try stdout.flush();
}
