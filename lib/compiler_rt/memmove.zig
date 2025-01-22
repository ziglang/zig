const std = @import("std");
const common = @import("./common.zig");
const builtin = @import("builtin");

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

pub fn memmoveFast(opt_dest: ?[*]u8, opt_src: ?[*]const u8, len: usize) callconv(.C) ?[*]u8 {
    // a port of https://github.com/facebook/folly/blob/1c8bc50e88804e2a7361a57cd9b551dd10f6c5fd/folly/memcpy.S
    if (len == 0) {
        @branchHint(.unlikely);
        return opt_dest;
    }

    const dest = opt_dest.?;
    const src = opt_src.?;

    if (len < 8) {
        @branchHint(.unlikely);
        if (len == 1) {
            @branchHint(.unlikely);
            dest[0] = src[0];
        } else if (len >= 4) {
            @branchHint(.unlikely);
            blockCopy(dest, src, 4, len);
        } else {
            blockCopy(dest, src, 2, len);
        }
        return dest;
    }

    if (len > 32) {
        @branchHint(.unlikely);
        if (len > 256) {
            @branchHint(.unlikely);
            copyMove(dest, src, len);
            return dest;
        }
        copyLong(dest, src, len);
        return dest;
    }

    if (len > 16) {
        @branchHint(.unlikely);
        blockCopy(dest, src, 16, len);
        return dest;
    }

    blockCopy(dest, src, 8, len);

    return dest;
}

inline fn blockCopy(dest: [*]u8, src: [*]const u8, block_size: comptime_int, len: usize) void {
    const first = @as(*align(1) const @Vector(block_size, u8), src[0..block_size]).*;
    const second = @as(*align(1) const @Vector(block_size, u8), src[len - block_size ..][0..block_size]).*;
    dest[0..block_size].* = first;
    dest[len - block_size ..][0..block_size].* = second;
}

inline fn copyLong(dest: [*]u8, src: [*]const u8, len: usize) void {
    var array: [8]@Vector(32, u8) = undefined;

    inline for (.{ 64, 128, 192, 256 }, 0..) |N, i| {
        array[i * 2] = src[(N / 2) - 32 ..][0..32].*;
        array[(i * 2) + 1] = src[len - N / 2 ..][0..32].*;

        if (len <= N) {
            @branchHint(.unlikely);
            for (0..i + 1) |j| {
                dest[j * 32 ..][0..32].* = array[j * 2];
                dest[len - ((j * 32) + 32) ..][0..32].* = array[(j * 2) + 1];
            }
            return;
        }
    }
}

inline fn copyMove(dest: [*]u8, src: [*]const u8, len: usize) void {
    if (@intFromPtr(src) >= @intFromPtr(dest)) {
        @branchHint(.unlikely);
        copyForward(dest, src, len);
    } else if (@intFromPtr(src) + len > @intFromPtr(dest)) {
        @branchHint(.unlikely);
        overlapBwd(dest, src, len);
    } else {
        copyForward(dest, src, len);
    }
}

inline fn copyForward(dest: [*]u8, src: [*]const u8, len: usize) void {
    const tail: @Vector(32, u8) = src[len - 32 ..][0..32].*;

    const N: usize = len & ~@as(usize, 127);
    var i: usize = 0;

    while (i < N) : (i += 128) {
        dest[i..][0..32].* = src[i..][0..32].*;
        dest[i + 32 ..][0..32].* = src[i + 32 ..][0..32].*;
        dest[i + 64 ..][0..32].* = src[i + 64 ..][0..32].*;
        dest[i + 96 ..][0..32].* = src[i + 96 ..][0..32].*;
    }

    if (len - i <= 32) {
        @branchHint(.unlikely);
        dest[len - 32 ..][0..32].* = tail;
    } else {
        copyLong(dest[i..], src[i..], len - i);
    }
}

inline fn overlapBwd(dest: [*]u8, src: [*]const u8, len: usize) void {
    var array: [5]@Vector(32, u8) = undefined;
    array[0] = src[len - 32 ..][0..32].*;
    inline for (1..5) |i| array[i] = src[(i - 1) << 5 ..][0..32].*;

    const end: usize = (@intFromPtr(dest) + len - 32) & 31;
    const range = len - end;
    var s = src + range;
    var d = dest + range;

    while (@intFromPtr(s) > @intFromPtr(src + 128)) {
        // zig fmt: off
        const first  = @as(*align(1) const @Vector(32, u8), @ptrCast(s - 32)).*;
        const second = @as(*align(1) const @Vector(32, u8), @ptrCast(s - 64)).*;
        const third  = @as(*align(1) const @Vector(32, u8), @ptrCast(s - 96)).*;
        const fourth = @as(*align(1) const @Vector(32, u8), @ptrCast(s - 128)).*;

        @as(*align(32) @Vector(32, u8), @alignCast(@ptrCast(d - 32))).*  = first;
        @as(*align(32) @Vector(32, u8), @alignCast(@ptrCast(d - 64))).*  = second;
        @as(*align(32) @Vector(32, u8), @alignCast(@ptrCast(d - 96))).*  = third;
        @as(*align(32) @Vector(32, u8), @alignCast(@ptrCast(d - 128))).* = fourth;
        // zig fmt: on

        s -= 128;
        d -= 128;
    }

    inline for (array[1..], 0..) |vec, i| dest[i * 32 ..][0..32].* = vec;
    dest[len - 32 ..][0..32].* = array[0];
}
