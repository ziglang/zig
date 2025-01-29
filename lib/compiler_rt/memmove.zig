const std = @import("std");
const common = @import("./common.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const memcpy = @import("memcpy.zig");

const Element = common.PreferredLoadStoreElement;

comptime {
    if (builtin.object_format != .c) {
        const export_options: std.builtin.ExportOptions = .{
            .name = "memmove",
            .linkage = common.linkage,
            .visibility = common.visibility,
        };

        if (builtin.mode == .ReleaseSmall)
            @export(&memmoveSmall, export_options)
        else
            @export(&memmoveFast, export_options);
    }
}

fn memmoveSmall(opt_dest: ?[*]u8, opt_src: ?[*]const u8, len: usize) callconv(.C) ?[*]u8 {
    const dest = opt_dest.?;
    const src = opt_src.?;

    if (@intFromPtr(dest) < @intFromPtr(src)) {
        for (0..len) |i| {
            dest[i] = src[i];
        }
    } else {
        for (0..len) |i| {
            dest[len - 1 - i] = src[len - 1 - i];
        }
    }

    return dest;
}

fn memmoveFast(dest: ?[*]u8, src: ?[*]u8, len: usize) callconv(.C) ?[*]u8 {
    @setRuntimeSafety(builtin.is_test);
    const small_limit = @max(2 * @sizeOf(Element), @sizeOf(Element));

    if (copySmallLength(small_limit, dest.?, src.?, len)) return dest;

    const dest_address = @intFromPtr(dest);
    const src_address = @intFromPtr(src);

    if (src_address < dest_address) {
        copyBackwards(dest.?, src.?, len);
    } else {
        copyForwards(dest.?, src.?, len);
    }

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
    @setRuntimeSafety(builtin.is_test);
    if (len < 4) {
        if (len == 0) return;
        const b = len / 2;
        const d0 = src[0];
        const db = src[b];
        const de = src[len - 1];
        dest[0] = d0;
        dest[b] = db;
        dest[len - 1] = de;
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
    @setRuntimeSafety(builtin.is_test);
    inline for (2..(std.math.log2(small_limit) + 1) / 2 + 1) |p| {
        const limit = 1 << (2 * p);
        if (len < limit) {
            copyRange4(limit / 4, dest, src, len);
            return true;
        }
    }
    return false;
}

/// copy `len` bytes from `src` to `dest`; `len` must be in the range
/// `[copy_len, 4 * copy_len)`.
inline fn copyRange4(
    comptime copy_len: comptime_int,
    dest: [*]u8,
    src: [*]const u8,
    len: usize,
) void {
    @setRuntimeSafety(builtin.is_test);
    comptime assert(std.math.isPowerOfTwo(copy_len));
    assert(len >= copy_len);
    assert(len < 4 * copy_len);

    const a = len & (copy_len * 2);
    const b = a / 2;

    const last = len - copy_len;
    const pen = last - b;

    const d0 = src[0..copy_len].*;
    const d1 = src[b..][0..copy_len].*;
    const d2 = src[pen..][0..copy_len].*;
    const d3 = src[last..][0..copy_len].*;

    // the slice dest[0..len] is needed to workaround -ODebug miscompilation
    dest[0..len][0..copy_len].* = d0;
    dest[b..][0..copy_len].* = d1;
    dest[pen..][0..copy_len].* = d2;
    dest[last..][0..copy_len].* = d3;
}

inline fn copyForwards(
    dest: [*]u8,
    src: [*]const u8,
    len: usize,
) void {
    @setRuntimeSafety(builtin.is_test);
    assert(len >= 2 * @sizeOf(Element));

    const head = src[0..@sizeOf(Element)].*;
    const tail = src[len - @sizeOf(Element) ..][0..@sizeOf(Element)].*;
    const alignment_offset = @alignOf(Element) - @intFromPtr(src) % @alignOf(Element);
    const n = len - alignment_offset;
    const d = dest + alignment_offset;
    const s = src + alignment_offset;

    copyBlocksAlignedSource(@ptrCast(d), @alignCast(@ptrCast(s)), n);

    // copy last `copy_size` bytes unconditionally, since block copy
    // methods only copy a multiple of `copy_size` bytes.
    dest[len - @sizeOf(Element) ..][0..@sizeOf(Element)].* = tail;
    dest[0..@sizeOf(Element)].* = head;
}

inline fn copyBlocksAlignedSource(
    dest: [*]align(1) Element,
    src: [*]const Element,
    max_bytes: usize,
) void {
    copyBlocks(dest, src, max_bytes);
}

/// Copies the largest multiple of `@sizeOf(T)` bytes from `src` to `dest`,
/// that is less than `max_bytes` where `T` is the child type of `src` and
/// `dest`; `max_bytes` must be at least `@sizeOf(T)`.
inline fn copyBlocks(
    dest: anytype,
    src: anytype,
    max_bytes: usize,
) void {
    @setRuntimeSafety(builtin.is_test);

    const T = @typeInfo(@TypeOf(dest)).pointer.child;
    comptime assert(T == @typeInfo(@TypeOf(src)).pointer.child);

    const loop_count = max_bytes / @sizeOf(T);

    for (dest[0..loop_count], src[0..loop_count]) |*d, s| {
        d.* = s;
    }
}

inline fn copyBackwards(
    dest: [*]u8,
    src: [*]const u8,
    len: usize,
) void {
    const end_bytes = src[len - @sizeOf(Element) ..][0..@sizeOf(Element)].*;
    const start_bytes = src[0..@sizeOf(Element)].*;

    const d_addr: usize = std.mem.alignBackward(usize, @intFromPtr(dest) + len, @alignOf(Element));
    const d: [*]Element = @ptrFromInt(d_addr);
    const n = d_addr - @intFromPtr(dest);
    const s: [*]align(1) const Element = @ptrCast(src + n);

    const loop_count = n / @sizeOf(Element);
    var i: usize = 1;
    while (i < loop_count + 1) : (i += 1) {
        (d - i)[0] = (s - i)[0];
    }

    dest[0..@sizeOf(Element)].* = start_bytes;
    dest[len - @sizeOf(Element) ..][0..@sizeOf(Element)].* = end_bytes;
}

test memmoveFast {
    const max_len = 1024;
    var buffer: [max_len + @alignOf(Element) - 1]u8 = undefined;
    for (&buffer, 0..) |*b, i| {
        b.* = @intCast(i % 97);
    }

    var move_buffer: [max_len + @alignOf(Element) - 1]u8 align(@alignOf(Element)) = undefined;

    for (0..max_len) |copy_len| {
        for (0..@alignOf(Element)) |s_offset| {
            for (0..@alignOf(Element)) |d_offset| {
                for (&move_buffer, buffer) |*d, s| {
                    d.* = s;
                }
                const dest = move_buffer[d_offset..][0..copy_len];
                const src = move_buffer[s_offset..][0..copy_len];
                _ = memmoveFast(dest.ptr, src.ptr, copy_len);
                std.testing.expectEqualSlices(u8, buffer[s_offset..][0..copy_len], dest) catch |e| {
                    std.debug.print(
                        "error occured with source offset {d} and destination offset {d}\n",
                        .{
                            s_offset,
                            d_offset,
                        },
                    );
                    return e;
                };
            }
        }
    }
}
