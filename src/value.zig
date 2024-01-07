const std = @import("std");
const builtin = @import("builtin");
const Type = @import("type.zig").Type;
const log2 = std.math.log2;
const assert = std.debug.assert;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Target = std.Target;
const Allocator = std.mem.Allocator;
const Zcu = @import("Module.zig");
const TypedValue = @import("TypedValue.zig");
const Sema = @import("Sema.zig");
const InternPool = @import("InternPool.zig");

pub const Value = struct {
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

    pub fn fmtValue(val: Value, ty: Type, zcu: *Zcu) std.fmt.Formatter(TypedValue.format) {
        return .{ .data = .{
            .tv = .{ .ty = ty, .val = val },
            .zcu = zcu,
        } };
    }

    /// Asserts that the value is representable as an array of bytes.
    /// Returns the value as a null-terminated string stored in the InternPool.
    pub fn toIpString(val: Value, ty: Type, zcu: *Zcu) !InternPool.NullTerminatedString {
        const ip = &zcu.intern_pool;
        return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            .enum_literal => |enum_literal| enum_literal,
            .ptr => |ptr| switch (ptr.len) {
                .none => unreachable,
                else => try arrayToIpString(val, Value.fromInterned(ptr.len).toUnsignedInt(zcu), zcu),
            },
            .aggregate => |aggregate| switch (aggregate.storage) {
                .bytes => |bytes| try ip.getOrPutString(zcu.gpa, bytes),
                .elems => try arrayToIpString(val, ty.arrayLen(zcu), zcu),
                .repeated_elem => |elem| {
                    const byte = @as(u8, @intCast(Value.fromInterned(elem).toUnsignedInt(zcu)));
                    const len = @as(usize, @intCast(ty.arrayLen(zcu)));
                    try ip.string_bytes.appendNTimes(zcu.gpa, byte, len);
                    return ip.getOrPutTrailingString(zcu.gpa, len);
                },
            },
            else => unreachable,
        };
    }

    /// Asserts that the value is representable as an array of bytes.
    /// Copies the value into a freshly allocated slice of memory, which is owned by the caller.
    pub fn toAllocatedBytes(val: Value, ty: Type, allocator: Allocator, zcu: *Zcu) ![]u8 {
        return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            .enum_literal => |enum_literal| allocator.dupe(u8, zcu.intern_pool.stringToSlice(enum_literal)),
            .ptr => |ptr| switch (ptr.len) {
                .none => unreachable,
                else => try arrayToAllocatedBytes(val, Value.fromInterned(ptr.len).toUnsignedInt(zcu), allocator, zcu),
            },
            .aggregate => |aggregate| switch (aggregate.storage) {
                .bytes => |bytes| try allocator.dupe(u8, bytes),
                .elems => try arrayToAllocatedBytes(val, ty.arrayLen(zcu), allocator, zcu),
                .repeated_elem => |elem| {
                    const byte = @as(u8, @intCast(Value.fromInterned(elem).toUnsignedInt(zcu)));
                    const result = try allocator.alloc(u8, @as(usize, @intCast(ty.arrayLen(zcu))));
                    @memset(result, byte);
                    return result;
                },
            },
            else => unreachable,
        };
    }

    fn arrayToAllocatedBytes(val: Value, len: u64, allocator: Allocator, zcu: *Zcu) ![]u8 {
        const result = try allocator.alloc(u8, @as(usize, @intCast(len)));
        for (result, 0..) |*elem, i| {
            const elem_val = try val.elemValue(zcu, i);
            elem.* = @as(u8, @intCast(elem_val.toUnsignedInt(zcu)));
        }
        return result;
    }

    fn arrayToIpString(val: Value, len_u64: u64, zcu: *Zcu) !InternPool.NullTerminatedString {
        const gpa = zcu.gpa;
        const ip = &zcu.intern_pool;
        const len = @as(usize, @intCast(len_u64));
        try ip.string_bytes.ensureUnusedCapacity(gpa, len);
        for (0..len) |i| {
            // I don't think elemValue has the possibility to affect ip.string_bytes. Let's
            // assert just to be sure.
            const prev = ip.string_bytes.items.len;
            const elem_val = try val.elemValue(zcu, i);
            assert(ip.string_bytes.items.len == prev);
            const byte = @as(u8, @intCast(elem_val.toUnsignedInt(zcu)));
            ip.string_bytes.appendAssumeCapacity(byte);
        }
        return ip.getOrPutTrailingString(gpa, len);
    }

    pub fn intern2(val: Value, ty: Type, zcu: *Zcu) Allocator.Error!InternPool.Index {
        if (val.ip_index != .none) return val.ip_index;
        return intern(val, ty, zcu);
    }

    pub fn intern(val: Value, ty: Type, zcu: *Zcu) Allocator.Error!InternPool.Index {
        if (val.ip_index != .none) return (try zcu.getCoerced(val, ty)).toIntern();
        const ip = &zcu.intern_pool;
        switch (val.tag()) {
            .eu_payload => {
                const pl = val.castTag(.eu_payload).?.data;
                return zcu.intern(.{ .error_union = .{
                    .ty = ty.toIntern(),
                    .val = .{ .payload = try pl.intern(ty.errorUnionPayload(zcu), zcu) },
                } });
            },
            .opt_payload => {
                const pl = val.castTag(.opt_payload).?.data;
                return zcu.intern(.{ .opt = .{
                    .ty = ty.toIntern(),
                    .val = try pl.intern(ty.optionalChild(zcu), zcu),
                } });
            },
            .slice => {
                const pl = val.castTag(.slice).?.data;
                const ptr = try pl.ptr.intern(ty.slicePtrFieldType(zcu), zcu);
                var ptr_key = ip.indexToKey(ptr).ptr;
                assert(ptr_key.len == .none);
                ptr_key.ty = ty.toIntern();
                ptr_key.len = try pl.len.intern(Type.usize, zcu);
                return zcu.intern(.{ .ptr = ptr_key });
            },
            .bytes => {
                const pl = val.castTag(.bytes).?.data;
                return zcu.intern(.{ .aggregate = .{
                    .ty = ty.toIntern(),
                    .storage = .{ .bytes = pl },
                } });
            },
            .repeated => {
                const pl = val.castTag(.repeated).?.data;
                return zcu.intern(.{ .aggregate = .{
                    .ty = ty.toIntern(),
                    .storage = .{ .repeated_elem = try pl.intern(ty.childType(zcu), zcu) },
                } });
            },
            .aggregate => {
                const len = @as(usize, @intCast(ty.arrayLen(zcu)));
                const old_elems = val.castTag(.aggregate).?.data[0..len];
                const new_elems = try zcu.gpa.alloc(InternPool.Index, old_elems.len);
                defer zcu.gpa.free(new_elems);
                const ty_key = ip.indexToKey(ty.toIntern());
                for (new_elems, old_elems, 0..) |*new_elem, old_elem, field_i|
                    new_elem.* = try old_elem.intern(switch (ty_key) {
                        .struct_type => ty.structFieldType(field_i, zcu),
                        .anon_struct_type => |info| Type.fromInterned(info.types.get(ip)[field_i]),
                        inline .array_type, .vector_type => |info| Type.fromInterned(info.child),
                        else => unreachable,
                    }, zcu);
                return zcu.intern(.{ .aggregate = .{
                    .ty = ty.toIntern(),
                    .storage = .{ .elems = new_elems },
                } });
            },
            .@"union" => {
                const pl = val.castTag(.@"union").?.data;
                if (pl.tag) |pl_tag| {
                    return zcu.intern(.{ .un = .{
                        .ty = ty.toIntern(),
                        .tag = try pl_tag.intern(ty.unionTagTypeHypothetical(zcu), zcu),
                        .val = try pl.val.intern(ty.unionFieldType(pl_tag, zcu).?, zcu),
                    } });
                } else {
                    return zcu.intern(.{ .un = .{
                        .ty = ty.toIntern(),
                        .tag = .none,
                        .val = try pl.val.intern(try ty.unionBackingType(zcu), zcu),
                    } });
                }
            },
        }
    }

    pub fn unintern(val: Value, arena: Allocator, zcu: *Zcu) Allocator.Error!Value {
        return if (val.ip_index == .none) val else switch (zcu.intern_pool.indexToKey(val.toIntern())) {
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
            => val,

            .error_union => |error_union| switch (error_union.val) {
                .err_name => val,
                .payload => |payload| Tag.eu_payload.create(arena, Value.fromInterned(payload)),
            },

            .ptr => |ptr| switch (ptr.len) {
                .none => val,
                else => |len| Tag.slice.create(arena, .{
                    .ptr = val.slicePtr(zcu),
                    .len = Value.fromInterned(len),
                }),
            },

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

    pub fn intFromEnum(val: Value, ty: Type, zcu: *Zcu) Allocator.Error!Value {
        const ip = &zcu.intern_pool;
        return switch (ip.indexToKey(ip.typeOf(val.toIntern()))) {
            // Assume it is already an integer and return it directly.
            .simple_type, .int_type => val,
            .enum_literal => |enum_literal| {
                const field_index = ty.enumFieldIndex(enum_literal, zcu).?;
                return switch (ip.indexToKey(ty.toIntern())) {
                    // Assume it is already an integer and return it directly.
                    .simple_type, .int_type => val,
                    .enum_type => |enum_type| if (enum_type.values.len != 0)
                        Value.fromInterned(enum_type.values.get(ip)[field_index])
                    else // Field index and integer values are the same.
                        zcu.intValue(Type.fromInterned(enum_type.tag_ty), field_index),
                    else => unreachable,
                };
            },
            .enum_type => |enum_type| try zcu.getCoerced(val, Type.fromInterned(enum_type.tag_ty)),
            else => unreachable,
        };
    }

    /// Asserts the value is an integer.
    pub fn toBigInt(val: Value, space: *BigIntSpace, zcu: *Zcu) BigIntConst {
        return val.toBigIntAdvanced(space, zcu, null) catch unreachable;
    }

    /// Asserts the value is an integer.
    pub fn toBigIntAdvanced(
        val: Value,
        space: *BigIntSpace,
        zcu: *Zcu,
        opt_sema: ?*Sema,
    ) Zcu.CompileError!BigIntConst {
        return switch (val.toIntern()) {
            .bool_false => BigIntMutable.init(&space.limbs, 0).toConst(),
            .bool_true => BigIntMutable.init(&space.limbs, 1).toConst(),
            .null_value => BigIntMutable.init(&space.limbs, 0).toConst(),
            else => switch (zcu.intern_pool.indexToKey(val.toIntern())) {
                .int => |int| switch (int.storage) {
                    .u64, .i64, .big_int => int.storage.toBigInt(space),
                    .lazy_align, .lazy_size => |ty| {
                        if (opt_sema) |sema| try sema.resolveTypeLayout(Type.fromInterned(ty));
                        const x = switch (int.storage) {
                            else => unreachable,
                            .lazy_align => Type.fromInterned(ty).abiAlignment(zcu).toByteUnits(0),
                            .lazy_size => Type.fromInterned(ty).abiSize(zcu),
                        };
                        return BigIntMutable.init(&space.limbs, x).toConst();
                    },
                },
                .enum_tag => |enum_tag| Value.fromInterned(enum_tag.int).toBigIntAdvanced(space, zcu, opt_sema),
                .opt, .ptr => BigIntMutable.init(
                    &space.limbs,
                    (try val.getUnsignedIntAdvanced(zcu, opt_sema)).?,
                ).toConst(),
                else => unreachable,
            },
        };
    }

    pub fn isFuncBody(val: Value, zcu: *Zcu) bool {
        return zcu.intern_pool.isFuncBody(val.toIntern());
    }

    pub fn getFunction(val: Value, zcu: *Zcu) ?InternPool.Key.Func {
        return if (val.ip_index != .none) switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            .func => |x| x,
            else => null,
        } else null;
    }

    pub fn getExternFunc(val: Value, zcu: *Zcu) ?InternPool.Key.ExternFunc {
        return if (val.ip_index != .none) switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            .extern_func => |extern_func| extern_func,
            else => null,
        } else null;
    }

    pub fn getVariable(val: Value, zcu: *Zcu) ?InternPool.Key.Variable {
        return if (val.ip_index != .none) switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            .variable => |variable| variable,
            else => null,
        } else null;
    }

    /// If the value fits in a u64, return it, otherwise null.
    /// Asserts not undefined.
    pub fn getUnsignedInt(val: Value, zcu: *Zcu) ?u64 {
        return getUnsignedIntAdvanced(val, zcu, null) catch unreachable;
    }

    /// If the value fits in a u64, return it, otherwise null.
    /// Asserts not undefined.
    pub fn getUnsignedIntAdvanced(val: Value, zcu: *Zcu, opt_sema: ?*Sema) !?u64 {
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
                    .lazy_align => |ty| if (opt_sema) |sema|
                        (try Type.fromInterned(ty).abiAlignmentAdvanced(zcu, .{ .sema = sema })).scalar.toByteUnits(0)
                    else
                        Type.fromInterned(ty).abiAlignment(zcu).toByteUnits(0),
                    .lazy_size => |ty| if (opt_sema) |sema|
                        (try Type.fromInterned(ty).abiSizeAdvanced(zcu, .{ .sema = sema })).scalar
                    else
                        Type.fromInterned(ty).abiSize(zcu),
                },
                .ptr => |ptr| switch (ptr.addr) {
                    .int => |int| Value.fromInterned(int).getUnsignedIntAdvanced(zcu, opt_sema),
                    .elem => |elem| {
                        const base_addr = (try Value.fromInterned(elem.base).getUnsignedIntAdvanced(zcu, opt_sema)) orelse return null;
                        const elem_ty = Type.fromInterned(zcu.intern_pool.typeOf(elem.base)).elemType2(zcu);
                        return base_addr + elem.index * elem_ty.abiSize(zcu);
                    },
                    .field => |field| {
                        const base_addr = (try Value.fromInterned(field.base).getUnsignedIntAdvanced(zcu, opt_sema)) orelse return null;
                        const struct_ty = Type.fromInterned(zcu.intern_pool.typeOf(field.base)).childType(zcu);
                        if (opt_sema) |sema| try sema.resolveTypeLayout(struct_ty);
                        return base_addr + struct_ty.structFieldOffset(@as(usize, @intCast(field.index)), zcu);
                    },
                    else => null,
                },
                .opt => |opt| switch (opt.val) {
                    .none => 0,
                    else => |payload| Value.fromInterned(payload).getUnsignedIntAdvanced(zcu, opt_sema),
                },
                else => null,
            },
        };
    }

    /// Asserts the value is an integer and it fits in a u64
    pub fn toUnsignedInt(val: Value, zcu: *Zcu) u64 {
        return getUnsignedInt(val, zcu).?;
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
                    .lazy_align => |ty| @intCast(Type.fromInterned(ty).abiAlignment(zcu).toByteUnits(0)),
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

    fn isDeclRef(val: Value, zcu: *Zcu) bool {
        var check = val;
        while (true) switch (zcu.intern_pool.indexToKey(check.toIntern())) {
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
    pub fn writeToMemory(val: Value, ty: Type, zcu: *Zcu, buffer: []u8) error{
        ReinterpretDeclRef,
        IllDefinedMemoryLayout,
        Unimplemented,
        OutOfMemory,
    }!void {
        const target = zcu.getTarget();
        const endian = target.cpu.arch.endian();
        if (val.isUndef(zcu)) {
            const size: usize = @intCast(ty.abiSize(zcu));
            @memset(buffer[0..size], 0xaa);
            return;
        }
        const ip = &zcu.intern_pool;
        switch (ty.zigTypeTag(zcu)) {
            .Void => {},
            .Bool => {
                buffer[0] = @intFromBool(val.toBool());
            },
            .Int, .Enum => {
                const int_info = ty.intInfo(zcu);
                const bits = int_info.bits;
                const byte_count: u16 = @intCast((@as(u17, bits) + 7) / 8);

                var bigint_buffer: BigIntSpace = undefined;
                const bigint = val.toBigInt(&bigint_buffer, zcu);
                bigint.writeTwosComplement(buffer[0..byte_count], endian);
            },
            .Float => switch (ty.floatBits(target)) {
                16 => std.mem.writeInt(u16, buffer[0..2], @as(u16, @bitCast(val.toFloat(f16, zcu))), endian),
                32 => std.mem.writeInt(u32, buffer[0..4], @as(u32, @bitCast(val.toFloat(f32, zcu))), endian),
                64 => std.mem.writeInt(u64, buffer[0..8], @as(u64, @bitCast(val.toFloat(f64, zcu))), endian),
                80 => std.mem.writeInt(u80, buffer[0..10], @as(u80, @bitCast(val.toFloat(f80, zcu))), endian),
                128 => std.mem.writeInt(u128, buffer[0..16], @as(u128, @bitCast(val.toFloat(f128, zcu))), endian),
                else => unreachable,
            },
            .Array => {
                const len = ty.arrayLen(zcu);
                const elem_ty = ty.childType(zcu);
                const elem_size = @as(usize, @intCast(elem_ty.abiSize(zcu)));
                var elem_i: usize = 0;
                var buf_off: usize = 0;
                while (elem_i < len) : (elem_i += 1) {
                    const elem_val = try val.elemValue(zcu, elem_i);
                    try elem_val.writeToMemory(elem_ty, zcu, buffer[buf_off..]);
                    buf_off += elem_size;
                }
            },
            .Vector => {
                // We use byte_count instead of abi_size here, so that any padding bytes
                // follow the data bytes, on both big- and little-endian systems.
                const byte_count = (@as(usize, @intCast(ty.bitSize(zcu))) + 7) / 8;
                return writeToPackedMemory(val, ty, zcu, buffer[0..byte_count], 0);
            },
            .Struct => {
                const struct_type = zcu.typeToStruct(ty) orelse return error.IllDefinedMemoryLayout;
                switch (struct_type.layout) {
                    .Auto => return error.IllDefinedMemoryLayout,
                    .Extern => for (0..struct_type.field_types.len) |i| {
                        const off: usize = @intCast(ty.structFieldOffset(i, zcu));
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
                        try writeToMemory(field_val, field_ty, zcu, buffer[off..]);
                    },
                    .Packed => {
                        const byte_count = (@as(usize, @intCast(ty.bitSize(zcu))) + 7) / 8;
                        return writeToPackedMemory(val, ty, zcu, buffer[0..byte_count], 0);
                    },
                }
            },
            .ErrorSet => {
                const bits = zcu.errorSetBits();
                const byte_count: u16 = @intCast((@as(u17, bits) + 7) / 8);

                const name = switch (ip.indexToKey(val.toIntern())) {
                    .err => |err| err.name,
                    .error_union => |error_union| error_union.val.err_name,
                    else => unreachable,
                };
                var bigint_buffer: BigIntSpace = undefined;
                const bigint = BigIntMutable.init(
                    &bigint_buffer.limbs,
                    zcu.global_error_set.getIndex(name).?,
                ).toConst();
                bigint.writeTwosComplement(buffer[0..byte_count], endian);
            },
            .Union => switch (ty.containerLayout(zcu)) {
                .Auto => return error.IllDefinedMemoryLayout, // Sema is supposed to have emitted a compile error already
                .Extern => {
                    if (val.unionTag(zcu)) |union_tag| {
                        const union_obj = zcu.typeToUnion(ty).?;
                        const field_index = zcu.unionTagFieldIndex(union_obj, union_tag).?;
                        const field_type = Type.fromInterned(union_obj.field_types.get(&zcu.intern_pool)[field_index]);
                        const field_val = try val.fieldValue(zcu, field_index);
                        const byte_count = @as(usize, @intCast(field_type.abiSize(zcu)));
                        return writeToMemory(field_val, field_type, zcu, buffer[0..byte_count]);
                    } else {
                        const backing_ty = try ty.unionBackingType(zcu);
                        const byte_count: usize = @intCast(backing_ty.abiSize(zcu));
                        return writeToMemory(val.unionValue(zcu), backing_ty, zcu, buffer[0..byte_count]);
                    }
                },
                .Packed => {
                    const backing_ty = try ty.unionBackingType(zcu);
                    const byte_count: usize = @intCast(backing_ty.abiSize(zcu));
                    return writeToPackedMemory(val, ty, zcu, buffer[0..byte_count], 0);
                },
            },
            .Pointer => {
                if (ty.isSlice(zcu)) return error.IllDefinedMemoryLayout;
                if (val.isDeclRef(zcu)) return error.ReinterpretDeclRef;
                return val.writeToMemory(Type.usize, zcu, buffer);
            },
            .Optional => {
                if (!ty.isPtrLikeOptional(zcu)) return error.IllDefinedMemoryLayout;
                const child = ty.optionalChild(zcu);
                const opt_val = val.optionalValue(zcu);
                if (opt_val) |some| {
                    return some.writeToMemory(child, zcu, buffer);
                } else {
                    return writeToMemory(try zcu.intValue(Type.usize, 0), Type.usize, zcu, buffer);
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
        zcu: *Zcu,
        buffer: []u8,
        bit_offset: usize,
    ) error{ ReinterpretDeclRef, OutOfMemory }!void {
        const ip = &zcu.intern_pool;
        const target = zcu.getTarget();
        const endian = target.cpu.arch.endian();
        if (val.isUndef(zcu)) {
            const bit_size = @as(usize, @intCast(ty.bitSize(zcu)));
            std.mem.writeVarPackedInt(buffer, bit_offset, bit_size, @as(u1, 0), endian);
            return;
        }
        switch (ty.zigTypeTag(zcu)) {
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
                const bits = ty.intInfo(zcu).bits;
                if (bits == 0) return;

                switch (ip.indexToKey((try val.intFromEnum(ty, zcu)).toIntern()).int.storage) {
                    inline .u64, .i64 => |int| std.mem.writeVarPackedInt(buffer, bit_offset, bits, int, endian),
                    .big_int => |bigint| bigint.writePackedTwosComplement(buffer, bit_offset, bits, endian),
                    .lazy_align => |lazy_align| {
                        const num = Type.fromInterned(lazy_align).abiAlignment(zcu).toByteUnits(0);
                        std.mem.writeVarPackedInt(buffer, bit_offset, bits, num, endian);
                    },
                    .lazy_size => |lazy_size| {
                        const num = Type.fromInterned(lazy_size).abiSize(zcu);
                        std.mem.writeVarPackedInt(buffer, bit_offset, bits, num, endian);
                    },
                }
            },
            .Float => switch (ty.floatBits(target)) {
                16 => std.mem.writePackedInt(u16, buffer, bit_offset, @as(u16, @bitCast(val.toFloat(f16, zcu))), endian),
                32 => std.mem.writePackedInt(u32, buffer, bit_offset, @as(u32, @bitCast(val.toFloat(f32, zcu))), endian),
                64 => std.mem.writePackedInt(u64, buffer, bit_offset, @as(u64, @bitCast(val.toFloat(f64, zcu))), endian),
                80 => std.mem.writePackedInt(u80, buffer, bit_offset, @as(u80, @bitCast(val.toFloat(f80, zcu))), endian),
                128 => std.mem.writePackedInt(u128, buffer, bit_offset, @as(u128, @bitCast(val.toFloat(f128, zcu))), endian),
                else => unreachable,
            },
            .Vector => {
                const elem_ty = ty.childType(zcu);
                const elem_bit_size = @as(u16, @intCast(elem_ty.bitSize(zcu)));
                const len = @as(usize, @intCast(ty.arrayLen(zcu)));

                var bits: u16 = 0;
                var elem_i: usize = 0;
                while (elem_i < len) : (elem_i += 1) {
                    // On big-endian systems, LLVM reverses the element order of vectors by default
                    const tgt_elem_i = if (endian == .big) len - elem_i - 1 else elem_i;
                    const elem_val = try val.elemValue(zcu, tgt_elem_i);
                    try elem_val.writeToPackedMemory(elem_ty, zcu, buffer, bit_offset + bits);
                    bits += elem_bit_size;
                }
            },
            .Struct => {
                const struct_type = ip.indexToKey(ty.toIntern()).struct_type;
                // Sema is supposed to have emitted a compile error already in the case of Auto,
                // and Extern is handled in non-packed writeToMemory.
                assert(struct_type.layout == .Packed);
                var bits: u16 = 0;
                const storage = ip.indexToKey(val.toIntern()).aggregate.storage;
                for (0..struct_type.field_types.len) |i| {
                    const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[i]);
                    const field_bits: u16 = @intCast(field_ty.bitSize(zcu));
                    const field_val = switch (storage) {
                        .bytes => unreachable,
                        .elems => |elems| elems[i],
                        .repeated_elem => |elem| elem,
                    };
                    try Value.fromInterned(field_val).writeToPackedMemory(field_ty, zcu, buffer, bit_offset + bits);
                    bits += field_bits;
                }
            },
            .Union => {
                const union_obj = zcu.typeToUnion(ty).?;
                switch (union_obj.getLayout(ip)) {
                    .Auto, .Extern => unreachable, // Handled in non-packed writeToMemory
                    .Packed => {
                        if (val.unionTag(zcu)) |union_tag| {
                            const field_index = zcu.unionTagFieldIndex(union_obj, union_tag).?;
                            const field_type = Type.fromInterned(union_obj.field_types.get(ip)[field_index]);
                            const field_val = try val.fieldValue(zcu, field_index);
                            return field_val.writeToPackedMemory(field_type, zcu, buffer, bit_offset);
                        } else {
                            const backing_ty = try ty.unionBackingType(zcu);
                            return val.unionValue(zcu).writeToPackedMemory(backing_ty, zcu, buffer, bit_offset);
                        }
                    },
                }
            },
            .Pointer => {
                assert(!ty.isSlice(zcu)); // No well defined layout.
                if (val.isDeclRef(zcu)) return error.ReinterpretDeclRef;
                return val.writeToPackedMemory(Type.usize, zcu, buffer, bit_offset);
            },
            .Optional => {
                assert(ty.isPtrLikeOptional(zcu));
                const child = ty.optionalChild(zcu);
                const opt_val = val.optionalValue(zcu);
                if (opt_val) |some| {
                    return some.writeToPackedMemory(child, zcu, buffer, bit_offset);
                } else {
                    return writeToPackedMemory(try zcu.intValue(Type.usize, 0), Type.usize, zcu, buffer, bit_offset);
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
        zcu: *Zcu,
        buffer: []const u8,
        arena: Allocator,
    ) error{
        IllDefinedMemoryLayout,
        Unimplemented,
        OutOfMemory,
    }!Value {
        const ip = &zcu.intern_pool;
        const target = zcu.getTarget();
        const endian = target.cpu.arch.endian();
        switch (ty.zigTypeTag(zcu)) {
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
                    .Enum => ty.intTagType(zcu),
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
            .Float => return Value.fromInterned((try zcu.intern(.{ .float = .{
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
                const elem_ty = ty.childType(zcu);
                const elem_size = elem_ty.abiSize(zcu);
                const elems = try arena.alloc(InternPool.Index, @as(usize, @intCast(ty.arrayLen(zcu))));
                var offset: usize = 0;
                for (elems) |*elem| {
                    elem.* = try (try readFromMemory(elem_ty, zcu, buffer[offset..], arena)).intern(elem_ty, zcu);
                    offset += @as(usize, @intCast(elem_size));
                }
                return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                    .ty = ty.toIntern(),
                    .storage = .{ .elems = elems },
                } })));
            },
            .Vector => {
                // We use byte_count instead of abi_size here, so that any padding bytes
                // follow the data bytes, on both big- and little-endian systems.
                const byte_count = (@as(usize, @intCast(ty.bitSize(zcu))) + 7) / 8;
                return readFromPackedMemory(ty, zcu, buffer[0..byte_count], 0, arena);
            },
            .Struct => {
                const struct_type = zcu.typeToStruct(ty).?;
                switch (struct_type.layout) {
                    .Auto => unreachable, // Sema is supposed to have emitted a compile error already
                    .Extern => {
                        const field_types = struct_type.field_types;
                        const field_vals = try arena.alloc(InternPool.Index, field_types.len);
                        for (field_vals, 0..) |*field_val, i| {
                            const field_ty = Type.fromInterned(field_types.get(ip)[i]);
                            const off: usize = @intCast(ty.structFieldOffset(i, zcu));
                            const sz: usize = @intCast(field_ty.abiSize(zcu));
                            field_val.* = try (try readFromMemory(field_ty, zcu, buffer[off..(off + sz)], arena)).intern(field_ty, zcu);
                        }
                        return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                            .ty = ty.toIntern(),
                            .storage = .{ .elems = field_vals },
                        } })));
                    },
                    .Packed => {
                        const byte_count = (@as(usize, @intCast(ty.bitSize(zcu))) + 7) / 8;
                        return readFromPackedMemory(ty, zcu, buffer[0..byte_count], 0, arena);
                    },
                }
            },
            .ErrorSet => {
                const bits = zcu.errorSetBits();
                const byte_count: u16 = @intCast((@as(u17, bits) + 7) / 8);
                const int = std.mem.readVarInt(u64, buffer[0..byte_count], endian);
                const index = (int << @as(u6, @intCast(64 - bits))) >> @as(u6, @intCast(64 - bits));
                const name = zcu.global_error_set.keys()[@intCast(index)];

                return Value.fromInterned((try zcu.intern(.{ .err = .{
                    .ty = ty.toIntern(),
                    .name = name,
                } })));
            },
            .Union => switch (ty.containerLayout(zcu)) {
                .Auto => return error.IllDefinedMemoryLayout,
                .Extern => {
                    const union_size = ty.abiSize(zcu);
                    const array_ty = try zcu.arrayType(.{ .len = union_size, .child = .u8_type });
                    const val = try (try readFromMemory(array_ty, zcu, buffer, arena)).intern(array_ty, zcu);
                    return Value.fromInterned((try zcu.intern(.{ .un = .{
                        .ty = ty.toIntern(),
                        .tag = .none,
                        .val = val,
                    } })));
                },
                .Packed => {
                    const byte_count = (@as(usize, @intCast(ty.bitSize(zcu))) + 7) / 8;
                    return readFromPackedMemory(ty, zcu, buffer[0..byte_count], 0, arena);
                },
            },
            .Pointer => {
                assert(!ty.isSlice(zcu)); // No well defined layout.
                const int_val = try readFromMemory(Type.usize, zcu, buffer, arena);
                return Value.fromInterned((try zcu.intern(.{ .ptr = .{
                    .ty = ty.toIntern(),
                    .addr = .{ .int = int_val.toIntern() },
                } })));
            },
            .Optional => {
                assert(ty.isPtrLikeOptional(zcu));
                const child_ty = ty.optionalChild(zcu);
                const child_val = try readFromMemory(child_ty, zcu, buffer, arena);
                return Value.fromInterned((try zcu.intern(.{ .opt = .{
                    .ty = ty.toIntern(),
                    .val = switch (child_val.orderAgainstZero(zcu)) {
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
        zcu: *Zcu,
        buffer: []const u8,
        bit_offset: usize,
        arena: Allocator,
    ) error{
        IllDefinedMemoryLayout,
        OutOfMemory,
    }!Value {
        const ip = &zcu.intern_pool;
        const target = zcu.getTarget();
        const endian = target.cpu.arch.endian();
        switch (ty.zigTypeTag(zcu)) {
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
                if (buffer.len == 0) return zcu.intValue(ty, 0);
                const int_info = ty.intInfo(zcu);
                const bits = int_info.bits;
                if (bits == 0) return zcu.intValue(ty, 0);

                // Fast path for integers <= u64
                if (bits <= 64) {
                    const int_ty = switch (ty_tag) {
                        .Int => ty,
                        .Enum => ty.intTagType(zcu),
                        else => unreachable,
                    };
                    return zcu.getCoerced(switch (int_info.signedness) {
                        .signed => return zcu.intValue(
                            int_ty,
                            std.mem.readVarPackedInt(i64, buffer, bit_offset, bits, endian, .signed),
                        ),
                        .unsigned => return zcu.intValue(
                            int_ty,
                            std.mem.readVarPackedInt(u64, buffer, bit_offset, bits, endian, .unsigned),
                        ),
                    }, ty);
                }

                // Slow path, we have to construct a big-int
                const abi_size = @as(usize, @intCast(ty.abiSize(zcu)));
                const Limb = std.math.big.Limb;
                const limb_count = (abi_size + @sizeOf(Limb) - 1) / @sizeOf(Limb);
                const limbs_buffer = try arena.alloc(Limb, limb_count);

                var bigint = BigIntMutable.init(limbs_buffer, 0);
                bigint.readPackedTwosComplement(buffer, bit_offset, bits, endian, int_info.signedness);
                return zcu.intValue_big(ty, bigint.toConst());
            },
            .Float => return Value.fromInterned((try zcu.intern(.{ .float = .{
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
                const elem_ty = ty.childType(zcu);
                const elems = try arena.alloc(InternPool.Index, @as(usize, @intCast(ty.arrayLen(zcu))));

                var bits: u16 = 0;
                const elem_bit_size = @as(u16, @intCast(elem_ty.bitSize(zcu)));
                for (elems, 0..) |_, i| {
                    // On big-endian systems, LLVM reverses the element order of vectors by default
                    const tgt_elem_i = if (endian == .big) elems.len - i - 1 else i;
                    elems[tgt_elem_i] = try (try readFromPackedMemory(elem_ty, zcu, buffer, bit_offset + bits, arena)).intern(elem_ty, zcu);
                    bits += elem_bit_size;
                }
                return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                    .ty = ty.toIntern(),
                    .storage = .{ .elems = elems },
                } })));
            },
            .Struct => {
                // Sema is supposed to have emitted a compile error already for Auto layout structs,
                // and Extern is handled by non-packed readFromMemory.
                const struct_type = zcu.typeToPackedStruct(ty).?;
                var bits: u16 = 0;
                const field_vals = try arena.alloc(InternPool.Index, struct_type.field_types.len);
                for (field_vals, 0..) |*field_val, i| {
                    const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[i]);
                    const field_bits: u16 = @intCast(field_ty.bitSize(zcu));
                    field_val.* = try (try readFromPackedMemory(field_ty, zcu, buffer, bit_offset + bits, arena)).intern(field_ty, zcu);
                    bits += field_bits;
                }
                return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                    .ty = ty.toIntern(),
                    .storage = .{ .elems = field_vals },
                } })));
            },
            .Union => switch (ty.containerLayout(zcu)) {
                .Auto, .Extern => unreachable, // Handled by non-packed readFromMemory
                .Packed => {
                    const backing_ty = try ty.unionBackingType(zcu);
                    const val = (try readFromPackedMemory(backing_ty, zcu, buffer, bit_offset, arena)).toIntern();
                    return Value.fromInterned((try zcu.intern(.{ .un = .{
                        .ty = ty.toIntern(),
                        .tag = .none,
                        .val = val,
                    } })));
                },
            },
            .Pointer => {
                assert(!ty.isSlice(zcu)); // No well defined layout.
                return readFromPackedMemory(Type.usize, zcu, buffer, bit_offset, arena);
            },
            .Optional => {
                assert(ty.isPtrLikeOptional(zcu));
                const child = ty.optionalChild(zcu);
                return readFromPackedMemory(child, zcu, buffer, bit_offset, arena);
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
                .lazy_align => |ty| @floatFromInt(Type.fromInterned(ty).abiAlignment(zcu).toByteUnits(0)),
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
            const limb: f128 = @as(f128, @floatFromInt(limbs[i]));
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
        return @as(u64, @intCast(bigint.popCount(ty.intInfo(zcu).bits)));
    }

    pub fn bitReverse(val: Value, ty: Type, zcu: *Zcu, arena: Allocator) !Value {
        const info = ty.intInfo(zcu);

        var buffer: Value.BigIntSpace = undefined;
        const operand_bigint = val.toBigInt(&buffer, zcu);

        const limbs = try arena.alloc(
            std.math.big.Limb,
            std.math.big.int.calcTwosCompLimbCount(info.bits),
        );
        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
        result_bigint.bitReverse(operand_bigint, info.signedness, info.bits);

        return zcu.intValue_big(ty, result_bigint.toConst());
    }

    pub fn byteSwap(val: Value, ty: Type, zcu: *Zcu, arena: Allocator) !Value {
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

        return zcu.intValue_big(ty, result_bigint.toConst());
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
    pub fn floatCast(self: Value, dest_ty: Type, zcu: *Zcu) !Value {
        const target = zcu.getTarget();
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = dest_ty.toIntern(),
            .storage = switch (dest_ty.floatBits(target)) {
                16 => .{ .f16 = self.toFloat(f16, zcu) },
                32 => .{ .f32 = self.toFloat(f32, zcu) },
                64 => .{ .f64 = self.toFloat(f64, zcu) },
                80 => .{ .f80 = self.toFloat(f80, zcu) },
                128 => .{ .f128 = self.toFloat(f128, zcu) },
                else => unreachable,
            },
        } })));
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
        return orderAgainstZeroAdvanced(lhs, zcu, null) catch unreachable;
    }

    pub fn orderAgainstZeroAdvanced(
        lhs: Value,
        zcu: *Zcu,
        opt_sema: ?*Sema,
    ) Zcu.CompileError!std.math.Order {
        return switch (lhs.toIntern()) {
            .bool_false => .eq,
            .bool_true => .gt,
            else => switch (zcu.intern_pool.indexToKey(lhs.toIntern())) {
                .ptr => |ptr| switch (ptr.addr) {
                    .decl, .mut_decl, .comptime_field => .gt,
                    .int => |int| Value.fromInterned(int).orderAgainstZeroAdvanced(zcu, opt_sema),
                    .elem => |elem| switch (try Value.fromInterned(elem.base).orderAgainstZeroAdvanced(zcu, opt_sema)) {
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
                        zcu,
                        false,
                        if (opt_sema) |sema| .{ .sema = sema } else .eager,
                    ) catch |err| switch (err) {
                        error.NeedLazy => unreachable,
                        else => |e| return e,
                    }) .gt else .eq,
                },
                .enum_tag => |enum_tag| Value.fromInterned(enum_tag.int).orderAgainstZeroAdvanced(zcu, opt_sema),
                .float => |float| switch (float.storage) {
                    inline else => |x| std.math.order(x, 0),
                },
                else => unreachable,
            },
        };
    }

    /// Asserts the value is comparable.
    pub fn order(lhs: Value, rhs: Value, zcu: *Zcu) std.math.Order {
        return orderAdvanced(lhs, rhs, zcu, null) catch unreachable;
    }

    /// Asserts the value is comparable.
    /// If opt_sema is null then this function asserts things are resolved and cannot fail.
    pub fn orderAdvanced(lhs: Value, rhs: Value, zcu: *Zcu, opt_sema: ?*Sema) !std.math.Order {
        const lhs_against_zero = try lhs.orderAgainstZeroAdvanced(zcu, opt_sema);
        const rhs_against_zero = try rhs.orderAgainstZeroAdvanced(zcu, opt_sema);
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
        const lhs_bigint = try lhs.toBigIntAdvanced(&lhs_bigint_space, zcu, opt_sema);
        const rhs_bigint = try rhs.toBigIntAdvanced(&rhs_bigint_space, zcu, opt_sema);
        return lhs_bigint.order(rhs_bigint);
    }

    /// Asserts the value is comparable. Does not take a type parameter because it supports
    /// comparisons between heterogeneous types.
    pub fn compareHetero(lhs: Value, op: std.math.CompareOperator, rhs: Value, zcu: *Zcu) bool {
        return compareHeteroAdvanced(lhs, op, rhs, zcu, null) catch unreachable;
    }

    pub fn compareHeteroAdvanced(
        lhs: Value,
        op: std.math.CompareOperator,
        rhs: Value,
        zcu: *Zcu,
        opt_sema: ?*Sema,
    ) !bool {
        if (lhs.pointerDecl(zcu)) |lhs_decl| {
            if (rhs.pointerDecl(zcu)) |rhs_decl| {
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
        } else if (rhs.pointerDecl(zcu)) |_| {
            switch (op) {
                .eq => return false,
                .neq => return true,
                else => {},
            }
        }
        return (try orderAdvanced(lhs, rhs, zcu, opt_sema)).compare(op);
    }

    /// Asserts the values are comparable. Both operands have type `ty`.
    /// For vectors, returns true if comparison is true for ALL elements.
    pub fn compareAll(lhs: Value, op: std.math.CompareOperator, rhs: Value, ty: Type, zcu: *Zcu) !bool {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const scalar_ty = ty.scalarType(zcu);
            for (0..ty.vectorLen(zcu)) |i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
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
    ///
    /// Note that `!compareAllWithZero(.eq, ...) != compareAllWithZero(.neq, ...)`
    pub fn compareAllWithZero(lhs: Value, op: std.math.CompareOperator, zcu: *Zcu) bool {
        return compareAllWithZeroAdvancedExtra(lhs, op, zcu, null) catch unreachable;
    }

    pub fn compareAllWithZeroAdvanced(
        lhs: Value,
        op: std.math.CompareOperator,
        sema: *Sema,
    ) Zcu.CompileError!bool {
        return compareAllWithZeroAdvancedExtra(lhs, op, sema.zcu, sema);
    }

    pub fn compareAllWithZeroAdvancedExtra(
        lhs: Value,
        op: std.math.CompareOperator,
        zcu: *Zcu,
        opt_sema: ?*Sema,
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
                .bytes => |bytes| for (bytes) |byte| {
                    if (!std.math.order(byte, 0).compare(op)) break false;
                } else true,
                .elems => |elems| for (elems) |elem| {
                    if (!try Value.fromInterned(elem).compareAllWithZeroAdvancedExtra(op, zcu, opt_sema)) break false;
                } else true,
                .repeated_elem => |elem| Value.fromInterned(elem).compareAllWithZeroAdvancedExtra(op, zcu, opt_sema),
            },
            else => {},
        }
        return (try orderAgainstZeroAdvanced(lhs, zcu, opt_sema)).compare(op);
    }

    pub fn eql(a: Value, b: Value, ty: Type, zcu: *Zcu) bool {
        assert(zcu.intern_pool.typeOf(a.toIntern()) == ty.toIntern());
        assert(zcu.intern_pool.typeOf(b.toIntern()) == ty.toIntern());
        return a.toIntern() == b.toIntern();
    }

    pub fn isComptimeMutablePtr(val: Value, zcu: *Zcu) bool {
        return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            .ptr => |ptr| switch (ptr.addr) {
                .mut_decl, .comptime_field => true,
                .eu_payload, .opt_payload => |base_ptr| Value.fromInterned(base_ptr).isComptimeMutablePtr(zcu),
                .elem, .field => |base_index| Value.fromInterned(base_index.base).isComptimeMutablePtr(zcu),
                else => false,
            },
            else => false,
        };
    }

    pub fn canMutateComptimeVarState(val: Value, zcu: *Zcu) bool {
        return val.isComptimeMutablePtr(zcu) or switch (val.toIntern()) {
            else => switch (zcu.intern_pool.indexToKey(val.toIntern())) {
                .error_union => |error_union| switch (error_union.val) {
                    .err_name => false,
                    .payload => |payload| Value.fromInterned(payload).canMutateComptimeVarState(zcu),
                },
                .ptr => |ptr| switch (ptr.addr) {
                    .eu_payload, .opt_payload => |base| Value.fromInterned(base).canMutateComptimeVarState(zcu),
                    else => false,
                },
                .opt => |opt| switch (opt.val) {
                    .none => false,
                    else => |payload| Value.fromInterned(payload).canMutateComptimeVarState(zcu),
                },
                .aggregate => |aggregate| for (aggregate.storage.values()) |elem| {
                    if (Value.fromInterned(elem).canMutateComptimeVarState(zcu)) break true;
                } else false,
                .un => |un| Value.fromInterned(un.val).canMutateComptimeVarState(zcu),
                else => false,
            },
        };
    }

    /// Gets the decl referenced by this pointer.  If the pointer does not point
    /// to a decl, or if it points to some part of a decl (like field_ptr or element_ptr),
    /// this function returns null.
    pub fn pointerDecl(val: Value, zcu: *Zcu) ?InternPool.DeclIndex {
        return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
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

    pub fn slicePtr(val: Value, zcu: *Zcu) Value {
        return Value.fromInterned(zcu.intern_pool.slicePtr(val.toIntern()));
    }

    pub fn sliceLen(val: Value, zcu: *Zcu) u64 {
        const ip = &zcu.intern_pool;
        const ptr = ip.indexToKey(val.toIntern()).ptr;
        return switch (ptr.len) {
            .none => switch (ip.indexToKey(switch (ptr.addr) {
                .decl => |decl| zcu.declPtr(decl).ty.toIntern(),
                .mut_decl => |mut_decl| zcu.declPtr(mut_decl.decl).ty.toIntern(),
                .anon_decl => |anon_decl| ip.typeOf(anon_decl.val),
                .comptime_field => |comptime_field| ip.typeOf(comptime_field),
                else => unreachable,
            })) {
                .array_type => |array_type| array_type.len,
                else => 1,
            },
            else => Value.fromInterned(ptr.len).toUnsignedInt(zcu),
        };
    }

    /// Asserts the value is a single-item pointer to an array, or an array,
    /// or an unknown-length pointer, and returns the element value at the index.
    pub fn elemValue(val: Value, zcu: *Zcu, index: usize) Allocator.Error!Value {
        return (try val.maybeElemValue(zcu, index)).?;
    }

    /// Like `elemValue`, but returns `null` instead of asserting on failure.
    pub fn maybeElemValue(val: Value, zcu: *Zcu, index: usize) Allocator.Error!?Value {
        return switch (val.ip_index) {
            .none => switch (val.tag()) {
                .bytes => try zcu.intValue(Type.u8, val.castTag(.bytes).?.data[index]),
                .repeated => val.castTag(.repeated).?.data,
                .aggregate => val.castTag(.aggregate).?.data[index],
                .slice => val.castTag(.slice).?.data.ptr.maybeElemValue(zcu, index),
                else => null,
            },
            else => switch (zcu.intern_pool.indexToKey(val.toIntern())) {
                .undef => |ty| Value.fromInterned((try zcu.intern(.{
                    .undef = Type.fromInterned(ty).elemType2(zcu).toIntern(),
                }))),
                .ptr => |ptr| switch (ptr.addr) {
                    .decl => |decl| zcu.declPtr(decl).val.maybeElemValue(zcu, index),
                    .anon_decl => |anon_decl| Value.fromInterned(anon_decl.val).maybeElemValue(zcu, index),
                    .mut_decl => |mut_decl| Value.fromInterned((try zcu.declPtr(mut_decl.decl).internValue(zcu))).maybeElemValue(zcu, index),
                    .int, .eu_payload => null,
                    .opt_payload => |base| Value.fromInterned(base).maybeElemValue(zcu, index),
                    .comptime_field => |field_val| Value.fromInterned(field_val).maybeElemValue(zcu, index),
                    .elem => |elem| Value.fromInterned(elem.base).maybeElemValue(zcu, index + @as(usize, @intCast(elem.index))),
                    .field => |field| if (Value.fromInterned(field.base).pointerDecl(zcu)) |decl_index| {
                        const base_decl = zcu.declPtr(decl_index);
                        const field_val = try base_decl.val.fieldValue(zcu, @as(usize, @intCast(field.index)));
                        return field_val.maybeElemValue(zcu, index);
                    } else null,
                },
                .opt => |opt| Value.fromInterned(opt.val).maybeElemValue(zcu, index),
                .aggregate => |aggregate| {
                    const len = zcu.intern_pool.aggregateTypeLen(aggregate.ty);
                    if (index < len) return Value.fromInterned(switch (aggregate.storage) {
                        .bytes => |bytes| try zcu.intern(.{ .int = .{
                            .ty = .u8_type,
                            .storage = .{ .u64 = bytes[index] },
                        } }),
                        .elems => |elems| elems[index],
                        .repeated_elem => |elem| elem,
                    });
                    assert(index == len);
                    return Value.fromInterned(zcu.intern_pool.indexToKey(aggregate.ty).array_type.sentinel);
                },
                else => null,
            },
        };
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
        const backing_decl = zcu.intern_pool.getBackingDecl(val.toIntern()).unwrap() orelse return false;
        const variable = zcu.declPtr(backing_decl).getOwnedVariable(zcu) orelse return false;
        return variable.is_threadlocal;
    }

    // Asserts that the provided start/end are in-bounds.
    pub fn sliceArray(
        val: Value,
        zcu: *Zcu,
        arena: Allocator,
        start: usize,
        end: usize,
    ) error{OutOfMemory}!Value {
        // TODO: write something like getCoercedInts to avoid needing to dupe
        return switch (val.ip_index) {
            .none => switch (val.tag()) {
                .slice => val.castTag(.slice).?.data.ptr.sliceArray(zcu, arena, start, end),
                .bytes => Tag.bytes.create(arena, val.castTag(.bytes).?.data[start..end]),
                .repeated => val,
                .aggregate => Tag.aggregate.create(arena, val.castTag(.aggregate).?.data[start..end]),
                else => unreachable,
            },
            else => switch (zcu.intern_pool.indexToKey(val.toIntern())) {
                .ptr => |ptr| switch (ptr.addr) {
                    .decl => |decl| try zcu.declPtr(decl).val.sliceArray(zcu, arena, start, end),
                    .mut_decl => |mut_decl| Value.fromInterned((try zcu.declPtr(mut_decl.decl).internValue(zcu)))
                        .sliceArray(zcu, arena, start, end),
                    .comptime_field => |comptime_field| Value.fromInterned(comptime_field)
                        .sliceArray(zcu, arena, start, end),
                    .elem => |elem| Value.fromInterned(elem.base)
                        .sliceArray(zcu, arena, start + @as(usize, @intCast(elem.index)), end + @as(usize, @intCast(elem.index))),
                    else => unreachable,
                },
                .aggregate => |aggregate| Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                    .ty = switch (zcu.intern_pool.indexToKey(zcu.intern_pool.typeOf(val.toIntern()))) {
                        .array_type => |array_type| try zcu.arrayType(.{
                            .len = @as(u32, @intCast(end - start)),
                            .child = array_type.child,
                            .sentinel = if (end == array_type.len) array_type.sentinel else .none,
                        }),
                        .vector_type => |vector_type| try zcu.vectorType(.{
                            .len = @as(u32, @intCast(end - start)),
                            .child = vector_type.child,
                        }),
                        else => unreachable,
                    }.toIntern(),
                    .storage = switch (aggregate.storage) {
                        .bytes => .{ .bytes = try arena.dupe(u8, zcu.intern_pool.indexToKey(val.toIntern()).aggregate.storage.bytes[start..end]) },
                        .elems => .{ .elems = try arena.dupe(InternPool.Index, zcu.intern_pool.indexToKey(val.toIntern()).aggregate.storage.elems[start..end]) },
                        .repeated_elem => |elem| .{ .repeated_elem = elem },
                    },
                } }))),
                else => unreachable,
            },
        };
    }

    pub fn fieldValue(val: Value, zcu: *Zcu, index: usize) !Value {
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
            else => switch (zcu.intern_pool.indexToKey(val.toIntern())) {
                .undef => |ty| Value.fromInterned((try zcu.intern(.{
                    .undef = Type.fromInterned(ty).structFieldType(index, zcu).toIntern(),
                }))),
                .aggregate => |aggregate| Value.fromInterned(switch (aggregate.storage) {
                    .bytes => |bytes| try zcu.intern(.{ .int = .{
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

    pub fn unionTag(val: Value, zcu: *Zcu) ?Value {
        if (val.ip_index == .none) return val.castTag(.@"union").?.data.tag;
        return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            .undef, .enum_tag => val,
            .un => |un| if (un.tag != .none) Value.fromInterned(un.tag) else return null,
            else => unreachable,
        };
    }

    pub fn unionValue(val: Value, zcu: *Zcu) Value {
        if (val.ip_index == .none) return val.castTag(.@"union").?.data.val;
        return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            .un => |un| Value.fromInterned(un.val),
            else => unreachable,
        };
    }

    /// Returns a pointer to the element value at the index.
    pub fn elemPtr(
        val: Value,
        elem_ptr_ty: Type,
        index: usize,
        zcu: *Zcu,
    ) Allocator.Error!Value {
        const elem_ty = elem_ptr_ty.childType(zcu);
        const ptr_val = switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            .ptr => |ptr| ptr: {
                switch (ptr.addr) {
                    .elem => |elem| if (Type.fromInterned(zcu.intern_pool.typeOf(elem.base)).elemType2(zcu).eql(elem_ty, zcu))
                        return Value.fromInterned((try zcu.intern(.{ .ptr = .{
                            .ty = elem_ptr_ty.toIntern(),
                            .addr = .{ .elem = .{
                                .base = elem.base,
                                .index = elem.index + index,
                            } },
                        } }))),
                    else => {},
                }
                break :ptr switch (ptr.len) {
                    .none => val,
                    else => val.slicePtr(zcu),
                };
            },
            else => val,
        };
        var ptr_ty_key = zcu.intern_pool.indexToKey(elem_ptr_ty.toIntern()).ptr_type;
        assert(ptr_ty_key.flags.size != .Slice);
        ptr_ty_key.flags.size = .Many;
        return Value.fromInterned((try zcu.intern(.{ .ptr = .{
            .ty = elem_ptr_ty.toIntern(),
            .addr = .{ .elem = .{
                .base = (try zcu.getCoerced(ptr_val, try zcu.ptrType(ptr_ty_key))).toIntern(),
                .index = index,
            } },
        } })));
    }

    pub fn isUndef(val: Value, zcu: *Zcu) bool {
        return val.ip_index != .none and zcu.intern_pool.isUndef(val.toIntern());
    }

    /// TODO: check for cases such as array that is not marked undef but all the element
    /// values are marked undef, or struct that is not marked undef but all fields are marked
    /// undef, etc.
    pub fn isUndefDeep(val: Value, zcu: *Zcu) bool {
        return val.isUndef(zcu);
    }

    /// Returns true if any value contained in `self` is undefined.
    pub fn anyUndef(val: Value, zcu: *Zcu) !bool {
        if (val.ip_index == .none) return false;
        return switch (val.toIntern()) {
            .undef => true,
            else => switch (zcu.intern_pool.indexToKey(val.toIntern())) {
                .undef => true,
                .simple_value => |v| v == .undefined,
                .ptr => |ptr| switch (ptr.len) {
                    .none => false,
                    else => for (0..@as(usize, @intCast(Value.fromInterned(ptr.len).toUnsignedInt(zcu)))) |index| {
                        if (try (try val.elemValue(zcu, index)).anyUndef(zcu)) break true;
                    } else false,
                },
                .aggregate => |aggregate| for (0..aggregate.storage.values().len) |i| {
                    const elem = zcu.intern_pool.indexToKey(val.toIntern()).aggregate.storage.values()[i];
                    if (try anyUndef(Value.fromInterned(elem), zcu)) break true;
                } else false,
                else => false,
            },
        };
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
                .ptr => |ptr| switch (ptr.addr) {
                    .int => {
                        var buf: BigIntSpace = undefined;
                        return val.toBigInt(&buf, zcu).eqlZero();
                    },
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

    pub fn getErrorInt(val: Value, zcu: *const Zcu) Zcu.ErrorInt {
        return if (getErrorName(val, zcu).unwrap()) |err_name|
            @as(Zcu.ErrorInt, @intCast(zcu.global_error_set.getIndex(err_name).?))
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
        return floatFromIntAdvanced(val, arena, int_ty, float_ty, zcu, null) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => unreachable,
        };
    }

    pub fn floatFromIntAdvanced(val: Value, arena: Allocator, int_ty: Type, float_ty: Type, zcu: *Zcu, opt_sema: ?*Sema) !Value {
        if (int_ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, int_ty.vectorLen(zcu));
            const scalar_ty = float_ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                scalar.* = try (try floatFromIntScalar(elem_val, scalar_ty, zcu, opt_sema)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return floatFromIntScalar(val, float_ty, zcu, opt_sema);
    }

    pub fn floatFromIntScalar(val: Value, float_ty: Type, zcu: *Zcu, opt_sema: ?*Sema) !Value {
        return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            .undef => try zcu.undefValue(float_ty),
            .int => |int| switch (int.storage) {
                .big_int => |big_int| {
                    const float = bigIntToFloat(big_int.limbs, big_int.positive);
                    return zcu.floatValue(float_ty, float);
                },
                inline .u64, .i64 => |x| floatFromIntInner(x, float_ty, zcu),
                .lazy_align => |ty| if (opt_sema) |sema| {
                    return floatFromIntInner((try Type.fromInterned(ty).abiAlignmentAdvanced(zcu, .{ .sema = sema })).scalar.toByteUnits(0), float_ty, zcu);
                } else {
                    return floatFromIntInner(Type.fromInterned(ty).abiAlignment(zcu).toByteUnits(0), float_ty, zcu);
                },
                .lazy_size => |ty| if (opt_sema) |sema| {
                    return floatFromIntInner((try Type.fromInterned(ty).abiSizeAdvanced(zcu, .{ .sema = sema })).scalar, float_ty, zcu);
                } else {
                    return floatFromIntInner(Type.fromInterned(ty).abiSize(zcu), float_ty, zcu);
                },
            },
            else => unreachable,
        };
    }

    fn floatFromIntInner(x: anytype, dest_ty: Type, zcu: *Zcu) !Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (dest_ty.floatBits(target)) {
            16 => .{ .f16 = @floatFromInt(x) },
            32 => .{ .f32 = @floatFromInt(x) },
            64 => .{ .f64 = @floatFromInt(x) },
            80 => .{ .f80 = @floatFromInt(x) },
            128 => .{ .f128 = @floatFromInt(x) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
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
        zcu: *Zcu,
    ) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try intAddSatScalar(lhs_elem, rhs_elem, scalar_ty, arena, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return intAddSatScalar(lhs, rhs, ty, arena, zcu);
    }

    /// Supports integers only; asserts neither operand is undefined.
    pub fn intAddSatScalar(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !Value {
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
        return zcu.intValue_big(ty, result_bigint.toConst());
    }

    /// Supports (vectors of) integers only; asserts neither operand is undefined.
    pub fn intSubSat(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try intSubSatScalar(lhs_elem, rhs_elem, scalar_ty, arena, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return intSubSatScalar(lhs, rhs, ty, arena, zcu);
    }

    /// Supports integers only; asserts neither operand is undefined.
    pub fn intSubSatScalar(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !Value {
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
        return zcu.intValue_big(ty, result_bigint.toConst());
    }

    pub fn intMulWithOverflow(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !OverflowArithmeticResult {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const vec_len = ty.vectorLen(zcu);
            const overflowed_data = try arena.alloc(InternPool.Index, vec_len);
            const result_data = try arena.alloc(InternPool.Index, vec_len);
            const scalar_ty = ty.scalarType(zcu);
            for (overflowed_data, result_data, 0..) |*of, *scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                const of_math_result = try intMulWithOverflowScalar(lhs_elem, rhs_elem, scalar_ty, arena, zcu);
                of.* = try of_math_result.overflow_bit.intern(Type.u1, zcu);
                scalar.* = try of_math_result.wrapped_result.intern(scalar_ty, zcu);
            }
            return OverflowArithmeticResult{
                .overflow_bit = Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                    .ty = (try zcu.vectorType(.{ .len = vec_len, .child = .u1_type })).toIntern(),
                    .storage = .{ .elems = overflowed_data },
                } }))),
                .wrapped_result = Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                    .ty = ty.toIntern(),
                    .storage = .{ .elems = result_data },
                } }))),
            };
        }
        return intMulWithOverflowScalar(lhs, rhs, ty, arena, zcu);
    }

    pub fn intMulWithOverflowScalar(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !OverflowArithmeticResult {
        const info = ty.intInfo(zcu);

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
            .overflow_bit = try zcu.intValue(Type.u1, @intFromBool(overflowed)),
            .wrapped_result = try zcu.intValue_big(ty, result_bigint.toConst()),
        };
    }

    /// Supports both (vectors of) floats and ints; handles undefined scalars.
    pub fn numberMulWrap(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try numberMulWrapScalar(lhs_elem, rhs_elem, scalar_ty, arena, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return numberMulWrapScalar(lhs, rhs, ty, arena, zcu);
    }

    /// Supports both floats and ints; handles undefined.
    pub fn numberMulWrapScalar(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !Value {
        if (lhs.isUndef(zcu) or rhs.isUndef(zcu)) return Value.undef;

        if (ty.zigTypeTag(zcu) == .ComptimeInt) {
            return intMul(lhs, rhs, ty, undefined, arena, zcu);
        }

        if (ty.isAnyFloat()) {
            return floatMul(lhs, rhs, ty, arena, zcu);
        }

        const overflow_result = try intMulWithOverflow(lhs, rhs, ty, arena, zcu);
        return overflow_result.wrapped_result;
    }

    /// Supports (vectors of) integers only; asserts neither operand is undefined.
    pub fn intMulSat(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try intMulSatScalar(lhs_elem, rhs_elem, scalar_ty, arena, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return intMulSatScalar(lhs, rhs, ty, arena, zcu);
    }

    /// Supports (vectors of) integers only; asserts neither operand is undefined.
    pub fn intMulSatScalar(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !Value {
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
        return zcu.intValue_big(ty, result_bigint.toConst());
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
    pub fn bitwiseNot(val: Value, ty: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                scalar.* = try (try bitwiseNotScalar(elem_val, scalar_ty, arena, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return bitwiseNotScalar(val, ty, arena, zcu);
    }

    /// operands must be integers; handles undefined.
    pub fn bitwiseNotScalar(val: Value, ty: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (val.isUndef(zcu)) return Value.fromInterned((try zcu.intern(.{ .undef = ty.toIntern() })));
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
        return zcu.intValue_big(ty, result_bigint.toConst());
    }

    /// operands must be (vectors of) integers; handles undefined scalars.
    pub fn bitwiseAnd(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, zcu: *Zcu) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try bitwiseAndScalar(lhs_elem, rhs_elem, scalar_ty, allocator, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return bitwiseAndScalar(lhs, rhs, ty, allocator, zcu);
    }

    /// operands must be integers; handles undefined.
    pub fn bitwiseAndScalar(lhs: Value, rhs: Value, ty: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (lhs.isUndef(zcu) or rhs.isUndef(zcu)) return Value.fromInterned((try zcu.intern(.{ .undef = ty.toIntern() })));
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
        return zcu.intValue_big(ty, result_bigint.toConst());
    }

    /// operands must be (vectors of) integers; handles undefined scalars.
    pub fn bitwiseNand(lhs: Value, rhs: Value, ty: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try bitwiseNandScalar(lhs_elem, rhs_elem, scalar_ty, arena, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return bitwiseNandScalar(lhs, rhs, ty, arena, zcu);
    }

    /// operands must be integers; handles undefined.
    pub fn bitwiseNandScalar(lhs: Value, rhs: Value, ty: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (lhs.isUndef(zcu) or rhs.isUndef(zcu)) return Value.fromInterned((try zcu.intern(.{ .undef = ty.toIntern() })));
        if (ty.toIntern() == .bool_type) return makeBool(!(lhs.toBool() and rhs.toBool()));

        const anded = try bitwiseAnd(lhs, rhs, ty, arena, zcu);
        const all_ones = if (ty.isSignedInt(zcu)) try zcu.intValue(ty, -1) else try ty.maxIntScalar(zcu, ty);
        return bitwiseXor(anded, all_ones, ty, arena, zcu);
    }

    /// operands must be (vectors of) integers; handles undefined scalars.
    pub fn bitwiseOr(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, zcu: *Zcu) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try bitwiseOrScalar(lhs_elem, rhs_elem, scalar_ty, allocator, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return bitwiseOrScalar(lhs, rhs, ty, allocator, zcu);
    }

    /// operands must be integers; handles undefined.
    pub fn bitwiseOrScalar(lhs: Value, rhs: Value, ty: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (lhs.isUndef(zcu) or rhs.isUndef(zcu)) return Value.fromInterned((try zcu.intern(.{ .undef = ty.toIntern() })));
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
        return zcu.intValue_big(ty, result_bigint.toConst());
    }

    /// operands must be (vectors of) integers; handles undefined scalars.
    pub fn bitwiseXor(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, zcu: *Zcu) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try bitwiseXorScalar(lhs_elem, rhs_elem, scalar_ty, allocator, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return bitwiseXorScalar(lhs, rhs, ty, allocator, zcu);
    }

    /// operands must be integers; handles undefined.
    pub fn bitwiseXorScalar(lhs: Value, rhs: Value, ty: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (lhs.isUndef(zcu) or rhs.isUndef(zcu)) return Value.fromInterned((try zcu.intern(.{ .undef = ty.toIntern() })));
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
        return zcu.intValue_big(ty, result_bigint.toConst());
    }

    /// If the value overflowed the type, returns a comptime_int (or vector thereof) instead, setting
    /// overflow_idx to the vector index the overflow was at (or 0 for a scalar).
    pub fn intDiv(lhs: Value, rhs: Value, ty: Type, overflow_idx: *?usize, allocator: Allocator, zcu: *Zcu) !Value {
        var overflow: usize = undefined;
        return intDivInner(lhs, rhs, ty, &overflow, allocator, zcu) catch |err| switch (err) {
            error.Overflow => {
                const is_vec = ty.isVector(zcu);
                overflow_idx.* = if (is_vec) overflow else 0;
                const safe_ty = if (is_vec) try zcu.vectorType(.{
                    .len = ty.vectorLen(zcu),
                    .child = .comptime_int_type,
                }) else Type.comptime_int;
                return intDivInner(lhs, rhs, safe_ty, undefined, allocator, zcu) catch |err1| switch (err1) {
                    error.Overflow => unreachable,
                    else => |e| return e,
                };
            },
            else => |e| return e,
        };
    }

    fn intDivInner(lhs: Value, rhs: Value, ty: Type, overflow_idx: *usize, allocator: Allocator, zcu: *Zcu) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                const val = intDivScalar(lhs_elem, rhs_elem, scalar_ty, allocator, zcu) catch |err| switch (err) {
                    error.Overflow => {
                        overflow_idx.* = i;
                        return error.Overflow;
                    },
                    else => |e| return e,
                };
                scalar.* = try val.intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return intDivScalar(lhs, rhs, ty, allocator, zcu);
    }

    pub fn intDivScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, zcu: *Zcu) !Value {
        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
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
            const info = ty.intInfo(zcu);
            if (!result_q.toConst().fitsInTwosComp(info.signedness, info.bits)) {
                return error.Overflow;
            }
        }
        return zcu.intValue_big(ty, result_q.toConst());
    }

    pub fn intDivFloor(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, zcu: *Zcu) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try intDivFloorScalar(lhs_elem, rhs_elem, scalar_ty, allocator, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return intDivFloorScalar(lhs, rhs, ty, allocator, zcu);
    }

    pub fn intDivFloorScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, zcu: *Zcu) !Value {
        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
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
        return zcu.intValue_big(ty, result_q.toConst());
    }

    pub fn intMod(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, zcu: *Zcu) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try intModScalar(lhs_elem, rhs_elem, scalar_ty, allocator, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return intModScalar(lhs, rhs, ty, allocator, zcu);
    }

    pub fn intModScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, zcu: *Zcu) !Value {
        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
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
        return zcu.intValue_big(ty, result_r.toConst());
    }

    /// Returns true if the value is a floating point type and is NaN. Returns false otherwise.
    pub fn isNan(val: Value, zcu: *const Zcu) bool {
        if (val.ip_index == .none) return false;
        return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            .float => |float| switch (float.storage) {
                inline else => |x| std.math.isNan(x),
            },
            else => false,
        };
    }

    /// Returns true if the value is a floating point type and is infinite. Returns false otherwise.
    pub fn isInf(val: Value, zcu: *const Zcu) bool {
        if (val.ip_index == .none) return false;
        return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            .float => |float| switch (float.storage) {
                inline else => |x| std.math.isInf(x),
            },
            else => false,
        };
    }

    pub fn isNegativeInf(val: Value, zcu: *const Zcu) bool {
        if (val.ip_index == .none) return false;
        return switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            .float => |float| switch (float.storage) {
                inline else => |x| std.math.isNegativeInf(x),
            },
            else => false,
        };
    }

    pub fn floatRem(lhs: Value, rhs: Value, float_type: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try floatRemScalar(lhs_elem, rhs_elem, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return floatRemScalar(lhs, rhs, float_type, zcu);
    }

    pub fn floatRemScalar(lhs: Value, rhs: Value, float_type: Type, zcu: *Zcu) !Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = @rem(lhs.toFloat(f16, zcu), rhs.toFloat(f16, zcu)) },
            32 => .{ .f32 = @rem(lhs.toFloat(f32, zcu), rhs.toFloat(f32, zcu)) },
            64 => .{ .f64 = @rem(lhs.toFloat(f64, zcu), rhs.toFloat(f64, zcu)) },
            80 => .{ .f80 = @rem(lhs.toFloat(f80, zcu), rhs.toFloat(f80, zcu)) },
            128 => .{ .f128 = @rem(lhs.toFloat(f128, zcu), rhs.toFloat(f128, zcu)) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn floatMod(lhs: Value, rhs: Value, float_type: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try floatModScalar(lhs_elem, rhs_elem, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return floatModScalar(lhs, rhs, float_type, zcu);
    }

    pub fn floatModScalar(lhs: Value, rhs: Value, float_type: Type, zcu: *Zcu) !Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = @mod(lhs.toFloat(f16, zcu), rhs.toFloat(f16, zcu)) },
            32 => .{ .f32 = @mod(lhs.toFloat(f32, zcu), rhs.toFloat(f32, zcu)) },
            64 => .{ .f64 = @mod(lhs.toFloat(f64, zcu), rhs.toFloat(f64, zcu)) },
            80 => .{ .f80 = @mod(lhs.toFloat(f80, zcu), rhs.toFloat(f80, zcu)) },
            128 => .{ .f128 = @mod(lhs.toFloat(f128, zcu), rhs.toFloat(f128, zcu)) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    /// If the value overflowed the type, returns a comptime_int (or vector thereof) instead, setting
    /// overflow_idx to the vector index the overflow was at (or 0 for a scalar).
    pub fn intMul(lhs: Value, rhs: Value, ty: Type, overflow_idx: *?usize, allocator: Allocator, zcu: *Zcu) !Value {
        var overflow: usize = undefined;
        return intMulInner(lhs, rhs, ty, &overflow, allocator, zcu) catch |err| switch (err) {
            error.Overflow => {
                const is_vec = ty.isVector(zcu);
                overflow_idx.* = if (is_vec) overflow else 0;
                const safe_ty = if (is_vec) try zcu.vectorType(.{
                    .len = ty.vectorLen(zcu),
                    .child = .comptime_int_type,
                }) else Type.comptime_int;
                return intMulInner(lhs, rhs, safe_ty, undefined, allocator, zcu) catch |err1| switch (err1) {
                    error.Overflow => unreachable,
                    else => |e| return e,
                };
            },
            else => |e| return e,
        };
    }

    fn intMulInner(lhs: Value, rhs: Value, ty: Type, overflow_idx: *usize, allocator: Allocator, zcu: *Zcu) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                const val = intMulScalar(lhs_elem, rhs_elem, scalar_ty, allocator, zcu) catch |err| switch (err) {
                    error.Overflow => {
                        overflow_idx.* = i;
                        return error.Overflow;
                    },
                    else => |e| return e,
                };
                scalar.* = try val.intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return intMulScalar(lhs, rhs, ty, allocator, zcu);
    }

    pub fn intMulScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, zcu: *Zcu) !Value {
        if (ty.toIntern() != .comptime_int_type) {
            const res = try intMulWithOverflowScalar(lhs, rhs, ty, allocator, zcu);
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
        return zcu.intValue_big(ty, result_bigint.toConst());
    }

    pub fn intTrunc(val: Value, ty: Type, allocator: Allocator, signedness: std.builtin.Signedness, bits: u16, zcu: *Zcu) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                scalar.* = try (try intTruncScalar(elem_val, scalar_ty, allocator, signedness, bits, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return intTruncScalar(val, ty, allocator, signedness, bits, zcu);
    }

    /// This variant may vectorize on `bits`. Asserts that `bits` is a (vector of) `u16`.
    pub fn intTruncBitsAsValue(
        val: Value,
        ty: Type,
        allocator: Allocator,
        signedness: std.builtin.Signedness,
        bits: Value,
        zcu: *Zcu,
    ) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                const bits_elem = try bits.elemValue(zcu, i);
                scalar.* = try (try intTruncScalar(elem_val, scalar_ty, allocator, signedness, @as(u16, @intCast(bits_elem.toUnsignedInt(zcu))), zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return intTruncScalar(val, ty, allocator, signedness, @as(u16, @intCast(bits.toUnsignedInt(zcu))), zcu);
    }

    pub fn intTruncScalar(
        val: Value,
        ty: Type,
        allocator: Allocator,
        signedness: std.builtin.Signedness,
        bits: u16,
        zcu: *Zcu,
    ) !Value {
        if (bits == 0) return zcu.intValue(ty, 0);

        var val_space: Value.BigIntSpace = undefined;
        const val_bigint = val.toBigInt(&val_space, zcu);

        const limbs = try allocator.alloc(
            std.math.big.Limb,
            std.math.big.int.calcTwosCompLimbCount(bits),
        );
        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };

        result_bigint.truncate(val_bigint, signedness, bits);
        return zcu.intValue_big(ty, result_bigint.toConst());
    }

    pub fn shl(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, zcu: *Zcu) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try shlScalar(lhs_elem, rhs_elem, scalar_ty, allocator, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return shlScalar(lhs, rhs, ty, allocator, zcu);
    }

    pub fn shlScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, zcu: *Zcu) !Value {
        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        var lhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
        const shift = @as(usize, @intCast(rhs.toUnsignedInt(zcu)));
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

        return zcu.intValue_big(ty, result_bigint.toConst());
    }

    pub fn shlWithOverflow(
        lhs: Value,
        rhs: Value,
        ty: Type,
        allocator: Allocator,
        zcu: *Zcu,
    ) !OverflowArithmeticResult {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const vec_len = ty.vectorLen(zcu);
            const overflowed_data = try allocator.alloc(InternPool.Index, vec_len);
            const result_data = try allocator.alloc(InternPool.Index, vec_len);
            const scalar_ty = ty.scalarType(zcu);
            for (overflowed_data, result_data, 0..) |*of, *scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                const of_math_result = try shlWithOverflowScalar(lhs_elem, rhs_elem, scalar_ty, allocator, zcu);
                of.* = try of_math_result.overflow_bit.intern(Type.u1, zcu);
                scalar.* = try of_math_result.wrapped_result.intern(scalar_ty, zcu);
            }
            return OverflowArithmeticResult{
                .overflow_bit = Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                    .ty = (try zcu.vectorType(.{ .len = vec_len, .child = .u1_type })).toIntern(),
                    .storage = .{ .elems = overflowed_data },
                } }))),
                .wrapped_result = Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                    .ty = ty.toIntern(),
                    .storage = .{ .elems = result_data },
                } }))),
            };
        }
        return shlWithOverflowScalar(lhs, rhs, ty, allocator, zcu);
    }

    pub fn shlWithOverflowScalar(
        lhs: Value,
        rhs: Value,
        ty: Type,
        allocator: Allocator,
        zcu: *Zcu,
    ) !OverflowArithmeticResult {
        const info = ty.intInfo(zcu);
        var lhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
        const shift = @as(usize, @intCast(rhs.toUnsignedInt(zcu)));
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
            .overflow_bit = try zcu.intValue(Type.u1, @intFromBool(overflowed)),
            .wrapped_result = try zcu.intValue_big(ty, result_bigint.toConst()),
        };
    }

    pub fn shlSat(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try shlSatScalar(lhs_elem, rhs_elem, scalar_ty, arena, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return shlSatScalar(lhs, rhs, ty, arena, zcu);
    }

    pub fn shlSatScalar(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !Value {
        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        const info = ty.intInfo(zcu);

        var lhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
        const shift = @as(usize, @intCast(rhs.toUnsignedInt(zcu)));
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
        return zcu.intValue_big(ty, result_bigint.toConst());
    }

    pub fn shlTrunc(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try shlTruncScalar(lhs_elem, rhs_elem, scalar_ty, arena, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return shlTruncScalar(lhs, rhs, ty, arena, zcu);
    }

    pub fn shlTruncScalar(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !Value {
        const shifted = try lhs.shl(rhs, ty, arena, zcu);
        const int_info = ty.intInfo(zcu);
        const truncated = try shifted.intTrunc(ty, arena, int_info.signedness, int_info.bits, zcu);
        return truncated;
    }

    pub fn shr(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, zcu: *Zcu) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try allocator.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try shrScalar(lhs_elem, rhs_elem, scalar_ty, allocator, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return shrScalar(lhs, rhs, ty, allocator, zcu);
    }

    pub fn shrScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, zcu: *Zcu) !Value {
        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        var lhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, zcu);
        const shift = @as(usize, @intCast(rhs.toUnsignedInt(zcu)));

        const result_limbs = lhs_bigint.limbs.len -| (shift / (@sizeOf(std.math.big.Limb) * 8));
        if (result_limbs == 0) {
            // The shift is enough to remove all the bits from the number, which means the
            // result is 0 or -1 depending on the sign.
            if (lhs_bigint.positive) {
                return zcu.intValue(ty, 0);
            } else {
                return zcu.intValue(ty, -1);
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
        return zcu.intValue_big(ty, result_bigint.toConst());
    }

    pub fn floatNeg(
        val: Value,
        float_type: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                scalar.* = try (try floatNegScalar(elem_val, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return floatNegScalar(val, float_type, zcu);
    }

    pub fn floatNegScalar(
        val: Value,
        float_type: Type,
        zcu: *Zcu,
    ) !Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = -val.toFloat(f16, zcu) },
            32 => .{ .f32 = -val.toFloat(f32, zcu) },
            64 => .{ .f64 = -val.toFloat(f64, zcu) },
            80 => .{ .f80 = -val.toFloat(f80, zcu) },
            128 => .{ .f128 = -val.toFloat(f128, zcu) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn floatAdd(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try floatAddScalar(lhs_elem, rhs_elem, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return floatAddScalar(lhs, rhs, float_type, zcu);
    }

    pub fn floatAddScalar(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        zcu: *Zcu,
    ) !Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = lhs.toFloat(f16, zcu) + rhs.toFloat(f16, zcu) },
            32 => .{ .f32 = lhs.toFloat(f32, zcu) + rhs.toFloat(f32, zcu) },
            64 => .{ .f64 = lhs.toFloat(f64, zcu) + rhs.toFloat(f64, zcu) },
            80 => .{ .f80 = lhs.toFloat(f80, zcu) + rhs.toFloat(f80, zcu) },
            128 => .{ .f128 = lhs.toFloat(f128, zcu) + rhs.toFloat(f128, zcu) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn floatSub(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try floatSubScalar(lhs_elem, rhs_elem, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return floatSubScalar(lhs, rhs, float_type, zcu);
    }

    pub fn floatSubScalar(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        zcu: *Zcu,
    ) !Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = lhs.toFloat(f16, zcu) - rhs.toFloat(f16, zcu) },
            32 => .{ .f32 = lhs.toFloat(f32, zcu) - rhs.toFloat(f32, zcu) },
            64 => .{ .f64 = lhs.toFloat(f64, zcu) - rhs.toFloat(f64, zcu) },
            80 => .{ .f80 = lhs.toFloat(f80, zcu) - rhs.toFloat(f80, zcu) },
            128 => .{ .f128 = lhs.toFloat(f128, zcu) - rhs.toFloat(f128, zcu) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn floatDiv(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try floatDivScalar(lhs_elem, rhs_elem, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return floatDivScalar(lhs, rhs, float_type, zcu);
    }

    pub fn floatDivScalar(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        zcu: *Zcu,
    ) !Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = lhs.toFloat(f16, zcu) / rhs.toFloat(f16, zcu) },
            32 => .{ .f32 = lhs.toFloat(f32, zcu) / rhs.toFloat(f32, zcu) },
            64 => .{ .f64 = lhs.toFloat(f64, zcu) / rhs.toFloat(f64, zcu) },
            80 => .{ .f80 = lhs.toFloat(f80, zcu) / rhs.toFloat(f80, zcu) },
            128 => .{ .f128 = lhs.toFloat(f128, zcu) / rhs.toFloat(f128, zcu) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn floatDivFloor(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try floatDivFloorScalar(lhs_elem, rhs_elem, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return floatDivFloorScalar(lhs, rhs, float_type, zcu);
    }

    pub fn floatDivFloorScalar(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        zcu: *Zcu,
    ) !Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = @divFloor(lhs.toFloat(f16, zcu), rhs.toFloat(f16, zcu)) },
            32 => .{ .f32 = @divFloor(lhs.toFloat(f32, zcu), rhs.toFloat(f32, zcu)) },
            64 => .{ .f64 = @divFloor(lhs.toFloat(f64, zcu), rhs.toFloat(f64, zcu)) },
            80 => .{ .f80 = @divFloor(lhs.toFloat(f80, zcu), rhs.toFloat(f80, zcu)) },
            128 => .{ .f128 = @divFloor(lhs.toFloat(f128, zcu), rhs.toFloat(f128, zcu)) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn floatDivTrunc(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try floatDivTruncScalar(lhs_elem, rhs_elem, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return floatDivTruncScalar(lhs, rhs, float_type, zcu);
    }

    pub fn floatDivTruncScalar(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        zcu: *Zcu,
    ) !Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = @divTrunc(lhs.toFloat(f16, zcu), rhs.toFloat(f16, zcu)) },
            32 => .{ .f32 = @divTrunc(lhs.toFloat(f32, zcu), rhs.toFloat(f32, zcu)) },
            64 => .{ .f64 = @divTrunc(lhs.toFloat(f64, zcu), rhs.toFloat(f64, zcu)) },
            80 => .{ .f80 = @divTrunc(lhs.toFloat(f80, zcu), rhs.toFloat(f80, zcu)) },
            128 => .{ .f128 = @divTrunc(lhs.toFloat(f128, zcu), rhs.toFloat(f128, zcu)) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn floatMul(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        zcu: *Zcu,
    ) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(zcu, i);
                const rhs_elem = try rhs.elemValue(zcu, i);
                scalar.* = try (try floatMulScalar(lhs_elem, rhs_elem, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return floatMulScalar(lhs, rhs, float_type, zcu);
    }

    pub fn floatMulScalar(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        zcu: *Zcu,
    ) !Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = lhs.toFloat(f16, zcu) * rhs.toFloat(f16, zcu) },
            32 => .{ .f32 = lhs.toFloat(f32, zcu) * rhs.toFloat(f32, zcu) },
            64 => .{ .f64 = lhs.toFloat(f64, zcu) * rhs.toFloat(f64, zcu) },
            80 => .{ .f80 = lhs.toFloat(f80, zcu) * rhs.toFloat(f80, zcu) },
            128 => .{ .f128 = lhs.toFloat(f128, zcu) * rhs.toFloat(f128, zcu) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn sqrt(val: Value, float_type: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                scalar.* = try (try sqrtScalar(elem_val, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return sqrtScalar(val, float_type, zcu);
    }

    pub fn sqrtScalar(val: Value, float_type: Type, zcu: *Zcu) Allocator.Error!Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = @sqrt(val.toFloat(f16, zcu)) },
            32 => .{ .f32 = @sqrt(val.toFloat(f32, zcu)) },
            64 => .{ .f64 = @sqrt(val.toFloat(f64, zcu)) },
            80 => .{ .f80 = @sqrt(val.toFloat(f80, zcu)) },
            128 => .{ .f128 = @sqrt(val.toFloat(f128, zcu)) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn sin(val: Value, float_type: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                scalar.* = try (try sinScalar(elem_val, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return sinScalar(val, float_type, zcu);
    }

    pub fn sinScalar(val: Value, float_type: Type, zcu: *Zcu) Allocator.Error!Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = @sin(val.toFloat(f16, zcu)) },
            32 => .{ .f32 = @sin(val.toFloat(f32, zcu)) },
            64 => .{ .f64 = @sin(val.toFloat(f64, zcu)) },
            80 => .{ .f80 = @sin(val.toFloat(f80, zcu)) },
            128 => .{ .f128 = @sin(val.toFloat(f128, zcu)) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn cos(val: Value, float_type: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                scalar.* = try (try cosScalar(elem_val, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return cosScalar(val, float_type, zcu);
    }

    pub fn cosScalar(val: Value, float_type: Type, zcu: *Zcu) Allocator.Error!Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = @cos(val.toFloat(f16, zcu)) },
            32 => .{ .f32 = @cos(val.toFloat(f32, zcu)) },
            64 => .{ .f64 = @cos(val.toFloat(f64, zcu)) },
            80 => .{ .f80 = @cos(val.toFloat(f80, zcu)) },
            128 => .{ .f128 = @cos(val.toFloat(f128, zcu)) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn tan(val: Value, float_type: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                scalar.* = try (try tanScalar(elem_val, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return tanScalar(val, float_type, zcu);
    }

    pub fn tanScalar(val: Value, float_type: Type, zcu: *Zcu) Allocator.Error!Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = @tan(val.toFloat(f16, zcu)) },
            32 => .{ .f32 = @tan(val.toFloat(f32, zcu)) },
            64 => .{ .f64 = @tan(val.toFloat(f64, zcu)) },
            80 => .{ .f80 = @tan(val.toFloat(f80, zcu)) },
            128 => .{ .f128 = @tan(val.toFloat(f128, zcu)) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn exp(val: Value, float_type: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                scalar.* = try (try expScalar(elem_val, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return expScalar(val, float_type, zcu);
    }

    pub fn expScalar(val: Value, float_type: Type, zcu: *Zcu) Allocator.Error!Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = @exp(val.toFloat(f16, zcu)) },
            32 => .{ .f32 = @exp(val.toFloat(f32, zcu)) },
            64 => .{ .f64 = @exp(val.toFloat(f64, zcu)) },
            80 => .{ .f80 = @exp(val.toFloat(f80, zcu)) },
            128 => .{ .f128 = @exp(val.toFloat(f128, zcu)) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn exp2(val: Value, float_type: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                scalar.* = try (try exp2Scalar(elem_val, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return exp2Scalar(val, float_type, zcu);
    }

    pub fn exp2Scalar(val: Value, float_type: Type, zcu: *Zcu) Allocator.Error!Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = @exp2(val.toFloat(f16, zcu)) },
            32 => .{ .f32 = @exp2(val.toFloat(f32, zcu)) },
            64 => .{ .f64 = @exp2(val.toFloat(f64, zcu)) },
            80 => .{ .f80 = @exp2(val.toFloat(f80, zcu)) },
            128 => .{ .f128 = @exp2(val.toFloat(f128, zcu)) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn log(val: Value, float_type: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                scalar.* = try (try logScalar(elem_val, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return logScalar(val, float_type, zcu);
    }

    pub fn logScalar(val: Value, float_type: Type, zcu: *Zcu) Allocator.Error!Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = @log(val.toFloat(f16, zcu)) },
            32 => .{ .f32 = @log(val.toFloat(f32, zcu)) },
            64 => .{ .f64 = @log(val.toFloat(f64, zcu)) },
            80 => .{ .f80 = @log(val.toFloat(f80, zcu)) },
            128 => .{ .f128 = @log(val.toFloat(f128, zcu)) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn log2(val: Value, float_type: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                scalar.* = try (try log2Scalar(elem_val, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return log2Scalar(val, float_type, zcu);
    }

    pub fn log2Scalar(val: Value, float_type: Type, zcu: *Zcu) Allocator.Error!Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = @log2(val.toFloat(f16, zcu)) },
            32 => .{ .f32 = @log2(val.toFloat(f32, zcu)) },
            64 => .{ .f64 = @log2(val.toFloat(f64, zcu)) },
            80 => .{ .f80 = @log2(val.toFloat(f80, zcu)) },
            128 => .{ .f128 = @log2(val.toFloat(f128, zcu)) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn log10(val: Value, float_type: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                scalar.* = try (try log10Scalar(elem_val, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return log10Scalar(val, float_type, zcu);
    }

    pub fn log10Scalar(val: Value, float_type: Type, zcu: *Zcu) Allocator.Error!Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = @log10(val.toFloat(f16, zcu)) },
            32 => .{ .f32 = @log10(val.toFloat(f32, zcu)) },
            64 => .{ .f64 = @log10(val.toFloat(f64, zcu)) },
            80 => .{ .f80 = @log10(val.toFloat(f80, zcu)) },
            128 => .{ .f128 = @log10(val.toFloat(f128, zcu)) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn abs(val: Value, ty: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (ty.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, ty.vectorLen(zcu));
            const scalar_ty = ty.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                scalar.* = try (try absScalar(elem_val, scalar_ty, zcu, arena)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = ty.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return absScalar(val, ty, zcu, arena);
    }

    pub fn absScalar(val: Value, ty: Type, zcu: *Zcu, arena: Allocator) Allocator.Error!Value {
        switch (ty.zigTypeTag(zcu)) {
            .Int => {
                var buffer: Value.BigIntSpace = undefined;
                var operand_bigint = try val.toBigInt(&buffer, zcu).toManaged(arena);
                operand_bigint.abs();

                return zcu.intValue_big(try ty.toUnsigned(zcu), operand_bigint.toConst());
            },
            .ComptimeInt => {
                var buffer: Value.BigIntSpace = undefined;
                var operand_bigint = try val.toBigInt(&buffer, zcu).toManaged(arena);
                operand_bigint.abs();

                return zcu.intValue_big(ty, operand_bigint.toConst());
            },
            .ComptimeFloat, .Float => {
                const target = zcu.getTarget();
                const storage: InternPool.Key.Float.Storage = switch (ty.floatBits(target)) {
                    16 => .{ .f16 = @abs(val.toFloat(f16, zcu)) },
                    32 => .{ .f32 = @abs(val.toFloat(f32, zcu)) },
                    64 => .{ .f64 = @abs(val.toFloat(f64, zcu)) },
                    80 => .{ .f80 = @abs(val.toFloat(f80, zcu)) },
                    128 => .{ .f128 = @abs(val.toFloat(f128, zcu)) },
                    else => unreachable,
                };
                return Value.fromInterned((try zcu.intern(.{ .float = .{
                    .ty = ty.toIntern(),
                    .storage = storage,
                } })));
            },
            else => unreachable,
        }
    }

    pub fn floor(val: Value, float_type: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                scalar.* = try (try floorScalar(elem_val, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return floorScalar(val, float_type, zcu);
    }

    pub fn floorScalar(val: Value, float_type: Type, zcu: *Zcu) Allocator.Error!Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = @floor(val.toFloat(f16, zcu)) },
            32 => .{ .f32 = @floor(val.toFloat(f32, zcu)) },
            64 => .{ .f64 = @floor(val.toFloat(f64, zcu)) },
            80 => .{ .f80 = @floor(val.toFloat(f80, zcu)) },
            128 => .{ .f128 = @floor(val.toFloat(f128, zcu)) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn ceil(val: Value, float_type: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                scalar.* = try (try ceilScalar(elem_val, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return ceilScalar(val, float_type, zcu);
    }

    pub fn ceilScalar(val: Value, float_type: Type, zcu: *Zcu) Allocator.Error!Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = @ceil(val.toFloat(f16, zcu)) },
            32 => .{ .f32 = @ceil(val.toFloat(f32, zcu)) },
            64 => .{ .f64 = @ceil(val.toFloat(f64, zcu)) },
            80 => .{ .f80 = @ceil(val.toFloat(f80, zcu)) },
            128 => .{ .f128 = @ceil(val.toFloat(f128, zcu)) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn round(val: Value, float_type: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                scalar.* = try (try roundScalar(elem_val, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return roundScalar(val, float_type, zcu);
    }

    pub fn roundScalar(val: Value, float_type: Type, zcu: *Zcu) Allocator.Error!Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = @round(val.toFloat(f16, zcu)) },
            32 => .{ .f32 = @round(val.toFloat(f32, zcu)) },
            64 => .{ .f64 = @round(val.toFloat(f64, zcu)) },
            80 => .{ .f80 = @round(val.toFloat(f80, zcu)) },
            128 => .{ .f128 = @round(val.toFloat(f128, zcu)) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    pub fn trunc(val: Value, float_type: Type, arena: Allocator, zcu: *Zcu) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(zcu, i);
                scalar.* = try (try truncScalar(elem_val, scalar_ty, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return truncScalar(val, float_type, zcu);
    }

    pub fn truncScalar(val: Value, float_type: Type, zcu: *Zcu) Allocator.Error!Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = @trunc(val.toFloat(f16, zcu)) },
            32 => .{ .f32 = @trunc(val.toFloat(f32, zcu)) },
            64 => .{ .f64 = @trunc(val.toFloat(f64, zcu)) },
            80 => .{ .f80 = @trunc(val.toFloat(f80, zcu)) },
            128 => .{ .f128 = @trunc(val.toFloat(f128, zcu)) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
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
        zcu: *Zcu,
    ) !Value {
        if (float_type.zigTypeTag(zcu) == .Vector) {
            const result_data = try arena.alloc(InternPool.Index, float_type.vectorLen(zcu));
            const scalar_ty = float_type.scalarType(zcu);
            for (result_data, 0..) |*scalar, i| {
                const mulend1_elem = try mulend1.elemValue(zcu, i);
                const mulend2_elem = try mulend2.elemValue(zcu, i);
                const addend_elem = try addend.elemValue(zcu, i);
                scalar.* = try (try mulAddScalar(scalar_ty, mulend1_elem, mulend2_elem, addend_elem, zcu)).intern(scalar_ty, zcu);
            }
            return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                .ty = float_type.toIntern(),
                .storage = .{ .elems = result_data },
            } })));
        }
        return mulAddScalar(float_type, mulend1, mulend2, addend, zcu);
    }

    pub fn mulAddScalar(
        float_type: Type,
        mulend1: Value,
        mulend2: Value,
        addend: Value,
        zcu: *Zcu,
    ) Allocator.Error!Value {
        const target = zcu.getTarget();
        const storage: InternPool.Key.Float.Storage = switch (float_type.floatBits(target)) {
            16 => .{ .f16 = @mulAdd(f16, mulend1.toFloat(f16, zcu), mulend2.toFloat(f16, zcu), addend.toFloat(f16, zcu)) },
            32 => .{ .f32 = @mulAdd(f32, mulend1.toFloat(f32, zcu), mulend2.toFloat(f32, zcu), addend.toFloat(f32, zcu)) },
            64 => .{ .f64 = @mulAdd(f64, mulend1.toFloat(f64, zcu), mulend2.toFloat(f64, zcu), addend.toFloat(f64, zcu)) },
            80 => .{ .f80 = @mulAdd(f80, mulend1.toFloat(f80, zcu), mulend2.toFloat(f80, zcu), addend.toFloat(f80, zcu)) },
            128 => .{ .f128 = @mulAdd(f128, mulend1.toFloat(f128, zcu), mulend2.toFloat(f128, zcu), addend.toFloat(f128, zcu)) },
            else => unreachable,
        };
        return Value.fromInterned((try zcu.intern(.{ .float = .{
            .ty = float_type.toIntern(),
            .storage = storage,
        } })));
    }

    /// If the value is represented in-memory as a series of bytes that all
    /// have the same value, return that byte value, otherwise null.
    pub fn hasRepeatedByteRepr(val: Value, ty: Type, zcu: *Zcu) !?u8 {
        const abi_size = std.math.cast(usize, ty.abiSize(zcu)) orelse return null;
        assert(abi_size >= 1);
        const byte_buffer = try zcu.gpa.alloc(u8, abi_size);
        defer zcu.gpa.free(byte_buffer);

        writeToMemory(val, ty, zcu, byte_buffer) catch |err| switch (err) {
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
    pub fn intValueBounds(val: Value, zcu: *Zcu) !?[2]Value {
        if (!val.isUndef(zcu)) return .{ val, val };
        const ty = zcu.intern_pool.typeOf(val.toIntern());
        if (ty == .comptime_int_type) return null;
        return .{
            try Type.fromInterned(ty).minInt(zcu, Type.fromInterned(ty)),
            try Type.fromInterned(ty).maxInt(zcu, Type.fromInterned(ty)),
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
            .name = t.name,
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
};
