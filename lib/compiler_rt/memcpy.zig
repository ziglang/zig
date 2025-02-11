const std = @import("std");
const assert = std.debug.assert;
const common = @import("./common.zig");
const builtin = @import("builtin");

comptime {
    if (builtin.object_format != .c) {
        const export_options: std.builtin.ExportOptions = .{
            .name = "memcpy",
            .linkage = common.linkage,
            .visibility = common.visibility,
        };

        if (builtin.mode == .ReleaseSmall)
            @export(&memcpySmall, export_options)
        else
            @export(&memcpyFast, export_options);
    }
}

const Element = Element: {
    if (std.simd.suggestVectorLength(u8)) |vec_size| {
        const Vec = @Vector(vec_size, u8);

        if (@sizeOf(Vec) == vec_size and std.math.isPowerOfTwo(vec_size)) {
            break :Element Vec;
        }
    }
    break :Element usize;
};

comptime {
    assert(std.math.isPowerOfTwo(@sizeOf(Element)));
}

fn memcpySmall(noalias dest: ?[*]u8, noalias src: ?[*]const u8, len: usize) callconv(.C) ?[*]u8 {
    @setRuntimeSafety(false);

    for (0..len) |i| {
        dest.?[i] = src.?[i];
    }

    return dest;
}

fn memcpyFast(noalias dest: ?[*]u8, noalias src: ?[*]const u8, len: usize) callconv(.C) ?[*]u8 {
    @setRuntimeSafety(false);

    const small_limit = 2 * @sizeOf(Element);

    if (copySmallLength(small_limit, dest.?, src.?, len)) return dest;

    copyForwards(dest.?, src.?, len);

    return dest;
}

inline fn copySmallLength(
    comptime small_limit: comptime_int,
    dest: [*]u8,
    src: [*]const u8,
    len: usize,
) bool {
    if (len < 16) {
        copyLessThan16(dest, src, len);
        return true;
    }

    if (comptime 2 < (std.math.log2(small_limit) + 1) / 2) {
        if (copy16ToSmallLimit(small_limit, dest, src, len)) return true;
    }

    return false;
}

inline fn copyLessThan16(
    dest: [*]u8,
    src: [*]const u8,
    len: usize,
) void {
    @setRuntimeSafety(false);
    if (len < 4) {
        if (len == 0) return;
        dest[0] = src[0];
        dest[len / 2] = src[len / 2];
        dest[len - 1] = src[len - 1];
        return;
    }
    copyRange4(4, dest, src, len);
}

inline fn copy16ToSmallLimit(
    comptime small_limit: comptime_int,
    dest: [*]u8,
    src: [*]const u8,
    len: usize,
) bool {
    @setRuntimeSafety(false);
    inline for (2..(std.math.log2(small_limit) + 1) / 2 + 1) |p| {
        const limit = 1 << (2 * p);
        if (len < limit) {
            copyRange4(limit / 4, dest, src, len);
            return true;
        }
    }
    return false;
}

inline fn copyForwards(
    noalias dest: [*]u8,
    noalias src: [*]const u8,
    len: usize,
) void {
    @setRuntimeSafety(false);

    copyFixedLength(dest, src, @sizeOf(Element));
    const alignment_offset = @alignOf(Element) - @intFromPtr(src) % @alignOf(Element);
    const n = len - alignment_offset;
    const d = dest + alignment_offset;
    const s = src + alignment_offset;

    copyBlocksAlignedSource(@ptrCast(d), @alignCast(@ptrCast(s)), n);

    // copy last `@sizeOf(Element)` bytes unconditionally, since block copy
    // methods only copy a multiple of `@sizeOf(Element)` bytes.
    const offset = len - @sizeOf(Element);
    copyFixedLength(dest + offset, src + offset, @sizeOf(Element));
}

inline fn copyBlocksAlignedSource(
    noalias dest: [*]align(1) Element,
    noalias src: [*]const Element,
    max_bytes: usize,
) void {
    copyBlocks(dest, src, max_bytes);
}

/// Copies the largest multiple of `@sizeOf(T)` bytes from `src` to `dest`,
/// that is less than `max_bytes` where `T` is the child type of `src` and
/// `dest`.
inline fn copyBlocks(
    noalias dest: anytype,
    noalias src: anytype,
    max_bytes: usize,
) void {
    @setRuntimeSafety(false);

    const T = @typeInfo(@TypeOf(dest)).pointer.child;
    comptime assert(T == @typeInfo(@TypeOf(src)).pointer.child);

    const loop_count = max_bytes / @sizeOf(T);

    for (dest[0..loop_count], src[0..loop_count]) |*d, s| {
        d.* = s;
    }
}

inline fn copyFixedLength(
    noalias dest: [*]u8,
    noalias src: [*]const u8,
    comptime len: comptime_int,
) void {
    @setRuntimeSafety(false);
    comptime assert(std.math.isPowerOfTwo(len));

    const T = if (len >= @sizeOf(Element))
        Element
    else if (len > @sizeOf(usize))
        @Vector(len, u8)
    else
        @Type(.{ .int = .{ .signedness = .unsigned, .bits = len * 8 } });

    const loop_count = @divExact(len, @sizeOf(T));

    const d: [*]align(1) T = @ptrCast(dest);
    const s: [*]align(1) const T = @ptrCast(src);

    inline for (0..loop_count) |i| {
        d[i] = s[i];
    }
}

/// copy `len` bytes from `src` to `dest`; `len` must be in the range
/// `[copy_len, 4 * copy_len)`.
inline fn copyRange4(
    comptime copy_len: comptime_int,
    noalias dest: [*]u8,
    noalias src: [*]const u8,
    len: usize,
) void {
    @setRuntimeSafety(false);
    comptime assert(std.math.isPowerOfTwo(copy_len));

    const a = len & (copy_len * 2);
    const b = a / 2;

    const last = len - copy_len;
    const pen = last - b;

    copyFixedLength(dest, src, copy_len);
    copyFixedLength(dest + b, src + b, copy_len);
    copyFixedLength(dest + pen, src + pen, copy_len);
    copyFixedLength(dest + last, src + last, copy_len);
}

test "memcpy" {
    const S = struct {
        fn testFunc(comptime copy_func: anytype) !void {
            const max_len = 1024;
            var buffer: [max_len + @alignOf(Element) - 1]u8 align(@alignOf(Element)) = undefined;
            for (&buffer, 0..) |*b, i| {
                b.* = @intCast(i % 97);
            }
            var dest: [max_len + @alignOf(Element) - 1]u8 align(@alignOf(Element)) = undefined;

            for (0..max_len) |copy_len| {
                for (0..@alignOf(Element)) |s_offset| {
                    for (0..@alignOf(Element)) |d_offset| {
                        @memset(&dest, 0xff);
                        const s = buffer[s_offset..][0..copy_len];
                        const d = dest[d_offset..][0..copy_len];
                        _ = copy_func(@ptrCast(d.ptr), @ptrCast(s.ptr), s.len);
                        std.testing.expectEqualSlices(u8, s, d) catch |e| {
                            std.debug.print("error encountered for length={d}, s_offset={d}, d_offset={d}\n", .{
                                copy_len, s_offset, d_offset,
                            });
                            return e;
                        };
                    }
                }
            }
        }
    };

    try S.testFunc(memcpySmall);
    try S.testFunc(memcpyFast);
}
