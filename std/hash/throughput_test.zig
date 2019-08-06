const builtin = @import("builtin");
const std = @import("std");
const time = std.time;
const Timer = time.Timer;
const hash = std.hash;

const KiB = 1024;
const MiB = 1024 * KiB;
const GiB = 1024 * MiB;

var prng = std.rand.DefaultPrng.init(0);

const Hash = struct {
    ty: type,
    name: []const u8,
    init_u8s: ?[]const u8 = null,
    init_u64: ?u64 = null,
};

const siphash_key = "0123456789abcdef";

const hashes = [_]Hash{
    Hash{ .ty = hash.Wyhash, .name = "wyhash", .init_u64 = 0 },
    Hash{ .ty = hash.SipHash64(1, 3), .name = "siphash(1,3)", .init_u8s = siphash_key },
    Hash{ .ty = hash.SipHash64(2, 4), .name = "siphash(2,4)", .init_u8s = siphash_key },
    Hash{ .ty = hash.Fnv1a_64, .name = "fnv1a" },
    Hash{ .ty = hash.Crc32, .name = "crc32" },
};

const Result = struct {
    hash: u64,
    throughput: u64,
};

pub fn benchmarkHash(comptime H: var, bytes: usize) !Result {
    var h = blk: {
        if (H.init_u8s) |init| {
            break :blk H.ty.init(init);
        }
        if (H.init_u64) |init| {
            break :blk H.ty.init(init);
        }
        break :blk H.ty.init();
    };

    var block: [8192]u8 = undefined;
    prng.random.bytes(block[0..]);

    var offset: usize = 0;
    var timer = try Timer.start();
    const start = timer.lap();
    while (offset < bytes) : (offset += block.len) {
        h.update(block[0..]);
    }
    const end = timer.read();

    const elapsed_s = @intToFloat(f64, end - start) / time.ns_per_s;
    const throughput = @floatToInt(u64, @intToFloat(f64, bytes) / elapsed_s);

    return Result{
        .hash = h.final(),
        .throughput = throughput,
    };
}

fn usage() void {
    std.debug.warn(
        \\throughput_test [options]
        \\
        \\Options:
        \\  --filter [test-name]
        \\  --seed   [int]
        \\  --count  [int]
        \\  --help
        \\
    );
}

fn mode(comptime x: comptime_int) comptime_int {
    return if (builtin.mode == builtin.Mode.Debug) x / 64 else x;
}

// TODO(#1358): Replace with builtin formatted padding when available.
fn printPad(stdout: var, s: []const u8) !void {
    var i: usize = 0;
    while (i < 12 - s.len) : (i += 1) {
        try stdout.print(" ");
    }
    try stdout.print("{}", s);
}

pub fn main() !void {
    var stdout_file = try std.io.getStdOut();
    var stdout_out_stream = stdout_file.outStream();
    const stdout = &stdout_out_stream.stream;

    var buffer: [1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(buffer[0..]);
    const args = try std.process.argsAlloc(&fixed.allocator);

    var filter: ?[]u8 = "";
    var count: usize = mode(128 * MiB);

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--seed")) {
            i += 1;
            if (i == args.len) {
                usage();
                std.os.exit(1);
            }

            const seed = try std.fmt.parseUnsigned(u32, args[i], 10);
            prng.seed(seed);
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

            const c = try std.fmt.parseUnsigned(u32, args[i], 10);
            count = c * MiB;
        } else if (std.mem.eql(u8, args[i], "--help")) {
            usage();
            return;
        } else {
            usage();
            std.os.exit(1);
        }
    }

    inline for (hashes) |H| {
        if (filter == null or std.mem.indexOf(u8, H.name, filter.?) != null) {
            const result = try benchmarkHash(H, count);
            try printPad(stdout, H.name);
            try stdout.print(": {:4} MiB/s [{:16}]\n", result.throughput / (1 * MiB), result.hash);
        }
    }
}
