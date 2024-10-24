const std = @import("std");
const assert = std.debug.assert;
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

const copy_alignment = @alignOf(CopyType);
const copy_size = @sizeOf(CopyType);

comptime {
    assert(copy_size >= copy_alignment);
    assert(std.math.isPowerOfTwo(copy_size));
}

pub const memcpy = if (builtin.mode == .ReleaseSmall or builtin.mode == .Debug)
    memcpy_small
else
    memcpy_fast;

fn memcpy_small(noalias dest: ?[*]u8, noalias src: ?[*]const u8, len: usize) callconv(.C) ?[*]u8 {
    @setRuntimeSafety(builtin.is_test);

    if (len != 0) {
        memcpy_blocks(dest.?, src.?, len, 1);
    }

    return dest;
}

fn memcpy_fast(noalias dest: ?[*]u8, noalias src: ?[*]const u8, len: usize) callconv(.C) ?[*]u8 {
    @setRuntimeSafety(builtin.is_test);

    if (len <= 16) {
        if (len <= 4) {
            if (len <= 2) {
                if (len == 0) return dest;
                memcpy_range2(1, dest.?, src.?, len);
            } else {
                memcpy_range2(2, dest.?, src.?, len);
            }
        } else if (len <= 8) {
            memcpy_range2(4, dest.?, src.?, len);
        } else {
            memcpy_range2(8, dest.?, src.?, len);
        }
        return dest;
    }

    const unroll_count = 2;

    const small_limit = @min(2 * copy_size, unroll_count * copy_size);
    if (comptime 5 <= std.math.log2(small_limit)) {
        inline for (5..std.math.log2(small_limit) + 1) |p| {
            const limit = 1 << p;
            if (len <= limit) {
                memcpy_range2(limit / 2, dest.?, src.?, len);
                return dest;
            }
        }
    }

    assert(2 * copy_size < len);

    // we know that `len > 2 * copy_size` and `copy_size >= copy_alignment`
    // so we can safely align `s` to `copy_alignment`
    dest.?[0..copy_size].* = src.?[0..copy_size].*;
    const alignment_offset = copy_alignment - @intFromPtr(src.?) % copy_alignment;
    const n = len - alignment_offset;
    const d = dest.? + alignment_offset;
    const s = src.? + alignment_offset;

    if (@intFromPtr(d) % copy_alignment == 0) {
        memcpy_aligned(@alignCast(@ptrCast(d)), @alignCast(@ptrCast(s)), n, unroll_count);
    } else {
        memcpy_unaligned(@ptrCast(d), @alignCast(@ptrCast(s)), n, unroll_count);
    }

    dest.?[len - copy_size ..][0..copy_size].* = src.?[len - copy_size ..][0..copy_size].*;

    return dest;
}

// inline is needed to prevent llvm making an infinitely recursive call to memcpy
inline fn memcpy_aligned(
    noalias dest: [*]CopyType,
    noalias src: [*]const CopyType,
    max_bytes: usize,
    comptime unroll_count: comptime_int,
) void {
    memcpy_blocks(dest, src, max_bytes, unroll_count);
}

inline fn memcpy_unaligned(
    noalias dest: [*]align(1) CopyType,
    noalias src: [*]const CopyType,
    max_bytes: usize,
    comptime unroll_count: comptime_int,
) void {
    memcpy_blocks(dest, src, max_bytes, unroll_count);
}

/// Copies a multiple of `@sizeOf(T)` bytes from `src` to `dest`, where `T` is
/// the child type of `src` and `dest`. No more than `max_bytes` will be copied
/// (`max_bytes` need not be a multiple of `@sizeOf(T)`) but `max_bytes` must
/// be at least `@sizeOf(T)`.
inline fn memcpy_blocks(
    noalias dest: anytype,
    noalias src: anytype,
    max_bytes: usize,
    comptime unroll_count: comptime_int,
) void {
    @setRuntimeSafety(builtin.is_test);
    comptime assert(unroll_count > 0);

    const T = @typeInfo(@TypeOf(dest)).pointer.child;
    comptime assert(T == @typeInfo(@TypeOf(src)).pointer.child);

    const loop_count = max_bytes / (@sizeOf(T) * unroll_count);

    for (0..loop_count) |i| {
        inline for (dest[i * unroll_count ..][0..unroll_count], src[i * unroll_count ..][0..unroll_count]) |*d, s| {
            d.* = s;
        }
    }

    const tail_start = (max_bytes / @sizeOf(T)) - (unroll_count - 1);
    inline for (dest[tail_start..][0 .. unroll_count - 1], src[tail_start..][0 .. unroll_count - 1]) |*d, s| {
        d.* = s;
    }
}

/// copy blocks of length `copy_len` from `src[0..len] to `dest[0..len]` at the
/// start and end of those respective slices
inline fn memcpy_range2(
    comptime copy_len: comptime_int,
    noalias dest: [*]u8,
    noalias src: [*]const u8,
    len: usize,
) void {
    @setRuntimeSafety(builtin.is_test);
    comptime assert(std.math.isPowerOfTwo(copy_len));

    const last = len - copy_len;
    if (copy_len > copy_size) { // comptime-known
        // we do these copies 1 CopyType at a time to prevent llvm turning this into a call to memcpy
        const d: [*]align(1) CopyType = @ptrCast(dest);
        const s: [*]align(1) const CopyType = @ptrCast(src);
        const count = @divExact(copy_len, copy_size);
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
    const S = struct {
        fn testFunc(comptime copy_func: anytype) !void {
            @setEvalBranchQuota(1024);
            inline for (0..1024) |copy_len| {
                var buffer: [copy_len]u8 align(copy_alignment) = undefined;
                const p: *align(copy_alignment) [copy_len / 2]u16 = @ptrCast(&buffer);
                for (p, 0..) |*b, i| {
                    b.* = @intCast(i);
                }
                var dest: [copy_len]u8 align(copy_alignment) = undefined;
                _ = copy_func(@ptrCast(&dest), @ptrCast(&buffer), copy_len);
                try std.testing.expectEqualSlices(u8, &buffer, &dest);
            }
        }
    };

    try S.testFunc(memcpy_small);
    try S.testFunc(memcpy_fast);
}

test "unaligned" {
    const S = struct {
        fn testFunc(comptime copy_func: anytype) !void {
            @setEvalBranchQuota(1024);
            inline for (0..1024) |copy_len| {
                var buffer: [copy_len + copy_alignment - 1]u8 align(copy_alignment) = undefined;
                const p: *align(copy_alignment) [copy_len / 2]u16 = @ptrCast(&buffer);
                for (p, 0..) |*b, i| {
                    b.* = @intCast(i);
                }
                var dest: [copy_len + copy_alignment - 1]u8 align(copy_alignment) = undefined;
                for (1..copy_alignment) |offset| {
                    @memset(&dest, 0);
                    const s = buffer[offset..][0..copy_len];
                    const d = dest[offset..][0..copy_len];
                    _ = copy_func(@ptrCast(d.ptr), @ptrCast(s.ptr), s.len);
                    try std.testing.expectEqualSlices(u8, s, d);
                }
            }
        }
    };

    try S.testFunc(memcpy_small);
    try S.testFunc(memcpy_fast);
}

test "misaligned" {
    const S = struct {
        fn testFunc(comptime copy_func: anytype) !void {
            @setEvalBranchQuota(1024);
            inline for (0..1024) |copy_len| {
                var buffer: [copy_len + copy_alignment - 1]u8 align(copy_alignment) = undefined;
                const p: *align(copy_alignment) [copy_len / 2]u16 = @ptrCast(&buffer);
                for (p, 0..) |*b, i| {
                    b.* = @intCast(i);
                }
                var dest: [copy_len + copy_alignment - 1]u8 align(copy_alignment) = undefined;

                for (0..copy_alignment) |s_offset| {
                    for (0..copy_alignment) |d_offset| {
                        if (s_offset == d_offset) continue;
                        @memset(&dest, 0);
                        const s = buffer[s_offset..][0..copy_len];
                        const d = dest[d_offset..][0..copy_len];
                        _ = copy_func(@ptrCast(d.ptr), @ptrCast(s.ptr), s.len);
                        try std.testing.expectEqualSlices(u8, s, d);
                    }
                }
            }
        }
    };

    try S.testFunc(memcpy_small);
    try S.testFunc(memcpy_fast);
}
