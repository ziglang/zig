const assert = @import("std").debug.assert;
const builtin = @import("std").builtin;
const math = @import("std").math;
const mem = @import("std").mem;

pub const block_size: u8 = 8;

const ip = [64]u8{
    6, 14, 22, 30, 38, 46, 54, 62,
    4, 12, 20, 28, 36, 44, 52, 60,
    2, 10, 18, 26, 34, 42, 50, 58,
    0, 8,  16, 24, 32, 40, 48, 56,
    7, 15, 23, 31, 39, 47, 55, 63,
    5, 13, 21, 29, 37, 45, 53, 61,
    3, 11, 19, 27, 35, 43, 51, 59,
    1, 9,  17, 25, 33, 41, 49, 57,
};

const fp = [64]u8{
    31, 63, 23, 55, 15, 47, 7, 39,
    30, 62, 22, 54, 14, 46, 6, 38,
    29, 61, 21, 53, 13, 45, 5, 37,
    28, 60, 20, 52, 12, 44, 4, 36,
    27, 59, 19, 51, 11, 43, 3, 35,
    26, 58, 18, 50, 10, 42, 2, 34,
    25, 57, 17, 49, 9,  41, 1, 33,
    24, 56, 16, 48, 8,  40, 0, 32,
};

const pc1 = [56]u8{
    7,  15, 23, 31, 39, 47, 55, 63,
    6,  14, 22, 30, 38, 46, 54, 62,
    5,  13, 21, 29, 37, 45, 53, 61,
    4,  12, 20, 28, 1,  9,  17, 25,
    33, 41, 49, 57, 2,  10, 18, 26,
    34, 42, 50, 58, 3,  11, 19, 27,
    35, 43, 51, 59, 36, 44, 52, 60,
};

const pc2 = [48]u8{
    13, 16, 10, 23, 0,  4,  2,  27,
    14, 5,  20, 9,  22, 18, 11, 3,
    25, 7,  15, 6,  26, 19, 12, 1,
    40, 51, 30, 36, 46, 54, 29, 39,
    50, 44, 32, 47, 43, 48, 38, 55,
    33, 52, 45, 41, 49, 35, 28, 31,
};

const s0 = [_]u32{
    0x00410100, 0x00010000, 0x40400000, 0x40410100, 0x00400000, 0x40010100, 0x40010000, 0x40400000,
    0x40010100, 0x00410100, 0x00410000, 0x40000100, 0x40400100, 0x00400000, 0x00000000, 0x40010000,
    0x00010000, 0x40000000, 0x00400100, 0x00010100, 0x40410100, 0x00410000, 0x40000100, 0x00400100,
    0x40000000, 0x00000100, 0x00010100, 0x40410000, 0x00000100, 0x40400100, 0x40410000, 0x00000000,
    0x00000000, 0x40410100, 0x00400100, 0x40010000, 0x00410100, 0x00010000, 0x40000100, 0x00400100,
    0x40410000, 0x00000100, 0x00010100, 0x40400000, 0x40010100, 0x40000000, 0x40400000, 0x00410000,
    0x40410100, 0x00010100, 0x00410000, 0x40400100, 0x00400000, 0x40000100, 0x40010000, 0x00000000,
    0x00010000, 0x00400000, 0x40400100, 0x00410100, 0x40000000, 0x40410000, 0x00000100, 0x40010100,
};

const s1 = [_]u32{
    0x08021002, 0x00000000, 0x00021000, 0x08020000, 0x08000002, 0x00001002, 0x08001000, 0x00021000,
    0x00001000, 0x08020002, 0x00000002, 0x08001000, 0x00020002, 0x08021000, 0x08020000, 0x00000002,
    0x00020000, 0x08001002, 0x08020002, 0x00001000, 0x00021002, 0x08000000, 0x00000000, 0x00020002,
    0x08001002, 0x00021002, 0x08021000, 0x08000002, 0x08000000, 0x00020000, 0x00001002, 0x08021002,
    0x00020002, 0x08021000, 0x08001000, 0x00021002, 0x08021002, 0x00020002, 0x08000002, 0x00000000,
    0x08000000, 0x00001002, 0x00020000, 0x08020002, 0x00001000, 0x08000000, 0x00021002, 0x08001002,
    0x08021000, 0x00001000, 0x00000000, 0x08000002, 0x00000002, 0x08021002, 0x00021000, 0x08020000,
    0x08020002, 0x00020000, 0x00001002, 0x08001000, 0x08001002, 0x00000002, 0x08020000, 0x00021000,
};

const s2 = [_]u32{
    0x20800000, 0x00808020, 0x00000020, 0x20800020, 0x20008000, 0x00800000, 0x20800020, 0x00008020,
    0x00800020, 0x00008000, 0x00808000, 0x20000000, 0x20808020, 0x20000020, 0x20000000, 0x20808000,
    0x00000000, 0x20008000, 0x00808020, 0x00000020, 0x20000020, 0x20808020, 0x00008000, 0x20800000,
    0x20808000, 0x00800020, 0x20008020, 0x00808000, 0x00008020, 0x00000000, 0x00800000, 0x20008020,
    0x00808020, 0x00000020, 0x20000000, 0x00008000, 0x20000020, 0x20008000, 0x00808000, 0x20800020,
    0x00000000, 0x00808020, 0x00008020, 0x20808000, 0x20008000, 0x00800000, 0x20808020, 0x20000000,
    0x20008020, 0x20800000, 0x00800000, 0x20808020, 0x00008000, 0x00800020, 0x20800020, 0x00008020,
    0x00800020, 0x00000000, 0x20808000, 0x20000020, 0x20800000, 0x20008020, 0x00000020, 0x00808000,
};

const s3 = [_]u32{
    0x00080201, 0x02000200, 0x00000001, 0x02080201, 0x00000000, 0x02080000, 0x02000201, 0x00080001,
    0x02080200, 0x02000001, 0x02000000, 0x00000201, 0x02000001, 0x00080201, 0x00080000, 0x02000000,
    0x02080001, 0x00080200, 0x00000200, 0x00000001, 0x00080200, 0x02000201, 0x02080000, 0x00000200,
    0x00000201, 0x00000000, 0x00080001, 0x02080200, 0x02000200, 0x02080001, 0x02080201, 0x00080000,
    0x02080001, 0x00000201, 0x00080000, 0x02000001, 0x00080200, 0x02000200, 0x00000001, 0x02080000,
    0x02000201, 0x00000000, 0x00000200, 0x00080001, 0x00000000, 0x02080001, 0x02080200, 0x00000200,
    0x02000000, 0x02080201, 0x00080201, 0x00080000, 0x02080201, 0x00000001, 0x02000200, 0x00080201,
    0x00080001, 0x00080200, 0x02080000, 0x02000201, 0x00000201, 0x02000000, 0x02000001, 0x02080200,
};

const s4 = [_]u32{
    0x01000000, 0x00002000, 0x00000080, 0x01002084, 0x01002004, 0x01000080, 0x00002084, 0x01002000,
    0x00002000, 0x00000004, 0x01000004, 0x00002080, 0x01000084, 0x01002004, 0x01002080, 0x00000000,
    0x00002080, 0x01000000, 0x00002004, 0x00000084, 0x01000080, 0x00002084, 0x00000000, 0x01000004,
    0x00000004, 0x01000084, 0x01002084, 0x00002004, 0x01002000, 0x00000080, 0x00000084, 0x01002080,
    0x01002080, 0x01000084, 0x00002004, 0x01002000, 0x00002000, 0x00000004, 0x01000004, 0x01000080,
    0x01000000, 0x00002080, 0x01002084, 0x00000000, 0x00002084, 0x01000000, 0x00000080, 0x00002004,
    0x01000084, 0x00000080, 0x00000000, 0x01002084, 0x01002004, 0x01002080, 0x00000084, 0x00002000,
    0x00002080, 0x01002004, 0x01000080, 0x00000084, 0x00000004, 0x00002084, 0x01002000, 0x01000004,
};

const s5 = [_]u32{
    0x10000008, 0x00040008, 0x00000000, 0x10040400, 0x00040008, 0x00000400, 0x10000408, 0x00040000,
    0x00000408, 0x10040408, 0x00040400, 0x10000000, 0x10000400, 0x10000008, 0x10040000, 0x00040408,
    0x00040000, 0x10000408, 0x10040008, 0x00000000, 0x00000400, 0x00000008, 0x10040400, 0x10040008,
    0x10040408, 0x10040000, 0x10000000, 0x00000408, 0x00000008, 0x00040400, 0x00040408, 0x10000400,
    0x00000408, 0x10000000, 0x10000400, 0x00040408, 0x10040400, 0x00040008, 0x00000000, 0x10000400,
    0x10000000, 0x00000400, 0x10040008, 0x00040000, 0x00040008, 0x10040408, 0x00040400, 0x00000008,
    0x10040408, 0x00040400, 0x00040000, 0x10000408, 0x10000008, 0x10040000, 0x00040408, 0x00000000,
    0x00000400, 0x10000008, 0x10000408, 0x10040400, 0x10040000, 0x00000408, 0x00000008, 0x10040008,
};

const s6 = [_]u32{
    0x00000800, 0x00000040, 0x00200040, 0x80200000, 0x80200840, 0x80000800, 0x00000840, 0x00000000,
    0x00200000, 0x80200040, 0x80000040, 0x00200800, 0x80000000, 0x00200840, 0x00200800, 0x80000040,
    0x80200040, 0x00000800, 0x80000800, 0x80200840, 0x00000000, 0x00200040, 0x80200000, 0x00000840,
    0x80200800, 0x80000840, 0x00200840, 0x80000000, 0x80000840, 0x80200800, 0x00000040, 0x00200000,
    0x80000840, 0x00200800, 0x80200800, 0x80000040, 0x00000800, 0x00000040, 0x00200000, 0x80200800,
    0x80200040, 0x80000840, 0x00000840, 0x00000000, 0x00000040, 0x80200000, 0x80000000, 0x00200040,
    0x00000000, 0x80200040, 0x00200040, 0x00000840, 0x80000040, 0x00000800, 0x80200840, 0x00200000,
    0x00200840, 0x80000000, 0x80000800, 0x80200840, 0x80200000, 0x00200840, 0x00200800, 0x80000800,
};

const s7 = [_]u32{
    0x04100010, 0x04104000, 0x00004010, 0x00000000, 0x04004000, 0x00100010, 0x04100000, 0x04104010,
    0x00000010, 0x04000000, 0x00104000, 0x00004010, 0x00104010, 0x04004010, 0x04000010, 0x04100000,
    0x00004000, 0x00104010, 0x00100010, 0x04004000, 0x04104010, 0x04000010, 0x00000000, 0x00104000,
    0x04000000, 0x00100000, 0x04004010, 0x04100010, 0x00100000, 0x00004000, 0x04104000, 0x00000010,
    0x00100000, 0x00004000, 0x04000010, 0x04104010, 0x00004010, 0x04000000, 0x00000000, 0x00104000,
    0x04100010, 0x04004010, 0x04004000, 0x00100010, 0x04104000, 0x00000010, 0x00100010, 0x04004000,
    0x04104010, 0x00100000, 0x04100000, 0x04000010, 0x00104000, 0x00004010, 0x04004010, 0x04100000,
    0x00000010, 0x04104000, 0x00104010, 0x00000000, 0x04000000, 0x04100010, 0x00004000, 0x00104010,
};

const sboxes = [8][64]u32{ s0, s1, s2, s3, s4, s5, s6, s7 };

pub const CryptMode = enum {
    Encrypt,
    Decrypt
};

fn permuteBits(long: var, indices: []const u8) @TypeOf(long) {
    comptime const T = @TypeOf(long);
    comptime const TL = math.Log2Int(T);

    var out: T = 0;
    for (indices) |x, i| {
        out ^= (((long >> @intCast(u6, x)) & 1) << @intCast(TL, i));
    }
    return out;
}

fn precomutePermutation(comptime permutation: []const u8) [8][256]u64 {
    @setEvalBranchQuota(1000000);
    comptime var i: u64 = 0;
    comptime var out: [8][256]u64 = undefined;
    inline while (i < 8) : (i += 1) {
        comptime var j: u64 = 0;
        inline while (j < 256) : (j += 1) {
            var p: u64 = j << (i * 8);
            out[i][j] = permuteBits(p, permutation);
        }
    }
    return out;
}

fn permuteBitsPrecomputed(long: u64, comptime precomputedPerm: [8][256]u64) u64 {
    var out: u64 = 0;
    inline for (precomputedPerm) |p, i| {
        out ^= p[@truncate(u8, long >> @intCast(u6, i * 8))];
    }
    return out;
}

fn initialPermutation(long: u64) u64 {
    return if (builtin.mode == .ReleaseSmall)
        permuteBits(long, &ip)
    else
        permuteBitsPrecomputed(long, comptime precomutePermutation(&ip));
}

fn finalPermutation(long: u64) u64 {
    return if (builtin.mode == .ReleaseSmall)
        permuteBits(long, &fp)
    else
        permuteBitsPrecomputed(long, comptime precomutePermutation(&fp));
}

fn permutePc1(long: u64) u64 {
    if (builtin.mode == .ReleaseSmall) {
        return permuteBits(long, &pc1);
    } else {
        comptime const prepc1 = precomutePermutation(&pc1);
        return permuteBitsPrecomputed(long, prepc1);
    }
}

fn permutePc2(long: u56) u56 {
    if (builtin.mode == .ReleaseSmall) {
        return permuteBits(long, &pc2);
    } else {
        comptime const prepc2 = precomutePermutation(&pc2);
        return @intCast(u56, permuteBitsPrecomputed(@as(u64, long), prepc2));
    }
}

pub fn cryptBlock(comptime crypt_mode: CryptMode, keys: []const u48, dest: []u8, source: []const u8) void {
    assert(source.len == block_size);
    assert(dest.len >= block_size);

    const dataLong = mem.readIntSliceBig(u64, source);
    const perm = initialPermutation(dataLong);

    var left = @truncate(u32, perm & 0xFFFFFFFF);
    var right = @truncate(u32, perm >> 32);

    comptime var i: u8 = 0;
    inline while (i < 16) : (i += 1) {
        const r = right;
        const k = keys[if (crypt_mode == .Encrypt) i else (15 - i)];
        var work: u32 = 0;

        work = s0[@truncate(u6, math.rotl(u32, r, 1)) ^ @truncate(u6, k)]
             ^ s1[@truncate(u6, r >> 3) ^ @truncate(u6, k >> 6)]
             ^ s2[@truncate(u6, r >> 7) ^ @truncate(u6, k >> 12)]
             ^ s3[@truncate(u6, r >> 11) ^ @truncate(u6, k >> 18)]
             ^ s4[@truncate(u6, r >> 15) ^ @truncate(u6, k >> 24)]
             ^ s5[@truncate(u6, r >> 19) ^ @truncate(u6, k >> 30)]
             ^ s6[@truncate(u6, r >> 23) ^ @truncate(u6, k >> 36)]
             ^ s7[@truncate(u6, math.rotr(u32, r, 1) >> 26) ^ @truncate(u6, k >> 42)];

        right = left ^ work;
        left = r;
    }

    var out: u64 = left;
    out <<= 32;
    out ^= right;
    out = finalPermutation(out);
    const outBytes = mem.asBytes(&out);
    mem.copy(u8, dest, outBytes);
}

const shifts = [_]u32{
    1, 2, 4, 6, 8, 10, 12, 14, 15, 17, 19, 21, 23, 25, 27, 28
};

pub fn subkeys(keyBytes: []const u8) [16]u48 {
    assert(keyBytes.len == block_size);

    const size: u6 = math.maxInt(u6);
    const key = mem.readIntSliceBig(u64, keyBytes);
    const perm = @truncate(u56, permutePc1(key));

    var left: u28 = @truncate(u28, perm & 0xfffffff);
    var right: u28 = @truncate(u28, (perm >> 28) & 0xfffffff);
    var keys: [16]u48 = undefined;

    inline for (shifts) |shift, i| {
        var subkey: u56 = math.rotr(u28, right, shift);
        subkey <<= 28;
        subkey ^= math.rotr(u28, left, shift);
        subkey = permutePc2(subkey);
        keys[i] = @truncate(u48, subkey);
    }

    return keys;
}

pub const DES = struct {
    const Self = @This();

    subkeys: [16]u48,

    pub fn init(key: [8]u8) Self {
        return Self {
            .subkeys = subkeys(&key)
        };
    }

    pub fn crypt(self: Self, crypt_mode: CryptMode, dest: []u8, source: []const u8) void {
        return switch (crypt_mode) {
            .Encrypt => cryptBlock(.Encrypt, &self.subkeys, dest, source),
            .Decrypt => cryptBlock(.Decrypt, &self.subkeys, dest, source),
        };
    }
};

pub const TDES = struct {
    const Self = @This();

    subkeys: [3][16]u48,

    pub fn init(key: [24]u8) Self {
        return Self {
            .subkeys = [_][16]u48{
                subkeys(key[0..8]),
                subkeys(key[8..16]),
                subkeys(key[16..])
            }
        };
    }

    pub fn crypt(self: Self, crypt_mode: CryptMode, dest: []u8, source: []const u8) void {
        var work: [8]u8 = undefined;
        mem.copy(u8, &work, source);
        switch (crypt_mode) {
            .Encrypt => {
                cryptBlock(.Encrypt, &self.subkeys[0], &work, &work);
                cryptBlock(.Decrypt, &self.subkeys[1], &work, &work);
                cryptBlock(.Encrypt, &self.subkeys[2], &work, &work);
            },
            .Decrypt => {
                cryptBlock(.Decrypt, &self.subkeys[2], &work, &work);
                cryptBlock(.Encrypt, &self.subkeys[1], &work, &work);
                cryptBlock(.Decrypt, &self.subkeys[0], &work, &work);
            }
        }
        mem.copy(u8, dest, &work);
    }
};


// Tests


fn desRoundsInt(comptime crypt_mode: CryptMode, keyLong: u64, dataLong: u64) u64 {
    const reversedKey = @byteSwap(u64, keyLong);
    const key = mem.asBytes(&reversedKey).*;
    const reversedData = @byteSwap(u64, dataLong);
    const source = mem.asBytes(&reversedData);

    var dest: [8]u8 = undefined;
    var cipher = DES.init(key);
    cipher.crypt(crypt_mode, &dest, source);
    return mem.readIntBig(u64, &dest);
}

fn desEncryptTest(keyLong: u64, dataLong: u64) u64 {
    return desRoundsInt(.Encrypt, keyLong, dataLong);
}

fn desDecryptTest(keyLong: u64, dataLong: u64) u64 {
    return desRoundsInt(.Decrypt, keyLong, dataLong);
}

const expectEqual = @import("std").testing.expectEqual;

// https://www.cosic.esat.kuleuven.be/nessie/testvectors/bc/des/Des-64-64.test-vectors
test "DES encrypt" {
    expectEqual(@as(u64, 0x994D4DC157B96C52), desEncryptTest(0x0101010101010101, 0x0101010101010101));
    expectEqual(@as(u64, 0xE127C2B61D98E6E2), desEncryptTest(0x0202020202020202, 0x0202020202020202));
    expectEqual(@as(u64, 0x984C91D78A269CE3), desEncryptTest(0x0303030303030303, 0x0303030303030303));
    expectEqual(@as(u64, 0x1F4570BB77550683), desEncryptTest(0x0404040404040404, 0x0404040404040404));
    expectEqual(@as(u64, 0x3990ABF98D672B16), desEncryptTest(0x0505050505050505, 0x0505050505050505));
    expectEqual(@as(u64, 0x3F5150BBA081D585), desEncryptTest(0x0606060606060606, 0x0606060606060606));
    expectEqual(@as(u64, 0xC65242248C9CF6F2), desEncryptTest(0x0707070707070707, 0x0707070707070707));
    expectEqual(@as(u64, 0x10772D40FAD24257), desEncryptTest(0x0808080808080808, 0x0808080808080808));
    expectEqual(@as(u64, 0xF0139440647A6E7B), desEncryptTest(0x0909090909090909, 0x0909090909090909));
    expectEqual(@as(u64, 0x0A288603044D740C), desEncryptTest(0x0A0A0A0A0A0A0A0A, 0x0A0A0A0A0A0A0A0A));
    expectEqual(@as(u64, 0x6359916942F7438F), desEncryptTest(0x0B0B0B0B0B0B0B0B, 0x0B0B0B0B0B0B0B0B));
    expectEqual(@as(u64, 0x934316AE443CF08B), desEncryptTest(0x0C0C0C0C0C0C0C0C, 0x0C0C0C0C0C0C0C0C));
    expectEqual(@as(u64, 0xE3F56D7F1130A2B7), desEncryptTest(0x0D0D0D0D0D0D0D0D, 0x0D0D0D0D0D0D0D0D));
    expectEqual(@as(u64, 0xA2E4705087C6B6B4), desEncryptTest(0x0E0E0E0E0E0E0E0E, 0x0E0E0E0E0E0E0E0E));
    expectEqual(@as(u64, 0xD5D76E09A447E8C3), desEncryptTest(0x0F0F0F0F0F0F0F0F, 0x0F0F0F0F0F0F0F0F));
    expectEqual(@as(u64, 0xDD7515F2BFC17F85), desEncryptTest(0x1010101010101010, 0x1010101010101010));
    expectEqual(@as(u64, 0xF40379AB9E0EC533), desEncryptTest(0x1111111111111111, 0x1111111111111111));
    expectEqual(@as(u64, 0x96CD27784D1563E5), desEncryptTest(0x1212121212121212, 0x1212121212121212));
    expectEqual(@as(u64, 0x2911CF5E94D33FE1), desEncryptTest(0x1313131313131313, 0x1313131313131313));
    expectEqual(@as(u64, 0x377B7F7CA3E5BBB3), desEncryptTest(0x1414141414141414, 0x1414141414141414));
    expectEqual(@as(u64, 0x701AA63832905A92), desEncryptTest(0x1515151515151515, 0x1515151515151515));
    expectEqual(@as(u64, 0x2006E716C4252D6D), desEncryptTest(0x1616161616161616, 0x1616161616161616));
    expectEqual(@as(u64, 0x452C1197422469F8), desEncryptTest(0x1717171717171717, 0x1717171717171717));
    expectEqual(@as(u64, 0xC33FD1EB49CB64DA), desEncryptTest(0x1818181818181818, 0x1818181818181818));
    expectEqual(@as(u64, 0x7572278F364EB50D), desEncryptTest(0x1919191919191919, 0x1919191919191919));
    expectEqual(@as(u64, 0x69E51488403EF4C3), desEncryptTest(0x1A1A1A1A1A1A1A1A, 0x1A1A1A1A1A1A1A1A));
    expectEqual(@as(u64, 0xFF847E0ADF192825), desEncryptTest(0x1B1B1B1B1B1B1B1B, 0x1B1B1B1B1B1B1B1B));
    expectEqual(@as(u64, 0x521B7FB3B41BB791), desEncryptTest(0x1C1C1C1C1C1C1C1C, 0x1C1C1C1C1C1C1C1C));
    expectEqual(@as(u64, 0x26059A6A0F3F6B35), desEncryptTest(0x1D1D1D1D1D1D1D1D, 0x1D1D1D1D1D1D1D1D));
    expectEqual(@as(u64, 0xF24A8D2231C77538), desEncryptTest(0x1E1E1E1E1E1E1E1E, 0x1E1E1E1E1E1E1E1E));
    expectEqual(@as(u64, 0x4FD96EC0D3304EF6), desEncryptTest(0x1F1F1F1F1F1F1F1F, 0x1F1F1F1F1F1F1F1F));
}

test "DES decrypt" {
    expectEqual(@as(u64, 0x0101010101010101), desDecryptTest(0x0101010101010101, 0x994D4DC157B96C52));
    expectEqual(@as(u64, 0x0202020202020202), desDecryptTest(0x0202020202020202, 0xE127C2B61D98E6E2));
    expectEqual(@as(u64, 0x0303030303030303), desDecryptTest(0x0303030303030303, 0x984C91D78A269CE3));
    expectEqual(@as(u64, 0x0404040404040404), desDecryptTest(0x0404040404040404, 0x1F4570BB77550683));
    expectEqual(@as(u64, 0x0505050505050505), desDecryptTest(0x0505050505050505, 0x3990ABF98D672B16));
    expectEqual(@as(u64, 0x0606060606060606), desDecryptTest(0x0606060606060606, 0x3F5150BBA081D585));
    expectEqual(@as(u64, 0x0707070707070707), desDecryptTest(0x0707070707070707, 0xC65242248C9CF6F2));
    expectEqual(@as(u64, 0x0808080808080808), desDecryptTest(0x0808080808080808, 0x10772D40FAD24257));
    expectEqual(@as(u64, 0x0909090909090909), desDecryptTest(0x0909090909090909, 0xF0139440647A6E7B));
    expectEqual(@as(u64, 0x0A0A0A0A0A0A0A0A), desDecryptTest(0x0A0A0A0A0A0A0A0A, 0x0A288603044D740C));
    expectEqual(@as(u64, 0x0B0B0B0B0B0B0B0B), desDecryptTest(0x0B0B0B0B0B0B0B0B, 0x6359916942F7438F));
    expectEqual(@as(u64, 0x0C0C0C0C0C0C0C0C), desDecryptTest(0x0C0C0C0C0C0C0C0C, 0x934316AE443CF08B));
    expectEqual(@as(u64, 0x0D0D0D0D0D0D0D0D), desDecryptTest(0x0D0D0D0D0D0D0D0D, 0xE3F56D7F1130A2B7));
    expectEqual(@as(u64, 0x0E0E0E0E0E0E0E0E), desDecryptTest(0x0E0E0E0E0E0E0E0E, 0xA2E4705087C6B6B4));
    expectEqual(@as(u64, 0x0F0F0F0F0F0F0F0F), desDecryptTest(0x0F0F0F0F0F0F0F0F, 0xD5D76E09A447E8C3));
    expectEqual(@as(u64, 0x1010101010101010), desDecryptTest(0x1010101010101010, 0xDD7515F2BFC17F85));
    expectEqual(@as(u64, 0x1111111111111111), desDecryptTest(0x1111111111111111, 0xF40379AB9E0EC533));
    expectEqual(@as(u64, 0x1212121212121212), desDecryptTest(0x1212121212121212, 0x96CD27784D1563E5));
    expectEqual(@as(u64, 0x1313131313131313), desDecryptTest(0x1313131313131313, 0x2911CF5E94D33FE1));
    expectEqual(@as(u64, 0x1414141414141414), desDecryptTest(0x1414141414141414, 0x377B7F7CA3E5BBB3));
    expectEqual(@as(u64, 0x1515151515151515), desDecryptTest(0x1515151515151515, 0x701AA63832905A92));
    expectEqual(@as(u64, 0x1616161616161616), desDecryptTest(0x1616161616161616, 0x2006E716C4252D6D));
    expectEqual(@as(u64, 0x1717171717171717), desDecryptTest(0x1717171717171717, 0x452C1197422469F8));
    expectEqual(@as(u64, 0x1818181818181818), desDecryptTest(0x1818181818181818, 0xC33FD1EB49CB64DA));
    expectEqual(@as(u64, 0x1919191919191919), desDecryptTest(0x1919191919191919, 0x7572278F364EB50D));
    expectEqual(@as(u64, 0x1A1A1A1A1A1A1A1A), desDecryptTest(0x1A1A1A1A1A1A1A1A, 0x69E51488403EF4C3));
    expectEqual(@as(u64, 0x1B1B1B1B1B1B1B1B), desDecryptTest(0x1B1B1B1B1B1B1B1B, 0xFF847E0ADF192825));
    expectEqual(@as(u64, 0x1C1C1C1C1C1C1C1C), desDecryptTest(0x1C1C1C1C1C1C1C1C, 0x521B7FB3B41BB791));
    expectEqual(@as(u64, 0x1D1D1D1D1D1D1D1D), desDecryptTest(0x1D1D1D1D1D1D1D1D, 0x26059A6A0F3F6B35));
    expectEqual(@as(u64, 0x1E1E1E1E1E1E1E1E), desDecryptTest(0x1E1E1E1E1E1E1E1E, 0xF24A8D2231C77538));
    expectEqual(@as(u64, 0x1F1F1F1F1F1F1F1F), desDecryptTest(0x1F1F1F1F1F1F1F1F, 0x4FD96EC0D3304EF6));
}

fn tdesRoundsInt(comptime crypt_mode: CryptMode, keyLong: u192, dataLong: u64) u64 {
    const reversedKey = @byteSwap(u192, keyLong);
    const smallKey = mem.asBytes(&reversedKey).*;
    var key: [24]u8 = undefined;
    mem.copy(u8, &key, &smallKey);

    const reversedData = @byteSwap(u64, dataLong);
    const source = mem.asBytes(&reversedData);

    var dest: [8]u8 = undefined;
    var cipher = TDES.init(key);
    cipher.crypt(crypt_mode, &dest, source);
    return mem.readIntBig(u64, &dest);
}

fn tdesEncryptTest(keyLong: u192, dataLong: u64) u64 {
    return tdesRoundsInt(.Encrypt, keyLong, dataLong);
}

fn tdesDecryptTest(keyLong: u192, dataLong: u64) u64 {
    return tdesRoundsInt(.Decrypt, keyLong, dataLong);
}

// https://www.cosic.esat.kuleuven.be/nessie/testvectors/bc/des/Triple-Des-3-Key-192-64.unverified.test-vectors
test "TDES encrypt" {
    expectEqual(@as(u64, 0x95A8D72813DAA94D), tdesEncryptTest(0x800000000000000000000000000000000000000000000000, 0x0000000000000000));
    expectEqual(@as(u64, 0x0EEC1487DD8C26D5), tdesEncryptTest(0x400000000000000000000000000000000000000000000000, 0x0000000000000000));
    expectEqual(@as(u64, 0x7AD16FFB79C45926), tdesEncryptTest(0x200000000000000000000000000000000000000000000000, 0x0000000000000000));
    expectEqual(@as(u64, 0xD3746294CA6A6CF3), tdesEncryptTest(0x100000000000000000000000000000000000000000000000, 0x0000000000000000));
    expectEqual(@as(u64, 0x809F5F873C1FD761), tdesEncryptTest(0x080000000000000000000000000000000000000000000000, 0x0000000000000000));
    expectEqual(@as(u64, 0xC02FAFFEC989D1FC), tdesEncryptTest(0x040000000000000000000000000000000000000000000000, 0x0000000000000000));
    expectEqual(@as(u64, 0x4615AA1D33E72F10), tdesEncryptTest(0x020000000000000000000000000000000000000000000000, 0x0000000000000000));
    expectEqual(@as(u64, 0x8CA64DE9C1B123A7), tdesEncryptTest(0x010000000000000000000000000000000000000000000000, 0x0000000000000000));
    expectEqual(@as(u64, 0x2055123350C00858), tdesEncryptTest(0x008000000000000000000000000000000000000000000000, 0x0000000000000000));
    expectEqual(@as(u64, 0xDF3B99D6577397C8), tdesEncryptTest(0x004000000000000000000000000000000000000000000000, 0x0000000000000000));
    expectEqual(@as(u64, 0x31FE17369B5288C9), tdesEncryptTest(0x002000000000000000000000000000000000000000000000, 0x0000000000000000));
    expectEqual(@as(u64, 0xDFDD3CC64DAE1642), tdesEncryptTest(0x001000000000000000000000000000000000000000000000, 0x0000000000000000));
    expectEqual(@as(u64, 0x178C83CE2B399D94), tdesEncryptTest(0x000800000000000000000000000000000000000000000000, 0x0000000000000000));
    expectEqual(@as(u64, 0x50F636324A9B7F80), tdesEncryptTest(0x000400000000000000000000000000000000000000000000, 0x0000000000000000));
    expectEqual(@as(u64, 0xA8468EE3BC18F06D), tdesEncryptTest(0x000200000000000000000000000000000000000000000000, 0x0000000000000000));
    expectEqual(@as(u64, 0x8CA64DE9C1B123A7), tdesEncryptTest(0x000100000000000000000000000000000000000000000000, 0x0000000000000000));
}

test "TDES decrypt" {
    expectEqual(@as(u64, 0x0000000000000000), tdesDecryptTest(0x800000000000000000000000000000000000000000000000, 0x95A8D72813DAA94D));
    expectEqual(@as(u64, 0x0000000000000000), tdesDecryptTest(0x400000000000000000000000000000000000000000000000, 0x0EEC1487DD8C26D5));
    expectEqual(@as(u64, 0x0000000000000000), tdesDecryptTest(0x200000000000000000000000000000000000000000000000, 0x7AD16FFB79C45926));
    expectEqual(@as(u64, 0x0000000000000000), tdesDecryptTest(0x100000000000000000000000000000000000000000000000, 0xD3746294CA6A6CF3));
    expectEqual(@as(u64, 0x0000000000000000), tdesDecryptTest(0x080000000000000000000000000000000000000000000000, 0x809F5F873C1FD761));
    expectEqual(@as(u64, 0x0000000000000000), tdesDecryptTest(0x040000000000000000000000000000000000000000000000, 0xC02FAFFEC989D1FC));
    expectEqual(@as(u64, 0x0000000000000000), tdesDecryptTest(0x020000000000000000000000000000000000000000000000, 0x4615AA1D33E72F10));
    expectEqual(@as(u64, 0x0000000000000000), tdesDecryptTest(0x010000000000000000000000000000000000000000000000, 0x8CA64DE9C1B123A7));
    expectEqual(@as(u64, 0x0000000000000000), tdesDecryptTest(0x008000000000000000000000000000000000000000000000, 0x2055123350C00858));
    expectEqual(@as(u64, 0x0000000000000000), tdesDecryptTest(0x004000000000000000000000000000000000000000000000, 0xDF3B99D6577397C8));
    expectEqual(@as(u64, 0x0000000000000000), tdesDecryptTest(0x002000000000000000000000000000000000000000000000, 0x31FE17369B5288C9));
    expectEqual(@as(u64, 0x0000000000000000), tdesDecryptTest(0x001000000000000000000000000000000000000000000000, 0xDFDD3CC64DAE1642));
    expectEqual(@as(u64, 0x0000000000000000), tdesDecryptTest(0x000800000000000000000000000000000000000000000000, 0x178C83CE2B399D94));
    expectEqual(@as(u64, 0x0000000000000000), tdesDecryptTest(0x000400000000000000000000000000000000000000000000, 0x50F636324A9B7F80));
    expectEqual(@as(u64, 0x0000000000000000), tdesDecryptTest(0x000200000000000000000000000000000000000000000000, 0xA8468EE3BC18F06D));
    expectEqual(@as(u64, 0x0000000000000000), tdesDecryptTest(0x000100000000000000000000000000000000000000000000, 0x8CA64DE9C1B123A7));
}
