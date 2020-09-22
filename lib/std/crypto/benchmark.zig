// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// zig run benchmark.zig --release-fast --override-lib-dir ..

const std = @import("../std.zig");
const builtin = std.builtin;
const mem = std.mem;
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
    Crypto{ .ty = crypto.hash.Md5, .name = "md5" },
    Crypto{ .ty = crypto.hash.Sha1, .name = "sha1" },
    Crypto{ .ty = crypto.hash.sha2.Sha256, .name = "sha256" },
    Crypto{ .ty = crypto.hash.sha2.Sha512, .name = "sha512" },
    Crypto{ .ty = crypto.hash.sha3.Sha3_256, .name = "sha3-256" },
    Crypto{ .ty = crypto.hash.sha3.Sha3_512, .name = "sha3-512" },
    Crypto{ .ty = crypto.hash.Gimli, .name = "gimli-hash" },
    Crypto{ .ty = crypto.hash.blake2.Blake2s256, .name = "blake2s" },
    Crypto{ .ty = crypto.hash.blake2.Blake2b512, .name = "blake2b" },
    Crypto{ .ty = crypto.hash.Blake3, .name = "blake3" },
};

pub fn benchmarkHash(comptime Hash: anytype, comptime bytes: comptime_int) !u64 {
    var h = Hash.init(.{});

    var block: [Hash.digest_length]u8 = undefined;
    prng.random.bytes(block[0..]);

    var offset: usize = 0;
    var timer = try Timer.start();
    const start = timer.lap();
    while (offset < bytes) : (offset += block.len) {
        h.update(block[0..]);
    }
    mem.doNotOptimizeAway(&h);
    const end = timer.read();

    const elapsed_s = @intToFloat(f64, end - start) / time.ns_per_s;
    const throughput = @floatToInt(u64, bytes / elapsed_s);

    return throughput;
}

const macs = [_]Crypto{
    Crypto{ .ty = crypto.onetimeauth.Poly1305, .name = "poly1305" },
    Crypto{ .ty = crypto.auth.hmac.HmacMd5, .name = "hmac-md5" },
    Crypto{ .ty = crypto.auth.hmac.HmacSha1, .name = "hmac-sha1" },
    Crypto{ .ty = crypto.auth.hmac.sha2.HmacSha256, .name = "hmac-sha256" },
    Crypto{ .ty = crypto.auth.hmac.sha2.HmacSha512, .name = "hmac-sha512" },
    Crypto{ .ty = crypto.auth.siphash.SipHash64(2, 4), .name = "siphash-2-4" },
    Crypto{ .ty = crypto.auth.siphash.SipHash64(1, 3), .name = "siphash-1-3" },
    Crypto{ .ty = crypto.auth.siphash.SipHash128(2, 4), .name = "siphash128-2-4" },
    Crypto{ .ty = crypto.auth.siphash.SipHash128(1, 3), .name = "siphash128-1-3" },
};

pub fn benchmarkMac(comptime Mac: anytype, comptime bytes: comptime_int) !u64 {
    var in: [512 * KiB]u8 = undefined;
    prng.random.bytes(in[0..]);

    const key_length = if (Mac.minimum_key_length == 0) 32 else Mac.minimum_key_length;
    var key: [key_length]u8 = undefined;
    prng.random.bytes(key[0..]);

    var mac: [Mac.mac_length]u8 = undefined;
    var offset: usize = 0;
    var timer = try Timer.start();
    const start = timer.lap();
    while (offset < bytes) : (offset += in.len) {
        Mac.create(mac[0..], in[0..], key[0..]);
        mem.doNotOptimizeAway(&mac);
    }
    const end = timer.read();

    const elapsed_s = @intToFloat(f64, end - start) / time.ns_per_s;
    const throughput = @floatToInt(u64, bytes / elapsed_s);

    return throughput;
}

const exchanges = [_]Crypto{Crypto{ .ty = crypto.dh.X25519, .name = "x25519" }};

pub fn benchmarkKeyExchange(comptime DhKeyExchange: anytype, comptime exchange_count: comptime_int) !u64 {
    std.debug.assert(DhKeyExchange.minimum_key_length >= DhKeyExchange.secret_length);

    var in: [DhKeyExchange.minimum_key_length]u8 = undefined;
    prng.random.bytes(in[0..]);

    var out: [DhKeyExchange.minimum_key_length]u8 = undefined;
    prng.random.bytes(out[0..]);

    var timer = try Timer.start();
    const start = timer.lap();
    {
        var i: usize = 0;
        while (i < exchange_count) : (i += 1) {
            _ = DhKeyExchange.create(out[0..], out[0..], in[0..]);
            mem.doNotOptimizeAway(&out);
        }
    }
    const end = timer.read();

    const elapsed_s = @intToFloat(f64, end - start) / time.ns_per_s;
    const throughput = @floatToInt(u64, exchange_count / elapsed_s);

    return throughput;
}

const signatures = [_]Crypto{Crypto{ .ty = crypto.sign.Ed25519, .name = "ed25519" }};

pub fn benchmarkSignature(comptime Signature: anytype, comptime signatures_count: comptime_int) !u64 {
    var seed: [Signature.seed_length]u8 = undefined;
    prng.random.bytes(seed[0..]);
    const msg = [_]u8{0} ** 64;
    const key_pair = try Signature.createKeyPair(seed);

    var timer = try Timer.start();
    const start = timer.lap();
    {
        var i: usize = 0;
        while (i < signatures_count) : (i += 1) {
            const s = try Signature.sign(&msg, key_pair, null);
            mem.doNotOptimizeAway(&s);
        }
    }
    const end = timer.read();

    const elapsed_s = @intToFloat(f64, end - start) / time.ns_per_s;
    const throughput = @floatToInt(u64, signatures_count / elapsed_s);

    return throughput;
}

const aeads = [_]Crypto{
    Crypto{ .ty = crypto.aead.ChaCha20Poly1305, .name = "chacha20Poly1305" },
    Crypto{ .ty = crypto.aead.XChaCha20Poly1305, .name = "xchacha20Poly1305" },
    Crypto{ .ty = crypto.aead.Gimli, .name = "gimli-aead" },
};

pub fn benchmarkAead(comptime Aead: anytype, comptime bytes: comptime_int) !u64 {
    var in: [512 * KiB]u8 = undefined;
    prng.random.bytes(in[0..]);

    var tag: [Aead.tag_length]u8 = undefined;

    var key: [Aead.key_length]u8 = undefined;
    prng.random.bytes(key[0..]);

    var nonce: [Aead.nonce_length]u8 = undefined;
    prng.random.bytes(nonce[0..]);

    var offset: usize = 0;
    var timer = try Timer.start();
    const start = timer.lap();
    while (offset < bytes) : (offset += in.len) {
        Aead.encrypt(in[0..], tag[0..], in[0..], &[_]u8{}, nonce, key);
        Aead.decrypt(in[0..], in[0..], tag, &[_]u8{}, nonce, key) catch unreachable;
    }
    mem.doNotOptimizeAway(&in);
    const end = timer.read();

    const elapsed_s = @intToFloat(f64, end - start) / time.ns_per_s;
    const throughput = @floatToInt(u64, 2 * bytes / elapsed_s);

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
            const throughput = try benchmarkHash(H.ty, mode(128 * MiB));
            try stdout.print("{:>17}: {:7} MiB/s\n", .{ H.name, throughput / (1 * MiB) });
        }
    }

    inline for (macs) |M| {
        if (filter == null or std.mem.indexOf(u8, M.name, filter.?) != null) {
            const throughput = try benchmarkMac(M.ty, mode(128 * MiB));
            try stdout.print("{:>17}: {:7} MiB/s\n", .{ M.name, throughput / (1 * MiB) });
        }
    }

    inline for (exchanges) |E| {
        if (filter == null or std.mem.indexOf(u8, E.name, filter.?) != null) {
            const throughput = try benchmarkKeyExchange(E.ty, mode(1000));
            try stdout.print("{:>17}: {:7} exchanges/s\n", .{ E.name, throughput });
        }
    }

    inline for (signatures) |E| {
        if (filter == null or std.mem.indexOf(u8, E.name, filter.?) != null) {
            const throughput = try benchmarkSignature(E.ty, mode(1000));
            try stdout.print("{:>17}: {:7} signatures/s\n", .{ E.name, throughput });
        }
    }

    inline for (aeads) |E| {
        if (filter == null or std.mem.indexOf(u8, E.name, filter.?) != null) {
            const throughput = try benchmarkAead(E.ty, mode(128 * MiB));
            try stdout.print("{:>17}: {:7} MiB/s\n", .{ E.name, throughput / (1 * MiB) });
        }
    }
}
