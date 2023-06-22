// zig run -O ReleaseFast --zig-lib-dir ../.. benchmark.zig

const std = @import("std");
const builtin = @import("builtin");
const time = std.time;
const Timer = time.Timer;
const rand = std.rand;

const KiB = 1024;
const MiB = 1024 * KiB;
const GiB = 1024 * MiB;

const Rng = struct {
    ty: type,
    name: []const u8,
    init_u8s: ?[]const u8 = null,
    init_u64: ?u64 = null,
};

const prngs = [_]Rng{
    Rng{
        .ty = rand.Isaac64,
        .name = "isaac64",
        .init_u64 = 0,
    },
    Rng{
        .ty = rand.Pcg,
        .name = "pcg",
        .init_u64 = 0,
    },
    Rng{
        .ty = rand.RomuTrio,
        .name = "romutrio",
        .init_u64 = 0,
    },
    Rng{
        .ty = std.rand.Sfc64,
        .name = "sfc64",
        .init_u64 = 0,
    },
    Rng{
        .ty = std.rand.Xoroshiro128,
        .name = "xoroshiro128",
        .init_u64 = 0,
    },
    Rng{
        .ty = std.rand.Xoshiro256,
        .name = "xoshiro256",
        .init_u64 = 0,
    },
};

const csprngs = [_]Rng{
    Rng{
        .ty = rand.Ascon,
        .name = "ascon",
        .init_u8s = &[_]u8{0} ** 32,
    },
    Rng{
        .ty = rand.ChaCha,
        .name = "chacha",
        .init_u8s = &[_]u8{0} ** 32,
    },
};

const Result = struct {
    throughput: u64,
};

const long_block_size: usize = 8 * 8192;
const short_block_size: usize = 8;

pub fn benchmark(comptime H: anytype, bytes: usize, comptime block_size: usize) !Result {
    var rng = blk: {
        if (H.init_u8s) |init| {
            break :blk H.ty.init(init[0..].*);
        }
        if (H.init_u64) |init| {
            break :blk H.ty.init(init);
        }
        break :blk H.ty.init();
    };

    var block: [block_size]u8 = undefined;

    var offset: usize = 0;
    var timer = try Timer.start();
    const start = timer.lap();
    while (offset < bytes) : (offset += block.len) {
        rng.fill(block[0..]);
    }
    const end = timer.read();

    const elapsed_s = @as(f64, @floatFromInt(end - start)) / time.ns_per_s;
    const throughput = @as(u64, @intFromFloat(@as(f64, @floatFromInt(bytes)) / elapsed_s));

    std.debug.assert(rng.random().int(u64) != 0);

    return Result{
        .throughput = throughput,
    };
}

fn usage() void {
    std.debug.print(
        \\throughput_test [options]
        \\
        \\Options:
        \\  --filter    [test-name]
        \\  --count     [int]
        \\  --prngs-only
        \\  --csprngs-only
        \\  --short-only
        \\  --long-only
        \\  --help
        \\
    , .{});
}

fn mode(comptime x: comptime_int) comptime_int {
    return if (builtin.mode == .Debug) x / 64 else x;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var buffer: [1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(buffer[0..]);
    const args = try std.process.argsAlloc(fixed.allocator());

    var filter: ?[]u8 = "";
    var count: usize = mode(128 * MiB);
    var bench_prngs = true;
    var bench_csprngs = true;
    var bench_long = true;
    var bench_short = true;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--mode")) {
            try stdout.print("{}\n", .{builtin.mode});
            return;
        } else if (std.mem.eql(u8, args[i], "--filter")) {
            i += 1;
            if (i == args.len) {
                usage();
                std.os.exit(1);
            }

            filter = args[i];
        } else if (std.mem.eql(u8, args[i], "--count")) {
            i += 1;
            if (i == args.len) {
                usage();
                std.os.exit(1);
            }

            const c = try std.fmt.parseUnsigned(usize, args[i], 10);
            count = c * MiB;
        } else if (std.mem.eql(u8, args[i], "--csprngs-only")) {
            bench_prngs = false;
        } else if (std.mem.eql(u8, args[i], "--prngs-only")) {
            bench_csprngs = false;
        } else if (std.mem.eql(u8, args[i], "--short-only")) {
            bench_long = false;
        } else if (std.mem.eql(u8, args[i], "--long-only")) {
            bench_short = false;
        } else if (std.mem.eql(u8, args[i], "--help")) {
            usage();
            return;
        } else {
            usage();
            std.os.exit(1);
        }
    }

    if (bench_prngs) {
        if (bench_long) {
            inline for (prngs) |R| {
                if (filter == null or std.mem.indexOf(u8, R.name, filter.?) != null) {
                    try stdout.print("{s} (long outputs)\n", .{R.name});
                    const result_long = try benchmark(R, count, long_block_size);
                    try stdout.print("    {:5} MiB/s\n", .{result_long.throughput / (1 * MiB)});
                }
            }
        }
        if (bench_short) {
            inline for (prngs) |R| {
                if (filter == null or std.mem.indexOf(u8, R.name, filter.?) != null) {
                    try stdout.print("{s} (short outputs)\n", .{R.name});
                    const result_short = try benchmark(R, count, short_block_size);
                    try stdout.print("    {:5} MiB/s\n", .{result_short.throughput / (1 * MiB)});
                }
            }
        }
    }
    if (bench_csprngs) {
        if (bench_long) {
            inline for (csprngs) |R| {
                if (filter == null or std.mem.indexOf(u8, R.name, filter.?) != null) {
                    try stdout.print("{s} (cryptographic, long outputs)\n", .{R.name});
                    const result_long = try benchmark(R, count, long_block_size);
                    try stdout.print("    {:5} MiB/s\n", .{result_long.throughput / (1 * MiB)});
                }
            }
        }
        if (bench_short) {
            inline for (csprngs) |R| {
                if (filter == null or std.mem.indexOf(u8, R.name, filter.?) != null) {
                    try stdout.print("{s} (cryptographic, short outputs)\n", .{R.name});
                    const result_short = try benchmark(R, count, short_block_size);
                    try stdout.print("    {:5} MiB/s\n", .{result_short.throughput / (1 * MiB)});
                }
            }
        }
    }
}
