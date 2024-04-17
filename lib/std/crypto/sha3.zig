const std = @import("std");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;

const KeccakState = std.crypto.core.keccak.State;

pub const Sha3_224 = Keccak(1600, 224, 0x06, 24);
pub const Sha3_256 = Keccak(1600, 256, 0x06, 24);
pub const Sha3_384 = Keccak(1600, 384, 0x06, 24);
pub const Sha3_512 = Keccak(1600, 512, 0x06, 24);

pub const Keccak256 = Keccak(1600, 256, 0x01, 24);
pub const Keccak512 = Keccak(1600, 512, 0x01, 24);
pub const Keccak_256 = @compileError("Deprecated: use `Keccak256` instead");
pub const Keccak_512 = @compileError("Deprecated: use `Keccak512` instead");

pub const Shake128 = Shake(128);
pub const Shake256 = Shake(256);

pub const CShake128 = CShake(128, null);
pub const CShake256 = CShake(256, null);

pub const KMac128 = KMac(128);
pub const KMac256 = KMac(256);

pub const TupleHash128 = TupleHash(128);
pub const TupleHash256 = TupleHash(256);

/// TurboSHAKE128 is a XOF (a secure hash function with a variable output length), with a 128 bit security level.
/// It is based on the same permutation as SHA3 and SHAKE128, but which much higher performance.
/// The delimiter is 0x1f by default, but can be changed for context-separation.
/// For a protocol that uses both KangarooTwelve and TurboSHAKE128, it is recommended to avoid using 0x06, 0x07 or 0x0b for the delimiter.
pub fn TurboShake128(delim: ?u7) type {
    return TurboShake(128, delim);
}

/// TurboSHAKE256 is a XOF (a secure hash function with a variable output length), with a 256 bit security level.
/// It is based on the same permutation as SHA3 and SHAKE256, but which much higher performance.
/// The delimiter is 0x1f by default, but can be changed for context-separation.
pub fn TurboShake256(comptime delim: ?u7) type {
    return TurboShake(256, delim);
}

/// A generic Keccak hash function.
pub fn Keccak(comptime f: u11, comptime output_bits: u11, comptime default_delim: u8, comptime rounds: u5) type {
    comptime assert(output_bits > 0 and output_bits * 2 < f and output_bits % 8 == 0); // invalid output length

    const State = KeccakState(f, output_bits * 2, rounds);

    return struct {
        const Self = @This();

        st: State,

        /// The output length, in bytes.
        pub const digest_length = output_bits / 8;
        /// The block length, or rate, in bytes.
        pub const block_length = State.rate;
        /// The delimiter can be overwritten in the options.
        pub const Options = struct { delim: u8 = default_delim };

        /// Initialize a Keccak hash function.
        pub fn init(options: Options) Self {
            return Self{ .st = .{ .delim = options.delim } };
        }

        /// Hash a slice of bytes.
        pub fn hash(bytes: []const u8, out: *[digest_length]u8, options: Options) void {
            var st = Self.init(options);
            st.update(bytes);
            st.final(out);
        }

        /// Absorb a slice of bytes into the state.
        pub fn update(self: *Self, bytes: []const u8) void {
            self.st.absorb(bytes);
        }

        /// Return the hash of the absorbed bytes.
        pub fn final(self: *Self, out: *[digest_length]u8) void {
            self.st.pad();
            self.st.squeeze(out[0..]);
        }

        pub const Error = error{};
        pub const Writer = std.io.Writer(*Self, Error, write);

        fn write(self: *Self, bytes: []const u8) Error!usize {
            self.update(bytes);
            return bytes.len;
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }
    };
}

/// The SHAKE extendable output hash function.
pub fn Shake(comptime security_level: u11) type {
    return ShakeLike(security_level, 0x1f, 24);
}

/// The TurboSHAKE extendable output hash function.
/// It is based on the same permutation as SHA3 and SHAKE, but which much higher performance.
/// The delimiter is 0x1f by default, but can be changed for context-separation.
/// https://eprint.iacr.org/2023/342
pub fn TurboShake(comptime security_level: u11, comptime delim: ?u7) type {
    comptime assert(security_level <= 256);
    const d = delim orelse 0x1f;
    comptime assert(d >= 0x01); // delimiter must be >= 1
    return ShakeLike(security_level, d, 12);
}

fn ShakeLike(comptime security_level: u11, comptime default_delim: u8, comptime rounds: u5) type {
    const f = 1600;
    const State = KeccakState(f, security_level * 2, rounds);

    return struct {
        const Self = @This();

        st: State,
        buf: [State.rate]u8 = undefined,
        offset: usize = 0,
        padded: bool = false,

        /// The recommended output length, in bytes.
        pub const digest_length = security_level / 8 * 2;
        /// The block length, or rate, in bytes.
        pub const block_length = State.rate;
        /// The delimiter can be overwritten in the options.
        pub const Options = struct { delim: u8 = default_delim };

        /// Initialize a SHAKE extensible hash function.
        pub fn init(options: Options) Self {
            return Self{ .st = .{ .delim = options.delim } };
        }

        /// Hash a slice of bytes.
        /// `out` can be any length.
        pub fn hash(bytes: []const u8, out: []u8, options: Options) void {
            var st = Self.init(options);
            st.update(bytes);
            st.squeeze(out);
        }

        /// Absorb a slice of bytes into the state.
        pub fn update(self: *Self, bytes: []const u8) void {
            self.st.absorb(bytes);
        }

        /// Squeeze a slice of bytes from the state.
        /// `out` can be any length, and the function can be called multiple times.
        pub fn squeeze(self: *Self, out_: []u8) void {
            if (!self.padded) {
                self.st.pad();
                self.padded = true;
            }
            var out = out_;
            if (self.offset > 0) {
                const left = self.buf.len - self.offset;
                if (left > 0) {
                    const n = @min(left, out.len);
                    @memcpy(out[0..n], self.buf[self.offset..][0..n]);
                    out = out[n..];
                    self.offset += n;
                    if (out.len == 0) {
                        return;
                    }
                }
            }
            const full_blocks = out[0 .. out.len - out.len % State.rate];
            if (full_blocks.len > 0) {
                self.st.squeeze(full_blocks);
                out = out[full_blocks.len..];
            }
            if (out.len > 0) {
                self.st.squeeze(self.buf[0..]);
                @memcpy(out[0..], self.buf[0..out.len]);
                self.offset = out.len;
            }
        }

        /// Return the hash of the absorbed bytes.
        /// `out` can be of any length, but the function must not be called multiple times (use `squeeze` for that purpose instead).
        pub fn final(self: *Self, out: []u8) void {
            self.squeeze(out);
            self.st.st.clear(0, State.rate);
        }

        /// Align the input to a block boundary.
        pub fn fillBlock(self: *Self) void {
            self.st.fillBlock();
        }

        pub const Error = error{};
        pub const Writer = std.io.Writer(*Self, Error, write);

        fn write(self: *Self, bytes: []const u8) Error!usize {
            self.update(bytes);
            return bytes.len;
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }
    };
}

/// The cSHAKE extendable output hash function.
/// cSHAKE is similar to SHAKE, but in addition to the input message, it also takes an optional context (aka customization string).
pub fn CShake(comptime security_level: u11, comptime fname: ?[]const u8) type {
    return CShakeLike(security_level, 0x04, 24, fname);
}

fn CShakeLike(comptime security_level: u11, comptime default_delim: u8, comptime rounds: u5, comptime fname: ?[]const u8) type {
    return struct {
        const Shaker = ShakeLike(security_level, default_delim, rounds);
        shaker: Shaker,

        /// The recommended output length, in bytes.
        pub const digest_length = Shaker.digest_length;
        /// The block length, or rate, in bytes.
        pub const block_length = Shaker.block_length;

        /// cSHAKE options can include a context string.
        pub const Options = struct { context: ?[]const u8 = null };

        const Self = @This();

        /// Initialize a SHAKE extensible hash function.
        pub fn init(options: Options) Self {
            if (fname == null and options.context == null) {
                return Self{ .shaker = Shaker.init(.{ .delim = 0x1f }) };
            }
            var shaker = Shaker.init(.{});
            comptime assert(Shaker.block_length % 8 == 0);
            const encoded_rate_len = NistLengthEncoding.encode(.left, block_length / 8);
            shaker.update(encoded_rate_len.slice());
            const encoded_zero = comptime NistLengthEncoding.encode(.left, 0);
            if (fname) |name| {
                const encoded_fname_len = comptime NistLengthEncoding.encode(.left, name.len);
                const encoded_fname = comptime encoded_fname_len.slice() ++ name;
                shaker.update(encoded_fname);
            } else {
                shaker.update(encoded_zero.slice());
            }
            if (options.context) |context| {
                const encoded_context_len = NistLengthEncoding.encode(.left, context.len);
                shaker.update(encoded_context_len.slice());
                shaker.update(context);
            } else {
                shaker.update(encoded_zero.slice());
            }
            shaker.st.fillBlock();
            return Self{ .shaker = shaker };
        }

        /// Hash a slice of bytes.
        /// `out` can be any length.
        pub fn hash(bytes: []const u8, out: []u8, options: Options) void {
            var st = Self.init(options);
            st.update(bytes);
            st.squeeze(out);
        }

        /// Absorb a slice of bytes into the state.
        pub fn update(self: *Self, bytes: []const u8) void {
            self.shaker.update(bytes);
        }

        /// Squeeze a slice of bytes from the state.
        /// `out` can be any length, and the function can be called multiple times.
        pub fn squeeze(self: *Self, out: []u8) void {
            self.shaker.squeeze(out);
        }

        /// Return the hash of the absorbed bytes.
        /// `out` can be of any length, but the function must not be called multiple times (use `squeeze` for that purpose instead).
        pub fn final(self: *Self, out: []u8) void {
            self.shaker.final(out);
        }

        /// Align the input to a block boundary.
        pub fn fillBlock(self: *Self) void {
            self.shaker.fillBlock();
        }

        pub const Error = error{};
        pub const Writer = std.io.Writer(*Self, Error, write);

        fn write(self: *Self, bytes: []const u8) Error!usize {
            self.update(bytes);
            return bytes.len;
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }
    };
}

/// The KMAC extendable output authentication function.
/// KMAC is a keyed version of the cSHAKE function, with an optional context.
/// It can be used as an SHA-3 based alternative to HMAC, as well as a generic keyed XoF (extendable output function).
pub fn KMac(comptime security_level: u11) type {
    return KMacLike(security_level, 0x04, 24);
}

fn KMacLike(comptime security_level: u11, comptime default_delim: u8, comptime rounds: u5) type {
    const CShaker = CShakeLike(security_level, default_delim, rounds, "KMAC");

    return struct {
        const Self = @This();

        /// The recommended output length, in bytes.
        pub const mac_length = CShaker.digest_length;
        /// The minimum output length, in bytes.
        pub const mac_length_min = 4;
        /// The recommended key length, in bytes.
        pub const key_length = security_level / 8;
        /// The minimum key length, in bytes.
        pub const key_length_min = 0;
        /// The block length, or rate, in bytes.
        pub const block_length = CShaker.block_length;

        cshaker: CShaker,
        xof_mode: bool = false,

        /// KMAC options can include a context string.
        pub const Options = struct {
            context: ?[]const u8 = null,
        };

        /// Initialize a state for the KMAC function, with an optional context and an arbitrary-long key.
        /// If the context and key are going to be reused, the structure can be initialized once, and cloned for each message.
        /// This is more efficient than reinitializing the state for each message at the cost of a small amount of memory.
        pub fn initWithOptions(key: []const u8, options: Options) Self {
            var cshaker = CShaker.init(.{ .context = options.context });
            const encoded_rate_len = NistLengthEncoding.encode(.left, block_length / 8);
            cshaker.update(encoded_rate_len.slice());
            const encoded_key_len = NistLengthEncoding.encode(.left, key.len);
            cshaker.update(encoded_key_len.slice());
            cshaker.update(key);
            cshaker.fillBlock();
            return Self{
                .cshaker = cshaker,
            };
        }

        /// Initialize a state for the KMAC function.
        /// If the context and key are going to be reused, the structure can be initialized once, and cloned for each message.
        /// This is more efficient than reinitializing the state for each message at the cost of a small amount of memory.
        pub fn init(key: []const u8) Self {
            return initWithOptions(key, .{});
        }

        /// Add data to the state.
        pub fn update(self: *Self, b: []const u8) void {
            self.cshaker.update(b);
        }

        /// Return an authentication tag for the current state.
        pub fn final(self: *Self, out: []u8) void {
            const encoded_out_len = NistLengthEncoding.encode(.right, out.len);
            self.update(encoded_out_len.slice());
            self.cshaker.final(out);
        }

        /// Squeeze a slice of bytes from the state.
        /// `out` can be any length, and the function can be called multiple times.
        pub fn squeeze(self: *Self, out: []u8) void {
            if (!self.xof_mode) {
                const encoded_out_len = comptime NistLengthEncoding.encode(.right, 0);
                self.update(encoded_out_len.slice());
                self.xof_mode = true;
            }
            self.cshaker.squeeze(out);
        }

        /// Return an authentication tag for a message and a key, with an optional context.
        pub fn createWithOptions(out: []u8, msg: []const u8, key: []const u8, options: Options) void {
            var ctx = Self.initWithOptions(key, options);
            ctx.update(msg);
            ctx.final(out);
        }

        /// Return an authentication tag for a message and a key.
        pub fn create(out: []u8, msg: []const u8, key: []const u8) void {
            var ctx = Self.init(key);
            ctx.update(msg);
            ctx.final(out);
        }

        pub const Error = error{};
        pub const Writer = std.io.Writer(*Self, Error, write);

        fn write(self: *Self, bytes: []const u8) Error!usize {
            self.update(bytes);
            return bytes.len;
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }
    };
}

/// The TupleHash extendable output hash function, with domain-separated inputs.
/// TupleHash is a secure hash function with a variable output length, based on the cSHAKE function.
/// It is designed for unambiguously hashing tuples of data.
///
/// With most hash functions, calling `update("A")` followed by `update("B")`is identical to `update("AB")`.
/// With TupleHash, this is not the case: `update("A"); update("B")` is different from `update("AB")`.
///
/// Any number of inputs can be hashed, and the output depends on individual inputs and their order.
pub fn TupleHash(comptime security_level: u11) type {
    return TupleHashLike(security_level, 0x04, 24);
}

fn TupleHashLike(comptime security_level: u11, comptime default_delim: u8, comptime rounds: u5) type {
    const CShaker = CShakeLike(security_level, default_delim, rounds, "TupleHash");

    return struct {
        const Self = @This();

        /// The output length, in bytes.
        pub const digest_length = CShaker.digest_length;
        /// The block length, or rate, in bytes.
        pub const block_length = CShaker.block_length;

        cshaker: CShaker,
        xof_mode: bool = false,

        /// TupleHash options can include a context string.
        pub const Options = struct {
            context: ?[]const u8 = null,
        };

        /// Initialize a state for the TupleHash function, with an optional context.
        /// If the context is going to be reused, the structure can be initialized once, and cloned for each message.
        /// This is more efficient than reinitializing the state for each message at the cost of a small amount of memory.
        ///
        /// A key can be optionally added to the context to create a keyed TupleHash function, similar to KMAC.
        pub fn initWithOptions(options: Options) Self {
            const cshaker = CShaker.init(.{ .context = options.context });
            return Self{
                .cshaker = cshaker,
            };
        }

        /// Initialize a state for the MAC function.
        pub fn init() Self {
            return initWithOptions(.{});
        }

        /// Add data to the state, separated from previous updates.
        pub fn update(self: *Self, b: []const u8) void {
            const encoded_b_len = NistLengthEncoding.encode(.left, b.len);
            self.cshaker.update(encoded_b_len.slice());
            self.cshaker.update(b);
        }

        /// Return an authentication tag for the current state.
        pub fn final(self: *Self, out: []u8) void {
            const encoded_out_len = NistLengthEncoding.encode(.right, out.len);
            self.cshaker.update(encoded_out_len.slice());
            self.cshaker.final(out);
        }

        /// Align the input to a block boundary.
        pub fn fillBlock(self: *Self) void {
            self.cshaker.fillBlock();
        }

        /// Squeeze a slice of bytes from the state.
        /// `out` can be any length, and the function can be called multiple times.
        pub fn squeeze(self: *Self, out: []u8) void {
            if (!self.xof_mode) {
                const encoded_out_len = comptime NistLengthEncoding.encode(.right, 0);
                self.update(encoded_out_len.slice());
                self.xof_mode = true;
            }
            self.cshaker.squeeze(out);
        }

        pub const Error = error{};
        pub const Writer = std.io.Writer(*Self, Error, write);

        fn write(self: *Self, bytes: []const u8) Error!usize {
            self.update(bytes);
            return bytes.len;
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }
    };
}

/// The NIST SP 800-185 encoded length format.
pub const NistLengthEncoding = enum {
    left,
    right,

    /// A length encoded according to NIST SP 800-185.
    pub const Length = struct {
        /// The size of the encoded value, in bytes.
        len: usize = 0,
        /// A buffer to store the encoded length.
        buf: [@sizeOf(usize) + 1]u8 = undefined,

        /// Return the encoded length as a slice.
        pub fn slice(self: *const Length) []const u8 {
            return self.buf[0..self.len];
        }
    };

    /// Encode a length according to NIST SP 800-185.
    pub fn encode(comptime encoding: NistLengthEncoding, len: usize) Length {
        const len_bits = @bitSizeOf(@TypeOf(len)) - @clz(len) + 3;
        const len_bytes = std.math.divCeil(usize, len_bits, 8) catch unreachable;

        var res = Length{ .len = len_bytes + 1 };
        if (encoding == .right) {
            res.buf[len_bytes] = @intCast(len_bytes);
        }
        const end = if (encoding == .right) len_bytes - 1 else len_bytes;
        res.buf[end] = @truncate(len << 3);
        var len_ = len >> 5;
        for (1..len_bytes) |i| {
            res.buf[end - i] = @truncate(len_);
            len_ >>= 8;
        }
        if (encoding == .left) {
            res.buf[0] = @intCast(len_bytes);
        }
        return res;
    }
};

const htest = @import("test.zig");

test "sha3-224 single" {
    try htest.assertEqualHash(Sha3_224, "6b4e03423667dbb73b6e15454f0eb1abd4597f9a1b078e3f5b5a6bc7", "");
    try htest.assertEqualHash(Sha3_224, "e642824c3f8cf24ad09234ee7d3c766fc9a3a5168d0c94ad73b46fdf", "abc");
    try htest.assertEqualHash(Sha3_224, "543e6868e1666c1a643630df77367ae5a62a85070a51c14cbf665cbc", "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu");
}

test "sha3-224 streaming" {
    var h = Sha3_224.init(.{});
    var out: [28]u8 = undefined;

    h.final(out[0..]);
    try htest.assertEqual("6b4e03423667dbb73b6e15454f0eb1abd4597f9a1b078e3f5b5a6bc7", out[0..]);

    h = Sha3_224.init(.{});
    h.update("abc");
    h.final(out[0..]);
    try htest.assertEqual("e642824c3f8cf24ad09234ee7d3c766fc9a3a5168d0c94ad73b46fdf", out[0..]);

    h = Sha3_224.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    try htest.assertEqual("e642824c3f8cf24ad09234ee7d3c766fc9a3a5168d0c94ad73b46fdf", out[0..]);
}

test "sha3-256 single" {
    try htest.assertEqualHash(Sha3_256, "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a", "");
    try htest.assertEqualHash(Sha3_256, "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532", "abc");
    try htest.assertEqualHash(Sha3_256, "916f6061fe879741ca6469b43971dfdb28b1a32dc36cb3254e812be27aad1d18", "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu");
}

test "sha3-256 streaming" {
    var h = Sha3_256.init(.{});
    var out: [32]u8 = undefined;

    h.final(out[0..]);
    try htest.assertEqual("a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a", out[0..]);

    h = Sha3_256.init(.{});
    h.update("abc");
    h.final(out[0..]);
    try htest.assertEqual("3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532", out[0..]);

    h = Sha3_256.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    try htest.assertEqual("3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532", out[0..]);
}

test "sha3-256 aligned final" {
    var block = [_]u8{0} ** Sha3_256.block_length;
    var out: [Sha3_256.digest_length]u8 = undefined;

    var h = Sha3_256.init(.{});
    h.update(&block);
    h.final(out[0..]);
}

test "sha3-384 single" {
    const h1 = "0c63a75b845e4f7d01107d852e4c2485c51a50aaaa94fc61995e71bbee983a2ac3713831264adb47fb6bd1e058d5f004";
    try htest.assertEqualHash(Sha3_384, h1, "");
    const h2 = "ec01498288516fc926459f58e2c6ad8df9b473cb0fc08c2596da7cf0e49be4b298d88cea927ac7f539f1edf228376d25";
    try htest.assertEqualHash(Sha3_384, h2, "abc");
    const h3 = "79407d3b5916b59c3e30b09822974791c313fb9ecc849e406f23592d04f625dc8c709b98b43b3852b337216179aa7fc7";
    try htest.assertEqualHash(Sha3_384, h3, "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu");
}

test "sha3-384 streaming" {
    var h = Sha3_384.init(.{});
    var out: [48]u8 = undefined;

    const h1 = "0c63a75b845e4f7d01107d852e4c2485c51a50aaaa94fc61995e71bbee983a2ac3713831264adb47fb6bd1e058d5f004";
    h.final(out[0..]);
    try htest.assertEqual(h1, out[0..]);

    const h2 = "ec01498288516fc926459f58e2c6ad8df9b473cb0fc08c2596da7cf0e49be4b298d88cea927ac7f539f1edf228376d25";
    h = Sha3_384.init(.{});
    h.update("abc");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);

    h = Sha3_384.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);
}

test "sha3-512 single" {
    const h1 = "a69f73cca23a9ac5c8b567dc185a756e97c982164fe25859e0d1dcc1475c80a615b2123af1f5f94c11e3e9402c3ac558f500199d95b6d3e301758586281dcd26";
    try htest.assertEqualHash(Sha3_512, h1, "");
    const h2 = "b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0";
    try htest.assertEqualHash(Sha3_512, h2, "abc");
    const h3 = "afebb2ef542e6579c50cad06d2e578f9f8dd6881d7dc824d26360feebf18a4fa73e3261122948efcfd492e74e82e2189ed0fb440d187f382270cb455f21dd185";
    try htest.assertEqualHash(Sha3_512, h3, "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu");
}

test "sha3-512 streaming" {
    var h = Sha3_512.init(.{});
    var out: [64]u8 = undefined;

    const h1 = "a69f73cca23a9ac5c8b567dc185a756e97c982164fe25859e0d1dcc1475c80a615b2123af1f5f94c11e3e9402c3ac558f500199d95b6d3e301758586281dcd26";
    h.final(out[0..]);
    try htest.assertEqual(h1, out[0..]);

    const h2 = "b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0";
    h = Sha3_512.init(.{});
    h.update("abc");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);

    h = Sha3_512.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);
}

test "sha3-512 aligned final" {
    var block = [_]u8{0} ** Sha3_512.block_length;
    var out: [Sha3_512.digest_length]u8 = undefined;

    var h = Sha3_512.init(.{});
    h.update(&block);
    h.final(out[0..]);
}

test "keccak-256 single" {
    try htest.assertEqualHash(Keccak256, "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470", "");
    try htest.assertEqualHash(Keccak256, "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45", "abc");
    try htest.assertEqualHash(Keccak256, "f519747ed599024f3882238e5ab43960132572b7345fbeb9a90769dafd21ad67", "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu");
}

test "keccak-512 single" {
    try htest.assertEqualHash(Keccak512, "0eab42de4c3ceb9235fc91acffe746b29c29a8c366b7c60e4e67c466f36a4304c00fa9caf9d87976ba469bcbe06713b435f091ef2769fb160cdab33d3670680e", "");
    try htest.assertEqualHash(Keccak512, "18587dc2ea106b9a1563e32b3312421ca164c7f1f07bc922a9c83d77cea3a1e5d0c69910739025372dc14ac9642629379540c17e2a65b19d77aa511a9d00bb96", "abc");
    try htest.assertEqualHash(Keccak512, "ac2fb35251825d3aa48468a9948c0a91b8256f6d97d8fa4160faff2dd9dfcc24f3f1db7a983dad13d53439ccac0b37e24037e7b95f80f59f37a2f683c4ba4682", "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu");
}

test "SHAKE-128 single" {
    var out: [10]u8 = undefined;
    Shake128.hash("hello123", &out, .{});
    try htest.assertEqual("1b85861510bc4d8e467d", &out);
}

test "SHAKE-128 multisqueeze" {
    var out: [10]u8 = undefined;
    var h = Shake128.init(.{});
    h.update("hello123");
    h.squeeze(out[0..4]);
    h.squeeze(out[4..]);
    try htest.assertEqual("1b85861510bc4d8e467d", &out);
}

test "SHAKE-128 multisqueeze with multiple blocks" {
    var out: [100]u8 = undefined;
    var out2: [100]u8 = undefined;

    var h = Shake128.init(.{});
    h.update("hello123");
    h.squeeze(out[0..50]);
    h.squeeze(out[50..]);

    var h2 = Shake128.init(.{});
    h2.update("hello123");
    h2.squeeze(&out2);
    try std.testing.expectEqualSlices(u8, &out, &out2);
}

test "SHAKE-256 single" {
    var out: [10]u8 = undefined;
    Shake256.hash("hello123", &out, .{});
    try htest.assertEqual("ade612ba265f92de4a37", &out);
}

test "TurboSHAKE-128" {
    var out: [32]u8 = undefined;
    TurboShake(128, 0x06).hash("\xff", &out, .{});
    try htest.assertEqual("8ec9c66465ed0d4a6c35d13506718d687a25cb05c74cca1e42501abd83874a67", &out);
}

test "SHA-3 with streaming" {
    var msg: [613]u8 = [613]u8{ 0x97, 0xd1, 0x2d, 0x1a, 0x16, 0x2d, 0x36, 0x4d, 0x20, 0x62, 0x19, 0x0b, 0x14, 0x93, 0xbb, 0xf8, 0x5b, 0xea, 0x04, 0xc2, 0x61, 0x8e, 0xd6, 0x08, 0x81, 0xa1, 0x1d, 0x73, 0x27, 0x48, 0xbf, 0xa4, 0xba, 0xb1, 0x9a, 0x48, 0x9c, 0xf9, 0x9b, 0xff, 0x34, 0x48, 0xa9, 0x75, 0xea, 0xc8, 0xa3, 0x48, 0x24, 0x9d, 0x75, 0x27, 0x48, 0xec, 0x03, 0xb0, 0xbb, 0xdf, 0x33, 0x90, 0xe3, 0x93, 0xed, 0x68, 0x24, 0x39, 0x12, 0xdf, 0xea, 0xee, 0x8c, 0x9f, 0x96, 0xde, 0x42, 0x46, 0x8c, 0x2b, 0x17, 0x83, 0x36, 0xfb, 0xf4, 0xf7, 0xff, 0x79, 0xb9, 0x45, 0x41, 0xc9, 0x56, 0x1a, 0x6b, 0x0c, 0xa4, 0x1a, 0xdd, 0x6b, 0x95, 0xe8, 0x03, 0x0f, 0x09, 0x29, 0x40, 0x1b, 0xea, 0x87, 0xfa, 0xb9, 0x18, 0xa9, 0x95, 0x07, 0x7c, 0x2f, 0x7c, 0x33, 0xfb, 0xc5, 0x11, 0x5e, 0x81, 0x0e, 0xbc, 0xae, 0xec, 0xb3, 0xe1, 0x4a, 0x26, 0x56, 0xe8, 0x5b, 0x11, 0x9d, 0x37, 0x06, 0x9b, 0x34, 0x31, 0x6e, 0xa3, 0xba, 0x41, 0xbc, 0x11, 0xd8, 0xc5, 0x15, 0xc9, 0x30, 0x2c, 0x9b, 0xb6, 0x71, 0xd8, 0x7c, 0xbc, 0x38, 0x2f, 0xd5, 0xbd, 0x30, 0x96, 0xd4, 0xa3, 0x00, 0x77, 0x9d, 0x55, 0x4a, 0x33, 0x53, 0xb6, 0xb3, 0x35, 0x1b, 0xae, 0xe5, 0xdc, 0x22, 0x23, 0x85, 0x95, 0x88, 0xf9, 0x3b, 0xbf, 0x74, 0x13, 0xaa, 0xcb, 0x0a, 0x60, 0x79, 0x13, 0x79, 0xc0, 0x4a, 0x02, 0xdb, 0x1c, 0xc9, 0xff, 0x60, 0x57, 0x9a, 0x70, 0x28, 0x58, 0x60, 0xbc, 0x57, 0x07, 0xc7, 0x47, 0x1a, 0x45, 0x71, 0x76, 0x94, 0xfb, 0x05, 0xad, 0xec, 0x12, 0x29, 0x5a, 0x44, 0x6a, 0x81, 0xd9, 0xc6, 0xf0, 0xb6, 0x9b, 0x97, 0x83, 0x69, 0xfb, 0xdc, 0x0d, 0x4a, 0x67, 0xbc, 0x72, 0xf5, 0x43, 0x5e, 0x9b, 0x13, 0xf2, 0xe4, 0x6d, 0x49, 0xdb, 0x76, 0xcb, 0x42, 0x6a, 0x3c, 0x9f, 0xa1, 0xfe, 0x5e, 0xca, 0x0a, 0xfc, 0xfa, 0x39, 0x27, 0xd1, 0x3c, 0xcb, 0x9a, 0xde, 0x4c, 0x6b, 0x09, 0x8b, 0x49, 0xfd, 0x1e, 0x3d, 0x5e, 0x67, 0x7c, 0x57, 0xad, 0x90, 0xcc, 0x46, 0x5f, 0x5c, 0xae, 0x6a, 0x9c, 0xb2, 0xcd, 0x2c, 0x89, 0x78, 0xcf, 0xf1, 0x49, 0x96, 0x55, 0x1e, 0x04, 0xef, 0x0e, 0x1c, 0xde, 0x6c, 0x96, 0x51, 0x00, 0xee, 0x9a, 0x1f, 0x8d, 0x61, 0xbc, 0xeb, 0xb1, 0xa6, 0xa5, 0x21, 0x8b, 0xa7, 0xf8, 0x25, 0x41, 0x48, 0x62, 0x5b, 0x01, 0x6c, 0x7c, 0x2a, 0xe8, 0xff, 0xf9, 0xf9, 0x1f, 0xe2, 0x79, 0x2e, 0xd1, 0xff, 0xa3, 0x2e, 0x1c, 0x3a, 0x1a, 0x5d, 0x2b, 0x7b, 0x87, 0x25, 0x22, 0xa4, 0x90, 0xea, 0x26, 0x9d, 0xdd, 0x13, 0x60, 0x4c, 0x10, 0x03, 0xf6, 0x99, 0xd3, 0x21, 0x0c, 0x69, 0xc6, 0xd8, 0xc8, 0x9e, 0x94, 0x89, 0x51, 0x21, 0xe3, 0x9a, 0xcd, 0xda, 0x54, 0x72, 0x64, 0xae, 0x94, 0x79, 0x36, 0x81, 0x44, 0x14, 0x6d, 0x3a, 0x0e, 0xa6, 0x30, 0xbf, 0x95, 0x99, 0xa6, 0xf5, 0x7f, 0x4f, 0xef, 0xc6, 0x71, 0x2f, 0x36, 0x13, 0x14, 0xa2, 0x9d, 0xc2, 0x0c, 0x0d, 0x4e, 0xc0, 0x02, 0xd3, 0x6f, 0xee, 0x98, 0x5e, 0x24, 0x31, 0x74, 0x11, 0x96, 0x6e, 0x43, 0x57, 0xe8, 0x8e, 0xa0, 0x8d, 0x3d, 0x79, 0x38, 0x20, 0xc2, 0x0f, 0xb4, 0x75, 0x99, 0x3b, 0xb1, 0xf0, 0xe8, 0xe1, 0xda, 0xf9, 0xd4, 0xe6, 0xd6, 0xf4, 0x8a, 0x32, 0x4a, 0x4a, 0x25, 0xa8, 0xd9, 0x60, 0xd6, 0x33, 0x31, 0x97, 0xb9, 0xb6, 0xed, 0x5f, 0xfc, 0x15, 0xbd, 0x13, 0xc0, 0x3a, 0x3f, 0x1f, 0x2d, 0x09, 0x1d, 0xeb, 0x69, 0x6a, 0xfe, 0xd7, 0x95, 0x3e, 0x8a, 0x4e, 0xe1, 0x6e, 0x61, 0xb2, 0x6c, 0xe3, 0x2b, 0x70, 0x60, 0x7e, 0x8c, 0xe4, 0xdd, 0x27, 0x30, 0x7e, 0x0d, 0xc7, 0xb7, 0x9a, 0x1a, 0x3c, 0xcc, 0xa7, 0x22, 0x77, 0x14, 0x05, 0x50, 0x57, 0x31, 0x1b, 0xc8, 0xbf, 0xce, 0x52, 0xaf, 0x9c, 0x8e, 0x10, 0x2e, 0xd2, 0x16, 0xb6, 0x6e, 0x43, 0x10, 0xaf, 0x8b, 0xde, 0x1d, 0x60, 0xb2, 0x7d, 0xe6, 0x2f, 0x08, 0x10, 0x12, 0x7e, 0xb4, 0x76, 0x45, 0xb6, 0xd8, 0x9b, 0x26, 0x40, 0xa1, 0x63, 0x5c, 0x7a, 0x2a, 0xb1, 0x8c, 0xd6, 0xa4, 0x6f, 0x5a, 0xae, 0x33, 0x7e, 0x6d, 0x71, 0xf5, 0xc8, 0x6d, 0x80, 0x1c, 0x35, 0xfc, 0x3f, 0xc1, 0xa6, 0xc6, 0x1a, 0x15, 0x04, 0x6d, 0x76, 0x38, 0x32, 0x95, 0xb2, 0x51, 0x1a, 0xe9, 0x3e, 0x89, 0x9f, 0x0c, 0x79 };
    var out: [Sha3_256.digest_length]u8 = undefined;

    Sha3_256.hash(&msg, &out, .{});
    try htest.assertEqual("5780048dfa381a1d01c747906e4a08711dd34fd712ecd7c6801dd2b38fd81a89", &out);

    var h = Sha3_256.init(.{});
    h.update(msg[0..64]);
    h.update(msg[64..613]);
    h.final(&out);
    try htest.assertEqual("5780048dfa381a1d01c747906e4a08711dd34fd712ecd7c6801dd2b38fd81a89", &out);
}

test "cSHAKE-128 with no context nor function name" {
    var out: [32]u8 = undefined;
    CShake128.hash("hello123", &out, .{});
    try htest.assertEqual("1b85861510bc4d8e467d6f8a92270533cbaa7ba5e06c2d2a502854bac468b8b9", &out);
}

test "cSHAKE-128 with context" {
    var out: [32]u8 = undefined;
    CShake128.hash("hello123", &out, .{ .context = "custom" });
    try htest.assertEqual("7509fa13a6bd3e38ad5c6fac042142c233996e40ebffc86c276f108b3b19cc6a", &out);
}

test "cSHAKE-128 with context and function" {
    var out: [32]u8 = undefined;
    CShake(128, "function").hash("hello123", &out, .{ .context = "custom" });
    try htest.assertEqual("ad7f4d7db2d96587fcd5047c65d37c368f5366e3afac60bb9b66b0bb95dfb675", &out);
}

test "cSHAKE-256" {
    var out: [32]u8 = undefined;
    CShake256.hash("hello123", &out, .{ .context = "custom" });
    try htest.assertEqual("dabe027eb1a6cbe3a0542d0560eb4e6b39146dd72ae1bf89c970a61bd93b1813", &out);
}

test "KMAC-128 with empty key and message" {
    var out: [KMac128.mac_length]u8 = undefined;
    const key = "";
    KMac128.create(&out, "", key);
    try htest.assertEqual("5c135c615152fb4d9784dd1155f9b6034e013fd77165c327dfa4d36701983ef7", &out);
}

test "KMAC-128" {
    var out: [KMac128.mac_length]u8 = undefined;
    const key = "A KMAC secret key";
    KMac128.create(&out, "hello123", key);
    try htest.assertEqual("1fa1c0d761129a83f9a4299ca137674de8373a3cc437799ae4c129e651627f8e", &out);
}

test "KMAC-128 with a customization string" {
    var out: [KMac128.mac_length]u8 = undefined;
    const key = "A KMAC secret key";
    KMac128.createWithOptions(&out, "hello123", key, .{ .context = "custom" });
    try htest.assertEqual("c58c6d42dc00a27dfa8e7e08f8c9307cecb5d662ddb11b6c36057fc2e0e068ba", &out);
}

test "KMACXOF-128" {
    const key = "A KMAC secret key";
    var xof = KMac128.init(key);
    xof.update("hello123");
    var out: [50]u8 = undefined;
    xof.squeeze(&out);
    try htest.assertEqual("628c2fb870d294b3673ac82d9f0d651aae6a5bb8084ea8cd8343cb888d075b9053173200a71f301141069c3c0322527981f7", &out);
    xof.squeeze(&out);
    try htest.assertEqual("7b638e178cfdac5727a4ea7694efaa967a65a1d0034501855acff506b4158d187d5a18d668e67b43f2abf61144b20ed4c09f", &out);
}

test "KMACXOF-256" {
    const key = "A KMAC secret key";
    var xof = KMac256.init(key);
    xof.update("hello123");
    var out: [50]u8 = undefined;
    xof.squeeze(&out);
    try htest.assertEqual("23fc644bc2655ba6fde7b7c11f2804f22e8d8c6bd7db856268bf3370ce2362703f6c7e91916a1b8c116e60edfbcb25613054", &out);
    xof.squeeze(&out);
    try htest.assertEqual("ff97251020ff255ee65a1c1f5f78ebe904f61211c39f973f82fbce2b196b9f51c2cb12afe51549a0f1eaf7954e657ba11af3", &out);
}

test "TupleHash-128" {
    var st = TupleHash128.init();
    st.update("hello");
    st.update("123");
    var out: [32]u8 = undefined;
    st.final(&out);
    try htest.assertEqual("3938d49ade8ec0f0c305ac63497b2d2e8b2f650714f9667cc41816b1c11ffd20", &out);
}

test "TupleHash-256" {
    var st = TupleHash256.init();
    st.update("hello");
    st.update("123");
    var out: [64]u8 = undefined;
    st.final(&out);
    try htest.assertEqual("2dca563c2882f2ba4f46a441a4c5e13fb97150d1436fe99c7e4e43a2d20d0f1cd3d38483bde4a966930606dfa6c61c4ca6400aeedfb474d1bf0d7f6a70968289", &out);
}
