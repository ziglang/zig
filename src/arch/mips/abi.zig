const std = @import("std");
const Type = @import("../../Type.zig");
const Zcu = @import("../../Zcu.zig");
const assert = std.debug.assert;

pub const Class = union(enum) {
    memory,
    byval,
    i32_array: u8,
};

pub const Context = enum { ret, arg };

pub fn classifyType(ty: Type, zcu: *Zcu, ctx: Context) Class {
    const target = zcu.getTarget();
    std.debug.assert(ty.hasRuntimeBitsIgnoreComptime(zcu));

    const max_direct_size = target.ptrBitWidth() * 2;
    switch (ty.zigTypeTag(zcu)) {
        .@"struct" => {
            const bit_size = ty.bitSize(zcu);
            if (ty.containerLayout(zcu) == .@"packed") {
                if (bit_size > max_direct_size) return .memory;
                return .byval;
            }
            if (bit_size > max_direct_size) return .memory;
            // TODO: for bit_size <= 32 using byval is more correct, but that needs inreg argument attribute
            const count = @as(u8, @intCast(std.mem.alignForward(u64, bit_size, 32) / 32));
            return .{ .i32_array = count };
        },
        .@"union" => {
            const bit_size = ty.bitSize(zcu);
            if (ty.containerLayout(zcu) == .@"packed") {
                if (bit_size > max_direct_size) return .memory;
                return .byval;
            }
            if (bit_size > max_direct_size) return .memory;

            return .byval;
        },
        .bool => return .byval,
        .float => return .byval,
        .int, .@"enum", .error_set => {
            return .byval;
        },
        .vector => {
            const elem_type = ty.elemType2(zcu);
            switch (elem_type.zigTypeTag(zcu)) {
                .bool, .int => {
                    const bit_size = ty.bitSize(zcu);
                    if (ctx == .ret and bit_size > 128) return .memory;
                    if (bit_size > 512) return .memory;
                    // TODO: byval vector arguments with non power of 2 size need inreg attribute
                    return .byval;
                },
                .float => return .memory,
                else => unreachable,
            }
        },
        .optional => {
            std.debug.assert(ty.isPtrLikeOptional(zcu));
            return .byval;
        },
        .pointer => {
            std.debug.assert(!ty.isSlice(zcu));
            return .byval;
        },
        .error_union,
        .frame,
        .@"anyframe",
        .noreturn,
        .void,
        .type,
        .comptime_float,
        .comptime_int,
        .undefined,
        .null,
        .@"fn",
        .@"opaque",
        .enum_literal,
        .array,
        => unreachable,
    }
}
