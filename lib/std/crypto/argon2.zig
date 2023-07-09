// https://datatracker.ietf.org/doc/rfc9106
// https://github.com/golang/crypto/tree/master/argon2
// https://github.com/P-H-C/phc-winner-argon2

const std = @import("std");
const builtin = @import("builtin");

const blake2 = crypto.hash.blake2;
const crypto = std.crypto;
const math = std.math;
const mem = std.mem;
const phc_format = pwhash.phc_format;
const pwhash = crypto.pwhash;

const Thread = std.Thread;
const Blake2b512 = blake2.Blake2b512;
const Blocks = std.ArrayListAligned([block_length]u64, 16);
const H0 = [Blake2b512.digest_length + 8]u8;

const EncodingError = crypto.errors.EncodingError;
const KdfError = pwhash.KdfError;
const HasherError = pwhash.HasherError;
const Error = pwhash.Error;

const version = 0x13;
const block_length = 128;
const sync_points = 4;
const max_int = 0xffff_ffff;

const default_salt_len = 32;
const default_hash_len = 32;
const max_salt_len = 64;
const max_hash_len = 64;

/// Argon2 type
pub const Mode = enum {
    /// Argon2d is faster and uses data-depending memory access, which makes it highly resistant
    /// against GPU cracking attacks and suitable for applications with no threats from side-channel
    /// timing attacks (eg. cryptocurrencies).
    argon2d,

    /// Argon2i instead uses data-independent memory access, which is preferred for password
    /// hashing and password-based key derivation, but it is slower as it makes more passes over
    /// the memory to protect from tradeoff attacks.
    argon2i,

    /// Argon2id is a hybrid of Argon2i and Argon2d, using a combination of data-depending and
    /// data-independent memory accesses, which gives some of Argon2i's resistance to side-channel
    /// cache timing attacks and much of Argon2d's resistance to GPU cracking attacks.
    argon2id,
};

/// Argon2 parameters
pub const Params = struct {
    const Self = @This();

    /// A [t]ime cost, which defines the amount of computation realized and therefore the execution
    /// time, given in number of iterations.
    t: u32,

    /// A [m]emory cost, which defines the memory usage, given in kibibytes.
    m: u32,

    /// A [p]arallelism degree, which defines the number of parallel threads.
    p: u24,

    /// The [secret] parameter, which is used for keyed hashing. This allows a secret key to be input
    /// at hashing time (from some external location) and be folded into the value of the hash. This
    /// means that even if your salts and hashes are compromised, an attacker cannot brute-force to
    /// find the password without the key.
    secret: ?[]const u8 = null,

    /// The [ad] parameter, which is used to fold any additional data into the hash value. Functionally,
    /// this behaves almost exactly like the secret or salt parameters; the ad parameter is folding
    /// into the value of the hash. However, this parameter is used for different data. The salt
    /// should be a random string stored alongside your password. The secret should be a random key
    /// only usable at hashing time. The ad is for any other data.
    ad: ?[]const u8 = null,

    /// Baseline parameters for interactive logins using argon2i type
    pub const interactive_2i = Self.fromLimits(4, 33554432);
    /// Baseline parameters for normal usage using argon2i type
    pub const moderate_2i = Self.fromLimits(6, 134217728);
    /// Baseline parameters for offline usage using argon2i type
    pub const sensitive_2i = Self.fromLimits(8, 536870912);

    /// Baseline parameters for interactive logins using argon2id type
    pub const interactive_2id = Self.fromLimits(2, 67108864);
    /// Baseline parameters for normal usage using argon2id type
    pub const moderate_2id = Self.fromLimits(3, 268435456);
    /// Baseline parameters for offline usage using argon2id type
    pub const sensitive_2id = Self.fromLimits(4, 1073741824);

    /// Create parameters from ops and mem limits, where mem_limit given in bytes
    pub fn fromLimits(ops_limit: u32, mem_limit: usize) Self {
        const m = mem_limit / 1024;
        std.debug.assert(m <= max_int);
        return .{ .t = ops_limit, .m = @as(u32, @intCast(m)), .p = 1 };
    }
};

fn initHash(
    password: []const u8,
    salt: []const u8,
    params: Params,
    dk_len: usize,
    mode: Mode,
) H0 {
    var h0: H0 = undefined;
    var parameters: [24]u8 = undefined;
    var tmp: [4]u8 = undefined;
    var b2 = Blake2b512.init(.{});
    mem.writeIntLittle(u32, parameters[0..4], params.p);
    mem.writeIntLittle(u32, parameters[4..8], @as(u32, @intCast(dk_len)));
    mem.writeIntLittle(u32, parameters[8..12], params.m);
    mem.writeIntLittle(u32, parameters[12..16], params.t);
    mem.writeIntLittle(u32, parameters[16..20], version);
    mem.writeIntLittle(u32, parameters[20..24], @intFromEnum(mode));
    b2.update(&parameters);
    mem.writeIntLittle(u32, &tmp, @as(u32, @intCast(password.len)));
    b2.update(&tmp);
    b2.update(password);
    mem.writeIntLittle(u32, &tmp, @as(u32, @intCast(salt.len)));
    b2.update(&tmp);
    b2.update(salt);
    const secret = params.secret orelse "";
    std.debug.assert(secret.len <= max_int);
    mem.writeIntLittle(u32, &tmp, @as(u32, @intCast(secret.len)));
    b2.update(&tmp);
    b2.update(secret);
    const ad = params.ad orelse "";
    std.debug.assert(ad.len <= max_int);
    mem.writeIntLittle(u32, &tmp, @as(u32, @intCast(ad.len)));
    b2.update(&tmp);
    b2.update(ad);
    b2.final(h0[0..Blake2b512.digest_length]);
    return h0;
}

fn blake2bLong(out: []u8, in: []const u8) void {
    const H = Blake2b512;
    var outlen_bytes: [4]u8 = undefined;
    mem.writeIntLittle(u32, &outlen_bytes, @as(u32, @intCast(out.len)));

    var out_buf: [H.digest_length]u8 = undefined;

    if (out.len <= H.digest_length) {
        var h = H.init(.{ .expected_out_bits = out.len * 8 });
        h.update(&outlen_bytes);
        h.update(in);
        h.final(&out_buf);
        @memcpy(out, out_buf[0..out.len]);
        return;
    }

    var h = H.init(.{});
    h.update(&outlen_bytes);
    h.update(in);
    h.final(&out_buf);
    var out_slice = out;
    out_slice[0 .. H.digest_length / 2].* = out_buf[0 .. H.digest_length / 2].*;
    out_slice = out_slice[H.digest_length / 2 ..];

    var in_buf: [H.digest_length]u8 = undefined;
    while (out_slice.len > H.digest_length) {
        in_buf = out_buf;
        H.hash(&in_buf, &out_buf, .{});
        out_slice[0 .. H.digest_length / 2].* = out_buf[0 .. H.digest_length / 2].*;
        out_slice = out_slice[H.digest_length / 2 ..];
    }
    in_buf = out_buf;
    H.hash(&in_buf, &out_buf, .{ .expected_out_bits = out_slice.len * 8 });
    @memcpy(out_slice, out_buf[0..out_slice.len]);
}

fn initBlocks(
    blocks: *Blocks,
    h0: *H0,
    memory: u32,
    threads: u24,
) void {
    var block0: [1024]u8 = undefined;
    var lane: u24 = 0;
    while (lane < threads) : (lane += 1) {
        const j = lane * (memory / threads);
        mem.writeIntLittle(u32, h0[Blake2b512.digest_length + 4 ..][0..4], lane);

        mem.writeIntLittle(u32, h0[Blake2b512.digest_length..][0..4], 0);
        blake2bLong(&block0, h0);
        for (&blocks.items[j + 0], 0..) |*v, i| {
            v.* = mem.readIntLittle(u64, block0[i * 8 ..][0..8]);
        }

        mem.writeIntLittle(u32, h0[Blake2b512.digest_length..][0..4], 1);
        blake2bLong(&block0, h0);
        for (&blocks.items[j + 1], 0..) |*v, i| {
            v.* = mem.readIntLittle(u64, block0[i * 8 ..][0..8]);
        }
    }
}

fn processBlocks(
    allocator: mem.Allocator,
    blocks: *Blocks,
    time: u32,
    memory: u32,
    threads: u24,
    mode: Mode,
) KdfError!void {
    const lanes = memory / threads;
    const segments = lanes / sync_points;

    if (builtin.single_threaded or threads == 1) {
        processBlocksSt(blocks, time, memory, threads, mode, lanes, segments);
    } else {
        try processBlocksMt(allocator, blocks, time, memory, threads, mode, lanes, segments);
    }
}

fn processBlocksSt(
    blocks: *Blocks,
    time: u32,
    memory: u32,
    threads: u24,
    mode: Mode,
    lanes: u32,
    segments: u32,
) void {
    var n: u32 = 0;
    while (n < time) : (n += 1) {
        var slice: u32 = 0;
        while (slice < sync_points) : (slice += 1) {
            var lane: u24 = 0;
            while (lane < threads) : (lane += 1) {
                processSegment(blocks, time, memory, threads, mode, lanes, segments, n, slice, lane);
            }
        }
    }
}

fn processBlocksMt(
    allocator: mem.Allocator,
    blocks: *Blocks,
    time: u32,
    memory: u32,
    threads: u24,
    mode: Mode,
    lanes: u32,
    segments: u32,
) KdfError!void {
    var threads_list = try std.ArrayList(Thread).initCapacity(allocator, threads);
    defer threads_list.deinit();

    var n: u32 = 0;
    while (n < time) : (n += 1) {
        var slice: u32 = 0;
        while (slice < sync_points) : (slice += 1) {
            var lane: u24 = 0;
            while (lane < threads) : (lane += 1) {
                const thread = try Thread.spawn(.{}, processSegment, .{
                    blocks, time, memory, threads, mode, lanes, segments, n, slice, lane,
                });
                threads_list.appendAssumeCapacity(thread);
            }
            lane = 0;
            while (lane < threads) : (lane += 1) {
                threads_list.items[lane].join();
            }
            threads_list.clearRetainingCapacity();
        }
    }
}

fn processSegment(
    blocks: *Blocks,
    passes: u32,
    memory: u32,
    threads: u24,
    mode: Mode,
    lanes: u32,
    segments: u32,
    n: u32,
    slice: u32,
    lane: u24,
) void {
    var addresses align(16) = [_]u64{0} ** block_length;
    var in align(16) = [_]u64{0} ** block_length;
    const zero align(16) = [_]u64{0} ** block_length;
    if (mode == .argon2i or (mode == .argon2id and n == 0 and slice < sync_points / 2)) {
        in[0] = n;
        in[1] = lane;
        in[2] = slice;
        in[3] = memory;
        in[4] = passes;
        in[5] = @intFromEnum(mode);
    }
    var index: u32 = 0;
    if (n == 0 and slice == 0) {
        index = 2;
        if (mode == .argon2i or mode == .argon2id) {
            in[6] += 1;
            processBlock(&addresses, &in, &zero);
            processBlock(&addresses, &addresses, &zero);
        }
    }
    var offset = lane * lanes + slice * segments + index;
    var random: u64 = 0;
    while (index < segments) : ({
        index += 1;
        offset += 1;
    }) {
        var prev = offset -% 1;
        if (index == 0 and slice == 0) {
            prev +%= lanes;
        }
        if (mode == .argon2i or (mode == .argon2id and n == 0 and slice < sync_points / 2)) {
            if (index % block_length == 0) {
                in[6] += 1;
                processBlock(&addresses, &in, &zero);
                processBlock(&addresses, &addresses, &zero);
            }
            random = addresses[index % block_length];
        } else {
            random = blocks.items[prev][0];
        }
        const new_offset = indexAlpha(random, lanes, segments, threads, n, slice, lane, index);
        processBlockXor(&blocks.items[offset], &blocks.items[prev], &blocks.items[new_offset]);
    }
}

fn processBlock(
    out: *align(16) [block_length]u64,
    in1: *align(16) const [block_length]u64,
    in2: *align(16) const [block_length]u64,
) void {
    processBlockGeneric(out, in1, in2, false);
}

fn processBlockXor(
    out: *[block_length]u64,
    in1: *const [block_length]u64,
    in2: *const [block_length]u64,
) void {
    processBlockGeneric(out, in1, in2, true);
}

fn processBlockGeneric(
    out: *[block_length]u64,
    in1: *const [block_length]u64,
    in2: *const [block_length]u64,
    comptime xor: bool,
) void {
    var t: [block_length]u64 = undefined;
    for (&t, 0..) |*v, i| {
        v.* = in1[i] ^ in2[i];
    }
    var i: usize = 0;
    while (i < block_length) : (i += 16) {
        blamkaGeneric(t[i..][0..16]);
    }
    i = 0;
    var buffer: [16]u64 = undefined;
    while (i < block_length / 8) : (i += 2) {
        var j: usize = 0;
        while (j < block_length / 8) : (j += 2) {
            buffer[j] = t[j * 8 + i];
            buffer[j + 1] = t[j * 8 + i + 1];
        }
        blamkaGeneric(&buffer);
        j = 0;
        while (j < block_length / 8) : (j += 2) {
            t[j * 8 + i] = buffer[j];
            t[j * 8 + i + 1] = buffer[j + 1];
        }
    }
    if (xor) {
        for (t, 0..) |v, j| {
            out[j] ^= in1[j] ^ in2[j] ^ v;
        }
    } else {
        for (t, 0..) |v, j| {
            out[j] = in1[j] ^ in2[j] ^ v;
        }
    }
}

const QuarterRound = struct { a: usize, b: usize, c: usize, d: usize };

fn Rp(a: usize, b: usize, c: usize, d: usize) QuarterRound {
    return .{ .a = a, .b = b, .c = c, .d = d };
}

fn fBlaMka(x: u64, y: u64) u64 {
    const xy = @as(u64, @as(u32, @truncate(x))) * @as(u64, @as(u32, @truncate(y)));
    return x +% y +% 2 *% xy;
}

fn blamkaGeneric(x: *[16]u64) void {
    const rounds = comptime [_]QuarterRound{
        Rp(0, 4, 8, 12),
        Rp(1, 5, 9, 13),
        Rp(2, 6, 10, 14),
        Rp(3, 7, 11, 15),
        Rp(0, 5, 10, 15),
        Rp(1, 6, 11, 12),
        Rp(2, 7, 8, 13),
        Rp(3, 4, 9, 14),
    };
    inline for (rounds) |r| {
        x[r.a] = fBlaMka(x[r.a], x[r.b]);
        x[r.d] = math.rotr(u64, x[r.d] ^ x[r.a], 32);
        x[r.c] = fBlaMka(x[r.c], x[r.d]);
        x[r.b] = math.rotr(u64, x[r.b] ^ x[r.c], 24);
        x[r.a] = fBlaMka(x[r.a], x[r.b]);
        x[r.d] = math.rotr(u64, x[r.d] ^ x[r.a], 16);
        x[r.c] = fBlaMka(x[r.c], x[r.d]);
        x[r.b] = math.rotr(u64, x[r.b] ^ x[r.c], 63);
    }
}

fn finalize(
    blocks: *Blocks,
    memory: u32,
    threads: u24,
    out: []u8,
) void {
    const lanes = memory / threads;
    var lane: u24 = 0;
    while (lane < threads - 1) : (lane += 1) {
        for (blocks.items[(lane * lanes) + lanes - 1], 0..) |v, i| {
            blocks.items[memory - 1][i] ^= v;
        }
    }
    var block: [1024]u8 = undefined;
    for (blocks.items[memory - 1], 0..) |v, i| {
        mem.writeIntLittle(u64, block[i * 8 ..][0..8], v);
    }
    blake2bLong(out, &block);
}

fn indexAlpha(
    rand: u64,
    lanes: u32,
    segments: u32,
    threads: u24,
    n: u32,
    slice: u32,
    lane: u24,
    index: u32,
) u32 {
    var ref_lane = @as(u32, @intCast(rand >> 32)) % threads;
    if (n == 0 and slice == 0) {
        ref_lane = lane;
    }
    var m = 3 * segments;
    var s = ((slice + 1) % sync_points) * segments;
    if (lane == ref_lane) {
        m += index;
    }
    if (n == 0) {
        m = slice * segments;
        s = 0;
        if (slice == 0 or lane == ref_lane) {
            m += index;
        }
    }
    if (index == 0 or lane == ref_lane) {
        m -= 1;
    }
    var p = @as(u64, @as(u32, @truncate(rand)));
    p = (p * p) >> 32;
    p = (p * m) >> 32;
    return ref_lane * lanes + @as(u32, @intCast(((s + m - (p + 1)) % lanes)));
}

/// Derives a key from the password, salt, and argon2 parameters.
///
/// Derived key has to be at least 4 bytes length.
///
/// Salt has to be at least 8 bytes length.
pub fn kdf(
    allocator: mem.Allocator,
    derived_key: []u8,
    password: []const u8,
    salt: []const u8,
    params: Params,
    mode: Mode,
) KdfError!void {
    if (derived_key.len < 4) return KdfError.WeakParameters;
    if (derived_key.len > max_int) return KdfError.OutputTooLong;

    if (password.len > max_int) return KdfError.WeakParameters;
    if (salt.len < 8 or salt.len > max_int) return KdfError.WeakParameters;
    if (params.t < 1 or params.p < 1) return KdfError.WeakParameters;

    var h0 = initHash(password, salt, params, derived_key.len, mode);
    const memory = @max(
        params.m / (sync_points * params.p) * (sync_points * params.p),
        2 * sync_points * params.p,
    );

    var blocks = try Blocks.initCapacity(allocator, memory);
    defer blocks.deinit();

    blocks.appendNTimesAssumeCapacity([_]u64{0} ** block_length, memory);

    initBlocks(&blocks, &h0, memory, params.p);
    try processBlocks(allocator, &blocks, params.t, memory, params.p, mode);
    finalize(&blocks, memory, params.p, derived_key);
}

const PhcFormatHasher = struct {
    const BinValue = phc_format.BinValue;

    const HashResult = struct {
        alg_id: []const u8,
        alg_version: ?u32,
        m: u32,
        t: u32,
        p: u24,
        salt: BinValue(max_salt_len),
        hash: BinValue(max_hash_len),
    };

    pub fn create(
        allocator: mem.Allocator,
        password: []const u8,
        params: Params,
        mode: Mode,
        buf: []u8,
    ) HasherError![]const u8 {
        if (params.secret != null or params.ad != null) return HasherError.InvalidEncoding;

        var salt: [default_salt_len]u8 = undefined;
        crypto.random.bytes(&salt);

        var hash: [default_hash_len]u8 = undefined;
        try kdf(allocator, &hash, password, &salt, params, mode);

        return phc_format.serialize(HashResult{
            .alg_id = @tagName(mode),
            .alg_version = version,
            .m = params.m,
            .t = params.t,
            .p = params.p,
            .salt = try BinValue(max_salt_len).fromSlice(&salt),
            .hash = try BinValue(max_hash_len).fromSlice(&hash),
        }, buf);
    }

    pub fn verify(
        allocator: mem.Allocator,
        str: []const u8,
        password: []const u8,
    ) HasherError!void {
        const hash_result = try phc_format.deserialize(HashResult, str);

        const mode = std.meta.stringToEnum(Mode, hash_result.alg_id) orelse
            return HasherError.PasswordVerificationFailed;
        if (hash_result.alg_version) |v| {
            if (v != version) return HasherError.InvalidEncoding;
        }
        const params = Params{ .t = hash_result.t, .m = hash_result.m, .p = hash_result.p };

        const expected_hash = hash_result.hash.constSlice();
        var hash_buf: [max_hash_len]u8 = undefined;
        if (expected_hash.len > hash_buf.len) return HasherError.InvalidEncoding;
        var hash = hash_buf[0..expected_hash.len];

        try kdf(allocator, hash, password, hash_result.salt.constSlice(), params, mode);
        if (!mem.eql(u8, hash, expected_hash)) return HasherError.PasswordVerificationFailed;
    }
};

/// Options for hashing a password.
///
/// Allocator is required for argon2.
///
/// Only phc encoding is supported.
pub const HashOptions = struct {
    allocator: ?mem.Allocator,
    params: Params,
    mode: Mode = .argon2id,
    encoding: pwhash.Encoding = .phc,
};

/// Compute a hash of a password using the argon2 key derivation function.
/// The function returns a string that includes all the parameters required for verification.
pub fn strHash(
    password: []const u8,
    options: HashOptions,
    out: []u8,
) Error![]const u8 {
    const allocator = options.allocator orelse return Error.AllocatorRequired;
    switch (options.encoding) {
        .phc => return PhcFormatHasher.create(
            allocator,
            password,
            options.params,
            options.mode,
            out,
        ),
        .crypt => return Error.InvalidEncoding,
    }
}

/// Options for hash verification.
///
/// Allocator is required for argon2.
pub const VerifyOptions = struct {
    allocator: ?mem.Allocator,
};

/// Verify that a previously computed hash is valid for a given password.
pub fn strVerify(
    str: []const u8,
    password: []const u8,
    options: VerifyOptions,
) Error!void {
    const allocator = options.allocator orelse return Error.AllocatorRequired;
    return PhcFormatHasher.verify(allocator, str, password);
}

test "argon2d" {
    const password = [_]u8{0x01} ** 32;
    const salt = [_]u8{0x02} ** 16;
    const secret = [_]u8{0x03} ** 8;
    const ad = [_]u8{0x04} ** 12;

    var dk: [32]u8 = undefined;
    try kdf(
        std.testing.allocator,
        &dk,
        &password,
        &salt,
        .{ .t = 3, .m = 32, .p = 4, .secret = &secret, .ad = &ad },
        .argon2d,
    );

    const want = [_]u8{
        0x51, 0x2b, 0x39, 0x1b, 0x6f, 0x11, 0x62, 0x97,
        0x53, 0x71, 0xd3, 0x09, 0x19, 0x73, 0x42, 0x94,
        0xf8, 0x68, 0xe3, 0xbe, 0x39, 0x84, 0xf3, 0xc1,
        0xa1, 0x3a, 0x4d, 0xb9, 0xfa, 0xbe, 0x4a, 0xcb,
    };
    try std.testing.expectEqualSlices(u8, &dk, &want);
}

test "argon2i" {
    const password = [_]u8{0x01} ** 32;
    const salt = [_]u8{0x02} ** 16;
    const secret = [_]u8{0x03} ** 8;
    const ad = [_]u8{0x04} ** 12;

    var dk: [32]u8 = undefined;
    try kdf(
        std.testing.allocator,
        &dk,
        &password,
        &salt,
        .{ .t = 3, .m = 32, .p = 4, .secret = &secret, .ad = &ad },
        .argon2i,
    );

    const want = [_]u8{
        0xc8, 0x14, 0xd9, 0xd1, 0xdc, 0x7f, 0x37, 0xaa,
        0x13, 0xf0, 0xd7, 0x7f, 0x24, 0x94, 0xbd, 0xa1,
        0xc8, 0xde, 0x6b, 0x01, 0x6d, 0xd3, 0x88, 0xd2,
        0x99, 0x52, 0xa4, 0xc4, 0x67, 0x2b, 0x6c, 0xe8,
    };
    try std.testing.expectEqualSlices(u8, &dk, &want);
}

test "argon2id" {
    const password = [_]u8{0x01} ** 32;
    const salt = [_]u8{0x02} ** 16;
    const secret = [_]u8{0x03} ** 8;
    const ad = [_]u8{0x04} ** 12;

    var dk: [32]u8 = undefined;
    try kdf(
        std.testing.allocator,
        &dk,
        &password,
        &salt,
        .{ .t = 3, .m = 32, .p = 4, .secret = &secret, .ad = &ad },
        .argon2id,
    );

    const want = [_]u8{
        0x0d, 0x64, 0x0d, 0xf5, 0x8d, 0x78, 0x76, 0x6c,
        0x08, 0xc0, 0x37, 0xa3, 0x4a, 0x8b, 0x53, 0xc9,
        0xd0, 0x1e, 0xf0, 0x45, 0x2d, 0x75, 0xb6, 0x5e,
        0xb5, 0x25, 0x20, 0xe9, 0x6b, 0x01, 0xe6, 0x59,
    };
    try std.testing.expectEqualSlices(u8, &dk, &want);
}

test "kdf" {
    const password = "password";
    const salt = "somesalt";

    const TestVector = struct {
        mode: Mode,
        time: u32,
        memory: u32,
        threads: u8,
        hash: []const u8,
    };
    const test_vectors = [_]TestVector{
        .{
            .mode = .argon2i,
            .time = 1,
            .memory = 64,
            .threads = 1,
            .hash = "b9c401d1844a67d50eae3967dc28870b22e508092e861a37",
        },
        .{
            .mode = .argon2d,
            .time = 1,
            .memory = 64,
            .threads = 1,
            .hash = "8727405fd07c32c78d64f547f24150d3f2e703a89f981a19",
        },
        .{
            .mode = .argon2id,
            .time = 1,
            .memory = 64,
            .threads = 1,
            .hash = "655ad15eac652dc59f7170a7332bf49b8469be1fdb9c28bb",
        },
        .{
            .mode = .argon2i,
            .time = 2,
            .memory = 64,
            .threads = 1,
            .hash = "8cf3d8f76a6617afe35fac48eb0b7433a9a670ca4a07ed64",
        },
        .{
            .mode = .argon2d,
            .time = 2,
            .memory = 64,
            .threads = 1,
            .hash = "3be9ec79a69b75d3752acb59a1fbb8b295a46529c48fbb75",
        },
        .{
            .mode = .argon2id,
            .time = 2,
            .memory = 64,
            .threads = 1,
            .hash = "068d62b26455936aa6ebe60060b0a65870dbfa3ddf8d41f7",
        },
        .{
            .mode = .argon2i,
            .time = 2,
            .memory = 64,
            .threads = 2,
            .hash = "2089f3e78a799720f80af806553128f29b132cafe40d059f",
        },
        .{
            .mode = .argon2d,
            .time = 2,
            .memory = 64,
            .threads = 2,
            .hash = "68e2462c98b8bc6bb60ec68db418ae2c9ed24fc6748a40e9",
        },
        .{
            .mode = .argon2id,
            .time = 2,
            .memory = 64,
            .threads = 2,
            .hash = "350ac37222f436ccb5c0972f1ebd3bf6b958bf2071841362",
        },
        .{
            .mode = .argon2i,
            .time = 3,
            .memory = 256,
            .threads = 2,
            .hash = "f5bbf5d4c3836af13193053155b73ec7476a6a2eb93fd5e6",
        },
        .{
            .mode = .argon2d,
            .time = 3,
            .memory = 256,
            .threads = 2,
            .hash = "f4f0669218eaf3641f39cc97efb915721102f4b128211ef2",
        },
        .{
            .mode = .argon2id,
            .time = 3,
            .memory = 256,
            .threads = 2,
            .hash = "4668d30ac4187e6878eedeacf0fd83c5a0a30db2cc16ef0b",
        },
        .{
            .mode = .argon2i,
            .time = 4,
            .memory = 4096,
            .threads = 4,
            .hash = "a11f7b7f3f93f02ad4bddb59ab62d121e278369288a0d0e7",
        },
        .{
            .mode = .argon2d,
            .time = 4,
            .memory = 4096,
            .threads = 4,
            .hash = "935598181aa8dc2b720914aa6435ac8d3e3a4210c5b0fb2d",
        },
        .{
            .mode = .argon2id,
            .time = 4,
            .memory = 4096,
            .threads = 4,
            .hash = "145db9733a9f4ee43edf33c509be96b934d505a4efb33c5a",
        },
        .{
            .mode = .argon2i,
            .time = 4,
            .memory = 1024,
            .threads = 8,
            .hash = "0cdd3956aa35e6b475a7b0c63488822f774f15b43f6e6e17",
        },
        .{
            .mode = .argon2d,
            .time = 4,
            .memory = 1024,
            .threads = 8,
            .hash = "83604fc2ad0589b9d055578f4d3cc55bc616df3578a896e9",
        },
        .{
            .mode = .argon2id,
            .time = 4,
            .memory = 1024,
            .threads = 8,
            .hash = "8dafa8e004f8ea96bf7c0f93eecf67a6047476143d15577f",
        },
        .{
            .mode = .argon2i,
            .time = 2,
            .memory = 64,
            .threads = 3,
            .hash = "5cab452fe6b8479c8661def8cd703b611a3905a6d5477fe6",
        },
        .{
            .mode = .argon2d,
            .time = 2,
            .memory = 64,
            .threads = 3,
            .hash = "22474a423bda2ccd36ec9afd5119e5c8949798cadf659f51",
        },
        .{
            .mode = .argon2id,
            .time = 2,
            .memory = 64,
            .threads = 3,
            .hash = "4a15b31aec7c2590b87d1f520be7d96f56658172deaa3079",
        },
        .{
            .mode = .argon2i,
            .time = 3,
            .memory = 1024,
            .threads = 6,
            .hash = "d236b29c2b2a09babee842b0dec6aa1e83ccbdea8023dced",
        },
        .{
            .mode = .argon2d,
            .time = 3,
            .memory = 1024,
            .threads = 6,
            .hash = "a3351b0319a53229152023d9206902f4ef59661cdca89481",
        },
        .{
            .mode = .argon2id,
            .time = 3,
            .memory = 1024,
            .threads = 6,
            .hash = "1640b932f4b60e272f5d2207b9a9c626ffa1bd88d2349016",
        },
    };
    for (test_vectors) |v| {
        var want: [24]u8 = undefined;
        _ = try std.fmt.hexToBytes(&want, v.hash);

        var dk: [24]u8 = undefined;
        try kdf(
            std.testing.allocator,
            &dk,
            password,
            salt,
            .{ .t = v.time, .m = v.memory, .p = v.threads },
            v.mode,
        );

        try std.testing.expectEqualSlices(u8, &dk, &want);
    }
}

test "phc format hasher" {
    const allocator = std.testing.allocator;
    const password = "testpass";

    var buf: [128]u8 = undefined;
    const hash = try PhcFormatHasher.create(
        allocator,
        password,
        .{ .t = 3, .m = 32, .p = 4 },
        .argon2id,
        &buf,
    );
    try PhcFormatHasher.verify(allocator, hash, password);
}

test "password hash and password verify" {
    const allocator = std.testing.allocator;
    const password = "testpass";

    var buf: [128]u8 = undefined;
    const hash = try strHash(
        password,
        .{ .allocator = allocator, .params = .{ .t = 3, .m = 32, .p = 4 } },
        &buf,
    );
    try strVerify(hash, password, .{ .allocator = allocator });
}

test "kdf derived key length" {
    const allocator = std.testing.allocator;

    const password = "testpass";
    const salt = "saltsalt";
    const params = Params{ .t = 3, .m = 32, .p = 4 };
    const mode = Mode.argon2id;

    var dk1: [11]u8 = undefined;
    try kdf(allocator, &dk1, password, salt, params, mode);

    var dk2: [77]u8 = undefined;
    try kdf(allocator, &dk2, password, salt, params, mode);

    var dk3: [111]u8 = undefined;
    try kdf(allocator, &dk3, password, salt, params, mode);
}
