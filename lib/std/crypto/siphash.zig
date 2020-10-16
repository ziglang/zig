// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//
// SipHash is a moderately fast pseudorandom function, returning a 64-bit or 128-bit tag for an arbitrary long input.
//
// Typical use cases include:
// - protection against against DoS attacks for hash tables and bloom filters
// - authentication of short-lived messages in online protocols
//
// https://131002.net/siphash/
const std = @import("../std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const math = std.math;
const mem = std.mem;

/// SipHash function with 64-bit output.
///
/// Recommended parameters are:
/// - (c_rounds=4, d_rounds=8) for conservative security; regular hash functions such as BLAKE2 or BLAKE3 are usually a better alternative.
/// - (c_rounds=2, d_rounds=4) standard parameters.
/// - (c_rounds=1, d_rounds=3) reduced-round function. Faster, no known implications on its practical security level.
/// - (c_rounds=1, d_rounds=2) fastest option, but the output may be distinguishable from random data with related keys or non-uniform input - not suitable as a PRF.
///
/// SipHash is not a traditional hash function. If the input includes untrusted content, a secret key is absolutely necessary.
/// And due to its small output size, collisions in SipHash64 can be found with an exhaustive search.
pub fn SipHash64(comptime c_rounds: usize, comptime d_rounds: usize) type {
    return SipHash(u64, c_rounds, d_rounds);
}

/// SipHash function with 128-bit output.
///
/// Recommended parameters are:
/// - (c_rounds=4, d_rounds=8) for conservative security; regular hash functions such as BLAKE2 or BLAKE3 are usually a better alternative.
/// - (c_rounds=2, d_rounds=4) standard parameters.
/// - (c_rounds=1, d_rounds=4) reduced-round function. Recommended to hash very short, similar strings, when a 128-bit PRF output is still required.
/// - (c_rounds=1, d_rounds=3) reduced-round function. Faster, no known implications on its practical security level.
/// - (c_rounds=1, d_rounds=2) fastest option, but the output may be distinguishable from random data with related keys or non-uniform input - not suitable as a PRF.
///
/// SipHash is not a traditional hash function. If the input includes untrusted content, a secret key is absolutely necessary.
pub fn SipHash128(comptime c_rounds: usize, comptime d_rounds: usize) type {
    return SipHash(u128, c_rounds, d_rounds);
}

fn SipHashStateless(comptime T: type, comptime c_rounds: usize, comptime d_rounds: usize) type {
    assert(T == u64 or T == u128);
    assert(c_rounds > 0 and d_rounds > 0);

    return struct {
        const Self = @This();
        const block_length = 64;
        const digest_length = 64;
        const key_length = 16;

        v0: u64,
        v1: u64,
        v2: u64,
        v3: u64,
        msg_len: u8,

        pub fn init(key: *const [key_length]u8) Self {
            const k0 = mem.readIntLittle(u64, key[0..8]);
            const k1 = mem.readIntLittle(u64, key[8..16]);

            var d = Self{
                .v0 = k0 ^ 0x736f6d6570736575,
                .v1 = k1 ^ 0x646f72616e646f6d,
                .v2 = k0 ^ 0x6c7967656e657261,
                .v3 = k1 ^ 0x7465646279746573,
                .msg_len = 0,
            };

            if (T == u128) {
                d.v1 ^= 0xee;
            }

            return d;
        }

        pub fn update(self: *Self, b: []const u8) void {
            std.debug.assert(b.len % 8 == 0);

            var off: usize = 0;
            while (off < b.len) : (off += 8) {
                @call(.{ .modifier = .always_inline }, self.round, .{b[off..][0..8].*});
            }

            self.msg_len +%= @truncate(u8, b.len);
        }

        pub fn final(self: *Self, b: []const u8) T {
            std.debug.assert(b.len < 8);

            self.msg_len +%= @truncate(u8, b.len);

            var buf = [_]u8{0} ** 8;
            mem.copy(u8, buf[0..], b[0..]);
            buf[7] = self.msg_len;
            self.round(buf);

            if (T == u128) {
                self.v2 ^= 0xee;
            } else {
                self.v2 ^= 0xff;
            }

            // TODO this is a workaround, should be able to supply the value without a separate variable
            const inl = std.builtin.CallOptions{ .modifier = .always_inline };

            comptime var i: usize = 0;
            inline while (i < d_rounds) : (i += 1) {
                @call(inl, sipRound, .{self});
            }

            const b1 = self.v0 ^ self.v1 ^ self.v2 ^ self.v3;
            if (T == u64) {
                return b1;
            }

            self.v1 ^= 0xdd;

            comptime var j: usize = 0;
            inline while (j < d_rounds) : (j += 1) {
                @call(inl, sipRound, .{self});
            }

            const b2 = self.v0 ^ self.v1 ^ self.v2 ^ self.v3;
            return (@as(u128, b2) << 64) | b1;
        }

        fn round(self: *Self, b: [8]u8) void {
            const m = mem.readIntLittle(u64, b[0..8]);
            self.v3 ^= m;

            // TODO this is a workaround, should be able to supply the value without a separate variable
            const inl = std.builtin.CallOptions{ .modifier = .always_inline };
            comptime var i: usize = 0;
            inline while (i < c_rounds) : (i += 1) {
                @call(inl, sipRound, .{self});
            }

            self.v0 ^= m;
        }

        fn sipRound(d: *Self) void {
            d.v0 +%= d.v1;
            d.v1 = math.rotl(u64, d.v1, @as(u64, 13));
            d.v1 ^= d.v0;
            d.v0 = math.rotl(u64, d.v0, @as(u64, 32));
            d.v2 +%= d.v3;
            d.v3 = math.rotl(u64, d.v3, @as(u64, 16));
            d.v3 ^= d.v2;
            d.v0 +%= d.v3;
            d.v3 = math.rotl(u64, d.v3, @as(u64, 21));
            d.v3 ^= d.v0;
            d.v2 +%= d.v1;
            d.v1 = math.rotl(u64, d.v1, @as(u64, 17));
            d.v1 ^= d.v2;
            d.v2 = math.rotl(u64, d.v2, @as(u64, 32));
        }

        pub fn hash(msg: []const u8, key: *const [key_length]u8) T {
            const aligned_len = msg.len - (msg.len % 8);
            var c = Self.init(key);
            @call(.{ .modifier = .always_inline }, c.update, .{msg[0..aligned_len]});
            return @call(.{ .modifier = .always_inline }, c.final, .{msg[aligned_len..]});
        }
    };
}

fn SipHash(comptime T: type, comptime c_rounds: usize, comptime d_rounds: usize) type {
    assert(T == u64 or T == u128);
    assert(c_rounds > 0 and d_rounds > 0);

    return struct {
        const State = SipHashStateless(T, c_rounds, d_rounds);
        const Self = @This();
        pub const key_length = 16;
        pub const mac_length = @sizeOf(T);
        pub const block_length = 8;

        state: State,
        buf: [8]u8,
        buf_len: usize,

        /// Initialize a state for a SipHash function
        pub fn init(key: *const [key_length]u8) Self {
            return Self{
                .state = State.init(key),
                .buf = undefined,
                .buf_len = 0,
            };
        }

        /// Add data to the state
        pub fn update(self: *Self, b: []const u8) void {
            var off: usize = 0;

            if (self.buf_len != 0 and self.buf_len + b.len >= 8) {
                off += 8 - self.buf_len;
                mem.copy(u8, self.buf[self.buf_len..], b[0..off]);
                self.state.update(self.buf[0..]);
                self.buf_len = 0;
            }

            const remain_len = b.len - off;
            const aligned_len = remain_len - (remain_len % 8);
            self.state.update(b[off .. off + aligned_len]);

            mem.copy(u8, self.buf[self.buf_len..], b[off + aligned_len ..]);
            self.buf_len += @intCast(u8, b[off + aligned_len ..].len);
        }

        /// Return an authentication tag for the current state
        /// Assumes `out` is less than or equal to `mac_length`.
        pub fn final(self: *Self, out: *[mac_length]u8) void {
            mem.writeIntLittle(T, out, self.state.final(self.buf[0..self.buf_len]));
        }

        /// Return an authentication tag for a message and a key
        pub fn create(out: *[mac_length]u8, msg: []const u8, key: *const [key_length]u8) void {
            var ctx = Self.init(key);
            ctx.update(msg);
            ctx.final(out);
        }

        /// Return an authentication tag for the current state, as an integer
        pub fn finalInt(self: *Self) T {
            return self.state.final(self.buf[0..self.buf_len]);
        }

        /// Return an authentication tag for a message and a key, as an integer
        pub fn toInt(msg: []const u8, key: *const [key_length]u8) T {
            return State.hash(msg, key);
        }
    };
}

// Test vectors from reference implementation.
// https://github.com/veorq/SipHash/blob/master/vectors.h
const test_key = "\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f";

test "siphash64-2-4 sanity" {
    const vectors = [_][8]u8{
        "\x31\x0e\x0e\xdd\x47\xdb\x6f\x72".*, // ""
        "\xfd\x67\xdc\x93\xc5\x39\xf8\x74".*, // "\x00"
        "\x5a\x4f\xa9\xd9\x09\x80\x6c\x0d".*, // "\x00\x01" ... etc
        "\x2d\x7e\xfb\xd7\x96\x66\x67\x85".*,
        "\xb7\x87\x71\x27\xe0\x94\x27\xcf".*,
        "\x8d\xa6\x99\xcd\x64\x55\x76\x18".*,
        "\xce\xe3\xfe\x58\x6e\x46\xc9\xcb".*,
        "\x37\xd1\x01\x8b\xf5\x00\x02\xab".*,
        "\x62\x24\x93\x9a\x79\xf5\xf5\x93".*,
        "\xb0\xe4\xa9\x0b\xdf\x82\x00\x9e".*,
        "\xf3\xb9\xdd\x94\xc5\xbb\x5d\x7a".*,
        "\xa7\xad\x6b\x22\x46\x2f\xb3\xf4".*,
        "\xfb\xe5\x0e\x86\xbc\x8f\x1e\x75".*,
        "\x90\x3d\x84\xc0\x27\x56\xea\x14".*,
        "\xee\xf2\x7a\x8e\x90\xca\x23\xf7".*,
        "\xe5\x45\xbe\x49\x61\xca\x29\xa1".*,
        "\xdb\x9b\xc2\x57\x7f\xcc\x2a\x3f".*,
        "\x94\x47\xbe\x2c\xf5\xe9\x9a\x69".*,
        "\x9c\xd3\x8d\x96\xf0\xb3\xc1\x4b".*,
        "\xbd\x61\x79\xa7\x1d\xc9\x6d\xbb".*,
        "\x98\xee\xa2\x1a\xf2\x5c\xd6\xbe".*,
        "\xc7\x67\x3b\x2e\xb0\xcb\xf2\xd0".*,
        "\x88\x3e\xa3\xe3\x95\x67\x53\x93".*,
        "\xc8\xce\x5c\xcd\x8c\x03\x0c\xa8".*,
        "\x94\xaf\x49\xf6\xc6\x50\xad\xb8".*,
        "\xea\xb8\x85\x8a\xde\x92\xe1\xbc".*,
        "\xf3\x15\xbb\x5b\xb8\x35\xd8\x17".*,
        "\xad\xcf\x6b\x07\x63\x61\x2e\x2f".*,
        "\xa5\xc9\x1d\xa7\xac\xaa\x4d\xde".*,
        "\x71\x65\x95\x87\x66\x50\xa2\xa6".*,
        "\x28\xef\x49\x5c\x53\xa3\x87\xad".*,
        "\x42\xc3\x41\xd8\xfa\x92\xd8\x32".*,
        "\xce\x7c\xf2\x72\x2f\x51\x27\x71".*,
        "\xe3\x78\x59\xf9\x46\x23\xf3\xa7".*,
        "\x38\x12\x05\xbb\x1a\xb0\xe0\x12".*,
        "\xae\x97\xa1\x0f\xd4\x34\xe0\x15".*,
        "\xb4\xa3\x15\x08\xbe\xff\x4d\x31".*,
        "\x81\x39\x62\x29\xf0\x90\x79\x02".*,
        "\x4d\x0c\xf4\x9e\xe5\xd4\xdc\xca".*,
        "\x5c\x73\x33\x6a\x76\xd8\xbf\x9a".*,
        "\xd0\xa7\x04\x53\x6b\xa9\x3e\x0e".*,
        "\x92\x59\x58\xfc\xd6\x42\x0c\xad".*,
        "\xa9\x15\xc2\x9b\xc8\x06\x73\x18".*,
        "\x95\x2b\x79\xf3\xbc\x0a\xa6\xd4".*,
        "\xf2\x1d\xf2\xe4\x1d\x45\x35\xf9".*,
        "\x87\x57\x75\x19\x04\x8f\x53\xa9".*,
        "\x10\xa5\x6c\xf5\xdf\xcd\x9a\xdb".*,
        "\xeb\x75\x09\x5c\xcd\x98\x6c\xd0".*,
        "\x51\xa9\xcb\x9e\xcb\xa3\x12\xe6".*,
        "\x96\xaf\xad\xfc\x2c\xe6\x66\xc7".*,
        "\x72\xfe\x52\x97\x5a\x43\x64\xee".*,
        "\x5a\x16\x45\xb2\x76\xd5\x92\xa1".*,
        "\xb2\x74\xcb\x8e\xbf\x87\x87\x0a".*,
        "\x6f\x9b\xb4\x20\x3d\xe7\xb3\x81".*,
        "\xea\xec\xb2\xa3\x0b\x22\xa8\x7f".*,
        "\x99\x24\xa4\x3c\xc1\x31\x57\x24".*,
        "\xbd\x83\x8d\x3a\xaf\xbf\x8d\xb7".*,
        "\x0b\x1a\x2a\x32\x65\xd5\x1a\xea".*,
        "\x13\x50\x79\xa3\x23\x1c\xe6\x60".*,
        "\x93\x2b\x28\x46\xe4\xd7\x06\x66".*,
        "\xe1\x91\x5f\x5c\xb1\xec\xa4\x6c".*,
        "\xf3\x25\x96\x5c\xa1\x6d\x62\x9f".*,
        "\x57\x5f\xf2\x8e\x60\x38\x1b\xe5".*,
        "\x72\x45\x06\xeb\x4c\x32\x8a\x95".*,
    };

    const siphash = SipHash64(2, 4);

    var buffer: [64]u8 = undefined;
    for (vectors) |vector, i| {
        buffer[i] = @intCast(u8, i);

        var out: [siphash.mac_length]u8 = undefined;
        siphash.create(&out, buffer[0..i], test_key);
        testing.expectEqual(out, vector);
    }
}

test "siphash128-2-4 sanity" {
    const vectors = [_][16]u8{
        "\xa3\x81\x7f\x04\xba\x25\xa8\xe6\x6d\xf6\x72\x14\xc7\x55\x02\x93".*,
        "\xda\x87\xc1\xd8\x6b\x99\xaf\x44\x34\x76\x59\x11\x9b\x22\xfc\x45".*,
        "\x81\x77\x22\x8d\xa4\xa4\x5d\xc7\xfc\xa3\x8b\xde\xf6\x0a\xff\xe4".*,
        "\x9c\x70\xb6\x0c\x52\x67\xa9\x4e\x5f\x33\xb6\xb0\x29\x85\xed\x51".*,
        "\xf8\x81\x64\xc1\x2d\x9c\x8f\xaf\x7d\x0f\x6e\x7c\x7b\xcd\x55\x79".*,
        "\x13\x68\x87\x59\x80\x77\x6f\x88\x54\x52\x7a\x07\x69\x0e\x96\x27".*,
        "\x14\xee\xca\x33\x8b\x20\x86\x13\x48\x5e\xa0\x30\x8f\xd7\xa1\x5e".*,
        "\xa1\xf1\xeb\xbe\xd8\xdb\xc1\x53\xc0\xb8\x4a\xa6\x1f\xf0\x82\x39".*,
        "\x3b\x62\xa9\xba\x62\x58\xf5\x61\x0f\x83\xe2\x64\xf3\x14\x97\xb4".*,
        "\x26\x44\x99\x06\x0a\xd9\xba\xab\xc4\x7f\x8b\x02\xbb\x6d\x71\xed".*,
        "\x00\x11\x0d\xc3\x78\x14\x69\x56\xc9\x54\x47\xd3\xf3\xd0\xfb\xba".*,
        "\x01\x51\xc5\x68\x38\x6b\x66\x77\xa2\xb4\xdc\x6f\x81\xe5\xdc\x18".*,
        "\xd6\x26\xb2\x66\x90\x5e\xf3\x58\x82\x63\x4d\xf6\x85\x32\xc1\x25".*,
        "\x98\x69\xe2\x47\xe9\xc0\x8b\x10\xd0\x29\x93\x4f\xc4\xb9\x52\xf7".*,
        "\x31\xfc\xef\xac\x66\xd7\xde\x9c\x7e\xc7\x48\x5f\xe4\x49\x49\x02".*,
        "\x54\x93\xe9\x99\x33\xb0\xa8\x11\x7e\x08\xec\x0f\x97\xcf\xc3\xd9".*,
        "\x6e\xe2\xa4\xca\x67\xb0\x54\xbb\xfd\x33\x15\xbf\x85\x23\x05\x77".*,
        "\x47\x3d\x06\xe8\x73\x8d\xb8\x98\x54\xc0\x66\xc4\x7a\xe4\x77\x40".*,
        "\xa4\x26\xe5\xe4\x23\xbf\x48\x85\x29\x4d\xa4\x81\xfe\xae\xf7\x23".*,
        "\x78\x01\x77\x31\xcf\x65\xfa\xb0\x74\xd5\x20\x89\x52\x51\x2e\xb1".*,
        "\x9e\x25\xfc\x83\x3f\x22\x90\x73\x3e\x93\x44\xa5\xe8\x38\x39\xeb".*,
        "\x56\x8e\x49\x5a\xbe\x52\x5a\x21\x8a\x22\x14\xcd\x3e\x07\x1d\x12".*,
        "\x4a\x29\xb5\x45\x52\xd1\x6b\x9a\x46\x9c\x10\x52\x8e\xff\x0a\xae".*,
        "\xc9\xd1\x84\xdd\xd5\xa9\xf5\xe0\xcf\x8c\xe2\x9a\x9a\xbf\x69\x1c".*,
        "\x2d\xb4\x79\xae\x78\xbd\x50\xd8\x88\x2a\x8a\x17\x8a\x61\x32\xad".*,
        "\x8e\xce\x5f\x04\x2d\x5e\x44\x7b\x50\x51\xb9\xea\xcb\x8d\x8f\x6f".*,
        "\x9c\x0b\x53\xb4\xb3\xc3\x07\xe8\x7e\xae\xe0\x86\x78\x14\x1f\x66".*,
        "\xab\xf2\x48\xaf\x69\xa6\xea\xe4\xbf\xd3\xeb\x2f\x12\x9e\xeb\x94".*,
        "\x06\x64\xda\x16\x68\x57\x4b\x88\xb9\x35\xf3\x02\x73\x58\xae\xf4".*,
        "\xaa\x4b\x9d\xc4\xbf\x33\x7d\xe9\x0c\xd4\xfd\x3c\x46\x7c\x6a\xb7".*,
        "\xea\x5c\x7f\x47\x1f\xaf\x6b\xde\x2b\x1a\xd7\xd4\x68\x6d\x22\x87".*,
        "\x29\x39\xb0\x18\x32\x23\xfa\xfc\x17\x23\xde\x4f\x52\xc4\x3d\x35".*,
        "\x7c\x39\x56\xca\x5e\xea\xfc\x3e\x36\x3e\x9d\x55\x65\x46\xeb\x68".*,
        "\x77\xc6\x07\x71\x46\xf0\x1c\x32\xb6\xb6\x9d\x5f\x4e\xa9\xff\xcf".*,
        "\x37\xa6\x98\x6c\xb8\x84\x7e\xdf\x09\x25\xf0\xf1\x30\x9b\x54\xde".*,
        "\xa7\x05\xf0\xe6\x9d\xa9\xa8\xf9\x07\x24\x1a\x2e\x92\x3c\x8c\xc8".*,
        "\x3d\xc4\x7d\x1f\x29\xc4\x48\x46\x1e\x9e\x76\xed\x90\x4f\x67\x11".*,
        "\x0d\x62\xbf\x01\xe6\xfc\x0e\x1a\x0d\x3c\x47\x51\xc5\xd3\x69\x2b".*,
        "\x8c\x03\x46\x8b\xca\x7c\x66\x9e\xe4\xfd\x5e\x08\x4b\xbe\xe7\xb5".*,
        "\x52\x8a\x5b\xb9\x3b\xaf\x2c\x9c\x44\x73\xcc\xe5\xd0\xd2\x2b\xd9".*,
        "\xdf\x6a\x30\x1e\x95\xc9\x5d\xad\x97\xae\x0c\xc8\xc6\x91\x3b\xd8".*,
        "\x80\x11\x89\x90\x2c\x85\x7f\x39\xe7\x35\x91\x28\x5e\x70\xb6\xdb".*,
        "\xe6\x17\x34\x6a\xc9\xc2\x31\xbb\x36\x50\xae\x34\xcc\xca\x0c\x5b".*,
        "\x27\xd9\x34\x37\xef\xb7\x21\xaa\x40\x18\x21\xdc\xec\x5a\xdf\x89".*,
        "\x89\x23\x7d\x9d\xed\x9c\x5e\x78\xd8\xb1\xc9\xb1\x66\xcc\x73\x42".*,
        "\x4a\x6d\x80\x91\xbf\x5e\x7d\x65\x11\x89\xfa\x94\xa2\x50\xb1\x4c".*,
        "\x0e\x33\xf9\x60\x55\xe7\xae\x89\x3f\xfc\x0e\x3d\xcf\x49\x29\x02".*,
        "\xe6\x1c\x43\x2b\x72\x0b\x19\xd1\x8e\xc8\xd8\x4b\xdc\x63\x15\x1b".*,
        "\xf7\xe5\xae\xf5\x49\xf7\x82\xcf\x37\x90\x55\xa6\x08\x26\x9b\x16".*,
        "\x43\x8d\x03\x0f\xd0\xb7\xa5\x4f\xa8\x37\xf2\xad\x20\x1a\x64\x03".*,
        "\xa5\x90\xd3\xee\x4f\xbf\x04\xe3\x24\x7e\x0d\x27\xf2\x86\x42\x3f".*,
        "\x5f\xe2\xc1\xa1\x72\xfe\x93\xc4\xb1\x5c\xd3\x7c\xae\xf9\xf5\x38".*,
        "\x2c\x97\x32\x5c\xbd\x06\xb3\x6e\xb2\x13\x3d\xd0\x8b\x3a\x01\x7c".*,
        "\x92\xc8\x14\x22\x7a\x6b\xca\x94\x9f\xf0\x65\x9f\x00\x2a\xd3\x9e".*,
        "\xdc\xe8\x50\x11\x0b\xd8\x32\x8c\xfb\xd5\x08\x41\xd6\x91\x1d\x87".*,
        "\x67\xf1\x49\x84\xc7\xda\x79\x12\x48\xe3\x2b\xb5\x92\x25\x83\xda".*,
        "\x19\x38\xf2\xcf\x72\xd5\x4e\xe9\x7e\x94\x16\x6f\xa9\x1d\x2a\x36".*,
        "\x74\x48\x1e\x96\x46\xed\x49\xfe\x0f\x62\x24\x30\x16\x04\x69\x8e".*,
        "\x57\xfc\xa5\xde\x98\xa9\xd6\xd8\x00\x64\x38\xd0\x58\x3d\x8a\x1d".*,
        "\x9f\xec\xde\x1c\xef\xdc\x1c\xbe\xd4\x76\x36\x74\xd9\x57\x53\x59".*,
        "\xe3\x04\x0c\x00\xeb\x28\xf1\x53\x66\xca\x73\xcb\xd8\x72\xe7\x40".*,
        "\x76\x97\x00\x9a\x6a\x83\x1d\xfe\xcc\xa9\x1c\x59\x93\x67\x0f\x7a".*,
        "\x58\x53\x54\x23\x21\xf5\x67\xa0\x05\xd5\x47\xa4\xf0\x47\x59\xbd".*,
        "\x51\x50\xd1\x77\x2f\x50\x83\x4a\x50\x3e\x06\x9a\x97\x3f\xbd\x7c".*,
    };

    const siphash = SipHash128(2, 4);

    var buffer: [64]u8 = undefined;
    for (vectors) |vector, i| {
        buffer[i] = @intCast(u8, i);

        var out: [siphash.mac_length]u8 = undefined;
        siphash.create(&out, buffer[0..i], test_key[0..]);
        testing.expectEqual(out, vector);
    }
}

test "iterative non-divisible update" {
    var buf: [1024]u8 = undefined;
    for (buf) |*e, i| {
        e.* = @truncate(u8, i);
    }

    const key = "0x128dad08f12307";
    const Siphash = SipHash64(2, 4);

    var end: usize = 9;
    while (end < buf.len) : (end += 9) {
        const non_iterative_hash = Siphash.toInt(buf[0..end], key[0..]);

        var siphash = Siphash.init(key);
        var i: usize = 0;
        while (i < end) : (i += 7) {
            siphash.update(buf[i..std.math.min(i + 7, end)]);
        }
        const iterative_hash = siphash.finalInt();

        std.testing.expectEqual(iterative_hash, non_iterative_hash);
    }
}
