// Based on Go stdlib implementation

const std = @import("../std.zig");
const mem = std.mem;
const debug = std.debug;

/// Counter mode.
///
/// This mode creates a key stream by encrypting an incrementing counter using a block cipher, and adding it to the source material.
///
/// Important: the counter mode doesn't provide authenticated encryption: the ciphertext can be trivially modified without this being detected.
/// As a result, applications should generally never use it directly, but only in a construction that includes a MAC.
pub fn ctr(comptime BlockCipher: anytype, block_cipher: BlockCipher, dst: []u8, src: []const u8, iv: [BlockCipher.block_length]u8, endian: std.builtin.Endian) void {
    debug.assert(dst.len >= src.len);
    const block_length = BlockCipher.block_length;
    var counter: [BlockCipher.block_length]u8 = undefined;
    var counterInt = mem.readInt(u128, &iv, endian);
    var i: usize = 0;

    const parallel_count = BlockCipher.block.parallel.optimal_parallel_blocks;
    const wide_block_length = parallel_count * 16;
    if (src.len >= wide_block_length) {
        var counters: [parallel_count * 16]u8 = undefined;
        while (i + wide_block_length <= src.len) : (i += wide_block_length) {
            comptime var j = 0;
            inline while (j < parallel_count) : (j += 1) {
                mem.writeInt(u128, counters[j * 16 .. j * 16 + 16], counterInt, endian);
                counterInt +%= 1;
            }
            block_cipher.xorWide(parallel_count, dst[i .. i + wide_block_length][0..wide_block_length], src[i .. i + wide_block_length][0..wide_block_length], counters);
        }
    }
    while (i + block_length <= src.len) : (i += block_length) {
        mem.writeInt(u128, &counter, counterInt, endian);
        counterInt +%= 1;
        block_cipher.xor(dst[i .. i + block_length][0..block_length], src[i .. i + block_length][0..block_length], counter);
    }
    if (i < src.len) {
        mem.writeInt(u128, &counter, counterInt, endian);
        var pad = [_]u8{0} ** block_length;
        const src_slice = src[i..];
        @memcpy(pad[0..src_slice.len], src_slice);
        block_cipher.xor(&pad, &pad, counter);
        const pad_slice = pad[0 .. src.len - i];
        @memcpy(dst[i..][0..pad_slice.len], pad_slice);
    }
}

/// Cipher block chaining mode (decryption).
///
/// First decrypts with cipher, then XORs with previous block (or initialization vector).
pub fn cbcDecrypt(BlockCipher: anytype, block_cipher: BlockCipher, dst: []u8, src: []const u8, iv: [BlockCipher.block_length]u8) void {
    // TODO: Add support for parallel decryption
    std.debug.assert(dst.len >= src.len);
    const block_length = BlockCipher.block_length;
    var i: usize = 0;
    var previous_block: [block_length]u8 = iv;
    while (i + block_length < src.len) : (i += block_length) {
        var block: [block_length]u8 = undefined;
        // xor block with last block or initialization vector
        block_cipher.decrypt(&block, src[i..][0..block_length]);
        for (block[0..], previous_block[0..]) |*byte, prev| {
            byte.* ^= prev;
        }
        // update last block value
        @memcpy(dst[i..][0..block_length], &block);
        @memcpy(&previous_block, src[i..][0..block_length]);
    }
    // account for unaligned final block
    if (i < src.len) {
        var pad = [_]u8{0} ** block_length;
        const src_slice = src[i..];
        @memcpy(pad[0..src_slice.len], src_slice);
        block_cipher.decrypt(&pad, &pad);
        for (pad[0..], previous_block[0..]) |*byte, prev| {
            byte.* ^= prev;
        }
        const pad_slice = pad[0 .. src.len - i];
        @memcpy(dst[i..][0..pad_slice.len], pad_slice);
    }
}

/// Cipher block chaining mode (encryption).
///
/// First XORs each block with the previous block (or initialization vector) and then
/// encrypts the block with cipher.
pub fn cbcEncrypt(BlockCipher: anytype, block_cipher: BlockCipher, dst: []u8, src: []const u8, iv: [BlockCipher.block_length]u8) void {
    std.debug.assert(dst.len >= src.len);
    const block_length = BlockCipher.block_length;
    var i: usize = 0;
    var previous_block: [block_length]u8 = iv;
    while (i + block_length < src.len) : (i += block_length) {
        var block: [block_length]u8 = undefined;
        // xor block with last block or initialization vector
        for (block[0..], src[i..][0..block_length], previous_block[0..]) |*byte, cur, prev| {
            byte.* = cur ^ prev;
        }
        block_cipher.encrypt(&block, &block);
        // update last block value
        @memcpy(dst[i..][0..block_length], block[0..block_length]);
        @memcpy(&previous_block, &block);
    }
    // account for unaligned final block
    if (i < src.len) {
        var pad = [_]u8{0} ** block_length;
        const src_slice = src[i..];
        @memcpy(pad[0..src_slice.len], src_slice);
        for (pad[0..], previous_block[0..]) |*byte, prev| {
            byte.* ^= prev;
        }
        block_cipher.encrypt(&pad, &pad);
        const pad_slice = pad[0 .. src.len - i];
        @memcpy(dst[i..][0..pad_slice.len], pad_slice);
    }
}
