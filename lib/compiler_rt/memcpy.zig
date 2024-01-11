const std = @import("std");
const common = @import("./common.zig");
const builtin = @import("builtin");

comptime {
    if (builtin.object_format != .c) {
        @export(memcpy, .{ .name = "memcpy", .linkage = common.linkage, .visibility = common.visibility });
    }
}

const CopyType = if (std.simd.suggestVectorLength(u8)) |vec_size|
    @Type(.{ .Int = .{
        .signedness = .unsigned,
        .bits = std.mem.byte_size_in_bits * vec_size,
    } })
else
    usize;

const alignment = @alignOf(CopyType);
const size = @sizeOf(CopyType);

const small_limit = 256;

pub fn memcpy(noalias dest: ?[*]u8, noalias src: ?[*]const u8, len: usize) callconv(.C) ?[*]u8 {
    @setRuntimeSafety(false);

    if (len < 9) {
        memcpy_remainder(16, dest.?, src.?, len);
        return dest;
    }

    if (len < 17) {
        memcpy_remainder(32, dest.?, src.?, len);
        return dest;
    }

    if (len < small_limit) {
        memcpy_remainder(small_limit, dest.?, src.?, len);
        return dest;
    }

    var d = dest.?;
    var s = src.?;
    var n = len;

    // copy bytes until source is aligned
    while (@intFromPtr(s) % alignment != 0) {
        d[0] = s[0];
        n -= 1;
        d += 1;
        s += 1;
    }

    if (@intFromPtr(d) % alignment == 0) {
        memcpy_aligned(@alignCast(@ptrCast(d)), @alignCast(@ptrCast(s)), n);
        return dest;
    }

    while (n > 0) {
        d[0] = s[0];
        n -= 1;
        d += 1;
        s += 1;
    }

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

    memcpy_remainder(size, @ptrCast(d), @ptrCast(s), n);
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

test "aligned" {
    @setEvalBranchQuota(1024);
    inline for (0..1024) |copy_len| {
        var buffer: [copy_len]u8 align(@alignOf(usize)) = undefined;
        const p: *align(@alignOf(usize)) [copy_len / 2]u16 = @ptrCast(&buffer);
        for (p, 0..) |*b, i| {
            b.* = @intCast(i);
        }
        var dest: [copy_len]u8 align(@alignOf(usize)) = undefined;
        _ = memcpy(@ptrCast(&dest), @ptrCast(&buffer), copy_len);
        try std.testing.expectEqualSlices(u8, &buffer, &dest);
    }
}

test "unaligned" {
    @setEvalBranchQuota(1024);
    inline for (0..1024) |copy_len| {
        var buffer: [copy_len + @alignOf(usize) - 1]u8 align(@alignOf(usize)) = undefined;
        const p: *align(@alignOf(usize)) [copy_len / 2]u16 = @ptrCast(&buffer);
        for (p, 0..) |*b, i| {
            b.* = @intCast(i);
        }
        var dest: [copy_len + @alignOf(usize) - 1]u8 align(@alignOf(usize)) = undefined;
        for (1..@alignOf(usize)) |offset| {
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
        var buffer: [copy_len + @alignOf(usize) - 1]u8 align(@alignOf(usize)) = undefined;
        const p: *align(@alignOf(usize)) [copy_len / 2]u16 = @ptrCast(&buffer);
        for (p, 0..) |*b, i| {
            b.* = @intCast(i);
        }
        var dest: [copy_len + @alignOf(usize) - 1]u8 align(@alignOf(usize)) = undefined;

        for (0..@alignOf(usize)) |s_offset| {
            for (0..@alignOf(usize)) |d_offset| {
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
