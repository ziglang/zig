const std = @import("std");
const crypto = std.crypto;
const debug = std.debug;
const math = std.math;
const mem = std.mem;
const testing = std.testing;

const TimingSafeEql = struct {
    fn _x86_64(comptime T: type, comptime xlen: usize, a: []const T, b: []const T) u64 {
        @setEvalBranchQuota(20000);

        comptime var i: usize = 0;
        comptime var buf = [_]u8{0} ** 1024;
        var z: u64 = 0;

        // 16 bytes at a time
        if (i + 16 <= xlen) {
            comptime var x16code: []const u8 = "pxor %%xmm2, %%xmm2;";
            inline while (i + 16 <= xlen) : (i += 16) {
                x16code = x16code ++ (std.fmt.bufPrint(&buf,
                    \\ movups {}(%[a]), %%xmm0;
                    \\ movups {}(%[b]), %%xmm1;
                    \\ pxor %%xmm0, %%xmm1;
                    \\ por %%xmm1, %%xmm2;
                , .{ i, i }) catch unreachable);
            }
            x16code = x16code ++
                \\ pxor %%xmm0, %%xmm0;
                \\ pcmpeqd %%xmm2, %%xmm0;
                \\ pmovmskb %%xmm0, %[ret];
                \\ notq %[ret];
                \\ andq $0xffff, %[ret];
            ;
            z = asm volatile (x16code
                : [ret] "=r" (-> u64)
                : [a] "r" (a.ptr),
                  [b] "r" (b.ptr)
                : "xmm0", "xmm1", "xmm2", "cc"
            );
        }
        // 8 bytes at a time
        if (i + 8 <= xlen) {
            comptime var x8code: []const u8 = "";
            inline while (i + 8 <= xlen) : (i += 8) {
                x8code = x8code ++ (std.fmt.bufPrint(&buf,
                    \\ movq {}(%[a]), %[s];
                    \\ movq {}(%[b]), %[t];
                    \\ xorq %[s], %[t];
                    \\ orq %[t], %[ret];
                , .{ i, i }) catch unreachable);
            }
            x8code = "movq %[z], %[ret];" ++ x8code;
            var s: u64 = 0;
            var t: u64 = 0;
            z = asm volatile (x8code
                : [ret] "=&r" (-> u64),
                  [s] "=&r" (s),
                  [t] "=&r" (t)
                : [a] "r" (a.ptr),
                  [b] "r" (b.ptr),
                  [z] "rm" (z)
                : "cc"
            );
        }
        // remaining bytes
        if (i < xlen) {
            comptime var x1code: []const u8 = "";
            inline while (i < xlen) : (i += 1) {
                x1code = x1code ++ (std.fmt.bufPrint(&buf,
                    \\ movzbq {}(%[a]), %[s];
                    \\ movzbq {}(%[b]), %[t];
                    \\ xorq %[s], %[t];
                    \\ orq %[t], %[ret];
                , .{ i, i }) catch unreachable);
            }
            x1code = "movq %[z], %[ret];" ++ x1code;
            var s: u64 = 0;
            var t: u64 = 0;
            z = asm volatile (x1code
                : [ret] "=&r" (-> u64),
                  [s] "=&r" (s),
                  [t] "=&r" (t)
                : [a] "r" (a.ptr),
                  [b] "r" (b.ptr),
                  [z] "rm" (z)
                : "cc"
            );
        }
        return z;
    }

    fn x86_64(comptime T: type, comptime len: usize, a: [len]T, b: [len]T) bool {
        const xlen = len * @sizeOf(T);
        comptime var i: usize = 0;
        var ret: u64 = 0;
        // Comparing more than 512 bits is unusual, but even if we did, there wouldn't be much to learn with such a large block
        inline while (i < xlen) : (i += 128) {
            comptime const left = math.min(128, xlen - i);
            ret |= _x86_64(T, left, a[i..], b[i..]);
        }
        return ret == 0;
    }

    fn generic(comptime T: type, comptime len: usize, a: [len]T, b: [len]T) bool {
        var z: T = 0;
        var i: usize = 0;
        while (i < len) : (i += 1) {
            z |= a[i] ^ b[i];
            asm volatile (""
                :
                : [a] "rm" (a[i]),
                  [b] "rm" (b[i]),
                  [z] "rm" (z)
                : "memory"
            );
        }
        return z == 0;
    }
};

/// Compares two slices in constant time (for a given length) and returns whether they are equal.
/// This function was designed to compare short cryptographic secrets (MACs, signatures).
/// For all other applications, use mem.eql() instead.
pub fn timingSafeEql(comptime T: type, comptime len: usize, a: [len]T, b: [len]T) bool {
    comptime debug.assert(len > 0);

    switch (std.builtin.arch) {
        .x86_64 => return TimingSafeEql.x86_64(T, len, a, b),
        else => return @call(.{ .modifier = .never_inline }, TimingSafeEql.generic, .{ T, len, a, b }),
    }
}

test "timingSafeEql" {
    var a: [256]u8 = undefined;
    var b: [256]u8 = undefined;

    comptime var i: usize = 1;
    inline while (i <= 256) : (i += 13) {
        crypto.randomBytes(a[0..i]) catch unreachable;
        crypto.randomBytes(b[0..i]) catch unreachable;
        if (mem.eql(u8, a[0..i], b[0..i])) {
            testing.expect(timingSafeEql(u8, i, a[0..i].*, b[0..i].*));
            a[0] ^= 0xff;
        }
        testing.expect(!timingSafeEql(u8, i, a[0..i].*, b[0..i].*));
        mem.copy(u8, a[0..i], b[0..i]);
        testing.expect(timingSafeEql(u8, i, a[0..i].*, b[0..i].*));
        a[0] +%= 1;
        testing.expect(!timingSafeEql(u8, i, a[0..i].*, b[0..i].*));
        a[0] = b[0];
        a[i - 1] -%= 1;
        testing.expect(!timingSafeEql(u8, i, a[0..i].*, b[0..i].*));
    }
}
