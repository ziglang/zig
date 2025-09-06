const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");
const Type = @import("Type.zig");
const assert = std.debug.assert;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Target = std.Target;
const Allocator = std.mem.Allocator;
const Zcu = @import("Zcu.zig");
const Sema = @import("Sema.zig");
const InternPool = @import("InternPool.zig");
const print_value = @import("print_value.zig");
const Value = @This();

ip_index: InternPool.Index,

pub fn format(val: Value, writer: *std.Io.Writer) !void {
    _ = val;
    _ = writer;
    @compileError("do not use format values directly; use either fmtDebug or fmtValue");
}

/// This is a debug function. In order to print values in a meaningful way
/// we also need access to the type.
pub fn dump(start_val: Value, w: std.Io.Writer) std.Io.Writer.Error!void {
    try w.print("(interned: {})", .{start_val.toIntern()});
}

pub fn fmtDebug(val: Value) std.fmt.Alt(Value, dump) {
    return .{ .data = val };
}

pub fn fmtValue(val: Value, pt: Zcu.PerThread) std.fmt.Alt(print_value.FormatContext, print_value.format) {
    return .{ .data = .{
        .val = val,
        .pt = pt,
        .opt_sema = null,
        .depth = 3,
    } };
}

pub fn fmtValueSema(val: Value, pt: Zcu.PerThread, sema: *Sema) std.fmt.Alt(print_value.FormatContext, print_value.formatSema) {
    return .{ .data = .{
        .val = val,
        .pt = pt,
        .opt_sema = sema,
        .depth = 3,
    } };
}

pub fn fmtValueSemaFull(ctx: print_value.FormatContext) std.fmt.Alt(print_value.FormatContext, print_value.formatSema) {
    return .{ .data = ctx };
}

/// Converts `val` to a null-terminated string stored in the InternPool.
/// Asserts `val` is an array of `u8`
pub fn toIpString(val: Value, ty: Type, pt: Zcu.PerThread) !InternPool.NullTerminatedString {
    const zcu = pt.zcu;
    assert(ty.zigTypeTag(zcu) == .array);
    assert(ty.childType(zcu).toIntern() == .u8_type);
    const ip = &zcu.intern_pool;
    switch (zcu.intern_pool.indexToKey(val.toIntern()).aggregate.storage) {
        .bytes => |bytes| return bytes.toNullTerminatedString(ty.arrayLen(zcu), ip),
        .elems => return arrayToIpString(val, ty.arrayLen(zcu), pt),
        .repeated_elem => |elem| {
            const byte: u8 = @intCast(Value.fromInterned(elem).toUnsignedInt(zcu));
            const len: u32 = @intCast(ty.arrayLen(zcu));
            const strings = ip.getLocal(pt.tid).getMutableStrings(zcu.gpa);
            try strings.appendNTimes(.{byte}, len);
            return ip.getOrPutTrailingString(zcu.gpa, pt.tid, len, .no_embedded_nulls);
        },
    }
}

/// Asserts that the value is representable as an array of bytes.
/// Copies the value into a freshly allocated slice of memory, which is owned by the caller.
pub fn toAllocatedBytes(val: Value, ty: Type, allocator: Allocator, pt: Zcu.PerThread) ![]u8 {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    return switch (ip.indexToKey(val.toIntern())) {
        .enum_literal => |enum_literal| allocator.dupe(u8, enum_literal.toSlice(ip)),
        .slice => |slice| try arrayToAllocatedBytes(val, Value.fromInterned(slice.len).toUnsignedInt(zcu), allocator, pt),
        .aggregate => |aggregate| switch (aggregate.storage) {
            .bytes => |bytes| try allocator.dupe(u8, bytes.toSlice(ty.arrayLenIncludingSentinel(zcu), ip)),
            .elems => try arrayToAllocatedBytes(val, ty.arrayLen(zcu), allocator, pt),
            .repeated_elem => |elem| {
                const byte: u8 = @intCast(Value.fromInterned(elem).toUnsignedInt(zcu));
                const result = try allocator.alloc(u8, @intCast(ty.arrayLen(zcu)));
                @memset(result, byte);
                return result;
            },
        },
        else => unreachable,
    };
}

fn arrayToAllocatedBytes(val: Value, len: u64, allocator: Allocator, pt: Zcu.PerThread) ![]u8 {
    const result = try allocator.alloc(u8, @intCast(len));
    for (result, 0..) |*elem, i| {
        const elem_val = try val.elemValue(pt, i);
        elem.* = @intCast(elem_val.toUnsignedInt(pt.zcu));
    }
    return result;
}

fn arrayToIpString(val: Value, len_u64: u64, pt: Zcu.PerThread) !InternPool.NullTerminatedString {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const len: u32 = @intCast(len_u64);
    const strings = ip.getLocal(pt.tid).getMutableStrings(gpa);
    try strings.ensureUnusedCapacity(len);
    for (0..len) |i| {
        // I don't think elemValue has the possibility to affect ip.string_bytes. Let's
        // assert just to be sure.
        const prev_len = strings.mutate.len;
        const elem_val = try val.elemValue(pt, i);
        assert(strings.mutate.len == prev_len);
        const byte: u8 = @intCast(elem_val.toUnsignedInt(zcu));
        strings.appendAssumeCapacity(.{byte});
    }
    return ip.getOrPutTrailingString(gpa, pt.tid, len, .no_embedded_nulls);
}

pub fn fromInterned(i: InternPool.Index) Value {
    assert(i != .none);
    return .{ .ip_index = i };
}

pub fn toIntern(val: Value) InternPool.Index {
    assert(val.ip_index != .none);
    return val.ip_index;
}

/// Asserts that the value is representable as a type.
pub fn toType(self: Value) Type {
    return Type.fromInterned(self.toIntern());
}

pub fn intFromEnum(val: Value, ty: Type, pt: Zcu.PerThread) Allocator.Error!Value {
    const ip = &pt.zcu.intern_pool;
    const enum_ty = ip.typeOf(val.toIntern());
    return switch (ip.indexToKey(enum_ty)) {
        // Assume it is already an integer and return it directly.
        .simple_type, .int_type => val,
        .enum_literal => |enum_literal| {
            const field_index = ty.enumFieldIndex(enum_literal, pt.zcu).?;
            switch (ip.indexToKey(ty.toIntern())) {
                // Assume it is already an integer and return it directly.
                .simple_type, .int_type => return val,
                .enum_type => {
                    const enum_type = ip.loadEnumType(ty.toIntern());
                    if (enum_type.values.len != 0) {
                        return Value.fromInterned(enum_type.values.get(ip)[field_index]);
                    } else {
                        // Field index and integer values are the same.
                        return pt.intValue(Type.fromInterned(enum_type.tag_ty), field_index);
                    }
                },
                else => unreachable,
            }
        },
        .enum_type => try pt.getCoerced(val, Type.fromInterned(ip.loadEnumType(enum_ty).tag_ty)),
        else => unreachable,
    };
}

pub const ResolveStrat = Type.ResolveStrat;

/// Asserts the value is an integer.
pub fn toBigInt(val: Value, space: *BigIntSpace, zcu: *Zcu) BigIntConst {
    return val.toBigIntAdvanced(space, .normal, zcu, {}) catch unreachable;
}

pub fn toBigIntSema(val: Value, space: *BigIntSpace, pt: Zcu.PerThread) !BigIntConst {
    return try val.toBigIntAdvanced(space, .sema, pt.zcu, pt.tid);
}

/// Asserts the value is an integer.
pub fn toBigIntAdvanced(
    val: Value,
    space: *BigIntSpace,
    comptime strat: ResolveStrat,
    zcu: *Zcu,
    tid: strat.Tid(),
) Zcu.SemaError!BigIntConst {
    const ip = &zcu.intern_pool;
    return switch (val.toIntern()) {
        .bool_false => BigIntMutable.init(&space.limbs, 0).toConst(),
        .bool_true => BigIntMutable.init(&space.limbs, 1).toConst(),
        .null_value => BigIntMutable.init(&space.limbs, 0).toConst(),
        else => switch (ip.indexToKey(val.toIntern())) {
            .int => |int| switch (int.storage) {
                .u64, .i64, .big_int => int.storage.toBigInt(space),
                .lazy_align, .lazy_size => |ty| {
                    if (strat == .sema) try Type.fromInterned(ty).resolveLayout(strat.pt(zcu, tid));
                    const x = switch (int.storage) {
                        else => unreachable,
                        .lazy_align => Type.fromInterned(ty).abiAlignment(zcu).toByteUnits() orelse 0,
                        .lazy_size => Type.fromInterned(ty).abiSize(zcu),
                    };
                    return BigIntMutable.init(&space.limbs, x).toConst();
                },
            },
            .enum_tag => |enum_tag| Value.fromInterned(enum_tag.int).toBigIntAdvanced(space, strat, zcu, tid),
            .opt, .ptr => BigIntMutable.init(
                &space.limbs,
                (try val.getUnsignedIntInner(strat, zcu, tid)).?,
            ).toConst(),
            .err => |err| BigIntMutable.init(&space.limbs, ip.getErrorValueIfExists(err.name).?).toConst(),
            else => unreachable,
        },
    };
}

pub fn isFuncBody(val: Value, zcu: *Zcu) bool {
    return zcu.intern_pool.isFuncBody(val.toIntern());
}

pub fn getFunction(val: Value, zcu: *Zcu) ?InternPool.Key.Func {
    return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .func => |x| x,
        else => null,
    };
}

pub fn getVariable(val: Value, mod: *Zcu) ?InternPool.Key.Variable {
    return switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .variable => |variable| variable,
        else => null,
    };
}

/// If the value fits in a u64, return it, otherwise null.
/// Asserts not undefined.
pub fn getUnsignedInt(val: Value, zcu: *const Zcu) ?u64 {
    return getUnsignedIntInner(val, .normal, zcu, {}) catch unreachable;
}

/// Asserts the value is an integer and it fits in a u64
pub fn toUnsignedInt(val: Value, zcu: *const Zcu) u64 {
    return getUnsignedInt(val, zcu).?;
}

pub fn getUnsignedIntSema(val: Value, pt: Zcu.PerThread) !?u64 {
    return try val.getUnsignedIntInner(.sema, pt.zcu, pt.tid);
}

/// If the value fits in a u64, return it, otherwise null.
/// Asserts not undefined.
pub fn getUnsignedIntInner(
    val: Value,
    comptime strat: ResolveStrat,
    zcu: strat.ZcuPtr(),
    tid: strat.Tid(),
) !?u64 {
    return switch (val.toIntern()) {
        .undef => unreachable,
        .bool_false => 0,
        .bool_true => 1,
        else => switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            .undef => unreachable,
            .int => |int| switch (int.storage) {
                .big_int => |big_int| big_int.toInt(u64) catch null,
                .u64 => |x| x,
                .i64 => |x| std.math.cast(u64, x),
                .lazy_align => |ty| (try Type.fromInterned(ty).abiAlignmentInner(strat.toLazy(), zcu, tid)).scalar.toByteUnits() orelse 0,
                .lazy_size => |ty| (try Type.fromInterned(ty).abiSizeInner(strat.toLazy(), zcu, tid)).scalar,
            },
            .ptr => |ptr| switch (ptr.base_addr) {
                .int => ptr.byte_offset,
                .field => |field| {
                    const base_addr = (try Value.fromInterned(field.base).getUnsignedIntInner(strat, zcu, tid)) orelse return null;
                    const struct_ty = Value.fromInterned(field.base).typeOf(zcu).childType(zcu);
                    if (strat == .sema) {
                        const pt = strat.pt(zcu, tid);
                        try struct_ty.resolveLayout(pt);
                    }
                    return base_addr + struct_ty.structFieldOffset(@intCast(field.index), zcu) + ptr.byte_offset;
                },
                else => null,
            },
            .opt => |opt| switch (opt.val) {
                .none => 0,
                else => |payload| Value.fromInterned(payload).getUnsignedIntInner(strat, zcu, tid),
            },
            .enum_tag => |enum_tag| return Value.fromInterned(enum_tag.int).getUnsignedIntInner(strat, zcu, tid),
            else => null,
        },
    };
}

/// Asserts the value is an integer and it fits in a u64
pub fn toUnsignedIntSema(val: Value, pt: Zcu.PerThread) !u64 {
    return (try getUnsignedIntInner(val, .sema, pt.zcu, pt.tid)).?;
}

/// Asserts the value is an integer and it fits in a i64
pub fn toSignedInt(val: Value, zcu: *const Zcu) i64 {
    return switch (val.toIntern()) {
        .bool_false => 0,
        .bool_true => 1,
        else => switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            .int => |int| switch (int.storage) {
                .big_int => |big_int| big_int.toInt(i64) catch unreachable,
                .i64 => |x| x,
                .u64 => |x| @intCast(x),
                .lazy_align => |ty| @intCast(Type.fromInterned(ty).abiAlignment(zcu).toByteUnits() orelse 0),
                .lazy_size => |ty| @intCast(Type.fromInterned(ty).abiSize(zcu)),
            },
            else => unreachable,
        },
    };
}

pub fn toBool(val: Value) bool {
    return switch (val.toIntern()) {
        .bool_true => true,
        .bool_false => false,
        else => unreachable,
    };
}

/// Write a Value's contents to `buffer`.
///
/// Asserts that buffer.len >= ty.abiSize(). The buffer is allowed to extend past
/// the end of the value in memory.
pub fn writeToMemory(val: Value, pt: Zcu.PerThread, buffer: []u8) error{
    ReinterpretDeclRef,
    IllDefinedMemoryLayout,
    Unimplemented,
    OutOfMemory,
}!void {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const endian = target.cpu.arch.endian();
    const ip = &zcu.intern_pool;
    const ty = val.typeOf(zcu);
    if (val.isUndef(zcu)) {
        const size: usize = @intCast(ty.abiSize(zcu));
        @memset(buffer[0..size], 0xaa);
        return;
    }
    switch (ty.zigTypeTag(zcu)) {
        .void => {},
        .bool => {
            buffer[0] = @intFromBool(val.toBool());
        },
        .int, .@"enum", .error_set, .pointer => |tag| {
            const int_ty = if (tag == .pointer) int_ty: {
                if (ty.isSlice(zcu)) return error.IllDefinedMemoryLayout;
                if (ip.getBackingAddrTag(val.toIntern()).? != .int) return error.ReinterpretDeclRef;
                break :int_ty Type.usize;
            } else ty;
            const int_info = int_ty.intInfo(zcu);
            const bits = int_info.bits;
            const byte_count: u16 = @intCast((@as(u17, bits) + 7) / 8);

            var bigint_buffer: BigIntSpace = undefined;
            const bigint = val.toBigInt(&bigint_buffer, zcu);
            bigint.writeTwosComplement(buffer[0..byte_count], endian);
        },
        .float => switch (ty.floatBits(target)) {
            16 => std.mem.writeInt(u16, buffer[0..2], @bitCast(val.toFloat(f16, zcu)), endian),
            32 => std.mem.writeInt(u32, buffer[0..4], @bitCast(val.toFloat(f32, zcu)), endian),
            64 => std.mem.writeInt(u64, buffer[0..8], @bitCast(val.toFloat(f64, zcu)), endian),
            80 => std.mem.writeInt(u80, buffer[0..10], @bitCast(val.toFloat(f80, zcu)), endian),
            128 => std.mem.writeInt(u128, buffer[0..16], @bitCast(val.toFloat(f128, zcu)), endian),
            else => unreachable,
        },
        .array => {
            const len = ty.arrayLen(zcu);
            const elem_ty = ty.childType(zcu);
            const elem_size: usize = @intCast(elem_ty.abiSize(zcu));
            var elem_i: usize = 0;
            var buf_off: usize = 0;
            while (elem_i < len) : (elem_i += 1) {
                const elem_val = try val.elemValue(pt, elem_i);
                try elem_val.writeToMemory(pt, buffer[buf_off..]);
                buf_off += elem_size;
            }
        },
        .vector => {
            // We use byte_count instead of abi_size here, so that any padding bytes
            // follow the data bytes, on both big- and little-endian systems.
            const byte_count = (@as(usize, @intCast(ty.bitSize(zcu))) + 7) / 8;
            return writeToPackedMemory(val, ty, pt, buffer[0..byte_count], 0);
        },
        .@"struct" => {
            const struct_type = zcu.typeToStruct(ty) orelse return error.IllDefinedMemoryLayout;
            switch (struct_type.layout) {
                .auto => return error.IllDefinedMemoryLayout,
                .@"extern" => for (0..struct_type.field_types.len) |field_index| {
                    const off: usize = @intCast(ty.structFieldOffset(field_index, zcu));
                    const field_val = Value.fromInterned(switch (ip.indexToKey(val.toIntern()).aggregate.storage) {
                        .bytes => |bytes| {
                            buffer[off] = bytes.at(field_index, ip);
                            continue;
                        },
                        .elems => |elems| elems[field_index],
                        .repeated_elem => |elem| elem,
                    });
                    try writeToMemory(field_val, pt, buffer[off..]);
                },
                .@"packed" => {
                    const byte_count = (@as(usize, @intCast(ty.bitSize(zcu))) + 7) / 8;
                    return writeToPackedMemory(val, ty, pt, buffer[0..byte_count], 0);
                },
            }
        },
        .@"union" => switch (ty.containerLayout(zcu)) {
            .auto => return error.IllDefinedMemoryLayout, // Sema is supposed to have emitted a compile error already
            .@"extern" => {
                if (val.unionTag(zcu)) |union_tag| {
                    const union_obj = zcu.typeToUnion(ty).?;
                    const field_index = zcu.unionTagFieldIndex(union_obj, union_tag).?;
                    const field_type = Type.fromInterned(union_obj.field_types.get(ip)[field_index]);
                    const field_val = try val.fieldValue(pt, field_index);
                    const byte_count: usize = @intCast(field_type.abiSize(zcu));
                    return writeToMemory(field_val, pt, buffer[0..byte_count]);
                } else {
                    const backing_ty = try ty.unionBackingType(pt);
                    const byte_count: usize = @intCast(backing_ty.abiSize(zcu));
                    return writeToMemory(val.unionValue(zcu), pt, buffer[0..byte_count]);
                }
            },
            .@"packed" => {
                const backing_ty = try ty.unionBackingType(pt);
                const byte_count: usize = @intCast(backing_ty.abiSize(zcu));
                return writeToPackedMemory(val, ty, pt, buffer[0..byte_count], 0);
            },
        },
        .optional => {
            if (!ty.isPtrLikeOptional(zcu)) return error.IllDefinedMemoryLayout;
            const opt_val = val.optionalValue(zcu);
            if (opt_val) |some| {
                return some.writeToMemory(pt, buffer);
            } else {
                return writeToMemory(try pt.intValue(Type.usize, 0), pt, buffer);
            }
        },
        else => return error.Unimplemented,
    }
}

/// Write a Value's contents to `buffer`.
///
/// Both the start and the end of the provided buffer must be tight, since
/// big-endian packed memory layouts start at the end of the buffer.
pub fn writeToPackedMemory(
    val: Value,
    ty: Type,
    pt: Zcu.PerThread,
    buffer: []u8,
    bit_offset: usize,
) error{ ReinterpretDeclRef, OutOfMemory }!void {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const target = zcu.getTarget();
    const endian = target.cpu.arch.endian();
    if (val.isUndef(zcu)) {
        const bit_size: usize = @intCast(ty.bitSize(zcu));
        if (bit_size != 0) {
            std.mem.writeVarPackedInt(buffer, bit_offset, bit_size, @as(u1, 0), endian);
        }
        return;
    }
    switch (ty.zigTypeTag(zcu)) {
        .void => {},
        .bool => {
            const byte_index = switch (endian) {
                .little => bit_offset / 8,
                .big => buffer.len - bit_offset / 8 - 1,
            };
            if (val.toBool()) {
                buffer[byte_index] |= (@as(u8, 1) << @as(u3, @intCast(bit_offset % 8)));
            } else {
                buffer[byte_index] &= ~(@as(u8, 1) << @as(u3, @intCast(bit_offset % 8)));
            }
        },
        .int, .@"enum" => {
            if (buffer.len == 0) return;
            const bits = ty.intInfo(zcu).bits;
            if (bits == 0) return;

            switch (ip.indexToKey((try val.intFromEnum(ty, pt)).toIntern()).int.storage) {
                inline .u64, .i64 => |int| std.mem.writeVarPackedInt(buffer, bit_offset, bits, int, endian),
                .big_int => |bigint| bigint.writePackedTwosComplement(buffer, bit_offset, bits, endian),
                .lazy_align => |lazy_align| {
                    const num = Type.fromInterned(lazy_align).abiAlignment(zcu).toByteUnits() orelse 0;
                    std.mem.writeVarPackedInt(buffer, bit_offset, bits, num, endian);
                },
                .lazy_size => |lazy_size| {
                    const num = Type.fromInterned(lazy_size).abiSize(zcu);
                    std.mem.writeVarPackedInt(buffer, bit_offset, bits, num, endian);
                },
            }
        },
        .float => switch (ty.floatBits(target)) {
            16 => std.mem.writePackedInt(u16, buffer, bit_offset, @bitCast(val.toFloat(f16, zcu)), endian),
            32 => std.mem.writePackedInt(u32, buffer, bit_offset, @bitCast(val.toFloat(f32, zcu)), endian),
            64 => std.mem.writePackedInt(u64, buffer, bit_offset, @bitCast(val.toFloat(f64, zcu)), endian),
            80 => std.mem.writePackedInt(u80, buffer, bit_offset, @bitCast(val.toFloat(f80, zcu)), endian),
            128 => std.mem.writePackedInt(u128, buffer, bit_offset, @bitCast(val.toFloat(f128, zcu)), endian),
            else => unreachable,
        },
        .vector => {
            const elem_ty = ty.childType(zcu);
            const elem_bit_size: u16 = @intCast(elem_ty.bitSize(zcu));
            const len: usize = @intCast(ty.arrayLen(zcu));

            var bits: u16 = 0;
            var elem_i: usize = 0;
            while (elem_i < len) : (elem_i += 1) {
                // On big-endian systems, LLVM reverses the element order of vectors by default
                const tgt_elem_i = if (endian == .big) len - elem_i - 1 else elem_i;
                const elem_val = try val.elemValue(pt, tgt_elem_i);
                try elem_val.writeToPackedMemory(elem_ty, pt, buffer, bit_offset + bits);
                bits += elem_bit_size;
            }
        },
        .@"struct" => {
            const struct_type = ip.loadStructType(ty.toIntern());
            // Sema is supposed to have emitted a compile error already in the case of Auto,
            // and Extern is handled in non-packed writeToMemory.
            assert(struct_type.layout == .@"packed");
            var bits: u16 = 0;
            for (0..struct_type.field_types.len) |i| {
                const field_val = Value.fromInterned(switch (ip.indexToKey(val.toIntern()).aggregate.storage) {
                    .bytes => unreachable,
                    .elems => |elems| elems[i],
                    .repeated_elem => |elem| elem,
                });
                const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[i]);
                const field_bits: u16 = @intCast(field_ty.bitSize(zcu));
                try field_val.writeToPackedMemory(field_ty, pt, buffer, bit_offset + bits);
                bits += field_bits;
            }
        },
        .@"union" => {
            const union_obj = zcu.typeToUnion(ty).?;
            switch (union_obj.flagsUnordered(ip).layout) {
                .auto, .@"extern" => unreachable, // Handled in non-packed writeToMemory
                .@"packed" => {
                    if (val.unionTag(zcu)) |union_tag| {
                        const field_index = zcu.unionTagFieldIndex(union_obj, union_tag).?;
                        const field_type = Type.fromInterned(union_obj.field_types.get(ip)[field_index]);
                        const field_val = try val.fieldValue(pt, field_index);
                        return field_val.writeToPackedMemory(field_type, pt, buffer, bit_offset);
                    } else {
                        const backing_ty = try ty.unionBackingType(pt);
                        return val.unionValue(zcu).writeToPackedMemory(backing_ty, pt, buffer, bit_offset);
                    }
                },
            }
        },
        .pointer => {
            assert(!ty.isSlice(zcu)); // No well defined layout.
            if (ip.getBackingAddrTag(val.toIntern()).? != .int) return error.ReinterpretDeclRef;
            return val.writeToPackedMemory(Type.usize, pt, buffer, bit_offset);
        },
        .optional => {
            assert(ty.isPtrLikeOptional(zcu));
            const child = ty.optionalChild(zcu);
            const opt_val = val.optionalValue(zcu);
            if (opt_val) |some| {
                return some.writeToPackedMemory(child, pt, buffer, bit_offset);
            } else {
                return writeToPackedMemory(try pt.intValue(Type.usize, 0), Type.usize, pt, buffer, bit_offset);
            }
        },
        else => @panic("TODO implement writeToPackedMemory for more types"),
    }
}

/// Load a Value from the contents of `buffer`.
///
/// Asserts that buffer.len >= ty.abiSize(). The buffer is allowed to extend past
/// the end of the value in memory.
pub fn readFromMemory(
    ty: Type,
    pt: Zcu.PerThread,
    buffer: []const u8,
    arena: Allocator,
) error{
    IllDefinedMemoryLayout,
    Unimplemented,
    OutOfMemory,
}!Value {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const target = zcu.getTarget();
    const endian = target.cpu.arch.endian();
    switch (ty.zigTypeTag(zcu)) {
        .void => return Value.void,
        .bool => {
            if (buffer[0] == 0) {
                return Value.false;
            } else {
                return Value.true;
            }
        },
        .int, .@"enum" => |ty_tag| {
            const int_ty = switch (ty_tag) {
                .int => ty,
                .@"enum" => ty.intTagType(zcu),
                else => unreachable,
            };
            const int_info = int_ty.intInfo(zcu);
            const bits = int_info.bits;
            const byte_count: u16 = @intCast((@as(u17, bits) + 7) / 8);
            if (bits == 0 or buffer.len == 0) return zcu.getCoerced(try zcu.intValue(int_ty, 0), ty);

            if (bits <= 64) switch (int_info.signedness) { // Fast path for integers <= u64
                .signed => {
                    const val = std.mem.readVarInt(i64, buffer[0..byte_count], endian);
                    const result = (val << @as(u6, @intCast(64 - bits))) >> @as(u6, @intCast(64 - bits));
                    return zcu.getCoerced(try zcu.intValue(int_ty, result), ty);
                },
                .unsigned => {
                    const val = std.mem.readVarInt(u64, buffer[0..byte_count], endian);
                    const result = (val << @as(u6, @intCast(64 - bits))) >> @as(u6, @intCast(64 - bits));
                    return zcu.getCoerced(try zcu.intValue(int_ty, result), ty);
                },
            } else { // Slow path, we have to construct a big-int
                const Limb = std.math.big.Limb;
                const limb_count = (byte_count + @sizeOf(Limb) - 1) / @sizeOf(Limb);
                const limbs_buffer = try arena.alloc(Limb, limb_count);

                var bigint = BigIntMutable.init(limbs_buffer, 0);
                bigint.readTwosComplement(buffer[0..byte_count], bits, endian, int_info.signedness);
                return zcu.getCoerced(try zcu.intValue_big(int_ty, bigint.toConst()), ty);
            }
        },
        .float => return Value.fromInterned(try pt.intern(.{ .float = .{
            .ty = ty.toIntern(),
            .storage = switch (ty.floatBits(target)) {
                16 => .{ .f16 = @bitCast(std.mem.readInt(u16, buffer[0..2], endian)) },
                32 => .{ .f32 = @bitCast(std.mem.readInt(u32, buffer[0..4], endian)) },
                64 => .{ .f64 = @bitCast(std.mem.readInt(u64, buffer[0..8], endian)) },
                80 => .{ .f80 = @bitCast(std.mem.readInt(u80, buffer[0..10], endian)) },
                128 => .{ .f128 = @bitCast(std.mem.readInt(u128, buffer[0..16], endian)) },
                else => unreachable,
            },
        } })),
        .array => {
            const elem_ty = ty.childType(zcu);
            const elem_size = elem_ty.abiSize(zcu);
            const elems = try arena.alloc(InternPool.Index, @intCast(ty.arrayLen(zcu)));
            var offset: usize = 0;
            for (elems) |*elem| {
                elem.* = (try readFromMemory(elem_ty, zcu, buffer[offset..], arena)).toIntern();
                offset += @intCast(elem_size);
            }
            return pt.aggregateValue(ty, elems);
        },
        .vector => {
            // We use byte_count instead of abi_size here, so that any padding bytes
            // follow the data bytes, on both big- and little-endian systems.
            const byte_count = (@as(usize, @intCast(ty.bitSize(zcu))) + 7) / 8;
            return readFromPackedMemory(ty, zcu, buffer[0..byte_count], 0, arena);
        },
        .@"struct" => {
            const struct_type = zcu.typeToStruct(ty).?;
            switch (struct_type.layout) {
                .auto => unreachable, // Sema is supposed to have emitted a compile error already
                .@"extern" => {
                    const field_types = struct_type.field_types;
                    const field_vals = try arena.alloc(InternPool.Index, field_types.len);
                    for (field_vals, 0..) |*field_val, i| {
                        const field_ty = Type.fromInterned(field_types.get(ip)[i]);
                        const off: usize = @intCast(ty.structFieldOffset(i, zcu));
                        const sz: usize = @intCast(field_ty.abiSize(zcu));
                        field_val.* = (try readFromMemory(field_ty, zcu, buffer[off..(off + sz)], arena)).toIntern();
                    }
                    return pt.aggregateValue(ty, field_vals);
                },
                .@"packed" => {
                    const byte_count = (@as(usize, @intCast(ty.bitSize(zcu))) + 7) / 8;
                    return readFromPackedMemory(ty, zcu, buffer[0..byte_count], 0, arena);
                },
            }
        },
        .error_set => {
            const bits = zcu.errorSetBits();
            const byte_count: u16 = @intCast((@as(u17, bits) + 7) / 8);
            const int = std.mem.readVarInt(u64, buffer[0..byte_count], endian);
            const index = (int << @as(u6, @intCast(64 - bits))) >> @as(u6, @intCast(64 - bits));
            const name = zcu.global_error_set.keys()[@intCast(index)];

            return Value.fromInterned(try pt.intern(.{ .err = .{
                .ty = ty.toIntern(),
                .name = name,
            } }));
        },
        .@"union" => switch (ty.containerLayout(zcu)) {
            .auto => return error.IllDefinedMemoryLayout,
            .@"extern" => {
                const union_size = ty.abiSize(zcu);
                const array_ty = try zcu.arrayType(.{ .len = union_size, .child = .u8_type });
                const val = (try readFromMemory(array_ty, zcu, buffer, arena)).toIntern();
                return Value.fromInterned(try pt.internUnion(.{
                    .ty = ty.toIntern(),
                    .tag = .none,
                    .val = val,
                }));
            },
            .@"packed" => {
                const byte_count = (@as(usize, @intCast(ty.bitSize(zcu))) + 7) / 8;
                return readFromPackedMemory(ty, zcu, buffer[0..byte_count], 0, arena);
            },
        },
        .pointer => {
            assert(!ty.isSlice(zcu)); // No well defined layout.
            const int_val = try readFromMemory(Type.usize, zcu, buffer, arena);
            return Value.fromInterned(try pt.intern(.{ .ptr = .{
                .ty = ty.toIntern(),
                .base_addr = .int,
                .byte_offset = int_val.toUnsignedInt(zcu),
            } }));
        },
        .optional => {
            assert(ty.isPtrLikeOptional(zcu));
            const child_ty = ty.optionalChild(zcu);
            const child_val = try readFromMemory(child_ty, zcu, buffer, arena);
            return Value.fromInterned(try pt.intern(.{ .opt = .{
                .ty = ty.toIntern(),
                .val = switch (child_val.orderAgainstZero(pt)) {
                    .lt => unreachable,
                    .eq => .none,
                    .gt => child_val.toIntern(),
                },
            } }));
        },
        else => return error.Unimplemented,
    }
}

/// Load a Value from the contents of `buffer`.
///
/// Both the start and the end of the provided buffer must be tight, since
/// big-endian packed memory layouts start at the end of the buffer.
pub fn readFromPackedMemory(
    ty: Type,
    pt: Zcu.PerThread,
    buffer: []const u8,
    bit_offset: usize,
    arena: Allocator,
) error{
    IllDefinedMemoryLayout,
    OutOfMemory,
}!Value {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const target = zcu.getTarget();
    const endian = target.cpu.arch.endian();
    switch (ty.zigTypeTag(zcu)) {
        .void => return Value.void,
        .bool => {
            const byte = switch (endian) {
                .big => buffer[buffer.len - bit_offset / 8 - 1],
                .little => buffer[bit_offset / 8],
            };
            if (((byte >> @as(u3, @intCast(bit_offset % 8))) & 1) == 0) {
                return Value.false;
            } else {
                return Value.true;
            }
        },
        .int => {
            if (buffer.len == 0) return pt.intValue(ty, 0);
            const int_info = ty.intInfo(zcu);
            const bits = int_info.bits;
            if (bits == 0) return pt.intValue(ty, 0);

            // Fast path for integers <= u64
            if (bits <= 64) switch (int_info.signedness) {
                // Use different backing types for unsigned vs signed to avoid the need to go via
                // a larger type like `i128`.
                .unsigned => return pt.intValue(ty, std.mem.readVarPackedInt(u64, buffer, bit_offset, bits, endian, .unsigned)),
                .signed => return pt.intValue(ty, std.mem.readVarPackedInt(i64, buffer, bit_offset, bits, endian, .signed)),
            };

            // Slow path, we have to construct a big-int
            const abi_size: usize = @intCast(ty.abiSize(zcu));
            const Limb = std.math.big.Limb;
            const limb_count = (abi_size + @sizeOf(Limb) - 1) / @sizeOf(Limb);
            const limbs_buffer = try arena.alloc(Limb, limb_count);

            var bigint = BigIntMutable.init(limbs_buffer, 0);
            bigint.readPackedTwosComplement(buffer, bit_offset, bits, endian, int_info.signedness);
            return pt.intValue_big(ty, bigint.toConst());
        },
        .@"enum" => {
            const int_ty = ty.intTagType(zcu);
            const int_val = try Value.readFromPackedMemory(int_ty, pt, buffer, bit_offset, arena);
            return pt.getCoerced(int_val, ty);
        },
        .float => return Value.fromInterned(try pt.intern(.{ .float = .{
            .ty = ty.toIntern(),
            .storage = switch (ty.floatBits(target)) {
                16 => .{ .f16 = @bitCast(std.mem.readPackedInt(u16, buffer, bit_offset, endian)) },
                32 => .{ .f32 = @bitCast(std.mem.readPackedInt(u32, buffer, bit_offset, endian)) },
                64 => .{ .f64 = @bitCast(std.mem.readPackedInt(u64, buffer, bit_offset, endian)) },
                80 => .{ .f80 = @bitCast(std.mem.readPackedInt(u80, buffer, bit_offset, endian)) },
                128 => .{ .f128 = @bitCast(std.mem.readPackedInt(u128, buffer, bit_offset, endian)) },
                else => unreachable,
            },
        } })),
        .vector => {
            const elem_ty = ty.childType(zcu);
            const elems = try arena.alloc(InternPool.Index, @intCast(ty.arrayLen(zcu)));

            var bits: u16 = 0;
            const elem_bit_size: u16 = @intCast(elem_ty.bitSize(zcu));
            for (elems, 0..) |_, i| {
                // On big-endian systems, LLVM reverses the element order of vectors by default
                const tgt_elem_i = if (endian == .big) elems.len - i - 1 else i;
                elems[tgt_elem_i] = (try readFromPackedMemory(elem_ty, pt, buffer, bit_offset + bits, arena)).toIntern();
                bits += elem_bit_size;
            }
            return pt.aggregateValue(ty, elems);
        },
        .@"struct" => {
            // Sema is supposed to have emitted a compile error already for Auto layout structs,
            // and Extern is handled by non-packed readFromMemory.
            const struct_type = zcu.typeToPackedStruct(ty).?;
            var bits: u16 = 0;
            const field_vals = try arena.alloc(InternPool.Index, struct_type.field_types.len);
            for (field_vals, 0..) |*field_val, i| {
                const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[i]);
                const field_bits: u16 = @intCast(field_ty.bitSize(zcu));
                field_val.* = (try readFromPackedMemory(field_ty, pt, buffer, bit_offset + bits, arena)).toIntern();
                bits += field_bits;
            }
            return pt.aggregateValue(ty, field_vals);
        },
        .@"union" => switch (ty.containerLayout(zcu)) {
            .auto, .@"extern" => unreachable, // Handled by non-packed readFromMemory
            .@"packed" => {
                const backing_ty = try ty.unionBackingType(pt);
                const val = (try readFromPackedMemory(backing_ty, pt, buffer, bit_offset, arena)).toIntern();
                return Value.fromInterned(try pt.internUnion(.{
                    .ty = ty.toIntern(),
                    .tag = .none,
                    .val = val,
                }));
            },
        },
        .pointer => {
            assert(!ty.isSlice(zcu)); // No well defined layout.
            const int_val = try readFromPackedMemory(Type.usize, pt, buffer, bit_offset, arena);
            return Value.fromInterned(try pt.intern(.{ .ptr = .{
                .ty = ty.toIntern(),
                .base_addr = .int,
                .byte_offset = int_val.toUnsignedInt(zcu),
            } }));
        },
        .optional => {
            assert(ty.isPtrLikeOptional(zcu));
            const child_ty = ty.optionalChild(zcu);
            const child_val = try readFromPackedMemory(child_ty, pt, buffer, bit_offset, arena);
            return Value.fromInterned(try pt.intern(.{ .opt = .{
                .ty = ty.toIntern(),
                .val = switch (child_val.orderAgainstZero(zcu)) {
                    .lt => unreachable,
                    .eq => .none,
                    .gt => child_val.toIntern(),
                },
            } }));
        },
        else => @panic("TODO implement readFromPackedMemory for more types"),
    }
}

/// Asserts that the value is a float or an integer.
pub fn toFloat(val: Value, comptime T: type, zcu: *const Zcu) T {
    return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .int => |int| switch (int.storage) {
            .big_int => |big_int| big_int.toFloat(T, .nearest_even)[0],
            inline .u64, .i64 => |x| {
                if (T == f80) {
                    @panic("TODO we can't lower this properly on non-x86 llvm backend yet");
                }
                return @floatFromInt(x);
            },
            .lazy_align => |ty| @floatFromInt(Type.fromInterned(ty).abiAlignment(zcu).toByteUnits() orelse 0),
            .lazy_size => |ty| @floatFromInt(Type.fromInterned(ty).abiSize(zcu)),
        },
        .float => |float| switch (float.storage) {
            inline else => |x| @floatCast(x),
        },
        else => unreachable,
    };
}

pub fn clz(val: Value, ty: Type, zcu: *Zcu) u64 {
    var bigint_buf: BigIntSpace = undefined;
    const bigint = val.toBigInt(&bigint_buf, zcu);
    return bigint.clz(ty.intInfo(zcu).bits);
}

pub fn ctz(val: Value, ty: Type, zcu: *Zcu) u64 {
    var bigint_buf: BigIntSpace = undefined;
    const bigint = val.toBigInt(&bigint_buf, zcu);
    return bigint.ctz(ty.intInfo(zcu).bits);
}

pub fn popCount(val: Value, ty: Type, zcu: *Zcu) u64 {
    var bigint_buf: BigIntSpace = undefined;
    const bigint = val.toBigInt(&bigint_buf, zcu);
    return @intCast(bigint.popCount(ty.intInfo(zcu).bits));
}

/// Asserts the value is an integer and not undefined.
/// Returns the number of bits the value requires to represent stored in twos complement form.
pub fn intBitCountTwosComp(self: Value, zcu: *Zcu) usize {
    var buffer: BigIntSpace = undefined;
    const big_int = self.toBigInt(&buffer, zcu);
    return big_int.bitCountTwosComp();
}

/// Converts an integer or a float to a float. May result in a loss of information.
/// Caller can find out by equality checking the result against the operand.
pub fn floatCast(val: Value, dest_ty: Type, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    if (val.isUndef(zcu)) return pt.undefValue(dest_ty);
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = dest_ty.toIntern(),
        .storage = switch (dest_ty.floatBits(target)) {
            16 => .{ .f16 = val.toFloat(f16, zcu) },
            32 => .{ .f32 = val.toFloat(f32, zcu) },
            64 => .{ .f64 = val.toFloat(f64, zcu) },
            80 => .{ .f80 = val.toFloat(f80, zcu) },
            128 => .{ .f128 = val.toFloat(f128, zcu) },
            else => unreachable,
        },
    } }));
}

pub fn orderAgainstZero(lhs: Value, zcu: *Zcu) std.math.Order {
    return orderAgainstZeroInner(lhs, .normal, zcu, {}) catch unreachable;
}

pub fn orderAgainstZeroSema(lhs: Value, pt: Zcu.PerThread) !std.math.Order {
    return try orderAgainstZeroInner(lhs, .sema, pt.zcu, pt.tid);
}

pub fn orderAgainstZeroInner(
    lhs: Value,
    comptime strat: ResolveStrat,
    zcu: *Zcu,
    tid: strat.Tid(),
) Zcu.SemaError!std.math.Order {
    return switch (lhs.toIntern()) {
        .bool_false => .eq,
        .bool_true => .gt,
        else => switch (zcu.intern_pool.indexToKey(lhs.toIntern())) {
            .ptr => |ptr| if (ptr.byte_offset > 0) .gt else switch (ptr.base_addr) {
                .nav, .comptime_alloc, .comptime_field => .gt,
                .int => .eq,
                else => unreachable,
            },
            .int => |int| switch (int.storage) {
                .big_int => |big_int| big_int.orderAgainstScalar(0),
                inline .u64, .i64 => |x| std.math.order(x, 0),
                .lazy_align => .gt, // alignment is never 0
                .lazy_size => |ty| return if (Type.fromInterned(ty).hasRuntimeBitsInner(
                    false,
                    strat.toLazy(),
                    zcu,
                    tid,
                ) catch |err| switch (err) {
                    error.NeedLazy => unreachable,
                    else => |e| return e,
                }) .gt else .eq,
            },
            .enum_tag => |enum_tag| Value.fromInterned(enum_tag.int).orderAgainstZeroInner(strat, zcu, tid),
            .float => |float| switch (float.storage) {
                inline else => |x| std.math.order(x, 0),
            },
            .err => .gt, // error values cannot be 0
            else => unreachable,
        },
    };
}

/// Asserts the value is comparable.
pub fn order(lhs: Value, rhs: Value, zcu: *Zcu) std.math.Order {
    return orderAdvanced(lhs, rhs, .normal, zcu, {}) catch unreachable;
}

/// Asserts the value is comparable.
pub fn orderAdvanced(
    lhs: Value,
    rhs: Value,
    comptime strat: ResolveStrat,
    zcu: *Zcu,
    tid: strat.Tid(),
) !std.math.Order {
    const lhs_against_zero = try lhs.orderAgainstZeroInner(strat, zcu, tid);
    const rhs_against_zero = try rhs.orderAgainstZeroInner(strat, zcu, tid);
    switch (lhs_against_zero) {
        .lt => if (rhs_against_zero != .lt) return .lt,
        .eq => return rhs_against_zero.invert(),
        .gt => {},
    }
    switch (rhs_against_zero) {
        .lt => if (lhs_against_zero != .lt) return .gt,
        .eq => return lhs_against_zero,
        .gt => {},
    }

    if (lhs.isFloat(zcu) or rhs.isFloat(zcu)) {
        const lhs_f128 = lhs.toFloat(f128, zcu);
        const rhs_f128 = rhs.toFloat(f128, zcu);
        return std.math.order(lhs_f128, rhs_f128);
    }

    var lhs_bigint_space: BigIntSpace = undefined;
    var rhs_bigint_space: BigIntSpace = undefined;
    const lhs_bigint = try lhs.toBigIntAdvanced(&lhs_bigint_space, strat, zcu, tid);
    const rhs_bigint = try rhs.toBigIntAdvanced(&rhs_bigint_space, strat, zcu, tid);
    return lhs_bigint.order(rhs_bigint);
}

/// Asserts the value is comparable. Does not take a type parameter because it supports
/// comparisons between heterogeneous types.
pub fn compareHetero(lhs: Value, op: std.math.CompareOperator, rhs: Value, zcu: *Zcu) bool {
    return compareHeteroAdvanced(lhs, op, rhs, .normal, zcu, {}) catch unreachable;
}

pub fn compareHeteroSema(lhs: Value, op: std.math.CompareOperator, rhs: Value, pt: Zcu.PerThread) !bool {
    return try compareHeteroAdvanced(lhs, op, rhs, .sema, pt.zcu, pt.tid);
}

pub fn compareHeteroAdvanced(
    lhs: Value,
    op: std.math.CompareOperator,
    rhs: Value,
    comptime strat: ResolveStrat,
    zcu: *Zcu,
    tid: strat.Tid(),
) !bool {
    if (lhs.pointerNav(zcu)) |lhs_nav| {
        if (rhs.pointerNav(zcu)) |rhs_nav| {
            switch (op) {
                .eq => return lhs_nav == rhs_nav,
                .neq => return lhs_nav != rhs_nav,
                else => {},
            }
        } else {
            switch (op) {
                .eq => return false,
                .neq => return true,
                else => {},
            }
        }
    } else if (rhs.pointerNav(zcu)) |_| {
        switch (op) {
            .eq => return false,
            .neq => return true,
            else => {},
        }
    }

    if (lhs.isNan(zcu) or rhs.isNan(zcu)) return op == .neq;
    return (try orderAdvanced(lhs, rhs, strat, zcu, tid)).compare(op);
}

/// Asserts the values are comparable. Both operands have type `ty`.
/// For vectors, returns true if comparison is true for ALL elements.
pub fn compareAll(lhs: Value, op: std.math.CompareOperator, rhs: Value, ty: Type, pt: Zcu.PerThread) !bool {
    const zcu = pt.zcu;
    if (ty.zigTypeTag(zcu) == .vector) {
        const scalar_ty = ty.scalarType(zcu);
        for (0..ty.vectorLen(zcu)) |i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            if (!compareScalar(lhs_elem, op, rhs_elem, scalar_ty, zcu)) {
                return false;
            }
        }
        return true;
    }
    return compareScalar(lhs, op, rhs, ty, zcu);
}

/// Asserts the values are comparable. Both operands have type `ty`.
pub fn compareScalar(
    lhs: Value,
    op: std.math.CompareOperator,
    rhs: Value,
    ty: Type,
    zcu: *Zcu,
) bool {
    return switch (op) {
        .eq => lhs.eql(rhs, ty, zcu),
        .neq => !lhs.eql(rhs, ty, zcu),
        else => compareHetero(lhs, op, rhs, zcu),
    };
}

/// Asserts the value is comparable.
/// For vectors, returns true if comparison is true for ALL elements.
/// Returns `false` if the value or any vector element is undefined.
///
/// Note that `!compareAllWithZero(.eq, ...) != compareAllWithZero(.neq, ...)`
pub fn compareAllWithZero(lhs: Value, op: std.math.CompareOperator, zcu: *Zcu) bool {
    return compareAllWithZeroAdvancedExtra(lhs, op, .normal, zcu, {}) catch unreachable;
}

pub fn compareAllWithZeroSema(
    lhs: Value,
    op: std.math.CompareOperator,
    pt: Zcu.PerThread,
) Zcu.CompileError!bool {
    return compareAllWithZeroAdvancedExtra(lhs, op, .sema, pt.zcu, pt.tid);
}

pub fn compareAllWithZeroAdvancedExtra(
    lhs: Value,
    op: std.math.CompareOperator,
    comptime strat: ResolveStrat,
    zcu: *Zcu,
    tid: strat.Tid(),
) Zcu.CompileError!bool {
    if (lhs.isInf(zcu)) {
        switch (op) {
            .neq => return true,
            .eq => return false,
            .gt, .gte => return !lhs.isNegativeInf(zcu),
            .lt, .lte => return lhs.isNegativeInf(zcu),
        }
    }

    switch (zcu.intern_pool.indexToKey(lhs.toIntern())) {
        .float => |float| switch (float.storage) {
            inline else => |x| if (std.math.isNan(x)) return op == .neq,
        },
        .aggregate => |aggregate| return switch (aggregate.storage) {
            .bytes => |bytes| for (bytes.toSlice(lhs.typeOf(zcu).arrayLenIncludingSentinel(zcu), &zcu.intern_pool)) |byte| {
                if (!std.math.order(byte, 0).compare(op)) break false;
            } else true,
            .elems => |elems| for (elems) |elem| {
                if (!try Value.fromInterned(elem).compareAllWithZeroAdvancedExtra(op, strat, zcu, tid)) break false;
            } else true,
            .repeated_elem => |elem| Value.fromInterned(elem).compareAllWithZeroAdvancedExtra(op, strat, zcu, tid),
        },
        .undef => return false,
        else => {},
    }
    return (try orderAgainstZeroInner(lhs, strat, zcu, tid)).compare(op);
}

pub fn eql(a: Value, b: Value, ty: Type, zcu: *Zcu) bool {
    assert(zcu.intern_pool.typeOf(a.toIntern()) == ty.toIntern());
    assert(zcu.intern_pool.typeOf(b.toIntern()) == ty.toIntern());
    return a.toIntern() == b.toIntern();
}

pub fn canMutateComptimeVarState(val: Value, zcu: *Zcu) bool {
    return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .error_union => |error_union| switch (error_union.val) {
            .err_name => false,
            .payload => |payload| Value.fromInterned(payload).canMutateComptimeVarState(zcu),
        },
        .ptr => |ptr| switch (ptr.base_addr) {
            .nav => false, // The value of a Nav can never reference a comptime alloc.
            .int => false,
            .comptime_alloc => true, // A comptime alloc is either mutable or references comptime-mutable memory.
            .comptime_field => true, // Comptime field pointers are comptime-mutable, albeit only to the "correct" value.
            .eu_payload, .opt_payload => |base| Value.fromInterned(base).canMutateComptimeVarState(zcu),
            .uav => |uav| Value.fromInterned(uav.val).canMutateComptimeVarState(zcu),
            .arr_elem, .field => |base_index| Value.fromInterned(base_index.base).canMutateComptimeVarState(zcu),
        },
        .slice => |slice| return Value.fromInterned(slice.ptr).canMutateComptimeVarState(zcu),
        .opt => |opt| switch (opt.val) {
            .none => false,
            else => |payload| Value.fromInterned(payload).canMutateComptimeVarState(zcu),
        },
        .aggregate => |aggregate| for (aggregate.storage.values()) |elem| {
            if (Value.fromInterned(elem).canMutateComptimeVarState(zcu)) break true;
        } else false,
        .un => |un| Value.fromInterned(un.val).canMutateComptimeVarState(zcu),
        else => false,
    };
}

/// Gets the `Nav` referenced by this pointer.  If the pointer does not point
/// to a `Nav`, or if it points to some part of one (like a field or element),
/// returns null.
pub fn pointerNav(val: Value, zcu: *Zcu) ?InternPool.Nav.Index {
    return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        // TODO: these 3 cases are weird; these aren't pointer values!
        .variable => |v| v.owner_nav,
        .@"extern" => |e| e.owner_nav,
        .func => |func| func.owner_nav,
        .ptr => |ptr| if (ptr.byte_offset == 0) switch (ptr.base_addr) {
            .nav => |nav| nav,
            else => null,
        } else null,
        else => null,
    };
}

pub const slice_ptr_index = 0;
pub const slice_len_index = 1;

pub fn slicePtr(val: Value, zcu: *Zcu) Value {
    return Value.fromInterned(zcu.intern_pool.slicePtr(val.toIntern()));
}

/// Gets the `len` field of a slice value as a `u64`.
/// Resolves the length using `Sema` if necessary.
pub fn sliceLen(val: Value, pt: Zcu.PerThread) !u64 {
    return Value.fromInterned(pt.zcu.intern_pool.sliceLen(val.toIntern())).toUnsignedIntSema(pt);
}

/// Asserts the value is an aggregate, and returns the element value at the given index.
pub fn elemValue(val: Value, pt: Zcu.PerThread, index: usize) Allocator.Error!Value {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .undef => |ty| {
            return Value.fromInterned(try pt.intern(.{ .undef = Type.fromInterned(ty).childType(zcu).toIntern() }));
        },
        .aggregate => |aggregate| {
            const len = ip.aggregateTypeLen(aggregate.ty);
            if (index < len) return Value.fromInterned(switch (aggregate.storage) {
                .bytes => |bytes| try pt.intern(.{ .int = .{
                    .ty = .u8_type,
                    .storage = .{ .u64 = bytes.at(index, ip) },
                } }),
                .elems => |elems| elems[index],
                .repeated_elem => |elem| elem,
            });
            assert(index == len);
            return Type.fromInterned(aggregate.ty).sentinel(zcu).?;
        },
        else => unreachable,
    }
}

pub fn isLazyAlign(val: Value, zcu: *Zcu) bool {
    return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .int => |int| int.storage == .lazy_align,
        else => false,
    };
}

pub fn isLazySize(val: Value, zcu: *Zcu) bool {
    return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .int => |int| int.storage == .lazy_size,
        else => false,
    };
}

// Asserts that the provided start/end are in-bounds.
pub fn sliceArray(
    val: Value,
    sema: *Sema,
    start: usize,
    end: usize,
) error{OutOfMemory}!Value {
    const pt = sema.pt;
    const ip = &pt.zcu.intern_pool;
    return Value.fromInterned(try pt.intern(.{
        .aggregate = .{
            .ty = switch (pt.zcu.intern_pool.indexToKey(pt.zcu.intern_pool.typeOf(val.toIntern()))) {
                .array_type => |array_type| try pt.arrayType(.{
                    .len = @intCast(end - start),
                    .child = array_type.child,
                    .sentinel = if (end == array_type.len) array_type.sentinel else .none,
                }),
                .vector_type => |vector_type| try pt.vectorType(.{
                    .len = @intCast(end - start),
                    .child = vector_type.child,
                }),
                else => unreachable,
            }.toIntern(),
            .storage = switch (ip.indexToKey(val.toIntern()).aggregate.storage) {
                .bytes => |bytes| storage: {
                    try ip.string_bytes.ensureUnusedCapacity(sema.gpa, end - start + 1);
                    break :storage .{ .bytes = try ip.getOrPutString(
                        sema.gpa,
                        bytes.toSlice(end, ip)[start..],
                        .maybe_embedded_nulls,
                    ) };
                },
                // TODO: write something like getCoercedInts to avoid needing to dupe
                .elems => |elems| .{ .elems = try sema.arena.dupe(InternPool.Index, elems[start..end]) },
                .repeated_elem => |elem| .{ .repeated_elem = elem },
            },
        },
    }));
}

pub fn fieldValue(val: Value, pt: Zcu.PerThread, index: usize) !Value {
    const zcu = pt.zcu;
    return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .undef => |ty| Value.fromInterned(try pt.intern(.{
            .undef = Type.fromInterned(ty).fieldType(index, zcu).toIntern(),
        })),
        .aggregate => |aggregate| Value.fromInterned(switch (aggregate.storage) {
            .bytes => |bytes| try pt.intern(.{ .int = .{
                .ty = .u8_type,
                .storage = .{ .u64 = bytes.at(index, &zcu.intern_pool) },
            } }),
            .elems => |elems| elems[index],
            .repeated_elem => |elem| elem,
        }),
        // TODO assert the tag is correct
        .un => |un| Value.fromInterned(un.val),
        else => unreachable,
    };
}

pub fn unionTag(val: Value, zcu: *Zcu) ?Value {
    return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .undef, .enum_tag => val,
        .un => |un| if (un.tag != .none) Value.fromInterned(un.tag) else return null,
        else => unreachable,
    };
}

pub fn unionValue(val: Value, zcu: *Zcu) Value {
    return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .un => |un| Value.fromInterned(un.val),
        else => unreachable,
    };
}

pub fn isUndef(val: Value, zcu: *const Zcu) bool {
    return zcu.intern_pool.isUndef(val.toIntern());
}

/// `val` must have a numeric or vector type.
/// Returns whether `val` is undefined or contains any undefined elements.
/// Returns the index of the first undefined element it encounters
/// or `null` if no element is undefined.
pub fn anyScalarIsUndef(val: Value, zcu: *const Zcu) bool {
    switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .undef => return true,
        .int, .float => return false,
        .aggregate => |agg| {
            assert(Type.fromInterned(agg.ty).zigTypeTag(zcu) == .vector);
            for (agg.storage.values()) |elem_val| {
                if (Value.fromInterned(elem_val).isUndef(zcu)) return true;
            }
            return false;
        },
        else => unreachable,
    }
}

/// `val` must have a numeric or vector type.
/// Returns whether `val` contains any elements equal to zero.
/// Asserts that `val` is not `undefined`, nor a vector containing any `undefined` elements.
pub fn anyScalarIsZero(val: Value, zcu: *Zcu) bool {
    assert(!val.anyScalarIsUndef(zcu));

    switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .int, .float => return val.eqlScalarNum(.zero_comptime_int, zcu),
        .aggregate => |agg| {
            assert(Type.fromInterned(agg.ty).zigTypeTag(zcu) == .vector);
            switch (agg.storage) {
                .bytes => |str| {
                    const len = Type.fromInterned(agg.ty).vectorLen(zcu);
                    const slice = str.toSlice(len, &zcu.intern_pool);
                    return std.mem.indexOfScalar(u8, slice, 0) != null;
                },
                .elems => |elems| {
                    for (elems) |elem| {
                        if (Value.fromInterned(elem).isUndef(zcu)) return true;
                    }
                    return false;
                },
                .repeated_elem => |elem| return Value.fromInterned(elem).isUndef(zcu),
            }
        },
        else => unreachable,
    }
}

/// Asserts the value is not undefined and not unreachable.
/// C pointers with an integer value of 0 are also considered null.
pub fn isNull(val: Value, zcu: *Zcu) bool {
    return switch (val.toIntern()) {
        .undef => unreachable,
        .unreachable_value => unreachable,
        .null_value => true,
        else => return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            .undef => unreachable,
            .ptr => |ptr| switch (ptr.base_addr) {
                .int => ptr.byte_offset == 0,
                else => false,
            },
            .opt => |opt| opt.val == .none,
            else => false,
        },
    };
}

/// Valid only for error (union) types. Asserts the value is not undefined and not unreachable.
pub fn getErrorName(val: Value, zcu: *const Zcu) InternPool.OptionalNullTerminatedString {
    return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .err => |err| err.name.toOptional(),
        .error_union => |error_union| switch (error_union.val) {
            .err_name => |err_name| err_name.toOptional(),
            .payload => .none,
        },
        else => unreachable,
    };
}

pub fn getErrorInt(val: Value, zcu: *Zcu) Zcu.ErrorInt {
    return if (getErrorName(val, zcu).unwrap()) |err_name|
        zcu.intern_pool.getErrorValueIfExists(err_name).?
    else
        0;
}

/// Assumes the type is an error union. Returns true if and only if the value is
/// the error union payload, not an error.
pub fn errorUnionIsPayload(val: Value, zcu: *const Zcu) bool {
    return zcu.intern_pool.indexToKey(val.toIntern()).error_union.val == .payload;
}

/// Value of the optional, null if optional has no payload.
pub fn optionalValue(val: Value, zcu: *const Zcu) ?Value {
    return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .opt => |opt| switch (opt.val) {
            .none => null,
            else => |payload| Value.fromInterned(payload),
        },
        .ptr => val,
        else => unreachable,
    };
}

/// Valid for all types. Asserts the value is not undefined.
pub fn isFloat(self: Value, zcu: *const Zcu) bool {
    return switch (self.toIntern()) {
        .undef => unreachable,
        else => switch (zcu.intern_pool.indexToKey(self.toIntern())) {
            .undef => unreachable,
            .float => true,
            else => false,
        },
    };
}

pub fn floatFromInt(val: Value, arena: Allocator, int_ty: Type, float_ty: Type, zcu: *Zcu) !Value {
    return floatFromIntAdvanced(val, arena, int_ty, float_ty, zcu, .normal) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => unreachable,
    };
}

pub fn floatFromIntAdvanced(
    val: Value,
    arena: Allocator,
    int_ty: Type,
    float_ty: Type,
    pt: Zcu.PerThread,
    comptime strat: ResolveStrat,
) !Value {
    const zcu = pt.zcu;
    if (int_ty.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, int_ty.vectorLen(zcu));
        const scalar_ty = float_ty.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try floatFromIntScalar(elem_val, scalar_ty, pt, strat)).toIntern();
        }
        return pt.aggregateValue(float_ty, result_data);
    }
    return floatFromIntScalar(val, float_ty, pt, strat);
}

pub fn floatFromIntScalar(val: Value, float_ty: Type, pt: Zcu.PerThread, comptime strat: ResolveStrat) !Value {
    return switch (pt.zcu.intern_pool.indexToKey(val.toIntern())) {
        .undef => try pt.undefValue(float_ty),
        .int => |int| switch (int.storage) {
            .big_int => |big_int| pt.floatValue(float_ty, big_int.toFloat(f128, .nearest_even)[0]),
            inline .u64, .i64 => |x| floatFromIntInner(x, float_ty, pt),
            .lazy_align => |ty| floatFromIntInner((try Type.fromInterned(ty).abiAlignmentInner(strat.toLazy(), pt.zcu, pt.tid)).scalar.toByteUnits() orelse 0, float_ty, pt),
            .lazy_size => |ty| floatFromIntInner((try Type.fromInterned(ty).abiSizeInner(strat.toLazy(), pt.zcu, pt.tid)).scalar, float_ty, pt),
        },
        else => unreachable,
    };
}

fn floatFromIntInner(x: anytype, dest_ty: Type, pt: Zcu.PerThread) !Value {
    const target = pt.zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (dest_ty.floatBits(target)) {
        16 => .{ .f16 = @floatFromInt(x) },
        32 => .{ .f32 = @floatFromInt(x) },
        64 => .{ .f64 = @floatFromInt(x) },
        80 => .{ .f80 = @floatFromInt(x) },
        128 => .{ .f128 = @floatFromInt(x) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = dest_ty.toIntern(),
        .storage = storage,
    } }));
}

fn calcLimbLenFloat(scalar: anytype) usize {
    if (scalar == 0) {
        return 1;
    }

    const w_value = @abs(scalar);
    return @divFloor(@as(std.math.big.Limb, @intFromFloat(std.math.log2(w_value))), @typeInfo(std.math.big.Limb).int.bits) + 1;
}

pub const OverflowArithmeticResult = struct {
    overflow_bit: Value,
    wrapped_result: Value,
};

/// Supports both floats and ints; handles undefined.
pub fn numberMax(lhs: Value, rhs: Value, zcu: *Zcu) Value {
    if (lhs.isUndef(zcu) or rhs.isUndef(zcu)) return undef;
    if (lhs.isNan(zcu)) return rhs;
    if (rhs.isNan(zcu)) return lhs;

    return switch (order(lhs, rhs, zcu)) {
        .lt => rhs,
        .gt, .eq => lhs,
    };
}

/// Supports both floats and ints; handles undefined.
pub fn numberMin(lhs: Value, rhs: Value, zcu: *Zcu) Value {
    if (lhs.isUndef(zcu) or rhs.isUndef(zcu)) return undef;
    if (lhs.isNan(zcu)) return rhs;
    if (rhs.isNan(zcu)) return lhs;

    return switch (order(lhs, rhs, zcu)) {
        .lt => lhs,
        .gt, .eq => rhs,
    };
}

/// Returns true if the value is a floating point type and is NaN. Returns false otherwise.
pub fn isNan(val: Value, zcu: *const Zcu) bool {
    return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .float => |float| switch (float.storage) {
            inline else => |x| std.math.isNan(x),
        },
        else => false,
    };
}

/// Returns true if the value is a floating point type and is infinite. Returns false otherwise.
pub fn isInf(val: Value, zcu: *const Zcu) bool {
    return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .float => |float| switch (float.storage) {
            inline else => |x| std.math.isInf(x),
        },
        else => false,
    };
}

/// Returns true if the value is a floating point type and is negative infinite. Returns false otherwise.
pub fn isNegativeInf(val: Value, zcu: *const Zcu) bool {
    return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .float => |float| switch (float.storage) {
            inline else => |x| std.math.isNegativeInf(x),
        },
        else => false,
    };
}

pub fn sqrt(val: Value, float_type: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    if (float_type.zigTypeTag(pt.zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(pt.zcu));
        const scalar_ty = float_type.scalarType(pt.zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try sqrtScalar(elem_val, scalar_ty, pt)).toIntern();
        }
        return pt.aggregateValue(float_type, result_data);
    }
    return sqrtScalar(val, float_type, pt);
}

pub fn sqrtScalar(val: Value, float_type: Type, pt: Zcu.PerThread) Allocator.Error!Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @sqrt(val.toFloat(f16, zcu)) },
        32 => .{ .f32 = @sqrt(val.toFloat(f32, zcu)) },
        64 => .{ .f64 = @sqrt(val.toFloat(f64, zcu)) },
        80 => .{ .f80 = @sqrt(val.toFloat(f80, zcu)) },
        128 => .{ .f128 = @sqrt(val.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn sin(val: Value, float_type: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (float_type.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
        const scalar_ty = float_type.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try sinScalar(elem_val, scalar_ty, pt)).toIntern();
        }
        return pt.aggregateValue(float_type, result_data);
    }
    return sinScalar(val, float_type, pt);
}

pub fn sinScalar(val: Value, float_type: Type, pt: Zcu.PerThread) Allocator.Error!Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @sin(val.toFloat(f16, zcu)) },
        32 => .{ .f32 = @sin(val.toFloat(f32, zcu)) },
        64 => .{ .f64 = @sin(val.toFloat(f64, zcu)) },
        80 => .{ .f80 = @sin(val.toFloat(f80, zcu)) },
        128 => .{ .f128 = @sin(val.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn cos(val: Value, float_type: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (float_type.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
        const scalar_ty = float_type.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try cosScalar(elem_val, scalar_ty, pt)).toIntern();
        }
        return pt.aggregateValue(float_type, result_data);
    }
    return cosScalar(val, float_type, pt);
}

pub fn cosScalar(val: Value, float_type: Type, pt: Zcu.PerThread) Allocator.Error!Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @cos(val.toFloat(f16, zcu)) },
        32 => .{ .f32 = @cos(val.toFloat(f32, zcu)) },
        64 => .{ .f64 = @cos(val.toFloat(f64, zcu)) },
        80 => .{ .f80 = @cos(val.toFloat(f80, zcu)) },
        128 => .{ .f128 = @cos(val.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn tan(val: Value, float_type: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (float_type.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
        const scalar_ty = float_type.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try tanScalar(elem_val, scalar_ty, pt)).toIntern();
        }
        return pt.aggregateValue(float_type, result_data);
    }
    return tanScalar(val, float_type, pt);
}

pub fn tanScalar(val: Value, float_type: Type, pt: Zcu.PerThread) Allocator.Error!Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @tan(val.toFloat(f16, zcu)) },
        32 => .{ .f32 = @tan(val.toFloat(f32, zcu)) },
        64 => .{ .f64 = @tan(val.toFloat(f64, zcu)) },
        80 => .{ .f80 = @tan(val.toFloat(f80, zcu)) },
        128 => .{ .f128 = @tan(val.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn exp(val: Value, float_type: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (float_type.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
        const scalar_ty = float_type.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try expScalar(elem_val, scalar_ty, pt)).toIntern();
        }
        return pt.aggregateValue(float_type, result_data);
    }
    return expScalar(val, float_type, pt);
}

pub fn expScalar(val: Value, float_type: Type, pt: Zcu.PerThread) Allocator.Error!Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @exp(val.toFloat(f16, zcu)) },
        32 => .{ .f32 = @exp(val.toFloat(f32, zcu)) },
        64 => .{ .f64 = @exp(val.toFloat(f64, zcu)) },
        80 => .{ .f80 = @exp(val.toFloat(f80, zcu)) },
        128 => .{ .f128 = @exp(val.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn exp2(val: Value, float_type: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (float_type.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
        const scalar_ty = float_type.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try exp2Scalar(elem_val, scalar_ty, pt)).toIntern();
        }
        return pt.aggregateValue(float_type, result_data);
    }
    return exp2Scalar(val, float_type, pt);
}

pub fn exp2Scalar(val: Value, float_type: Type, pt: Zcu.PerThread) Allocator.Error!Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @exp2(val.toFloat(f16, zcu)) },
        32 => .{ .f32 = @exp2(val.toFloat(f32, zcu)) },
        64 => .{ .f64 = @exp2(val.toFloat(f64, zcu)) },
        80 => .{ .f80 = @exp2(val.toFloat(f80, zcu)) },
        128 => .{ .f128 = @exp2(val.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn log(val: Value, float_type: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (float_type.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
        const scalar_ty = float_type.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try logScalar(elem_val, scalar_ty, pt)).toIntern();
        }
        return pt.aggregateValue(float_type, result_data);
    }
    return logScalar(val, float_type, pt);
}

pub fn logScalar(val: Value, float_type: Type, pt: Zcu.PerThread) Allocator.Error!Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @log(val.toFloat(f16, zcu)) },
        32 => .{ .f32 = @log(val.toFloat(f32, zcu)) },
        64 => .{ .f64 = @log(val.toFloat(f64, zcu)) },
        80 => .{ .f80 = @log(val.toFloat(f80, zcu)) },
        128 => .{ .f128 = @log(val.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn log2(val: Value, float_type: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (float_type.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
        const scalar_ty = float_type.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try log2Scalar(elem_val, scalar_ty, pt)).toIntern();
        }
        return pt.aggregateValue(float_type, result_data);
    }
    return log2Scalar(val, float_type, pt);
}

pub fn log2Scalar(val: Value, float_type: Type, pt: Zcu.PerThread) Allocator.Error!Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @log2(val.toFloat(f16, zcu)) },
        32 => .{ .f32 = @log2(val.toFloat(f32, zcu)) },
        64 => .{ .f64 = @log2(val.toFloat(f64, zcu)) },
        80 => .{ .f80 = @log2(val.toFloat(f80, zcu)) },
        128 => .{ .f128 = @log2(val.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn log10(val: Value, float_type: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (float_type.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
        const scalar_ty = float_type.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try log10Scalar(elem_val, scalar_ty, pt)).toIntern();
        }
        return pt.aggregateValue(float_type, result_data);
    }
    return log10Scalar(val, float_type, pt);
}

pub fn log10Scalar(val: Value, float_type: Type, pt: Zcu.PerThread) Allocator.Error!Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @log10(val.toFloat(f16, zcu)) },
        32 => .{ .f32 = @log10(val.toFloat(f32, zcu)) },
        64 => .{ .f64 = @log10(val.toFloat(f64, zcu)) },
        80 => .{ .f80 = @log10(val.toFloat(f80, zcu)) },
        128 => .{ .f128 = @log10(val.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn abs(val: Value, ty: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (ty.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(zcu));
        const scalar_ty = ty.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try absScalar(elem_val, scalar_ty, pt, arena)).toIntern();
        }
        return pt.aggregateValue(ty, result_data);
    }
    return absScalar(val, ty, pt, arena);
}

pub fn absScalar(val: Value, ty: Type, pt: Zcu.PerThread, arena: Allocator) Allocator.Error!Value {
    const zcu = pt.zcu;
    switch (ty.zigTypeTag(zcu)) {
        .int => {
            var buffer: Value.BigIntSpace = undefined;
            var operand_bigint = try val.toBigInt(&buffer, zcu).toManaged(arena);
            operand_bigint.abs();

            return pt.intValue_big(try ty.toUnsigned(pt), operand_bigint.toConst());
        },
        .comptime_int => {
            var buffer: Value.BigIntSpace = undefined;
            var operand_bigint = try val.toBigInt(&buffer, zcu).toManaged(arena);
            operand_bigint.abs();

            return pt.intValue_big(ty, operand_bigint.toConst());
        },
        .comptime_float, .float => {
            const target = zcu.getTarget();
            const storage: InternPool.Key.Float.Storage = switch (ty.floatBits(target)) {
                16 => .{ .f16 = @abs(val.toFloat(f16, zcu)) },
                32 => .{ .f32 = @abs(val.toFloat(f32, zcu)) },
                64 => .{ .f64 = @abs(val.toFloat(f64, zcu)) },
                80 => .{ .f80 = @abs(val.toFloat(f80, zcu)) },
                128 => .{ .f128 = @abs(val.toFloat(f128, zcu)) },
                else => unreachable,
            };
            return Value.fromInterned(try pt.intern(.{ .float = .{
                .ty = ty.toIntern(),
                .storage = storage,
            } }));
        },
        else => unreachable,
    }
}

pub fn floor(val: Value, float_type: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (float_type.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
        const scalar_ty = float_type.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try floorScalar(elem_val, scalar_ty, pt)).toIntern();
        }
        return pt.aggregateValue(float_type, result_data);
    }
    return floorScalar(val, float_type, pt);
}

pub fn floorScalar(val: Value, float_type: Type, pt: Zcu.PerThread) Allocator.Error!Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @floor(val.toFloat(f16, zcu)) },
        32 => .{ .f32 = @floor(val.toFloat(f32, zcu)) },
        64 => .{ .f64 = @floor(val.toFloat(f64, zcu)) },
        80 => .{ .f80 = @floor(val.toFloat(f80, zcu)) },
        128 => .{ .f128 = @floor(val.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn ceil(val: Value, float_type: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (float_type.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
        const scalar_ty = float_type.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try ceilScalar(elem_val, scalar_ty, pt)).toIntern();
        }
        return pt.aggregateValue(float_type, result_data);
    }
    return ceilScalar(val, float_type, pt);
}

pub fn ceilScalar(val: Value, float_type: Type, pt: Zcu.PerThread) Allocator.Error!Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @ceil(val.toFloat(f16, zcu)) },
        32 => .{ .f32 = @ceil(val.toFloat(f32, zcu)) },
        64 => .{ .f64 = @ceil(val.toFloat(f64, zcu)) },
        80 => .{ .f80 = @ceil(val.toFloat(f80, zcu)) },
        128 => .{ .f128 = @ceil(val.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn round(val: Value, float_type: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (float_type.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
        const scalar_ty = float_type.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try roundScalar(elem_val, scalar_ty, pt)).toIntern();
        }
        return pt.aggregateValue(float_type, result_data);
    }
    return roundScalar(val, float_type, pt);
}

pub fn roundScalar(val: Value, float_type: Type, pt: Zcu.PerThread) Allocator.Error!Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @round(val.toFloat(f16, zcu)) },
        32 => .{ .f32 = @round(val.toFloat(f32, zcu)) },
        64 => .{ .f64 = @round(val.toFloat(f64, zcu)) },
        80 => .{ .f80 = @round(val.toFloat(f80, zcu)) },
        128 => .{ .f128 = @round(val.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn trunc(val: Value, float_type: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (float_type.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
        const scalar_ty = float_type.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try truncScalar(elem_val, scalar_ty, pt)).toIntern();
        }
        return pt.aggregateValue(float_type, result_data);
    }
    return truncScalar(val, float_type, pt);
}

pub fn truncScalar(val: Value, float_type: Type, pt: Zcu.PerThread) Allocator.Error!Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @trunc(val.toFloat(f16, zcu)) },
        32 => .{ .f32 = @trunc(val.toFloat(f32, zcu)) },
        64 => .{ .f64 = @trunc(val.toFloat(f64, zcu)) },
        80 => .{ .f80 = @trunc(val.toFloat(f80, zcu)) },
        128 => .{ .f128 = @trunc(val.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn mulAdd(
    float_type: Type,
    mulend1: Value,
    mulend2: Value,
    addend: Value,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    const zcu = pt.zcu;
    if (float_type.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
        const scalar_ty = float_type.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const mulend1_elem = try mulend1.elemValue(pt, i);
            const mulend2_elem = try mulend2.elemValue(pt, i);
            const addend_elem = try addend.elemValue(pt, i);
            scalar.* = (try mulAddScalar(scalar_ty, mulend1_elem, mulend2_elem, addend_elem, pt)).toIntern();
        }
        return pt.aggregateValue(float_type, result_data);
    }
    return mulAddScalar(float_type, mulend1, mulend2, addend, pt);
}

pub fn mulAddScalar(
    float_type: Type,
    mulend1: Value,
    mulend2: Value,
    addend: Value,
    pt: Zcu.PerThread,
) Allocator.Error!Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @mulAdd(f16, mulend1.toFloat(f16, zcu), mulend2.toFloat(f16, zcu), addend.toFloat(f16, zcu)) },
        32 => .{ .f32 = @mulAdd(f32, mulend1.toFloat(f32, zcu), mulend2.toFloat(f32, zcu), addend.toFloat(f32, zcu)) },
        64 => .{ .f64 = @mulAdd(f64, mulend1.toFloat(f64, zcu), mulend2.toFloat(f64, zcu), addend.toFloat(f64, zcu)) },
        80 => .{ .f80 = @mulAdd(f80, mulend1.toFloat(f80, zcu), mulend2.toFloat(f80, zcu), addend.toFloat(f80, zcu)) },
        128 => .{ .f128 = @mulAdd(f128, mulend1.toFloat(f128, zcu), mulend2.toFloat(f128, zcu), addend.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

/// If the value is represented in-memory as a series of bytes that all
/// have the same value, return that byte value, otherwise null.
pub fn hasRepeatedByteRepr(val: Value, pt: Zcu.PerThread) !?u8 {
    const zcu = pt.zcu;
    const ty = val.typeOf(zcu);
    const abi_size = std.math.cast(usize, ty.abiSize(zcu)) orelse return null;
    assert(abi_size >= 1);
    const byte_buffer = try zcu.gpa.alloc(u8, abi_size);
    defer zcu.gpa.free(byte_buffer);

    writeToMemory(val, pt, byte_buffer) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.ReinterpretDeclRef => return null,
        // TODO: The writeToMemory function was originally created for the purpose
        // of comptime pointer casting. However, it is now additionally being used
        // for checking the actual memory layout that will be generated by machine
        // code late in compilation. So, this error handling is too aggressive and
        // causes some false negatives, causing less-than-ideal code generation.
        error.IllDefinedMemoryLayout => return null,
        error.Unimplemented => return null,
    };
    const first_byte = byte_buffer[0];
    for (byte_buffer[1..]) |byte| {
        if (byte != first_byte) return null;
    }
    return first_byte;
}

pub fn typeOf(val: Value, zcu: *const Zcu) Type {
    return Type.fromInterned(zcu.intern_pool.typeOf(val.toIntern()));
}

/// For an integer (comptime or fixed-width) `val`, returns the comptime-known bounds of the value.
/// If `val` is not undef, the bounds are both `val`.
/// If `val` is undef and has a fixed-width type, the bounds are the bounds of the type.
/// If `val` is undef and is a `comptime_int`, returns null.
pub fn intValueBounds(val: Value, pt: Zcu.PerThread) !?[2]Value {
    if (!val.isUndef(pt.zcu)) return .{ val, val };
    const ty = pt.zcu.intern_pool.typeOf(val.toIntern());
    if (ty == .comptime_int_type) return null;
    return .{
        try Type.fromInterned(ty).minInt(pt, Type.fromInterned(ty)),
        try Type.fromInterned(ty).maxInt(pt, Type.fromInterned(ty)),
    };
}

pub const BigIntSpace = InternPool.Key.Int.Storage.BigIntSpace;

pub const undef: Value = .{ .ip_index = .undef };
pub const undef_bool: Value = .{ .ip_index = .undef_bool };
pub const undef_usize: Value = .{ .ip_index = .undef_usize };
pub const undef_u1: Value = .{ .ip_index = .undef_u1 };
pub const zero_comptime_int: Value = .{ .ip_index = .zero };
pub const zero_usize: Value = .{ .ip_index = .zero_usize };
pub const zero_u1: Value = .{ .ip_index = .zero_u1 };
pub const zero_u8: Value = .{ .ip_index = .zero_u8 };
pub const one_comptime_int: Value = .{ .ip_index = .one };
pub const one_usize: Value = .{ .ip_index = .one_usize };
pub const one_u1: Value = .{ .ip_index = .one_u1 };
pub const one_u8: Value = .{ .ip_index = .one_u8 };
pub const four_u8: Value = .{ .ip_index = .four_u8 };
pub const negative_one_comptime_int: Value = .{ .ip_index = .negative_one };
pub const @"void": Value = .{ .ip_index = .void_value };
pub const @"unreachable": Value = .{ .ip_index = .unreachable_value };
pub const @"null": Value = .{ .ip_index = .null_value };
pub const @"true": Value = .{ .ip_index = .bool_true };
pub const @"false": Value = .{ .ip_index = .bool_false };
pub const empty_tuple: Value = .{ .ip_index = .empty_tuple };

pub fn makeBool(x: bool) Value {
    return if (x) .true else .false;
}

/// `parent_ptr` must be a single-pointer to some optional.
/// Returns a pointer to the payload of the optional.
/// May perform type resolution.
pub fn ptrOptPayload(parent_ptr: Value, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    const parent_ptr_ty = parent_ptr.typeOf(zcu);
    const opt_ty = parent_ptr_ty.childType(zcu);

    assert(parent_ptr_ty.ptrSize(zcu) == .one);
    assert(opt_ty.zigTypeTag(zcu) == .optional);

    const result_ty = try pt.ptrTypeSema(info: {
        var new = parent_ptr_ty.ptrInfo(zcu);
        // We can correctly preserve alignment `.none`, since an optional has the same
        // natural alignment as its child type.
        new.child = opt_ty.childType(zcu).toIntern();
        break :info new;
    });

    if (parent_ptr.isUndef(zcu)) return pt.undefValue(result_ty);

    if (opt_ty.isPtrLikeOptional(zcu)) {
        // Just reinterpret the pointer, since the layout is well-defined
        return pt.getCoerced(parent_ptr, result_ty);
    }

    const base_ptr = try parent_ptr.canonicalizeBasePtr(.one, opt_ty, pt);
    return Value.fromInterned(try pt.intern(.{ .ptr = .{
        .ty = result_ty.toIntern(),
        .base_addr = .{ .opt_payload = base_ptr.toIntern() },
        .byte_offset = 0,
    } }));
}

/// `parent_ptr` must be a single-pointer to some error union.
/// Returns a pointer to the payload of the error union.
/// May perform type resolution.
pub fn ptrEuPayload(parent_ptr: Value, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    const parent_ptr_ty = parent_ptr.typeOf(zcu);
    const eu_ty = parent_ptr_ty.childType(zcu);

    assert(parent_ptr_ty.ptrSize(zcu) == .one);
    assert(eu_ty.zigTypeTag(zcu) == .error_union);

    const result_ty = try pt.ptrTypeSema(info: {
        var new = parent_ptr_ty.ptrInfo(zcu);
        // We can correctly preserve alignment `.none`, since an error union has a
        // natural alignment greater than or equal to that of its payload type.
        new.child = eu_ty.errorUnionPayload(zcu).toIntern();
        break :info new;
    });

    if (parent_ptr.isUndef(zcu)) return pt.undefValue(result_ty);

    const base_ptr = try parent_ptr.canonicalizeBasePtr(.one, eu_ty, pt);
    return Value.fromInterned(try pt.intern(.{ .ptr = .{
        .ty = result_ty.toIntern(),
        .base_addr = .{ .eu_payload = base_ptr.toIntern() },
        .byte_offset = 0,
    } }));
}

/// `parent_ptr` must be a single-pointer to a struct, union, or slice.
/// Returns a pointer to the aggregate field at the specified index.
/// For slices, uses `slice_ptr_index` and `slice_len_index`.
/// May perform type resolution.
pub fn ptrField(parent_ptr: Value, field_idx: u32, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    const parent_ptr_ty = parent_ptr.typeOf(zcu);
    const aggregate_ty = parent_ptr_ty.childType(zcu);

    const parent_ptr_info = parent_ptr_ty.ptrInfo(zcu);
    assert(parent_ptr_info.flags.size == .one or parent_ptr_info.flags.size == .c);

    // Exiting this `switch` indicates that the `field` pointer representation should be used.
    // `field_align` may be `.none` to represent the natural alignment of `field_ty`, but is not necessarily.
    const field_ty: Type, const field_align: InternPool.Alignment = switch (aggregate_ty.zigTypeTag(zcu)) {
        .@"struct" => field: {
            const field_ty = aggregate_ty.fieldType(field_idx, zcu);
            switch (aggregate_ty.containerLayout(zcu)) {
                .auto => break :field .{ field_ty, try aggregate_ty.fieldAlignmentSema(field_idx, pt) },
                .@"extern" => {
                    // Well-defined layout, so just offset the pointer appropriately.
                    try aggregate_ty.resolveLayout(pt);
                    const byte_off = aggregate_ty.structFieldOffset(field_idx, zcu);
                    const field_align = a: {
                        const parent_align = if (parent_ptr_info.flags.alignment == .none) pa: {
                            break :pa try aggregate_ty.abiAlignmentSema(pt);
                        } else parent_ptr_info.flags.alignment;
                        break :a InternPool.Alignment.fromLog2Units(@min(parent_align.toLog2Units(), @ctz(byte_off)));
                    };
                    const result_ty = try pt.ptrTypeSema(info: {
                        var new = parent_ptr_info;
                        new.child = field_ty.toIntern();
                        new.flags.alignment = field_align;
                        break :info new;
                    });
                    return parent_ptr.getOffsetPtr(byte_off, result_ty, pt);
                },
                .@"packed" => switch (aggregate_ty.packedStructFieldPtrInfo(parent_ptr_ty, field_idx, pt)) {
                    .bit_ptr => |packed_offset| {
                        const result_ty = try pt.ptrType(info: {
                            var new = parent_ptr_info;
                            new.packed_offset = packed_offset;
                            new.child = field_ty.toIntern();
                            if (new.flags.alignment == .none) {
                                new.flags.alignment = try aggregate_ty.abiAlignmentSema(pt);
                            }
                            break :info new;
                        });
                        return pt.getCoerced(parent_ptr, result_ty);
                    },
                    .byte_ptr => |ptr_info| {
                        const result_ty = try pt.ptrTypeSema(info: {
                            var new = parent_ptr_info;
                            new.child = field_ty.toIntern();
                            new.packed_offset = .{
                                .host_size = 0,
                                .bit_offset = 0,
                            };
                            new.flags.alignment = ptr_info.alignment;
                            break :info new;
                        });
                        return parent_ptr.getOffsetPtr(ptr_info.offset, result_ty, pt);
                    },
                },
            }
        },
        .@"union" => field: {
            const union_obj = zcu.typeToUnion(aggregate_ty).?;
            const field_ty = Type.fromInterned(union_obj.field_types.get(&zcu.intern_pool)[field_idx]);
            switch (aggregate_ty.containerLayout(zcu)) {
                .auto => break :field .{ field_ty, try aggregate_ty.fieldAlignmentSema(field_idx, pt) },
                .@"extern" => {
                    // Point to the same address.
                    const result_ty = try pt.ptrTypeSema(info: {
                        var new = parent_ptr_info;
                        new.child = field_ty.toIntern();
                        break :info new;
                    });
                    return pt.getCoerced(parent_ptr, result_ty);
                },
                .@"packed" => {
                    // If the field has an ABI size matching its bit size, then we can continue to use a
                    // non-bit pointer if the parent pointer is also a non-bit pointer.
                    if (parent_ptr_info.packed_offset.host_size == 0 and (try field_ty.abiSizeInner(.sema, zcu, pt.tid)).scalar * 8 == try field_ty.bitSizeSema(pt)) {
                        // We must offset the pointer on big-endian targets, since the bits of packed memory don't align nicely.
                        const byte_offset = switch (zcu.getTarget().cpu.arch.endian()) {
                            .little => 0,
                            .big => (try aggregate_ty.abiSizeInner(.sema, zcu, pt.tid)).scalar - (try field_ty.abiSizeInner(.sema, zcu, pt.tid)).scalar,
                        };
                        const result_ty = try pt.ptrTypeSema(info: {
                            var new = parent_ptr_info;
                            new.child = field_ty.toIntern();
                            new.flags.alignment = InternPool.Alignment.fromLog2Units(
                                @ctz(byte_offset | (try parent_ptr_ty.ptrAlignmentSema(pt)).toByteUnits().?),
                            );
                            break :info new;
                        });
                        return parent_ptr.getOffsetPtr(byte_offset, result_ty, pt);
                    } else {
                        // The result must be a bit-pointer if it is not already.
                        const result_ty = try pt.ptrTypeSema(info: {
                            var new = parent_ptr_info;
                            new.child = field_ty.toIntern();
                            if (new.packed_offset.host_size == 0) {
                                new.packed_offset.host_size = @intCast(((try aggregate_ty.bitSizeSema(pt)) + 7) / 8);
                                assert(new.packed_offset.bit_offset == 0);
                            }
                            break :info new;
                        });
                        return pt.getCoerced(parent_ptr, result_ty);
                    }
                },
            }
        },
        .pointer => field_ty: {
            assert(aggregate_ty.isSlice(zcu));
            break :field_ty switch (field_idx) {
                Value.slice_ptr_index => .{ aggregate_ty.slicePtrFieldType(zcu), Type.usize.abiAlignment(zcu) },
                Value.slice_len_index => .{ Type.usize, Type.usize.abiAlignment(zcu) },
                else => unreachable,
            };
        },
        else => unreachable,
    };

    const new_align: InternPool.Alignment = if (parent_ptr_info.flags.alignment != .none) a: {
        const ty_align = (try field_ty.abiAlignmentInner(.sema, zcu, pt.tid)).scalar;
        const true_field_align = if (field_align == .none) ty_align else field_align;
        const new_align = true_field_align.min(parent_ptr_info.flags.alignment);
        if (new_align == ty_align) break :a .none;
        break :a new_align;
    } else field_align;

    const result_ty = try pt.ptrTypeSema(info: {
        var new = parent_ptr_info;
        new.child = field_ty.toIntern();
        new.flags.alignment = new_align;
        break :info new;
    });

    if (parent_ptr.isUndef(zcu)) return pt.undefValue(result_ty);

    const base_ptr = try parent_ptr.canonicalizeBasePtr(.one, aggregate_ty, pt);
    return Value.fromInterned(try pt.intern(.{ .ptr = .{
        .ty = result_ty.toIntern(),
        .base_addr = .{ .field = .{
            .base = base_ptr.toIntern(),
            .index = field_idx,
        } },
        .byte_offset = 0,
    } }));
}

/// `orig_parent_ptr` must be either a single-pointer to an array or vector, or a many-pointer or C-pointer or slice.
/// Returns a pointer to the element at the specified index.
/// May perform type resolution.
pub fn ptrElem(orig_parent_ptr: Value, field_idx: u64, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    const parent_ptr = switch (orig_parent_ptr.typeOf(zcu).ptrSize(zcu)) {
        .one, .many, .c => orig_parent_ptr,
        .slice => orig_parent_ptr.slicePtr(zcu),
    };

    const parent_ptr_ty = parent_ptr.typeOf(zcu);
    const elem_ty = parent_ptr_ty.childType(zcu);
    const result_ty = try parent_ptr_ty.elemPtrType(@intCast(field_idx), pt);

    if (parent_ptr.isUndef(zcu)) return pt.undefValue(result_ty);

    if (result_ty.ptrInfo(zcu).packed_offset.host_size != 0) {
        // Since we have a bit-pointer, the pointer address should be unchanged.
        assert(elem_ty.zigTypeTag(zcu) == .vector);
        return pt.getCoerced(parent_ptr, result_ty);
    }

    const PtrStrat = union(enum) {
        offset: u64,
        elem_ptr: Type, // many-ptr elem ty
    };

    const strat: PtrStrat = switch (parent_ptr_ty.ptrSize(zcu)) {
        .one => switch (elem_ty.zigTypeTag(zcu)) {
            .vector => .{ .offset = field_idx * @divExact(try elem_ty.childType(zcu).bitSizeSema(pt), 8) },
            .array => strat: {
                const arr_elem_ty = elem_ty.childType(zcu);
                if (try arr_elem_ty.comptimeOnlySema(pt)) {
                    break :strat .{ .elem_ptr = arr_elem_ty };
                }
                break :strat .{ .offset = field_idx * (try arr_elem_ty.abiSizeInner(.sema, zcu, pt.tid)).scalar };
            },
            else => unreachable,
        },

        .many, .c => if (try elem_ty.comptimeOnlySema(pt))
            .{ .elem_ptr = elem_ty }
        else
            .{ .offset = field_idx * (try elem_ty.abiSizeInner(.sema, zcu, pt.tid)).scalar },

        .slice => unreachable,
    };

    switch (strat) {
        .offset => |byte_offset| {
            return parent_ptr.getOffsetPtr(byte_offset, result_ty, pt);
        },
        .elem_ptr => |manyptr_elem_ty| if (field_idx == 0) {
            return pt.getCoerced(parent_ptr, result_ty);
        } else {
            const arr_base_ty, const arr_base_len = manyptr_elem_ty.arrayBase(zcu);
            const base_idx = arr_base_len * field_idx;
            const parent_info = zcu.intern_pool.indexToKey(parent_ptr.toIntern()).ptr;
            switch (parent_info.base_addr) {
                .arr_elem => |arr_elem| {
                    if (Value.fromInterned(arr_elem.base).typeOf(zcu).childType(zcu).toIntern() == arr_base_ty.toIntern()) {
                        // We already have a pointer to an element of an array of this type.
                        // Just modify the index.
                        return Value.fromInterned(try pt.intern(.{ .ptr = ptr: {
                            var new = parent_info;
                            new.base_addr.arr_elem.index += base_idx;
                            new.ty = result_ty.toIntern();
                            break :ptr new;
                        } }));
                    }
                },
                else => {},
            }
            const base_ptr = try parent_ptr.canonicalizeBasePtr(.many, arr_base_ty, pt);
            return Value.fromInterned(try pt.intern(.{ .ptr = .{
                .ty = result_ty.toIntern(),
                .base_addr = .{ .arr_elem = .{
                    .base = base_ptr.toIntern(),
                    .index = base_idx,
                } },
                .byte_offset = 0,
            } }));
        },
    }
}

fn canonicalizeBasePtr(base_ptr: Value, want_size: std.builtin.Type.Pointer.Size, want_child: Type, pt: Zcu.PerThread) !Value {
    const ptr_ty = base_ptr.typeOf(pt.zcu);
    const ptr_info = ptr_ty.ptrInfo(pt.zcu);

    if (ptr_info.flags.size == want_size and
        ptr_info.child == want_child.toIntern() and
        !ptr_info.flags.is_const and
        !ptr_info.flags.is_volatile and
        !ptr_info.flags.is_allowzero and
        ptr_info.sentinel == .none and
        ptr_info.flags.alignment == .none)
    {
        // Already canonical!
        return base_ptr;
    }

    const new_ty = try pt.ptrType(.{
        .child = want_child.toIntern(),
        .sentinel = .none,
        .flags = .{
            .size = want_size,
            .alignment = .none,
            .is_const = false,
            .is_volatile = false,
            .is_allowzero = false,
            .address_space = ptr_info.flags.address_space,
        },
    });
    return pt.getCoerced(base_ptr, new_ty);
}

pub fn getOffsetPtr(ptr_val: Value, byte_off: u64, new_ty: Type, pt: Zcu.PerThread) !Value {
    if (ptr_val.isUndef(pt.zcu)) return ptr_val;
    var ptr = pt.zcu.intern_pool.indexToKey(ptr_val.toIntern()).ptr;
    ptr.ty = new_ty.toIntern();
    ptr.byte_offset += byte_off;
    return Value.fromInterned(try pt.intern(.{ .ptr = ptr }));
}

pub const PointerDeriveStep = union(enum) {
    int: struct {
        addr: u64,
        ptr_ty: Type,
    },
    nav_ptr: InternPool.Nav.Index,
    uav_ptr: InternPool.Key.Ptr.BaseAddr.Uav,
    comptime_alloc_ptr: struct {
        idx: InternPool.ComptimeAllocIndex,
        val: Value,
        ptr_ty: Type,
    },
    comptime_field_ptr: Value,
    eu_payload_ptr: struct {
        parent: *PointerDeriveStep,
        /// This type will never be cast: it is provided for convenience.
        result_ptr_ty: Type,
    },
    opt_payload_ptr: struct {
        parent: *PointerDeriveStep,
        /// This type will never be cast: it is provided for convenience.
        result_ptr_ty: Type,
    },
    field_ptr: struct {
        parent: *PointerDeriveStep,
        field_idx: u32,
        /// This type will never be cast: it is provided for convenience.
        result_ptr_ty: Type,
    },
    elem_ptr: struct {
        parent: *PointerDeriveStep,
        elem_idx: u64,
        /// This type will never be cast: it is provided for convenience.
        result_ptr_ty: Type,
    },
    offset_and_cast: struct {
        parent: *PointerDeriveStep,
        byte_offset: u64,
        new_ptr_ty: Type,
    },

    pub fn ptrType(step: PointerDeriveStep, pt: Zcu.PerThread) !Type {
        return switch (step) {
            .int => |int| int.ptr_ty,
            .nav_ptr => |nav| try pt.navPtrType(nav),
            .uav_ptr => |uav| Type.fromInterned(uav.orig_ty),
            .comptime_alloc_ptr => |info| info.ptr_ty,
            .comptime_field_ptr => |val| try pt.singleConstPtrType(val.typeOf(pt.zcu)),
            .offset_and_cast => |oac| oac.new_ptr_ty,
            inline .eu_payload_ptr, .opt_payload_ptr, .field_ptr, .elem_ptr => |x| x.result_ptr_ty,
        };
    }
};

pub fn pointerDerivation(ptr_val: Value, arena: Allocator, pt: Zcu.PerThread) Allocator.Error!PointerDeriveStep {
    return ptr_val.pointerDerivationAdvanced(arena, pt, false, null) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        error.AnalysisFail => unreachable,
    };
}

/// Given a pointer value, get the sequence of steps to derive it, ideally by taking
/// only field and element pointers with no casts. This can be used by codegen backends
/// which prefer field/elem accesses when lowering constant pointer values.
/// It is also used by the Value printing logic for pointers.
pub fn pointerDerivationAdvanced(ptr_val: Value, arena: Allocator, pt: Zcu.PerThread, comptime resolve_types: bool, opt_sema: ?*Sema) !PointerDeriveStep {
    const zcu = pt.zcu;
    const ptr = zcu.intern_pool.indexToKey(ptr_val.toIntern()).ptr;
    const base_derive: PointerDeriveStep = switch (ptr.base_addr) {
        .int => return .{ .int = .{
            .addr = ptr.byte_offset,
            .ptr_ty = Type.fromInterned(ptr.ty),
        } },
        .nav => |nav| .{ .nav_ptr = nav },
        .uav => |uav| base: {
            // A slight tweak: `orig_ty` here is sometimes not `const`, but it ought to be.
            // TODO: fix this in the sites interning anon decls!
            const const_ty = try pt.ptrType(info: {
                var info = Type.fromInterned(uav.orig_ty).ptrInfo(zcu);
                info.flags.is_const = true;
                break :info info;
            });
            break :base .{ .uav_ptr = .{
                .val = uav.val,
                .orig_ty = const_ty.toIntern(),
            } };
        },
        .comptime_alloc => |idx| base: {
            const sema = opt_sema.?;
            const alloc = sema.getComptimeAlloc(idx);
            const val = try alloc.val.intern(pt, sema.arena);
            const ty = val.typeOf(zcu);
            break :base .{ .comptime_alloc_ptr = .{
                .idx = idx,
                .val = val,
                .ptr_ty = try pt.ptrType(.{
                    .child = ty.toIntern(),
                    .flags = .{
                        .alignment = alloc.alignment,
                    },
                }),
            } };
        },
        .comptime_field => |val| .{ .comptime_field_ptr = Value.fromInterned(val) },
        .eu_payload => |eu_ptr| base: {
            const base_ptr = Value.fromInterned(eu_ptr);
            const base_ptr_ty = base_ptr.typeOf(zcu);
            const parent_step = try arena.create(PointerDeriveStep);
            parent_step.* = try pointerDerivationAdvanced(Value.fromInterned(eu_ptr), arena, pt, resolve_types, opt_sema);
            break :base .{ .eu_payload_ptr = .{
                .parent = parent_step,
                .result_ptr_ty = try pt.adjustPtrTypeChild(base_ptr_ty, base_ptr_ty.childType(zcu).errorUnionPayload(zcu)),
            } };
        },
        .opt_payload => |opt_ptr| base: {
            const base_ptr = Value.fromInterned(opt_ptr);
            const base_ptr_ty = base_ptr.typeOf(zcu);
            const parent_step = try arena.create(PointerDeriveStep);
            parent_step.* = try pointerDerivationAdvanced(Value.fromInterned(opt_ptr), arena, pt, resolve_types, opt_sema);
            break :base .{ .opt_payload_ptr = .{
                .parent = parent_step,
                .result_ptr_ty = try pt.adjustPtrTypeChild(base_ptr_ty, base_ptr_ty.childType(zcu).optionalChild(zcu)),
            } };
        },
        .field => |field| base: {
            const base_ptr = Value.fromInterned(field.base);
            const base_ptr_ty = base_ptr.typeOf(zcu);
            const agg_ty = base_ptr_ty.childType(zcu);
            const field_ty, const field_align = switch (agg_ty.zigTypeTag(zcu)) {
                .@"struct" => .{ agg_ty.fieldType(@intCast(field.index), zcu), try agg_ty.fieldAlignmentInner(
                    @intCast(field.index),
                    if (resolve_types) .sema else .normal,
                    pt.zcu,
                    if (resolve_types) pt.tid else {},
                ) },
                .@"union" => .{ agg_ty.unionFieldTypeByIndex(@intCast(field.index), zcu), try agg_ty.fieldAlignmentInner(
                    @intCast(field.index),
                    if (resolve_types) .sema else .normal,
                    pt.zcu,
                    if (resolve_types) pt.tid else {},
                ) },
                .pointer => .{ switch (field.index) {
                    Value.slice_ptr_index => agg_ty.slicePtrFieldType(zcu),
                    Value.slice_len_index => Type.usize,
                    else => unreachable,
                }, Type.usize.abiAlignment(zcu) },
                else => unreachable,
            };
            const base_align = base_ptr_ty.ptrAlignment(zcu);
            const result_align = field_align.minStrict(base_align);
            const result_ty = try pt.ptrType(.{
                .child = field_ty.toIntern(),
                .flags = flags: {
                    var flags = base_ptr_ty.ptrInfo(zcu).flags;
                    if (result_align == field_ty.abiAlignment(zcu)) {
                        flags.alignment = .none;
                    } else {
                        flags.alignment = result_align;
                    }
                    break :flags flags;
                },
            });
            const parent_step = try arena.create(PointerDeriveStep);
            parent_step.* = try pointerDerivationAdvanced(base_ptr, arena, pt, resolve_types, opt_sema);
            break :base .{ .field_ptr = .{
                .parent = parent_step,
                .field_idx = @intCast(field.index),
                .result_ptr_ty = result_ty,
            } };
        },
        .arr_elem => |arr_elem| base: {
            const parent_step = try arena.create(PointerDeriveStep);
            parent_step.* = try pointerDerivationAdvanced(Value.fromInterned(arr_elem.base), arena, pt, resolve_types, opt_sema);
            const parent_ptr_info = (try parent_step.ptrType(pt)).ptrInfo(zcu);
            const result_ptr_ty = try pt.ptrType(.{
                .child = parent_ptr_info.child,
                .flags = flags: {
                    var flags = parent_ptr_info.flags;
                    flags.size = .one;
                    break :flags flags;
                },
            });
            break :base .{ .elem_ptr = .{
                .parent = parent_step,
                .elem_idx = arr_elem.index,
                .result_ptr_ty = result_ptr_ty,
            } };
        },
    };

    if (ptr.byte_offset == 0 and ptr.ty == (try base_derive.ptrType(pt)).toIntern()) {
        return base_derive;
    }

    const ptr_ty_info = Type.fromInterned(ptr.ty).ptrInfo(zcu);
    const need_child: Type = .fromInterned(ptr_ty_info.child);
    if (need_child.comptimeOnly(zcu)) {
        // No refinement can happen - this pointer is presumably invalid.
        // Just offset it.
        const parent = try arena.create(PointerDeriveStep);
        parent.* = base_derive;
        return .{ .offset_and_cast = .{
            .parent = parent,
            .byte_offset = ptr.byte_offset,
            .new_ptr_ty = Type.fromInterned(ptr.ty),
        } };
    }
    const need_bytes = need_child.abiSize(zcu);

    var cur_derive = base_derive;
    var cur_offset = ptr.byte_offset;

    // Refine through fields and array elements as much as possible.

    if (need_bytes > 0) while (true) {
        const cur_ty = (try cur_derive.ptrType(pt)).childType(zcu);
        if (cur_ty.toIntern() == need_child.toIntern() and cur_offset == 0) {
            break;
        }
        switch (cur_ty.zigTypeTag(zcu)) {
            .noreturn,
            .type,
            .comptime_int,
            .comptime_float,
            .null,
            .undefined,
            .enum_literal,
            .@"opaque",
            .@"fn",
            .error_union,
            .int,
            .float,
            .bool,
            .void,
            .pointer,
            .error_set,
            .@"anyframe",
            .frame,
            .@"enum",
            .vector,
            .@"union",
            => break,

            .optional => {
                ptr_opt: {
                    if (!cur_ty.isPtrLikeOptional(zcu)) break :ptr_opt;
                    if (need_child.zigTypeTag(zcu) != .pointer) break :ptr_opt;
                    switch (need_child.ptrSize(zcu)) {
                        .one, .many => {},
                        .slice, .c => break :ptr_opt,
                    }
                    const parent = try arena.create(PointerDeriveStep);
                    parent.* = cur_derive;
                    cur_derive = .{ .opt_payload_ptr = .{
                        .parent = parent,
                        .result_ptr_ty = try pt.adjustPtrTypeChild(try parent.ptrType(pt), cur_ty.optionalChild(zcu)),
                    } };
                    continue;
                }
                break;
            },

            .array => {
                const elem_ty = cur_ty.childType(zcu);
                const elem_size = elem_ty.abiSize(zcu);
                const start_idx = cur_offset / elem_size;
                const end_idx = (cur_offset + need_bytes + elem_size - 1) / elem_size;
                if (end_idx == start_idx + 1 and ptr_ty_info.flags.size == .one) {
                    const parent = try arena.create(PointerDeriveStep);
                    parent.* = cur_derive;
                    cur_derive = .{ .elem_ptr = .{
                        .parent = parent,
                        .elem_idx = start_idx,
                        .result_ptr_ty = try pt.adjustPtrTypeChild(try parent.ptrType(pt), elem_ty),
                    } };
                    cur_offset -= start_idx * elem_size;
                } else {
                    // Go into the first element if needed, but don't go any deeper.
                    if (start_idx > 0) {
                        const parent = try arena.create(PointerDeriveStep);
                        parent.* = cur_derive;
                        cur_derive = .{ .elem_ptr = .{
                            .parent = parent,
                            .elem_idx = start_idx,
                            .result_ptr_ty = try pt.adjustPtrTypeChild(try parent.ptrType(pt), elem_ty),
                        } };
                        cur_offset -= start_idx * elem_size;
                    }
                    break;
                }
            },
            .@"struct" => switch (cur_ty.containerLayout(zcu)) {
                .auto, .@"packed" => break,
                .@"extern" => for (0..cur_ty.structFieldCount(zcu)) |field_idx| {
                    const field_ty = cur_ty.fieldType(field_idx, zcu);
                    const start_off = cur_ty.structFieldOffset(field_idx, zcu);
                    const end_off = start_off + field_ty.abiSize(zcu);
                    if (cur_offset >= start_off and cur_offset + need_bytes <= end_off) {
                        const old_ptr_ty = try cur_derive.ptrType(pt);
                        const parent_align = old_ptr_ty.ptrAlignment(zcu);
                        const field_align = InternPool.Alignment.fromLog2Units(@min(parent_align.toLog2Units(), @ctz(start_off)));
                        const parent = try arena.create(PointerDeriveStep);
                        parent.* = cur_derive;
                        const new_ptr_ty = try pt.ptrType(.{
                            .child = field_ty.toIntern(),
                            .flags = flags: {
                                var flags = old_ptr_ty.ptrInfo(zcu).flags;
                                if (field_align == field_ty.abiAlignment(zcu)) {
                                    flags.alignment = .none;
                                } else {
                                    flags.alignment = field_align;
                                }
                                break :flags flags;
                            },
                        });
                        cur_derive = .{ .field_ptr = .{
                            .parent = parent,
                            .field_idx = @intCast(field_idx),
                            .result_ptr_ty = new_ptr_ty,
                        } };
                        cur_offset -= start_off;
                        break;
                    }
                } else break, // pointer spans multiple fields
            },
        }
    };

    if (cur_offset == 0) compatible: {
        const src_ptr_ty_info = (try cur_derive.ptrType(pt)).ptrInfo(zcu);
        // We allow silently doing some "coercible" pointer things.
        // In particular, we only give up if cv qualifiers are *removed*.
        if (src_ptr_ty_info.flags.is_const and !ptr_ty_info.flags.is_const) break :compatible;
        if (src_ptr_ty_info.flags.is_volatile and !ptr_ty_info.flags.is_volatile) break :compatible;
        if (src_ptr_ty_info.flags.is_allowzero and !ptr_ty_info.flags.is_allowzero) break :compatible;
        // Everything else has to match exactly.
        if (src_ptr_ty_info.child != ptr_ty_info.child) break :compatible;
        if (src_ptr_ty_info.sentinel != ptr_ty_info.sentinel) break :compatible;
        if (src_ptr_ty_info.packed_offset != ptr_ty_info.packed_offset) break :compatible;
        if (src_ptr_ty_info.flags.size != ptr_ty_info.flags.size) break :compatible;
        if (src_ptr_ty_info.flags.alignment != ptr_ty_info.flags.alignment) break :compatible;
        if (src_ptr_ty_info.flags.address_space != ptr_ty_info.flags.address_space) break :compatible;
        if (src_ptr_ty_info.flags.vector_index != ptr_ty_info.flags.vector_index) break :compatible;

        return cur_derive;
    }

    const parent = try arena.create(PointerDeriveStep);
    parent.* = cur_derive;
    return .{ .offset_and_cast = .{
        .parent = parent,
        .byte_offset = cur_offset,
        .new_ptr_ty = Type.fromInterned(ptr.ty),
    } };
}

pub fn resolveLazy(
    val: Value,
    arena: Allocator,
    pt: Zcu.PerThread,
) Zcu.SemaError!Value {
    switch (pt.zcu.intern_pool.indexToKey(val.toIntern())) {
        .int => |int| switch (int.storage) {
            .u64, .i64, .big_int => return val,
            .lazy_align, .lazy_size => return pt.intValue(
                Type.fromInterned(int.ty),
                try val.toUnsignedIntSema(pt),
            ),
        },
        .slice => |slice| {
            const ptr = try Value.fromInterned(slice.ptr).resolveLazy(arena, pt);
            const len = try Value.fromInterned(slice.len).resolveLazy(arena, pt);
            if (ptr.toIntern() == slice.ptr and len.toIntern() == slice.len) return val;
            return Value.fromInterned(try pt.intern(.{ .slice = .{
                .ty = slice.ty,
                .ptr = ptr.toIntern(),
                .len = len.toIntern(),
            } }));
        },
        .ptr => |ptr| {
            switch (ptr.base_addr) {
                .nav, .comptime_alloc, .uav, .int => return val,
                .comptime_field => |field_val| {
                    const resolved_field_val = (try Value.fromInterned(field_val).resolveLazy(arena, pt)).toIntern();
                    return if (resolved_field_val == field_val)
                        val
                    else
                        Value.fromInterned(try pt.intern(.{ .ptr = .{
                            .ty = ptr.ty,
                            .base_addr = .{ .comptime_field = resolved_field_val },
                            .byte_offset = ptr.byte_offset,
                        } }));
                },
                .eu_payload, .opt_payload => |base| {
                    const resolved_base = (try Value.fromInterned(base).resolveLazy(arena, pt)).toIntern();
                    return if (resolved_base == base)
                        val
                    else
                        Value.fromInterned(try pt.intern(.{ .ptr = .{
                            .ty = ptr.ty,
                            .base_addr = switch (ptr.base_addr) {
                                .eu_payload => .{ .eu_payload = resolved_base },
                                .opt_payload => .{ .opt_payload = resolved_base },
                                else => unreachable,
                            },
                            .byte_offset = ptr.byte_offset,
                        } }));
                },
                .arr_elem, .field => |base_index| {
                    const resolved_base = (try Value.fromInterned(base_index.base).resolveLazy(arena, pt)).toIntern();
                    return if (resolved_base == base_index.base)
                        val
                    else
                        Value.fromInterned(try pt.intern(.{ .ptr = .{
                            .ty = ptr.ty,
                            .base_addr = switch (ptr.base_addr) {
                                .arr_elem => .{ .arr_elem = .{
                                    .base = resolved_base,
                                    .index = base_index.index,
                                } },
                                .field => .{ .field = .{
                                    .base = resolved_base,
                                    .index = base_index.index,
                                } },
                                else => unreachable,
                            },
                            .byte_offset = ptr.byte_offset,
                        } }));
                },
            }
        },
        .aggregate => |aggregate| switch (aggregate.storage) {
            .bytes => return val,
            .elems => |elems| {
                var resolved_elems: []InternPool.Index = &.{};
                for (elems, 0..) |elem, i| {
                    const resolved_elem = (try Value.fromInterned(elem).resolveLazy(arena, pt)).toIntern();
                    if (resolved_elems.len == 0 and resolved_elem != elem) {
                        resolved_elems = try arena.alloc(InternPool.Index, elems.len);
                        @memcpy(resolved_elems[0..i], elems[0..i]);
                    }
                    if (resolved_elems.len > 0) resolved_elems[i] = resolved_elem;
                }
                return if (resolved_elems.len == 0)
                    val
                else
                    pt.aggregateValue(.fromInterned(aggregate.ty), resolved_elems);
            },
            .repeated_elem => |elem| {
                const resolved_elem = try Value.fromInterned(elem).resolveLazy(arena, pt);
                return if (resolved_elem.toIntern() == elem)
                    val
                else
                    pt.aggregateSplatValue(.fromInterned(aggregate.ty), resolved_elem);
            },
        },
        .un => |un| {
            const resolved_tag = if (un.tag == .none)
                .none
            else
                (try Value.fromInterned(un.tag).resolveLazy(arena, pt)).toIntern();
            const resolved_val = (try Value.fromInterned(un.val).resolveLazy(arena, pt)).toIntern();
            return if (resolved_tag == un.tag and resolved_val == un.val)
                val
            else
                Value.fromInterned(try pt.internUnion(.{
                    .ty = un.ty,
                    .tag = resolved_tag,
                    .val = resolved_val,
                }));
        },
        else => return val,
    }
}

const InterpretMode = enum {
    /// In this mode, types are assumed to match what the compiler was built with in terms of field
    /// order, field types, etc. This improves compiler performance. However, it means that certain
    /// modifications to `std.builtin` will result in compiler crashes.
    direct,
    /// In this mode, various details of the type are allowed to differ from what the compiler was built
    /// with. Fields are matched by name rather than index; added struct fields are ignored, and removed
    /// struct fields use their default value if one exists. This is slower than `.direct`, but permits
    /// making certain changes to `std.builtin` (in particular reordering/adding/removing fields), so it
    /// is useful when applying breaking changes.
    by_name,
};
const interpret_mode: InterpretMode = @field(InterpretMode, @tagName(build_options.value_interpret_mode));

/// Given a `Value` representing a comptime-known value of type `T`, unwrap it into an actual `T` known to the compiler.
/// This is useful for accessing `std.builtin` structures received from comptime logic.
/// `val` must be fully resolved.
pub fn interpret(val: Value, comptime T: type, pt: Zcu.PerThread) error{ OutOfMemory, UndefinedValue, TypeMismatch }!T {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const ty = val.typeOf(zcu);
    if (ty.zigTypeTag(zcu) != @typeInfo(T)) return error.TypeMismatch;
    if (val.isUndef(zcu)) return error.UndefinedValue;

    return switch (@typeInfo(T)) {
        .type,
        .noreturn,
        .comptime_float,
        .comptime_int,
        .undefined,
        .null,
        .@"fn",
        .@"opaque",
        .enum_literal,
        => comptime unreachable, // comptime-only or otherwise impossible

        .pointer,
        .array,
        .error_union,
        .error_set,
        .frame,
        .@"anyframe",
        .vector,
        => comptime unreachable, // unsupported

        .void => {},

        .bool => switch (val.toIntern()) {
            .bool_false => false,
            .bool_true => true,
            else => unreachable,
        },

        .int => switch (ip.indexToKey(val.toIntern()).int.storage) {
            .lazy_align, .lazy_size => unreachable, // `val` is fully resolved
            inline .u64, .i64 => |x| std.math.cast(T, x) orelse return error.TypeMismatch,
            .big_int => |big| big.toInt(T) catch return error.TypeMismatch,
        },

        .float => val.toFloat(T, zcu),

        .optional => |opt| if (val.optionalValue(zcu)) |unwrapped|
            try unwrapped.interpret(opt.child, pt)
        else
            null,

        .@"enum" => switch (interpret_mode) {
            .direct => {
                const int = val.getUnsignedInt(zcu) orelse return error.TypeMismatch;
                return std.enums.fromInt(T, int) orelse error.TypeMismatch;
            },
            .by_name => {
                const field_index = ty.enumTagFieldIndex(val, zcu) orelse return error.TypeMismatch;
                const field_name = ty.enumFieldName(field_index, zcu);
                return std.meta.stringToEnum(T, field_name.toSlice(ip)) orelse error.TypeMismatch;
            },
        },

        .@"union" => |@"union"| {
            // No need to handle `interpret_mode`, because the `.@"enum"` handling already deals with it.
            const tag_val = val.unionTag(zcu) orelse return error.TypeMismatch;
            const tag = try tag_val.interpret(@"union".tag_type.?, pt);
            return switch (tag) {
                inline else => |tag_comptime| @unionInit(
                    T,
                    @tagName(tag_comptime),
                    try val.unionValue(zcu).interpret(@FieldType(T, @tagName(tag_comptime)), pt),
                ),
            };
        },

        .@"struct" => |@"struct"| switch (interpret_mode) {
            .direct => {
                if (ty.structFieldCount(zcu) != @"struct".fields.len) return error.TypeMismatch;
                var result: T = undefined;
                inline for (@"struct".fields, 0..) |field, field_idx| {
                    const field_val = try val.fieldValue(pt, field_idx);
                    @field(result, field.name) = try field_val.interpret(field.type, pt);
                }
                return result;
            },
            .by_name => {
                const struct_obj = zcu.typeToStruct(ty) orelse return error.TypeMismatch;
                var result: T = undefined;
                inline for (@"struct".fields) |field| {
                    const field_name_ip = try ip.getOrPutString(zcu.gpa, pt.tid, field.name, .no_embedded_nulls);
                    @field(result, field.name) = if (struct_obj.nameIndex(ip, field_name_ip)) |field_idx| f: {
                        const field_val = try val.fieldValue(pt, field_idx);
                        break :f try field_val.interpret(field.type, pt);
                    } else (field.defaultValue() orelse return error.TypeMismatch);
                }
                return result;
            },
        },
    };
}

/// Given any `val` and a `Type` corresponding `@TypeOf(val)`, construct a `Value` representing it which can be used
/// within the compilation. This is useful for passing `std.builtin` structures in the compiler back to the compilation.
/// This is the inverse of `interpret`.
pub fn uninterpret(val: anytype, ty: Type, pt: Zcu.PerThread) error{ OutOfMemory, TypeMismatch }!Value {
    const T = @TypeOf(val);

    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    if (ty.zigTypeTag(zcu) != @typeInfo(T)) return error.TypeMismatch;

    return switch (@typeInfo(T)) {
        .type,
        .noreturn,
        .comptime_float,
        .comptime_int,
        .undefined,
        .null,
        .@"fn",
        .@"opaque",
        .enum_literal,
        => comptime unreachable, // comptime-only or otherwise impossible

        .pointer,
        .array,
        .error_union,
        .error_set,
        .frame,
        .@"anyframe",
        .vector,
        => comptime unreachable, // unsupported

        .void => .void,

        .bool => if (val) .true else .false,

        .int => try pt.intValue(ty, val),

        .float => try pt.floatValue(ty, val),

        .optional => if (val) |some|
            .fromInterned(try pt.intern(.{ .opt = .{
                .ty = ty.toIntern(),
                .val = (try uninterpret(some, ty.optionalChild(zcu), pt)).toIntern(),
            } }))
        else
            try pt.nullValue(ty),

        .@"enum" => switch (interpret_mode) {
            .direct => try pt.enumValue(ty, (try uninterpret(@intFromEnum(val), ty.intTagType(zcu), pt)).toIntern()),
            .by_name => {
                const field_name_ip = try ip.getOrPutString(zcu.gpa, pt.tid, @tagName(val), .no_embedded_nulls);
                const field_idx = ty.enumFieldIndex(field_name_ip, zcu) orelse return error.TypeMismatch;
                return pt.enumValueFieldIndex(ty, field_idx);
            },
        },

        .@"union" => |@"union"| {
            // No need to handle `interpret_mode`, because the `.@"enum"` handling already deals with it.
            const tag: @"union".tag_type.? = val;
            const tag_val = try uninterpret(tag, ty.unionTagType(zcu).?, pt);
            const field_ty = ty.unionFieldType(tag_val, zcu) orelse return error.TypeMismatch;
            return switch (val) {
                inline else => |payload| try pt.unionValue(
                    ty,
                    tag_val,
                    try uninterpret(payload, field_ty, pt),
                ),
            };
        },

        .@"struct" => |@"struct"| switch (interpret_mode) {
            .direct => {
                if (ty.structFieldCount(zcu) != @"struct".fields.len) return error.TypeMismatch;
                var field_vals: [@"struct".fields.len]InternPool.Index = undefined;
                inline for (&field_vals, @"struct".fields, 0..) |*field_val, field, field_idx| {
                    const field_ty = ty.fieldType(field_idx, zcu);
                    field_val.* = (try uninterpret(@field(val, field.name), field_ty, pt)).toIntern();
                }
                return pt.aggregateValue(ty, &field_vals);
            },
            .by_name => {
                const struct_obj = zcu.typeToStruct(ty) orelse return error.TypeMismatch;
                const want_fields_len = struct_obj.field_types.len;
                const field_vals = try zcu.gpa.alloc(InternPool.Index, want_fields_len);
                defer zcu.gpa.free(field_vals);
                @memset(field_vals, .none);
                inline for (@"struct".fields) |field| {
                    const field_name_ip = try ip.getOrPutString(zcu.gpa, pt.tid, field.name, .no_embedded_nulls);
                    if (struct_obj.nameIndex(ip, field_name_ip)) |field_idx| {
                        const field_ty = ty.fieldType(field_idx, zcu);
                        field_vals[field_idx] = (try uninterpret(@field(val, field.name), field_ty, pt)).toIntern();
                    }
                }
                for (field_vals, 0..) |*field_val, field_idx| {
                    if (field_val.* == .none) {
                        const default_init = struct_obj.field_inits.get(ip)[field_idx];
                        if (default_init == .none) return error.TypeMismatch;
                        field_val.* = default_init;
                    }
                }
                return pt.aggregateValue(ty, field_vals);
            },
        },
    };
}

/// Returns whether `ptr_val_a[0..elem_count]` and `ptr_val_b[0..elem_count]` overlap.
/// `ptr_val_a` and `ptr_val_b` are indexable pointers (not slices) whose element types are in-memory coercible.
pub fn doPointersOverlap(ptr_val_a: Value, ptr_val_b: Value, elem_count: u64, zcu: *const Zcu) bool {
    const ip = &zcu.intern_pool;

    const a_elem_ty = ptr_val_a.typeOf(zcu).indexablePtrElem(zcu);
    const b_elem_ty = ptr_val_b.typeOf(zcu).indexablePtrElem(zcu);

    const a_ptr = ip.indexToKey(ptr_val_a.toIntern()).ptr;
    const b_ptr = ip.indexToKey(ptr_val_b.toIntern()).ptr;

    // If `a_elem_ty` is not comptime-only, then overlapping pointers have identical
    // `base_addr`, and we just need to look at the byte offset. If it *is* comptime-only,
    // then `base_addr` may be an `arr_elem`, and we'll have to consider the element index.
    if (a_elem_ty.comptimeOnly(zcu)) {
        assert(a_elem_ty.toIntern() == b_elem_ty.toIntern()); // IMC comptime-only types are equivalent

        const a_base_addr: InternPool.Key.Ptr.BaseAddr, const a_idx: u64 = switch (a_ptr.base_addr) {
            else => .{ a_ptr.base_addr, 0 },
            .arr_elem => |arr_elem| a: {
                const base_ptr = Value.fromInterned(arr_elem.base);
                const base_child_ty = base_ptr.typeOf(zcu).childType(zcu);
                if (base_child_ty.toIntern() == a_elem_ty.toIntern()) {
                    // This `arr_elem` is indexing into the element type we want.
                    const base_ptr_info = ip.indexToKey(base_ptr.toIntern()).ptr;
                    if (base_ptr_info.byte_offset != 0) {
                        return false; // this pointer is invalid, just let the access fail
                    }
                    break :a .{ base_ptr_info.base_addr, arr_elem.index };
                }
                break :a .{ a_ptr.base_addr, 0 };
            },
        };
        const b_base_addr: InternPool.Key.Ptr.BaseAddr, const b_idx: u64 = switch (a_ptr.base_addr) {
            else => .{ b_ptr.base_addr, 0 },
            .arr_elem => |arr_elem| b: {
                const base_ptr = Value.fromInterned(arr_elem.base);
                const base_child_ty = base_ptr.typeOf(zcu).childType(zcu);
                if (base_child_ty.toIntern() == b_elem_ty.toIntern()) {
                    // This `arr_elem` is indexing into the element type we want.
                    const base_ptr_info = ip.indexToKey(base_ptr.toIntern()).ptr;
                    if (base_ptr_info.byte_offset != 0) {
                        return false; // this pointer is invalid, just let the access fail
                    }
                    break :b .{ base_ptr_info.base_addr, arr_elem.index };
                }
                break :b .{ b_ptr.base_addr, 0 };
            },
        };
        if (!std.meta.eql(a_base_addr, b_base_addr)) return false;
        const diff = if (a_idx >= b_idx) a_idx - b_idx else b_idx - a_idx;
        return diff < elem_count;
    } else {
        assert(a_elem_ty.abiSize(zcu) == b_elem_ty.abiSize(zcu));

        if (!std.meta.eql(a_ptr.base_addr, b_ptr.base_addr)) return false;

        const bytes_diff = if (a_ptr.byte_offset >= b_ptr.byte_offset)
            a_ptr.byte_offset - b_ptr.byte_offset
        else
            b_ptr.byte_offset - a_ptr.byte_offset;

        const need_bytes_diff = elem_count * a_elem_ty.abiSize(zcu);
        return bytes_diff < need_bytes_diff;
    }
}

/// `lhs` and `rhs` are both scalar numeric values (int or float).
/// Supports comparisons between heterogeneous types.
/// If `lhs` or `rhs` is undef, returns `false`.
pub fn eqlScalarNum(lhs: Value, rhs: Value, zcu: *Zcu) bool {
    if (lhs.isUndef(zcu)) return false;
    if (rhs.isUndef(zcu)) return false;

    if (lhs.isFloat(zcu) or rhs.isFloat(zcu)) {
        const lhs_f128 = lhs.toFloat(f128, zcu);
        const rhs_f128 = rhs.toFloat(f128, zcu);
        return lhs_f128 == rhs_f128;
    }

    if (lhs.getUnsignedInt(zcu)) |lhs_u64| {
        if (rhs.getUnsignedInt(zcu)) |rhs_u64| {
            return lhs_u64 == rhs_u64;
        }
    }

    var lhs_bigint_space: BigIntSpace = undefined;
    var rhs_bigint_space: BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_bigint_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_bigint_space, zcu);
    return lhs_bigint.eql(rhs_bigint);
}
