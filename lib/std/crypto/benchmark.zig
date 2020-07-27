// zig run benchmark.zig --release-fast --override-lib-dir ..

const builtin = @import("builtin");
const std = @import("std");
const time = std.time;
const Timer = time.Timer;
const crypto = std.crypto;

const KiB = 1024;
const MiB = 1024 * KiB;

var prng = std.rand.DefaultPrng.init(0);

const Crypto = struct {
    ty: type,
    name: []const u8,
};

const hashes = [_]Crypto{
    Crypto{ .ty = crypto.Md5, .name = "md5" },
    Crypto{ .ty = crypto.Sha1, .name = "sha1" },
    Crypto{ .ty = crypto.Sha256, .name = "sha256" },
    Crypto{ .ty = crypto.Sha512, .name = "sha512" },
    Crypto{ .ty = crypto.Sha3_256, .name = "sha3-256" },
    Crypto{ .ty = crypto.Sha3_512, .name = "sha3-512" },
    Crypto{ .ty = crypto.gimli.Hash, .name = "gimli-hash" },
    Crypto{ .ty = crypto.Blake2s256, .name = "blake2s" },
    Crypto{ .ty = crypto.Blake2b512, .name = "blake2b" },
    Crypto{ .ty = crypto.Blake3, .name = "blake3" },
};

pub fn benchmarkHash(comptime Hash: anytype, comptime bytes: comptime_int) !u64 {
    var h = Hash.init();

    var block: [Hash.digest_length]u8 = undefined;
    prng.random.bytes(block[0..]);

    var offset: usize = 0;
    var timer = try Timer.start();
    const start = timer.lap();
    while (offset < bytes) : (offset += block.len) {
        h.update(block[0..]);
    }
    const end = timer.read();

    const elapsed_s = @intToFloat(f64, end - start) / time.ns_per_s;
    const throughput = @floatToInt(u64, bytes / elapsed_s);

    return throughput;
}

const macs = [_]Crypto{
    Crypto{ .ty = crypto.Poly1305, .name = "poly1305" },
    Crypto{ .ty = crypto.HmacMd5, .name = "hmac-md5" },
    Crypto{ .ty = crypto.HmacSha1, .name = "hmac-sha1" },
    Crypto{ .ty = crypto.HmacSha256, .name = "hmac-sha256" },
};

pub fn benchmarkMac(comptime Mac: anytype, comptime bytes: comptime_int) !u64 {
    std.debug.assert(32 >= Mac.mac_length and 32 >= Mac.minimum_key_length);

    var in: [1 * MiB]u8 = undefined;
    prng.random.bytes(in[0..]);

    var key: [32]u8 = undefined;
    prng.random.bytes(key[0..]);

    var offset: usize = 0;
    var timer = try Timer.start();
    const start = timer.lap();
    while (offset < bytes) : (offset += in.len) {
        Mac.create(key[0..], in[0..], key[0..]);
    }
    const end = timer.read();

    const elapsed_s = @intToFloat(f64, end - start) / time.ns_per_s;
    const throughput = @floatToInt(u64, bytes / elapsed_s);

    return throughput;
}

const exchanges = [_]Crypto{Crypto{ .ty = crypto.X25519, .name = "x25519" }};

pub fn benchmarkKeyExchange(comptime DhKeyExchange: anytype, comptime exchange_count: comptime_int) !u64 {
    std.debug.assert(DhKeyExchange.minimum_key_length >= DhKeyExchange.secret_length);

    var in: [DhKeyExchange.minimum_key_length]u8 = undefined;
    prng.random.bytes(in[0..]);

    var out: [DhKeyExchange.minimum_key_length]u8 = undefined;
    prng.random.bytes(out[0..]);

    var offset: usize = 0;
    var timer = try Timer.start();
    const start = timer.lap();
    {
        var i: usize = 0;
        while (i < exchange_count) : (i += 1) {
            _ = DhKeyExchange.create(out[0..], out[0..], in[0..]);
        }
    }
    const end = timer.read();

    const elapsed_s = @intToFloat(f64, end - start) / time.ns_per_s;
    const throughput = @floatToInt(u64, exchange_count / elapsed_s);

    return throughput;
}

fn usage() void {
    std.debug.warn(
        \\throughput_test [options]
        \\
        \\Options:
        \\  --filter [test-name]
        \\  --seed   [int]
        \\  --help
        \\
    , .{});
}

fn mode(comptime x: comptime_int) comptime_int {
    return if (builtin.mode == .Debug) x / 64 else x;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().outStream();

    var buffer: [1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(buffer[0..]);
    const args = try std.process.argsAlloc(&fixed.allocator);

    var filter: ?[]u8 = "";

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

            const seed = try std.fmt.parseUnsigned(u32, args[i], 10);
            prng.seed(seed);
        } else if (std.mem.eql(u8, args[i], "--filter")) {
            i += 1;
            if (i == args.len) {
                usage();
                std.os.exit(1);
            }

            filter = args[i];
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
            const throughput = try benchmarkHash(H.ty, mode(32 * MiB));
            try stdout.print("{:>11}: {:5} MiB/s\n", .{ H.name, throughput / (1 * MiB) });
        }
    }

    inline for (macs) |M| {
        if (filter == null or std.mem.indexOf(u8, M.name, filter.?) != null) {
            const throughput = try benchmarkMac(M.ty, mode(128 * MiB));
            try stdout.print("{:>11}: {:5} MiB/s\n", .{ M.name, throughput / (1 * MiB) });
        }
    }

    inline for (exchanges) |E| {
        if (filter == null or std.mem.indexOf(u8, E.name, filter.?) != null) {
            const throughput = try benchmarkKeyExchange(E.ty, mode(1000));
            try stdout.print("{:>11}: {:5} exchanges/s\n", .{ E.name, throughput });
        }
    }
}
