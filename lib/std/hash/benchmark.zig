// zig run -O ReleaseFast --zig-lib-dir ../.. benchmark.zig

const std = @import("std");
const builtin = @import("builtin");
const time = std.time;
const Timer = time.Timer;
const hash = std.hash;

const KiB = 1024;
const MiB = 1024 * KiB;
const GiB = 1024 * MiB;

var prng = std.rand.DefaultPrng.init(0);
const random = prng.random();

const Hash = struct {
    ty: type,
    name: []const u8,
    has_iterative_api: bool = true,
    has_crypto_api: bool = false,
    init_u8s: ?[]const u8 = null,
    init_u64: ?u64 = null,
};

const hashes = [_]Hash{
    Hash{
        .ty = hash.XxHash64,
        .name = "xxhash64",
        .init_u64 = 0,
    },
    Hash{
        .ty = hash.XxHash32,
        .name = "xxhash32",
        .init_u64 = 0,
    },
    Hash{
        .ty = hash.Wyhash,
        .name = "wyhash",
        .init_u64 = 0,
    },
    Hash{
        .ty = hash.Fnv1a_64,
        .name = "fnv1a",
    },
    Hash{
        .ty = hash.Adler32,
        .name = "adler32",
    },
    Hash{
        .ty = hash.crc.Crc32WithPoly(.IEEE),
        .name = "crc32-slicing-by-8",
    },
    Hash{
        .ty = hash.crc.Crc32SmallWithPoly(.IEEE),
        .name = "crc32-half-byte-lookup",
    },
    Hash{
        .ty = hash.CityHash32,
        .name = "cityhash-32",
        .has_iterative_api = false,
    },
    Hash{
        .ty = hash.CityHash64,
        .name = "cityhash-64",
        .has_iterative_api = false,
    },
    Hash{
        .ty = hash.Murmur2_32,
        .name = "murmur2-32",
        .has_iterative_api = false,
    },
    Hash{
        .ty = hash.Murmur2_64,
        .name = "murmur2-64",
        .has_iterative_api = false,
    },
    Hash{
        .ty = hash.Murmur3_32,
        .name = "murmur3-32",
        .has_iterative_api = false,
    },
    Hash{
        .ty = hash.SipHash64(1, 3),
        .name = "siphash64",
        .has_crypto_api = true,
        .init_u8s = &[_]u8{0} ** 16,
    },
    Hash{
        .ty = hash.SipHash128(1, 3),
        .name = "siphash128",
        .has_crypto_api = true,
        .init_u8s = &[_]u8{0} ** 16,
    },
};

const Result = struct {
    hash: u64,
    throughput: u64,
};

const block_size: usize = 8 * 8192;
const alignment: usize = 64;

pub fn benchmarkHash(comptime H: anytype, bytes: usize, allocator: std.mem.Allocator) !Result {
    const blocks_count = bytes / block_size;
    var blocks = try allocator.alloc(u8, block_size + alignment * (blocks_count - 1));
    defer allocator.free(blocks);
    random.bytes(blocks);

    var h = blk: {
        if (H.init_u8s) |init| {
            break :blk H.ty.init(init[0..H.ty.key_length]);
        }
        if (H.init_u64) |init| {
            break :blk H.ty.init(init);
        }
        break :blk H.ty.init();
    };

    var timer = try Timer.start();
    const start = timer.lap();
    for (0..blocks_count) |i| {
        h.update(blocks[i * alignment ..][0..block_size]);
    }
    const final = if (H.has_crypto_api) @truncate(u64, h.finalInt()) else h.final();
    std.mem.doNotOptimizeAway(final);

    const end = timer.read();

    const elapsed_s = @floatFromInt(f64, end - start) / time.ns_per_s;
    const throughput = @intFromFloat(u64, @floatFromInt(f64, bytes) / elapsed_s);

    return Result{
        .hash = final,
        .throughput = throughput,
    };
}

pub fn benchmarkHashSmallKeys(comptime H: anytype, key_size: usize, bytes: usize, allocator: std.mem.Allocator) !Result {
    var blocks = try allocator.alloc(u8, bytes);
    defer allocator.free(blocks);
    random.bytes(blocks);

    const key_count = bytes / key_size;

    var timer = try Timer.start();
    const start = timer.lap();

    var sum: u64 = 0;
    for (0..key_count) |i| {
        const small_key = blocks[i * key_size ..][0..key_size];
        const final = blk: {
            if (H.init_u8s) |init| {
                if (H.has_crypto_api) {
                    break :blk @truncate(u64, H.ty.toInt(small_key, init[0..H.ty.key_length]));
                } else {
                    break :blk H.ty.hash(init, small_key);
                }
            }
            if (H.init_u64) |init| {
                break :blk H.ty.hash(init, small_key);
            }
            break :blk H.ty.hash(small_key);
        };
        sum +%= final;
    }
    const end = timer.read();

    const elapsed_s = @floatFromInt(f64, end - start) / time.ns_per_s;
    const throughput = @intFromFloat(u64, @floatFromInt(f64, bytes) / elapsed_s);

    std.mem.doNotOptimizeAway(sum);

    return Result{
        .hash = sum,
        .throughput = throughput,
    };
}

fn usage() void {
    std.debug.print(
        \\throughput_test [options]
        \\
        \\Options:
        \\  --filter    [test-name]
        \\  --seed      [int]
        \\  --count     [int]
        \\  --key-size  [int]
        \\  --iterative-only
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
    var key_size: usize = 32;
    var seed: u32 = 0;
    var test_iterative_only = false;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--mode")) {
            try stdout.print("{}\n", .{builtin.mode});
            return;
        } else if (std.mem.eql(u8, args[i], "--seed")) {
            i += 1;
            if (i == args.len) {
                usage();
                std.os.exit(1);
            }

            seed = try std.fmt.parseUnsigned(u32, args[i], 10);
            // we seed later
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
        } else if (std.mem.eql(u8, args[i], "--key-size")) {
            i += 1;
            if (i == args.len) {
                usage();
                std.os.exit(1);
            }

            key_size = try std.fmt.parseUnsigned(usize, args[i], 10);
            if (key_size > block_size) {
                try stdout.print("key_size cannot exceed block size of {}\n", .{block_size});
                std.os.exit(1);
            }
        } else if (std.mem.eql(u8, args[i], "--iterative-only")) {
            test_iterative_only = true;
        } else if (std.mem.eql(u8, args[i], "--help")) {
            usage();
            return;
        } else {
            usage();
            std.os.exit(1);
        }
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    inline for (hashes) |H| {
        if (filter == null or std.mem.indexOf(u8, H.name, filter.?) != null) {
            if (!test_iterative_only or H.has_iterative_api) {
                try stdout.print("{s}\n", .{H.name});

                // Always reseed prior to every call so we are hashing the same buffer contents.
                // This allows easier comparison between different implementations.
                if (H.has_iterative_api) {
                    prng.seed(seed);
                    const result = try benchmarkHash(H, count, allocator);
                    try stdout.print("   iterative: {:5} MiB/s [{x:0<16}]\n", .{ result.throughput / (1 * MiB), result.hash });
                }

                if (!test_iterative_only) {
                    prng.seed(seed);
                    const result_small = try benchmarkHashSmallKeys(H, key_size, count, allocator);
                    try stdout.print("  small keys: {:5} MiB/s [{x:0<16}]\n", .{ result_small.throughput / (1 * MiB), result_small.hash });
                }
            }
        }
    }
}
