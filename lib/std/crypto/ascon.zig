//! Ascon is a 320-bit permutation, selected as new standard for lightweight cryptography
//! in the NIST Lightweight Cryptography competition (2019–2023).
//! https://csrc.nist.gov/News/2023/lightweight-cryptography-nist-selects-ascon
//!
//! The permutation is compact, and optimized for timing and side channel resistance,
//! making it a good choice for embedded applications.
//!
//! It is not meant to be used directly, but as a building block for symmetric cryptography.

const std = @import("std");
const builtin = std.builtin;
const debug = std.debug;
const mem = std.mem;
const testing = std.testing;
const rotr = std.math.rotr;

/// An Ascon state.
///
/// The state is represented as 5 64-bit words.
///
/// The NIST submission (v1.2) serializes these words as big-endian,
/// but software implementations are free to use native endianness.
pub fn State(comptime endian: builtin.Endian) type {
    return struct {
        const Self = @This();

        /// Number of bytes in the state.
        pub const block_bytes = 40;

        const Block = [5]u64;

        st: Block,

        /// Initialize the state from a slice of bytes.
        pub fn init(initial_state: [block_bytes]u8) Self {
            var state = Self{ .st = undefined };
            @memcpy(state.asBytes(), &initial_state);
            state.endianSwap();
            return state;
        }

        /// Initialize the state from u64 words in native endianness.
        pub fn initFromWords(initial_state: [5]u64) Self {
            var state = Self{ .st = initial_state };
            return state;
        }

        /// Initialize the state for Ascon XOF
        pub fn initXof() Self {
            return Self{ .st = Block{
                0xb57e273b814cd416,
                0x2b51042562ae2420,
                0x66a3a7768ddf2218,
                0x5aad0a7a8153650c,
                0x4f3e0e32539493b6,
            } };
        }

        /// Initialize the state for Ascon XOFa
        pub fn initXofA() Self {
            return Self{ .st = Block{
                0x44906568b77b9832,
                0xcd8d6cae53455532,
                0xf7b5212756422129,
                0x246885e1de0d225b,
                0xa8cb5ce33449973f,
            } };
        }

        /// A representation of the state as bytes. The byte order is architecture-dependent.
        pub fn asBytes(self: *Self) *[block_bytes]u8 {
            return mem.asBytes(&self.st);
        }

        /// Byte-swap the entire state if the architecture doesn't match the required endianness.
        pub fn endianSwap(self: *Self) void {
            for (&self.st) |*w| {
                w.* = mem.toNative(u64, w.*, endian);
            }
        }

        /// Set bytes starting at the beginning of the state.
        pub fn setBytes(self: *Self, bytes: []const u8) void {
            var i: usize = 0;
            while (i + 8 <= bytes.len) : (i += 8) {
                self.st[i / 8] = mem.readInt(u64, bytes[i..][0..8], endian);
            }
            if (i < bytes.len) {
                var padded = [_]u8{0} ** 8;
                @memcpy(padded[0 .. bytes.len - i], bytes[i..]);
                self.st[i / 8] = mem.readInt(u64, padded[0..], endian);
            }
        }

        /// XOR a byte into the state at a given offset.
        pub fn addByte(self: *Self, byte: u8, offset: usize) void {
            const z = switch (endian) {
                .Big => 64 - 8 - 8 * @as(u6, @truncate(offset % 8)),
                .Little => 8 * @as(u6, @truncate(offset % 8)),
            };
            self.st[offset / 8] ^= @as(u64, byte) << z;
        }

        /// XOR bytes into the beginning of the state.
        pub fn addBytes(self: *Self, bytes: []const u8) void {
            var i: usize = 0;
            while (i + 8 <= bytes.len) : (i += 8) {
                self.st[i / 8] ^= mem.readInt(u64, bytes[i..][0..8], endian);
            }
            if (i < bytes.len) {
                var padded = [_]u8{0} ** 8;
                @memcpy(padded[0 .. bytes.len - i], bytes[i..]);
                self.st[i / 8] ^= mem.readInt(u64, padded[0..], endian);
            }
        }

        /// Extract the first bytes of the state.
        pub fn extractBytes(self: *Self, out: []u8) void {
            var i: usize = 0;
            while (i + 8 <= out.len) : (i += 8) {
                mem.writeInt(u64, out[i..][0..8], self.st[i / 8], endian);
            }
            if (i < out.len) {
                var padded = [_]u8{0} ** 8;
                mem.writeInt(u64, padded[0..], self.st[i / 8], endian);
                @memcpy(out[i..], padded[0 .. out.len - i]);
            }
        }

        /// XOR the first bytes of the state into a slice of bytes.
        pub fn xorBytes(self: *Self, out: []u8, in: []const u8) void {
            debug.assert(out.len == in.len);

            var i: usize = 0;
            while (i + 8 <= in.len) : (i += 8) {
                const x = mem.readIntNative(u64, in[i..][0..8]) ^ mem.nativeTo(u64, self.st[i / 8], endian);
                mem.writeIntNative(u64, out[i..][0..8], x);
            }
            if (i < in.len) {
                var padded = [_]u8{0} ** 8;
                @memcpy(padded[0 .. in.len - i], in[i..]);
                const x = mem.readIntNative(u64, &padded) ^ mem.nativeTo(u64, self.st[i / 8], endian);
                mem.writeIntNative(u64, &padded, x);
                @memcpy(out[i..], padded[0 .. in.len - i]);
            }
        }

        /// Set the words storing the bytes of a given range to zero.
        pub fn clear(self: *Self, from: usize, to: usize) void {
            @memset(self.st[from / 8 .. (to + 7) / 8], 0);
        }

        /// Clear the entire state, disabling compiler optimizations.
        pub fn secureZero(self: *Self) void {
            std.crypto.utils.secureZero(u64, &self.st);
        }

        /// Apply a reduced-round permutation to the state.
        pub inline fn permuteR(state: *Self, comptime rounds: u4) void {
            const rks = [12]u64{ 0xf0, 0xe1, 0xd2, 0xc3, 0xb4, 0xa5, 0x96, 0x87, 0x78, 0x69, 0x5a, 0x4b };
            inline for (rks[rks.len - rounds ..]) |rk| {
                state.round(rk);
            }
        }

        /// Apply a full-round permutation to the state.
        pub inline fn permute(state: *Self) void {
            state.permuteR(12);
        }

        /// Apply a permutation to the state and prevent backtracking.
        /// The rate is expressed in bytes and must be a multiple of the word size (8).
        pub inline fn permuteRatchet(state: *Self, comptime rounds: u4, comptime rate: u6) void {
            const capacity = block_bytes - rate;
            debug.assert(capacity > 0 and capacity % 8 == 0); // capacity must be a multiple of 64 bits
            var mask: [capacity / 8]u64 = undefined;
            inline for (&mask, state.st[state.st.len - mask.len ..]) |*m, x| m.* = x;
            state.permuteR(rounds);
            inline for (mask, state.st[state.st.len - mask.len ..]) |m, *x| x.* ^= m;
        }

        // Core Ascon permutation.
        inline fn round(state: *Self, rk: u64) void {
            const x = &state.st;
            x[2] ^= rk;

            x[0] ^= x[4];
            x[4] ^= x[3];
            x[2] ^= x[1];
            var t: Block = .{
                x[0] ^ (~x[1] & x[2]),
                x[1] ^ (~x[2] & x[3]),
                x[2] ^ (~x[3] & x[4]),
                x[3] ^ (~x[4] & x[0]),
                x[4] ^ (~x[0] & x[1]),
            };
            t[1] ^= t[0];
            t[3] ^= t[2];
            t[0] ^= t[4];

            x[2] = t[2] ^ rotr(u64, t[2], 6 - 1);
            x[3] = t[3] ^ rotr(u64, t[3], 17 - 10);
            x[4] = t[4] ^ rotr(u64, t[4], 41 - 7);
            x[0] = t[0] ^ rotr(u64, t[0], 28 - 19);
            x[1] = t[1] ^ rotr(u64, t[1], 61 - 39);
            x[2] = t[2] ^ rotr(u64, x[2], 1);
            x[3] = t[3] ^ rotr(u64, x[3], 10);
            x[4] = t[4] ^ rotr(u64, x[4], 7);
            x[0] = t[0] ^ rotr(u64, x[0], 19);
            x[1] = t[1] ^ rotr(u64, x[1], 39);
            x[2] = ~x[2];
        }
    };
}

test "ascon" {
    const Ascon = State(.Big);
    const bytes = [_]u8{0x01} ** Ascon.block_bytes;
    var st = Ascon.init(bytes);
    var out: [Ascon.block_bytes]u8 = undefined;
    st.permute();
    st.extractBytes(&out);
    const expected1 = [_]u8{ 148, 147, 49, 226, 218, 221, 208, 113, 186, 94, 96, 10, 183, 219, 119, 150, 169, 206, 65, 18, 215, 97, 78, 106, 118, 81, 211, 150, 52, 17, 117, 64, 216, 45, 148, 240, 65, 181, 90, 180 };
    try testing.expectEqualSlices(u8, &expected1, &out);
    st.clear(0, 10);
    st.extractBytes(&out);
    const expected2 = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 169, 206, 65, 18, 215, 97, 78, 106, 118, 81, 211, 150, 52, 17, 117, 64, 216, 45, 148, 240, 65, 181, 90, 180 };
    try testing.expectEqualSlices(u8, &expected2, &out);
    st.addByte(1, 5);
    st.addByte(2, 5);
    st.extractBytes(&out);
    const expected3 = [_]u8{ 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 169, 206, 65, 18, 215, 97, 78, 106, 118, 81, 211, 150, 52, 17, 117, 64, 216, 45, 148, 240, 65, 181, 90, 180 };
    try testing.expectEqualSlices(u8, &expected3, &out);
    st.addBytes(&bytes);
    st.extractBytes(&out);
    const expected4 = [_]u8{ 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 168, 207, 64, 19, 214, 96, 79, 107, 119, 80, 210, 151, 53, 16, 116, 65, 217, 44, 149, 241, 64, 180, 91, 181 };
    try testing.expectEqualSlices(u8, &expected4, &out);
}
