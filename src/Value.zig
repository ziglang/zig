const std = @import("std");
const builtin = @import("builtin");
const Type = @import("type.zig").Type;
const assert = std.debug.assert;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Target = std.Target;
const Allocator = std.mem.Allocator;
const Module = @import("Module.zig");
const TypedValue = @import("TypedValue.zig");
const Sema = @import("Sema.zig");
const InternPool = @import("InternPool.zig");
const Value = @This();

/// We are migrating towards using this for every Value object. However, many
/// values are still represented the legacy way. This is indicated by using
/// InternPool.Index.none.
ip_index: InternPool.Index,

/// This is the raw data, with no bookkeeping, no memory awareness,
/// no de-duplication, and no type system awareness.
/// This union takes advantage of the fact that the first page of memory
/// is unmapped, giving us 4096 possible enum tags that have no payload.
legacy: extern union {
    ptr_otherwise: *Payload,
},

// Keep in sync with tools/stage2_pretty_printers_common.py
pub const Tag = enum(usize) {
    // The first section of this enum are tags that require no payload.
    // After this, the tag requires a payload.

    /// When the type is error union:
    /// * If the tag is `.@"error"`, the error union is an error.
    /// * If the tag is `.eu_payload`, the error union is a payload.
    /// * A nested error such as `anyerror!(anyerror!T)` in which the the outer error union
    ///   is non-error, but the inner error union is an error, is represented as
    ///   a tag of `.eu_payload`, with a sub-tag of `.@"error"`.
    eu_payload,
    /// When the type is optional:
    /// * If the tag is `.null_value`, the optional is null.
    /// * If the tag is `.opt_payload`, the optional is a payload.
    /// * A nested optional such as `??T` in which the the outer optional
    ///   is non-null, but the inner optional is null, is represented as
    ///   a tag of `.opt_payload`, with a sub-tag of `.null_value`.
    opt_payload,
    /// Pointer and length as sub `Value` objects.
    slice,
    /// A slice of u8 whose memory is managed externally.
    bytes,
    /// This value is repeated some number of times. The amount of times to repeat
    /// is stored externally.
    repeated,
    /// An instance of a struct, array, or vector.
    /// Each element/field stored as a `Value`.
    /// In the case of sentinel-terminated arrays, the sentinel value *is* stored,
    /// so the slice length will be one more than the type's array length.
    aggregate,
    /// An instance of a union.
    @"union",

    pub fn Type(comptime t: Tag) type {
        return switch (t) {
            .eu_payload,
            .opt_payload,
            .repeated,
            => Payload.SubValue,
            .slice => Payload.Slice,
            .bytes => Payload.Bytes,
            .aggregate => Payload.Aggregate,
            .@"union" => Payload.Union,
        };
    }

    pub fn create(comptime t: Tag, ally: Allocator, data: Data(t)) error{OutOfMemory}!Value {
        const ptr = try ally.create(t.Type());
        ptr.* = .{
            .base = .{ .tag = t },
            .data = data,
        };
        return Value{
            .ip_index = .none,
            .legacy = .{ .ptr_otherwise = &ptr.base },
        };
    }

    pub fn Data(comptime t: Tag) type {
        return std.meta.fieldInfo(t.Type(), .data).type;
    }
};

pub fn initPayload(payload: *Payload) Value {
    return Value{
        .ip_index = .none,
        .legacy = .{ .ptr_otherwise = payload },
    };
}

pub fn tag(self: Value) Tag {
    assert(self.ip_index == .none);
    return self.legacy.ptr_otherwise.tag;
}

/// Prefer `castTag` to this.
pub fn cast(self: Value, comptime T: type) ?*T {
    if (self.ip_index != .none) {
        return null;
    }
    if (@hasField(T, "base_tag")) {
        return self.castTag(T.base_tag);
    }
    inline for (@typeInfo(Tag).Enum.fields) |field| {
        const t = @as(Tag, @enumFromInt(field.value));
        if (self.legacy.ptr_otherwise.tag == t) {
            if (T == t.Type()) {
                return @fieldParentPtr(T, "base", self.legacy.ptr_otherwise);
            }
            return null;
        }
    }
    unreachable;
}

pub fn castTag(self: Value, comptime t: Tag) ?*t.Type() {
    if (self.ip_index != .none) return null;

    if (self.legacy.ptr_otherwise.tag == t)
        return @fieldParentPtr(t.Type(), "base", self.legacy.ptr_otherwise);

    return null;
}

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
    if (start_val.ip_index != .none) {
        try out_stream.print("(interned: {})", .{start_val.toIntern()});
        return;
    }
    var val = start_val;
    while (true) switch (val.tag()) {
        .aggregate => {
            return out_stream.writeAll("(aggregate)");
        },
        .@"union" => {
            return out_stream.writeAll("(union value)");
        },
        .bytes => return out_stream.print("\"{}\"", .{std.zig.fmtEscapes(val.castTag(.bytes).?.data)}),
        .repeated => {
            try out_stream.writeAll("(repeated) ");
            val = val.castTag(.repeated).?.data;
        },
        .eu_payload => {
            try out_stream.writeAll("(eu_payload) ");
            val = val.castTag(.repeated).?.data;
        },
        .opt_payload => {
            try out_stream.writeAll("(opt_payload) ");
            val = val.castTag(.repeated).?.data;
        },
        .slice => return out_stream.writeAll("(slice)"),
    };
}

pub fn fmtDebug(val: Value) std.fmt.Formatter(dump) {
    return .{ .data = val };
}

pub fn fmtValue(val: Value, ty: Type, mod: *Module) std.fmt.Formatter(TypedValue.format) {
    return .{ .data = .{
        .tv = .{ .ty = ty, .val = val },
        .mod = mod,
    } };
}

/// Asserts that the value is representable as an array of bytes.
/// Returns the value as a null-terminated string stored in the InternPool.
pub fn toIpString(val: Value, ty: Type, mod: *Module) !InternPool.NullTerminatedString {
    const ip = &mod.intern_pool;
    return switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .enum_literal => |enum_literal| enum_literal,
        .slice => |slice| try arrayToIpString(val, Value.fromInterned(slice.len).toUnsignedInt(mod), mod),
        .aggregate => |aggregate| switch (aggregate.storage) {
            .bytes => |bytes| try ip.getOrPutString(mod.gpa, bytes),
            .elems => try arrayToIpString(val, ty.arrayLen(mod), mod),
            .repeated_elem => |elem| {
                const byte = @as(u8, @intCast(Value.fromInterned(elem).toUnsignedInt(mod)));
                const len = @as(usize, @intCast(ty.arrayLen(mod)));
                try ip.string_bytes.appendNTimes(mod.gpa, byte, len);
                return ip.getOrPutTrailingString(mod.gpa, len);
            },
        },
        else => unreachable,
    };
}

/// Asserts that the value is representable as an array of bytes.
/// Copies the value into a freshly allocated slice of memory, which is owned by the caller.
pub fn toAllocatedBytes(val: Value, ty: Type, allocator: Allocator, mod: *Module) ![]u8 {
    return switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .enum_literal => |enum_literal| allocator.dupe(u8, mod.intern_pool.stringToSlice(enum_literal)),
        .slice => |slice| try arrayToAllocatedBytes(val, Value.fromInterned(slice.len).toUnsignedInt(mod), allocator, mod),
        .aggregate => |aggregate| switch (aggregate.storage) {
            .bytes => |bytes| try allocator.dupe(u8, bytes),
            .elems => try arrayToAllocatedBytes(val, ty.arrayLen(mod), allocator, mod),
            .repeated_elem => |elem| {
                const byte = @as(u8, @intCast(Value.fromInterned(elem).toUnsignedInt(mod)));
                const result = try allocator.alloc(u8, @as(usize, @intCast(ty.arrayLen(mod))));
                @memset(result, byte);
                return result;
            },
        },
        else => unreachable,
    };
}

fn arrayToAllocatedBytes(val: Value, len: u64, allocator: Allocator, mod: *Module) ![]u8 {
    const result = try allocator.alloc(u8, @as(usize, @intCast(len)));
    for (result, 0..) |*elem, i| {
        const elem_val = try val.elemValue(mod, i);
        elem.* = @as(u8, @intCast(elem_val.toUnsignedInt(mod)));
    }
    return result;
}

fn arrayToIpString(val: Value, len_u64: u64, mod: *Module) !InternPool.NullTerminatedString {
    const gpa = mod.gpa;
    const ip = &mod.intern_pool;
    const len = @as(usize, @intCast(len_u64));
    try ip.string_bytes.ensureUnusedCapacity(gpa, len);
    for (0..len) |i| {
        // I don't think elemValue has the possibility to affect ip.string_bytes. Let's
        // assert just to be sure.
        const prev = ip.string_bytes.items.len;
        const elem_val = try val.elemValue(mod, i);
        assert(ip.string_bytes.items.len == prev);
        const byte = @as(u8, @intCast(elem_val.toUnsignedInt(mod)));
        ip.string_bytes.appendAssumeCapacity(byte);
    }
    return ip.getOrPutTrailingString(gpa, len);
}

pub fn intern2(val: Value, ty: Type, mod: *Module) Allocator.Error!InternPool.Index {
    if (val.ip_index != .none) return val.ip_index;
    return intern(val, ty, mod);
}

pub fn intern(val: Value, ty: Type, mod: *Module) Allocator.Error!InternPool.Index {
    if (val.ip_index != .none) return (try mod.getCoerced(val, ty)).toIntern();
    const ip = &mod.intern_pool;
    switch (val.tag()) {
        .eu_payload => {
            const pl = val.castTag(.eu_payload).?.data;
            return mod.intern(.{ .error_union = .{
                .ty = ty.toIntern(),
                .val = .{ .payload = try pl.intern(ty.errorUnionPayload(mod), mod) },
            } });
        },
        .opt_payload => {
            const pl = val.castTag(.opt_payload).?.data;
            return mod.intern(.{ .opt = .{
                .ty = ty.toIntern(),
                .val = try pl.intern(ty.optionalChild(mod), mod),
            } });
        },
        .slice => {
            const pl = val.castTag(.slice).?.data;
            return mod.intern(.{ .slice = .{
                .ty = ty.toIntern(),
                .len = try pl.len.intern(Type.usize, mod),
                .ptr = try pl.ptr.intern(ty.slicePtrFieldType(mod), mod),
            } });
        },
        .bytes => {
            const pl = val.castTag(.bytes).?.data;
            return mod.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .bytes = pl },
            } });
        },
        .repeated => {
            const pl = val.castTag(.repeated).?.data;
            return mod.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .repeated_elem = try pl.intern(ty.childType(mod), mod) },
            } });
        },
        .aggregate => {
            const len = @as(usize, @intCast(ty.arrayLen(mod)));
            const old_elems = val.castTag(.aggregate).?.data[0..len];
            const new_elems = try mod.gpa.alloc(InternPool.Index, old_elems.len);
            defer mod.gpa.free(new_elems);
            const ty_key = ip.indexToKey(ty.toIntern());
            for (new_elems, old_elems, 0..) |*new_elem, old_elem, field_i|
                new_elem.* = try old_elem.intern(switch (ty_key) {
                    .struct_type => ty.structFieldType(field_i, mod),
                    .anon_struct_type => |info| Type.fromInterned(info.types.get(ip)[field_i]),
                    inline .array_type, .vector_type => |info| Type.fromInterned(info.child),
                    else => unreachable,
                }, mod);
            return mod.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = new_elems },
            } });
        },
        .@"union" => {
            const pl = val.castTag(.@"union").?.data;
            if (pl.tag) |pl_tag| {
                return mod.intern(.{ .un = .{
                    .ty = ty.toIntern(),
                    .tag = try pl_tag.intern(ty.unionTagTypeHypothetical(mod), mod),
                    .val = try pl.val.intern(ty.unionFieldType(pl_tag, mod).?, mod),
                } });
            } else {
                return mod.intern(.{ .un = .{
                    .ty = ty.toIntern(),
                    .tag = .none,
                    .val = try pl.val.intern(try ty.unionBackingType(mod), mod),
                } });
            }
        },
    }
}

pub fn unintern(val: Value, arena: Allocator, mod: *Module) Allocator.Error!Value {
    return if (val.ip_index == .none) val else switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .int_type,
        .ptr_type,
        .array_type,
        .vector_type,
        .opt_type,
        .anyframe_type,
        .error_union_type,
        .simple_type,
        .struct_type,
        .anon_struct_type,
        .union_type,
        .opaque_type,
        .enum_type,
        .func_type,
        .error_set_type,
        .inferred_error_set_type,

        .undef,
        .simple_value,
        .variable,
        .extern_func,
        .func,
        .int,
        .err,
        .enum_literal,
        .enum_tag,
        .empty_enum_value,
        .float,
        .ptr,
        => val,

        .error_union => |error_union| switch (error_union.val) {
            .err_name => val,
            .payload => |payload| Tag.eu_payload.create(arena, Value.fromInterned(payload)),
        },

        .slice => |slice| Tag.slice.create(arena, .{
            .ptr = Value.fromInterned(slice.ptr),
            .len = Value.fromInterned(slice.len),
        }),

        .opt => |opt| switch (opt.val) {
            .none => val,
            else => |payload| Tag.opt_payload.create(arena, Value.fromInterned(payload)),
        },

        .aggregate => |aggregate| switch (aggregate.storage) {
            .bytes => |bytes| Tag.bytes.create(arena, try arena.dupe(u8, bytes)),
            .elems => |old_elems| {
                const new_elems = try arena.alloc(Value, old_elems.len);
                for (new_elems, old_elems) |*new_elem, old_elem| new_elem.* = Value.fromInterned(old_elem);
                return Tag.aggregate.create(arena, new_elems);
            },
            .repeated_elem => |elem| Tag.repeated.create(arena, Value.fromInterned(elem)),
        },

        .un => |un| Tag.@"union".create(arena, .{
            // toValue asserts that the value cannot be .none which is valid on unions.
            .tag = if (un.tag == .none) null else Value.fromInterned(un.tag),
            .val = Value.fromInterned(un.val),
        }),

        .memoized_call => unreachable,
    };
}

pub fn fromInterned(i: InternPool.Index) Value {
    assert(i != .none);
    return .{
        .ip_index = i,
        .legacy = undefined,
    };
}

pub fn toIntern(val: Value) InternPool.Index {
    assert(val.ip_index != .none);
    return val.ip_index;
}

/// Asserts that the value is representable as a type.
pub fn toType(self: Value) Type {
    return Type.fromInterned(self.toIntern());
}

pub fn intFromEnum(val: Value, ty: Type, mod: *Module) Allocator.Error!Value {
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(ip.typeOf(val.toIntern()))) {
        // Assume it is already an integer and return it directly.
        .simple_type, .int_type => val,
        .enum_literal => |enum_literal| {
            const field_index = ty.enumFieldIndex(enum_literal, mod).?;
            return switch (ip.indexToKey(ty.toIntern())) {
                // Assume it is already an integer and return it directly.
                .simple_type, .int_type => val,
                .enum_type => |enum_type| if (enum_type.values.len != 0)
                    Value.fromInterned(enum_type.values.get(ip)[field_index])
                else // Field index and integer values are the same.
                    mod.intValue(Type.fromInterned(enum_type.tag_ty), field_index),
                else => unreachable,
            };
        },
        .enum_type => |enum_type| try mod.getCoerced(val, Type.fromInterned(enum_type.tag_ty)),
        else => unreachable,
    };
}

/// Asserts the value is an integer.
pub fn toBigInt(val: Value, space: *BigIntSpace, mod: *Module) BigIntConst {
    return val.toBigIntAdvanced(space, mod, null) catch unreachable;
}

/// Asserts the value is an integer.
pub fn toBigIntAdvanced(
    val: Value,
    space: *BigIntSpace,
    mod: *Module,
    opt_sema: ?*Sema,
) Module.CompileError!BigIntConst {
    return switch (val.toIntern()) {
        .bool_false => BigIntMutable.init(&space.limbs, 0).toConst(),
        .bool_true => BigIntMutable.init(&space.limbs, 1).toConst(),
        .null_value => BigIntMutable.init(&space.limbs, 0).toConst(),
        else => switch (mod.intern_pool.indexToKey(val.toIntern())) {
            .int => |int| switch (int.storage) {
                .u64, .i64, .big_int => int.storage.toBigInt(space),
                .lazy_align, .lazy_size => |ty| {
                    if (opt_sema) |sema| try sema.resolveTypeLayout(Type.fromInterned(ty));
                    const x = switch (int.storage) {
                        else => unreachable,
                        .lazy_align => Type.fromInterned(ty).abiAlignment(mod).toByteUnits(0),
                        .lazy_size => Type.fromInterned(ty).abiSize(mod),
                    };
                    return BigIntMutable.init(&space.limbs, x).toConst();
                },
            },
            .enum_tag => |enum_tag| Value.fromInterned(enum_tag.int).toBigIntAdvanced(space, mod, opt_sema),
            .opt, .ptr => BigIntMutable.init(
                &space.limbs,
                (try val.getUnsignedIntAdvanced(mod, opt_sema)).?,
            ).toConst(),
            else => unreachable,
        },
    };
}

pub fn isFuncBody(val: Value, mod: *Module) bool {
    return mod.intern_pool.isFuncBody(val.toIntern());
}

pub fn getFunction(val: Value, mod: *Module) ?InternPool.Key.Func {
    return if (val.ip_index != .none) switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .func => |x| x,
        else => null,
    } else null;
}

pub fn getExternFunc(val: Value, mod: *Module) ?InternPool.Key.ExternFunc {
    return if (val.ip_index != .none) switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .extern_func => |extern_func| extern_func,
        else => null,
    } else null;
}

pub fn getVariable(val: Value, mod: *Module) ?InternPool.Key.Variable {
    return if (val.ip_index != .none) switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .variable => |variable| variable,
        else => null,
    } else null;
}

/// If the value fits in a u64, return it, otherwise null.
/// Asserts not undefined.
pub fn getUnsignedInt(val: Value, mod: *Module) ?u64 {
    return getUnsignedIntAdvanced(val, mod, null) catch unreachable;
}

/// If the value fits in a u64, return it, otherwise null.
/// Asserts not undefined.
pub fn getUnsignedIntAdvanced(val: Value, mod: *Module, opt_sema: ?*Sema) !?u64 {
    return switch (val.toIntern()) {
        .undef => unreachable,
        .bool_false => 0,
        .bool_true => 1,
        else => switch (mod.intern_pool.indexToKey(val.toIntern())) {
            .undef => unreachable,
            .int => |int| switch (int.storage) {
                .big_int => |big_int| big_int.to(u64) catch null,
                .u64 => |x| x,
                .i64 => |x| std.math.cast(u64, x),
                .lazy_align => |ty| if (opt_sema) |sema|
                    (try Type.fromInterned(ty).abiAlignmentAdvanced(mod, .{ .sema = sema })).scalar.toByteUnits(0)
                else
                    Type.fromInterned(ty).abiAlignment(mod).toByteUnits(0),
                .lazy_size => |ty| if (opt_sema) |sema|
                    (try Type.fromInterned(ty).abiSizeAdvanced(mod, .{ .sema = sema })).scalar
                else
                    Type.fromInterned(ty).abiSize(mod),
            },
            .ptr => |ptr| switch (ptr.addr) {
                .int => |int| Value.fromInterned(int).getUnsignedIntAdvanced(mod, opt_sema),
                .elem => |elem| {
                    const base_addr = (try Value.fromInterned(elem.base).getUnsignedIntAdvanced(mod, opt_sema)) orelse return null;
                    const elem_ty = Type.fromInterned(mod.intern_pool.typeOf(elem.base)).elemType2(mod);
                    return base_addr + elem.index * elem_ty.abiSize(mod);
                },
                .field => |field| {
                    const base_addr = (try Value.fromInterned(field.base).getUnsignedIntAdvanced(mod, opt_sema)) orelse return null;
                    const struct_ty = Type.fromInterned(mod.intern_pool.typeOf(field.base)).childType(mod);
                    if (opt_sema) |sema| try sema.resolveTypeLayout(struct_ty);
                    return base_addr + struct_ty.structFieldOffset(@as(usize, @intCast(field.index)), mod);
                },
                else => null,
            },
            .opt => |opt| switch (opt.val) {
                .none => 0,
                else => |payload| Value.fromInterned(payload).getUnsignedIntAdvanced(mod, opt_sema),
            },
            else => null,
        },
    };
}

/// Asserts the value is an integer and it fits in a u64
pub fn toUnsignedInt(val: Value, mod: *Module) u64 {
    return getUnsignedInt(val, mod).?;
}

/// Asserts the value is an integer and it fits in a u64
pub fn toUnsignedIntAdvanced(val: Value, sema: *Sema) !u64 {
    return (try getUnsignedIntAdvanced(val, sema.mod, sema)).?;
}

/// Asserts the value is an integer and it fits in a i64
pub fn toSignedInt(val: Value, mod: *Module) i64 {
    return switch (val.toIntern()) {
        .bool_false => 0,
        .bool_true => 1,
        else => switch (mod.intern_pool.indexToKey(val.toIntern())) {
            .int => |int| switch (int.storage) {
                .big_int => |big_int| big_int.to(i64) catch unreachable,
                .i64 => |x| x,
                .u64 => |x| @intCast(x),
                .lazy_align => |ty| @intCast(Type.fromInterned(ty).abiAlignment(mod).toByteUnits(0)),
                .lazy_size => |ty| @intCast(Type.fromInterned(ty).abiSize(mod)),
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

fn isDeclRef(val: Value, mod: *Module) bool {
    var check = val;
    while (true) switch (mod.intern_pool.indexToKey(check.toIntern())) {
        .ptr => |ptr| switch (ptr.addr) {
            .decl, .mut_decl, .comptime_field, .anon_decl => return true,
            .eu_payload, .opt_payload => |base| check = Value.fromInterned(base),
            .elem, .field => |base_index| check = Value.fromInterned(base_index.base),
            .int => return false,
        },
        else => return false,
    };
}

/// Write a Value's contents to `buffer`.
///
/// Asserts that buffer.len >= ty.abiSize(). The buffer is allowed to extend past
/// the end of the value in memory.
pub fn writeToMemory(val: Value, ty: Type, mod: *Module, buffer: []u8) error{
    ReinterpretDeclRef,
    IllDefinedMemoryLayout,
    Unimplemented,
    OutOfMemory,
}!void {
    const target = mod.getTarget();
    const endian = target.cpu.arch.endian();
    if (val.isUndef(mod)) {
        const size: usize = @intCast(ty.abiSize(mod));
        @memset(buffer[0..size], 0xaa);
        return;
    }
    const ip = &mod.intern_pool;
    switch (ty.zigTypeTag(mod)) {
        .Void => {},
        .Bool => {
            buffer[0] = @intFromBool(val.toBool());
        },
        .Int, .Enum => {
            const int_info = ty.intInfo(mod);
            const bits = int_info.bits;
            const byte_count: u16 = @intCast((@as(u17, bits) + 7) / 8);

            var bigint_buffer: BigIntSpace = undefined;
            const bigint = val.toBigInt(&bigint_buffer, mod);
            bigint.writeTwosComplement(buffer[0..byte_count], endian);
        },
        .Float => switch (ty.floatBits(target)) {
            16 => std.mem.writeInt(u16, buffer[0..2], @as(u16, @bitCast(val.toFloat(f16, mod))), endian),
            32 => std.mem.writeInt(u32, buffer[0..4], @as(u32, @bitCast(val.toFloat(f32, mod))), endian),
            64 => std.mem.writeInt(u64, buffer[0..8], @as(u64, @bitCast(val.toFloat(f64, mod))), endian),
            80 => std.mem.writeInt(u80, buffer[0..10], @as(u80, @bitCast(val.toFloat(f80, mod))), endian),
            128 => std.mem.writeInt(u128, buffer[0..16], @as(u128, @bitCast(val.toFloat(f128, mod))), endian),
            else => unreachable,
        },
        .Array => {
            const len = ty.arrayLen(mod);
            const elem_ty = ty.childType(mod);
            const elem_size = @as(usize, @intCast(elem_ty.abiSize(mod)));
            var elem_i: usize = 0;
            var buf_off: usize = 0;
            while (elem_i < len) : (elem_i += 1) {
                const elem_val = try val.elemValue(mod, elem_i);
                try elem_val.writeToMemory(elem_ty, mod, buffer[buf_off..]);
                buf_off += elem_size;
            }
        },
        .Vector => {
            // We use byte_count instead of abi_size here, so that any padding bytes
            // follow the data bytes, on both big- and little-endian systems.
            const byte_count = (@as(usize, @intCast(ty.bitSize(mod))) + 7) / 8;
            return writeToPackedMemory(val, ty, mod, buffer[0..byte_count], 0);
        },
        .Struct => {
            const struct_type = mod.typeToStruct(ty) orelse return error.IllDefinedMemoryLayout;
            switch (struct_type.layout) {
                .Auto => return error.IllDefinedMemoryLayout,
                .Extern => for (0..struct_type.field_types.len) |i| {
                    const off: usize = @intCast(ty.structFieldOffset(i, mod));
                    const field_val = switch (val.ip_index) {
                        .none => switch (val.tag()) {
                            .bytes => {
                                buffer[off] = val.castTag(.bytes).?.data[i];
                                continue;
                            },
                            .aggregate => val.castTag(.aggregate).?.data[i],
                            .repeated => val.castTag(.repeated).?.data,
                            else => unreachable,
                        },
                        else => Value.fromInterned(switch (ip.indexToKey(val.toIntern()).aggregate.storage) {
                            .bytes => |bytes| {
                                buffer[off] = bytes[i];
                                continue;
                            },
                            .elems => |elems| elems[i],
                            .repeated_elem => |elem| elem,
                        }),
                    };
                    const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[i]);
                    try writeToMemory(field_val, field_ty, mod, buffer[off..]);
                },
                .Packed => {
                    const byte_count = (@as(usize, @intCast(ty.bitSize(mod))) + 7) / 8;
                    return writeToPackedMemory(val, ty, mod, buffer[0..byte_count], 0);
                },
            }
        },
        .ErrorSet => {
            const bits = mod.errorSetBits();
            const byte_count: u16 = @intCast((@as(u17, bits) + 7) / 8);

            const name = switch (ip.indexToKey(val.toIntern())) {
                .err => |err| err.name,
                .error_union => |error_union| error_union.val.err_name,
                else => unreachable,
            };
            var bigint_buffer: BigIntSpace = undefined;
            const bigint = BigIntMutable.init(
                &bigint_buffer.limbs,
                mod.global_error_set.getIndex(name).?,
            ).toConst();
            bigint.writeTwosComplement(buffer[0..byte_count], endian);
        },
        .Union => switch (ty.containerLayout(mod)) {
            .Auto => return error.IllDefinedMemoryLayout, // Sema is supposed to have emitted a compile error already
            .Extern => {
                if (val.unionTag(mod)) |union_tag| {
                    const union_obj = mod.typeToUnion(ty).?;
                    const field_index = mod.unionTagFieldIndex(union_obj, union_tag).?;
                    const field_type = Type.fromInterned(union_obj.field_types.get(&mod.intern_pool)[field_index]);
                    const field_val = try val.fieldValue(mod, field_index);
                    const byte_count = @as(usize, @intCast(field_type.abiSize(mod)));
                    return writeToMemory(field_val, field_type, mod, buffer[0..byte_count]);
                } else {
                    const backing_ty = try ty.unionBackingType(mod);
                    const byte_count: usize = @intCast(backing_ty.abiSize(mod));
                    return writeToMemory(val.unionValue(mod), backing_ty, mod, buffer[0..byte_count]);
                }
            },
            .Packed => {
                const backing_ty = try ty.unionBackingType(mod);
                const byte_count: usize = @intCast(backing_ty.abiSize(mod));
                return writeToPackedMemory(val, ty, mod, buffer[0..byte_count], 0);
            },
        },
        .Pointer => {
            if (ty.isSlice(mod)) return error.IllDefinedMemoryLayout;
            if (val.isDeclRef(mod)) return error.ReinterpretDeclRef;
            return val.writeToMemory(Type.usize, mod, buffer);
        },
        .Optional => {
            if (!ty.isPtrLikeOptional(mod)) return error.IllDefinedMemoryLayout;
            const child = ty.optionalChild(mod);
            const opt_val = val.optionalValue(mod);
            if (opt_val) |some| {
                return some.writeToMemory(child, mod, buffer);
            } else {
                return writeToMemory(try mod.intValue(Type.usize, 0), Type.usize, mod, buffer);
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
    mod: *Module,
    buffer: []u8,
    bit_offset: usize,
) error{ ReinterpretDeclRef, OutOfMemory }!void {
    const ip = &mod.intern_pool;
    const target = mod.getTarget();
    const endian = target.cpu.arch.endian();
    if (val.isUndef(mod)) {
        const bit_size = @as(usize, @intCast(ty.bitSize(mod)));
        std.mem.writeVarPackedInt(buffer, bit_offset, bit_size, @as(u1, 0), endian);
        return;
    }
    switch (ty.zigTypeTag(mod)) {
        .Void => {},
        .Bool => {
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
        .Int, .Enum => {
            if (buffer.len == 0) return;
            const bits = ty.intInfo(mod).bits;
            if (bits == 0) return;

            switch (ip.indexToKey((try val.intFromEnum(ty, mod)).toIntern()).int.storage) {
                inline .u64, .i64 => |int| std.mem.writeVarPackedInt(buffer, bit_offset, bits, int, endian),
                .big_int => |bigint| bigint.writePackedTwosComplement(buffer, bit_offset, bits, endian),
                .lazy_align => |lazy_align| {
                    const num = Type.fromInterned(lazy_align).abiAlignment(mod).toByteUnits(0);
                    std.mem.writeVarPackedInt(buffer, bit_offset, bits, num, endian);
                },
                .lazy_size => |lazy_size| {
                    const num = Type.fromInterned(lazy_size).abiSize(mod);
                    std.mem.writeVarPackedInt(buffer, bit_offset, bits, num, endian);
                },
            }
        },
        .Float => switch (ty.floatBits(target)) {
            16 => std.mem.writePackedInt(u16, buffer, bit_offset, @as(u16, @bitCast(val.toFloat(f16, mod))), endian),
            32 => std.mem.writePackedInt(u32, buffer, bit_offset, @as(u32, @bitCast(val.toFloat(f32, mod))), endian),
            64 => std.mem.writePackedInt(u64, buffer, bit_offset, @as(u64, @bitCast(val.toFloat(f64, mod))), endian),
            80 => std.mem.writePackedInt(u80, buffer, bit_offset, @as(u80, @bitCast(val.toFloat(f80, mod))), endian),
            128 => std.mem.writePackedInt(u128, buffer, bit_offset, @as(u128, @bitCast(val.toFloat(f128, mod))), endian),
            else => unreachable,
        },
        .Vector => {
            const elem_ty = ty.childType(mod);
            const elem_bit_size = @as(u16, @intCast(elem_ty.bitSize(mod)));
            const len = @as(usize, @intCast(ty.arrayLen(mod)));

            var bits: u16 = 0;
            var elem_i: usize = 0;
            while (elem_i < len) : (elem_i += 1) {
                // On big-endian systems, LLVM reverses the element order of vectors by default
                const tgt_elem_i = if (endian == .big) len - elem_i - 1 else elem_i;
                const elem_val = try val.elemValue(mod, tgt_elem_i);
                try elem_val.writeToPackedMemory(elem_ty, mod, buffer, bit_offset + bits);
                bits += elem_bit_size;
            }
        },
        .Struct => {
            const struct_type = ip.indexToKey(ty.toIntern()).struct_type;
            // Sema is supposed to have emitted a compile error already in the case of Auto,
            // and Extern is handled in non-packed writeToMemory.
            assert(struct_type.layout == .Packed);
            var bits: u16 = 0;
            for (0..struct_type.field_types.len) |i| {
                const field_val = switch (val.ip_index) {
                    .none => switch (val.tag()) {
                        .bytes => unreachable,
                        .aggregate => val.castTag(.aggregate).?.data[i],
                        .repeated => val.castTag(.repeated).?.data,
                        else => unreachable,
                    },
                    else => Value.fromInterned(switch (ip.indexToKey(val.toIntern()).aggregate.storage) {
                        .bytes => unreachable,
                        .elems => |elems| elems[i],
                        .repeated_elem => |elem| elem,
                    }),
                };
                const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[i]);
                const field_bits: u16 = @intCast(field_ty.bitSize(mod));
                try field_val.writeToPackedMemory(field_ty, mod, buffer, bit_offset + bits);
                bits += field_bits;
            }
        },
        .Union => {
            const union_obj = mod.typeToUnion(ty).?;
            switch (union_obj.getLayout(ip)) {
                .Auto, .Extern => unreachable, // Handled in non-packed writeToMemory
                .Packed => {
                    if (val.unionTag(mod)) |union_tag| {
                        const field_index = mod.unionTagFieldIndex(union_obj, union_tag).?;
                        const field_type = Type.fromInterned(union_obj.field_types.get(ip)[field_index]);
                        const field_val = try val.fieldValue(mod, field_index);
                        return field_val.writeToPackedMemory(field_type, mod, buffer, bit_offset);
                    } else {
                        const backing_ty = try ty.unionBackingType(mod);
                        return val.unionValue(mod).writeToPackedMemory(backing_ty, mod, buffer, bit_offset);
                    }
                },
            }
        },
        .Pointer => {
            assert(!ty.isSlice(mod)); // No well defined layout.
            if (val.isDeclRef(mod)) return error.ReinterpretDeclRef;
            return val.writeToPackedMemory(Type.usize, mod, buffer, bit_offset);
        },
        .Optional => {
            assert(ty.isPtrLikeOptional(mod));
            const child = ty.optionalChild(mod);
            const opt_val = val.optionalValue(mod);
            if (opt_val) |some| {
                return some.writeToPackedMemory(child, mod, buffer, bit_offset);
            } else {
                return writeToPackedMemory(try mod.intValue(Type.usize, 0), Type.usize, mod, buffer, bit_offset);
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
    mod: *Module,
    buffer: []const u8,
    arena: Allocator,
) error{
    IllDefinedMemoryLayout,
    Unimplemented,
    OutOfMemory,
}!Value {
    const ip = &mod.intern_pool;
    const target = mod.getTarget();
    const endian = target.cpu.arch.endian();
    switch (ty.zigTypeTag(mod)) {
        .Void => return Value.void,
        .Bool => {
            if (buffer[0] == 0) {
                return Value.false;
            } else {
                return Value.true;
            }
        },
        .Int, .Enum => |ty_tag| {
            const int_ty = switch (ty_tag) {
                .Int => ty,
                .Enum => ty.intTagType(mod),
                else => unreachable,
            };
            const int_info = int_ty.intInfo(mod);
            const bits = int_info.bits;
            const byte_count: u16 = @intCast((@as(u17, bits) + 7) / 8);
            if (bits == 0 or buffer.len == 0) return mod.getCoerced(try mod.intValue(int_ty, 0), ty);

            if (bits <= 64) switch (int_info.signedness) { // Fast path for integers <= u64
                .signed => {
                    const val = std.mem.readVarInt(i64, buffer[0..byte_count], endian);
                    const result = (val << @as(u6, @intCast(64 - bits))) >> @as(u6, @intCast(64 - bits));
                    return mod.getCoerced(try mod.intValue(int_ty, result), ty);
                },
                .unsigned => {
                    const val = std.mem.readVarInt(u64, buffer[0..byte_count], endian);
                    const result = (val << @as(u6, @intCast(64 - bits))) >> @as(u6, @intCast(64 - bits));
                    return mod.getCoerced(try mod.intValue(int_ty, result), ty);
                },
            } else { // Slow path, we have to construct a big-int
                const Limb = std.math.big.Limb;
                const limb_count = (byte_count + @sizeOf(Limb) - 1) / @sizeOf(Limb);
                const limbs_buffer = try arena.alloc(Limb, limb_count);

                var bigint = BigIntMutable.init(limbs_buffer, 0);
                bigint.readTwosComplement(buffer[0..byte_count], bits, endian, int_info.signedness);
                return mod.getCoerced(try mod.intValue_big(int_ty, bigint.toConst()), ty);
            }
        },
        .Float => return Value.fromInterned((try mod.intern(.{ .float = .{
            .ty = ty.toIntern(),
            .storage = switch (ty.floatBits(target)) {
                16 => .{ .f16 = @as(f16, @bitCast(std.mem.readInt(u16, buffer[0..2], endian))) },
                32 => .{ .f32 = @as(f32, @bitCast(std.mem.readInt(u32, buffer[0..4], endian))) },
                64 => .{ .f64 = @as(f64, @bitCast(std.mem.readInt(u64, buffer[0..8], endian))) },
                80 => .{ .f80 = @as(f80, @bitCast(std.mem.readInt(u80, buffer[0..10], endian))) },
                128 => .{ .f128 = @as(f128, @bitCast(std.mem.readInt(u128, buffer[0..16], endian))) },
                else => unreachable,
            },
        } }))),
        .Array => {
            const elem_ty = ty.childType(mod);
            const elem_size = elem_ty.abiSize(mod);
            const elems = try arena.alloc(InternPool.Index, @as(usize, @intCast(ty.arrayLen(mod))));
            var offset: usize = 0;
            for (elems) |*elem| {
                elem.* = try (try readFromMemory(elem_ty, mod, buffer[offset..], arena)).intern(elem_ty, mod);
                offset += @as(usize, @intCast(elem_size));
            }
            return Value.fromInterned((try mod.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = elems },
            } })));
        },
        .Vector => {
            // We use byte_count instead of abi_size here, so that any padding bytes
            // follow the data bytes, on both big- and little-endian systems.
            const byte_count = (@as(usize, @intCast(ty.bitSize(mod))) + 7) / 8;
            return readFromPackedMemory(ty, mod, buffer[0..byte_count], 0, arena);
        },
        .Struct => {
            const struct_type = mod.typeToStruct(ty).?;
            switch (struct_type.layout) {
                .Auto => unreachable, // Sema is supposed to have emitted a compile error already
                .Extern => {
                    const field_types = struct_type.field_types;
                    const field_vals = try arena.alloc(InternPool.Index, field_types.len);
                    for (field_vals, 0..) |*field_val, i| {
                        const field_ty = Type.fromInterned(field_types.get(ip)[i]);
                        const off: usize = @intCast(ty.structFieldOffset(i, mod));
                        const sz: usize = @intCast(field_ty.abiSize(mod));
                        field_val.* = try (try readFromMemory(field_ty, mod, buffer[off..(off + sz)], arena)).intern(field_ty, mod);
                    }
                    return Value.fromInterned((try mod.intern(.{ .aggregate = .{
                        .ty = ty.toIntern(),
                        .storage = .{ .elems = field_vals },
                    } })));
                },
                .Packed => {
                    const byte_count = (@as(usize, @intCast(ty.bitSize(mod))) + 7) / 8;
                    return readFromPackedMemory(ty, mod, buffer[0..byte_count], 0, arena);
                },
            }
        },
        .ErrorSet => {
            const bits = mod.errorSetBits();
            const byte_count: u16 = @intCast((@as(u17, bits) + 7) / 8);
            const int = std.mem.readVarInt(u64, buffer[0..byte_count], endian);
            const index = (int << @as(u6, @intCast(64 - bits))) >> @as(u6, @intCast(64 - bits));
            const name = mod.global_error_set.keys()[@intCast(index)];

            return Value.fromInterned((try mod.intern(.{ .err = .{
                .ty = ty.toIntern(),
                .name = name,
            } })));
        },
        .Union => switch (ty.containerLayout(mod)) {
            .Auto => return error.IllDefinedMemoryLayout,
            .Extern => {
                const union_size = ty.abiSize(mod);
                const array_ty = try mod.arrayType(.{ .len = union_size, .child = .u8_type });
                const val = try (try readFromMemory(array_ty, mod, buffer, arena)).intern(array_ty, mod);
                return Value.fromInterned((try mod.intern(.{ .un = .{
                    .ty = ty.toIntern(),
                    .tag = .none,
                    .val = val,
                } })));
            },
            .Packed => {
                const byte_count = (@as(usize, @intCast(ty.bitSize(mod))) + 7) / 8;
                return readFromPackedMemory(ty, mod, buffer[0..byte_count], 0, arena);
            },
        },
        .Pointer => {
            assert(!ty.isSlice(mod)); // No well defined layout.
            const int_val = try readFromMemory(Type.usize, mod, buffer, arena);
            return Value.fromInterned((try mod.intern(.{ .ptr = .{
                .ty = ty.toIntern(),
                .addr = .{ .int = int_val.toIntern() },
            } })));
        },
        .Optional => {
            assert(ty.isPtrLikeOptional(mod));
            const child_ty = ty.optionalChild(mod);
            const child_val = try readFromMemory(child_ty, mod, buffer, arena);
            return Value.fromInterned((try mod.intern(.{ .opt = .{
                .ty = ty.toIntern(),
                .val = switch (child_val.orderAgainstZero(mod)) {
                    .lt => unreachable,
                    .eq => .none,
                    .gt => child_val.toIntern(),
                },
            } })));
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
    mod: *Module,
    buffer: []const u8,
    bit_offset: usize,
    arena: Allocator,
) error{
    IllDefinedMemoryLayout,
    OutOfMemory,
}!Value {
    const ip = &mod.intern_pool;
    const target = mod.getTarget();
    const endian = target.cpu.arch.endian();
    switch (ty.zigTypeTag(mod)) {
        .Void => return Value.void,
        .Bool => {
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
        .Int, .Enum => |ty_tag| {
            if (buffer.len == 0) return mod.intValue(ty, 0);
            const int_info = ty.intInfo(mod);
            const bits = int_info.bits;
            if (bits == 0) return mod.intValue(ty, 0);

            // Fast path for integers <= u64
            if (bits <= 64) {
                const int_ty = switch (ty_tag) {
                    .Int => ty,
                    .Enum => ty.intTagType(mod),
                    else => unreachable,
                };
                return mod.getCoerced(switch (int_info.signedness) {
                    .signed => return mod.intValue(
                        int_ty,
                        std.mem.readVarPackedInt(i64, buffer, bit_offset, bits, endian, .signed),
                    ),
                    .unsigned => return mod.intValue(
                        int_ty,
                        std.mem.readVarPackedInt(u64, buffer, bit_offset, bits, endian, .unsigned),
                    ),
                }, ty);
            }

            // Slow path, we have to construct a big-int
            const abi_size = @as(usize, @intCast(ty.abiSize(mod)));
            const Limb = std.math.big.Limb;
            const limb_count = (abi_size + @sizeOf(Limb) - 1) / @sizeOf(Limb);
            const limbs_buffer = try arena.alloc(Limb, limb_count);

            var bigint = BigIntMutable.init(limbs_buffer, 0);
            bigint.readPackedTwosComplement(buffer, bit_offset, bits, endian, int_info.signedness);
            return mod.intValue_big(ty, bigint.toConst());
        },
        .Float => return Value.fromInterned((try mod.intern(.{ .float = .{
            .ty = ty.toIntern(),
            .storage = switch (ty.floatBits(target)) {
                16 => .{ .f16 = @as(f16, @bitCast(std.mem.readPackedInt(u16, buffer, bit_offset, endian))) },
                32 => .{ .f32 = @as(f32, @bitCast(std.mem.readPackedInt(u32, buffer, bit_offset, endian))) },
                64 => .{ .f64 = @as(f64, @bitCast(std.mem.readPackedInt(u64, buffer, bit_offset, endian))) },
                80 => .{ .f80 = @as(f80, @bitCast(std.mem.readPackedInt(u80, buffer, bit_offset, endian))) },
                128 => .{ .f128 = @as(f128, @bitCast(std.mem.readPackedInt(u128, buffer, bit_offset, endian))) },
                else => unreachable,
            },
        } }))),
        .Vector => {
            const elem_ty = ty.childType(mod);
            const elems = try arena.alloc(InternPool.Index, @as(usize, @intCast(ty.arrayLen(mod))));

            var bits: u16 = 0;
            const elem_bit_size = @as(u16, @intCast(elem_ty.bitSize(mod)));
            for (elems, 0..) |_, i| {
                // On big-endian systems, LLVM reverses the element order of vectors by default
                const tgt_elem_i = if (endian == .big) elems.len - i - 1 else i;
                elems[tgt_elem_i] = try (try readFromPackedMemory(elem_ty, mod, buffer, bit_offset + bits, arena)).intern(elem_ty, mod);
                bits += elem_bit_size;
            }
            return Value.fromInterned((try mod.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = elems },
            } })));
        },
        .Struct => {
            // Sema is supposed to have emitted a compile error already for Auto layout structs,
            // and Extern is handled by non-packed readFromMemory.
            const struct_type = mod.typeToPackedStruct(ty).?;
            var bits: u16 = 0;
            const field_vals = try arena.alloc(InternPool.Index, struct_type.field_types.len);
            for (field_vals, 0..) |*field_val, i| {
                const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[i]);
                const field_bits: u16 = @intCast(field_ty.bitSize(mod));
                field_val.* = try (try readFromPackedMemory(field_ty, mod, buffer, bit_offset + bits, arena)).intern(field_ty, mod);
                bits += field_bits;
            }
            return Value.fromInterned((try mod.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = field_vals },
            } })));
        },
        .Union => switch (ty.containerLayout(mod)) {
            .Auto, .Extern => unreachable, // Handled by non-packed readFromMemory
            .Packed => {
                const backing_ty = try ty.unionBackingType(mod);
                const val = (try readFromPackedMemory(backing_ty, mod, buffer, bit_offset, arena)).toIntern();
                return Value.fromInterned((try mod.intern(.{ .un = .{
                    .ty = ty.toIntern(),
                    .tag = .none,
                    .val = val,
                } })));
            },
        },
        .Pointer => {
            assert(!ty.isSlice(mod)); // No well defined layout.
            return readFromPackedMemory(Type.usize, mod, buffer, bit_offset, arena);
        },
        .Optional => {
            assert(ty.isPtrLikeOptional(mod));
            const child = ty.optionalChild(mod);
            return readFromPackedMemory(child, mod, buffer, bit_offset, arena);
        },
        else => @panic("TODO implement readFromPackedMemory for more types"),
    }
}

/// Asserts that the value is a float or an integer.
pub fn toFloat(val: Value, comptime T: type, mod: *Module) T {
    return switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .int => |int| switch (int.storage) {
            .big_int => |big_int| @floatCast(bigIntToFloat(big_int.limbs, big_int.positive)),
            inline .u64, .i64 => |x| {
                if (T == f80) {
                    @panic("TODO we can't lower this properly on non-x86 llvm backend yet");
                }
                return @floatFromInt(x);
            },
            .lazy_align => |ty| @floatFromInt(Type.fromInterned(ty).abiAlignment(mod).toByteUnits(0)),
            .lazy_size => |ty| @floatFromInt(Type.fromInterned(ty).abiSize(mod)),
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
        const limb: f128 = @as(f128, @floatFromInt(limbs[i]));
        result = @mulAdd(f128, base, result, limb);
    }
    if (positive) {
        return result;
    } else {
        return -result;
    }
}

pub fn clz(val: Value, ty: Type, mod: *Module) u64 {
    var bigint_buf: BigIntSpace = undefined;
    const bigint = val.toBigInt(&bigint_buf, mod);
    return bigint.clz(ty.intInfo(mod).bits);
}

pub fn ctz(val: Value, ty: Type, mod: *Module) u64 {
    var bigint_buf: BigIntSpace = undefined;
    const bigint = val.toBigInt(&bigint_buf, mod);
    return bigint.ctz(ty.intInfo(mod).bits);
}

pub fn popCount(val: Value, ty: Type, mod: *Module) u64 {
    var bigint_buf: BigIntSpace = undefined;
    const bigint = val.toBigInt(&bigint_buf, mod);
    return @as(u64, @intCast(bigint.popCount(ty.intInfo(mod).bits)));
}

pub fn bitReverse(val: Value, ty: Type, mod: *Module, arena: Allocator) !Value {
    const info = ty.intInfo(mod);

    var buffer: Value.BigIntSpace = undefined;
    const operand_bigint = val.toBigInt(&buffer, mod);

    const limbs = try arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.bitReverse(operand_bigint, info.signedness, info.bits);

    return mod.intValue_big(ty, result_bigint.toConst());
}

pub fn byteSwap(val: Value, ty: Type, mod: *Module, arena: Allocator) !Value {
    const info = ty.intInfo(mod);

    // Bit count must be evenly divisible by 8
    assert(info.bits % 8 == 0);

    var buffer: Value.BigIntSpace = undefined;
    const operand_bigint = val.toBigInt(&buffer, mod);

    const limbs = try arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.byteSwap(operand_bigint, info.signedness, info.bits / 8);

    return mod.intValue_big(ty, result_bigint.toConst());
}

/// Asserts the value is an integer and not undefined.
/// Returns the number of bits the value requires to represent stored in twos complement form.
pub fn intBitCountTwosComp(self: Value, mod: *Module) usize {
    var buffer: BigIntSpace = undefined;
    const big_int = self.toBigInt(&buffer, mod);
    return big_int.bitCountTwosComp();
}

/// Converts an integer or a float to a float. May result in a loss of information.
/// Caller can find out by equality checking the result against the operand.
pub fn floatCast(self: Value, dest_ty: Type, mod: *Module) !Value {
    const target = mod.getTarget();
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = dest_ty.toIntern(),
        .storage = switch (dest_ty.floatBits(target)) {
            16 => .{ .f16 = self.toFloat(f16, mod) },
            32 => .{ .f32 = self.toFloat(f32, mod) },
            64 => .{ .f64 = self.toFloat(f64, mod) },
            80 => .{ .f80 = self.toFloat(f80, mod) },
            128 => .{ .f128 = self.toFloat(f128, mod) },
            else => unreachable,
        },
    } })));
}

/// Asserts the value is a float
pub fn floatHasFraction(self: Value, mod: *const Module) bool {
    return switch (mod.intern_pool.indexToKey(self.toIntern())) {
        .float => |float| switch (float.storage) {
            inline else => |x| @rem(x, 1) != 0,
        },
        else => unreachable,
    };
}

pub fn orderAgainstZero(lhs: Value, mod: *Module) std.math.Order {
    return orderAgainstZeroAdvanced(lhs, mod, null) catch unreachable;
}

pub fn orderAgainstZeroAdvanced(
    lhs: Value,
    mod: *Module,
    opt_sema: ?*Sema,
) Module.CompileError!std.math.Order {
    return switch (lhs.toIntern()) {
        .bool_false => .eq,
        .bool_true => .gt,
        else => switch (mod.intern_pool.indexToKey(lhs.toIntern())) {
            .ptr => |ptr| switch (ptr.addr) {
                .decl, .mut_decl, .comptime_field => .gt,
                .int => |int| Value.fromInterned(int).orderAgainstZeroAdvanced(mod, opt_sema),
                .elem => |elem| switch (try Value.fromInterned(elem.base).orderAgainstZeroAdvanced(mod, opt_sema)) {
                    .lt => unreachable,
                    .gt => .gt,
                    .eq => if (elem.index == 0) .eq else .gt,
                },
                else => unreachable,
            },
            .int => |int| switch (int.storage) {
                .big_int => |big_int| big_int.orderAgainstScalar(0),
                inline .u64, .i64 => |x| std.math.order(x, 0),
                .lazy_align => .gt, // alignment is never 0
                .lazy_size => |ty| return if (Type.fromInterned(ty).hasRuntimeBitsAdvanced(
                    mod,
                    false,
                    if (opt_sema) |sema| .{ .sema = sema } else .eager,
                ) catch |err| switch (err) {
                    error.NeedLazy => unreachable,
                    else => |e| return e,
                }) .gt else .eq,
            },
            .enum_tag => |enum_tag| Value.fromInterned(enum_tag.int).orderAgainstZeroAdvanced(mod, opt_sema),
            .float => |float| switch (float.storage) {
                inline else => |x| std.math.order(x, 0),
            },
            else => unreachable,
        },
    };
}

/// Asserts the value is comparable.
pub fn order(lhs: Value, rhs: Value, mod: *Module) std.math.Order {
    return orderAdvanced(lhs, rhs, mod, null) catch unreachable;
}

/// Asserts the value is comparable.
/// If opt_sema is null then this function asserts things are resolved and cannot fail.
pub fn orderAdvanced(lhs: Value, rhs: Value, mod: *Module, opt_sema: ?*Sema) !std.math.Order {
    const lhs_against_zero = try lhs.orderAgainstZeroAdvanced(mod, opt_sema);
    const rhs_against_zero = try rhs.orderAgainstZeroAdvanced(mod, opt_sema);
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

    if (lhs.isFloat(mod) or rhs.isFloat(mod)) {
        const lhs_f128 = lhs.toFloat(f128, mod);
        const rhs_f128 = rhs.toFloat(f128, mod);
        return std.math.order(lhs_f128, rhs_f128);
    }

    var lhs_bigint_space: BigIntSpace = undefined;
    var rhs_bigint_space: BigIntSpace = undefined;
    const lhs_bigint = try lhs.toBigIntAdvanced(&lhs_bigint_space, mod, opt_sema);
    const rhs_bigint = try rhs.toBigIntAdvanced(&rhs_bigint_space, mod, opt_sema);
    return lhs_bigint.order(rhs_bigint);
}

/// Asserts the value is comparable. Does not take a type parameter because it supports
/// comparisons between heterogeneous types.
pub fn compareHetero(lhs: Value, op: std.math.CompareOperator, rhs: Value, mod: *Module) bool {
    return compareHeteroAdvanced(lhs, op, rhs, mod, null) catch unreachable;
}

pub fn compareHeteroAdvanced(
    lhs: Value,
    op: std.math.CompareOperator,
    rhs: Value,
    mod: *Module,
    opt_sema: ?*Sema,
) !bool {
    if (lhs.pointerDecl(mod)) |lhs_decl| {
        if (rhs.pointerDecl(mod)) |rhs_decl| {
            switch (op) {
                .eq => return lhs_decl == rhs_decl,
                .neq => return lhs_decl != rhs_decl,
                else => {},
            }
        } else {
            switch (op) {
                .eq => return false,
                .neq => return true,
                else => {},
            }
        }
    } else if (rhs.pointerDecl(mod)) |_| {
        switch (op) {
            .eq => return false,
            .neq => return true,
            else => {},
        }
    }
    return (try orderAdvanced(lhs, rhs, mod, opt_sema)).compare(op);
}

/// Asserts the values are comparable. Both operands have type `ty`.
/// For vectors, returns true if comparison is true for ALL elements.
pub fn compareAll(lhs: Value, op: std.math.CompareOperator, rhs: Value, ty: Type, mod: *Module) !bool {
    if (ty.zigTypeTag(mod) == .Vector) {
        const scalar_ty = ty.scalarType(mod);
        for (0..ty.vectorLen(mod)) |i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            if (!compareScalar(lhs_elem, op, rhs_elem, scalar_ty, mod)) {
                return false;
            }
        }
        return true;
    }
    return compareScalar(lhs, op, rhs, ty, mod);
}

/// Asserts the values are comparable. Both operands have type `ty`.
pub fn compareScalar(
    lhs: Value,
    op: std.math.CompareOperator,
    rhs: Value,
    ty: Type,
    mod: *Module,
) bool {
    return switch (op) {
        .eq => lhs.eql(rhs, ty, mod),
        .neq => !lhs.eql(rhs, ty, mod),
        else => compareHetero(lhs, op, rhs, mod),
    };
}

/// Asserts the value is comparable.
/// For vectors, returns true if comparison is true for ALL elements.
///
/// Note that `!compareAllWithZero(.eq, ...) != compareAllWithZero(.neq, ...)`
pub fn compareAllWithZero(lhs: Value, op: std.math.CompareOperator, mod: *Module) bool {
    return compareAllWithZeroAdvancedExtra(lhs, op, mod, null) catch unreachable;
}

pub fn compareAllWithZeroAdvanced(
    lhs: Value,
    op: std.math.CompareOperator,
    sema: *Sema,
) Module.CompileError!bool {
    return compareAllWithZeroAdvancedExtra(lhs, op, sema.mod, sema);
}

pub fn compareAllWithZeroAdvancedExtra(
    lhs: Value,
    op: std.math.CompareOperator,
    mod: *Module,
    opt_sema: ?*Sema,
) Module.CompileError!bool {
    if (lhs.isInf(mod)) {
        switch (op) {
            .neq => return true,
            .eq => return false,
            .gt, .gte => return !lhs.isNegativeInf(mod),
            .lt, .lte => return lhs.isNegativeInf(mod),
        }
    }

    switch (mod.intern_pool.indexToKey(lhs.toIntern())) {
        .float => |float| switch (float.storage) {
            inline else => |x| if (std.math.isNan(x)) return op == .neq,
        },
        .aggregate => |aggregate| return switch (aggregate.storage) {
            .bytes => |bytes| for (bytes) |byte| {
                if (!std.math.order(byte, 0).compare(op)) break false;
            } else true,
            .elems => |elems| for (elems) |elem| {
                if (!try Value.fromInterned(elem).compareAllWithZeroAdvancedExtra(op, mod, opt_sema)) break false;
            } else true,
            .repeated_elem => |elem| Value.fromInterned(elem).compareAllWithZeroAdvancedExtra(op, mod, opt_sema),
        },
        else => {},
    }
    return (try orderAgainstZeroAdvanced(lhs, mod, opt_sema)).compare(op);
}

pub fn eql(a: Value, b: Value, ty: Type, mod: *Module) bool {
    assert(mod.intern_pool.typeOf(a.toIntern()) == ty.toIntern());
    assert(mod.intern_pool.typeOf(b.toIntern()) == ty.toIntern());
    return a.toIntern() == b.toIntern();
}

pub fn isComptimeMutablePtr(val: Value, mod: *Module) bool {
    return switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .slice => |slice| return Value.fromInterned(slice.ptr).isComptimeMutablePtr(mod),
        .ptr => |ptr| switch (ptr.addr) {
            .mut_decl, .comptime_field => true,
            .eu_payload, .opt_payload => |base_ptr| Value.fromInterned(base_ptr).isComptimeMutablePtr(mod),
            .elem, .field => |base_index| Value.fromInterned(base_index.base).isComptimeMutablePtr(mod),
            else => false,
        },
        else => false,
    };
}

pub fn canMutateComptimeVarState(val: Value, mod: *Module) bool {
    return val.isComptimeMutablePtr(mod) or switch (val.toIntern()) {
        else => switch (mod.intern_pool.indexToKey(val.toIntern())) {
            .error_union => |error_union| switch (error_union.val) {
                .err_name => false,
                .payload => |payload| Value.fromInterned(payload).canMutateComptimeVarState(mod),
            },
            .ptr => |ptr| switch (ptr.addr) {
                .eu_payload, .opt_payload => |base| Value.fromInterned(base).canMutateComptimeVarState(mod),
                .anon_decl => |anon_decl| Value.fromInterned(anon_decl.val).canMutateComptimeVarState(mod),
                .elem, .field => |base_index| Value.fromInterned(base_index.base).canMutateComptimeVarState(mod),
                else => false,
            },
            .opt => |opt| switch (opt.val) {
                .none => false,
                else => |payload| Value.fromInterned(payload).canMutateComptimeVarState(mod),
            },
            .aggregate => |aggregate| for (aggregate.storage.values()) |elem| {
                if (Value.fromInterned(elem).canMutateComptimeVarState(mod)) break true;
            } else false,
            .un => |un| Value.fromInterned(un.val).canMutateComptimeVarState(mod),
            else => false,
        },
    };
}

/// Gets the decl referenced by this pointer.  If the pointer does not point
/// to a decl, or if it points to some part of a decl (like field_ptr or element_ptr),
/// this function returns null.
pub fn pointerDecl(val: Value, mod: *Module) ?InternPool.DeclIndex {
    return switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .variable => |variable| variable.decl,
        .extern_func => |extern_func| extern_func.decl,
        .func => |func| func.owner_decl,
        .ptr => |ptr| switch (ptr.addr) {
            .decl => |decl| decl,
            .mut_decl => |mut_decl| mut_decl.decl,
            else => null,
        },
        else => null,
    };
}

pub const slice_ptr_index = 0;
pub const slice_len_index = 1;

pub fn slicePtr(val: Value, mod: *Module) Value {
    return Value.fromInterned(mod.intern_pool.slicePtr(val.toIntern()));
}

pub fn sliceLen(val: Value, mod: *Module) u64 {
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(val.toIntern())) {
        .ptr => |ptr| switch (ip.indexToKey(switch (ptr.addr) {
            .decl => |decl| mod.declPtr(decl).ty.toIntern(),
            .mut_decl => |mut_decl| mod.declPtr(mut_decl.decl).ty.toIntern(),
            .anon_decl => |anon_decl| ip.typeOf(anon_decl.val),
            .comptime_field => |comptime_field| ip.typeOf(comptime_field),
            else => unreachable,
        })) {
            .array_type => |array_type| array_type.len,
            else => 1,
        },
        .slice => |slice| Value.fromInterned(slice.len).toUnsignedInt(mod),
        else => unreachable,
    };
}

/// Asserts the value is a single-item pointer to an array, or an array,
/// or an unknown-length pointer, and returns the element value at the index.
pub fn elemValue(val: Value, mod: *Module, index: usize) Allocator.Error!Value {
    return (try val.maybeElemValue(mod, index)).?;
}

/// Like `elemValue`, but returns `null` instead of asserting on failure.
pub fn maybeElemValue(val: Value, mod: *Module, index: usize) Allocator.Error!?Value {
    return switch (val.ip_index) {
        .none => switch (val.tag()) {
            .bytes => try mod.intValue(Type.u8, val.castTag(.bytes).?.data[index]),
            .repeated => val.castTag(.repeated).?.data,
            .aggregate => val.castTag(.aggregate).?.data[index],
            .slice => val.castTag(.slice).?.data.ptr.maybeElemValue(mod, index),
            else => null,
        },
        else => switch (mod.intern_pool.indexToKey(val.toIntern())) {
            .undef => |ty| Value.fromInterned((try mod.intern(.{
                .undef = Type.fromInterned(ty).elemType2(mod).toIntern(),
            }))),
            .slice => |slice| return Value.fromInterned(slice.ptr).maybeElemValue(mod, index),
            .ptr => |ptr| switch (ptr.addr) {
                .decl => |decl| mod.declPtr(decl).val.maybeElemValue(mod, index),
                .anon_decl => |anon_decl| Value.fromInterned(anon_decl.val).maybeElemValue(mod, index),
                .mut_decl => |mut_decl| Value.fromInterned((try mod.declPtr(mut_decl.decl).internValue(mod))).maybeElemValue(mod, index),
                .int, .eu_payload => null,
                .opt_payload => |base| Value.fromInterned(base).maybeElemValue(mod, index),
                .comptime_field => |field_val| Value.fromInterned(field_val).maybeElemValue(mod, index),
                .elem => |elem| Value.fromInterned(elem.base).maybeElemValue(mod, index + @as(usize, @intCast(elem.index))),
                .field => |field| if (Value.fromInterned(field.base).pointerDecl(mod)) |decl_index| {
                    const base_decl = mod.declPtr(decl_index);
                    const field_val = try base_decl.val.fieldValue(mod, @as(usize, @intCast(field.index)));
                    return field_val.maybeElemValue(mod, index);
                } else null,
            },
            .opt => |opt| Value.fromInterned(opt.val).maybeElemValue(mod, index),
            .aggregate => |aggregate| {
                const len = mod.intern_pool.aggregateTypeLen(aggregate.ty);
                if (index < len) return Value.fromInterned(switch (aggregate.storage) {
                    .bytes => |bytes| try mod.intern(.{ .int = .{
                        .ty = .u8_type,
                        .storage = .{ .u64 = bytes[index] },
                    } }),
                    .elems => |elems| elems[index],
                    .repeated_elem => |elem| elem,
                });
                assert(index == len);
                return Value.fromInterned(mod.intern_pool.indexToKey(aggregate.ty).array_type.sentinel);
            },
            else => null,
        },
    };
}

pub fn isLazyAlign(val: Value, mod: *Module) bool {
    return switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .int => |int| int.storage == .lazy_align,
        else => false,
    };
}

pub fn isLazySize(val: Value, mod: *Module) bool {
    return switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .int => |int| int.storage == .lazy_size,
        else => false,
    };
}

pub fn isPtrToThreadLocal(val: Value, mod: *Module) bool {
    const backing_decl = mod.intern_pool.getBackingDecl(val.toIntern()).unwrap() orelse return false;
    const variable = mod.declPtr(backing_decl).getOwnedVariable(mod) orelse return false;
    return variable.is_threadlocal;
}

// Asserts that the provided start/end are in-bounds.
pub fn sliceArray(
    val: Value,
    mod: *Module,
    arena: Allocator,
    start: usize,
    end: usize,
) error{OutOfMemory}!Value {
    // TODO: write something like getCoercedInts to avoid needing to dupe
    return switch (val.ip_index) {
        .none => switch (val.tag()) {
            .slice => val.castTag(.slice).?.data.ptr.sliceArray(mod, arena, start, end),
            .bytes => Tag.bytes.create(arena, val.castTag(.bytes).?.data[start..end]),
            .repeated => val,
            .aggregate => Tag.aggregate.create(arena, val.castTag(.aggregate).?.data[start..end]),
            else => unreachable,
        },
        else => switch (mod.intern_pool.indexToKey(val.toIntern())) {
            .ptr => |ptr| switch (ptr.addr) {
                .decl => |decl| try mod.declPtr(decl).val.sliceArray(mod, arena, start, end),
                .mut_decl => |mut_decl| Value.fromInterned((try mod.declPtr(mut_decl.decl).internValue(mod)))
                    .sliceArray(mod, arena, start, end),
                .comptime_field => |comptime_field| Value.fromInterned(comptime_field)
                    .sliceArray(mod, arena, start, end),
                .elem => |elem| Value.fromInterned(elem.base)
                    .sliceArray(mod, arena, start + @as(usize, @intCast(elem.index)), end + @as(usize, @intCast(elem.index))),
                else => unreachable,
            },
            .aggregate => |aggregate| Value.fromInterned((try mod.intern(.{ .aggregate = .{
                .ty = switch (mod.intern_pool.indexToKey(mod.intern_pool.typeOf(val.toIntern()))) {
                    .array_type => |array_type| try mod.arrayType(.{
                        .len = @as(u32, @intCast(end - start)),
                        .child = array_type.child,
                        .sentinel = if (end == array_type.len) array_type.sentinel else .none,
                    }),
                    .vector_type => |vector_type| try mod.vectorType(.{
                        .len = @as(u32, @intCast(end - start)),
                        .child = vector_type.child,
                    }),
                    else => unreachable,
                }.toIntern(),
                .storage = switch (aggregate.storage) {
                    .bytes => .{ .bytes = try arena.dupe(u8, mod.intern_pool.indexToKey(val.toIntern()).aggregate.storage.bytes[start..end]) },
                    .elems => .{ .elems = try arena.dupe(InternPool.Index, mod.intern_pool.indexToKey(val.toIntern()).aggregate.storage.elems[start..end]) },
                    .repeated_elem => |elem| .{ .repeated_elem = elem },
                },
            } }))),
            else => unreachable,
        },
    };
}

pub fn fieldValue(val: Value, mod: *Module, index: usize) !Value {
    return switch (val.ip_index) {
        .none => switch (val.tag()) {
            .aggregate => {
                const field_values = val.castTag(.aggregate).?.data;
                return field_values[index];
            },
            .@"union" => {
                const payload = val.castTag(.@"union").?.data;
                // TODO assert the tag is correct
                return payload.val;
            },
            else => unreachable,
        },
        else => switch (mod.intern_pool.indexToKey(val.toIntern())) {
            .undef => |ty| Value.fromInterned((try mod.intern(.{
                .undef = Type.fromInterned(ty).structFieldType(index, mod).toIntern(),
            }))),
            .aggregate => |aggregate| Value.fromInterned(switch (aggregate.storage) {
                .bytes => |bytes| try mod.intern(.{ .int = .{
                    .ty = .u8_type,
                    .storage = .{ .u64 = bytes[index] },
                } }),
                .elems => |elems| elems[index],
                .repeated_elem => |elem| elem,
            }),
            // TODO assert the tag is correct
            .un => |un| Value.fromInterned(un.val),
            else => unreachable,
        },
    };
}

pub fn unionTag(val: Value, mod: *Module) ?Value {
    if (val.ip_index == .none) return val.castTag(.@"union").?.data.tag;
    return switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .undef, .enum_tag => val,
        .un => |un| if (un.tag != .none) Value.fromInterned(un.tag) else return null,
        else => unreachable,
    };
}

pub fn unionValue(val: Value, mod: *Module) Value {
    if (val.ip_index == .none) return val.castTag(.@"union").?.data.val;
    return switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .un => |un| Value.fromInterned(un.val),
        else => unreachable,
    };
}

/// Returns a pointer to the element value at the index.
pub fn elemPtr(
    val: Value,
    elem_ptr_ty: Type,
    index: usize,
    mod: *Module,
) Allocator.Error!Value {
    const elem_ty = elem_ptr_ty.childType(mod);
    const ptr_val = switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .slice => |slice| Value.fromInterned(slice.ptr),
        else => val,
    };
    switch (mod.intern_pool.indexToKey(ptr_val.toIntern())) {
        .ptr => |ptr| switch (ptr.addr) {
            .elem => |elem| if (Type.fromInterned(mod.intern_pool.typeOf(elem.base)).elemType2(mod).eql(elem_ty, mod))
                return Value.fromInterned((try mod.intern(.{ .ptr = .{
                    .ty = elem_ptr_ty.toIntern(),
                    .addr = .{ .elem = .{
                        .base = elem.base,
                        .index = elem.index + index,
                    } },
                } }))),
            else => {},
        },
        else => {},
    }
    var ptr_ty_key = mod.intern_pool.indexToKey(elem_ptr_ty.toIntern()).ptr_type;
    assert(ptr_ty_key.flags.size != .Slice);
    ptr_ty_key.flags.size = .Many;
    return Value.fromInterned((try mod.intern(.{ .ptr = .{
        .ty = elem_ptr_ty.toIntern(),
        .addr = .{ .elem = .{
            .base = (try mod.getCoerced(ptr_val, try mod.ptrType(ptr_ty_key))).toIntern(),
            .index = index,
        } },
    } })));
}

pub fn isUndef(val: Value, mod: *Module) bool {
    return val.ip_index != .none and mod.intern_pool.isUndef(val.toIntern());
}

/// TODO: check for cases such as array that is not marked undef but all the element
/// values are marked undef, or struct that is not marked undef but all fields are marked
/// undef, etc.
pub fn isUndefDeep(val: Value, mod: *Module) bool {
    return val.isUndef(mod);
}

/// Returns true if any value contained in `self` is undefined.
pub fn anyUndef(val: Value, mod: *Module) !bool {
    if (val.ip_index == .none) return false;
    return switch (val.toIntern()) {
        .undef => true,
        else => switch (mod.intern_pool.indexToKey(val.toIntern())) {
            .undef => true,
            .simple_value => |v| v == .undefined,
            .slice => |slice| for (0..@intCast(Value.fromInterned(slice.len).toUnsignedInt(mod))) |idx| {
                if (try (try val.elemValue(mod, idx)).anyUndef(mod)) break true;
            } else false,
            .aggregate => |aggregate| for (0..aggregate.storage.values().len) |i| {
                const elem = mod.intern_pool.indexToKey(val.toIntern()).aggregate.storage.values()[i];
                if (try anyUndef(Value.fromInterned(elem), mod)) break true;
            } else false,
            else => false,
        },
    };
}

/// Asserts the value is not undefined and not unreachable.
/// C pointers with an integer value of 0 are also considered null.
pub fn isNull(val: Value, mod: *Module) bool {
    return switch (val.toIntern()) {
        .undef => unreachable,
        .unreachable_value => unreachable,
        .null_value => true,
        else => return switch (mod.intern_pool.indexToKey(val.toIntern())) {
            .undef => unreachable,
            .ptr => |ptr| switch (ptr.addr) {
                .int => {
                    var buf: BigIntSpace = undefined;
                    return val.toBigInt(&buf, mod).eqlZero();
                },
                else => false,
            },
            .opt => |opt| opt.val == .none,
            else => false,
        },
    };
}

/// Valid only for error (union) types. Asserts the value is not undefined and not unreachable.
pub fn getErrorName(val: Value, mod: *const Module) InternPool.OptionalNullTerminatedString {
    return switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .err => |err| err.name.toOptional(),
        .error_union => |error_union| switch (error_union.val) {
            .err_name => |err_name| err_name.toOptional(),
            .payload => .none,
        },
        else => unreachable,
    };
}

pub fn getErrorInt(val: Value, mod: *const Module) Module.ErrorInt {
    return if (getErrorName(val, mod).unwrap()) |err_name|
        @as(Module.ErrorInt, @intCast(mod.global_error_set.getIndex(err_name).?))
    else
        0;
}

/// Assumes the type is an error union. Returns true if and only if the value is
/// the error union payload, not an error.
pub fn errorUnionIsPayload(val: Value, mod: *const Module) bool {
    return mod.intern_pool.indexToKey(val.toIntern()).error_union.val == .payload;
}

/// Value of the optional, null if optional has no payload.
pub fn optionalValue(val: Value, mod: *const Module) ?Value {
    return switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .opt => |opt| switch (opt.val) {
            .none => null,
            else => |payload| Value.fromInterned(payload),
        },
        .ptr => val,
        else => unreachable,
    };
}

/// Valid for all types. Asserts the value is not undefined.
pub fn isFloat(self: Value, mod: *const Module) bool {
    return switch (self.toIntern()) {
        .undef => unreachable,
        else => switch (mod.intern_pool.indexToKey(self.toIntern())) {
            .undef => unreachable,
            .float => true,
            else => false,
        },
    };
}

pub fn floatFromInt(val: Value, arena: Allocator, int_ty: Type, float_ty: Type, mod: *Module) !Value {
    return floatFromIntAdvanced(val, arena, int_ty, float_ty, mod, null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => unreachable,
    };
}

pub fn floatFromIntAdvanced(val: Value, arena: Allocator, int_ty: Type, float_ty: Type, mod: *Module, opt_sema: ?*Sema) !Value {
    if (int_ty.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, int_ty.vectorLen(mod));
        const scalar_ty = float_ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            scalar.* = try (try floatFromIntScalar(elem_val, scalar_ty, mod, opt_sema)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return floatFromIntScalar(val, float_ty, mod, opt_sema);
}

pub fn floatFromIntScalar(val: Value, float_ty: Type, mod: *Module, opt_sema: ?*Sema) !Value {
    return switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .undef => try mod.undefValue(float_ty),
        .int => |int| switch (int.storage) {
            .big_int => |big_int| {
                const float = bigIntToFloat(big_int.limbs, big_int.positive);
                return mod.floatValue(float_ty, float);
            },
            inline .u64, .i64 => |x| floatFromIntInner(x, float_ty, mod),
            .lazy_align => |ty| if (opt_sema) |sema| {
                return floatFromIntInner((try Type.fromInterned(ty).abiAlignmentAdvanced(mod, .{ .sema = sema })).scalar.toByteUnits(0), float_ty, mod);
            } else {
                return floatFromIntInner(Type.fromInterned(ty).abiAlignment(mod).toByteUnits(0), float_ty, mod);
            },
            .lazy_size => |ty| if (opt_sema) |sema| {
                return floatFromIntInner((try Type.fromInterned(ty).abiSizeAdvanced(mod, .{ .sema = sema })).scalar, float_ty, mod);
            } else {
                return floatFromIntInner(Type.fromInterned(ty).abiSize(mod), float_ty, mod);
            },
        },
        else => unreachable,
    };
}

fn floatFromIntInner(x: anytype, dest_ty: Type, mod: *Module) !Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (dest_ty.floatBits(target)) {
        16 => .{ .f16 = @floatFromInt(x) },
        32 => .{ .f32 = @floatFromInt(x) },
        64 => .{ .f64 = @floatFromInt(x) },
        80 => .{ .f80 = @floatFromInt(x) },
        128 => .{ .f128 = @floatFromInt(x) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = dest_ty.toIntern(),
        .storage = storage,
    } })));
}

fn calcLimbLenFloat(scalar: anytype) usize {
    if (scalar == 0) {
        return 1;
    }

    const w_value = @abs(scalar);
    return @divFloor(@as(std.math.big.Limb, @intFromFloat(std.math.log2(w_value))), @typeInfo(std.math.big.Limb).Int.bits) + 1;
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
    mod: *Module,
) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try intAddSatScalar(lhs_elem, rhs_elem, scalar_ty, arena, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return intAddSatScalar(lhs, rhs, ty, arena, mod);
}

/// Supports integers only; asserts neither operand is undefined.
pub fn intAddSatScalar(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    mod: *Module,
) !Value {
    assert(!lhs.isUndef(mod));
    assert(!rhs.isUndef(mod));

    const info = ty.intInfo(mod);

    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
    const rhs_bigint = rhs.toBigInt(&rhs_space, mod);
    const limbs = try arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.addSat(lhs_bigint, rhs_bigint, info.signedness, info.bits);
    return mod.intValue_big(ty, result_bigint.toConst());
}

/// Supports (vectors of) integers only; asserts neither operand is undefined.
pub fn intSubSat(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    mod: *Module,
) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try intSubSatScalar(lhs_elem, rhs_elem, scalar_ty, arena, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return intSubSatScalar(lhs, rhs, ty, arena, mod);
}

/// Supports integers only; asserts neither operand is undefined.
pub fn intSubSatScalar(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    mod: *Module,
) !Value {
    assert(!lhs.isUndef(mod));
    assert(!rhs.isUndef(mod));

    const info = ty.intInfo(mod);

    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
    const rhs_bigint = rhs.toBigInt(&rhs_space, mod);
    const limbs = try arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.subSat(lhs_bigint, rhs_bigint, info.signedness, info.bits);
    return mod.intValue_big(ty, result_bigint.toConst());
}

pub fn intMulWithOverflow(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    mod: *Module,
) !OverflowArithmeticResult {
    if (ty.zigTypeTag(mod) == .Vector) {
        const vec_len = ty.vectorLen(mod);
        const overflowed_data = try arena.alloc(InternPool.Index, vec_len);
        const result_data = try arena.alloc(InternPool.Index, vec_len);
        const scalar_ty = ty.scalarType(mod);
        for (overflowed_data, result_data, 0..) |*of, *scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            const of_math_result = try intMulWithOverflowScalar(lhs_elem, rhs_elem, scalar_ty, arena, mod);
            of.* = try of_math_result.overflow_bit.intern(Type.u1, mod);
            scalar.* = try of_math_result.wrapped_result.intern(scalar_ty, mod);
        }
        return OverflowArithmeticResult{
            .overflow_bit = Value.fromInterned((try mod.intern(.{ .aggregate = .{
                .ty = (try mod.vectorType(.{ .len = vec_len, .child = .u1_type })).toIntern(),
                .storage = .{ .elems = overflowed_data },
            } }))),
            .wrapped_result = Value.fromInterned((try mod.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } }))),
        };
    }
    return intMulWithOverflowScalar(lhs, rhs, ty, arena, mod);
}

pub fn intMulWithOverflowScalar(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    mod: *Module,
) !OverflowArithmeticResult {
    const info = ty.intInfo(mod);

    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
    const rhs_bigint = rhs.toBigInt(&rhs_space, mod);
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
        .overflow_bit = try mod.intValue(Type.u1, @intFromBool(overflowed)),
        .wrapped_result = try mod.intValue_big(ty, result_bigint.toConst()),
    };
}

/// Supports both (vectors of) floats and ints; handles undefined scalars.
pub fn numberMulWrap(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    mod: *Module,
) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try numberMulWrapScalar(lhs_elem, rhs_elem, scalar_ty, arena, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return numberMulWrapScalar(lhs, rhs, ty, arena, mod);
}

/// Supports both floats and ints; handles undefined.
pub fn numberMulWrapScalar(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    mod: *Module,
) !Value {
    if (lhs.isUndef(mod) or rhs.isUndef(mod)) return Value.undef;

    if (ty.zigTypeTag(mod) == .ComptimeInt) {
        return intMul(lhs, rhs, ty, undefined, arena, mod);
    }

    if (ty.isAnyFloat()) {
        return floatMul(lhs, rhs, ty, arena, mod);
    }

    const overflow_result = try intMulWithOverflow(lhs, rhs, ty, arena, mod);
    return overflow_result.wrapped_result;
}

/// Supports (vectors of) integers only; asserts neither operand is undefined.
pub fn intMulSat(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    mod: *Module,
) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try intMulSatScalar(lhs_elem, rhs_elem, scalar_ty, arena, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return intMulSatScalar(lhs, rhs, ty, arena, mod);
}

/// Supports (vectors of) integers only; asserts neither operand is undefined.
pub fn intMulSatScalar(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    mod: *Module,
) !Value {
    assert(!lhs.isUndef(mod));
    assert(!rhs.isUndef(mod));

    const info = ty.intInfo(mod);

    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
    const rhs_bigint = rhs.toBigInt(&rhs_space, mod);
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
    return mod.intValue_big(ty, result_bigint.toConst());
}

/// Supports both floats and ints; handles undefined.
pub fn numberMax(lhs: Value, rhs: Value, mod: *Module) Value {
    if (lhs.isUndef(mod) or rhs.isUndef(mod)) return undef;
    if (lhs.isNan(mod)) return rhs;
    if (rhs.isNan(mod)) return lhs;

    return switch (order(lhs, rhs, mod)) {
        .lt => rhs,
        .gt, .eq => lhs,
    };
}

/// Supports both floats and ints; handles undefined.
pub fn numberMin(lhs: Value, rhs: Value, mod: *Module) Value {
    if (lhs.isUndef(mod) or rhs.isUndef(mod)) return undef;
    if (lhs.isNan(mod)) return rhs;
    if (rhs.isNan(mod)) return lhs;

    return switch (order(lhs, rhs, mod)) {
        .lt => lhs,
        .gt, .eq => rhs,
    };
}

/// operands must be (vectors of) integers; handles undefined scalars.
pub fn bitwiseNot(val: Value, ty: Type, arena: Allocator, mod: *Module) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            scalar.* = try (try bitwiseNotScalar(elem_val, scalar_ty, arena, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return bitwiseNotScalar(val, ty, arena, mod);
}

/// operands must be integers; handles undefined.
pub fn bitwiseNotScalar(val: Value, ty: Type, arena: Allocator, mod: *Module) !Value {
    if (val.isUndef(mod)) return Value.fromInterned((try mod.intern(.{ .undef = ty.toIntern() })));
    if (ty.toIntern() == .bool_type) return makeBool(!val.toBool());

    const info = ty.intInfo(mod);

    if (info.bits == 0) {
        return val;
    }

    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var val_space: Value.BigIntSpace = undefined;
    const val_bigint = val.toBigInt(&val_space, mod);
    const limbs = try arena.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(info.bits),
    );

    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.bitNotWrap(val_bigint, info.signedness, info.bits);
    return mod.intValue_big(ty, result_bigint.toConst());
}

/// operands must be (vectors of) integers; handles undefined scalars.
pub fn bitwiseAnd(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try bitwiseAndScalar(lhs_elem, rhs_elem, scalar_ty, allocator, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return bitwiseAndScalar(lhs, rhs, ty, allocator, mod);
}

/// operands must be integers; handles undefined.
pub fn bitwiseAndScalar(lhs: Value, rhs: Value, ty: Type, arena: Allocator, mod: *Module) !Value {
    if (lhs.isUndef(mod) or rhs.isUndef(mod)) return Value.fromInterned((try mod.intern(.{ .undef = ty.toIntern() })));
    if (ty.toIntern() == .bool_type) return makeBool(lhs.toBool() and rhs.toBool());

    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
    const rhs_bigint = rhs.toBigInt(&rhs_space, mod);
    const limbs = try arena.alloc(
        std.math.big.Limb,
        // + 1 for negatives
        @max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.bitAnd(lhs_bigint, rhs_bigint);
    return mod.intValue_big(ty, result_bigint.toConst());
}

/// operands must be (vectors of) integers; handles undefined scalars.
pub fn bitwiseNand(lhs: Value, rhs: Value, ty: Type, arena: Allocator, mod: *Module) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try bitwiseNandScalar(lhs_elem, rhs_elem, scalar_ty, arena, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return bitwiseNandScalar(lhs, rhs, ty, arena, mod);
}

/// operands must be integers; handles undefined.
pub fn bitwiseNandScalar(lhs: Value, rhs: Value, ty: Type, arena: Allocator, mod: *Module) !Value {
    if (lhs.isUndef(mod) or rhs.isUndef(mod)) return Value.fromInterned((try mod.intern(.{ .undef = ty.toIntern() })));
    if (ty.toIntern() == .bool_type) return makeBool(!(lhs.toBool() and rhs.toBool()));

    const anded = try bitwiseAnd(lhs, rhs, ty, arena, mod);
    const all_ones = if (ty.isSignedInt(mod)) try mod.intValue(ty, -1) else try ty.maxIntScalar(mod, ty);
    return bitwiseXor(anded, all_ones, ty, arena, mod);
}

/// operands must be (vectors of) integers; handles undefined scalars.
pub fn bitwiseOr(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try bitwiseOrScalar(lhs_elem, rhs_elem, scalar_ty, allocator, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return bitwiseOrScalar(lhs, rhs, ty, allocator, mod);
}

/// operands must be integers; handles undefined.
pub fn bitwiseOrScalar(lhs: Value, rhs: Value, ty: Type, arena: Allocator, mod: *Module) !Value {
    if (lhs.isUndef(mod) or rhs.isUndef(mod)) return Value.fromInterned((try mod.intern(.{ .undef = ty.toIntern() })));
    if (ty.toIntern() == .bool_type) return makeBool(lhs.toBool() or rhs.toBool());

    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
    const rhs_bigint = rhs.toBigInt(&rhs_space, mod);
    const limbs = try arena.alloc(
        std.math.big.Limb,
        @max(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.bitOr(lhs_bigint, rhs_bigint);
    return mod.intValue_big(ty, result_bigint.toConst());
}

/// operands must be (vectors of) integers; handles undefined scalars.
pub fn bitwiseXor(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try bitwiseXorScalar(lhs_elem, rhs_elem, scalar_ty, allocator, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return bitwiseXorScalar(lhs, rhs, ty, allocator, mod);
}

/// operands must be integers; handles undefined.
pub fn bitwiseXorScalar(lhs: Value, rhs: Value, ty: Type, arena: Allocator, mod: *Module) !Value {
    if (lhs.isUndef(mod) or rhs.isUndef(mod)) return Value.fromInterned((try mod.intern(.{ .undef = ty.toIntern() })));
    if (ty.toIntern() == .bool_type) return makeBool(lhs.toBool() != rhs.toBool());

    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
    const rhs_bigint = rhs.toBigInt(&rhs_space, mod);
    const limbs = try arena.alloc(
        std.math.big.Limb,
        // + 1 for negatives
        @max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.bitXor(lhs_bigint, rhs_bigint);
    return mod.intValue_big(ty, result_bigint.toConst());
}

/// If the value overflowed the type, returns a comptime_int (or vector thereof) instead, setting
/// overflow_idx to the vector index the overflow was at (or 0 for a scalar).
pub fn intDiv(lhs: Value, rhs: Value, ty: Type, overflow_idx: *?usize, allocator: Allocator, mod: *Module) !Value {
    var overflow: usize = undefined;
    return intDivInner(lhs, rhs, ty, &overflow, allocator, mod) catch |err| switch (err) {
        error.Overflow => {
            const is_vec = ty.isVector(mod);
            overflow_idx.* = if (is_vec) overflow else 0;
            const safe_ty = if (is_vec) try mod.vectorType(.{
                .len = ty.vectorLen(mod),
                .child = .comptime_int_type,
            }) else Type.comptime_int;
            return intDivInner(lhs, rhs, safe_ty, undefined, allocator, mod) catch |err1| switch (err1) {
                error.Overflow => unreachable,
                else => |e| return e,
            };
        },
        else => |e| return e,
    };
}

fn intDivInner(lhs: Value, rhs: Value, ty: Type, overflow_idx: *usize, allocator: Allocator, mod: *Module) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            const val = intDivScalar(lhs_elem, rhs_elem, scalar_ty, allocator, mod) catch |err| switch (err) {
                error.Overflow => {
                    overflow_idx.* = i;
                    return error.Overflow;
                },
                else => |e| return e,
            };
            scalar.* = try val.intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return intDivScalar(lhs, rhs, ty, allocator, mod);
}

pub fn intDivScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
    const rhs_bigint = rhs.toBigInt(&rhs_space, mod);
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
        const info = ty.intInfo(mod);
        if (!result_q.toConst().fitsInTwosComp(info.signedness, info.bits)) {
            return error.Overflow;
        }
    }
    return mod.intValue_big(ty, result_q.toConst());
}

pub fn intDivFloor(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try intDivFloorScalar(lhs_elem, rhs_elem, scalar_ty, allocator, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return intDivFloorScalar(lhs, rhs, ty, allocator, mod);
}

pub fn intDivFloorScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
    const rhs_bigint = rhs.toBigInt(&rhs_space, mod);
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
    return mod.intValue_big(ty, result_q.toConst());
}

pub fn intMod(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try intModScalar(lhs_elem, rhs_elem, scalar_ty, allocator, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return intModScalar(lhs, rhs, ty, allocator, mod);
}

pub fn intModScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
    const rhs_bigint = rhs.toBigInt(&rhs_space, mod);
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
    return mod.intValue_big(ty, result_r.toConst());
}

/// Returns true if the value is a floating point type and is NaN. Returns false otherwise.
pub fn isNan(val: Value, mod: *const Module) bool {
    if (val.ip_index == .none) return false;
    return switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .float => |float| switch (float.storage) {
            inline else => |x| std.math.isNan(x),
        },
        else => false,
    };
}

/// Returns true if the value is a floating point type and is infinite. Returns false otherwise.
pub fn isInf(val: Value, mod: *const Module) bool {
    if (val.ip_index == .none) return false;
    return switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .float => |float| switch (float.storage) {
            inline else => |x| std.math.isInf(x),
        },
        else => false,
    };
}

pub fn isNegativeInf(val: Value, mod: *const Module) bool {
    if (val.ip_index == .none) return false;
    return switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .float => |float| switch (float.storage) {
            inline else => |x| std.math.isNegativeInf(x),
        },
        else => false,
    };
}

pub fn floatRem(lhs: Value, rhs: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try floatRemScalar(lhs_elem, rhs_elem, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return floatRemScalar(lhs, rhs, float_type, mod);
}

pub fn floatRemScalar(lhs: Value, rhs: Value, float_type: Type, mod: *Module) !Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @rem(lhs.toFloat(f16, mod), rhs.toFloat(f16, mod)) },
        32 => .{ .f32 = @rem(lhs.toFloat(f32, mod), rhs.toFloat(f32, mod)) },
        64 => .{ .f64 = @rem(lhs.toFloat(f64, mod), rhs.toFloat(f64, mod)) },
        80 => .{ .f80 = @rem(lhs.toFloat(f80, mod), rhs.toFloat(f80, mod)) },
        128 => .{ .f128 = @rem(lhs.toFloat(f128, mod), rhs.toFloat(f128, mod)) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn floatMod(lhs: Value, rhs: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try floatModScalar(lhs_elem, rhs_elem, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return floatModScalar(lhs, rhs, float_type, mod);
}

pub fn floatModScalar(lhs: Value, rhs: Value, float_type: Type, mod: *Module) !Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @mod(lhs.toFloat(f16, mod), rhs.toFloat(f16, mod)) },
        32 => .{ .f32 = @mod(lhs.toFloat(f32, mod), rhs.toFloat(f32, mod)) },
        64 => .{ .f64 = @mod(lhs.toFloat(f64, mod), rhs.toFloat(f64, mod)) },
        80 => .{ .f80 = @mod(lhs.toFloat(f80, mod), rhs.toFloat(f80, mod)) },
        128 => .{ .f128 = @mod(lhs.toFloat(f128, mod), rhs.toFloat(f128, mod)) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

/// If the value overflowed the type, returns a comptime_int (or vector thereof) instead, setting
/// overflow_idx to the vector index the overflow was at (or 0 for a scalar).
pub fn intMul(lhs: Value, rhs: Value, ty: Type, overflow_idx: *?usize, allocator: Allocator, mod: *Module) !Value {
    var overflow: usize = undefined;
    return intMulInner(lhs, rhs, ty, &overflow, allocator, mod) catch |err| switch (err) {
        error.Overflow => {
            const is_vec = ty.isVector(mod);
            overflow_idx.* = if (is_vec) overflow else 0;
            const safe_ty = if (is_vec) try mod.vectorType(.{
                .len = ty.vectorLen(mod),
                .child = .comptime_int_type,
            }) else Type.comptime_int;
            return intMulInner(lhs, rhs, safe_ty, undefined, allocator, mod) catch |err1| switch (err1) {
                error.Overflow => unreachable,
                else => |e| return e,
            };
        },
        else => |e| return e,
    };
}

fn intMulInner(lhs: Value, rhs: Value, ty: Type, overflow_idx: *usize, allocator: Allocator, mod: *Module) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            const val = intMulScalar(lhs_elem, rhs_elem, scalar_ty, allocator, mod) catch |err| switch (err) {
                error.Overflow => {
                    overflow_idx.* = i;
                    return error.Overflow;
                },
                else => |e| return e,
            };
            scalar.* = try val.intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return intMulScalar(lhs, rhs, ty, allocator, mod);
}

pub fn intMulScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
    if (ty.toIntern() != .comptime_int_type) {
        const res = try intMulWithOverflowScalar(lhs, rhs, ty, allocator, mod);
        if (res.overflow_bit.compareAllWithZero(.neq, mod)) return error.Overflow;
        return res.wrapped_result;
    }
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
    const rhs_bigint = rhs.toBigInt(&rhs_space, mod);
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
    return mod.intValue_big(ty, result_bigint.toConst());
}

pub fn intTrunc(val: Value, ty: Type, allocator: Allocator, signedness: std.builtin.Signedness, bits: u16, mod: *Module) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            scalar.* = try (try intTruncScalar(elem_val, scalar_ty, allocator, signedness, bits, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return intTruncScalar(val, ty, allocator, signedness, bits, mod);
}

/// This variant may vectorize on `bits`. Asserts that `bits` is a (vector of) `u16`.
pub fn intTruncBitsAsValue(
    val: Value,
    ty: Type,
    allocator: Allocator,
    signedness: std.builtin.Signedness,
    bits: Value,
    mod: *Module,
) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            const bits_elem = try bits.elemValue(mod, i);
            scalar.* = try (try intTruncScalar(elem_val, scalar_ty, allocator, signedness, @as(u16, @intCast(bits_elem.toUnsignedInt(mod))), mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return intTruncScalar(val, ty, allocator, signedness, @as(u16, @intCast(bits.toUnsignedInt(mod))), mod);
}

pub fn intTruncScalar(
    val: Value,
    ty: Type,
    allocator: Allocator,
    signedness: std.builtin.Signedness,
    bits: u16,
    mod: *Module,
) !Value {
    if (bits == 0) return mod.intValue(ty, 0);

    var val_space: Value.BigIntSpace = undefined;
    const val_bigint = val.toBigInt(&val_space, mod);

    const limbs = try allocator.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(bits),
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };

    result_bigint.truncate(val_bigint, signedness, bits);
    return mod.intValue_big(ty, result_bigint.toConst());
}

pub fn shl(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try shlScalar(lhs_elem, rhs_elem, scalar_ty, allocator, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return shlScalar(lhs, rhs, ty, allocator, mod);
}

pub fn shlScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
    const shift = @as(usize, @intCast(rhs.toUnsignedInt(mod)));
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
        const int_info = ty.intInfo(mod);
        result_bigint.truncate(result_bigint.toConst(), int_info.signedness, int_info.bits);
    }

    return mod.intValue_big(ty, result_bigint.toConst());
}

pub fn shlWithOverflow(
    lhs: Value,
    rhs: Value,
    ty: Type,
    allocator: Allocator,
    mod: *Module,
) !OverflowArithmeticResult {
    if (ty.zigTypeTag(mod) == .Vector) {
        const vec_len = ty.vectorLen(mod);
        const overflowed_data = try allocator.alloc(InternPool.Index, vec_len);
        const result_data = try allocator.alloc(InternPool.Index, vec_len);
        const scalar_ty = ty.scalarType(mod);
        for (overflowed_data, result_data, 0..) |*of, *scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            const of_math_result = try shlWithOverflowScalar(lhs_elem, rhs_elem, scalar_ty, allocator, mod);
            of.* = try of_math_result.overflow_bit.intern(Type.u1, mod);
            scalar.* = try of_math_result.wrapped_result.intern(scalar_ty, mod);
        }
        return OverflowArithmeticResult{
            .overflow_bit = Value.fromInterned((try mod.intern(.{ .aggregate = .{
                .ty = (try mod.vectorType(.{ .len = vec_len, .child = .u1_type })).toIntern(),
                .storage = .{ .elems = overflowed_data },
            } }))),
            .wrapped_result = Value.fromInterned((try mod.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } }))),
        };
    }
    return shlWithOverflowScalar(lhs, rhs, ty, allocator, mod);
}

pub fn shlWithOverflowScalar(
    lhs: Value,
    rhs: Value,
    ty: Type,
    allocator: Allocator,
    mod: *Module,
) !OverflowArithmeticResult {
    const info = ty.intInfo(mod);
    var lhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
    const shift = @as(usize, @intCast(rhs.toUnsignedInt(mod)));
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
        .overflow_bit = try mod.intValue(Type.u1, @intFromBool(overflowed)),
        .wrapped_result = try mod.intValue_big(ty, result_bigint.toConst()),
    };
}

pub fn shlSat(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    mod: *Module,
) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try shlSatScalar(lhs_elem, rhs_elem, scalar_ty, arena, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return shlSatScalar(lhs, rhs, ty, arena, mod);
}

pub fn shlSatScalar(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    mod: *Module,
) !Value {
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    const info = ty.intInfo(mod);

    var lhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
    const shift = @as(usize, @intCast(rhs.toUnsignedInt(mod)));
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
    return mod.intValue_big(ty, result_bigint.toConst());
}

pub fn shlTrunc(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    mod: *Module,
) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try shlTruncScalar(lhs_elem, rhs_elem, scalar_ty, arena, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return shlTruncScalar(lhs, rhs, ty, arena, mod);
}

pub fn shlTruncScalar(
    lhs: Value,
    rhs: Value,
    ty: Type,
    arena: Allocator,
    mod: *Module,
) !Value {
    const shifted = try lhs.shl(rhs, ty, arena, mod);
    const int_info = ty.intInfo(mod);
    const truncated = try shifted.intTrunc(ty, arena, int_info.signedness, int_info.bits, mod);
    return truncated;
}

pub fn shr(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try shrScalar(lhs_elem, rhs_elem, scalar_ty, allocator, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return shrScalar(lhs, rhs, ty, allocator, mod);
}

pub fn shrScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
    const shift = @as(usize, @intCast(rhs.toUnsignedInt(mod)));

    const result_limbs = lhs_bigint.limbs.len -| (shift / (@sizeOf(std.math.big.Limb) * 8));
    if (result_limbs == 0) {
        // The shift is enough to remove all the bits from the number, which means the
        // result is 0 or -1 depending on the sign.
        if (lhs_bigint.positive) {
            return mod.intValue(ty, 0);
        } else {
            return mod.intValue(ty, -1);
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
    return mod.intValue_big(ty, result_bigint.toConst());
}

pub fn floatNeg(
    val: Value,
    float_type: Type,
    arena: Allocator,
    mod: *Module,
) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            scalar.* = try (try floatNegScalar(elem_val, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return floatNegScalar(val, float_type, mod);
}

pub fn floatNegScalar(
    val: Value,
    float_type: Type,
    mod: *Module,
) !Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = -val.toFloat(f16, mod) },
        32 => .{ .f32 = -val.toFloat(f32, mod) },
        64 => .{ .f64 = -val.toFloat(f64, mod) },
        80 => .{ .f80 = -val.toFloat(f80, mod) },
        128 => .{ .f128 = -val.toFloat(f128, mod) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn floatAdd(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    arena: Allocator,
    mod: *Module,
) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try floatAddScalar(lhs_elem, rhs_elem, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return floatAddScalar(lhs, rhs, float_type, mod);
}

pub fn floatAddScalar(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    mod: *Module,
) !Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = lhs.toFloat(f16, mod) + rhs.toFloat(f16, mod) },
        32 => .{ .f32 = lhs.toFloat(f32, mod) + rhs.toFloat(f32, mod) },
        64 => .{ .f64 = lhs.toFloat(f64, mod) + rhs.toFloat(f64, mod) },
        80 => .{ .f80 = lhs.toFloat(f80, mod) + rhs.toFloat(f80, mod) },
        128 => .{ .f128 = lhs.toFloat(f128, mod) + rhs.toFloat(f128, mod) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn floatSub(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    arena: Allocator,
    mod: *Module,
) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try floatSubScalar(lhs_elem, rhs_elem, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return floatSubScalar(lhs, rhs, float_type, mod);
}

pub fn floatSubScalar(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    mod: *Module,
) !Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = lhs.toFloat(f16, mod) - rhs.toFloat(f16, mod) },
        32 => .{ .f32 = lhs.toFloat(f32, mod) - rhs.toFloat(f32, mod) },
        64 => .{ .f64 = lhs.toFloat(f64, mod) - rhs.toFloat(f64, mod) },
        80 => .{ .f80 = lhs.toFloat(f80, mod) - rhs.toFloat(f80, mod) },
        128 => .{ .f128 = lhs.toFloat(f128, mod) - rhs.toFloat(f128, mod) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn floatDiv(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    arena: Allocator,
    mod: *Module,
) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try floatDivScalar(lhs_elem, rhs_elem, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return floatDivScalar(lhs, rhs, float_type, mod);
}

pub fn floatDivScalar(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    mod: *Module,
) !Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = lhs.toFloat(f16, mod) / rhs.toFloat(f16, mod) },
        32 => .{ .f32 = lhs.toFloat(f32, mod) / rhs.toFloat(f32, mod) },
        64 => .{ .f64 = lhs.toFloat(f64, mod) / rhs.toFloat(f64, mod) },
        80 => .{ .f80 = lhs.toFloat(f80, mod) / rhs.toFloat(f80, mod) },
        128 => .{ .f128 = lhs.toFloat(f128, mod) / rhs.toFloat(f128, mod) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn floatDivFloor(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    arena: Allocator,
    mod: *Module,
) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try floatDivFloorScalar(lhs_elem, rhs_elem, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return floatDivFloorScalar(lhs, rhs, float_type, mod);
}

pub fn floatDivFloorScalar(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    mod: *Module,
) !Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @divFloor(lhs.toFloat(f16, mod), rhs.toFloat(f16, mod)) },
        32 => .{ .f32 = @divFloor(lhs.toFloat(f32, mod), rhs.toFloat(f32, mod)) },
        64 => .{ .f64 = @divFloor(lhs.toFloat(f64, mod), rhs.toFloat(f64, mod)) },
        80 => .{ .f80 = @divFloor(lhs.toFloat(f80, mod), rhs.toFloat(f80, mod)) },
        128 => .{ .f128 = @divFloor(lhs.toFloat(f128, mod), rhs.toFloat(f128, mod)) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn floatDivTrunc(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    arena: Allocator,
    mod: *Module,
) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try floatDivTruncScalar(lhs_elem, rhs_elem, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return floatDivTruncScalar(lhs, rhs, float_type, mod);
}

pub fn floatDivTruncScalar(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    mod: *Module,
) !Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @divTrunc(lhs.toFloat(f16, mod), rhs.toFloat(f16, mod)) },
        32 => .{ .f32 = @divTrunc(lhs.toFloat(f32, mod), rhs.toFloat(f32, mod)) },
        64 => .{ .f64 = @divTrunc(lhs.toFloat(f64, mod), rhs.toFloat(f64, mod)) },
        80 => .{ .f80 = @divTrunc(lhs.toFloat(f80, mod), rhs.toFloat(f80, mod)) },
        128 => .{ .f128 = @divTrunc(lhs.toFloat(f128, mod), rhs.toFloat(f128, mod)) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn floatMul(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    arena: Allocator,
    mod: *Module,
) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const lhs_elem = try lhs.elemValue(mod, i);
            const rhs_elem = try rhs.elemValue(mod, i);
            scalar.* = try (try floatMulScalar(lhs_elem, rhs_elem, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return floatMulScalar(lhs, rhs, float_type, mod);
}

pub fn floatMulScalar(
    lhs: Value,
    rhs: Value,
    float_type: Type,
    mod: *Module,
) !Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = lhs.toFloat(f16, mod) * rhs.toFloat(f16, mod) },
        32 => .{ .f32 = lhs.toFloat(f32, mod) * rhs.toFloat(f32, mod) },
        64 => .{ .f64 = lhs.toFloat(f64, mod) * rhs.toFloat(f64, mod) },
        80 => .{ .f80 = lhs.toFloat(f80, mod) * rhs.toFloat(f80, mod) },
        128 => .{ .f128 = lhs.toFloat(f128, mod) * rhs.toFloat(f128, mod) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn sqrt(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            scalar.* = try (try sqrtScalar(elem_val, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return sqrtScalar(val, float_type, mod);
}

pub fn sqrtScalar(val: Value, float_type: Type, mod: *Module) Allocator.Error!Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @sqrt(val.toFloat(f16, mod)) },
        32 => .{ .f32 = @sqrt(val.toFloat(f32, mod)) },
        64 => .{ .f64 = @sqrt(val.toFloat(f64, mod)) },
        80 => .{ .f80 = @sqrt(val.toFloat(f80, mod)) },
        128 => .{ .f128 = @sqrt(val.toFloat(f128, mod)) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn sin(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            scalar.* = try (try sinScalar(elem_val, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return sinScalar(val, float_type, mod);
}

pub fn sinScalar(val: Value, float_type: Type, mod: *Module) Allocator.Error!Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @sin(val.toFloat(f16, mod)) },
        32 => .{ .f32 = @sin(val.toFloat(f32, mod)) },
        64 => .{ .f64 = @sin(val.toFloat(f64, mod)) },
        80 => .{ .f80 = @sin(val.toFloat(f80, mod)) },
        128 => .{ .f128 = @sin(val.toFloat(f128, mod)) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn cos(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            scalar.* = try (try cosScalar(elem_val, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return cosScalar(val, float_type, mod);
}

pub fn cosScalar(val: Value, float_type: Type, mod: *Module) Allocator.Error!Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @cos(val.toFloat(f16, mod)) },
        32 => .{ .f32 = @cos(val.toFloat(f32, mod)) },
        64 => .{ .f64 = @cos(val.toFloat(f64, mod)) },
        80 => .{ .f80 = @cos(val.toFloat(f80, mod)) },
        128 => .{ .f128 = @cos(val.toFloat(f128, mod)) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn tan(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            scalar.* = try (try tanScalar(elem_val, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return tanScalar(val, float_type, mod);
}

pub fn tanScalar(val: Value, float_type: Type, mod: *Module) Allocator.Error!Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @tan(val.toFloat(f16, mod)) },
        32 => .{ .f32 = @tan(val.toFloat(f32, mod)) },
        64 => .{ .f64 = @tan(val.toFloat(f64, mod)) },
        80 => .{ .f80 = @tan(val.toFloat(f80, mod)) },
        128 => .{ .f128 = @tan(val.toFloat(f128, mod)) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn exp(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            scalar.* = try (try expScalar(elem_val, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return expScalar(val, float_type, mod);
}

pub fn expScalar(val: Value, float_type: Type, mod: *Module) Allocator.Error!Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @exp(val.toFloat(f16, mod)) },
        32 => .{ .f32 = @exp(val.toFloat(f32, mod)) },
        64 => .{ .f64 = @exp(val.toFloat(f64, mod)) },
        80 => .{ .f80 = @exp(val.toFloat(f80, mod)) },
        128 => .{ .f128 = @exp(val.toFloat(f128, mod)) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn exp2(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            scalar.* = try (try exp2Scalar(elem_val, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return exp2Scalar(val, float_type, mod);
}

pub fn exp2Scalar(val: Value, float_type: Type, mod: *Module) Allocator.Error!Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @exp2(val.toFloat(f16, mod)) },
        32 => .{ .f32 = @exp2(val.toFloat(f32, mod)) },
        64 => .{ .f64 = @exp2(val.toFloat(f64, mod)) },
        80 => .{ .f80 = @exp2(val.toFloat(f80, mod)) },
        128 => .{ .f128 = @exp2(val.toFloat(f128, mod)) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn log(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            scalar.* = try (try logScalar(elem_val, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return logScalar(val, float_type, mod);
}

pub fn logScalar(val: Value, float_type: Type, mod: *Module) Allocator.Error!Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @log(val.toFloat(f16, mod)) },
        32 => .{ .f32 = @log(val.toFloat(f32, mod)) },
        64 => .{ .f64 = @log(val.toFloat(f64, mod)) },
        80 => .{ .f80 = @log(val.toFloat(f80, mod)) },
        128 => .{ .f128 = @log(val.toFloat(f128, mod)) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn log2(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            scalar.* = try (try log2Scalar(elem_val, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return log2Scalar(val, float_type, mod);
}

pub fn log2Scalar(val: Value, float_type: Type, mod: *Module) Allocator.Error!Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @log2(val.toFloat(f16, mod)) },
        32 => .{ .f32 = @log2(val.toFloat(f32, mod)) },
        64 => .{ .f64 = @log2(val.toFloat(f64, mod)) },
        80 => .{ .f80 = @log2(val.toFloat(f80, mod)) },
        128 => .{ .f128 = @log2(val.toFloat(f128, mod)) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn log10(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            scalar.* = try (try log10Scalar(elem_val, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return log10Scalar(val, float_type, mod);
}

pub fn log10Scalar(val: Value, float_type: Type, mod: *Module) Allocator.Error!Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @log10(val.toFloat(f16, mod)) },
        32 => .{ .f32 = @log10(val.toFloat(f32, mod)) },
        64 => .{ .f64 = @log10(val.toFloat(f64, mod)) },
        80 => .{ .f80 = @log10(val.toFloat(f80, mod)) },
        128 => .{ .f128 = @log10(val.toFloat(f128, mod)) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn abs(val: Value, ty: Type, arena: Allocator, mod: *Module) !Value {
    if (ty.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(mod));
        const scalar_ty = ty.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            scalar.* = try (try absScalar(elem_val, scalar_ty, mod, arena)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = ty.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return absScalar(val, ty, mod, arena);
}

pub fn absScalar(val: Value, ty: Type, mod: *Module, arena: Allocator) Allocator.Error!Value {
    switch (ty.zigTypeTag(mod)) {
        .Int => {
            var buffer: Value.BigIntSpace = undefined;
            var operand_bigint = try val.toBigInt(&buffer, mod).toManaged(arena);
            operand_bigint.abs();

            return mod.intValue_big(try ty.toUnsigned(mod), operand_bigint.toConst());
        },
        .ComptimeInt => {
            var buffer: Value.BigIntSpace = undefined;
            var operand_bigint = try val.toBigInt(&buffer, mod).toManaged(arena);
            operand_bigint.abs();

            return mod.intValue_big(ty, operand_bigint.toConst());
        },
        .ComptimeFloat, .Float => {
            const target = mod.getTarget();
            const storage: InternPool.Key.Float.Storage = switch (ty.floatBits(target)) {
                16 => .{ .f16 = @abs(val.toFloat(f16, mod)) },
                32 => .{ .f32 = @abs(val.toFloat(f32, mod)) },
                64 => .{ .f64 = @abs(val.toFloat(f64, mod)) },
                80 => .{ .f80 = @abs(val.toFloat(f80, mod)) },
                128 => .{ .f128 = @abs(val.toFloat(f128, mod)) },
                else => unreachable,
            };
            return Value.fromInterned((try mod.intern(.{ .float = .{
                .ty = ty.toIntern(),
                .storage = storage,
            } })));
        },
        else => unreachable,
    }
}

pub fn floor(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            scalar.* = try (try floorScalar(elem_val, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return floorScalar(val, float_type, mod);
}

pub fn floorScalar(val: Value, float_type: Type, mod: *Module) Allocator.Error!Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @floor(val.toFloat(f16, mod)) },
        32 => .{ .f32 = @floor(val.toFloat(f32, mod)) },
        64 => .{ .f64 = @floor(val.toFloat(f64, mod)) },
        80 => .{ .f80 = @floor(val.toFloat(f80, mod)) },
        128 => .{ .f128 = @floor(val.toFloat(f128, mod)) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn ceil(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            scalar.* = try (try ceilScalar(elem_val, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return ceilScalar(val, float_type, mod);
}

pub fn ceilScalar(val: Value, float_type: Type, mod: *Module) Allocator.Error!Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @ceil(val.toFloat(f16, mod)) },
        32 => .{ .f32 = @ceil(val.toFloat(f32, mod)) },
        64 => .{ .f64 = @ceil(val.toFloat(f64, mod)) },
        80 => .{ .f80 = @ceil(val.toFloat(f80, mod)) },
        128 => .{ .f128 = @ceil(val.toFloat(f128, mod)) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn round(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            scalar.* = try (try roundScalar(elem_val, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return roundScalar(val, float_type, mod);
}

pub fn roundScalar(val: Value, float_type: Type, mod: *Module) Allocator.Error!Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @round(val.toFloat(f16, mod)) },
        32 => .{ .f32 = @round(val.toFloat(f32, mod)) },
        64 => .{ .f64 = @round(val.toFloat(f64, mod)) },
        80 => .{ .f80 = @round(val.toFloat(f80, mod)) },
        128 => .{ .f128 = @round(val.toFloat(f128, mod)) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn trunc(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const elem_val = try val.elemValue(mod, i);
            scalar.* = try (try truncScalar(elem_val, scalar_ty, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return truncScalar(val, float_type, mod);
}

pub fn truncScalar(val: Value, float_type: Type, mod: *Module) Allocator.Error!Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @trunc(val.toFloat(f16, mod)) },
        32 => .{ .f32 = @trunc(val.toFloat(f32, mod)) },
        64 => .{ .f64 = @trunc(val.toFloat(f64, mod)) },
        80 => .{ .f80 = @trunc(val.toFloat(f80, mod)) },
        128 => .{ .f128 = @trunc(val.toFloat(f128, mod)) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

pub fn mulAdd(
    float_type: Type,
    mulend1: Value,
    mulend2: Value,
    addend: Value,
    arena: Allocator,
    mod: *Module,
) !Value {
    if (float_type.zigTypeTag(mod) == .Vector) {
        const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(mod));
        const scalar_ty = float_type.scalarType(mod);
        for (result_data, 0..) |*scalar, i| {
            const mulend1_elem = try mulend1.elemValue(mod, i);
            const mulend2_elem = try mulend2.elemValue(mod, i);
            const addend_elem = try addend.elemValue(mod, i);
            scalar.* = try (try mulAddScalar(scalar_ty, mulend1_elem, mulend2_elem, addend_elem, mod)).intern(scalar_ty, mod);
        }
        return Value.fromInterned((try mod.intern(.{ .aggregate = .{
            .ty = float_type.toIntern(),
            .storage = .{ .elems = result_data },
        } })));
    }
    return mulAddScalar(float_type, mulend1, mulend2, addend, mod);
}

pub fn mulAddScalar(
    float_type: Type,
    mulend1: Value,
    mulend2: Value,
    addend: Value,
    mod: *Module,
) Allocator.Error!Value {
    const target = mod.getTarget();
    const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
        16 => .{ .f16 = @mulAdd(f16, mulend1.toFloat(f16, mod), mulend2.toFloat(f16, mod), addend.toFloat(f16, mod)) },
        32 => .{ .f32 = @mulAdd(f32, mulend1.toFloat(f32, mod), mulend2.toFloat(f32, mod), addend.toFloat(f32, mod)) },
        64 => .{ .f64 = @mulAdd(f64, mulend1.toFloat(f64, mod), mulend2.toFloat(f64, mod), addend.toFloat(f64, mod)) },
        80 => .{ .f80 = @mulAdd(f80, mulend1.toFloat(f80, mod), mulend2.toFloat(f80, mod), addend.toFloat(f80, mod)) },
        128 => .{ .f128 = @mulAdd(f128, mulend1.toFloat(f128, mod), mulend2.toFloat(f128, mod), addend.toFloat(f128, mod)) },
        else => unreachable,
    };
    return Value.fromInterned((try mod.intern(.{ .float = .{
        .ty = float_type.toIntern(),
        .storage = storage,
    } })));
}

/// If the value is represented in-memory as a series of bytes that all
/// have the same value, return that byte value, otherwise null.
pub fn hasRepeatedByteRepr(val: Value, ty: Type, mod: *Module) !?u8 {
    const abi_size = std.math.cast(usize, ty.abiSize(mod)) orelse return null;
    assert(abi_size >= 1);
    const byte_buffer = try mod.gpa.alloc(u8, abi_size);
    defer mod.gpa.free(byte_buffer);

    writeToMemory(val, ty, mod, byte_buffer) catch |err| switch (err) {
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

/// For an integer (comptime or fixed-width) `val`, returns the comptime-known bounds of the value.
/// If `val` is not undef, the bounds are both `val`.
/// If `val` is undef and has a fixed-width type, the bounds are the bounds of the type.
/// If `val` is undef and is a `comptime_int`, returns null.
pub fn intValueBounds(val: Value, mod: *Module) !?[2]Value {
    if (!val.isUndef(mod)) return .{ val, val };
    const ty = mod.intern_pool.typeOf(val.toIntern());
    if (ty == .comptime_int_type) return null;
    return .{
        try Type.fromInterned(ty).minInt(mod, Type.fromInterned(ty)),
        try Type.fromInterned(ty).maxInt(mod, Type.fromInterned(ty)),
    };
}

/// This type is not copyable since it may contain pointers to its inner data.
pub const Payload = struct {
    tag: Tag,

    pub const Slice = struct {
        base: Payload,
        data: struct {
            ptr: Value,
            len: Value,
        },
    };

    pub const Bytes = struct {
        base: Payload,
        /// Includes the sentinel, if any.
        data: []const u8,
    };

    pub const SubValue = struct {
        base: Payload,
        data: Value,
    };

    pub const Aggregate = struct {
        base: Payload,
        /// Field values. The types are according to the struct or array type.
        /// The length is provided here so that copying a Value does not depend on the Type.
        data: []Value,
    };

    pub const Union = struct {
        pub const base_tag = Tag.@"union";

        base: Payload = .{ .tag = base_tag },
        data: Data,

        pub const Data = struct {
            tag: ?Value,
            val: Value,
        };
    };
};

pub const BigIntSpace = InternPool.Key.Int.Storage.BigIntSpace;

pub const zero_usize: Value = .{ .ip_index = .zero_usize, .legacy = undefined };
pub const zero_u8: Value = .{ .ip_index = .zero_u8, .legacy = undefined };
pub const zero_comptime_int: Value = .{ .ip_index = .zero, .legacy = undefined };
pub const one_comptime_int: Value = .{ .ip_index = .one, .legacy = undefined };
pub const negative_one_comptime_int: Value = .{ .ip_index = .negative_one, .legacy = undefined };
pub const undef: Value = .{ .ip_index = .undef, .legacy = undefined };
pub const @"void": Value = .{ .ip_index = .void_value, .legacy = undefined };
pub const @"null": Value = .{ .ip_index = .null_value, .legacy = undefined };
pub const @"false": Value = .{ .ip_index = .bool_false, .legacy = undefined };
pub const @"true": Value = .{ .ip_index = .bool_true, .legacy = undefined };
pub const @"unreachable": Value = .{ .ip_index = .unreachable_value, .legacy = undefined };

pub const generic_poison: Value = .{ .ip_index = .generic_poison, .legacy = undefined };
pub const generic_poison_type: Value = .{ .ip_index = .generic_poison_type, .legacy = undefined };
pub const empty_struct: Value = .{ .ip_index = .empty_struct, .legacy = undefined };

pub fn makeBool(x: bool) Value {
    return if (x) Value.true else Value.false;
}

pub const RuntimeIndex = InternPool.RuntimeIndex;

/// This function is used in the debugger pretty formatters in tools/ to fetch the
/// Tag to Payload mapping to facilitate fancy debug printing for this type.
fn dbHelper(self: *Value, tag_to_payload_map: *map: {
    const tags = @typeInfo(Tag).Enum.fields;
    var fields: [tags.len]std.builtin.Type.StructField = undefined;
    for (&fields, tags) |*field, t| field.* = .{
        .name = t.name ++ "",
        .type = *@field(Tag, t.name).Type(),
        .default_value = null,
        .is_comptime = false,
        .alignment = 0,
    };
    break :map @Type(.{ .Struct = .{
        .layout = .Extern,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = false,
    } });
}) void {
    _ = self;
    _ = tag_to_payload_map;
}

comptime {
    if (builtin.mode == .Debug) {
        _ = &dbHelper;
    }
}
