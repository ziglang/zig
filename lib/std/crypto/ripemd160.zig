// https://homes.esat.kuleuven.be/~bosselae/ripemd160.html

const std = @import("std");

pub const Ripemd160 = struct {
    bytes: [160 / 8]u8,

    pub fn hash(str: []const u8) Ripemd160 {
        var res: Ripemd160 = undefined;
        var temp: [5]u32 = .{ 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0 };
        var ptr = str.ptr;

        { // compress string in 16-word chunks
            var i = str.len / 64;
            while (i > 0) : (i -= 1) {
                var chunk: [16]u32 = [_]u32{0} ** 16;
                var j: usize = 0;
                while (j < 16) : (j += 1) {
                    chunk[j] = std.mem.readIntLittle(u32, ptr[0..4]);
                    ptr += 4;
                }
                compress(&temp, chunk);
            }
        }

        { // compress remaining string, (str.len % 64) bytes
            var chunk: [16]u32 = [_]u32{0} ** 16;
            var i: usize = 0;
            while (i < (str.len & 63)) : (i += 1) {
                chunk[i >> 2] ^= (@intCast(u32, ptr[0]) << @intCast(u5, 8 * (i & 3)));
                ptr += 1;
            }

            chunk[(str.len >> 2) & 15] ^= @as(u32, 1) << @intCast(u5, 8 * (str.len & 3) + 7);

            if ((str.len & 63) > 55) {
                compress(&temp, chunk);
                chunk = [_]u32{0} ** 16;
            }

            chunk[14] = @intCast(u32, str.len << 3);
            chunk[15] = @intCast(u32, (str.len >> 29) | (0 << 3));
            compress(&temp, chunk);
        }

        { // write final hash
            var i: usize = 0;
            while (i < 160 / 8) : (i += 4) {
                std.mem.writeIntLittle(u32, @ptrCast(*[4]u8, &res.bytes[i]), temp[i >> 2]);
            }
        }

        return res;
    }
};

fn compress(hash: *[5]u32, words: [16]u32) void {
    const permutations: [10][16]u5 = .{
        .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
        .{ 7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8 },
        .{ 3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12 },
        .{ 1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2 },
        .{ 4, 0, 5, 9, 7, 12, 2, 10, 14, 1, 3, 8, 11, 6, 15, 13 },
        .{ 5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12 },
        .{ 6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2 },
        .{ 15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13 },
        .{ 8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14 },
        .{ 12, 15, 10, 4, 1, 5, 8, 7, 6, 2, 13, 14, 0, 3, 9, 11 },
    };

    const shifts: [10][16]u5 = .{
        .{ 11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8 },
        .{ 7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12 },
        .{ 11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5 },
        .{ 11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12 },
        .{ 9, 15, 5, 11, 6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6 },
        .{ 8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6 },
        .{ 9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11 },
        .{ 9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5 },
        .{ 15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8 },
        .{ 8, 5, 12, 9, 12, 5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11 },
    };

    var left: [5]u32 = undefined;
    var right: [5]u32 = undefined;
    std.mem.copy(u32, left[0..], hash[0..5]);
    std.mem.copy(u32, right[0..], hash[0..5]);

    round(bfn1, -0, 0x00000000, permutations[0], shifts[0], &left, words);
    round(bfn2, -1, 0x5a827999, permutations[1], shifts[1], &left, words);
    round(bfn3, -2, 0x6ed9eba1, permutations[2], shifts[2], &left, words);
    round(bfn4, -3, 0x8f1bbcdc, permutations[3], shifts[3], &left, words);
    round(bfn5, -4, 0xa953fd4e, permutations[4], shifts[4], &left, words);

    round(bfn5, -0, 0x50a28be6, permutations[5], shifts[5], &right, words);
    round(bfn4, -1, 0x5c4dd124, permutations[6], shifts[6], &right, words);
    round(bfn3, -2, 0x6d703ef3, permutations[7], shifts[7], &right, words);
    round(bfn2, -3, 0x7a6d76e9, permutations[8], shifts[8], &right, words);
    round(bfn1, -4, 0x00000000, permutations[9], shifts[9], &right, words);

    right[3] = right[3] +% left[2] +% hash[1];
    hash[1] = hash[2] +% left[3] +% right[4];
    hash[2] = hash[3] +% left[4] +% right[0];
    hash[3] = hash[4] +% left[0] +% right[1];
    hash[4] = hash[0] +% left[1] +% right[2];
    hash[0] = right[3];
}

fn round(
    comptime bfn: fn (u32, u32, u32) u32,
    comptime off: i32,
    comptime constant: u32,
    comptime p: [16]u5,
    comptime shifts: [16]u5,
    hash: *[5]u32,
    words: [16]u32,
) void {
    comptime var r = off;
    comptime var i: usize = 0;
    inline while (i < 16) : (i += 1) {
        hash[@mod(r + 0, 5)] = hash[@mod(r + 0, 5)] +% bfn(hash[@mod(r + 1, 5)], hash[@mod(r + 2, 5)], hash[@mod(r + 3, 5)]) +% words[p[i]] +% constant;
        hash[@mod(r + 0, 5)] = std.math.rotl(u32, hash[@mod(r + 0, 5)], @intCast(u32, shifts[i])) +% hash[@mod(r + 4, 5)];
        hash[@mod(r + 2, 5)] = std.math.rotl(u32, hash[@mod(r + 2, 5)], 10);
        r -= 1;
    }
}

fn bfn1(x: u32, y: u32, z: u32) u32 {
    return x ^ y ^ z;
}

fn bfn2(x: u32, y: u32, z: u32) u32 {
    return (x & y) | (~x & z);
}

fn bfn3(x: u32, y: u32, z: u32) u32 {
    return (x | ~y) ^ z;
}

fn bfn4(x: u32, y: u32, z: u32) u32 {
    return (x & z) | (y & ~z);
}

fn bfn5(x: u32, y: u32, z: u32) u32 {
    return x ^ (y | ~z);
}

fn testHashEql(expected: []const u8, in: []const u8) !void {
    const hash = Ripemd160.hash(in);
    var hex_str: [40]u8 = undefined;
    _ = try std.fmt.bufPrint(&hex_str, "{x}", .{std.fmt.fmtSliceHexLower(hash.bytes[0..])});
    try std.testing.expectEqualSlices(u8, expected, hex_str[0..]);
}

test "RIPEMD-160 standard tests" {
    try testHashEql("9c1185a5c5e9fc54612808977ee8f548b2258d31", "");
    try testHashEql("0bdc9d2d256b3ee9daae347be6f4dc835a467ffe", "a");
    try testHashEql("8eb208f7e05d987a9b044a8e98c6b087f15a0bfc", "abc");
    try testHashEql("5d0689ef49d2fae572b881b123a85ffa21595f36", "message digest");
    try testHashEql("f71c27109c692c1b56bbdceb5b9d2865b3708dbc", "abcdefghijklmnopqrstuvwxyz");
    try testHashEql("12a053384a9c0c88e405a06c27dcf49ada62eb2b", "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq");
    try testHashEql("b0e20b6e3116640286ed3a87a5713079b21f5189", "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789");
    try testHashEql("9b752e45573d4b39f4dbd3323cab82bf63326bfb", "1234567890" ** 8);
    try testHashEql("52783243c1697bdbe16d37f97f68f08325dc1528", "a" ** 1000000);
}
