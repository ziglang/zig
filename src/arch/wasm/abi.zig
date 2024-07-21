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
pub fn classifyType(ty: Type, pt: Zcu.PerThread) [2]Class {
    const mod = pt.zcu;
    const ip = &mod.intern_pool;
    const target = mod.getTarget();
    if (!ty.hasRuntimeBitsIgnoreComptime(pt)) return none;
    switch (ty.zigTypeTag(mod)) {
        .Struct => {
            const struct_type = pt.zcu.typeToStruct(ty).?;
            if (struct_type.layout == .@"packed") {
                if (ty.bitSize(pt) <= 64) return direct;
                return .{ .direct, .direct };
            }
            if (struct_type.field_types.len > 1) {
                // The struct type is non-scalar.
                return memory;
            }
            const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[0]);
            const explicit_align = struct_type.fieldAlign(ip, 0);
            if (explicit_align != .none) {
                if (explicit_align.compareStrict(.gt, field_ty.abiAlignment(pt)))
                    return memory;
            }
            return classifyType(field_ty, pt);
        },
        .Int, .Enum, .ErrorSet => {
            const int_bits = ty.intInfo(pt.zcu).bits;
            if (int_bits <= 64) return direct;
            if (int_bits <= 128) return .{ .direct, .direct };
            return memory;
        },
        .Float => {
            const float_bits = ty.floatBits(target);
            if (float_bits <= 64) return direct;
            if (float_bits <= 128) return .{ .direct, .direct };
            return memory;
        },
        .Bool => return direct,
        .Vector => return direct,
        .Array => return memory,
        .Optional => {
            assert(ty.isPtrLikeOptional(pt.zcu));
            return direct;
        },
        .Pointer => {
            assert(!ty.isSlice(pt.zcu));
            return direct;
        },
        .Union => {
            const union_obj = pt.zcu.typeToUnion(ty).?;
            if (union_obj.flagsUnordered(ip).layout == .@"packed") {
                if (ty.bitSize(pt) <= 64) return direct;
                return .{ .direct, .direct };
            }
            const layout = ty.unionGetLayout(pt);
            assert(layout.tag_size == 0);
            if (union_obj.field_types.len > 1) return memory;
            const first_field_ty = Type.fromInterned(union_obj.field_types.get(ip)[0]);
            return classifyType(first_field_ty, pt);
        },
        .ErrorUnion,
        .Frame,
        .AnyFrame,
        .NoReturn,
        .Void,
        .Type,
        .ComptimeFloat,
        .ComptimeInt,
        .Undefined,
        .Null,
        .Fn,
        .Opaque,
        .EnumLiteral,
        => unreachable,
    }
}

/// Returns the scalar type a given type can represent.
/// Asserts given type can be represented as scalar, such as
/// a struct with a single scalar field.
pub fn scalarType(ty: Type, pt: Zcu.PerThread) Type {
    const mod = pt.zcu;
    const ip = &mod.intern_pool;
    switch (ty.zigTypeTag(mod)) {
        .Struct => {
            if (mod.typeToPackedStruct(ty)) |packed_struct| {
                return scalarType(Type.fromInterned(packed_struct.backingIntTypeUnordered(ip)), pt);
            } else {
                assert(ty.structFieldCount(mod) == 1);
                return scalarType(ty.structFieldType(0, mod), pt);
            }
        },
        .Union => {
            const union_obj = mod.typeToUnion(ty).?;
            if (union_obj.flagsUnordered(ip).layout != .@"packed") {
                const layout = pt.getUnionLayout(union_obj);
                if (layout.payload_size == 0 and layout.tag_size != 0) {
                    return scalarType(ty.unionTagTypeSafety(mod).?, pt);
                }
                assert(union_obj.field_types.len == 1);
            }
            const first_field_ty = Type.fromInterned(union_obj.field_types.get(ip)[0]);
            return scalarType(first_field_ty, pt);
        },
        else => return ty,
    }
}
