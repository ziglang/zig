//! Xoodoo is a 384-bit permutation designed to achieve high security with high
//! performance across a broad range of platforms, including 64-bit Intel/AMD
//! server CPUs, 64-bit and 32-bit ARM smartphone CPUs, 32-bit ARM
//! microcontrollers, 8-bit AVR microcontrollers, FPGAs, ASICs without
//! side-channel protection, and ASICs with side-channel protection.
//!
//! Xoodoo is the core function of Xoodyak, a finalist of the NIST lightweight cryptography competition.
//! https://csrc.nist.gov/CSRC/media/Projects/Lightweight-Cryptography/documents/round-1/spec-doc/Xoodyak-spec.pdf
//!
//! It is not meant to be used directly, but as a building block for symmetric cryptography.

const std = @import("../std.zig");
const builtin = @import("builtin");
const mem = std.mem;
const math = std.math;
const testing = std.testing;

/// A Xoodoo state.
pub const State = struct {
    /// Number of bytes in the state.
    pub const block_bytes = 48;

    const rcs = [12]u32{ 0x058, 0x038, 0x3c0, 0x0d0, 0x120, 0x014, 0x060, 0x02c, 0x380, 0x0f0, 0x1a0, 0x012 };
    const Lane = @Vector(4, u32);
    st: [3]Lane,

    /// Initialize a state from a slice of bytes.
    pub fn init(initial_state: [block_bytes]u8) State {
        var state = State{ .st = undefined };
        mem.copy(u8, state.asBytes(), &initial_state);
        state.endianSwap();
        return state;
    }

    // A representation of the state as 32-bit words.
    fn asWords(self: *State) *[12]u32 {
        return @ptrCast(*[12]u32, &self.st);
    }

    /// A representation of the state as bytes. The byte order is architecture-dependent.
    pub fn asBytes(self: *State) *[block_bytes]u8 {
        return mem.asBytes(&self.st);
    }

    /// Byte-swap words storing the bytes of a given range if the architecture is not little-endian.
    pub fn endianSwapPartial(self: *State, from: usize, to: usize) void {
        for (self.asWords()[from / 4 .. (to + 3) / 4]) |*w| {
            w.* = mem.littleToNative(u32, w.*);
        }
    }

    /// Byte-swap the entire state if the architecture is not little-endian.
    pub fn endianSwap(self: *State) void {
        for (self.asWords()) |*w| {
            w.* = mem.littleToNative(u32, w.*);
        }
    }

    /// XOR a byte into the state at a given offset.
    pub fn addByte(self: *State, byte: u8, offset: usize) void {
        self.endianSwapPartial(offset, offset);
        self.asBytes()[offset] ^= byte;
        self.endianSwapPartial(offset, offset);
    }

    /// XOR bytes into the beginning of the state.
    pub fn addBytes(self: *State, bytes: []const u8) void {
        self.endianSwap();
        for (self.asBytes()[0..bytes.len], 0..) |*byte, i| {
            byte.* ^= bytes[i];
        }
        self.endianSwap();
    }

    /// Extract the first bytes of the state.
    pub fn extract(self: *State, out: []u8) void {
        self.endianSwap();
        mem.copy(u8, out, self.asBytes()[0..out.len]);
        self.endianSwap();
    }

    /// Set the words storing the bytes of a given range to zero.
    pub fn clear(self: *State, from: usize, to: usize) void {
        mem.set(u32, self.asWords()[from / 4 .. (to + 3) / 4], 0);
    }

    /// Apply the Xoodoo permutation.
    pub fn permute(self: *State) void {
        const rot8x32 = comptime if (builtin.target.cpu.arch.endian() == .Big)
            [_]i32{ 9, 10, 11, 8, 13, 14, 15, 12, 1, 2, 3, 0, 5, 6, 7, 4 }
        else
            [_]i32{ 11, 8, 9, 10, 15, 12, 13, 14, 3, 0, 1, 2, 7, 4, 5, 6 };

        var a = self.st[0];
        var b = self.st[1];
        var c = self.st[2];
        inline for (rcs) |rc| {
            var p = @shuffle(u32, a ^ b ^ c, undefined, [_]i32{ 3, 0, 1, 2 });
            var e = math.rotl(Lane, p, 5);
            p = math.rotl(Lane, p, 14);
            e ^= p;
            a ^= e;
            b ^= e;
            c ^= e;
            b = @shuffle(u32, b, undefined, [_]i32{ 3, 0, 1, 2 });
            c = math.rotl(Lane, c, 11);
            a[0] ^= rc;
            a ^= ~b & c;
            b ^= ~c & a;
            c ^= ~a & b;
            b = math.rotl(Lane, b, 1);
            c = @bitCast(Lane, @shuffle(u8, @bitCast(@Vector(16, u8), c), undefined, rot8x32));
        }
        self.st[0] = a;
        self.st[1] = b;
        self.st[2] = c;
    }
};

test "xoodoo" {
    const bytes = [_]u8{0x01} ** State.block_bytes;
    var st = State.init(bytes);
    var out: [State.block_bytes]u8 = undefined;
    st.permute();
    st.extract(&out);
    const expected1 = [_]u8{ 51, 240, 163, 117, 43, 238, 62, 200, 114, 52, 79, 41, 48, 108, 150, 181, 24, 5, 252, 185, 235, 179, 28, 3, 116, 170, 36, 15, 232, 35, 116, 61, 110, 4, 109, 227, 91, 205, 0, 180, 179, 146, 112, 235, 96, 212, 206, 205 };
    try testing.expectEqualSlices(u8, &expected1, &out);
    st.clear(0, 10);
    st.extract(&out);
    const expected2 = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 48, 108, 150, 181, 24, 5, 252, 185, 235, 179, 28, 3, 116, 170, 36, 15, 232, 35, 116, 61, 110, 4, 109, 227, 91, 205, 0, 180, 179, 146, 112, 235, 96, 212, 206, 205 };
    try testing.expectEqualSlices(u8, &expected2, &out);
    st.addByte(1, 5);
    st.addByte(2, 5);
    st.extract(&out);
    const expected3 = [_]u8{ 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 48, 108, 150, 181, 24, 5, 252, 185, 235, 179, 28, 3, 116, 170, 36, 15, 232, 35, 116, 61, 110, 4, 109, 227, 91, 205, 0, 180, 179, 146, 112, 235, 96, 212, 206, 205 };
    try testing.expectEqualSlices(u8, &expected3, &out);
    st.addBytes(&bytes);
    st.extract(&out);
    const expected4 = [_]u8{ 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 49, 109, 151, 180, 25, 4, 253, 184, 234, 178, 29, 2, 117, 171, 37, 14, 233, 34, 117, 60, 111, 5, 108, 226, 90, 204, 1, 181, 178, 147, 113, 234, 97, 213, 207, 204 };
    try testing.expectEqualSlices(u8, &expected4, &out);
}
