const std = @import("std");
const builtin = @import("builtin");
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

pub fn format(val: Value, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = val;
    _ = fmt;
    _ = options;
    _ = writer;
    @compileError("do not use format values directly; use either fmtDebug or fmtValue");
}

/// This is a debug function. In order to print values in a meaningful way
/// we also need access to the type.
pub fn dump(
    start_val: Value,
    comptime fmt: []const u8,
    _: std.fmt.FormatOptions,
    out_stream: anytype,
) !void {
    comptime assert(fmt.len == 0);
    try out_stream.print("(interned: {})", .{start_val.toIntern()});
}

pub fn fmtDebug(val: Value) std.fmt.Formatter(dump) {
    return .{ .data = val };
}

pub fn fmtValue(val: Value, pt: Zcu.PerThread) std.fmt.Formatter(print_value.format) {
    return .{ .data = .{
        .val = val,
        .pt = pt,
        .opt_sema = null,
        .depth = 3,
    } };
}

pub fn fmtValueSema(val: Value, pt: Zcu.PerThread, sema: *Sema) std.fmt.Formatter(print_value.formatSema) {
    return .{ .data = .{
        .val = val,
        .pt = pt,
        .opt_sema = sema,
        .depth = 3,
    } };
}

pub fn fmtValueSemaFull(ctx: print_value.FormatContext) std.fmt.Formatter(print_value.formatSema) {
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
pub fn getUnsignedInt(val: Value, zcu: *Zcu) ?u64 {
    return getUnsignedIntInner(val, .normal, zcu, {}) catch unreachable;
}

/// Asserts the value is an integer and it fits in a u64
pub fn toUnsignedInt(val: Value, zcu: *Zcu) u64 {
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
    zcu: *Zcu,
    tid: strat.Tid(),
) !?u64 {
    return switch (val.toIntern()) {
        .undef => unreachable,
        .bool_false => 0,
        .bool_true => 1,
        else => switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            .undef => unreachable,
            .int => |int| switch (int.storage) {
                .big_int => |big_int| big_int.to(u64) catch null,
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
pub fn toSignedInt(val: Value, zcu: *Zcu) i64 {
    return switch (val.toIntern()) {
        .bool_false => 0,
        .bool_true => 1,
        else => switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            .int => |int| switch (int.storage) {
                .big_int => |big_int| big_int.to(i64) catch unreachable,
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
            return Value.fromInterned(try pt.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = elems },
            } }));
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
                    return Value.fromInterned(try pt.intern(.{ .aggregate = .{
                        .ty = ty.toIntern(),
                        .storage = .{ .elems = field_vals },
                    } }));
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
            return Value.fromInterned(try pt.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = elems },
            } }));
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
            return Value.fromInterned(try pt.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = field_vals },
            } }));
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
pub fn toFloat(val: Value, comptime T: type, zcu: *Zcu) T {
    return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .int => |int| switch (int.storage) {
            .big_int => |big_int| @floatCast(bigIntToFloat(big_int.limbs, big_int.positive)),
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

/// TODO move this to std lib big int code
fn bigIntToFloat(limbs: []const std.math.big.Limb, positive: bool) f128 {
    if (limbs.len == 0) return 0;

    const base = std.math.maxInt(std.math.big.Limb) + 1;
    var result: f128 = 0;
    var i: usize = limbs.len;
    while (i != 0) {
        i -= 1;
        const limb: f128 = @floatFromInt(limbs[i]);
        result = @mulAdd(f128, base, result, limb);
    }
    if (positive) {
        return result;
    } else {
        return -result;
    }
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

pub fn bitReverse(val: Value, ty: Type, pt: Zcu.PerThread, arena: Allocator) !Value {
    const zcu = pt.zcu;
    const info = ty.intInfo(zcu);

    var buffer: Value.BigIntSpace = undefined;
    const operand_bigint = val.toBigInt(&buffer, zcu);

    const limbs = try arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.bitReverse(operand_bigint, info.signedness, info.bits);

    return pt.intValue_big(ty, result_bigint.toConst());
}

pub fn byteSwap(val: Value, ty: Type, pt: Zcu.PerThread, arena: Allocator) !Value {
    const zcu = pt.zcu;
    const info = ty.intInfo(zcu);

    // Bit count must be evenly divisible by 8
    assert(info.bits % 8 == 0);

    var buffer: Value.BigIntSpace = undefined;
    const operand_bigint = val.toBigInt(&buffer, zcu);

    const limbs = try arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.byteSwap(operand_bigint, info.signedness, info.bits / 8);

    return pt.intValue_big(ty, result_bigint.toConst());
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

/// Asserts the value is a float
pub fn floatHasFraction(self: Value, zcu: *const Zcu) bool {
    return switch (zcu.intern_pool.indexToKey(self.toIntern())) {
        .float => |float| switch (float.storage) {
            inline else => |x| @rem(x, 1) != 0,
        },
        else => unreachable,
    };
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

pub fn isPtrToThreadLocal(val: Value, zcu: *Zcu) bool {
    const ip = &zcu.intern_pool;
    const nav = ip.getBackingNav(val.toIntern()).unwrap() orelse return false;
    return switch (ip.indexToKey(ip.getNav(nav).status.resolved.val)) {
        .@"extern" => |e| e.is_threadlocal,
        .variable => |v| v.is_threadlocal,
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

pub fn isUndef(val: Value, zcu: *Zcu) bool {
    return zcu.intern_pool.isUndef(val.toIntern());
}

/// TODO: check for cases such as array that is not marked undef but all the element
/// values are marked undef, or struct that is not marked undef but all fields are marked
/// undef, etc.
pub fn isUndefDeep(val: Value, zcu: *Zcu) bool {
    return val.isUndef(zcu);
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
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return floatFromIntScalar(val, float_ty, pt, strat);
}

pub fn floatFromIntScalar(val: Value, float_ty: Type, pt: Zcu.PerThread, comptime strat: ResolveStrat) !Value {
    const zcu = pt.zcu;
    return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .undef => try pt.undefValue(float_ty),
        .int => |int| switch (int.storage) {
            .big_int => |big_int| {
                const float = bigIntToFloat(big_int.limbs, big_int.positive);
                return pt.floatValue(float_ty, float);
            },
            inline .u64, .i64 => |x| floatFromIntInner(x, float_ty, pt),
            .lazy_align => |ty| return floatFromIntInner((try Type.fromInterned(ty).abiAlignmentInner(strat.toLazy(), pt.zcu, pt.tid)).scalar.toByteUnits() orelse 0, float_ty, pt),
            .lazy_size => |ty| return floatFromIntInner((try Type.fromInterned(ty).abiSizeInner(strat.toLazy(), pt.zcu, pt.tid)).scalar, float_ty, pt),
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

/// Supports (vectors of) integers only; asserts neither operand is undefined.
pub fn intAddSat(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    if (ty.zigTypeTag(pt.zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(pt.zcu));
        const scalar_ty = ty.scalarType(pt.zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try intAddSatScalar(lhs_elem, rhs_elem, scalar_ty, arena, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return intAddSatScalar(lhs, rhs, ty, arena, pt);
}

/// Supports integers only; asserts neither operand is undefined.
pub fn intAddSatScalar(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    const zcu = pt.zcu;
    assert(!lhs.isUndef(zcu));
    assert(!rhs.isUndef(zcu));

    const info = ty.intInfo(zcu);

    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs = try arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.addSat(lhs_bigint, rhs_bigint, info.signedness, info.bits);
    return pt.intValue_big(ty, result_bigint.toConst());
}

/// Supports (vectors of) integers only; asserts neither operand is undefined.
pub fn intSubSat(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    if (ty.zigTypeTag(pt.zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(pt.zcu));
        const scalar_ty = ty.scalarType(pt.zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try intSubSatScalar(lhs_elem, rhs_elem, scalar_ty, arena, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return intSubSatScalar(lhs, rhs, ty, arena, pt);
}

/// Supports integers only; asserts neither operand is undefined.
pub fn intSubSatScalar(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    const zcu = pt.zcu;

    assert(!lhs.isUndef(zcu));
    assert(!rhs.isUndef(zcu));

    const info = ty.intInfo(zcu);

    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs = try arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.subSat(lhs_bigint, rhs_bigint, info.signedness, info.bits);
    return pt.intValue_big(ty, result_bigint.toConst());
}

pub fn intMulWithOverflow(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !OverflowArithmeticResult {
    const zcu = pt.zcu;
    if (ty.zigTypeTag(zcu) == .vector) {
        const vec_len = ty.vectorLen(zcu);
        const overflowed_data = try arena.alloc(InternPool.Index, vec_len);
        const result_data = try arena.alloc(InternPool.Index, vec_len);
        const scalar_ty = ty.scalarType(zcu);
        for (overflowed_data, result_data, 0..) |*of, *scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            const of_math_result = try intMulWithOverflowScalar(lhs_elem, rhs_elem, scalar_ty, arena, pt);
            of.* = of_math_result.overflow_bit.toIntern();
            scalar.* = of_math_result.wrapped_result.toIntern();
        }
        return OverflowArithmeticResult{
            .overflow_bit = Value.fromInterned(try pt.intern(.{ .aggregate = .{
                .ty = (try pt.vectorType(.{ .len = vec_len, .child = .u1_type })).toIntern(),
                .storage = .{ .elems = overflowed_data },
            } })),
            .wrapped_result = Value.fromInterned(try pt.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })),
        };
    }
    return intMulWithOverflowScalar(lhs, rhs, ty, arena, pt);
}

pub fn intMulWithOverflowScalar(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !OverflowArithmeticResult {
    const zcu = pt.zcu;
    const info = ty.intInfo(zcu);

    if (lhs.isUndef(zcu) or rhs.isUndef(zcu)) {
        return .{
            .overflow_bit = try pt.undefValue(Type.u1),
            .wrapped_result = try pt.undefValue(ty),
        };
    }

    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs = try arena.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len + rhs_bigint.limbs.len,
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    const limbs_buffer = try arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcMulLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len, 1),
    );
    result_bigint.mul(lhs_bigint, rhs_bigint, limbs_buffer, arena);

    const overflowed = !result_bigint.toConst().fitsInTwosComp(info.signedness, info.bits);
    if (overflowed) {
        result_bigint.truncate(result_bigint.toConst(), info.signedness, info.bits);
    }

    return OverflowArithmeticResult{
        .overflow_bit = try pt.intValue(Type.u1, @intFromBool(overflowed)),
        .wrapped_result = try pt.intValue_big(ty, result_bigint.toConst()),
    };
}

/// Supports both (vectors of) floats and ints; handles undefined scalars.
pub fn numberMulWrap(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    const zcu = pt.zcu;
    if (ty.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(zcu));
        const scalar_ty = ty.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try numberMulWrapScalar(lhs_elem, rhs_elem, scalar_ty, arena, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return numberMulWrapScalar(lhs, rhs, ty, arena, pt);
}

/// Supports both floats and ints; handles undefined.
pub fn numberMulWrapScalar(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    const zcu = pt.zcu;
    if (lhs.isUndef(zcu) or rhs.isUndef(zcu)) return Value.undef;

    if (ty.zigTypeTag(zcu) == .comptime_int) {
        return intMul(lhs, rhs, ty, undefined, arena, pt);
    }

    if (ty.isAnyFloat()) {
        return floatMul(lhs, rhs, ty, arena, pt);
    }

    const overflow_result = try intMulWithOverflow(lhs, rhs, ty, arena, pt);
    return overflow_result.wrapped_result;
}

/// Supports (vectors of) integers only; asserts neither operand is undefined.
pub fn intMulSat(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    if (ty.zigTypeTag(pt.zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(pt.zcu));
        const scalar_ty = ty.scalarType(pt.zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try intMulSatScalar(lhs_elem, rhs_elem, scalar_ty, arena, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return intMulSatScalar(lhs, rhs, ty, arena, pt);
}

/// Supports (vectors of) integers only; asserts neither operand is undefined.
pub fn intMulSatScalar(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    const zcu = pt.zcu;

    assert(!lhs.isUndef(zcu));
    assert(!rhs.isUndef(zcu));

    const info = ty.intInfo(zcu);

    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs = try arena.alloc(
        std.math.big.Limb,
        @max(
            // For the saturate
            std.math.big.int.calcTwosCompLimbCount(info.bits),
            lhs_bigint.limbs.len + rhs_bigint.limbs.len,
        ),
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    const limbs_buffer = try arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcMulLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len, 1),
    );
    result_bigint.mul(lhs_bigint, rhs_bigint, limbs_buffer, arena);
    result_bigint.saturate(result_bigint.toConst(), info.signedness, info.bits);
    return pt.intValue_big(ty, result_bigint.toConst());
}

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

/// operands must be (vectors of) integers; handles undefined scalars.
pub fn bitwiseNot(val: Value, ty: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (ty.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(zcu));
        const scalar_ty = ty.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try bitwiseNotScalar(elem_val, scalar_ty, arena, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return bitwiseNotScalar(val, ty, arena, pt);
}

/// operands must be integers; handles undefined.
pub fn bitwiseNotScalar(val: Value, ty: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (val.isUndef(zcu)) return Value.fromInterned(try pt.intern(.{ .undef = ty.toIntern() }));
    if (ty.toIntern() == .bool_type) return makeBool(!val.toBool());

    const info = ty.intInfo(zcu);

    if (info.bits == 0) {
        return val;
    }

    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var val_space: Value.BigIntSpace = undefined;
    const val_bigint = val.toBigInt(&val_space, zcu);
    const limbs = try arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );

    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.bitNotWrap(val_bigint, info.signedness, info.bits);
    return pt.intValue_big(ty, result_bigint.toConst());
}

/// operands must be (vectors of) integers; handles undefined scalars.
pub fn bitwiseAnd(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (ty.zigTypeTag(zcu) == .vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(zcu));
        const scalar_ty = ty.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try bitwiseAndScalar(lhs_elem, rhs_elem, scalar_ty, allocator, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return bitwiseAndScalar(lhs, rhs, ty, allocator, pt);
}

/// operands must be integers; handles undefined.
pub fn bitwiseAndScalar(orig_lhs: Value, orig_rhs: Value, ty: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    // If one operand is defined, we turn the other into `0xAA` so the bitwise AND can
    // still zero out some bits.
    // TODO: ideally we'd still like tracking for the undef bits. Related: #19634.
    const lhs: Value, const rhs: Value = make_defined: {
        const lhs_undef = orig_lhs.isUndef(zcu);
        const rhs_undef = orig_rhs.isUndef(zcu);
        break :make_defined switch ((@as(u2, @intFromBool(lhs_undef)) << 1) | @intFromBool(rhs_undef)) {
            0b00 => .{ orig_lhs, orig_rhs },
            0b01 => .{ orig_lhs, try intValueAa(ty, arena, pt) },
            0b10 => .{ try intValueAa(ty, arena, pt), orig_rhs },
            0b11 => return pt.undefValue(ty),
        };
    };

    if (ty.toIntern() == .bool_type) return makeBool(lhs.toBool() and rhs.toBool());

    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs = try arena.alloc(
        std.math.big.Limb,
        // + 1 for negatives
        @max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.bitAnd(lhs_bigint, rhs_bigint);
    return pt.intValue_big(ty, result_bigint.toConst());
}

/// Given an integer or boolean type, creates an value of that with the bit pattern 0xAA.
/// This is used to convert undef values into 0xAA when performing e.g. bitwise operations.
fn intValueAa(ty: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (ty.toIntern() == .bool_type) return Value.true;
    const info = ty.intInfo(zcu);

    const buf = try arena.alloc(u8, (info.bits + 7) / 8);
    @memset(buf, 0xAA);

    const limbs = try arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.readTwosComplement(buf, info.bits, zcu.getTarget().cpu.arch.endian(), info.signedness);
    return pt.intValue_big(ty, result_bigint.toConst());
}

/// operands must be (vectors of) integers; handles undefined scalars.
pub fn bitwiseNand(lhs: Value, rhs: Value, ty: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (ty.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(zcu));
        const scalar_ty = ty.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try bitwiseNandScalar(lhs_elem, rhs_elem, scalar_ty, arena, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return bitwiseNandScalar(lhs, rhs, ty, arena, pt);
}

/// operands must be integers; handles undefined.
pub fn bitwiseNandScalar(lhs: Value, rhs: Value, ty: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (lhs.isUndef(zcu) or rhs.isUndef(zcu)) return Value.fromInterned(try pt.intern(.{ .undef = ty.toIntern() }));
    if (ty.toIntern() == .bool_type) return makeBool(!(lhs.toBool() and rhs.toBool()));

    const anded = try bitwiseAnd(lhs, rhs, ty, arena, pt);
    const all_ones = if (ty.isSignedInt(zcu)) try pt.intValue(ty, -1) else try ty.maxIntScalar(pt, ty);
    return bitwiseXor(anded, all_ones, ty, arena, pt);
}

/// operands must be (vectors of) integers; handles undefined scalars.
pub fn bitwiseOr(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (ty.zigTypeTag(zcu) == .vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(zcu));
        const scalar_ty = ty.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try bitwiseOrScalar(lhs_elem, rhs_elem, scalar_ty, allocator, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return bitwiseOrScalar(lhs, rhs, ty, allocator, pt);
}

/// operands must be integers; handles undefined.
pub fn bitwiseOrScalar(orig_lhs: Value, orig_rhs: Value, ty: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    // If one operand is defined, we turn the other into `0xAA` so the bitwise AND can
    // still zero out some bits.
    // TODO: ideally we'd still like tracking for the undef bits. Related: #19634.
    const zcu = pt.zcu;
    const lhs: Value, const rhs: Value = make_defined: {
        const lhs_undef = orig_lhs.isUndef(zcu);
        const rhs_undef = orig_rhs.isUndef(zcu);
        break :make_defined switch ((@as(u2, @intFromBool(lhs_undef)) << 1) | @intFromBool(rhs_undef)) {
            0b00 => .{ orig_lhs, orig_rhs },
            0b01 => .{ orig_lhs, try intValueAa(ty, arena, pt) },
            0b10 => .{ try intValueAa(ty, arena, pt), orig_rhs },
            0b11 => return pt.undefValue(ty),
        };
    };

    if (ty.toIntern() == .bool_type) return makeBool(lhs.toBool() or rhs.toBool());

    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs = try arena.alloc(
        std.math.big.Limb,
        @max(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.bitOr(lhs_bigint, rhs_bigint);
    return pt.intValue_big(ty, result_bigint.toConst());
}

/// operands must be (vectors of) integers; handles undefined scalars.
pub fn bitwiseXor(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (ty.zigTypeTag(zcu) == .vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(zcu));
        const scalar_ty = ty.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try bitwiseXorScalar(lhs_elem, rhs_elem, scalar_ty, allocator, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return bitwiseXorScalar(lhs, rhs, ty, allocator, pt);
}

/// operands must be integers; handles undefined.
pub fn bitwiseXorScalar(lhs: Value, rhs: Value, ty: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (lhs.isUndef(zcu) or rhs.isUndef(zcu)) return Value.fromInterned(try pt.intern(.{ .undef = ty.toIntern() }));
    if (ty.toIntern() == .bool_type) return makeBool(lhs.toBool() != rhs.toBool());

    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs = try arena.alloc(
        std.math.big.Limb,
        // + 1 for negatives
        @max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.bitXor(lhs_bigint, rhs_bigint);
    return pt.intValue_big(ty, result_bigint.toConst());
}

/// If the value overflowed the type, returns a comptime_int (or vector thereof) instead, setting
/// overflow_idx to the vector index the overflow was at (or 0 for a scalar).
pub fn intDiv(lhs: Value, rhs: Value, ty: Type, overflow_idx: *?usize, allocator: Allocator, pt: Zcu.PerThread) !Value {
    var overflow: usize = undefined;
    return intDivInner(lhs, rhs, ty, &overflow, allocator, pt) catch |err| switch (err) {
        error.Overflow => {
            const is_vec = ty.isVector(pt.zcu);
            overflow_idx.* = if (is_vec) overflow else 0;
            const safe_ty = if (is_vec) try pt.vectorType(.{
                .len = ty.vectorLen(pt.zcu),
                .child = .comptime_int_type,
            }) else Type.comptime_int;
            return intDivInner(lhs, rhs, safe_ty, undefined, allocator, pt) catch |err1| switch (err1) {
                error.Overflow => unreachable,
                else => |e| return e,
            };
        },
        else => |e| return e,
    };
}

fn intDivInner(lhs: Value, rhs: Value, ty: Type, overflow_idx: *usize, allocator: Allocator, pt: Zcu.PerThread) !Value {
    if (ty.zigTypeTag(pt.zcu) == .vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(pt.zcu));
        const scalar_ty = ty.scalarType(pt.zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            const val = intDivScalar(lhs_elem, rhs_elem, scalar_ty, allocator, pt) catch |err| switch (err) {
                error.Overflow => {
                    overflow_idx.* = i;
                    return error.Overflow;
                },
                else => |e| return e,
            };
            scalar.* = val.toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return intDivScalar(lhs, rhs, ty, allocator, pt);
}

pub fn intDivScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, pt: Zcu.PerThread) !Value {
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    const zcu = pt.zcu;
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs_q = try allocator.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len,
    );
    const limbs_r = try allocator.alloc(
        std.math.big.Limb,
        rhs_bigint.limbs.len,
    );
    const limbs_buffer = try allocator.alloc(
        std.math.big.Limb,
        std.math.big.int.calcDivLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
    );
    var result_q = BigIntMutable{ .limbs = limbs_q, .positive = undefined, .len = undefined };
    var result_r = BigIntMutable{ .limbs = limbs_r, .positive = undefined, .len = undefined };
    result_q.divTrunc(&result_r, lhs_bigint, rhs_bigint, limbs_buffer);
    if (ty.toIntern() != .comptime_int_type) {
        const info = ty.intInfo(pt.zcu);
        if (!result_q.toConst().fitsInTwosComp(info.signedness, info.bits)) {
            return error.Overflow;
        }
    }
    return pt.intValue_big(ty, result_q.toConst());
}

pub fn intDivFloor(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, pt: Zcu.PerThread) !Value {
    if (ty.zigTypeTag(pt.zcu) == .vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(pt.zcu));
        const scalar_ty = ty.scalarType(pt.zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try intDivFloorScalar(lhs_elem, rhs_elem, scalar_ty, allocator, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return intDivFloorScalar(lhs, rhs, ty, allocator, pt);
}

pub fn intDivFloorScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, pt: Zcu.PerThread) !Value {
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    const zcu = pt.zcu;
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs_q = try allocator.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len,
    );
    const limbs_r = try allocator.alloc(
        std.math.big.Limb,
        rhs_bigint.limbs.len,
    );
    const limbs_buffer = try allocator.alloc(
        std.math.big.Limb,
        std.math.big.int.calcDivLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
    );
    var result_q = BigIntMutable{ .limbs = limbs_q, .positive = undefined, .len = undefined };
    var result_r = BigIntMutable{ .limbs = limbs_r, .positive = undefined, .len = undefined };
    result_q.divFloor(&result_r, lhs_bigint, rhs_bigint, limbs_buffer);
    return pt.intValue_big(ty, result_q.toConst());
}

pub fn intMod(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, pt: Zcu.PerThread) !Value {
    if (ty.zigTypeTag(pt.zcu) == .vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(pt.zcu));
        const scalar_ty = ty.scalarType(pt.zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try intModScalar(lhs_elem, rhs_elem, scalar_ty, allocator, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return intModScalar(lhs, rhs, ty, allocator, pt);
}

pub fn intModScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, pt: Zcu.PerThread) !Value {
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    const zcu = pt.zcu;
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs_q = try allocator.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len,
    );
    const limbs_r = try allocator.alloc(
        std.math.big.Limb,
        rhs_bigint.limbs.len,
    );
    const limbs_buffer = try allocator.alloc(
        std.math.big.Limb,
        std.math.big.int.calcDivLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
    );
    var result_q = BigIntMutable{ .limbs = limbs_q, .positive = undefined, .len = undefined };
    var result_r = BigIntMutable{ .limbs = limbs_r, .positive = undefined, .len = undefined };
    result_q.divFloor(&result_r, lhs_bigint, rhs_bigint, limbs_buffer);
    return pt.intValue_big(ty, result_r.toConst());
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

pub fn isNegativeInf(val: Value, zcu: *const Zcu) bool {
    return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .float => |float| switch (float.storage) {
            inline else => |x| std.math.isNegativeInf(x),
        },
        else => false,
    };
}

pub fn floatRem(lhs: Value, rhs: Value, float_type: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    if (float_type.zigTypeTag(pt.zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(pt.zcu));
        const scalar_ty = float_type.scalarType(pt.zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try floatRemScalar(lhs_elem, rhs_elem, scalar_ty, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return floatRemScalar(lhs, rhs, float_type, pt);
}

pub fn floatRemScalar(lhs: Value, rhs: Value, float_type: Type, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    const target = pt.zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @rem(lhs.toFloat(f16, zcu), rhs.toFloat(f16, zcu)) },
        32 => .{ .f32 = @rem(lhs.toFloat(f32, zcu), rhs.toFloat(f32, zcu)) },
        64 => .{ .f64 = @rem(lhs.toFloat(f64, zcu), rhs.toFloat(f64, zcu)) },
        80 => .{ .f80 = @rem(lhs.toFloat(f80, zcu), rhs.toFloat(f80, zcu)) },
        128 => .{ .f128 = @rem(lhs.toFloat(f128, zcu), rhs.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn floatMod(lhs: Value, rhs: Value, float_type: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    if (float_type.zigTypeTag(pt.zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(pt.zcu));
        const scalar_ty = float_type.scalarType(pt.zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try floatModScalar(lhs_elem, rhs_elem, scalar_ty, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return floatModScalar(lhs, rhs, float_type, pt);
}

pub fn floatModScalar(lhs: Value, rhs: Value, float_type: Type, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @mod(lhs.toFloat(f16, zcu), rhs.toFloat(f16, zcu)) },
        32 => .{ .f32 = @mod(lhs.toFloat(f32, zcu), rhs.toFloat(f32, zcu)) },
        64 => .{ .f64 = @mod(lhs.toFloat(f64, zcu), rhs.toFloat(f64, zcu)) },
        80 => .{ .f80 = @mod(lhs.toFloat(f80, zcu), rhs.toFloat(f80, zcu)) },
        128 => .{ .f128 = @mod(lhs.toFloat(f128, zcu), rhs.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

/// If the value overflowed the type, returns a comptime_int (or vector thereof) instead, setting
/// overflow_idx to the vector index the overflow was at (or 0 for a scalar).
pub fn intMul(lhs: Value, rhs: Value, ty: Type, overflow_idx: *?usize, allocator: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    var overflow: usize = undefined;
    return intMulInner(lhs, rhs, ty, &overflow, allocator, pt) catch |err| switch (err) {
        error.Overflow => {
            const is_vec = ty.isVector(zcu);
            overflow_idx.* = if (is_vec) overflow else 0;
            const safe_ty = if (is_vec) try pt.vectorType(.{
                .len = ty.vectorLen(zcu),
                .child = .comptime_int_type,
            }) else Type.comptime_int;
            return intMulInner(lhs, rhs, safe_ty, undefined, allocator, pt) catch |err1| switch (err1) {
                error.Overflow => unreachable,
                else => |e| return e,
            };
        },
        else => |e| return e,
    };
}

fn intMulInner(lhs: Value, rhs: Value, ty: Type, overflow_idx: *usize, allocator: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (ty.zigTypeTag(zcu) == .vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(zcu));
        const scalar_ty = ty.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            const val = intMulScalar(lhs_elem, rhs_elem, scalar_ty, allocator, pt) catch |err| switch (err) {
                error.Overflow => {
                    overflow_idx.* = i;
                    return error.Overflow;
                },
                else => |e| return e,
            };
            scalar.* = val.toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return intMulScalar(lhs, rhs, ty, allocator, pt);
}

pub fn intMulScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (ty.toIntern() != .comptime_int_type) {
        const res = try intMulWithOverflowScalar(lhs, rhs, ty, allocator, pt);
        if (res.overflow_bit.compareAllWithZero(.neq, zcu)) return error.Overflow;
        return res.wrapped_result;
    }
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const rhs_bigint = rhs.toBigInt(&rhs_space, zcu);
    const limbs = try allocator.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len + rhs_bigint.limbs.len,
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    const limbs_buffer = try allocator.alloc(
        std.math.big.Limb,
        std.math.big.int.calcMulLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len, 1),
    );
    defer allocator.free(limbs_buffer);
    result_bigint.mul(lhs_bigint, rhs_bigint, limbs_buffer, allocator);
    return pt.intValue_big(ty, result_bigint.toConst());
}

pub fn intTrunc(val: Value, ty: Type, allocator: Allocator, signedness: std.builtin.Signedness, bits: u16, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (ty.zigTypeTag(zcu) == .vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(zcu));
        const scalar_ty = ty.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try intTruncScalar(elem_val, scalar_ty, allocator, signedness, bits, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return intTruncScalar(val, ty, allocator, signedness, bits, pt);
}

/// This variant may vectorize on `bits`. Asserts that `bits` is a (vector of) `u16`.
pub fn intTruncBitsAsValue(
    val: Value,
    ty: Type,
    allocator: Allocator,
    signedness: std.builtin.Signedness,
    bits: Value,
    pt: Zcu.PerThread,
) !Value {
    const zcu = pt.zcu;
    if (ty.zigTypeTag(zcu) == .vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(zcu));
        const scalar_ty = ty.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            const bits_elem = try bits.elemValue(pt, i);
            scalar.* = (try intTruncScalar(elem_val, scalar_ty, allocator, signedness, @intCast(bits_elem.toUnsignedInt(zcu)), pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return intTruncScalar(val, ty, allocator, signedness, @intCast(bits.toUnsignedInt(zcu)), pt);
}

pub fn intTruncScalar(
    val: Value,
    ty: Type,
    allocator: Allocator,
    signedness: std.builtin.Signedness,
    bits: u16,
    pt: Zcu.PerThread,
) !Value {
    const zcu = pt.zcu;
    if (bits == 0) return pt.intValue(ty, 0);

    if (val.isUndef(zcu)) return pt.undefValue(ty);

    var val_space: Value.BigIntSpace = undefined;
    const val_bigint = val.toBigInt(&val_space, zcu);

    const limbs = try allocator.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(bits),
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };

    result_bigint.truncate(val_bigint, signedness, bits);
    return pt.intValue_big(ty, result_bigint.toConst());
}

pub fn shl(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    if (ty.zigTypeTag(zcu) == .vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(zcu));
        const scalar_ty = ty.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try shlScalar(lhs_elem, rhs_elem, scalar_ty, allocator, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return shlScalar(lhs, rhs, ty, allocator, pt);
}

pub fn shlScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, pt: Zcu.PerThread) !Value {
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    const zcu = pt.zcu;
    var lhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const shift: usize = @intCast(rhs.toUnsignedInt(zcu));
    const limbs = try allocator.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len + (shift / (@sizeOf(std.math.big.Limb) * 8)) + 1,
    );
    var result_bigint = BigIntMutable{
        .limbs = limbs,
        .positive = undefined,
        .len = undefined,
    };
    result_bigint.shiftLeft(lhs_bigint, shift);
    if (ty.toIntern() != .comptime_int_type) {
        const int_info = ty.intInfo(zcu);
        result_bigint.truncate(result_bigint.toConst(), int_info.signedness, int_info.bits);
    }

    return pt.intValue_big(ty, result_bigint.toConst());
}

pub fn shlWithOverflow(
    lhs: Value,
    rhs: Value,
    ty: Type,
    allocator: Allocator,
    pt: Zcu.PerThread,
) !OverflowArithmeticResult {
    if (ty.zigTypeTag(pt.zcu) == .vector) {
        const vec_len = ty.vectorLen(pt.zcu);
        const overflowed_data = try allocator.alloc(InternPool.Index, vec_len);
        const result_data = try allocator.alloc(InternPool.Index, vec_len);
        const scalar_ty = ty.scalarType(pt.zcu);
        for (overflowed_data, result_data, 0..) |*of, *scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            const of_math_result = try shlWithOverflowScalar(lhs_elem, rhs_elem, scalar_ty, allocator, pt);
            of.* = of_math_result.overflow_bit.toIntern();
            scalar.* = of_math_result.wrapped_result.toIntern();
        }
        return OverflowArithmeticResult{
            .overflow_bit = Value.fromInterned(try pt.intern(.{ .aggregate = .{
                .ty = (try pt.vectorType(.{ .len = vec_len, .child = .u1_type })).toIntern(),
                .storage = .{ .elems = overflowed_data },
            } })),
            .wrapped_result = Value.fromInterned(try pt.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })),
        };
    }
    return shlWithOverflowScalar(lhs, rhs, ty, allocator, pt);
}

pub fn shlWithOverflowScalar(
    lhs: Value,
    rhs: Value,
    ty: Type,
    allocator: Allocator,
    pt: Zcu.PerThread,
) !OverflowArithmeticResult {
    const zcu = pt.zcu;
    const info = ty.intInfo(zcu);
    var lhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const shift: usize = @intCast(rhs.toUnsignedInt(zcu));
    const limbs = try allocator.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len + (shift / (@sizeOf(std.math.big.Limb) * 8)) + 1,
    );
    var result_bigint = BigIntMutable{
        .limbs = limbs,
        .positive = undefined,
        .len = undefined,
    };
    result_bigint.shiftLeft(lhs_bigint, shift);
    const overflowed = !result_bigint.toConst().fitsInTwosComp(info.signedness, info.bits);
    if (overflowed) {
        result_bigint.truncate(result_bigint.toConst(), info.signedness, info.bits);
    }
    return OverflowArithmeticResult{
        .overflow_bit = try pt.intValue(Type.u1, @intFromBool(overflowed)),
        .wrapped_result = try pt.intValue_big(ty, result_bigint.toConst()),
    };
}

pub fn shlSat(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    if (ty.zigTypeTag(pt.zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(pt.zcu));
        const scalar_ty = ty.scalarType(pt.zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try shlSatScalar(lhs_elem, rhs_elem, scalar_ty, arena, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return shlSatScalar(lhs, rhs, ty, arena, pt);
}

pub fn shlSatScalar(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    const zcu = pt.zcu;
    const info = ty.intInfo(zcu);

    var lhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const shift: usize = @intCast(rhs.toUnsignedInt(zcu));
    const limbs = try arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits) + 1,
    );
    var result_bigint = BigIntMutable{
        .limbs = limbs,
        .positive = undefined,
        .len = undefined,
    };
    result_bigint.shiftLeftSat(lhs_bigint, shift, info.signedness, info.bits);
    return pt.intValue_big(ty, result_bigint.toConst());
}

pub fn shlTrunc(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    if (ty.zigTypeTag(pt.zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(pt.zcu));
        const scalar_ty = ty.scalarType(pt.zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try shlTruncScalar(lhs_elem, rhs_elem, scalar_ty, arena, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return shlTruncScalar(lhs, rhs, ty, arena, pt);
}

pub fn shlTruncScalar(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    const shifted = try lhs.shl(rhs, ty, arena, pt);
    const int_info = ty.intInfo(pt.zcu);
    const truncated = try shifted.intTrunc(ty, arena, int_info.signedness, int_info.bits, pt);
    return truncated;
}

pub fn shr(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, pt: Zcu.PerThread) !Value {
    if (ty.zigTypeTag(pt.zcu) == .vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(pt.zcu));
        const scalar_ty = ty.scalarType(pt.zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try shrScalar(lhs_elem, rhs_elem, scalar_ty, allocator, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return shrScalar(lhs, rhs, ty, allocator, pt);
}

pub fn shrScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, pt: Zcu.PerThread) !Value {
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    const zcu = pt.zcu;
    var lhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
    const shift: usize = @intCast(rhs.toUnsignedInt(zcu));

    const result_limbs = lhs_bigint.limbs.len -| (shift / (@sizeOf(std.math.big.Limb) * 8));
    if (result_limbs == 0) {
        // The shift is enough to remove all the bits from the number, which means the
        // result is 0 or -1 depending on the sign.
        if (lhs_bigint.positive) {
            return pt.intValue(ty, 0);
        } else {
            return pt.intValue(ty, -1);
        }
    }

    const limbs = try allocator.alloc(
        std.math.big.Limb,
        result_limbs,
    );
    var result_bigint = BigIntMutable{
        .limbs = limbs,
        .positive = undefined,
        .len = undefined,
    };
    result_bigint.shiftRight(lhs_bigint, shift);
    return pt.intValue_big(ty, result_bigint.toConst());
}

pub fn floatNeg(
    val: Value,
    float_type: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    const zcu = pt.zcu;
    if (float_type.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
        const scalar_ty = float_type.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try floatNegScalar(elem_val, scalar_ty, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return floatNegScalar(val, float_type, pt);
}

pub fn floatNegScalar(val: Value, float_type: Type, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = -val.toFloat(f16, zcu) },
        32 => .{ .f32 = -val.toFloat(f32, zcu) },
        64 => .{ .f64 = -val.toFloat(f64, zcu) },
        80 => .{ .f80 = -val.toFloat(f80, zcu) },
        128 => .{ .f128 = -val.toFloat(f128, zcu) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn floatAdd(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    const zcu = pt.zcu;
    if (float_type.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
        const scalar_ty = float_type.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try floatAddScalar(lhs_elem, rhs_elem, scalar_ty, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return floatAddScalar(lhs, rhs, float_type, pt);
}

pub fn floatAddScalar(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    pt: Zcu.PerThread,
) !Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = lhs.toFloat(f16, zcu) + rhs.toFloat(f16, zcu) },
        32 => .{ .f32 = lhs.toFloat(f32, zcu) + rhs.toFloat(f32, zcu) },
        64 => .{ .f64 = lhs.toFloat(f64, zcu) + rhs.toFloat(f64, zcu) },
        80 => .{ .f80 = lhs.toFloat(f80, zcu) + rhs.toFloat(f80, zcu) },
        128 => .{ .f128 = lhs.toFloat(f128, zcu) + rhs.toFloat(f128, zcu) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn floatSub(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    const zcu = pt.zcu;
    if (float_type.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
        const scalar_ty = float_type.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try floatSubScalar(lhs_elem, rhs_elem, scalar_ty, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return floatSubScalar(lhs, rhs, float_type, pt);
}

pub fn floatSubScalar(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    pt: Zcu.PerThread,
) !Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = lhs.toFloat(f16, zcu) - rhs.toFloat(f16, zcu) },
        32 => .{ .f32 = lhs.toFloat(f32, zcu) - rhs.toFloat(f32, zcu) },
        64 => .{ .f64 = lhs.toFloat(f64, zcu) - rhs.toFloat(f64, zcu) },
        80 => .{ .f80 = lhs.toFloat(f80, zcu) - rhs.toFloat(f80, zcu) },
        128 => .{ .f128 = lhs.toFloat(f128, zcu) - rhs.toFloat(f128, zcu) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn floatDiv(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    if (float_type.zigTypeTag(pt.zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(pt.zcu));
        const scalar_ty = float_type.scalarType(pt.zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try floatDivScalar(lhs_elem, rhs_elem, scalar_ty, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return floatDivScalar(lhs, rhs, float_type, pt);
}

pub fn floatDivScalar(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    pt: Zcu.PerThread,
) !Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = lhs.toFloat(f16, zcu) / rhs.toFloat(f16, zcu) },
        32 => .{ .f32 = lhs.toFloat(f32, zcu) / rhs.toFloat(f32, zcu) },
        64 => .{ .f64 = lhs.toFloat(f64, zcu) / rhs.toFloat(f64, zcu) },
        80 => .{ .f80 = lhs.toFloat(f80, zcu) / rhs.toFloat(f80, zcu) },
        128 => .{ .f128 = lhs.toFloat(f128, zcu) / rhs.toFloat(f128, zcu) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn floatDivFloor(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    if (float_type.zigTypeTag(pt.zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(pt.zcu));
        const scalar_ty = float_type.scalarType(pt.zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try floatDivFloorScalar(lhs_elem, rhs_elem, scalar_ty, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return floatDivFloorScalar(lhs, rhs, float_type, pt);
}

pub fn floatDivFloorScalar(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    pt: Zcu.PerThread,
) !Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @divFloor(lhs.toFloat(f16, zcu), rhs.toFloat(f16, zcu)) },
        32 => .{ .f32 = @divFloor(lhs.toFloat(f32, zcu), rhs.toFloat(f32, zcu)) },
        64 => .{ .f64 = @divFloor(lhs.toFloat(f64, zcu), rhs.toFloat(f64, zcu)) },
        80 => .{ .f80 = @divFloor(lhs.toFloat(f80, zcu), rhs.toFloat(f80, zcu)) },
        128 => .{ .f128 = @divFloor(lhs.toFloat(f128, zcu), rhs.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn floatDivTrunc(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    if (float_type.zigTypeTag(pt.zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(pt.zcu));
        const scalar_ty = float_type.scalarType(pt.zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try floatDivTruncScalar(lhs_elem, rhs_elem, scalar_ty, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return floatDivTruncScalar(lhs, rhs, float_type, pt);
}

pub fn floatDivTruncScalar(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    pt: Zcu.PerThread,
) !Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @divTrunc(lhs.toFloat(f16, zcu), rhs.toFloat(f16, zcu)) },
        32 => .{ .f32 = @divTrunc(lhs.toFloat(f32, zcu), rhs.toFloat(f32, zcu)) },
        64 => .{ .f64 = @divTrunc(lhs.toFloat(f64, zcu), rhs.toFloat(f64, zcu)) },
        80 => .{ .f80 = @divTrunc(lhs.toFloat(f80, zcu), rhs.toFloat(f80, zcu)) },
        128 => .{ .f128 = @divTrunc(lhs.toFloat(f128, zcu), rhs.toFloat(f128, zcu)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn floatMul(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    arena: Allocator,
    pt: Zcu.PerThread,
) !Value {
    const zcu = pt.zcu;
    if (float_type.zigTypeTag(zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
        const scalar_ty = float_type.scalarType(zcu);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(pt, i);
            const rhs_elem = try rhs.elemValue(pt, i);
            scalar.* = (try floatMulScalar(lhs_elem, rhs_elem, scalar_ty, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
    }
    return floatMulScalar(lhs, rhs, float_type, pt);
}

pub fn floatMulScalar(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    pt: Zcu.PerThread,
) !Value {
    const zcu = pt.zcu;
    const target = zcu.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = lhs.toFloat(f16, zcu) * rhs.toFloat(f16, zcu) },
        32 => .{ .f32 = lhs.toFloat(f32, zcu) * rhs.toFloat(f32, zcu) },
        64 => .{ .f64 = lhs.toFloat(f64, zcu) * rhs.toFloat(f64, zcu) },
        80 => .{ .f80 = lhs.toFloat(f80, zcu) * rhs.toFloat(f80, zcu) },
        128 => .{ .f128 = lhs.toFloat(f128, zcu) * rhs.toFloat(f128, zcu) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } }));
}

pub fn sqrt(val: Value, float_type: Type, arena: Allocator, pt: Zcu.PerThread) !Value {
    if (float_type.zigTypeTag(pt.zcu) == .vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(pt.zcu));
        const scalar_ty = float_type.scalarType(pt.zcu);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(pt, i);
            scalar.* = (try sqrtScalar(elem_val, scalar_ty, pt)).toIntern();
        }
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
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
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
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
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
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
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
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
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
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
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
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
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
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
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
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
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
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
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
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
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
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
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
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
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
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
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
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
        return Value.fromInterned(try pt.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } }));
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

pub fn isGenericPoison(val: Value) bool {
    return val.toIntern() == .generic_poison;
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

pub const zero_usize: Value = .{ .ip_index = .zero_usize };
pub const zero_u8: Value = .{ .ip_index = .zero_u8 };
pub const zero_comptime_int: Value = .{ .ip_index = .zero };
pub const one_comptime_int: Value = .{ .ip_index = .one };
pub const negative_one_comptime_int: Value = .{ .ip_index = .negative_one };
pub const undef: Value = .{ .ip_index = .undef };
pub const @"void": Value = .{ .ip_index = .void_value };
pub const @"null": Value = .{ .ip_index = .null_value };
pub const @"false": Value = .{ .ip_index = .bool_false };
pub const @"true": Value = .{ .ip_index = .bool_true };
pub const @"unreachable": Value = .{ .ip_index = .unreachable_value };

pub const generic_poison: Value = .{ .ip_index = .generic_poison };
pub const generic_poison_type: Value = .{ .ip_index = .generic_poison_type };
pub const empty_struct: Value = .{ .ip_index = .empty_struct };

pub fn makeBool(x: bool) Value {
    return if (x) Value.true else Value.false;
}

pub const RuntimeIndex = InternPool.RuntimeIndex;

/// `parent_ptr` must be a single-pointer to some optional.
/// Returns a pointer to the payload of the optional.
/// May perform type resolution.
pub fn ptrOptPayload(parent_ptr: Value, pt: Zcu.PerThread) !Value {
    const zcu = pt.zcu;
    const parent_ptr_ty = parent_ptr.typeOf(zcu);
    const opt_ty = parent_ptr_ty.childType(zcu);

    assert(parent_ptr_ty.ptrSize(zcu) == .One);
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

    const base_ptr = try parent_ptr.canonicalizeBasePtr(.One, opt_ty, pt);
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

    assert(parent_ptr_ty.ptrSize(zcu) == .One);
    assert(eu_ty.zigTypeTag(zcu) == .error_union);

    const result_ty = try pt.ptrTypeSema(info: {
        var new = parent_ptr_ty.ptrInfo(zcu);
        // We can correctly preserve alignment `.none`, since an error union has a
        // natural alignment greater than or equal to that of its payload type.
        new.child = eu_ty.errorUnionPayload(zcu).toIntern();
        break :info new;
    });

    if (parent_ptr.isUndef(zcu)) return pt.undefValue(result_ty);

    const base_ptr = try parent_ptr.canonicalizeBasePtr(.One, eu_ty, pt);
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
    assert(parent_ptr_info.flags.size == .One);

    // Exiting this `switch` indicates that the `field` pointer representation should be used.
    // `field_align` may be `.none` to represent the natural alignment of `field_ty`, but is not necessarily.
    const field_ty: Type, const field_align: InternPool.Alignment = switch (aggregate_ty.zigTypeTag(zcu)) {
        .@"struct" => field: {
            const field_ty = aggregate_ty.fieldType(field_idx, zcu);
            switch (aggregate_ty.containerLayout(zcu)) {
                .auto => break :field .{ field_ty, try aggregate_ty.fieldAlignmentSema(field_idx, pt) },
                .@"extern" => {
                    // Well-defined layout, so just offset the pointer appropriately.
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

    const base_ptr = try parent_ptr.canonicalizeBasePtr(.One, aggregate_ty, pt);
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
        .One, .Many, .C => orig_parent_ptr,
        .Slice => orig_parent_ptr.slicePtr(zcu),
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
        .One => switch (elem_ty.zigTypeTag(zcu)) {
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

        .Many, .C => if (try elem_ty.comptimeOnlySema(pt))
            .{ .elem_ptr = elem_ty }
        else
            .{ .offset = field_idx * (try elem_ty.abiSizeInner(.sema, zcu, pt.tid)).scalar },

        .Slice => unreachable,
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
            const base_ptr = try parent_ptr.canonicalizeBasePtr(.Many, arr_base_ty, pt);
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
    return ptr_val.pointerDerivationAdvanced(arena, pt, false, {}) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        error.AnalysisFail => unreachable,
    };
}

/// Given a pointer value, get the sequence of steps to derive it, ideally by taking
/// only field and element pointers with no casts. This can be used by codegen backends
/// which prefer field/elem accesses when lowering constant pointer values.
/// It is also used by the Value printing logic for pointers.
pub fn pointerDerivationAdvanced(ptr_val: Value, arena: Allocator, pt: Zcu.PerThread, comptime have_sema: bool, sema: if (have_sema) *Sema else void) !PointerDeriveStep {
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
            if (!have_sema) unreachable;
            const alloc = sema.getComptimeAlloc(idx);
            const val = try alloc.val.intern(pt, sema.arena);
            const ty = val.typeOf(zcu);
            break :base .{ .comptime_alloc_ptr = .{
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
            parent_step.* = try pointerDerivationAdvanced(Value.fromInterned(eu_ptr), arena, pt, have_sema, sema);
            break :base .{ .eu_payload_ptr = .{
                .parent = parent_step,
                .result_ptr_ty = try pt.adjustPtrTypeChild(base_ptr_ty, base_ptr_ty.childType(zcu).errorUnionPayload(zcu)),
            } };
        },
        .opt_payload => |opt_ptr| base: {
            const base_ptr = Value.fromInterned(opt_ptr);
            const base_ptr_ty = base_ptr.typeOf(zcu);
            const parent_step = try arena.create(PointerDeriveStep);
            parent_step.* = try pointerDerivationAdvanced(Value.fromInterned(opt_ptr), arena, pt, have_sema, sema);
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
                    if (have_sema) .sema else .normal,
                    pt.zcu,
                    if (have_sema) pt.tid else {},
                ) },
                .@"union" => .{ agg_ty.unionFieldTypeByIndex(@intCast(field.index), zcu), try agg_ty.fieldAlignmentInner(
                    @intCast(field.index),
                    if (have_sema) .sema else .normal,
                    pt.zcu,
                    if (have_sema) pt.tid else {},
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
            parent_step.* = try pointerDerivationAdvanced(base_ptr, arena, pt, have_sema, sema);
            break :base .{ .field_ptr = .{
                .parent = parent_step,
                .field_idx = @intCast(field.index),
                .result_ptr_ty = result_ty,
            } };
        },
        .arr_elem => |arr_elem| base: {
            const parent_step = try arena.create(PointerDeriveStep);
            parent_step.* = try pointerDerivationAdvanced(Value.fromInterned(arr_elem.base), arena, pt, have_sema, sema);
            const parent_ptr_info = (try parent_step.ptrType(pt)).ptrInfo(zcu);
            const result_ptr_ty = try pt.ptrType(.{
                .child = parent_ptr_info.child,
                .flags = flags: {
                    var flags = parent_ptr_info.flags;
                    flags.size = .One;
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

    const need_child = Type.fromInterned(ptr.ty).childType(zcu);
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
            .optional,
            .@"union",
            => break,

            .array => {
                const elem_ty = cur_ty.childType(zcu);
                const elem_size = elem_ty.abiSize(zcu);
                const start_idx = cur_offset / elem_size;
                const end_idx = (cur_offset + need_bytes + elem_size - 1) / elem_size;
                if (end_idx == start_idx + 1) {
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

    if (cur_offset == 0 and (try cur_derive.ptrType(pt)).toIntern() == ptr.ty) {
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
                return if (resolved_elems.len == 0) val else Value.fromInterned(try pt.intern(.{ .aggregate = .{
                    .ty = aggregate.ty,
                    .storage = .{ .elems = resolved_elems },
                } }));
            },
            .repeated_elem => |elem| {
                const resolved_elem = (try Value.fromInterned(elem).resolveLazy(arena, pt)).toIntern();
                return if (resolved_elem == elem) val else Value.fromInterned(try pt.intern(.{ .aggregate = .{
                    .ty = aggregate.ty,
                    .storage = .{ .repeated_elem = resolved_elem },
                } }));
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
