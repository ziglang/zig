//! Implements CRC-32C (Castagnoli) using the SSE4.2 Intel CRC32 instruction.
//!
//! A couple useful links for understanding the approach taken here:
//! - https://github.com/madler/brotli/blob/1d428d3a9baade233ebc3ac108293256bcb813d1/crc32c.c
//! - https://github.com/madler/zlib/blob/5a82f71ed1dfc0bec044d9702463dbdf84ea3b71/crc32.c
//! - http://www.ross.net/crc/download/crc_v3.txt

// Reflected CRC-32C polynomial in binary form.
const POLY = 0x82f63b78;

const LONG = 8192;
const SHORT = 256;
const long_lookup_table = genTable(LONG);
const short_lookup_table = genTable(SHORT);

/// Generates the lookup table for efficiently combining CRCs over a block of a given length `length`.
/// This works by building an operator that advances the CRC state as if `length` zero-bytes were appended.
/// We pre-compute 4 tables of 256 entries each (one per byte offset).
///
///
/// The idea behind this table is quite interesting. The CRC state is equivalent to the
/// remainder of dividing the message polynomial (over GF(2)) by the CRC polynomial.
///
/// Advancing the CRC register by `k` zero bits is equivalent to multiplying the current
/// CRC state by `x^k` modulo the CRC polynomial. This operation can be represented
/// as a linear transformation in GF(2), i.e, a matrix.
///
/// We build up this matrix via repeated squaring:
/// - odd represents the operator for 1 zero bit (i.e, multiplication by `x^1 mod POLY`)
/// - even represents the operator for 2 zero bits (`x^2 mod POLY`)
/// - squaring again gives `x^4 mod POLY`, and so on until we get to the right size.
///
/// By squaring the shifting `len`, we build the operator for `x^l mod POLY`.
fn genTable(length: usize) [4][256]u32 {
    @setEvalBranchQuota(250000);

    var even: [32]u32 = undefined;
    zeroes: {
        var odd: [32]u32 = undefined;

        // Initialize our `odd` array with the operator for a single zero bit:
        // - odd[0] is the polynomial itself (acts on the MSB).
        // - odd[1..32] represent shifting a single bit through 31 positions.
        odd[0] = POLY;
        var row: u32 = 1;
        for (1..32) |n| {
            odd[n] = row;
            row <<= 1;
        }

        // even = odd squared: even represents `x^2 mod POLY`.
        square(&even, &odd);
        // odd = even squared: odd now represents `x^4 mod POLY`.
        square(&odd, &even);

        // Continue squaring to double the number of zeroes encoded each time:
        //
        // At each point in the process:
        // - square(even, odd): even gets the operator for twice the current length.
        // - square(odd, even): odd gets the operator for 4 times the original length.
        var len = length;
        while (true) {
            square(&even, &odd);
            len >>= 1;
            if (len == 0) break :zeroes;
            square(&odd, &even);
            len >>= 1;
            if (len == 0) break;
        }

        @memcpy(&even, &odd);
    }

    var zeroes: [4][256]u32 = undefined;
    for (0..256) |n| {
        zeroes[0][n] = times(&even, n);
        zeroes[1][n] = times(&even, n << 8);
        zeroes[2][n] = times(&even, n << 16);
        zeroes[3][n] = times(&even, n << 24);
    }
    return zeroes;
}

/// Computes `mat * vec` over `GF(2)`, where `mat` is a 32x32 binary matrix and `vec`
/// is a 32-bit vector. This somewhat "simulates" how bits propagate through the CRC register
/// during shifting.
///
/// - In GF(2) (aka a field where the only values are 0 and 1, aka binary), multiplication is
/// an `AND`, and addition is `XOR`.
/// - This dot product determines how each bit in the input vector "contributes" to
/// the final CRC state, by XORing (adding) rows of the matrix where `vec` has 1s.
fn times(mat: *const [32]u32, vec: u32) u32 {
    var sum: u32 = 0;
    var v = vec;
    var i: u32 = 0;
    while (v != 0) {
        if (v & 1 != 0) sum ^= mat[i];
        v >>= 1;
        i += 1;
    }
    return sum;
}

/// Computes the square of a matrix in GF(2), i.e `dst = dst x src`.
///
/// This produces the operator for doubling the number of zeroes:
/// if `src` represents advancing the CRC by `k` zeroes, then `dest` will
/// represent advancing by 2k zeroes.
///
/// Since polynomial multiplication mod POLY is linear, `mat(mat(x)) = mat^2(x)`
/// gives the effect of two sequential applications of the operator.
fn square(dst: *[32]u32, src: *const [32]u32) void {
    for (dst, src) |*d, s| {
        d.* = times(src, s);
    }
}

fn shift(table: *const [4][256]u32, crc: u32) u32 {
    return table[0][crc & 0xFF] ^ table[1][(crc >> 8) & 0xFF] ^ table[2][(crc >> 16) & 0xFF] ^ table[3][crc >> 24];
}

fn crc32(crc: u32, input: []const u8) u32 {
    var crc0: u64 = ~crc;

    // Compute the CRC for up to seven leading bytes to bring the
    // `next` pointer to an eight-byte boundary.
    var next = input;
    while (next.len > 0 and @intFromPtr(next.ptr) & 7 != 0) {
        asm volatile ("crc32b %[out], %[in]"
            : [in] "+r" (crc0),
            : [out] "rm" (next[0]),
        );
        next = next[1..];
    }

    // Compute the CRC on sets of LONG * 3 bytes, executing three independent
    // CRC instructions, each on LONG bytes. This is an optimization for
    // targets where the CRC instruction has a throughput of one CRC per
    // cycle, but a latency of three cycles.
    while (next.len >= LONG * 3) {
        var crc1: u64 = 0;
        var crc2: u64 = 0;

        const start = next.len;
        while (true) {
            // Safe @alignCast(), since we've aligned the pointer to 8 bytes before this loop.
            const long: [*]const u64 = @ptrCast(@alignCast(next));
            asm volatile (
                \\crc32q %[out0], %[in0]
                \\crc32q %[out1], %[in1]
                \\crc32q %[out2], %[in2]
                : [in0] "+r" (crc0),
                  [in1] "+r" (crc1),
                  [in2] "+r" (crc2),
                : [out0] "rm" (long[0 * LONG / 8]),
                  [out1] "rm" (long[1 * LONG / 8]),
                  [out2] "rm" (long[2 * LONG / 8]),
            );
            next = next[8..];
            if (next.len <= start - LONG) break;
        }

        crc0 = shift(&long_lookup_table, @truncate(crc0)) ^ crc1;
        crc0 = shift(&long_lookup_table, @truncate(crc0)) ^ crc2;
        next = next[LONG * 2 ..];
    }

    // Same thing as above, but for smaller chunks of SHORT bytes.
    while (next.len >= SHORT * 3) {
        var crc1: u64 = 0;
        var crc2: u64 = 0;

        const start = next.len;
        while (true) {
            const long: [*]const u64 = @ptrCast(@alignCast(next));
            asm volatile (
                \\crc32q %[out0], %[in0]
                \\crc32q %[out1], %[in1]
                \\crc32q %[out2], %[in2]
                : [in0] "+r" (crc0),
                  [in1] "+r" (crc1),
                  [in2] "+r" (crc2),
                : [out0] "rm" (long[0 * SHORT / 8]),
                  [out1] "rm" (long[1 * SHORT / 8]),
                  [out2] "rm" (long[2 * SHORT / 8]),
            );
            next = next[8..];
            if (next.len <= start - SHORT) break;
        }

        crc0 = shift(&short_lookup_table, @truncate(crc0)) ^ crc1;
        crc0 = shift(&short_lookup_table, @truncate(crc0)) ^ crc2;
        next = next[SHORT * 2 ..];
    }

    // Compute via 8-byte chunks, until we're left with less than 8 bytes.
    while (next.len >= 8) {
        const long: [*]const u64 = @ptrCast(@alignCast(next));
        asm volatile ("crc32q %[out], %[in]"
            : [in] "+r" (crc0),
            : [out] "rm" (long[0]),
        );
        next = next[8..];
    }

    // Finish the last bytes with just single instructions.
    while (next.len > 0) {
        asm volatile ("crc32b %[out], %[in]"
            : [in] "+r" (crc0),
            : [out] "rm" (next[0]),
        );
        next = next[1..];
    }

    return @truncate(~crc0);
}

// Wrapper around the accelerated implementation to match the one in impl.zig.
pub const Wrapper = struct {
    crc: u32,

    pub fn init() Wrapper {
        return .{ .crc = 0 };
    }

    pub fn update(w: *Wrapper, bytes: []const u8) void {
        w.crc = crc32(w.crc, bytes);
    }

    pub fn final(w: Wrapper) u32 {
        return w.crc;
    }

    pub fn hash(bytes: []const u8) u32 {
        var c = init();
        c.update(bytes);
        return c.final();
    }
};
