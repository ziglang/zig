// Gimli is a 384-bit permutation designed to achieve high security with high
// performance across a broad range of platforms, including 64-bit Intel/AMD
// server CPUs, 64-bit and 32-bit ARM smartphone CPUs, 32-bit ARM
// microcontrollers, 8-bit AVR microcontrollers, FPGAs, ASICs without
// side-channel protection, and ASICs with side-channel protection.
//
// https://gimli.cr.yp.to/
// https://csrc.nist.gov/CSRC/media/Projects/Lightweight-Cryptography/documents/round-1/spec-doc/gimli-spec.pdf

const std = @import("../std.zig");
const mem = std.mem;
const math = std.math;
const debug = std.debug;
const assert = std.debug.assert;
const testing = std.testing;
const htest = @import("test.zig");

pub const State = struct {
    pub const BLOCKBYTES = 48;
    pub const RATE = 16;

    // TODO: https://github.com/ziglang/zig/issues/2673#issuecomment-501763017
    data: [BLOCKBYTES / 4]u32,

    const Self = @This();

    pub fn toSlice(self: *Self) []u8 {
        return @sliceToBytes(self.data[0..]);
    }

    pub fn toSliceConst(self: *Self) []const u8 {
        return @sliceToBytes(self.data[0..]);
    }

    pub fn permute(self: *Self) void {
        const state = &self.data;
        var round = u32(24);
        while (round > 0) : (round -= 1) {
            var column = usize(0);
            while (column < 4) : (column += 1) {
                const x = math.rotl(u32, state[column], 24);
                const y = math.rotl(u32, state[4 + column], 9);
                const z = state[8 + column];
                state[8 + column] = ((x ^ (z << 1)) ^ ((y & z) << 2));
                state[4 + column] = ((y ^ x) ^ ((x | z) << 1));
                state[column] = ((z ^ y) ^ ((x & y) << 3));
            }
            switch (round & 3) {
                0 => {
                    mem.swap(u32, &state[0], &state[1]);
                    mem.swap(u32, &state[2], &state[3]);
                    state[0] ^= round | 0x9e377900;
                },
                2 => {
                    mem.swap(u32, &state[0], &state[2]);
                    mem.swap(u32, &state[1], &state[3]);
                },
                else => {},
            }
        }
    }

    pub fn squeeze(self: *Self, out: []u8) void {
        var i = usize(0);
        while (i + RATE <= out.len) : (i += RATE) {
            self.permute();
            mem.copy(u8, out[i..], self.toSliceConst()[0..RATE]);
        }
        const leftover = out.len - i;
        if (leftover != 0) {
            self.permute();
            mem.copy(u8, out[i..], self.toSliceConst()[0..leftover]);
        }
    }
};

test "permute" {
    // test vector from gimli-20170627
    var state = State{
        .data = blk: {
            var input: [12]u32 = undefined;
            var i = u32(0);
            while (i < 12) : (i += 1) {
                input[i] = i * i * i + i *% 0x9e3779b9;
            }
            testing.expectEqualSlices(u32, input, [_]u32{
                0x00000000, 0x9e3779ba, 0x3c6ef37a, 0xdaa66d46,
                0x78dde724, 0x1715611a, 0xb54cdb2e, 0x53845566,
                0xf1bbcfc8, 0x8ff34a5a, 0x2e2ac522, 0xcc624026,
            });
            break :blk input;
        },
    };
    state.permute();
    testing.expectEqualSlices(u32, state.data, [_]u32{
        0xba11c85a, 0x91bad119, 0x380ce880, 0xd24c2c68,
        0x3eceffea, 0x277a921c, 0x4f73a0bd, 0xda5a9cd8,
        0x84b673f0, 0x34e52ff7, 0x9e2bef49, 0xf41bb8d6,
    });
}

pub const Hash = struct {
    state: State,
    buf_off: usize,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .state = State{
                .data = [_]u32{0} ** (State.BLOCKBYTES / 4),
            },
            .buf_off = 0,
        };
    }

    /// Also known as 'absorb'
    pub fn update(self: *Self, data: []const u8) void {
        const buf = self.state.toSlice();
        var in = data;
        while (in.len > 0) {
            var left = State.RATE - self.buf_off;
            if (left == 0) {
                self.state.permute();
                self.buf_off = 0;
                left = State.RATE;
            }
            const ps = math.min(in.len, left);
            for (buf[self.buf_off .. self.buf_off + ps]) |*p, i| {
                p.* ^= in[i];
            }
            self.buf_off += ps;
            in = in[ps..];
        }
    }

    /// Finish the current hashing operation, writing the hash to `out`
    ///
    /// From 4.9 "Application to hashing"
    /// By default, Gimli-Hash provides a fixed-length output of 32 bytes
    /// (the concatenation of two 16-byte blocks).  However, Gimli-Hash can
    /// be used as an “extendable one-way function” (XOF).
    pub fn final(self: *Self, out: []u8) void {
        const buf = self.state.toSlice();

        // XOR 1 into the next byte of the state
        buf[self.buf_off] ^= 1;
        // XOR 1 into the last byte of the state, position 47.
        buf[buf.len - 1] ^= 1;

        self.state.squeeze(out);
    }
};

pub fn hash(out: []u8, in: []const u8) void {
    var st = Hash.init();
    st.update(in);
    st.final(out);
}

test "hash" {
    // a test vector (30) from NIST KAT submission.
    var msg: [58 / 2]u8 = undefined;
    try std.fmt.hexToBytes(&msg, "000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C");
    var md: [32]u8 = undefined;
    hash(&md, msg);
    htest.assertEqual("1C9A03DC6A5DDC5444CFC6F4B154CFF5CF081633B2CEA4D7D0AE7CCFED5AAA44", md);
}
