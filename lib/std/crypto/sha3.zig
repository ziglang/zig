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

/// A generic Keccak hash function.
pub fn Keccak(comptime f: u11, comptime output_bits: u11, comptime delim: u8, comptime rounds: u5) type {
    comptime assert(output_bits > 0 and output_bits * 2 < f and output_bits % 8 == 0); // invalid output length

    const State = KeccakState(f, output_bits * 2, delim, rounds);

    return struct {
        const Self = @This();

        st: State = .{},

        /// The output length, in bytes.
        pub const digest_length = output_bits / 8;
        /// The block length, or rate, in bytes.
        pub const block_length = State.rate;
        /// Keccak does not have any options.
        pub const Options = struct {};

        /// Initialize a Keccak hash function.
        pub fn init(options: Options) Self {
            _ = options;
            return Self{};
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
    const f = 1600;
    const rounds = 24;
    const State = KeccakState(f, security_level * 2, 0x1f, rounds);

    return struct {
        const Self = @This();

        st: State = .{},
        buf: [State.rate]u8 = undefined,
        offset: usize = 0,
        padded: bool = false,

        /// The recommended output length, in bytes.
        pub const digest_length = security_level / 2;
        /// The block length, or rate, in bytes.
        pub const block_length = State.rate;
        /// Keccak does not have any options.
        pub const Options = struct {};

        /// Initialize a SHAKE extensible hash function.
        pub fn init(options: Options) Self {
            _ = options;
            return Self{};
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
                    const n = math.min(left, out.len);
                    mem.copy(u8, out[0..n], self.buf[self.offset..][0..n]);
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
                mem.copy(u8, out[0..], self.buf[0..out.len]);
                self.offset = out.len;
            }
        }

        /// Return the hash of the absorbed bytes.
        /// `out` can be of any length, but the function must not be called multiple times (use `squeeze` for that purpose instead).
        pub fn final(self: *Self, out: []u8) void {
            self.squeeze(out);
            self.st.st.clear(0, State.rate);
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
