// Based on Go stdlib implementation

const std = @import("../../std.zig");
const math = std.math;
const mem = std.mem;

const BlockVec = [4]u32;

/// A single AES block.
pub const Block = struct {
    pub const block_length: usize = 16;

    /// Internal representation of a block.
    repr: BlockVec align(16),

    /// Convert a byte sequence into an internal representation.
    pub inline fn fromBytes(bytes: *const [16]u8) Block {
        const s0 = mem.readIntBig(u32, bytes[0..4]);
        const s1 = mem.readIntBig(u32, bytes[4..8]);
        const s2 = mem.readIntBig(u32, bytes[8..12]);
        const s3 = mem.readIntBig(u32, bytes[12..16]);
        return Block{ .repr = BlockVec{ s0, s1, s2, s3 } };
    }

    /// Convert the internal representation of a block into a byte sequence.
    pub inline fn toBytes(block: Block) [16]u8 {
        var bytes: [16]u8 = undefined;
        mem.writeIntBig(u32, bytes[0..4], block.repr[0]);
        mem.writeIntBig(u32, bytes[4..8], block.repr[1]);
        mem.writeIntBig(u32, bytes[8..12], block.repr[2]);
        mem.writeIntBig(u32, bytes[12..16], block.repr[3]);
        return bytes;
    }

    /// XOR the block with a byte sequence.
    pub inline fn xorBytes(block: Block, bytes: *const [16]u8) [16]u8 {
        const block_bytes = block.toBytes();
        var x: [16]u8 = undefined;
        comptime var i: usize = 0;
        inline while (i < 16) : (i += 1) {
            x[i] = block_bytes[i] ^ bytes[i];
        }
        return x;
    }

    /// Encrypt a block with a round key.
    pub inline fn encrypt(block: Block, round_key: Block) Block {
        const s0 = block.repr[0];
        const s1 = block.repr[1];
        const s2 = block.repr[2];
        const s3 = block.repr[3];

        const t0 = round_key.repr[0] ^ table_encrypt[0][@truncate(u8, s0 >> 24)] ^ table_encrypt[1][@truncate(u8, s1 >> 16)] ^ table_encrypt[2][@truncate(u8, s2 >> 8)] ^ table_encrypt[3][@truncate(u8, s3)];
        const t1 = round_key.repr[1] ^ table_encrypt[0][@truncate(u8, s1 >> 24)] ^ table_encrypt[1][@truncate(u8, s2 >> 16)] ^ table_encrypt[2][@truncate(u8, s3 >> 8)] ^ table_encrypt[3][@truncate(u8, s0)];
        const t2 = round_key.repr[2] ^ table_encrypt[0][@truncate(u8, s2 >> 24)] ^ table_encrypt[1][@truncate(u8, s3 >> 16)] ^ table_encrypt[2][@truncate(u8, s0 >> 8)] ^ table_encrypt[3][@truncate(u8, s1)];
        const t3 = round_key.repr[3] ^ table_encrypt[0][@truncate(u8, s3 >> 24)] ^ table_encrypt[1][@truncate(u8, s0 >> 16)] ^ table_encrypt[2][@truncate(u8, s1 >> 8)] ^ table_encrypt[3][@truncate(u8, s2)];

        return Block{ .repr = BlockVec{ t0, t1, t2, t3 } };
    }

    /// Encrypt a block with the last round key.
    pub inline fn encryptLast(block: Block, round_key: Block) Block {
        const t0 = block.repr[0];
        const t1 = block.repr[1];
        const t2 = block.repr[2];
        const t3 = block.repr[3];

        // Last round uses s-box directly and XORs to produce output.
        var s0 = @as(u32, sbox_encrypt[t0 >> 24]) << 24 | @as(u32, sbox_encrypt[t1 >> 16 & 0xff]) << 16 | @as(u32, sbox_encrypt[t2 >> 8 & 0xff]) << 8 | @as(u32, sbox_encrypt[t3 & 0xff]);
        var s1 = @as(u32, sbox_encrypt[t1 >> 24]) << 24 | @as(u32, sbox_encrypt[t2 >> 16 & 0xff]) << 16 | @as(u32, sbox_encrypt[t3 >> 8 & 0xff]) << 8 | @as(u32, sbox_encrypt[t0 & 0xff]);
        var s2 = @as(u32, sbox_encrypt[t2 >> 24]) << 24 | @as(u32, sbox_encrypt[t3 >> 16 & 0xff]) << 16 | @as(u32, sbox_encrypt[t0 >> 8 & 0xff]) << 8 | @as(u32, sbox_encrypt[t1 & 0xff]);
        var s3 = @as(u32, sbox_encrypt[t3 >> 24]) << 24 | @as(u32, sbox_encrypt[t0 >> 16 & 0xff]) << 16 | @as(u32, sbox_encrypt[t1 >> 8 & 0xff]) << 8 | @as(u32, sbox_encrypt[t2 & 0xff]);
        s0 ^= round_key.repr[0];
        s1 ^= round_key.repr[1];
        s2 ^= round_key.repr[2];
        s3 ^= round_key.repr[3];

        return Block{ .repr = BlockVec{ s0, s1, s2, s3 } };
    }

    /// Decrypt a block with a round key.
    pub inline fn decrypt(block: Block, round_key: Block) Block {
        const s0 = block.repr[0];
        const s1 = block.repr[1];
        const s2 = block.repr[2];
        const s3 = block.repr[3];

        const t0 = round_key.repr[0] ^ table_decrypt[0][@truncate(u8, s0 >> 24)] ^ table_decrypt[1][@truncate(u8, s3 >> 16)] ^ table_decrypt[2][@truncate(u8, s2 >> 8)] ^ table_decrypt[3][@truncate(u8, s1)];
        const t1 = round_key.repr[1] ^ table_decrypt[0][@truncate(u8, s1 >> 24)] ^ table_decrypt[1][@truncate(u8, s0 >> 16)] ^ table_decrypt[2][@truncate(u8, s3 >> 8)] ^ table_decrypt[3][@truncate(u8, s2)];
        const t2 = round_key.repr[2] ^ table_decrypt[0][@truncate(u8, s2 >> 24)] ^ table_decrypt[1][@truncate(u8, s1 >> 16)] ^ table_decrypt[2][@truncate(u8, s0 >> 8)] ^ table_decrypt[3][@truncate(u8, s3)];
        const t3 = round_key.repr[3] ^ table_decrypt[0][@truncate(u8, s3 >> 24)] ^ table_decrypt[1][@truncate(u8, s2 >> 16)] ^ table_decrypt[2][@truncate(u8, s1 >> 8)] ^ table_decrypt[3][@truncate(u8, s0)];

        return Block{ .repr = BlockVec{ t0, t1, t2, t3 } };
    }

    /// Decrypt a block with the last round key.
    pub inline fn decryptLast(block: Block, round_key: Block) Block {
        const t0 = block.repr[0];
        const t1 = block.repr[1];
        const t2 = block.repr[2];
        const t3 = block.repr[3];

        // Last round uses s-box directly and XORs to produce output.
        var s0 = @as(u32, sbox_decrypt[t0 >> 24]) << 24 | @as(u32, sbox_decrypt[t3 >> 16 & 0xff]) << 16 | @as(u32, sbox_decrypt[t2 >> 8 & 0xff]) << 8 | @as(u32, sbox_decrypt[t1 & 0xff]);
        var s1 = @as(u32, sbox_decrypt[t1 >> 24]) << 24 | @as(u32, sbox_decrypt[t0 >> 16 & 0xff]) << 16 | @as(u32, sbox_decrypt[t3 >> 8 & 0xff]) << 8 | @as(u32, sbox_decrypt[t2 & 0xff]);
        var s2 = @as(u32, sbox_decrypt[t2 >> 24]) << 24 | @as(u32, sbox_decrypt[t1 >> 16 & 0xff]) << 16 | @as(u32, sbox_decrypt[t0 >> 8 & 0xff]) << 8 | @as(u32, sbox_decrypt[t3 & 0xff]);
        var s3 = @as(u32, sbox_decrypt[t3 >> 24]) << 24 | @as(u32, sbox_decrypt[t2 >> 16 & 0xff]) << 16 | @as(u32, sbox_decrypt[t1 >> 8 & 0xff]) << 8 | @as(u32, sbox_decrypt[t0 & 0xff]);
        s0 ^= round_key.repr[0];
        s1 ^= round_key.repr[1];
        s2 ^= round_key.repr[2];
        s3 ^= round_key.repr[3];

        return Block{ .repr = BlockVec{ s0, s1, s2, s3 } };
    }

    /// Apply the bitwise XOR operation to the content of two blocks.
    pub inline fn xorBlocks(block1: Block, block2: Block) Block {
        var x: BlockVec = undefined;
        comptime var i = 0;
        inline while (i < 4) : (i += 1) {
            x[i] = block1.repr[i] ^ block2.repr[i];
        }
        return Block{ .repr = x };
    }

    /// Apply the bitwise AND operation to the content of two blocks.
    pub inline fn andBlocks(block1: Block, block2: Block) Block {
        var x: BlockVec = undefined;
        comptime var i = 0;
        inline while (i < 4) : (i += 1) {
            x[i] = block1.repr[i] & block2.repr[i];
        }
        return Block{ .repr = x };
    }

    /// Apply the bitwise OR operation to the content of two blocks.
    pub inline fn orBlocks(block1: Block, block2: Block) Block {
        var x: BlockVec = undefined;
        comptime var i = 0;
        inline while (i < 4) : (i += 1) {
            x[i] = block1.repr[i] | block2.repr[i];
        }
        return Block{ .repr = x };
    }

    /// Perform operations on multiple blocks in parallel.
    pub const parallel = struct {
        /// The recommended number of AES encryption/decryption to perform in parallel for the chosen implementation.
        pub const optimal_parallel_blocks = 1;

        /// Encrypt multiple blocks in parallel, each their own round key.
        pub fn encryptParallel(comptime count: usize, blocks: [count]Block, round_keys: [count]Block) [count]Block {
            var i = 0;
            var out: [count]Block = undefined;
            while (i < count) : (i += 1) {
                out[i] = blocks[i].encrypt(round_keys[i]);
            }
            return out;
        }

        /// Decrypt multiple blocks in parallel, each their own round key.
        pub fn decryptParallel(comptime count: usize, blocks: [count]Block, round_keys: [count]Block) [count]Block {
            var i = 0;
            var out: [count]Block = undefined;
            while (i < count) : (i += 1) {
                out[i] = blocks[i].decrypt(round_keys[i]);
            }
            return out;
        }

        /// Encrypt multiple blocks in parallel with the same round key.
        pub fn encryptWide(comptime count: usize, blocks: [count]Block, round_key: Block) [count]Block {
            var i = 0;
            var out: [count]Block = undefined;
            while (i < count) : (i += 1) {
                out[i] = blocks[i].encrypt(round_key);
            }
            return out;
        }

        /// Decrypt multiple blocks in parallel with the same round key.
        pub fn decryptWide(comptime count: usize, blocks: [count]Block, round_key: Block) [count]Block {
            var i = 0;
            var out: [count]Block = undefined;
            while (i < count) : (i += 1) {
                out[i] = blocks[i].decrypt(round_key);
            }
            return out;
        }

        /// Encrypt multiple blocks in parallel with the same last round key.
        pub fn encryptLastWide(comptime count: usize, blocks: [count]Block, round_key: Block) [count]Block {
            var i = 0;
            var out: [count]Block = undefined;
            while (i < count) : (i += 1) {
                out[i] = blocks[i].encryptLast(round_key);
            }
            return out;
        }

        /// Decrypt multiple blocks in parallel with the same last round key.
        pub fn decryptLastWide(comptime count: usize, blocks: [count]Block, round_key: Block) [count]Block {
            var i = 0;
            var out: [count]Block = undefined;
            while (i < count) : (i += 1) {
                out[i] = blocks[i].decryptLast(round_key);
            }
            return out;
        }
    };
};

fn KeySchedule(comptime Aes: type) type {
    std.debug.assert(Aes.rounds == 10 or Aes.rounds == 14);
    const key_length = Aes.key_bits / 8;
    const rounds = Aes.rounds;

    return struct {
        const Self = @This();
        const words_in_key = key_length / 4;

        round_keys: [rounds + 1]Block,

        // Key expansion algorithm. See FIPS-197, Figure 11.
        fn expandKey(key: [key_length]u8) Self {
            const subw = struct {
                // Apply sbox_encrypt to each byte in w.
                fn func(w: u32) u32 {
                    return @as(u32, sbox_encrypt[w >> 24]) << 24 | @as(u32, sbox_encrypt[w >> 16 & 0xff]) << 16 | @as(u32, sbox_encrypt[w >> 8 & 0xff]) << 8 | @as(u32, sbox_encrypt[w & 0xff]);
                }
            }.func;

            var round_keys: [rounds + 1]Block = undefined;
            comptime var i: usize = 0;
            inline while (i < words_in_key) : (i += 1) {
                round_keys[i / 4].repr[i % 4] = mem.readIntBig(u32, key[4 * i ..][0..4]);
            }
            inline while (i < round_keys.len * 4) : (i += 1) {
                var t = round_keys[(i - 1) / 4].repr[(i - 1) % 4];
                if (i % words_in_key == 0) {
                    t = subw(std.math.rotl(u32, t, 8)) ^ (@as(u32, powx[i / words_in_key - 1]) << 24);
                } else if (words_in_key > 6 and i % words_in_key == 4) {
                    t = subw(t);
                }
                round_keys[i / 4].repr[i % 4] = round_keys[(i - words_in_key) / 4].repr[(i - words_in_key) % 4] ^ t;
            }
            return Self{ .round_keys = round_keys };
        }

        /// Invert the key schedule.
        pub fn invert(key_schedule: Self) Self {
            const round_keys = &key_schedule.round_keys;
            var inv_round_keys: [rounds + 1]Block = undefined;
            const total_words = 4 * round_keys.len;
            var i: usize = 0;
            while (i < total_words) : (i += 4) {
                const ei = total_words - i - 4;
                comptime var j: usize = 0;
                inline while (j < 4) : (j += 1) {
                    var x = round_keys[(ei + j) / 4].repr[(ei + j) % 4];
                    if (i > 0 and i + 4 < total_words) {
                        x = table_decrypt[0][sbox_encrypt[x >> 24]] ^ table_decrypt[1][sbox_encrypt[x >> 16 & 0xff]] ^ table_decrypt[2][sbox_encrypt[x >> 8 & 0xff]] ^ table_decrypt[3][sbox_encrypt[x & 0xff]];
                    }
                    inv_round_keys[(i + j) / 4].repr[(i + j) % 4] = x;
                }
            }
            return Self{ .round_keys = inv_round_keys };
        }
    };
}

/// A context to perform encryption using the standard AES key schedule.
pub fn AesEncryptCtx(comptime Aes: type) type {
    std.debug.assert(Aes.key_bits == 128 or Aes.key_bits == 256);
    const rounds = Aes.rounds;

    return struct {
        const Self = @This();
        pub const block = Aes.block;
        pub const block_length = block.block_length;
        key_schedule: KeySchedule(Aes),

        /// Create a new encryption context with the given key.
        pub fn init(key: [Aes.key_bits / 8]u8) Self {
            const key_schedule = KeySchedule(Aes).expandKey(key);
            return Self{
                .key_schedule = key_schedule,
            };
        }

        /// Encrypt a single block.
        pub fn encrypt(ctx: Self, dst: *[16]u8, src: *const [16]u8) void {
            const round_keys = ctx.key_schedule.round_keys;
            var t = Block.fromBytes(src).xorBlocks(round_keys[0]);
            comptime var i = 1;
            inline while (i < rounds) : (i += 1) {
                t = t.encrypt(round_keys[i]);
            }
            t = t.encryptLast(round_keys[rounds]);
            dst.* = t.toBytes();
        }

        /// Encrypt+XOR a single block.
        pub fn xor(ctx: Self, dst: *[16]u8, src: *const [16]u8, counter: [16]u8) void {
            const round_keys = ctx.key_schedule.round_keys;
            var t = Block.fromBytes(&counter).xorBlocks(round_keys[0]);
            comptime var i = 1;
            inline while (i < rounds) : (i += 1) {
                t = t.encrypt(round_keys[i]);
            }
            t = t.encryptLast(round_keys[rounds]);
            dst.* = t.xorBytes(src);
        }

        /// Encrypt multiple blocks, possibly leveraging parallelization.
        pub fn encryptWide(ctx: Self, comptime count: usize, dst: *[16 * count]u8, src: *const [16 * count]u8) void {
            var i: usize = 0;
            while (i < count) : (i += 1) {
                ctx.encrypt(dst[16 * i .. 16 * i + 16][0..16], src[16 * i .. 16 * i + 16][0..16]);
            }
        }

        /// Encrypt+XOR multiple blocks, possibly leveraging parallelization.
        pub fn xorWide(ctx: Self, comptime count: usize, dst: *[16 * count]u8, src: *const [16 * count]u8, counters: [16 * count]u8) void {
            var i: usize = 0;
            while (i < count) : (i += 1) {
                ctx.xor(dst[16 * i .. 16 * i + 16][0..16], src[16 * i .. 16 * i + 16][0..16], counters[16 * i .. 16 * i + 16][0..16].*);
            }
        }
    };
}

/// A context to perform decryption using the standard AES key schedule.
pub fn AesDecryptCtx(comptime Aes: type) type {
    std.debug.assert(Aes.key_bits == 128 or Aes.key_bits == 256);
    const rounds = Aes.rounds;

    return struct {
        const Self = @This();
        pub const block = Aes.block;
        pub const block_length = block.block_length;
        key_schedule: KeySchedule(Aes),

        /// Create a decryption context from an existing encryption context.
        pub fn initFromEnc(ctx: AesEncryptCtx(Aes)) Self {
            return Self{
                .key_schedule = ctx.key_schedule.invert(),
            };
        }

        /// Create a new decryption context with the given key.
        pub fn init(key: [Aes.key_bits / 8]u8) Self {
            const enc_ctx = AesEncryptCtx(Aes).init(key);
            return initFromEnc(enc_ctx);
        }

        /// Decrypt a single block.
        pub fn decrypt(ctx: Self, dst: *[16]u8, src: *const [16]u8) void {
            const inv_round_keys = ctx.key_schedule.round_keys;
            var t = Block.fromBytes(src).xorBlocks(inv_round_keys[0]);
            comptime var i = 1;
            inline while (i < rounds) : (i += 1) {
                t = t.decrypt(inv_round_keys[i]);
            }
            t = t.decryptLast(inv_round_keys[rounds]);
            dst.* = t.toBytes();
        }

        /// Decrypt multiple blocks, possibly leveraging parallelization.
        pub fn decryptWide(ctx: Self, comptime count: usize, dst: *[16 * count]u8, src: *const [16 * count]u8) void {
            var i: usize = 0;
            while (i < count) : (i += 1) {
                ctx.decrypt(dst[16 * i .. 16 * i + 16][0..16], src[16 * i .. 16 * i + 16][0..16]);
            }
        }
    };
}

/// AES-128 with the standard key schedule.
pub const Aes128 = struct {
    pub const key_bits: usize = 128;
    pub const rounds = ((key_bits - 64) / 32 + 8);
    pub const block = Block;

    /// Create a new context for encryption.
    pub fn initEnc(key: [key_bits / 8]u8) AesEncryptCtx(Aes128) {
        return AesEncryptCtx(Aes128).init(key);
    }

    /// Create a new context for decryption.
    pub fn initDec(key: [key_bits / 8]u8) AesDecryptCtx(Aes128) {
        return AesDecryptCtx(Aes128).init(key);
    }
};

/// AES-256 with the standard key schedule.
pub const Aes256 = struct {
    pub const key_bits: usize = 256;
    pub const rounds = ((key_bits - 64) / 32 + 8);
    pub const block = Block;

    /// Create a new context for encryption.
    pub fn initEnc(key: [key_bits / 8]u8) AesEncryptCtx(Aes256) {
        return AesEncryptCtx(Aes256).init(key);
    }

    /// Create a new context for decryption.
    pub fn initDec(key: [key_bits / 8]u8) AesDecryptCtx(Aes256) {
        return AesDecryptCtx(Aes256).init(key);
    }
};

// constants

// Rijndael's irreducible polynomial.
const poly: u9 = 1 << 8 | 1 << 4 | 1 << 3 | 1 << 1 | 1 << 0; // x⁸ + x⁴ + x³ + x + 1

// Powers of x mod poly in GF(2).
const powx = init: {
    var array: [16]u8 = undefined;

    var value = 1;
    for (&array) |*power| {
        power.* = value;
        value = mul(value, 2);
    }

    break :init array;
};

const sbox_encrypt align(64) = generateSbox(false);
const sbox_decrypt align(64) = generateSbox(true);
const table_encrypt align(64) = generateTable(false);
const table_decrypt align(64) = generateTable(true);

// Generate S-box substitution values.
fn generateSbox(invert: bool) [256]u8 {
    @setEvalBranchQuota(10000);

    var sbox: [256]u8 = undefined;

    var p: u8 = 1;
    var q: u8 = 1;
    for (sbox) |_| {
        p = mul(p, 3);
        q = mul(q, 0xf6); // divide by 3

        var value: u8 = q ^ 0x63;
        value ^= math.rotl(u8, q, 1);
        value ^= math.rotl(u8, q, 2);
        value ^= math.rotl(u8, q, 3);
        value ^= math.rotl(u8, q, 4);

        if (invert) {
            sbox[value] = p;
        } else {
            sbox[p] = value;
        }
    }

    if (invert) {
        sbox[0x63] = 0x00;
    } else {
        sbox[0x00] = 0x63;
    }

    return sbox;
}

// Generate lookup tables.
fn generateTable(invert: bool) [4][256]u32 {
    var table: [4][256]u32 = undefined;

    for (generateSbox(invert), 0..) |value, index| {
        table[0][index] = mul(value, if (invert) 0xb else 0x3);
        table[0][index] |= math.shl(u32, mul(value, if (invert) 0xd else 0x1), 8);
        table[0][index] |= math.shl(u32, mul(value, if (invert) 0x9 else 0x1), 16);
        table[0][index] |= math.shl(u32, mul(value, if (invert) 0xe else 0x2), 24);

        table[1][index] = math.rotr(u32, table[0][index], 8);
        table[2][index] = math.rotr(u32, table[0][index], 16);
        table[3][index] = math.rotr(u32, table[0][index], 24);
    }

    return table;
}

// Multiply a and b as GF(2) polynomials modulo poly.
fn mul(a: u8, b: u8) u8 {
    @setEvalBranchQuota(30000);

    var i: u8 = a;
    var j: u9 = b;
    var s: u9 = 0;

    while (i > 0) : (i >>= 1) {
        if (i & 1 != 0) {
            s ^= j;
        }

        j *= 2;
        if (j & 0x100 != 0) {
            j ^= poly;
        }
    }

    return @truncate(u8, s);
}
