const std = @import("std");

const SignedWithVariants = enum(i4) { a, b, _ };

const UnsignedWithVariants = enum(u4) { a, b, _ };

const SignedEmpty = enum(i6) { _ };

const UnsignedEmpty = enum(u6) { _ };

pub fn main() void {
    inline for (.{ SignedWithVariants, UnsignedWithVariants, SignedEmpty, UnsignedEmpty }) |EnumTy| {
        const TagType = @typeInfo(EnumTy).@"enum".tag_type;
        var v: isize = std.math.minInt(TagType);
        while (v < std.math.maxInt(TagType)) : (v += 1) {
            const variant = @as(EnumTy, @enumFromInt(v));
            assert(@as(@TypeOf(v), @intCast(@intFromEnum(variant))) == v);
        }
        const max = std.math.maxInt(TagType);
        const max_variant = @as(EnumTy, @enumFromInt(max));
        assert(@as(@TypeOf(max), @intCast(@intFromEnum(max_variant))) == max);
    }
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

// run
// backend=stage2,llvm
