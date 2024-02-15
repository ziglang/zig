const std = @import("std");
const common = @import("./common.zig");
const builtin = @import("builtin");

comptime {
    if (builtin.object_format != .c) {
        @export(&memcpy, .{ .name = "memcpy", .linkage = common.linkage, .visibility = common.visibility });
    }
}

const CopyType = if (std.simd.suggestVectorLength(u8)) |vec_size|
    @Type(.{ .vector = .{
        .child = u8,
        .len = vec_size,
    } })
else
    usize;

const alignment = @alignOf(CopyType);
const size = @sizeOf(CopyType);

const small_limit = 256;

comptime {
    std.debug.assert(small_limit >= alignment);
    std.debug.assert(std.math.isPowerOfTwo(size));
    std.debug.assert(std.math.isPowerOfTwo(small_limit));
}

pub fn memcpy(noalias dest: ?[*]u8, noalias src: ?[*]const u8, len: usize) callconv(.C) ?[*]u8 {
    @setRuntimeSafety(false);

    if (len < 16) {
        if (len < 4) {
            memcpy_remainder(4, dest.?, src.?, len);
            return dest;
        }
        memcpy_range4(4, dest.?, src.?, len);
        return dest;
    }

    if (len <= 32) {
        memcpy_range2(16, dest.?, src.?, len);
        return dest;
    }

    if (len < small_limit) {
        memcpy_remainder(small_limit, dest.?, src.?, len);
        return dest;
    }

    var d = dest.?;
    var s = src.?;
    var n = len;

    // align source, this assumes small_limit >= alignment
    d[0..size].* = s[0..size].*;
    const alignment_offset = alignment - @intFromPtr(s) % alignment;
    n -= alignment_offset;
    d += alignment_offset;
    s += alignment_offset;

    if (@intFromPtr(d) % alignment == 0) {
        memcpy_aligned(@alignCast(@ptrCast(d)), @alignCast(@ptrCast(s)), n);
    } else {
        var vd: [*]align(1) CopyType = @ptrCast(d);
        var vs: [*]const CopyType = @alignCast(@ptrCast(s));
        while (n >= @sizeOf(CopyType)) {
            vd[0] = vs[0];
            vd += 1;
            vs += 1;
            n -= @sizeOf(CopyType);
        }
    }

    dest.?[len - size ..][0..size].* = src.?[len - size ..][0..size].*;

    return dest;
}

// inline is needed to prevent llvm making an infinitely recursive call to memcpy
inline fn memcpy_aligned(
    noalias dest: [*]CopyType,
    noalias src: [*]const CopyType,
    len: usize,
) void {
    @setRuntimeSafety(false);

    var d = dest;
    var s = src;
    var n = len;

    while (n >= size) {
        d[0] = s[0];
        n -= size;
        d += 1;
        s += 1;
    }
}

inline fn memcpy_remainder(
    comptime max_end: comptime_int,
    noalias dest: [*]u8,
    noalias src: [*]const u8,
    len: usize,
) void {
    @setRuntimeSafety(false);
    comptime std.debug.assert(std.math.isPowerOfTwo(max_end));

    var d = dest;
    var s = src;
    comptime var rem = max_end / 2;
    inline while (rem > 0) {
        if (len & rem != 0) {
            for (d[0..rem], s[0..rem]) |*b, v| {
                b.* = v;
            }
            d += rem;
            s += rem;
        }
        rem /= 2;
    }
}

/// behavior is undefined if `len` does not satisfy `min <= len < 4 * min`
inline fn memcpy_range4(
    comptime min: comptime_int,
    noalias dest: [*]u8,
    noalias src: [*]const u8,
    len: usize,
) void {
    @setRuntimeSafety(false);
    comptime std.debug.assert(std.math.isPowerOfTwo(min));

    const copy_len = min;
    const last = len - copy_len;
    const offset = (len & (2 * min)) / 2;
    dest[0..copy_len].* = src[0..copy_len].*;
    dest[offset..][0..copy_len].* = src[offset..][0..copy_len].*;
    dest[last - offset ..][0..copy_len].* = src[last - offset ..][0..copy_len].*;
    dest[last..][0..copy_len].* = src[last..][0..copy_len].*;
}

/// copy blocks of length `copy_len` from `src[0..len] to `dest[0..len]` at the
/// start and end of those respective slices
inline fn memcpy_range2(
    comptime copy_len: comptime_int,
    noalias dest: [*]u8,
    noalias src: [*]const u8,
    len: usize,
) void {
    @setRuntimeSafety(false);
    comptime std.debug.assert(std.math.isPowerOfTwo(copy_len));

    const last = len - copy_len;
    if (copy_len > size) { // comptime-known
        // we do these copies 1 CopyType at a time to prevent llvm turning this into a call to memcpy
        const d: [*]align(1) CopyType = @ptrCast(dest);
        const s: [*]align(1) const CopyType = @ptrCast(src);
        const count = @divExact(copy_len, size);
        inline for (d[0..count], s[0..count]) |*r, v| {
            r.* = v;
        }
        const dl: [*]align(1) CopyType = @ptrCast(dest + last);
        const sl: [*]align(1) const CopyType = @ptrCast(src + last);
        inline for (dl[0..count], sl[0..count]) |*r, v| {
            r.* = v;
        }
    } else {
        dest[0..copy_len].* = src[0..copy_len].*;
        dest[last..][0..copy_len].* = src[last..][0..copy_len].*;
    }
}

test "aligned" {
    @setEvalBranchQuota(1024);
    inline for (0..1024) |copy_len| {
        var buffer: [copy_len]u8 align(alignment) = undefined;
        const p: *align(alignment) [copy_len / 2]u16 = @ptrCast(&buffer);
        for (p, 0..) |*b, i| {
            b.* = @intCast(i);
        }
        var dest: [copy_len]u8 align(alignment) = undefined;
        _ = memcpy(@ptrCast(&dest), @ptrCast(&buffer), copy_len);
        try std.testing.expectEqualSlices(u8, &buffer, &dest);
    }
}

test "unaligned" {
    @setEvalBranchQuota(1024);
    inline for (0..1024) |copy_len| {
        var buffer: [copy_len + alignment - 1]u8 align(alignment) = undefined;
        const p: *align(alignment) [copy_len / 2]u16 = @ptrCast(&buffer);
        for (p, 0..) |*b, i| {
            b.* = @intCast(i);
        }
        var dest: [copy_len + alignment - 1]u8 align(alignment) = undefined;
        for (1..alignment) |offset| {
            @memset(&dest, 0);
            const s = buffer[offset..][0..copy_len];
            const d = dest[offset..][0..copy_len];
            _ = memcpy(@ptrCast(d.ptr), @ptrCast(s.ptr), s.len);
            try std.testing.expectEqualSlices(u8, s, d);
        }
    }
}

test "misaligned" {
    @setEvalBranchQuota(1024);
    inline for (0..1024) |copy_len| {
        var buffer: [copy_len + alignment - 1]u8 align(alignment) = undefined;
        const p: *align(alignment) [copy_len / 2]u16 = @ptrCast(&buffer);
        for (p, 0..) |*b, i| {
            b.* = @intCast(i);
        }
        var dest: [copy_len + alignment - 1]u8 align(alignment) = undefined;

        for (0..alignment) |s_offset| {
            for (0..alignment) |d_offset| {
                if (s_offset == d_offset) continue;
                @memset(&dest, 0);
                const s = buffer[s_offset..][0..copy_len];
                const d = dest[d_offset..][0..copy_len];
                _ = memcpy(@ptrCast(d.ptr), @ptrCast(s.ptr), s.len);
                try std.testing.expectEqualSlices(u8, s, d);
            }
        }
    }
}
