//! Classifies Zig types to follow the C-ABI for Wasm.
//! The convention for Wasm's C-ABI can be found at the tool-conventions repo:
//! https://github.com/WebAssembly/tool-conventions/blob/main/BasicCABI.md
//! When not targeting the C-ABI, Zig is allowed to do derail from this convention.
//! Note: Above mentioned document is not an official specification, therefore called a convention.

const std = @import("std");
const Type = @import("../../type.zig").Type;
const Target = std.Target;

/// Defines how to pass a type as part of a function signature,
/// both for parameters as well as return values.
pub const Class = enum { direct, indirect, none };

const none: [2]Class = .{ .none, .none };
const memory: [2]Class = .{ .indirect, .none };
const direct: [2]Class = .{ .direct, .none };

/// Classifies a given Zig type to determine how they must be passed
/// or returned as value within a wasm function.
/// When all elements result in `.none`, no value must be passed in or returned.
pub fn classifyType(ty: Type, target: Target) [2]Class {
    if (!ty.hasRuntimeBitsIgnoreComptime()) return none;
    switch (ty.zigTypeTag()) {
        .Struct => {
            // When the (maybe) scalar type exceeds max 'direct' integer size
            if (ty.abiSize(target) > 8) return memory;
            // When the struct type is non-scalar
            if (ty.structFieldCount() > 1) return memory;
            // When the struct's alignment is non-natural
            const field = ty.structFields().values()[0];
            if (field.abi_align != 0) {
                if (field.abi_align > field.ty.abiAlignment(target)) {
                    return memory;
                }
            }
            if (field.ty.isInt() or field.ty.isAnyFloat()) {
                return direct;
            }
            return classifyType(field.ty, target);
        },
        .Int, .Enum, .ErrorSet, .Vector => {
            const int_bits = ty.intInfo(target).bits;
            if (int_bits <= 64) return direct;
            if (int_bits > 64 and int_bits <= 128) return .{ .direct, .direct };
            return memory;
        },
        .Float => {
            const float_bits = ty.floatBits(target);
            if (float_bits <= 64) return direct;
            if (float_bits > 64 and float_bits <= 128) return .{ .direct, .direct };
            return memory;
        },
        .Bool => return direct,
        .Array => return memory,
        .ErrorUnion => {
            const has_tag = ty.errorUnionSet().hasRuntimeBitsIgnoreComptime();
            const has_pl = ty.errorUnionPayload().hasRuntimeBitsIgnoreComptime();
            if (!has_pl) return direct;
            if (!has_tag) {
                return classifyType(ty.errorUnionPayload(), target);
            }
            return memory;
        },
        .Optional => {
            if (ty.isPtrLikeOptional()) return direct;
            var buf: Type.Payload.ElemType = undefined;
            const pl_has_bits = ty.optionalChild(&buf).hasRuntimeBitsIgnoreComptime();
            if (!pl_has_bits) return direct;
            return memory;
        },
        .Pointer => {
            // Slices act like struct and will be passed by reference
            if (ty.isSlice()) return memory;
            return direct;
        },
        .Union => {
            const layout = ty.unionGetLayout(target);
            if (layout.payload_size == 0 and layout.tag_size != 0) {
                return classifyType(ty.unionTagType().?, target);
            }
            if (ty.unionFields().count() > 1) return memory;
            return classifyType(ty.unionFields().values()[0].ty, target);
        },
        .AnyFrame, .Frame => return direct,

        .NoReturn,
        .Void,
        .Type,
        .ComptimeFloat,
        .ComptimeInt,
        .Undefined,
        .Null,
        .BoundFn,
        .Fn,
        .Opaque,
        .EnumLiteral,
        => unreachable,
    }
}

/// Returns the scalar type a given type can represent.
/// Asserts given type can be represented as scalar, such as
/// a struct with a single scalar field.
pub fn scalarType(ty: Type, target: std.Target) Type {
    switch (ty.zigTypeTag()) {
        .Struct => {
            std.debug.assert(ty.structFieldCount() == 1);
            return scalarType(ty.structFieldType(0), target);
        },
        .Union => {
            const layout = ty.unionGetLayout(target);
            if (layout.payload_size == 0 and layout.tag_size != 0) {
                return scalarType(ty.unionTagType().?, target);
            }
            std.debug.assert(ty.unionFields().count() == 1);
            return scalarType(ty.unionFields().values()[0].ty, target);
        },
        else => return ty,
    }
}
