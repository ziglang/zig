//! Classifies Zig types to follow the C-ABI for Wasm.
//! The convention for Wasm's C-ABI can be found at the tool-conventions repo:
//! https://github.com/WebAssembly/tool-conventions/blob/main/BasicCABI.md
//! When not targeting the C-ABI, Zig is allowed to do derail from this convention.
//! Note: Above mentioned document is not an official specification, therefore called a convention.

const std = @import("std");
const Target = std.Target;
const assert = std.debug.assert;

const Type = @import("../../type.zig").Type;
const Module = @import("../../Module.zig");

/// Defines how to pass a type as part of a function signature,
/// both for parameters as well as return values.
pub const Class = enum { direct, indirect, none };

const none: [2]Class = .{ .none, .none };
const memory: [2]Class = .{ .indirect, .none };
const direct: [2]Class = .{ .direct, .none };

/// Classifies a given Zig type to determine how they must be passed
/// or returned as value within a wasm function.
/// When all elements result in `.none`, no value must be passed in or returned.
pub fn classifyType(ty: Type, mod: *Module) [2]Class {
    const ip = &mod.intern_pool;
    const target = mod.getTarget();
    if (!ty.hasRuntimeBitsIgnoreComptime(mod)) return none;
    switch (ty.zigTypeTag(mod)) {
        .Struct => {
            const struct_type = mod.typeToStruct(ty).?;
            if (struct_type.layout == .@"packed") {
                if (ty.bitSize(mod) <= 64) return direct;
                return .{ .direct, .direct };
            }
            if (struct_type.field_types.len > 1) {
                // The struct type is non-scalar.
                return memory;
            }
            const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[0]);
            const explicit_align = struct_type.fieldAlign(ip, 0);
            if (explicit_align != .none) {
                if (explicit_align.compareStrict(.gt, field_ty.abiAlignment(mod)))
                    return memory;
            }
            return classifyType(field_ty, mod);
        },
        .Int, .Enum, .ErrorSet => {
            const int_bits = ty.intInfo(mod).bits;
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
            assert(ty.isPtrLikeOptional(mod));
            return direct;
        },
        .Pointer => {
            assert(!ty.isSlice(mod));
            return direct;
        },
        .Union => {
            const union_obj = mod.typeToUnion(ty).?;
            if (union_obj.getLayout(ip) == .@"packed") {
                if (ty.bitSize(mod) <= 64) return direct;
                return .{ .direct, .direct };
            }
            const layout = ty.unionGetLayout(mod);
            assert(layout.tag_size == 0);
            if (union_obj.field_types.len > 1) return memory;
            const first_field_ty = Type.fromInterned(union_obj.field_types.get(ip)[0]);
            return classifyType(first_field_ty, mod);
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
pub fn scalarType(ty: Type, mod: *Module) Type {
    const ip = &mod.intern_pool;
    switch (ty.zigTypeTag(mod)) {
        .Struct => {
            if (mod.typeToPackedStruct(ty)) |packed_struct| {
                return scalarType(Type.fromInterned(packed_struct.backingIntType(ip).*), mod);
            } else {
                assert(ty.structFieldCount(mod) == 1);
                return scalarType(ty.structFieldType(0, mod), mod);
            }
        },
        .Union => {
            const union_obj = mod.typeToUnion(ty).?;
            if (union_obj.getLayout(ip) != .@"packed") {
                const layout = mod.getUnionLayout(union_obj);
                if (layout.payload_size == 0 and layout.tag_size != 0) {
                    return scalarType(ty.unionTagTypeSafety(mod).?, mod);
                }
                assert(union_obj.field_types.len == 1);
            }
            const first_field_ty = Type.fromInterned(union_obj.field_types.get(ip)[0]);
            return scalarType(first_field_ty, mod);
        },
        else => return ty,
    }
}
