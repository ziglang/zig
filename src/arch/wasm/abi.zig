//! Classifies Zig types to follow the C-ABI for Wasm.
//! The convention for Wasm's C-ABI can be found at the tool-conventions repo:
//! https://github.com/WebAssembly/tool-conventions/blob/main/BasicCABI.md
//! When not targeting the C-ABI, Zig is allowed to do derail from this convention.
//! Note: Above mentioned document is not an official specification, therefore called a convention.

const std = @import("std");
const Target = std.Target;

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
    const target = mod.getTarget();
    if (!ty.hasRuntimeBitsIgnoreComptime(mod)) return none;
    switch (ty.zigTypeTag(mod)) {
        .Struct => {
            if (ty.containerLayout(mod) == .Packed) {
                if (ty.bitSize(mod) <= 64) return direct;
                return .{ .direct, .direct };
            }
            // When the struct type is non-scalar
            if (ty.structFieldCount(mod) > 1) return memory;
            // When the struct's alignment is non-natural
            const field = ty.structFields(mod).values()[0];
            if (field.abi_align != .none) {
                if (field.abi_align.toByteUnitsOptional().? > field.ty.abiAlignment(mod)) {
                    return memory;
                }
            }
            return classifyType(field.ty, mod);
        },
        .Int, .Enum, .ErrorSet, .Vector => {
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
        .Array => return memory,
        .Optional => {
            std.debug.assert(ty.isPtrLikeOptional(mod));
            return direct;
        },
        .Pointer => {
            std.debug.assert(!ty.isSlice(mod));
            return direct;
        },
        .Union => {
            if (ty.containerLayout(mod) == .Packed) {
                if (ty.bitSize(mod) <= 64) return direct;
                return .{ .direct, .direct };
            }
            const layout = ty.unionGetLayout(mod);
            std.debug.assert(layout.tag_size == 0);
            if (ty.unionFields(mod).count() > 1) return memory;
            return classifyType(ty.unionFields(mod).values()[0].ty, mod);
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
    switch (ty.zigTypeTag(mod)) {
        .Struct => {
            switch (ty.containerLayout(mod)) {
                .Packed => {
                    const struct_obj = mod.typeToStruct(ty).?;
                    return scalarType(struct_obj.backing_int_ty, mod);
                },
                else => {
                    std.debug.assert(ty.structFieldCount(mod) == 1);
                    return scalarType(ty.structFieldType(0, mod), mod);
                },
            }
        },
        .Union => {
            if (ty.containerLayout(mod) != .Packed) {
                const layout = ty.unionGetLayout(mod);
                if (layout.payload_size == 0 and layout.tag_size != 0) {
                    return scalarType(ty.unionTagTypeSafety(mod).?, mod);
                }
                std.debug.assert(ty.unionFields(mod).count() == 1);
            }
            return scalarType(ty.unionFields(mod).values()[0].ty, mod);
        },
        else => return ty,
    }
}
