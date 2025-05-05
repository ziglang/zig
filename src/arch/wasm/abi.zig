//! Classifies Zig types to follow the C-ABI for Wasm.
//! The convention for Wasm's C-ABI can be found at the tool-conventions repo:
//! https://github.com/WebAssembly/tool-conventions/blob/main/BasicCABI.md
//! When not targeting the C-ABI, Zig is allowed to do derail from this convention.
//! Note: Above mentioned document is not an official specification, therefore called a convention.

const std = @import("std");
const Target = std.Target;
const assert = std.debug.assert;

const Type = @import("../../Type.zig");
const Zcu = @import("../../Zcu.zig");

/// Defines how to pass a type as part of a function signature,
/// both for parameters as well as return values.
pub const Class = union(enum) {
    direct: Type,
    indirect,
};

/// Classifies a given Zig type to determine how they must be passed
/// or returned as value within a wasm function.
pub fn classifyType(ty: Type, zcu: *const Zcu) Class {
    const ip = &zcu.intern_pool;
    assert(ty.hasRuntimeBitsIgnoreComptime(zcu));
    switch (ty.zigTypeTag(zcu)) {
        .int, .@"enum", .error_set => return .{ .direct = ty },
        .float => return .{ .direct = ty },
        .bool => return .{ .direct = ty },
        .vector => return .{ .direct = ty },
        .array => return .indirect,
        .optional => {
            assert(ty.isPtrLikeOptional(zcu));
            return .{ .direct = ty };
        },
        .pointer => {
            assert(!ty.isSlice(zcu));
            return .{ .direct = ty };
        },
        .@"struct" => {
            const struct_type = zcu.typeToStruct(ty).?;
            if (struct_type.layout == .@"packed") {
                return .{ .direct = ty };
            }
            if (struct_type.field_types.len > 1) {
                // The struct type is non-scalar.
                return .indirect;
            }
            const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[0]);
            const explicit_align = struct_type.fieldAlign(ip, 0);
            if (explicit_align != .none) {
                if (explicit_align.compareStrict(.gt, field_ty.abiAlignment(zcu)))
                    return .indirect;
            }
            return classifyType(field_ty, zcu);
        },
        .@"union" => {
            const union_obj = zcu.typeToUnion(ty).?;
            if (union_obj.flagsUnordered(ip).layout == .@"packed") {
                return .{ .direct = ty };
            }
            const layout = ty.unionGetLayout(zcu);
            assert(layout.tag_size == 0);
            if (union_obj.field_types.len > 1) return .indirect;
            const first_field_ty = Type.fromInterned(union_obj.field_types.get(ip)[0]);
            return classifyType(first_field_ty, zcu);
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
        => unreachable,
    }
}

pub fn lowerAsDoubleI64(scalar_ty: Type, zcu: *const Zcu) bool {
    return scalar_ty.bitSize(zcu) > 64;
}
