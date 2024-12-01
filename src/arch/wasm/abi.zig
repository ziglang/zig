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
pub const Class = enum { direct, indirect, none };

const none: [2]Class = .{ .none, .none };
const memory: [2]Class = .{ .indirect, .none };
const direct: [2]Class = .{ .direct, .none };

/// Classifies a given Zig type to determine how they must be passed
/// or returned as value within a wasm function.
/// When all elements result in `.none`, no value must be passed in or returned.
pub fn classifyType(ty: Type, zcu: *Zcu) [2]Class {
    const ip = &zcu.intern_pool;
    const target = zcu.getTarget();
    if (!ty.hasRuntimeBitsIgnoreComptime(zcu)) return none;
    switch (ty.zigTypeTag(zcu)) {
        .@"struct" => {
            const struct_type = zcu.typeToStruct(ty).?;
            if (struct_type.layout == .@"packed") {
                if (ty.bitSize(zcu) <= 64) return direct;
                return .{ .direct, .direct };
            }
            if (struct_type.field_types.len > 1) {
                // The struct type is non-scalar.
                return memory;
            }
            const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[0]);
            const explicit_align = struct_type.fieldAlign(ip, 0);
            if (explicit_align != .none) {
                if (explicit_align.compareStrict(.gt, field_ty.abiAlignment(zcu)))
                    return memory;
            }
            return classifyType(field_ty, zcu);
        },
        .int, .@"enum", .error_set => {
            const int_bits = ty.intInfo(zcu).bits;
            if (int_bits <= 64) return direct;
            if (int_bits <= 128) return .{ .direct, .direct };
            return memory;
        },
        .float => {
            const float_bits = ty.floatBits(target);
            if (float_bits <= 64) return direct;
            if (float_bits <= 128) return .{ .direct, .direct };
            return memory;
        },
        .bool => return direct,
        .vector => return direct,
        .array => return memory,
        .optional => {
            assert(ty.isPtrLikeOptional(zcu));
            return direct;
        },
        .pointer => {
            assert(!ty.isSlice(zcu));
            return direct;
        },
        .@"union" => {
            const union_obj = zcu.typeToUnion(ty).?;
            if (union_obj.flagsUnordered(ip).layout == .@"packed") {
                if (ty.bitSize(zcu) <= 64) return direct;
                return .{ .direct, .direct };
            }
            const layout = ty.unionGetLayout(zcu);
            assert(layout.tag_size == 0);
            if (union_obj.field_types.len > 1) return memory;
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

/// Returns the scalar type a given type can represent.
/// Asserts given type can be represented as scalar, such as
/// a struct with a single scalar field.
pub fn scalarType(ty: Type, zcu: *Zcu) Type {
    const ip = &zcu.intern_pool;
    switch (ty.zigTypeTag(zcu)) {
        .@"struct" => {
            if (zcu.typeToPackedStruct(ty)) |packed_struct| {
                return scalarType(Type.fromInterned(packed_struct.backingIntTypeUnordered(ip)), zcu);
            } else {
                assert(ty.structFieldCount(zcu) == 1);
                return scalarType(ty.fieldType(0, zcu), zcu);
            }
        },
        .@"union" => {
            const union_obj = zcu.typeToUnion(ty).?;
            if (union_obj.flagsUnordered(ip).layout != .@"packed") {
                const layout = Type.getUnionLayout(union_obj, zcu);
                if (layout.payload_size == 0 and layout.tag_size != 0) {
                    return scalarType(ty.unionTagTypeSafety(zcu).?, zcu);
                }
                assert(union_obj.field_types.len == 1);
            }
            const first_field_ty = Type.fromInterned(union_obj.field_types.get(ip)[0]);
            return scalarType(first_field_ty, zcu);
        },
        else => return ty,
    }
}
