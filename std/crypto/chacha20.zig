// Based on public domain Supercop by Daniel J. Bernstein

const mem = @import("../mem.zig");
const endian = @import("../endian.zig");
const builtin = @import("builtin");

const QuarterRound = struct {
    a: usize,
    b: usize,
    c: usize,
    d: usize,
};

fn Rp(a: usize, b: usize, c: usize, d: usize) QuarterRound {
    return QuarterRound{
        .a = a,
        .b = b,
        .c = c,
        .d = d,
    };
}

fn rotate(a: u32, b: u5) u32 {
    return ((a << b) |
            (a >> @intCast(u5, (32 - @intCast(u6, b))))
           );
}

fn salsa20_wordtobyte(input: [16]u32) [64]u8 {
    var x: [16]u32 = undefined;
    var out: [64]u8 = undefined;

    for (x) |_, i|
        x[i] = input[i];
    const rounds = comptime []QuarterRound{
        Rp( 0, 4, 8,12),
        Rp( 1, 5, 9,13),
        Rp( 2, 6,10,14),
        Rp( 3, 7,11,15),
        Rp( 0, 5,10,15),
        Rp( 1, 6,11,12),
        Rp( 2, 7, 8,13),
        Rp( 3, 4, 9,14),
    };
    comptime var j: usize = 20;
    inline while (j > 0) : (j -=2) {
        for (rounds) |r| {
            x[r.a] +%= x[r.b]; x[r.d] = rotate(x[r.d] ^ x[r.a], 16);
            x[r.c] +%= x[r.d]; x[r.b] = rotate(x[r.b] ^ x[r.c], 12);
            x[r.a] +%= x[r.b]; x[r.d] = rotate(x[r.d] ^ x[r.a],  8);
            x[r.c] +%= x[r.d]; x[r.b] = rotate(x[r.b] ^ x[r.c],  7);
        }
    }
    for (x) |_, i|
        x[i] +%= input[i];
    for (x) |_, i|
        mem.writeInt(out[4 * i .. 4 * i + 4], x[i], builtin.Endian.Little);
    return out;
}

pub fn chaCha20(in: []const u8, key: [8]u32, nonce: [8]u8, out: *[]u8) void {
    var ctx: [16]u32 = undefined;
    var remaining: usize = undefined;
    var cursor: usize = 0;

    //if (in.len > out.len) {
    //    remaining = out.len;
    //} else
        remaining = in.len;

    comptime const c = "expand 32-byte k";
    comptime const constant_le = []u32{
        // TODO more zig way of doing this
        @intCast(u32, c[ 0]) | @intCast(u32, c[ 1]) << 8 | @intCast(u32, c[ 2]) << 16 | @intCast(u32, c[ 3]) << 24,
        @intCast(u32, c[ 4]) | @intCast(u32, c[ 5]) << 8 | @intCast(u32, c[ 6]) << 16 | @intCast(u32, c[ 7]) << 24,
        @intCast(u32, c[ 8]) | @intCast(u32, c[ 9]) << 8 | @intCast(u32, c[10]) << 16 | @intCast(u32, c[11]) << 24,
        @intCast(u32, c[12]) | @intCast(u32, c[13]) << 8 | @intCast(u32, c[14]) << 16 | @intCast(u32, c[15]) << 24,
    };
    
    for (constant_le) |_, i|
        ctx[i] = constant_le[i];

    for (key) |_, i|
        ctx[4 + i] = key[i];

    ctx[12] = 0;
    ctx[13] = 0;
    // TODO more zig way of doing this
    ctx[14] = @intCast(u32, nonce[ 0]) | @intCast(u32, nonce[ 1]) << 8 | @intCast(u32, nonce[ 2]) << 16 | @intCast(u32, nonce[ 3]) << 24;
    ctx[15] = @intCast(u32, nonce[ 4]) | @intCast(u32, nonce[ 5]) << 8 | @intCast(u32, nonce[ 6]) << 16 | @intCast(u32, nonce[ 7]) << 24;

    while (true) {
        var buf = salsa20_wordtobyte(ctx);
        var count: u64 = undefined;

        if (remaining < 64) {
            var i: usize = 0;
            while (i < remaining) : (i += 1)
                out.*[cursor + i] = in[cursor + i] ^ buf[i];
            return;
        }

        comptime var i: usize = 0;
        inline while (i < 64) : (i += 1)
            out.*[cursor + i] = in[cursor + i] ^ buf[i];

        cursor += 64;
        remaining -= 64;

        count = @intCast(u64, ctx[12]) | @intCast(u64, ctx[13]) << 32;
        count += 1;
        ctx[12] = @intCast(u32, count & @maxValue(u32));
        ctx[13] = @intCast(u32, count >> 32);
    }
}

// https://tools.ietf.org/html/draft-agl-tls-chacha20poly1305-04#section-7
test "test vector" {
    const assert = @import("std").debug.assert;

    const expected_result = []u8{
        0x76, 0xb8, 0xe0, 0xad, 0xa0, 0xf1, 0x3d, 0x90,
        0x40, 0x5d, 0x6a, 0xe5, 0x53, 0x86, 0xbd, 0x28,
        0xbd, 0xd2, 0x19, 0xb8, 0xa0, 0x8d, 0xed, 0x1a,
        0xa8, 0x36, 0xef, 0xcc, 0x8b, 0x77, 0x0d, 0xc7,
        0xda, 0x41, 0x59, 0x7c, 0x51, 0x57, 0x48, 0x8d,
        0x77, 0x24, 0xe0, 0x3f, 0xb8, 0xd8, 0x4a, 0x37,
        0x6a, 0x43, 0xb8, 0xf4, 0x15, 0x18, 0xa1, 0x1c,
        0xc3, 0x87, 0xb6, 0x69, 0xb2, 0xee, 0x65, 0x86,
    };
    const input = []u8{
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };
    var result: [64]u8 = undefined;
    const key = []u32{0, 0, 0, 0, 0, 0, 0, 0};
    const nonce = []u8{0, 0, 0, 0, 0, 0, 0, 0};

    chaCha20(input[0..], key, nonce, &result[0..]);
    assert(mem.compare(u8, expected_result, result) == mem.Compare.Equal);
}
