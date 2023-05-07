const std = @import("std");
const builtin = @import("builtin");
const Type = @import("type.zig").Type;
const log2 = std.math.log2;
const assert = std.debug.assert;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Target = std.Target;
const Allocator = std.mem.Allocator;
const Module = @import("Module.zig");
const Air = @import("Air.zig");
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
        /// If the tag value is less than Tag.no_payload_count, then no pointer
        /// dereference is needed.
        tag_if_small_enough: Tag,
        ptr_otherwise: *Payload,
    },

    // Keep in sync with tools/stage2_pretty_printers_common.py
    pub const Tag = enum(usize) {
        // The first section of this enum are tags that require no payload.
        /// The only possible value for a particular type, which is stored externally.
        the_only_possible_value,

        empty_struct_value,
        empty_array, // See last_no_payload_tag below.
        // After this, the tag requires a payload.

        ty,
        function,
        extern_fn,
        /// A comptime-known pointer can point to the address of a global
        /// variable. The child element value in this case will have this tag.
        variable,
        /// A wrapper for values which are comptime-known but should
        /// semantically be runtime-known.
        runtime_value,
        /// Represents a pointer to a Decl.
        /// When machine codegen backend sees this, it must set the Decl's `alive` field to true.
        decl_ref,
        /// Pointer to a Decl, but allows comptime code to mutate the Decl's Value.
        /// This Tag will never be seen by machine codegen backends. It is changed into a
        /// `decl_ref` when a comptime variable goes out of scope.
        decl_ref_mut,
        /// Behaves like `decl_ref_mut` but validates that the stored value matches the field value.
        comptime_field_ptr,
        /// Pointer to a specific element of an array, vector or slice.
        elem_ptr,
        /// Pointer to a specific field of a struct or union.
        field_ptr,
        /// A slice of u8 whose memory is managed externally.
        bytes,
        /// Similar to bytes however it stores an index relative to `Module.string_literal_bytes`.
        str_lit,
        /// This value is repeated some number of times. The amount of times to repeat
        /// is stored externally.
        repeated,
        /// An array with length 0 but it has a sentinel.
        empty_array_sentinel,
        /// Pointer and length as sub `Value` objects.
        slice,
        float_16,
        float_32,
        float_64,
        float_80,
        float_128,
        enum_literal,
        /// A specific enum tag, indicated by the field index (declaration order).
        enum_field_index,
        @"error",
        /// When the type is error union:
        /// * If the tag is `.@"error"`, the error union is an error.
        /// * If the tag is `.eu_payload`, the error union is a payload.
        /// * A nested error such as `anyerror!(anyerror!T)` in which the the outer error union
        ///   is non-error, but the inner error union is an error, is represented as
        ///   a tag of `.eu_payload`, with a sub-tag of `.@"error"`.
        eu_payload,
        /// A pointer to the payload of an error union, based on a pointer to an error union.
        eu_payload_ptr,
        /// When the type is optional:
        /// * If the tag is `.null_value`, the optional is null.
        /// * If the tag is `.opt_payload`, the optional is a payload.
        /// * A nested optional such as `??T` in which the the outer optional
        ///   is non-null, but the inner optional is null, is represented as
        ///   a tag of `.opt_payload`, with a sub-tag of `.null_value`.
        opt_payload,
        /// A pointer to the payload of an optional, based on a pointer to an optional.
        opt_payload_ptr,
        /// An instance of a struct, array, or vector.
        /// Each element/field stored as a `Value`.
        /// In the case of sentinel-terminated arrays, the sentinel value *is* stored,
        /// so the slice length will be one more than the type's array length.
        aggregate,
        /// An instance of a union.
        @"union",
        /// This is a special value that tracks a set of types that have been stored
        /// to an inferred allocation. It does not support any of the normal value queries.
        inferred_alloc,
        /// Used to coordinate alloc_inferred, store_to_inferred_ptr, and resolve_inferred_alloc
        /// instructions for comptime code.
        inferred_alloc_comptime,
        /// The ABI alignment of the payload type.
        lazy_align,
        /// The ABI size of the payload type.
        lazy_size,

        pub const last_no_payload_tag = Tag.empty_array;
        pub const no_payload_count = @enumToInt(last_no_payload_tag) + 1;

        pub fn Type(comptime t: Tag) type {
            return switch (t) {
                .the_only_possible_value,
                .empty_struct_value,
                .empty_array,
                => @compileError("Value Tag " ++ @tagName(t) ++ " has no payload"),

                .extern_fn => Payload.ExternFn,

                .decl_ref => Payload.Decl,

                .repeated,
                .eu_payload,
                .opt_payload,
                .empty_array_sentinel,
                .runtime_value,
                => Payload.SubValue,

                .eu_payload_ptr,
                .opt_payload_ptr,
                => Payload.PayloadPtr,

                .bytes,
                .enum_literal,
                => Payload.Bytes,

                .str_lit => Payload.StrLit,
                .slice => Payload.Slice,

                .enum_field_index => Payload.U32,

                .ty,
                .lazy_align,
                .lazy_size,
                => Payload.Ty,

                .function => Payload.Function,
                .variable => Payload.Variable,
                .decl_ref_mut => Payload.DeclRefMut,
                .elem_ptr => Payload.ElemPtr,
                .field_ptr => Payload.FieldPtr,
                .float_16 => Payload.Float_16,
                .float_32 => Payload.Float_32,
                .float_64 => Payload.Float_64,
                .float_80 => Payload.Float_80,
                .float_128 => Payload.Float_128,
                .@"error" => Payload.Error,
                .inferred_alloc => Payload.InferredAlloc,
                .inferred_alloc_comptime => Payload.InferredAllocComptime,
                .aggregate => Payload.Aggregate,
                .@"union" => Payload.Union,
                .comptime_field_ptr => Payload.ComptimeFieldPtr,
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

    pub fn initTag(small_tag: Tag) Value {
        assert(@enumToInt(small_tag) < Tag.no_payload_count);
        return Value{
            .ip_index = .none,
            .legacy = .{ .tag_if_small_enough = small_tag },
        };
    }

    pub fn initPayload(payload: *Payload) Value {
        assert(@enumToInt(payload.tag) >= Tag.no_payload_count);
        return Value{
            .ip_index = .none,
            .legacy = .{ .ptr_otherwise = payload },
        };
    }

    pub fn tag(self: Value) Tag {
        assert(self.ip_index == .none);
        if (@enumToInt(self.legacy.tag_if_small_enough) < Tag.no_payload_count) {
            return self.legacy.tag_if_small_enough;
        } else {
            return self.legacy.ptr_otherwise.tag;
        }
    }

    /// Prefer `castTag` to this.
    pub fn cast(self: Value, comptime T: type) ?*T {
        if (self.ip_index != .none) {
            return null;
        }
        if (@hasField(T, "base_tag")) {
            return self.castTag(T.base_tag);
        }
        if (@enumToInt(self.legacy.tag_if_small_enough) < Tag.no_payload_count) {
            return null;
        }
        inline for (@typeInfo(Tag).Enum.fields) |field| {
            if (field.value < Tag.no_payload_count)
                continue;
            const t = @intToEnum(Tag, field.value);
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

        if (@enumToInt(self.legacy.tag_if_small_enough) < Tag.no_payload_count)
            return null;

        if (self.legacy.ptr_otherwise.tag == t)
            return @fieldParentPtr(t.Type(), "base", self.legacy.ptr_otherwise);

        return null;
    }

    /// It's intentional that this function is not passed a corresponding Type, so that
    /// a Value can be copied from a Sema to a Decl prior to resolving struct/union field types.
    pub fn copy(self: Value, arena: Allocator) error{OutOfMemory}!Value {
        if (self.ip_index != .none) {
            return Value{ .ip_index = self.ip_index, .legacy = undefined };
        }
        if (@enumToInt(self.legacy.tag_if_small_enough) < Tag.no_payload_count) {
            return Value{
                .ip_index = .none,
                .legacy = .{ .tag_if_small_enough = self.legacy.tag_if_small_enough },
            };
        } else switch (self.legacy.ptr_otherwise.tag) {
            .the_only_possible_value,
            .empty_array,
            .empty_struct_value,
            => unreachable,

            .ty, .lazy_align, .lazy_size => {
                const payload = self.cast(Payload.Ty).?;
                const new_payload = try arena.create(Payload.Ty);
                new_payload.* = .{
                    .base = payload.base,
                    .data = try payload.data.copy(arena),
                };
                return Value{
                    .ip_index = .none,
                    .legacy = .{ .ptr_otherwise = &new_payload.base },
                };
            },
            .function => return self.copyPayloadShallow(arena, Payload.Function),
            .extern_fn => return self.copyPayloadShallow(arena, Payload.ExternFn),
            .variable => return self.copyPayloadShallow(arena, Payload.Variable),
            .decl_ref => return self.copyPayloadShallow(arena, Payload.Decl),
            .decl_ref_mut => return self.copyPayloadShallow(arena, Payload.DeclRefMut),
            .eu_payload_ptr,
            .opt_payload_ptr,
            => {
                const payload = self.cast(Payload.PayloadPtr).?;
                const new_payload = try arena.create(Payload.PayloadPtr);
                new_payload.* = .{
                    .base = payload.base,
                    .data = .{
                        .container_ptr = try payload.data.container_ptr.copy(arena),
                        .container_ty = try payload.data.container_ty.copy(arena),
                    },
                };
                return Value{
                    .ip_index = .none,
                    .legacy = .{ .ptr_otherwise = &new_payload.base },
                };
            },
            .comptime_field_ptr => {
                const payload = self.cast(Payload.ComptimeFieldPtr).?;
                const new_payload = try arena.create(Payload.ComptimeFieldPtr);
                new_payload.* = .{
                    .base = payload.base,
                    .data = .{
                        .field_val = try payload.data.field_val.copy(arena),
                        .field_ty = try payload.data.field_ty.copy(arena),
                    },
                };
                return Value{
                    .ip_index = .none,
                    .legacy = .{ .ptr_otherwise = &new_payload.base },
                };
            },
            .elem_ptr => {
                const payload = self.castTag(.elem_ptr).?;
                const new_payload = try arena.create(Payload.ElemPtr);
                new_payload.* = .{
                    .base = payload.base,
                    .data = .{
                        .array_ptr = try payload.data.array_ptr.copy(arena),
                        .elem_ty = try payload.data.elem_ty.copy(arena),
                        .index = payload.data.index,
                    },
                };
                return Value{
                    .ip_index = .none,
                    .legacy = .{ .ptr_otherwise = &new_payload.base },
                };
            },
            .field_ptr => {
                const payload = self.castTag(.field_ptr).?;
                const new_payload = try arena.create(Payload.FieldPtr);
                new_payload.* = .{
                    .base = payload.base,
                    .data = .{
                        .container_ptr = try payload.data.container_ptr.copy(arena),
                        .container_ty = try payload.data.container_ty.copy(arena),
                        .field_index = payload.data.field_index,
                    },
                };
                return Value{
                    .ip_index = .none,
                    .legacy = .{ .ptr_otherwise = &new_payload.base },
                };
            },
            .bytes => {
                const bytes = self.castTag(.bytes).?.data;
                const new_payload = try arena.create(Payload.Bytes);
                new_payload.* = .{
                    .base = .{ .tag = .bytes },
                    .data = try arena.dupe(u8, bytes),
                };
                return Value{
                    .ip_index = .none,
                    .legacy = .{ .ptr_otherwise = &new_payload.base },
                };
            },
            .str_lit => return self.copyPayloadShallow(arena, Payload.StrLit),
            .repeated,
            .eu_payload,
            .opt_payload,
            .empty_array_sentinel,
            .runtime_value,
            => {
                const payload = self.cast(Payload.SubValue).?;
                const new_payload = try arena.create(Payload.SubValue);
                new_payload.* = .{
                    .base = payload.base,
                    .data = try payload.data.copy(arena),
                };
                return Value{
                    .ip_index = .none,
                    .legacy = .{ .ptr_otherwise = &new_payload.base },
                };
            },
            .slice => {
                const payload = self.castTag(.slice).?;
                const new_payload = try arena.create(Payload.Slice);
                new_payload.* = .{
                    .base = payload.base,
                    .data = .{
                        .ptr = try payload.data.ptr.copy(arena),
                        .len = try payload.data.len.copy(arena),
                    },
                };
                return Value{
                    .ip_index = .none,
                    .legacy = .{ .ptr_otherwise = &new_payload.base },
                };
            },
            .float_16 => return self.copyPayloadShallow(arena, Payload.Float_16),
            .float_32 => return self.copyPayloadShallow(arena, Payload.Float_32),
            .float_64 => return self.copyPayloadShallow(arena, Payload.Float_64),
            .float_80 => return self.copyPayloadShallow(arena, Payload.Float_80),
            .float_128 => return self.copyPayloadShallow(arena, Payload.Float_128),
            .enum_literal => {
                const payload = self.castTag(.enum_literal).?;
                const new_payload = try arena.create(Payload.Bytes);
                new_payload.* = .{
                    .base = payload.base,
                    .data = try arena.dupe(u8, payload.data),
                };
                return Value{
                    .ip_index = .none,
                    .legacy = .{ .ptr_otherwise = &new_payload.base },
                };
            },
            .enum_field_index => return self.copyPayloadShallow(arena, Payload.U32),
            .@"error" => return self.copyPayloadShallow(arena, Payload.Error),

            .aggregate => {
                const payload = self.castTag(.aggregate).?;
                const new_payload = try arena.create(Payload.Aggregate);
                new_payload.* = .{
                    .base = payload.base,
                    .data = try arena.alloc(Value, payload.data.len),
                };
                for (new_payload.data, 0..) |*elem, i| {
                    elem.* = try payload.data[i].copy(arena);
                }
                return Value{
                    .ip_index = .none,
                    .legacy = .{ .ptr_otherwise = &new_payload.base },
                };
            },

            .@"union" => {
                const tag_and_val = self.castTag(.@"union").?.data;
                const new_payload = try arena.create(Payload.Union);
                new_payload.* = .{
                    .base = .{ .tag = .@"union" },
                    .data = .{
                        .tag = try tag_and_val.tag.copy(arena),
                        .val = try tag_and_val.val.copy(arena),
                    },
                };
                return Value{
                    .ip_index = .none,
                    .legacy = .{ .ptr_otherwise = &new_payload.base },
                };
            },

            .inferred_alloc => unreachable,
            .inferred_alloc_comptime => unreachable,
        }
    }

    fn copyPayloadShallow(self: Value, arena: Allocator, comptime T: type) error{OutOfMemory}!Value {
        const payload = self.cast(T).?;
        const new_payload = try arena.create(T);
        new_payload.* = payload.*;
        return Value{
            .ip_index = .none,
            .legacy = .{ .ptr_otherwise = &new_payload.base },
        };
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
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        comptime assert(fmt.len == 0);
        if (start_val.ip_index != .none) {
            try out_stream.print("(interned: {})", .{start_val.ip_index});
            return;
        }
        var val = start_val;
        while (true) switch (val.tag()) {
            .empty_struct_value => return out_stream.writeAll("struct {}{}"),
            .aggregate => {
                return out_stream.writeAll("(aggregate)");
            },
            .@"union" => {
                return out_stream.writeAll("(union value)");
            },
            .the_only_possible_value => return out_stream.writeAll("(the only possible value)"),
            .ty => return val.castTag(.ty).?.data.dump("", options, out_stream),
            .lazy_align => {
                try out_stream.writeAll("@alignOf(");
                try val.castTag(.lazy_align).?.data.dump("", options, out_stream);
                return try out_stream.writeAll(")");
            },
            .lazy_size => {
                try out_stream.writeAll("@sizeOf(");
                try val.castTag(.lazy_size).?.data.dump("", options, out_stream);
                return try out_stream.writeAll(")");
            },
            .runtime_value => return out_stream.writeAll("[runtime value]"),
            .function => return out_stream.print("(function decl={d})", .{val.castTag(.function).?.data.owner_decl}),
            .extern_fn => return out_stream.writeAll("(extern function)"),
            .variable => return out_stream.writeAll("(variable)"),
            .decl_ref_mut => {
                const decl_index = val.castTag(.decl_ref_mut).?.data.decl_index;
                return out_stream.print("(decl_ref_mut {d})", .{decl_index});
            },
            .decl_ref => {
                const decl_index = val.castTag(.decl_ref).?.data;
                return out_stream.print("(decl_ref {d})", .{decl_index});
            },
            .comptime_field_ptr => {
                return out_stream.writeAll("(comptime_field_ptr)");
            },
            .elem_ptr => {
                const elem_ptr = val.castTag(.elem_ptr).?.data;
                try out_stream.print("&[{}] ", .{elem_ptr.index});
                val = elem_ptr.array_ptr;
            },
            .field_ptr => {
                const field_ptr = val.castTag(.field_ptr).?.data;
                try out_stream.print("fieldptr({d}) ", .{field_ptr.field_index});
                val = field_ptr.container_ptr;
            },
            .empty_array => return out_stream.writeAll(".{}"),
            .enum_literal => return out_stream.print(".{}", .{std.zig.fmtId(val.castTag(.enum_literal).?.data)}),
            .enum_field_index => return out_stream.print("(enum field {d})", .{val.castTag(.enum_field_index).?.data}),
            .bytes => return out_stream.print("\"{}\"", .{std.zig.fmtEscapes(val.castTag(.bytes).?.data)}),
            .str_lit => {
                const str_lit = val.castTag(.str_lit).?.data;
                return out_stream.print("(.str_lit index={d} len={d})", .{
                    str_lit.index, str_lit.len,
                });
            },
            .repeated => {
                try out_stream.writeAll("(repeated) ");
                val = val.castTag(.repeated).?.data;
            },
            .empty_array_sentinel => return out_stream.writeAll("(empty array with sentinel)"),
            .slice => return out_stream.writeAll("(slice)"),
            .float_16 => return out_stream.print("{}", .{val.castTag(.float_16).?.data}),
            .float_32 => return out_stream.print("{}", .{val.castTag(.float_32).?.data}),
            .float_64 => return out_stream.print("{}", .{val.castTag(.float_64).?.data}),
            .float_80 => return out_stream.print("{}", .{val.castTag(.float_80).?.data}),
            .float_128 => return out_stream.print("{}", .{val.castTag(.float_128).?.data}),
            .@"error" => return out_stream.print("error.{s}", .{val.castTag(.@"error").?.data.name}),
            .eu_payload => {
                try out_stream.writeAll("(eu_payload) ");
                val = val.castTag(.eu_payload).?.data;
            },
            .opt_payload => {
                try out_stream.writeAll("(opt_payload) ");
                val = val.castTag(.opt_payload).?.data;
            },
            .inferred_alloc => return out_stream.writeAll("(inferred allocation value)"),
            .inferred_alloc_comptime => return out_stream.writeAll("(inferred comptime allocation value)"),
            .eu_payload_ptr => {
                try out_stream.writeAll("(eu_payload_ptr)");
                val = val.castTag(.eu_payload_ptr).?.data.container_ptr;
            },
            .opt_payload_ptr => {
                try out_stream.writeAll("(opt_payload_ptr)");
                val = val.castTag(.opt_payload_ptr).?.data.container_ptr;
            },
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
    /// Copies the value into a freshly allocated slice of memory, which is owned by the caller.
    pub fn toAllocatedBytes(val: Value, ty: Type, allocator: Allocator, mod: *Module) ![]u8 {
        switch (val.tag()) {
            .bytes => {
                const bytes = val.castTag(.bytes).?.data;
                const adjusted_len = bytes.len - @boolToInt(ty.sentinel(mod) != null);
                const adjusted_bytes = bytes[0..adjusted_len];
                return allocator.dupe(u8, adjusted_bytes);
            },
            .str_lit => {
                const str_lit = val.castTag(.str_lit).?.data;
                const bytes = mod.string_literal_bytes.items[str_lit.index..][0..str_lit.len];
                return allocator.dupe(u8, bytes);
            },
            .enum_literal => return allocator.dupe(u8, val.castTag(.enum_literal).?.data),
            .repeated => {
                const byte = @intCast(u8, val.castTag(.repeated).?.data.toUnsignedInt(mod));
                const result = try allocator.alloc(u8, @intCast(usize, ty.arrayLen(mod)));
                @memset(result, byte);
                return result;
            },
            .decl_ref => {
                const decl_index = val.castTag(.decl_ref).?.data;
                const decl = mod.declPtr(decl_index);
                const decl_val = try decl.value();
                return decl_val.toAllocatedBytes(decl.ty, allocator, mod);
            },
            .the_only_possible_value => return &[_]u8{},
            .slice => {
                const slice = val.castTag(.slice).?.data;
                return arrayToAllocatedBytes(slice.ptr, slice.len.toUnsignedInt(mod), allocator, mod);
            },
            else => return arrayToAllocatedBytes(val, ty.arrayLen(mod), allocator, mod),
        }
    }

    fn arrayToAllocatedBytes(val: Value, len: u64, allocator: Allocator, mod: *Module) ![]u8 {
        const result = try allocator.alloc(u8, @intCast(usize, len));
        for (result, 0..) |*elem, i| {
            const elem_val = try val.elemValue(mod, i);
            elem.* = @intCast(u8, elem_val.toUnsignedInt(mod));
        }
        return result;
    }

    /// Asserts that the value is representable as a type.
    pub fn toType(self: Value) Type {
        if (self.ip_index != .none) return self.ip_index.toType();
        return switch (self.tag()) {
            .ty => self.castTag(.ty).?.data,

            else => unreachable,
        };
    }

    /// Asserts the type is an enum type.
    pub fn toEnum(val: Value, comptime E: type) E {
        switch (val.tag()) {
            .enum_field_index => {
                const field_index = val.castTag(.enum_field_index).?.data;
                return @intToEnum(E, field_index);
            },
            .the_only_possible_value => {
                const fields = std.meta.fields(E);
                assert(fields.len == 1);
                return @intToEnum(E, fields[0].value);
            },
            else => unreachable,
        }
    }

    pub fn enumToInt(val: Value, ty: Type, mod: *Module) Allocator.Error!Value {
        const field_index = switch (val.tag()) {
            .enum_field_index => val.castTag(.enum_field_index).?.data,
            .the_only_possible_value => blk: {
                assert(ty.enumFieldCount() == 1);
                break :blk 0;
            },
            .enum_literal => i: {
                const name = val.castTag(.enum_literal).?.data;
                break :i ty.enumFieldIndex(name).?;
            },
            // Assume it is already an integer and return it directly.
            else => return val,
        };

        switch (ty.tag()) {
            .enum_full, .enum_nonexhaustive => {
                const enum_full = ty.cast(Type.Payload.EnumFull).?.data;
                if (enum_full.values.count() != 0) {
                    return enum_full.values.keys()[field_index];
                } else {
                    // Field index and integer values are the same.
                    return mod.intValue(enum_full.tag_ty, field_index);
                }
            },
            .enum_numbered => {
                const enum_obj = ty.castTag(.enum_numbered).?.data;
                if (enum_obj.values.count() != 0) {
                    return enum_obj.values.keys()[field_index];
                } else {
                    // Field index and integer values are the same.
                    return mod.intValue(enum_obj.tag_ty, field_index);
                }
            },
            .enum_simple => {
                // Field index and integer values are the same.
                const tag_ty = ty.intTagType();
                return mod.intValue(tag_ty, field_index);
            },
            else => unreachable,
        }
    }

    pub fn tagName(val: Value, ty: Type, mod: *Module) []const u8 {
        if (ty.zigTypeTag(mod) == .Union) return val.unionTag().tagName(ty.unionTagTypeHypothetical(), mod);

        const field_index = switch (val.tag()) {
            .enum_field_index => val.castTag(.enum_field_index).?.data,
            .the_only_possible_value => blk: {
                assert(ty.enumFieldCount() == 1);
                break :blk 0;
            },
            .enum_literal => return val.castTag(.enum_literal).?.data,
            else => field_index: {
                const values = switch (ty.tag()) {
                    .enum_full, .enum_nonexhaustive => ty.cast(Type.Payload.EnumFull).?.data.values,
                    .enum_numbered => ty.castTag(.enum_numbered).?.data.values,
                    .enum_simple => Module.EnumFull.ValueMap{},
                    else => unreachable,
                };
                if (values.entries.len == 0) {
                    // auto-numbered enum
                    break :field_index @intCast(u32, val.toUnsignedInt(mod));
                }
                const int_tag_ty = ty.intTagType();
                break :field_index @intCast(u32, values.getIndexContext(val, .{ .ty = int_tag_ty, .mod = mod }).?);
            },
        };

        const fields = switch (ty.tag()) {
            .enum_full, .enum_nonexhaustive => ty.cast(Type.Payload.EnumFull).?.data.fields,
            .enum_numbered => ty.castTag(.enum_numbered).?.data.fields,
            .enum_simple => ty.castTag(.enum_simple).?.data.fields,
            else => unreachable,
        };
        return fields.keys()[field_index];
    }

    /// Asserts the value is an integer.
    pub fn toBigInt(val: Value, space: *BigIntSpace, mod: *const Module) BigIntConst {
        return val.toBigIntAdvanced(space, mod, null) catch unreachable;
    }

    /// Asserts the value is an integer.
    pub fn toBigIntAdvanced(
        val: Value,
        space: *BigIntSpace,
        mod: *const Module,
        opt_sema: ?*Sema,
    ) Module.CompileError!BigIntConst {
        return switch (val.ip_index) {
            .bool_false => BigIntMutable.init(&space.limbs, 0).toConst(),
            .bool_true => BigIntMutable.init(&space.limbs, 1).toConst(),
            .undef => unreachable,
            .null_value => BigIntMutable.init(&space.limbs, 0).toConst(),
            .none => switch (val.tag()) {
                .the_only_possible_value, // i0, u0
                => BigIntMutable.init(&space.limbs, 0).toConst(),

                .enum_field_index => {
                    const index = val.castTag(.enum_field_index).?.data;
                    return BigIntMutable.init(&space.limbs, index).toConst();
                },
                .runtime_value => {
                    const sub_val = val.castTag(.runtime_value).?.data;
                    return sub_val.toBigIntAdvanced(space, mod, opt_sema);
                },
                .lazy_align => {
                    const ty = val.castTag(.lazy_align).?.data;
                    if (opt_sema) |sema| {
                        try sema.resolveTypeLayout(ty);
                    }
                    const x = ty.abiAlignment(mod);
                    return BigIntMutable.init(&space.limbs, x).toConst();
                },
                .lazy_size => {
                    const ty = val.castTag(.lazy_size).?.data;
                    if (opt_sema) |sema| {
                        try sema.resolveTypeLayout(ty);
                    }
                    const x = ty.abiSize(mod);
                    return BigIntMutable.init(&space.limbs, x).toConst();
                },

                .elem_ptr => {
                    const elem_ptr = val.castTag(.elem_ptr).?.data;
                    const array_addr = (try elem_ptr.array_ptr.getUnsignedIntAdvanced(mod, opt_sema)).?;
                    const elem_size = elem_ptr.elem_ty.abiSize(mod);
                    const new_addr = array_addr + elem_size * elem_ptr.index;
                    return BigIntMutable.init(&space.limbs, new_addr).toConst();
                },

                else => unreachable,
            },
            else => switch (mod.intern_pool.indexToKey(val.ip_index)) {
                .int => |int| int.storage.toBigInt(space),
                else => unreachable,
            },
        };
    }

    /// If the value fits in a u64, return it, otherwise null.
    /// Asserts not undefined.
    pub fn getUnsignedInt(val: Value, mod: *const Module) ?u64 {
        return getUnsignedIntAdvanced(val, mod, null) catch unreachable;
    }

    /// If the value fits in a u64, return it, otherwise null.
    /// Asserts not undefined.
    pub fn getUnsignedIntAdvanced(val: Value, mod: *const Module, opt_sema: ?*Sema) !?u64 {
        switch (val.ip_index) {
            .bool_false => return 0,
            .bool_true => return 1,
            .undef => unreachable,
            .none => switch (val.tag()) {
                .the_only_possible_value, // i0, u0
                => return 0,

                .lazy_align => {
                    const ty = val.castTag(.lazy_align).?.data;
                    if (opt_sema) |sema| {
                        return (try ty.abiAlignmentAdvanced(mod, .{ .sema = sema })).scalar;
                    } else {
                        return ty.abiAlignment(mod);
                    }
                },
                .lazy_size => {
                    const ty = val.castTag(.lazy_size).?.data;
                    if (opt_sema) |sema| {
                        return (try ty.abiSizeAdvanced(mod, .{ .sema = sema })).scalar;
                    } else {
                        return ty.abiSize(mod);
                    }
                },

                else => return null,
            },
            else => return switch (mod.intern_pool.indexToKey(val.ip_index)) {
                .int => |int| switch (int.storage) {
                    .big_int => |big_int| big_int.to(u64) catch null,
                    .u64 => |x| x,
                    .i64 => |x| std.math.cast(u64, x),
                },
                else => null,
            },
        }
    }

    /// Asserts the value is an integer and it fits in a u64
    pub fn toUnsignedInt(val: Value, mod: *const Module) u64 {
        return getUnsignedInt(val, mod).?;
    }

    /// Asserts the value is an integer and it fits in a i64
    pub fn toSignedInt(val: Value, mod: *const Module) i64 {
        switch (val.ip_index) {
            .bool_false => return 0,
            .bool_true => return 1,
            .undef => unreachable,
            .none => switch (val.tag()) {
                .the_only_possible_value, // i0, u0
                => return 0,

                .lazy_align => {
                    const ty = val.castTag(.lazy_align).?.data;
                    return @intCast(i64, ty.abiAlignment(mod));
                },
                .lazy_size => {
                    const ty = val.castTag(.lazy_size).?.data;
                    return @intCast(i64, ty.abiSize(mod));
                },

                else => unreachable,
            },
            else => return switch (mod.intern_pool.indexToKey(val.ip_index)) {
                .int => |int| switch (int.storage) {
                    .big_int => |big_int| big_int.to(i64) catch unreachable,
                    .i64 => |x| x,
                    .u64 => |x| @intCast(i64, x),
                },
                else => unreachable,
            },
        }
    }

    pub fn toBool(val: Value, mod: *const Module) bool {
        return switch (val.ip_index) {
            .bool_true => true,
            .bool_false => false,
            .none => unreachable,
            else => switch (mod.intern_pool.indexToKey(val.ip_index)) {
                .int => |int| switch (int.storage) {
                    .big_int => |big_int| !big_int.eqZero(),
                    inline .u64, .i64 => |x| x != 0,
                },
                else => unreachable,
            },
        };
    }

    fn isDeclRef(val: Value) bool {
        var check = val;
        while (true) switch (check.tag()) {
            .variable, .decl_ref, .decl_ref_mut, .comptime_field_ptr => return true,
            .field_ptr => check = check.castTag(.field_ptr).?.data.container_ptr,
            .elem_ptr => check = check.castTag(.elem_ptr).?.data.array_ptr,
            .eu_payload_ptr, .opt_payload_ptr => check = check.cast(Value.Payload.PayloadPtr).?.data.container_ptr,
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
        if (val.isUndef()) {
            const size = @intCast(usize, ty.abiSize(mod));
            @memset(buffer[0..size], 0xaa);
            return;
        }
        switch (ty.zigTypeTag(mod)) {
            .Void => {},
            .Bool => {
                buffer[0] = @boolToInt(val.toBool(mod));
            },
            .Int, .Enum => {
                const int_info = ty.intInfo(mod);
                const bits = int_info.bits;
                const byte_count = (bits + 7) / 8;

                const int_val = try val.enumToInt(ty, mod);

                if (byte_count <= @sizeOf(u64)) {
                    const ip_key = mod.intern_pool.indexToKey(int_val.ip_index);
                    const int: u64 = switch (ip_key.int.storage) {
                        .u64 => |x| x,
                        .i64 => |x| @bitCast(u64, x),
                        .big_int => unreachable,
                    };
                    for (buffer[0..byte_count], 0..) |_, i| switch (endian) {
                        .Little => buffer[i] = @truncate(u8, (int >> @intCast(u6, (8 * i)))),
                        .Big => buffer[byte_count - i - 1] = @truncate(u8, (int >> @intCast(u6, (8 * i)))),
                    };
                } else {
                    var bigint_buffer: BigIntSpace = undefined;
                    const bigint = int_val.toBigInt(&bigint_buffer, mod);
                    bigint.writeTwosComplement(buffer[0..byte_count], endian);
                }
            },
            .Float => switch (ty.floatBits(target)) {
                16 => std.mem.writeInt(u16, buffer[0..2], @bitCast(u16, val.toFloat(f16, mod)), endian),
                32 => std.mem.writeInt(u32, buffer[0..4], @bitCast(u32, val.toFloat(f32, mod)), endian),
                64 => std.mem.writeInt(u64, buffer[0..8], @bitCast(u64, val.toFloat(f64, mod)), endian),
                80 => std.mem.writeInt(u80, buffer[0..10], @bitCast(u80, val.toFloat(f80, mod)), endian),
                128 => std.mem.writeInt(u128, buffer[0..16], @bitCast(u128, val.toFloat(f128, mod)), endian),
                else => unreachable,
            },
            .Array => {
                const len = ty.arrayLen(mod);
                const elem_ty = ty.childType(mod);
                const elem_size = @intCast(usize, elem_ty.abiSize(mod));
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
                const byte_count = (@intCast(usize, ty.bitSize(mod)) + 7) / 8;
                return writeToPackedMemory(val, ty, mod, buffer[0..byte_count], 0);
            },
            .Struct => switch (ty.containerLayout()) {
                .Auto => return error.IllDefinedMemoryLayout,
                .Extern => {
                    const fields = ty.structFields().values();
                    const field_vals = val.castTag(.aggregate).?.data;
                    for (fields, 0..) |field, i| {
                        const off = @intCast(usize, ty.structFieldOffset(i, mod));
                        try writeToMemory(field_vals[i], field.ty, mod, buffer[off..]);
                    }
                },
                .Packed => {
                    const byte_count = (@intCast(usize, ty.bitSize(mod)) + 7) / 8;
                    return writeToPackedMemory(val, ty, mod, buffer[0..byte_count], 0);
                },
            },
            .ErrorSet => {
                // TODO revisit this when we have the concept of the error tag type
                const Int = u16;
                const int = mod.global_error_set.get(val.castTag(.@"error").?.data.name).?;
                std.mem.writeInt(Int, buffer[0..@sizeOf(Int)], @intCast(Int, int), endian);
            },
            .Union => switch (ty.containerLayout()) {
                .Auto => return error.IllDefinedMemoryLayout,
                .Extern => return error.Unimplemented,
                .Packed => {
                    const byte_count = (@intCast(usize, ty.bitSize(mod)) + 7) / 8;
                    return writeToPackedMemory(val, ty, mod, buffer[0..byte_count], 0);
                },
            },
            .Pointer => {
                if (ty.isSlice(mod)) return error.IllDefinedMemoryLayout;
                if (val.isDeclRef()) return error.ReinterpretDeclRef;
                return val.writeToMemory(Type.usize, mod, buffer);
            },
            .Optional => {
                if (!ty.isPtrLikeOptional(mod)) return error.IllDefinedMemoryLayout;
                const child = ty.optionalChild(mod);
                const opt_val = val.optionalValue(mod);
                if (opt_val) |some| {
                    return some.writeToMemory(child, mod, buffer);
                } else {
                    return writeToMemory(Value.zero, Type.usize, mod, buffer);
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
        const target = mod.getTarget();
        const endian = target.cpu.arch.endian();
        if (val.isUndef()) {
            const bit_size = @intCast(usize, ty.bitSize(mod));
            std.mem.writeVarPackedInt(buffer, bit_offset, bit_size, @as(u1, 0), endian);
            return;
        }
        switch (ty.zigTypeTag(mod)) {
            .Void => {},
            .Bool => {
                const byte_index = switch (endian) {
                    .Little => bit_offset / 8,
                    .Big => buffer.len - bit_offset / 8 - 1,
                };
                if (val.toBool(mod)) {
                    buffer[byte_index] |= (@as(u8, 1) << @intCast(u3, bit_offset % 8));
                } else {
                    buffer[byte_index] &= ~(@as(u8, 1) << @intCast(u3, bit_offset % 8));
                }
            },
            .Int, .Enum => {
                const bits = ty.intInfo(mod).bits;
                const abi_size = @intCast(usize, ty.abiSize(mod));

                const int_val = try val.enumToInt(ty, mod);

                if (abi_size == 0) return;
                if (abi_size <= @sizeOf(u64)) {
                    const ip_key = mod.intern_pool.indexToKey(int_val.ip_index);
                    const int: u64 = switch (ip_key.int.storage) {
                        .u64 => |x| x,
                        .i64 => |x| @bitCast(u64, x),
                        else => unreachable,
                    };
                    std.mem.writeVarPackedInt(buffer, bit_offset, bits, int, endian);
                } else {
                    var bigint_buffer: BigIntSpace = undefined;
                    const bigint = int_val.toBigInt(&bigint_buffer, mod);
                    bigint.writePackedTwosComplement(buffer, bit_offset, bits, endian);
                }
            },
            .Float => switch (ty.floatBits(target)) {
                16 => std.mem.writePackedInt(u16, buffer, bit_offset, @bitCast(u16, val.toFloat(f16, mod)), endian),
                32 => std.mem.writePackedInt(u32, buffer, bit_offset, @bitCast(u32, val.toFloat(f32, mod)), endian),
                64 => std.mem.writePackedInt(u64, buffer, bit_offset, @bitCast(u64, val.toFloat(f64, mod)), endian),
                80 => std.mem.writePackedInt(u80, buffer, bit_offset, @bitCast(u80, val.toFloat(f80, mod)), endian),
                128 => std.mem.writePackedInt(u128, buffer, bit_offset, @bitCast(u128, val.toFloat(f128, mod)), endian),
                else => unreachable,
            },
            .Vector => {
                const elem_ty = ty.childType(mod);
                const elem_bit_size = @intCast(u16, elem_ty.bitSize(mod));
                const len = @intCast(usize, ty.arrayLen(mod));

                var bits: u16 = 0;
                var elem_i: usize = 0;
                while (elem_i < len) : (elem_i += 1) {
                    // On big-endian systems, LLVM reverses the element order of vectors by default
                    const tgt_elem_i = if (endian == .Big) len - elem_i - 1 else elem_i;
                    const elem_val = try val.elemValue(mod, tgt_elem_i);
                    try elem_val.writeToPackedMemory(elem_ty, mod, buffer, bit_offset + bits);
                    bits += elem_bit_size;
                }
            },
            .Struct => switch (ty.containerLayout()) {
                .Auto => unreachable, // Sema is supposed to have emitted a compile error already
                .Extern => unreachable, // Handled in non-packed writeToMemory
                .Packed => {
                    var bits: u16 = 0;
                    const fields = ty.structFields().values();
                    const field_vals = val.castTag(.aggregate).?.data;
                    for (fields, 0..) |field, i| {
                        const field_bits = @intCast(u16, field.ty.bitSize(mod));
                        try field_vals[i].writeToPackedMemory(field.ty, mod, buffer, bit_offset + bits);
                        bits += field_bits;
                    }
                },
            },
            .Union => switch (ty.containerLayout()) {
                .Auto => unreachable, // Sema is supposed to have emitted a compile error already
                .Extern => unreachable, // Handled in non-packed writeToMemory
                .Packed => {
                    const field_index = ty.unionTagFieldIndex(val.unionTag(), mod);
                    const field_type = ty.unionFields().values()[field_index.?].ty;
                    const field_val = val.fieldValue(field_type, mod, field_index.?);

                    return field_val.writeToPackedMemory(field_type, mod, buffer, bit_offset);
                },
            },
            .Pointer => {
                assert(!ty.isSlice(mod)); // No well defined layout.
                if (val.isDeclRef()) return error.ReinterpretDeclRef;
                return val.writeToPackedMemory(Type.usize, mod, buffer, bit_offset);
            },
            .Optional => {
                assert(ty.isPtrLikeOptional(mod));
                const child = ty.optionalChild(mod);
                const opt_val = val.optionalValue(mod);
                if (opt_val) |some| {
                    return some.writeToPackedMemory(child, mod, buffer, bit_offset);
                } else {
                    return writeToPackedMemory(Value.zero, Type.usize, mod, buffer, bit_offset);
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
    ) Allocator.Error!Value {
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
            .Int, .Enum => {
                const int_info = ty.intInfo(mod);
                const bits = int_info.bits;
                const byte_count = (bits + 7) / 8;
                if (bits == 0 or buffer.len == 0) return Value.zero;

                if (bits <= 64) switch (int_info.signedness) { // Fast path for integers <= u64
                    .signed => {
                        const val = std.mem.readVarInt(i64, buffer[0..byte_count], endian);
                        const result = (val << @intCast(u6, 64 - bits)) >> @intCast(u6, 64 - bits);
                        return mod.intValue(ty, result);
                    },
                    .unsigned => {
                        const val = std.mem.readVarInt(u64, buffer[0..byte_count], endian);
                        const result = (val << @intCast(u6, 64 - bits)) >> @intCast(u6, 64 - bits);
                        return mod.intValue(ty, result);
                    },
                } else { // Slow path, we have to construct a big-int
                    const Limb = std.math.big.Limb;
                    const limb_count = (byte_count + @sizeOf(Limb) - 1) / @sizeOf(Limb);
                    const limbs_buffer = try arena.alloc(Limb, limb_count);

                    var bigint = BigIntMutable.init(limbs_buffer, 0);
                    bigint.readTwosComplement(buffer[0..byte_count], bits, endian, int_info.signedness);
                    return mod.intValue_big(ty, bigint.toConst());
                }
            },
            .Float => switch (ty.floatBits(target)) {
                16 => return Value.Tag.float_16.create(arena, @bitCast(f16, std.mem.readInt(u16, buffer[0..2], endian))),
                32 => return Value.Tag.float_32.create(arena, @bitCast(f32, std.mem.readInt(u32, buffer[0..4], endian))),
                64 => return Value.Tag.float_64.create(arena, @bitCast(f64, std.mem.readInt(u64, buffer[0..8], endian))),
                80 => return Value.Tag.float_80.create(arena, @bitCast(f80, std.mem.readInt(u80, buffer[0..10], endian))),
                128 => return Value.Tag.float_128.create(arena, @bitCast(f128, std.mem.readInt(u128, buffer[0..16], endian))),
                else => unreachable,
            },
            .Array => {
                const elem_ty = ty.childType(mod);
                const elem_size = elem_ty.abiSize(mod);
                const elems = try arena.alloc(Value, @intCast(usize, ty.arrayLen(mod)));
                var offset: usize = 0;
                for (elems) |*elem| {
                    elem.* = try readFromMemory(elem_ty, mod, buffer[offset..], arena);
                    offset += @intCast(usize, elem_size);
                }
                return Tag.aggregate.create(arena, elems);
            },
            .Vector => {
                // We use byte_count instead of abi_size here, so that any padding bytes
                // follow the data bytes, on both big- and little-endian systems.
                const byte_count = (@intCast(usize, ty.bitSize(mod)) + 7) / 8;
                return readFromPackedMemory(ty, mod, buffer[0..byte_count], 0, arena);
            },
            .Struct => switch (ty.containerLayout()) {
                .Auto => unreachable, // Sema is supposed to have emitted a compile error already
                .Extern => {
                    const fields = ty.structFields().values();
                    const field_vals = try arena.alloc(Value, fields.len);
                    for (fields, 0..) |field, i| {
                        const off = @intCast(usize, ty.structFieldOffset(i, mod));
                        const sz = @intCast(usize, ty.structFieldType(i).abiSize(mod));
                        field_vals[i] = try readFromMemory(field.ty, mod, buffer[off..(off + sz)], arena);
                    }
                    return Tag.aggregate.create(arena, field_vals);
                },
                .Packed => {
                    const byte_count = (@intCast(usize, ty.bitSize(mod)) + 7) / 8;
                    return readFromPackedMemory(ty, mod, buffer[0..byte_count], 0, arena);
                },
            },
            .ErrorSet => {
                // TODO revisit this when we have the concept of the error tag type
                const Int = u16;
                const int = std.mem.readInt(Int, buffer[0..@sizeOf(Int)], endian);

                const payload = try arena.create(Value.Payload.Error);
                payload.* = .{
                    .base = .{ .tag = .@"error" },
                    .data = .{ .name = mod.error_name_list.items[@intCast(usize, int)] },
                };
                return Value.initPayload(&payload.base);
            },
            .Pointer => {
                assert(!ty.isSlice(mod)); // No well defined layout.
                return readFromMemory(Type.usize, mod, buffer, arena);
            },
            .Optional => {
                assert(ty.isPtrLikeOptional(mod));
                const child = ty.optionalChild(mod);
                return readFromMemory(child, mod, buffer, arena);
            },
            else => @panic("TODO implement readFromMemory for more types"),
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
    ) Allocator.Error!Value {
        const target = mod.getTarget();
        const endian = target.cpu.arch.endian();
        switch (ty.zigTypeTag(mod)) {
            .Void => return Value.void,
            .Bool => {
                const byte = switch (endian) {
                    .Big => buffer[buffer.len - bit_offset / 8 - 1],
                    .Little => buffer[bit_offset / 8],
                };
                if (((byte >> @intCast(u3, bit_offset % 8)) & 1) == 0) {
                    return Value.false;
                } else {
                    return Value.true;
                }
            },
            .Int, .Enum => {
                if (buffer.len == 0) return Value.zero;
                const int_info = ty.intInfo(mod);
                const abi_size = @intCast(usize, ty.abiSize(mod));

                const bits = int_info.bits;
                if (bits == 0) return Value.zero;
                if (bits <= 64) switch (int_info.signedness) { // Fast path for integers <= u64
                    .signed => return mod.intValue(ty, std.mem.readVarPackedInt(i64, buffer, bit_offset, bits, endian, .signed)),
                    .unsigned => return mod.intValue(ty, std.mem.readVarPackedInt(u64, buffer, bit_offset, bits, endian, .unsigned)),
                } else { // Slow path, we have to construct a big-int
                    const Limb = std.math.big.Limb;
                    const limb_count = (abi_size + @sizeOf(Limb) - 1) / @sizeOf(Limb);
                    const limbs_buffer = try arena.alloc(Limb, limb_count);

                    var bigint = BigIntMutable.init(limbs_buffer, 0);
                    bigint.readPackedTwosComplement(buffer, bit_offset, bits, endian, int_info.signedness);
                    return mod.intValue_big(ty, bigint.toConst());
                }
            },
            .Float => switch (ty.floatBits(target)) {
                16 => return Value.Tag.float_16.create(arena, @bitCast(f16, std.mem.readPackedInt(u16, buffer, bit_offset, endian))),
                32 => return Value.Tag.float_32.create(arena, @bitCast(f32, std.mem.readPackedInt(u32, buffer, bit_offset, endian))),
                64 => return Value.Tag.float_64.create(arena, @bitCast(f64, std.mem.readPackedInt(u64, buffer, bit_offset, endian))),
                80 => return Value.Tag.float_80.create(arena, @bitCast(f80, std.mem.readPackedInt(u80, buffer, bit_offset, endian))),
                128 => return Value.Tag.float_128.create(arena, @bitCast(f128, std.mem.readPackedInt(u128, buffer, bit_offset, endian))),
                else => unreachable,
            },
            .Vector => {
                const elem_ty = ty.childType(mod);
                const elems = try arena.alloc(Value, @intCast(usize, ty.arrayLen(mod)));

                var bits: u16 = 0;
                const elem_bit_size = @intCast(u16, elem_ty.bitSize(mod));
                for (elems, 0..) |_, i| {
                    // On big-endian systems, LLVM reverses the element order of vectors by default
                    const tgt_elem_i = if (endian == .Big) elems.len - i - 1 else i;
                    elems[tgt_elem_i] = try readFromPackedMemory(elem_ty, mod, buffer, bit_offset + bits, arena);
                    bits += elem_bit_size;
                }
                return Tag.aggregate.create(arena, elems);
            },
            .Struct => switch (ty.containerLayout()) {
                .Auto => unreachable, // Sema is supposed to have emitted a compile error already
                .Extern => unreachable, // Handled by non-packed readFromMemory
                .Packed => {
                    var bits: u16 = 0;
                    const fields = ty.structFields().values();
                    const field_vals = try arena.alloc(Value, fields.len);
                    for (fields, 0..) |field, i| {
                        const field_bits = @intCast(u16, field.ty.bitSize(mod));
                        field_vals[i] = try readFromPackedMemory(field.ty, mod, buffer, bit_offset + bits, arena);
                        bits += field_bits;
                    }
                    return Tag.aggregate.create(arena, field_vals);
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
    pub fn toFloat(val: Value, comptime T: type, mod: *const Module) T {
        return switch (val.ip_index) {
            .none => switch (val.tag()) {
                .float_16 => @floatCast(T, val.castTag(.float_16).?.data),
                .float_32 => @floatCast(T, val.castTag(.float_32).?.data),
                .float_64 => @floatCast(T, val.castTag(.float_64).?.data),
                .float_80 => @floatCast(T, val.castTag(.float_80).?.data),
                .float_128 => @floatCast(T, val.castTag(.float_128).?.data),

                else => unreachable,
            },
            else => switch (mod.intern_pool.indexToKey(val.ip_index)) {
                .int => |int| switch (int.storage) {
                    .big_int => |big_int| @floatCast(T, bigIntToFloat(big_int.limbs, big_int.positive)),
                    inline .u64, .i64 => |x| {
                        if (T == f80) {
                            @panic("TODO we can't lower this properly on non-x86 llvm backend yet");
                        }
                        return @intToFloat(T, x);
                    },
                },
                else => unreachable,
            },
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
            const limb: f128 = @intToFloat(f128, limbs[i]);
            result = @mulAdd(f128, base, result, limb);
        }
        if (positive) {
            return result;
        } else {
            return -result;
        }
    }

    pub fn clz(val: Value, ty: Type, mod: *const Module) u64 {
        const ty_bits = ty.intInfo(mod).bits;
        return switch (val.ip_index) {
            .bool_false => ty_bits,
            .bool_true => ty_bits - 1,
            .none => switch (val.tag()) {
                .the_only_possible_value => {
                    assert(ty_bits == 0);
                    return ty_bits;
                },

                .lazy_align, .lazy_size => {
                    var bigint_buf: BigIntSpace = undefined;
                    const bigint = val.toBigIntAdvanced(&bigint_buf, mod, null) catch unreachable;
                    return bigint.clz(ty_bits);
                },

                else => unreachable,
            },
            else => switch (mod.intern_pool.indexToKey(val.ip_index)) {
                .int => |int| switch (int.storage) {
                    .big_int => |big_int| big_int.clz(ty_bits),
                    .u64 => |x| @clz(x) + ty_bits - 64,
                    .i64 => @panic("TODO implement i64 Value clz"),
                },
                else => unreachable,
            },
        };
    }

    pub fn ctz(val: Value, ty: Type, mod: *const Module) u64 {
        const ty_bits = ty.intInfo(mod).bits;
        return switch (val.ip_index) {
            .bool_false => ty_bits,
            .bool_true => 0,
            .none => switch (val.tag()) {
                .the_only_possible_value => {
                    assert(ty_bits == 0);
                    return ty_bits;
                },

                .lazy_align, .lazy_size => {
                    var bigint_buf: BigIntSpace = undefined;
                    const bigint = val.toBigIntAdvanced(&bigint_buf, mod, null) catch unreachable;
                    return bigint.ctz();
                },

                else => unreachable,
            },
            else => switch (mod.intern_pool.indexToKey(val.ip_index)) {
                .int => |int| switch (int.storage) {
                    .big_int => |big_int| big_int.ctz(),
                    .u64 => |x| {
                        const big = @ctz(x);
                        return if (big == 64) ty_bits else big;
                    },
                    .i64 => @panic("TODO implement i64 Value ctz"),
                },
                else => unreachable,
            },
        };
    }

    pub fn popCount(val: Value, ty: Type, mod: *const Module) u64 {
        assert(!val.isUndef());
        switch (val.ip_index) {
            .bool_false => return 0,
            .bool_true => return 1,
            .none => unreachable,
            else => switch (mod.intern_pool.indexToKey(val.ip_index)) {
                .int => |int| {
                    const info = ty.intInfo(mod);
                    var buffer: Value.BigIntSpace = undefined;
                    const big_int = int.storage.toBigInt(&buffer);
                    return @intCast(u64, big_int.popCount(info.bits));
                },
                else => unreachable,
            },
        }
    }

    pub fn bitReverse(val: Value, ty: Type, mod: *Module, arena: Allocator) !Value {
        assert(!val.isUndef());

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
        assert(!val.isUndef());

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
    pub fn intBitCountTwosComp(self: Value, mod: *const Module) usize {
        const target = mod.getTarget();
        return switch (self.ip_index) {
            .bool_false => 0,
            .bool_true => 1,
            .none => switch (self.tag()) {
                .the_only_possible_value => 0,

                .decl_ref_mut,
                .comptime_field_ptr,
                .extern_fn,
                .decl_ref,
                .function,
                .variable,
                .eu_payload_ptr,
                .opt_payload_ptr,
                => target.ptrBitWidth(),

                else => {
                    var buffer: BigIntSpace = undefined;
                    return self.toBigInt(&buffer, mod).bitCountTwosComp();
                },
            },
            else => switch (mod.intern_pool.indexToKey(self.ip_index)) {
                .int => |int| switch (int.storage) {
                    .big_int => |big_int| big_int.bitCountTwosComp(),
                    .u64 => |x| if (x == 0) 0 else @intCast(usize, std.math.log2(x) + 1),
                    .i64 => {
                        var buffer: Value.BigIntSpace = undefined;
                        const big_int = int.storage.toBigInt(&buffer);
                        return big_int.bitCountTwosComp();
                    },
                },
                else => unreachable,
            },
        };
    }

    /// Converts an integer or a float to a float. May result in a loss of information.
    /// Caller can find out by equality checking the result against the operand.
    pub fn floatCast(self: Value, arena: Allocator, dest_ty: Type, mod: *const Module) !Value {
        const target = mod.getTarget();
        switch (dest_ty.floatBits(target)) {
            16 => return Value.Tag.float_16.create(arena, self.toFloat(f16, mod)),
            32 => return Value.Tag.float_32.create(arena, self.toFloat(f32, mod)),
            64 => return Value.Tag.float_64.create(arena, self.toFloat(f64, mod)),
            80 => return Value.Tag.float_80.create(arena, self.toFloat(f80, mod)),
            128 => return Value.Tag.float_128.create(arena, self.toFloat(f128, mod)),
            else => unreachable,
        }
    }

    /// Asserts the value is a float
    pub fn floatHasFraction(self: Value) bool {
        return switch (self.tag()) {
            .float_16 => @rem(self.castTag(.float_16).?.data, 1) != 0,
            .float_32 => @rem(self.castTag(.float_32).?.data, 1) != 0,
            .float_64 => @rem(self.castTag(.float_64).?.data, 1) != 0,
            //.float_80 => @rem(self.castTag(.float_80).?.data, 1) != 0,
            .float_80 => @panic("TODO implement __remx in compiler-rt"),
            .float_128 => @rem(self.castTag(.float_128).?.data, 1) != 0,

            else => unreachable,
        };
    }

    pub fn orderAgainstZero(lhs: Value, mod: *const Module) std.math.Order {
        return orderAgainstZeroAdvanced(lhs, mod, null) catch unreachable;
    }

    pub fn orderAgainstZeroAdvanced(
        lhs: Value,
        mod: *const Module,
        opt_sema: ?*Sema,
    ) Module.CompileError!std.math.Order {
        switch (lhs.ip_index) {
            .bool_false => return .eq,
            .bool_true => return .gt,
            .none => return switch (lhs.tag()) {
                .the_only_possible_value => .eq,

                .decl_ref,
                .decl_ref_mut,
                .comptime_field_ptr,
                .extern_fn,
                .function,
                .variable,
                => .gt,

                .enum_field_index => return std.math.order(lhs.castTag(.enum_field_index).?.data, 0),
                .runtime_value => {
                    // This is needed to correctly handle hashing the value.
                    // Checks in Sema should prevent direct comparisons from reaching here.
                    const val = lhs.castTag(.runtime_value).?.data;
                    return val.orderAgainstZeroAdvanced(mod, opt_sema);
                },

                .lazy_align => {
                    const ty = lhs.castTag(.lazy_align).?.data;
                    const strat: Type.AbiAlignmentAdvancedStrat = if (opt_sema) |sema| .{ .sema = sema } else .eager;
                    if (ty.hasRuntimeBitsAdvanced(mod, false, strat) catch |err| switch (err) {
                        error.NeedLazy => unreachable,
                        else => |e| return e,
                    }) {
                        return .gt;
                    } else {
                        return .eq;
                    }
                },
                .lazy_size => {
                    const ty = lhs.castTag(.lazy_size).?.data;
                    const strat: Type.AbiAlignmentAdvancedStrat = if (opt_sema) |sema| .{ .sema = sema } else .eager;
                    if (ty.hasRuntimeBitsAdvanced(mod, false, strat) catch |err| switch (err) {
                        error.NeedLazy => unreachable,
                        else => |e| return e,
                    }) {
                        return .gt;
                    } else {
                        return .eq;
                    }
                },

                .float_16 => std.math.order(lhs.castTag(.float_16).?.data, 0),
                .float_32 => std.math.order(lhs.castTag(.float_32).?.data, 0),
                .float_64 => std.math.order(lhs.castTag(.float_64).?.data, 0),
                .float_80 => std.math.order(lhs.castTag(.float_80).?.data, 0),
                .float_128 => std.math.order(lhs.castTag(.float_128).?.data, 0),

                .elem_ptr => {
                    const elem_ptr = lhs.castTag(.elem_ptr).?.data;
                    switch (try elem_ptr.array_ptr.orderAgainstZeroAdvanced(mod, opt_sema)) {
                        .lt => unreachable,
                        .gt => return .gt,
                        .eq => {
                            if (elem_ptr.index == 0) {
                                return .eq;
                            } else {
                                return .gt;
                            }
                        },
                    }
                },

                else => unreachable,
            },
            else => return switch (mod.intern_pool.indexToKey(lhs.ip_index)) {
                .int => |int| switch (int.storage) {
                    .big_int => |big_int| big_int.orderAgainstScalar(0),
                    inline .u64, .i64 => |x| std.math.order(x, 0),
                },
                else => unreachable,
            },
        }
    }

    /// Asserts the value is comparable.
    pub fn order(lhs: Value, rhs: Value, mod: *const Module) std.math.Order {
        return orderAdvanced(lhs, rhs, mod, null) catch unreachable;
    }

    /// Asserts the value is comparable.
    /// If opt_sema is null then this function asserts things are resolved and cannot fail.
    pub fn orderAdvanced(lhs: Value, rhs: Value, mod: *const Module, opt_sema: ?*Sema) !std.math.Order {
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

        const lhs_float = lhs.isFloat();
        const rhs_float = rhs.isFloat();
        if (lhs_float and rhs_float) {
            const lhs_tag = lhs.tag();
            const rhs_tag = rhs.tag();
            if (lhs_tag == rhs_tag) {
                return switch (lhs.tag()) {
                    .float_16 => return std.math.order(lhs.castTag(.float_16).?.data, rhs.castTag(.float_16).?.data),
                    .float_32 => return std.math.order(lhs.castTag(.float_32).?.data, rhs.castTag(.float_32).?.data),
                    .float_64 => return std.math.order(lhs.castTag(.float_64).?.data, rhs.castTag(.float_64).?.data),
                    .float_80 => return std.math.order(lhs.castTag(.float_80).?.data, rhs.castTag(.float_80).?.data),
                    .float_128 => return std.math.order(lhs.castTag(.float_128).?.data, rhs.castTag(.float_128).?.data),
                    else => unreachable,
                };
            }
        }
        if (lhs_float or rhs_float) {
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
    pub fn compareHetero(lhs: Value, op: std.math.CompareOperator, rhs: Value, mod: *const Module) bool {
        return compareHeteroAdvanced(lhs, op, rhs, mod, null) catch unreachable;
    }

    pub fn compareHeteroAdvanced(
        lhs: Value,
        op: std.math.CompareOperator,
        rhs: Value,
        mod: *const Module,
        opt_sema: ?*Sema,
    ) !bool {
        if (lhs.pointerDecl()) |lhs_decl| {
            if (rhs.pointerDecl()) |rhs_decl| {
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
        } else if (rhs.pointerDecl()) |_| {
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
        if (lhs.isInf()) {
            switch (op) {
                .neq => return true,
                .eq => return false,
                .gt, .gte => return !lhs.isNegativeInf(),
                .lt, .lte => return lhs.isNegativeInf(),
            }
        }

        switch (lhs.ip_index) {
            .none => switch (lhs.tag()) {
                .repeated => return lhs.castTag(.repeated).?.data.compareAllWithZeroAdvancedExtra(op, mod, opt_sema),
                .aggregate => {
                    for (lhs.castTag(.aggregate).?.data) |elem_val| {
                        if (!(try elem_val.compareAllWithZeroAdvancedExtra(op, mod, opt_sema))) return false;
                    }
                    return true;
                },
                .str_lit => {
                    const str_lit = lhs.castTag(.str_lit).?.data;
                    const bytes = mod.string_literal_bytes.items[str_lit.index..][0..str_lit.len];
                    for (bytes) |byte| {
                        if (!std.math.compare(byte, op, 0)) return false;
                    }
                    return true;
                },
                .bytes => {
                    const bytes = lhs.castTag(.bytes).?.data;
                    for (bytes) |byte| {
                        if (!std.math.compare(byte, op, 0)) return false;
                    }
                    return true;
                },
                .float_16 => if (std.math.isNan(lhs.castTag(.float_16).?.data)) return op == .neq,
                .float_32 => if (std.math.isNan(lhs.castTag(.float_32).?.data)) return op == .neq,
                .float_64 => if (std.math.isNan(lhs.castTag(.float_64).?.data)) return op == .neq,
                .float_80 => if (std.math.isNan(lhs.castTag(.float_80).?.data)) return op == .neq,
                .float_128 => if (std.math.isNan(lhs.castTag(.float_128).?.data)) return op == .neq,
                else => {},
            },
            else => {},
        }
        return (try orderAgainstZeroAdvanced(lhs, mod, opt_sema)).compare(op);
    }

    pub fn eql(a: Value, b: Value, ty: Type, mod: *Module) bool {
        return eqlAdvanced(a, ty, b, ty, mod, null) catch unreachable;
    }

    /// This function is used by hash maps and so treats floating-point NaNs as equal
    /// to each other, and not equal to other floating-point values.
    /// Similarly, it treats `undef` as a distinct value from all other values.
    /// This function has to be able to support implicit coercion of `a` to `ty`. That is,
    /// `ty` will be an exactly correct Type for `b` but it may be a post-coerced Type
    /// for `a`. This function must act *as if* `a` has been coerced to `ty`. This complication
    /// is required in order to make generic function instantiation efficient - specifically
    /// the insertion into the monomorphized function table.
    /// If `null` is provided for `opt_sema` then it is guaranteed no error will be returned.
    pub fn eqlAdvanced(
        a: Value,
        a_ty: Type,
        b: Value,
        ty: Type,
        mod: *Module,
        opt_sema: ?*Sema,
    ) Module.CompileError!bool {
        if (a.ip_index != .none or b.ip_index != .none) return a.ip_index == b.ip_index;

        const target = mod.getTarget();
        const a_tag = a.tag();
        const b_tag = b.tag();
        if (a_tag == b_tag) switch (a_tag) {
            .the_only_possible_value, .empty_struct_value => return true,
            .enum_literal => {
                const a_name = a.castTag(.enum_literal).?.data;
                const b_name = b.castTag(.enum_literal).?.data;
                return std.mem.eql(u8, a_name, b_name);
            },
            .enum_field_index => {
                const a_field_index = a.castTag(.enum_field_index).?.data;
                const b_field_index = b.castTag(.enum_field_index).?.data;
                return a_field_index == b_field_index;
            },
            .opt_payload => {
                const a_payload = a.castTag(.opt_payload).?.data;
                const b_payload = b.castTag(.opt_payload).?.data;
                const payload_ty = ty.optionalChild(mod);
                return eqlAdvanced(a_payload, payload_ty, b_payload, payload_ty, mod, opt_sema);
            },
            .slice => {
                const a_payload = a.castTag(.slice).?.data;
                const b_payload = b.castTag(.slice).?.data;
                if (!(try eqlAdvanced(a_payload.len, Type.usize, b_payload.len, Type.usize, mod, opt_sema))) {
                    return false;
                }

                var ptr_buf: Type.SlicePtrFieldTypeBuffer = undefined;
                const ptr_ty = ty.slicePtrFieldType(&ptr_buf, mod);

                return eqlAdvanced(a_payload.ptr, ptr_ty, b_payload.ptr, ptr_ty, mod, opt_sema);
            },
            .elem_ptr => {
                const a_payload = a.castTag(.elem_ptr).?.data;
                const b_payload = b.castTag(.elem_ptr).?.data;
                if (a_payload.index != b_payload.index) return false;

                return eqlAdvanced(a_payload.array_ptr, ty, b_payload.array_ptr, ty, mod, opt_sema);
            },
            .field_ptr => {
                const a_payload = a.castTag(.field_ptr).?.data;
                const b_payload = b.castTag(.field_ptr).?.data;
                if (a_payload.field_index != b_payload.field_index) return false;

                return eqlAdvanced(a_payload.container_ptr, ty, b_payload.container_ptr, ty, mod, opt_sema);
            },
            .@"error" => {
                const a_name = a.castTag(.@"error").?.data.name;
                const b_name = b.castTag(.@"error").?.data.name;
                return std.mem.eql(u8, a_name, b_name);
            },
            .eu_payload => {
                const a_payload = a.castTag(.eu_payload).?.data;
                const b_payload = b.castTag(.eu_payload).?.data;
                const payload_ty = ty.errorUnionPayload();
                return eqlAdvanced(a_payload, payload_ty, b_payload, payload_ty, mod, opt_sema);
            },
            .eu_payload_ptr => {
                const a_payload = a.castTag(.eu_payload_ptr).?.data;
                const b_payload = b.castTag(.eu_payload_ptr).?.data;
                return eqlAdvanced(a_payload.container_ptr, ty, b_payload.container_ptr, ty, mod, opt_sema);
            },
            .opt_payload_ptr => {
                const a_payload = a.castTag(.opt_payload_ptr).?.data;
                const b_payload = b.castTag(.opt_payload_ptr).?.data;
                return eqlAdvanced(a_payload.container_ptr, ty, b_payload.container_ptr, ty, mod, opt_sema);
            },
            .function => {
                const a_payload = a.castTag(.function).?.data;
                const b_payload = b.castTag(.function).?.data;
                return a_payload == b_payload;
            },
            .aggregate => {
                const a_field_vals = a.castTag(.aggregate).?.data;
                const b_field_vals = b.castTag(.aggregate).?.data;
                assert(a_field_vals.len == b_field_vals.len);

                if (ty.isSimpleTupleOrAnonStruct()) {
                    const types = ty.tupleFields().types;
                    assert(types.len == a_field_vals.len);
                    for (types, 0..) |field_ty, i| {
                        if (!(try eqlAdvanced(a_field_vals[i], field_ty, b_field_vals[i], field_ty, mod, opt_sema))) {
                            return false;
                        }
                    }
                    return true;
                }

                if (ty.zigTypeTag(mod) == .Struct) {
                    const fields = ty.structFields().values();
                    assert(fields.len == a_field_vals.len);
                    for (fields, 0..) |field, i| {
                        if (!(try eqlAdvanced(a_field_vals[i], field.ty, b_field_vals[i], field.ty, mod, opt_sema))) {
                            return false;
                        }
                    }
                    return true;
                }

                const elem_ty = ty.childType(mod);
                for (a_field_vals, 0..) |a_elem, i| {
                    const b_elem = b_field_vals[i];

                    if (!(try eqlAdvanced(a_elem, elem_ty, b_elem, elem_ty, mod, opt_sema))) {
                        return false;
                    }
                }
                return true;
            },
            .@"union" => {
                const a_union = a.castTag(.@"union").?.data;
                const b_union = b.castTag(.@"union").?.data;
                switch (ty.containerLayout()) {
                    .Packed, .Extern => {
                        const tag_ty = ty.unionTagTypeHypothetical();
                        if (!(try eqlAdvanced(a_union.tag, tag_ty, b_union.tag, tag_ty, mod, opt_sema))) {
                            // In this case, we must disregard mismatching tags and compare
                            // based on the in-memory bytes of the payloads.
                            @panic("TODO comptime comparison of extern union values with mismatching tags");
                        }
                    },
                    .Auto => {
                        const tag_ty = ty.unionTagTypeHypothetical();
                        if (!(try eqlAdvanced(a_union.tag, tag_ty, b_union.tag, tag_ty, mod, opt_sema))) {
                            return false;
                        }
                    },
                }
                const active_field_ty = ty.unionFieldType(a_union.tag, mod);
                return eqlAdvanced(a_union.val, active_field_ty, b_union.val, active_field_ty, mod, opt_sema);
            },
            else => {},
        } else if (b_tag == .@"error") {
            return false;
        }

        if (a.pointerDecl()) |a_decl| {
            if (b.pointerDecl()) |b_decl| {
                return a_decl == b_decl;
            } else {
                return false;
            }
        } else if (b.pointerDecl()) |_| {
            return false;
        }

        switch (ty.zigTypeTag(mod)) {
            .Type => {
                const a_type = a.toType();
                const b_type = b.toType();
                return a_type.eql(b_type, mod);
            },
            .Enum => {
                const a_val = try a.enumToInt(ty, mod);
                const b_val = try b.enumToInt(ty, mod);
                const int_ty = ty.intTagType();
                return eqlAdvanced(a_val, int_ty, b_val, int_ty, mod, opt_sema);
            },
            .Array, .Vector => {
                const len = ty.arrayLen(mod);
                const elem_ty = ty.childType(mod);
                var i: usize = 0;
                while (i < len) : (i += 1) {
                    const a_elem = try elemValue(a, mod, i);
                    const b_elem = try elemValue(b, mod, i);
                    if (!(try eqlAdvanced(a_elem, elem_ty, b_elem, elem_ty, mod, opt_sema))) {
                        return false;
                    }
                }
                return true;
            },
            .Pointer => switch (ty.ptrSize(mod)) {
                .Slice => {
                    const a_len = switch (a_ty.ptrSize(mod)) {
                        .Slice => a.sliceLen(mod),
                        .One => a_ty.childType(mod).arrayLen(mod),
                        else => unreachable,
                    };
                    if (a_len != b.sliceLen(mod)) {
                        return false;
                    }

                    var ptr_buf: Type.SlicePtrFieldTypeBuffer = undefined;
                    const ptr_ty = ty.slicePtrFieldType(&ptr_buf, mod);
                    const a_ptr = switch (a_ty.ptrSize(mod)) {
                        .Slice => a.slicePtr(),
                        .One => a,
                        else => unreachable,
                    };
                    return try eqlAdvanced(a_ptr, ptr_ty, b.slicePtr(), ptr_ty, mod, opt_sema);
                },
                .Many, .C, .One => {},
            },
            .Struct => {
                // A struct can be represented with one of:
                //   .empty_struct_value,
                //   .the_one_possible_value,
                //   .aggregate,
                // Note that we already checked above for matching tags, e.g. both .aggregate.
                return ty.onePossibleValue(mod) != null;
            },
            .Union => {
                // Here we have to check for value equality, as-if `a` has been coerced to `ty`.
                if (ty.onePossibleValue(mod) != null) {
                    return true;
                }
                if (a_ty.castTag(.anon_struct)) |payload| {
                    const tuple = payload.data;
                    if (tuple.values.len != 1) {
                        return false;
                    }
                    const field_name = tuple.names[0];
                    const union_obj = ty.cast(Type.Payload.Union).?.data;
                    const field_index = union_obj.fields.getIndex(field_name) orelse return false;
                    const tag_and_val = b.castTag(.@"union").?.data;
                    var field_tag_buf: Value.Payload.U32 = .{
                        .base = .{ .tag = .enum_field_index },
                        .data = @intCast(u32, field_index),
                    };
                    const field_tag = Value.initPayload(&field_tag_buf.base);
                    const tag_matches = tag_and_val.tag.eql(field_tag, union_obj.tag_ty, mod);
                    if (!tag_matches) return false;
                    return eqlAdvanced(tag_and_val.val, union_obj.tag_ty, tuple.values[0], tuple.types[0], mod, opt_sema);
                }
                return false;
            },
            .Float => {
                switch (ty.floatBits(target)) {
                    16 => return @bitCast(u16, a.toFloat(f16, mod)) == @bitCast(u16, b.toFloat(f16, mod)),
                    32 => return @bitCast(u32, a.toFloat(f32, mod)) == @bitCast(u32, b.toFloat(f32, mod)),
                    64 => return @bitCast(u64, a.toFloat(f64, mod)) == @bitCast(u64, b.toFloat(f64, mod)),
                    80 => return @bitCast(u80, a.toFloat(f80, mod)) == @bitCast(u80, b.toFloat(f80, mod)),
                    128 => return @bitCast(u128, a.toFloat(f128, mod)) == @bitCast(u128, b.toFloat(f128, mod)),
                    else => unreachable,
                }
            },
            .ComptimeFloat => {
                const a_float = a.toFloat(f128, mod);
                const b_float = b.toFloat(f128, mod);

                const a_nan = std.math.isNan(a_float);
                const b_nan = std.math.isNan(b_float);
                if (a_nan != b_nan) return false;
                if (std.math.signbit(a_float) != std.math.signbit(b_float)) return false;
                if (a_nan) return true;
                return a_float == b_float;
            },
            .Optional => if (b_tag == .opt_payload) {
                var sub_pl: Payload.SubValue = .{
                    .base = .{ .tag = b.tag() },
                    .data = a,
                };
                const sub_val = Value.initPayload(&sub_pl.base);
                return eqlAdvanced(sub_val, ty, b, ty, mod, opt_sema);
            },
            .ErrorUnion => if (a_tag != .@"error" and b_tag == .eu_payload) {
                var sub_pl: Payload.SubValue = .{
                    .base = .{ .tag = b.tag() },
                    .data = a,
                };
                const sub_val = Value.initPayload(&sub_pl.base);
                return eqlAdvanced(sub_val, ty, b, ty, mod, opt_sema);
            },
            else => {},
        }
        if (a_tag == .@"error") return false;
        return (try orderAdvanced(a, b, mod, opt_sema)).compare(.eq);
    }

    /// This function is used by hash maps and so treats floating-point NaNs as equal
    /// to each other, and not equal to other floating-point values.
    pub fn hash(val: Value, ty: Type, hasher: *std.hash.Wyhash, mod: *Module) void {
        if (val.ip_index != .none) {
            // The InternPool data structure hashes based on Key to make interned objects
            // unique. An Index can be treated simply as u32 value for the
            // purpose of Type/Value hashing and equality.
            std.hash.autoHash(hasher, val.ip_index);
            return;
        }
        const zig_ty_tag = ty.zigTypeTag(mod);
        std.hash.autoHash(hasher, zig_ty_tag);
        if (val.isUndef()) return;
        // The value is runtime-known and shouldn't affect the hash.
        if (val.tag() == .runtime_value) return;

        switch (zig_ty_tag) {
            .Opaque => unreachable, // Cannot hash opaque types

            .Void,
            .NoReturn,
            .Undefined,
            .Null,
            => {},

            .Type => {
                return val.toType().hashWithHasher(hasher, mod);
            },
            .Float => {
                // For hash/eql purposes, we treat floats as their IEEE integer representation.
                switch (ty.floatBits(mod.getTarget())) {
                    16 => std.hash.autoHash(hasher, @bitCast(u16, val.toFloat(f16, mod))),
                    32 => std.hash.autoHash(hasher, @bitCast(u32, val.toFloat(f32, mod))),
                    64 => std.hash.autoHash(hasher, @bitCast(u64, val.toFloat(f64, mod))),
                    80 => std.hash.autoHash(hasher, @bitCast(u80, val.toFloat(f80, mod))),
                    128 => std.hash.autoHash(hasher, @bitCast(u128, val.toFloat(f128, mod))),
                    else => unreachable,
                }
            },
            .ComptimeFloat => {
                const float = val.toFloat(f128, mod);
                const is_nan = std.math.isNan(float);
                std.hash.autoHash(hasher, is_nan);
                if (!is_nan) {
                    std.hash.autoHash(hasher, @bitCast(u128, float));
                } else {
                    std.hash.autoHash(hasher, std.math.signbit(float));
                }
            },
            .Bool, .Int, .ComptimeInt, .Pointer => switch (val.tag()) {
                .slice => {
                    const slice = val.castTag(.slice).?.data;
                    var ptr_buf: Type.SlicePtrFieldTypeBuffer = undefined;
                    const ptr_ty = ty.slicePtrFieldType(&ptr_buf, mod);
                    hash(slice.ptr, ptr_ty, hasher, mod);
                    hash(slice.len, Type.usize, hasher, mod);
                },

                else => return hashPtr(val, hasher, mod),
            },
            .Array, .Vector => {
                const len = ty.arrayLen(mod);
                const elem_ty = ty.childType(mod);
                var index: usize = 0;
                while (index < len) : (index += 1) {
                    const elem_val = val.elemValue(mod, index) catch |err| switch (err) {
                        // Will be solved when arrays and vectors get migrated to the intern pool.
                        error.OutOfMemory => @panic("OOM"),
                    };
                    elem_val.hash(elem_ty, hasher, mod);
                }
            },
            .Struct => {
                switch (val.tag()) {
                    .empty_struct_value => {},
                    .aggregate => {
                        const field_values = val.castTag(.aggregate).?.data;
                        for (field_values, 0..) |field_val, i| {
                            const field_ty = ty.structFieldType(i);
                            field_val.hash(field_ty, hasher, mod);
                        }
                    },
                    else => unreachable,
                }
            },
            .Optional => {
                if (val.castTag(.opt_payload)) |payload| {
                    std.hash.autoHash(hasher, true); // non-null
                    const sub_val = payload.data;
                    const sub_ty = ty.optionalChild(mod);
                    sub_val.hash(sub_ty, hasher, mod);
                } else {
                    std.hash.autoHash(hasher, false); // null
                }
            },
            .ErrorUnion => {
                if (val.tag() == .@"error") {
                    std.hash.autoHash(hasher, false); // error
                    const sub_ty = ty.errorUnionSet();
                    val.hash(sub_ty, hasher, mod);
                    return;
                }

                if (val.castTag(.eu_payload)) |payload| {
                    std.hash.autoHash(hasher, true); // payload
                    const sub_ty = ty.errorUnionPayload();
                    payload.data.hash(sub_ty, hasher, mod);
                    return;
                } else unreachable;
            },
            .ErrorSet => {
                // just hash the literal error value. this is the most stable
                // thing between compiler invocations. we can't use the error
                // int cause (1) its not stable and (2) we don't have access to mod.
                hasher.update(val.getError().?);
            },
            .Enum => {
                // This panic will go away when enum values move to be stored in the intern pool.
                const int_val = val.enumToInt(ty, mod) catch @panic("OOM");
                hashInt(int_val, hasher, mod);
            },
            .Union => {
                const union_obj = val.cast(Payload.Union).?.data;
                if (ty.unionTagType()) |tag_ty| {
                    union_obj.tag.hash(tag_ty, hasher, mod);
                }
                const active_field_ty = ty.unionFieldType(union_obj.tag, mod);
                union_obj.val.hash(active_field_ty, hasher, mod);
            },
            .Fn => {
                // Note that this hashes the *Fn/*ExternFn rather than the *Decl.
                // This is to differentiate function bodies from function pointers.
                // This is currently redundant since we already hash the zig type tag
                // at the top of this function.
                if (val.castTag(.function)) |func| {
                    std.hash.autoHash(hasher, func.data);
                } else if (val.castTag(.extern_fn)) |func| {
                    std.hash.autoHash(hasher, func.data);
                } else unreachable;
            },
            .Frame => {
                @panic("TODO implement hashing frame values");
            },
            .AnyFrame => {
                @panic("TODO implement hashing anyframe values");
            },
            .EnumLiteral => {
                const bytes = val.castTag(.enum_literal).?.data;
                hasher.update(bytes);
            },
        }
    }

    /// This is a more conservative hash function that produces equal hashes for values
    /// that can coerce into each other.
    /// This function is used by hash maps and so treats floating-point NaNs as equal
    /// to each other, and not equal to other floating-point values.
    pub fn hashUncoerced(val: Value, ty: Type, hasher: *std.hash.Wyhash, mod: *Module) void {
        if (val.isUndef()) return;
        // The value is runtime-known and shouldn't affect the hash.
        if (val.tag() == .runtime_value) return;

        switch (ty.zigTypeTag(mod)) {
            .Opaque => unreachable, // Cannot hash opaque types
            .Void,
            .NoReturn,
            .Undefined,
            .Null,
            .Struct, // It sure would be nice to do something clever with structs.
            => |zig_type_tag| std.hash.autoHash(hasher, zig_type_tag),
            .Type => {
                val.toType().hashWithHasher(hasher, mod);
            },
            .Float, .ComptimeFloat => std.hash.autoHash(hasher, @bitCast(u128, val.toFloat(f128, mod))),
            .Bool, .Int, .ComptimeInt, .Pointer, .Fn => switch (val.tag()) {
                .slice => {
                    const slice = val.castTag(.slice).?.data;
                    var ptr_buf: Type.SlicePtrFieldTypeBuffer = undefined;
                    const ptr_ty = ty.slicePtrFieldType(&ptr_buf, mod);
                    slice.ptr.hashUncoerced(ptr_ty, hasher, mod);
                },
                else => val.hashPtr(hasher, mod),
            },
            .Array, .Vector => {
                const len = ty.arrayLen(mod);
                const elem_ty = ty.childType(mod);
                var index: usize = 0;
                while (index < len) : (index += 1) {
                    const elem_val = val.elemValue(mod, index) catch |err| switch (err) {
                        // Will be solved when arrays and vectors get migrated to the intern pool.
                        error.OutOfMemory => @panic("OOM"),
                    };
                    elem_val.hashUncoerced(elem_ty, hasher, mod);
                }
            },
            .Optional => if (val.castTag(.opt_payload)) |payload| {
                const child_ty = ty.optionalChild(mod);
                payload.data.hashUncoerced(child_ty, hasher, mod);
            } else std.hash.autoHash(hasher, std.builtin.TypeId.Null),
            .ErrorSet, .ErrorUnion => if (val.getError()) |err| hasher.update(err) else {
                const pl_ty = ty.errorUnionPayload();
                val.castTag(.eu_payload).?.data.hashUncoerced(pl_ty, hasher, mod);
            },
            .Enum, .EnumLiteral, .Union => {
                hasher.update(val.tagName(ty, mod));
                if (val.cast(Payload.Union)) |union_obj| {
                    const active_field_ty = ty.unionFieldType(union_obj.data.tag, mod);
                    union_obj.data.val.hashUncoerced(active_field_ty, hasher, mod);
                } else std.hash.autoHash(hasher, std.builtin.TypeId.Void);
            },
            .Frame => @panic("TODO implement hashing frame values"),
            .AnyFrame => @panic("TODO implement hashing anyframe values"),
        }
    }

    pub const ArrayHashContext = struct {
        ty: Type,
        mod: *Module,

        pub fn hash(self: @This(), val: Value) u32 {
            const other_context: HashContext = .{ .ty = self.ty, .mod = self.mod };
            return @truncate(u32, other_context.hash(val));
        }
        pub fn eql(self: @This(), a: Value, b: Value, b_index: usize) bool {
            _ = b_index;
            return a.eql(b, self.ty, self.mod);
        }
    };

    pub const HashContext = struct {
        ty: Type,
        mod: *Module,

        pub fn hash(self: @This(), val: Value) u64 {
            var hasher = std.hash.Wyhash.init(0);
            val.hash(self.ty, &hasher, self.mod);
            return hasher.final();
        }

        pub fn eql(self: @This(), a: Value, b: Value) bool {
            return a.eql(b, self.ty, self.mod);
        }
    };

    pub fn isComptimeMutablePtr(val: Value) bool {
        return switch (val.ip_index) {
            .none => switch (val.tag()) {
                .decl_ref_mut, .comptime_field_ptr => true,
                .elem_ptr => isComptimeMutablePtr(val.castTag(.elem_ptr).?.data.array_ptr),
                .field_ptr => isComptimeMutablePtr(val.castTag(.field_ptr).?.data.container_ptr),
                .eu_payload_ptr => isComptimeMutablePtr(val.castTag(.eu_payload_ptr).?.data.container_ptr),
                .opt_payload_ptr => isComptimeMutablePtr(val.castTag(.opt_payload_ptr).?.data.container_ptr),
                .slice => isComptimeMutablePtr(val.castTag(.slice).?.data.ptr),

                else => false,
            },
            else => false,
        };
    }

    pub fn canMutateComptimeVarState(val: Value) bool {
        if (val.isComptimeMutablePtr()) return true;
        return switch (val.ip_index) {
            .none => switch (val.tag()) {
                .repeated => return val.castTag(.repeated).?.data.canMutateComptimeVarState(),
                .eu_payload => return val.castTag(.eu_payload).?.data.canMutateComptimeVarState(),
                .eu_payload_ptr => return val.castTag(.eu_payload_ptr).?.data.container_ptr.canMutateComptimeVarState(),
                .opt_payload => return val.castTag(.opt_payload).?.data.canMutateComptimeVarState(),
                .opt_payload_ptr => return val.castTag(.opt_payload_ptr).?.data.container_ptr.canMutateComptimeVarState(),
                .aggregate => {
                    const fields = val.castTag(.aggregate).?.data;
                    for (fields) |field| {
                        if (field.canMutateComptimeVarState()) return true;
                    }
                    return false;
                },
                .@"union" => return val.cast(Payload.Union).?.data.val.canMutateComptimeVarState(),
                .slice => return val.castTag(.slice).?.data.ptr.canMutateComptimeVarState(),
                else => return false,
            },
            else => return false,
        };
    }

    /// Gets the decl referenced by this pointer.  If the pointer does not point
    /// to a decl, or if it points to some part of a decl (like field_ptr or element_ptr),
    /// this function returns null.
    pub fn pointerDecl(val: Value) ?Module.Decl.Index {
        return switch (val.ip_index) {
            .none => switch (val.tag()) {
                .decl_ref_mut => val.castTag(.decl_ref_mut).?.data.decl_index,
                .extern_fn => val.castTag(.extern_fn).?.data.owner_decl,
                .function => val.castTag(.function).?.data.owner_decl,
                .variable => val.castTag(.variable).?.data.owner_decl,
                .decl_ref => val.cast(Payload.Decl).?.data,
                else => null,
            },
            else => null,
        };
    }

    fn hashInt(int_val: Value, hasher: *std.hash.Wyhash, mod: *const Module) void {
        var buffer: BigIntSpace = undefined;
        const big = int_val.toBigInt(&buffer, mod);
        std.hash.autoHash(hasher, big.positive);
        for (big.limbs) |limb| {
            std.hash.autoHash(hasher, limb);
        }
    }

    fn hashPtr(ptr_val: Value, hasher: *std.hash.Wyhash, mod: *const Module) void {
        switch (ptr_val.tag()) {
            .decl_ref,
            .decl_ref_mut,
            .extern_fn,
            .function,
            .variable,
            => {
                const decl: Module.Decl.Index = ptr_val.pointerDecl().?;
                std.hash.autoHash(hasher, decl);
            },
            .comptime_field_ptr => {
                std.hash.autoHash(hasher, Value.Tag.comptime_field_ptr);
            },

            .elem_ptr => {
                const elem_ptr = ptr_val.castTag(.elem_ptr).?.data;
                hashPtr(elem_ptr.array_ptr, hasher, mod);
                std.hash.autoHash(hasher, Value.Tag.elem_ptr);
                std.hash.autoHash(hasher, elem_ptr.index);
            },
            .field_ptr => {
                const field_ptr = ptr_val.castTag(.field_ptr).?.data;
                std.hash.autoHash(hasher, Value.Tag.field_ptr);
                hashPtr(field_ptr.container_ptr, hasher, mod);
                std.hash.autoHash(hasher, field_ptr.field_index);
            },
            .eu_payload_ptr => {
                const err_union_ptr = ptr_val.castTag(.eu_payload_ptr).?.data;
                std.hash.autoHash(hasher, Value.Tag.eu_payload_ptr);
                hashPtr(err_union_ptr.container_ptr, hasher, mod);
            },
            .opt_payload_ptr => {
                const opt_ptr = ptr_val.castTag(.opt_payload_ptr).?.data;
                std.hash.autoHash(hasher, Value.Tag.opt_payload_ptr);
                hashPtr(opt_ptr.container_ptr, hasher, mod);
            },

            .the_only_possible_value,
            .lazy_align,
            .lazy_size,
            => return hashInt(ptr_val, hasher, mod),

            else => unreachable,
        }
    }

    pub fn slicePtr(val: Value) Value {
        return switch (val.tag()) {
            .slice => val.castTag(.slice).?.data.ptr,
            // TODO this should require being a slice tag, and not allow decl_ref, field_ptr, etc.
            .decl_ref, .decl_ref_mut, .field_ptr, .elem_ptr, .comptime_field_ptr => val,
            else => unreachable,
        };
    }

    pub fn sliceLen(val: Value, mod: *Module) u64 {
        return switch (val.tag()) {
            .slice => val.castTag(.slice).?.data.len.toUnsignedInt(mod),
            .decl_ref => {
                const decl_index = val.castTag(.decl_ref).?.data;
                const decl = mod.declPtr(decl_index);
                if (decl.ty.zigTypeTag(mod) == .Array) {
                    return decl.ty.arrayLen(mod);
                } else {
                    return 1;
                }
            },
            .decl_ref_mut => {
                const decl_index = val.castTag(.decl_ref_mut).?.data.decl_index;
                const decl = mod.declPtr(decl_index);
                if (decl.ty.zigTypeTag(mod) == .Array) {
                    return decl.ty.arrayLen(mod);
                } else {
                    return 1;
                }
            },
            .comptime_field_ptr => {
                const payload = val.castTag(.comptime_field_ptr).?.data;
                if (payload.field_ty.zigTypeTag(mod) == .Array) {
                    return payload.field_ty.arrayLen(mod);
                } else {
                    return 1;
                }
            },
            else => unreachable,
        };
    }

    /// Asserts the value is a single-item pointer to an array, or an array,
    /// or an unknown-length pointer, and returns the element value at the index.
    pub fn elemValue(val: Value, mod: *Module, index: usize) Allocator.Error!Value {
        switch (val.ip_index) {
            .undef => return Value.undef,
            .none => switch (val.tag()) {
                // This is the case of accessing an element of an undef array.
                .empty_array => unreachable, // out of bounds array index
                .empty_struct_value => unreachable, // out of bounds array index

                .empty_array_sentinel => {
                    assert(index == 0); // The only valid index for an empty array with sentinel.
                    return val.castTag(.empty_array_sentinel).?.data;
                },

                .bytes => {
                    const byte = val.castTag(.bytes).?.data[index];
                    return mod.intValue(Type.u8, byte);
                },
                .str_lit => {
                    const str_lit = val.castTag(.str_lit).?.data;
                    const bytes = mod.string_literal_bytes.items[str_lit.index..][0..str_lit.len];
                    const byte = bytes[index];
                    return mod.intValue(Type.u8, byte);
                },

                // No matter the index; all the elements are the same!
                .repeated => return val.castTag(.repeated).?.data,

                .aggregate => return val.castTag(.aggregate).?.data[index],
                .slice => return val.castTag(.slice).?.data.ptr.elemValue(mod, index),

                .decl_ref => return mod.declPtr(val.castTag(.decl_ref).?.data).val.elemValue(mod, index),
                .decl_ref_mut => return mod.declPtr(val.castTag(.decl_ref_mut).?.data.decl_index).val.elemValue(mod, index),
                .comptime_field_ptr => return val.castTag(.comptime_field_ptr).?.data.field_val.elemValue(mod, index),
                .elem_ptr => {
                    const data = val.castTag(.elem_ptr).?.data;
                    return data.array_ptr.elemValue(mod, index + data.index);
                },
                .field_ptr => {
                    const data = val.castTag(.field_ptr).?.data;
                    if (data.container_ptr.pointerDecl()) |decl_index| {
                        const container_decl = mod.declPtr(decl_index);
                        const field_type = data.container_ty.structFieldType(data.field_index);
                        const field_val = container_decl.val.fieldValue(field_type, mod, data.field_index);
                        return field_val.elemValue(mod, index);
                    } else unreachable;
                },

                // The child type of arrays which have only one possible value need
                // to have only one possible value itself.
                .the_only_possible_value => return val,

                .opt_payload_ptr => return val.castTag(.opt_payload_ptr).?.data.container_ptr.elemValue(mod, index),
                .eu_payload_ptr => return val.castTag(.eu_payload_ptr).?.data.container_ptr.elemValue(mod, index),

                .opt_payload => return val.castTag(.opt_payload).?.data.elemValue(mod, index),
                .eu_payload => return val.castTag(.eu_payload).?.data.elemValue(mod, index),

                else => unreachable,
            },
            else => unreachable,
        }
    }

    pub fn tagIsVariable(val: Value) bool {
        return val.ip_index == .none and val.tag() == .variable;
    }

    /// Returns true if a Value is backed by a variable
    pub fn isVariable(val: Value, mod: *Module) bool {
        return switch (val.ip_index) {
            .none => switch (val.tag()) {
                .slice => val.castTag(.slice).?.data.ptr.isVariable(mod),
                .comptime_field_ptr => val.castTag(.comptime_field_ptr).?.data.field_val.isVariable(mod),
                .elem_ptr => val.castTag(.elem_ptr).?.data.array_ptr.isVariable(mod),
                .field_ptr => val.castTag(.field_ptr).?.data.container_ptr.isVariable(mod),
                .eu_payload_ptr => val.castTag(.eu_payload_ptr).?.data.container_ptr.isVariable(mod),
                .opt_payload_ptr => val.castTag(.opt_payload_ptr).?.data.container_ptr.isVariable(mod),
                .decl_ref => {
                    const decl = mod.declPtr(val.castTag(.decl_ref).?.data);
                    assert(decl.has_tv);
                    return decl.val.isVariable(mod);
                },
                .decl_ref_mut => {
                    const decl = mod.declPtr(val.castTag(.decl_ref_mut).?.data.decl_index);
                    assert(decl.has_tv);
                    return decl.val.isVariable(mod);
                },

                .variable => true,
                else => false,
            },
            else => false,
        };
    }

    pub fn isPtrToThreadLocal(val: Value, mod: *Module) bool {
        return switch (val.ip_index) {
            .none => switch (val.tag()) {
                .variable => false,
                else => val.isPtrToThreadLocalInner(mod),
            },
            else => val.isPtrToThreadLocalInner(mod),
        };
    }

    fn isPtrToThreadLocalInner(val: Value, mod: *Module) bool {
        return switch (val.ip_index) {
            .none => switch (val.tag()) {
                .slice => val.castTag(.slice).?.data.ptr.isPtrToThreadLocalInner(mod),
                .comptime_field_ptr => val.castTag(.comptime_field_ptr).?.data.field_val.isPtrToThreadLocalInner(mod),
                .elem_ptr => val.castTag(.elem_ptr).?.data.array_ptr.isPtrToThreadLocalInner(mod),
                .field_ptr => val.castTag(.field_ptr).?.data.container_ptr.isPtrToThreadLocalInner(mod),
                .eu_payload_ptr => val.castTag(.eu_payload_ptr).?.data.container_ptr.isPtrToThreadLocalInner(mod),
                .opt_payload_ptr => val.castTag(.opt_payload_ptr).?.data.container_ptr.isPtrToThreadLocalInner(mod),
                .decl_ref => mod.declPtr(val.castTag(.decl_ref).?.data).val.isPtrToThreadLocalInner(mod),
                .decl_ref_mut => mod.declPtr(val.castTag(.decl_ref_mut).?.data.decl_index).val.isPtrToThreadLocalInner(mod),

                .variable => val.castTag(.variable).?.data.is_threadlocal,
                else => false,
            },
            else => false,
        };
    }

    // Asserts that the provided start/end are in-bounds.
    pub fn sliceArray(
        val: Value,
        mod: *Module,
        arena: Allocator,
        start: usize,
        end: usize,
    ) error{OutOfMemory}!Value {
        return switch (val.tag()) {
            .empty_array_sentinel => if (start == 0 and end == 1) val else Value.initTag(.empty_array),
            .bytes => Tag.bytes.create(arena, val.castTag(.bytes).?.data[start..end]),
            .str_lit => {
                const str_lit = val.castTag(.str_lit).?.data;
                return Tag.str_lit.create(arena, .{
                    .index = @intCast(u32, str_lit.index + start),
                    .len = @intCast(u32, end - start),
                });
            },
            .aggregate => Tag.aggregate.create(arena, val.castTag(.aggregate).?.data[start..end]),
            .slice => sliceArray(val.castTag(.slice).?.data.ptr, mod, arena, start, end),

            .decl_ref => sliceArray(mod.declPtr(val.castTag(.decl_ref).?.data).val, mod, arena, start, end),
            .decl_ref_mut => sliceArray(mod.declPtr(val.castTag(.decl_ref_mut).?.data.decl_index).val, mod, arena, start, end),
            .comptime_field_ptr => sliceArray(val.castTag(.comptime_field_ptr).?.data.field_val, mod, arena, start, end),
            .elem_ptr => blk: {
                const elem_ptr = val.castTag(.elem_ptr).?.data;
                break :blk sliceArray(elem_ptr.array_ptr, mod, arena, start + elem_ptr.index, end + elem_ptr.index);
            },

            .repeated,
            .the_only_possible_value,
            => val,

            else => unreachable,
        };
    }

    pub fn fieldValue(val: Value, ty: Type, mod: *const Module, index: usize) Value {
        switch (val.ip_index) {
            .undef => return Value.undef,
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

                .the_only_possible_value => return ty.onePossibleValue(mod).?,

                .empty_struct_value => {
                    if (ty.isSimpleTupleOrAnonStruct()) {
                        const tuple = ty.tupleFields();
                        return tuple.values[index];
                    }
                    if (ty.structFieldValueComptime(mod, index)) |some| {
                        return some;
                    }
                    unreachable;
                },

                else => unreachable,
            },
            else => unreachable,
        }
    }

    pub fn unionTag(val: Value) Value {
        switch (val.ip_index) {
            .undef => return val,
            .none => switch (val.tag()) {
                .enum_field_index => return val,
                .@"union" => return val.castTag(.@"union").?.data.tag,
                else => unreachable,
            },
            else => unreachable,
        }
    }

    /// Returns a pointer to the element value at the index.
    pub fn elemPtr(
        val: Value,
        ty: Type,
        arena: Allocator,
        index: usize,
        mod: *Module,
    ) Allocator.Error!Value {
        const elem_ty = ty.elemType2(mod);
        const ptr_val = switch (val.tag()) {
            .slice => val.castTag(.slice).?.data.ptr,
            else => val,
        };

        if (ptr_val.tag() == .elem_ptr) {
            const elem_ptr = ptr_val.castTag(.elem_ptr).?.data;
            if (elem_ptr.elem_ty.eql(elem_ty, mod)) {
                return Tag.elem_ptr.create(arena, .{
                    .array_ptr = elem_ptr.array_ptr,
                    .elem_ty = elem_ptr.elem_ty,
                    .index = elem_ptr.index + index,
                });
            }
        }
        return Tag.elem_ptr.create(arena, .{
            .array_ptr = ptr_val,
            .elem_ty = elem_ty,
            .index = index,
        });
    }

    pub fn isUndef(val: Value) bool {
        return val.ip_index == .undef;
    }

    /// TODO: check for cases such as array that is not marked undef but all the element
    /// values are marked undef, or struct that is not marked undef but all fields are marked
    /// undef, etc.
    pub fn isUndefDeep(val: Value) bool {
        return val.isUndef();
    }

    /// Returns true if any value contained in `self` is undefined.
    /// TODO: check for cases such as array that is not marked undef but all the element
    /// values are marked undef, or struct that is not marked undef but all fields are marked
    /// undef, etc.
    pub fn anyUndef(self: Value, mod: *Module) !bool {
        switch (self.ip_index) {
            .undef => return true,
            .none => switch (self.tag()) {
                .slice => {
                    const payload = self.castTag(.slice).?;
                    const len = payload.data.len.toUnsignedInt(mod);

                    for (0..len) |i| {
                        const elem_val = try payload.data.ptr.elemValue(mod, i);
                        if (try elem_val.anyUndef(mod)) return true;
                    }
                },

                .aggregate => {
                    const payload = self.castTag(.aggregate).?;
                    for (payload.data) |val| {
                        if (try val.anyUndef(mod)) return true;
                    }
                },
                else => {},
            },
            else => {},
        }

        return false;
    }

    /// Asserts the value is not undefined and not unreachable.
    /// Integer value 0 is considered null because of C pointers.
    pub fn isNull(val: Value, mod: *const Module) bool {
        return switch (val.ip_index) {
            .undef => unreachable,
            .unreachable_value => unreachable,

            .null_value,
            .zero,
            .zero_usize,
            .zero_u8,
            => true,

            .none => switch (val.tag()) {
                .opt_payload => false,

                // If it's not one of those two tags then it must be a C pointer value,
                // in which case the value 0 is null and other values are non-null.

                .the_only_possible_value => true,

                .inferred_alloc => unreachable,
                .inferred_alloc_comptime => unreachable,

                else => false,
            },
            else => return switch (mod.intern_pool.indexToKey(val.ip_index)) {
                .int => |int| switch (int.storage) {
                    .big_int => |big_int| big_int.eqZero(),
                    inline .u64, .i64 => |x| x == 0,
                },
                else => unreachable,
            },
        };
    }

    /// Valid only for error (union) types. Asserts the value is not undefined and not
    /// unreachable. For error unions, prefer `errorUnionIsPayload` to find out whether
    /// something is an error or not because it works without having to figure out the
    /// string.
    pub fn getError(self: Value) ?[]const u8 {
        return switch (self.ip_index) {
            .undef => unreachable,
            .unreachable_value => unreachable,
            .none => switch (self.tag()) {
                .@"error" => self.castTag(.@"error").?.data.name,
                .eu_payload => null,

                .inferred_alloc => unreachable,
                .inferred_alloc_comptime => unreachable,
                else => unreachable,
            },
            else => unreachable,
        };
    }

    /// Assumes the type is an error union. Returns true if and only if the value is
    /// the error union payload, not an error.
    pub fn errorUnionIsPayload(val: Value) bool {
        return switch (val.ip_index) {
            .undef => unreachable,
            .none => switch (val.tag()) {
                .eu_payload => true,
                else => false,

                .inferred_alloc => unreachable,
                .inferred_alloc_comptime => unreachable,
            },
            else => false,
        };
    }

    /// Value of the optional, null if optional has no payload.
    pub fn optionalValue(val: Value, mod: *const Module) ?Value {
        if (val.isNull(mod)) return null;

        // Valid for optional representation to be the direct value
        // and not use opt_payload.
        return if (val.castTag(.opt_payload)) |p| p.data else val;
    }

    /// Valid for all types. Asserts the value is not undefined.
    pub fn isFloat(self: Value) bool {
        return switch (self.ip_index) {
            .undef => unreachable,
            .none => switch (self.tag()) {
                .inferred_alloc => unreachable,
                .inferred_alloc_comptime => unreachable,

                .float_16,
                .float_32,
                .float_64,
                .float_80,
                .float_128,
                => true,
                else => false,
            },
            else => false,
        };
    }

    pub fn intToFloat(val: Value, arena: Allocator, int_ty: Type, float_ty: Type, mod: *Module) !Value {
        return intToFloatAdvanced(val, arena, int_ty, float_ty, mod, null) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => unreachable,
        };
    }

    pub fn intToFloatAdvanced(val: Value, arena: Allocator, int_ty: Type, float_ty: Type, mod: *Module, opt_sema: ?*Sema) !Value {
        if (int_ty.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, int_ty.vectorLen(mod));
            const scalar_ty = float_ty.scalarType(mod);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                scalar.* = try intToFloatScalar(elem_val, arena, scalar_ty, mod, opt_sema);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return intToFloatScalar(val, arena, float_ty, mod, opt_sema);
    }

    pub fn intToFloatScalar(val: Value, arena: Allocator, float_ty: Type, mod: *Module, opt_sema: ?*Sema) !Value {
        const target = mod.getTarget();
        switch (val.ip_index) {
            .undef => return val,
            .none => switch (val.tag()) {
                .the_only_possible_value => return Value.zero, // for i0, u0
                .lazy_align => {
                    const ty = val.castTag(.lazy_align).?.data;
                    if (opt_sema) |sema| {
                        return intToFloatInner((try ty.abiAlignmentAdvanced(mod, .{ .sema = sema })).scalar, arena, float_ty, target);
                    } else {
                        return intToFloatInner(ty.abiAlignment(mod), arena, float_ty, target);
                    }
                },
                .lazy_size => {
                    const ty = val.castTag(.lazy_size).?.data;
                    if (opt_sema) |sema| {
                        return intToFloatInner((try ty.abiSizeAdvanced(mod, .{ .sema = sema })).scalar, arena, float_ty, target);
                    } else {
                        return intToFloatInner(ty.abiSize(mod), arena, float_ty, target);
                    }
                },
                else => unreachable,
            },
            else => return switch (mod.intern_pool.indexToKey(val.ip_index)) {
                .int => |int| switch (int.storage) {
                    .big_int => |big_int| {
                        const float = bigIntToFloat(big_int.limbs, big_int.positive);
                        return floatToValue(float, arena, float_ty, target);
                    },
                    inline .u64, .i64 => |x| intToFloatInner(x, arena, float_ty, target),
                },
                else => unreachable,
            },
        }
    }

    fn intToFloatInner(x: anytype, arena: Allocator, dest_ty: Type, target: Target) !Value {
        switch (dest_ty.floatBits(target)) {
            16 => return Value.Tag.float_16.create(arena, @intToFloat(f16, x)),
            32 => return Value.Tag.float_32.create(arena, @intToFloat(f32, x)),
            64 => return Value.Tag.float_64.create(arena, @intToFloat(f64, x)),
            80 => return Value.Tag.float_80.create(arena, @intToFloat(f80, x)),
            128 => return Value.Tag.float_128.create(arena, @intToFloat(f128, x)),
            else => unreachable,
        }
    }

    pub fn floatToValue(float: f128, arena: Allocator, dest_ty: Type, target: Target) !Value {
        switch (dest_ty.floatBits(target)) {
            16 => return Value.Tag.float_16.create(arena, @floatCast(f16, float)),
            32 => return Value.Tag.float_32.create(arena, @floatCast(f32, float)),
            64 => return Value.Tag.float_64.create(arena, @floatCast(f64, float)),
            80 => return Value.Tag.float_80.create(arena, @floatCast(f80, float)),
            128 => return Value.Tag.float_128.create(arena, float),
            else => unreachable,
        }
    }

    fn calcLimbLenFloat(scalar: anytype) usize {
        if (scalar == 0) {
            return 1;
        }

        const w_value = @fabs(scalar);
        return @divFloor(@floatToInt(std.math.big.Limb, std.math.log2(w_value)), @typeInfo(std.math.big.Limb).Int.bits) + 1;
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
            const result_data = try arena.alloc(Value, ty.vectorLen(mod));
            const scalar_ty = ty.scalarType(mod);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try intAddSatScalar(lhs_elem, rhs_elem, scalar_ty, arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
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
        assert(!lhs.isUndef());
        assert(!rhs.isUndef());

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
            const result_data = try arena.alloc(Value, ty.vectorLen(mod));
            const scalar_ty = ty.scalarType(mod);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try intSubSatScalar(lhs_elem, rhs_elem, scalar_ty, arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
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
        assert(!lhs.isUndef());
        assert(!rhs.isUndef());

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
            const overflowed_data = try arena.alloc(Value, ty.vectorLen(mod));
            const result_data = try arena.alloc(Value, ty.vectorLen(mod));
            const scalar_ty = ty.scalarType(mod);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                const of_math_result = try intMulWithOverflowScalar(lhs_elem, rhs_elem, scalar_ty, arena, mod);
                overflowed_data[i] = of_math_result.overflow_bit;
                scalar.* = of_math_result.wrapped_result;
            }
            return OverflowArithmeticResult{
                .overflow_bit = try Value.Tag.aggregate.create(arena, overflowed_data),
                .wrapped_result = try Value.Tag.aggregate.create(arena, result_data),
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
        var limbs_buffer = try arena.alloc(
            std.math.big.Limb,
            std.math.big.int.calcMulLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len, 1),
        );
        result_bigint.mul(lhs_bigint, rhs_bigint, limbs_buffer, arena);

        const overflowed = !result_bigint.toConst().fitsInTwosComp(info.signedness, info.bits);
        if (overflowed) {
            result_bigint.truncate(result_bigint.toConst(), info.signedness, info.bits);
        }

        return OverflowArithmeticResult{
            .overflow_bit = boolToInt(overflowed),
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
            const result_data = try arena.alloc(Value, ty.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try numberMulWrapScalar(lhs_elem, rhs_elem, ty.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
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
        if (lhs.isUndef() or rhs.isUndef()) return Value.undef;

        if (ty.zigTypeTag(mod) == .ComptimeInt) {
            return intMul(lhs, rhs, ty, arena, mod);
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
            const result_data = try arena.alloc(Value, ty.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try intMulSatScalar(lhs_elem, rhs_elem, ty.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
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
        assert(!lhs.isUndef());
        assert(!rhs.isUndef());

        const info = ty.intInfo(mod);

        var lhs_space: Value.BigIntSpace = undefined;
        var rhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
        const rhs_bigint = rhs.toBigInt(&rhs_space, mod);
        const limbs = try arena.alloc(
            std.math.big.Limb,
            std.math.max(
                // For the saturate
                std.math.big.int.calcTwosCompLimbCount(info.bits),
                lhs_bigint.limbs.len + rhs_bigint.limbs.len,
            ),
        );
        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
        var limbs_buffer = try arena.alloc(
            std.math.big.Limb,
            std.math.big.int.calcMulLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len, 1),
        );
        result_bigint.mul(lhs_bigint, rhs_bigint, limbs_buffer, arena);
        result_bigint.saturate(result_bigint.toConst(), info.signedness, info.bits);
        return mod.intValue_big(ty, result_bigint.toConst());
    }

    /// Supports both floats and ints; handles undefined.
    pub fn numberMax(lhs: Value, rhs: Value, mod: *Module) Value {
        if (lhs.isUndef() or rhs.isUndef()) return undef;
        if (lhs.isNan()) return rhs;
        if (rhs.isNan()) return lhs;

        return switch (order(lhs, rhs, mod)) {
            .lt => rhs,
            .gt, .eq => lhs,
        };
    }

    /// Supports both floats and ints; handles undefined.
    pub fn numberMin(lhs: Value, rhs: Value, mod: *Module) Value {
        if (lhs.isUndef() or rhs.isUndef()) return undef;
        if (lhs.isNan()) return rhs;
        if (rhs.isNan()) return lhs;

        return switch (order(lhs, rhs, mod)) {
            .lt => lhs,
            .gt, .eq => rhs,
        };
    }

    /// operands must be (vectors of) integers; handles undefined scalars.
    pub fn bitwiseNot(val: Value, ty: Type, arena: Allocator, mod: *Module) !Value {
        if (ty.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, ty.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                scalar.* = try bitwiseNotScalar(elem_val, ty.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return bitwiseNotScalar(val, ty, arena, mod);
    }

    /// operands must be integers; handles undefined.
    pub fn bitwiseNotScalar(val: Value, ty: Type, arena: Allocator, mod: *Module) !Value {
        if (val.isUndef()) return Value.undef;

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
            const result_data = try allocator.alloc(Value, ty.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try bitwiseAndScalar(lhs_elem, rhs_elem, ty.scalarType(mod), allocator, mod);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
        }
        return bitwiseAndScalar(lhs, rhs, ty, allocator, mod);
    }

    /// operands must be integers; handles undefined.
    pub fn bitwiseAndScalar(lhs: Value, rhs: Value, ty: Type, arena: Allocator, mod: *Module) !Value {
        if (lhs.isUndef() or rhs.isUndef()) return Value.undef;

        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        var lhs_space: Value.BigIntSpace = undefined;
        var rhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
        const rhs_bigint = rhs.toBigInt(&rhs_space, mod);
        const limbs = try arena.alloc(
            std.math.big.Limb,
            // + 1 for negatives
            std.math.max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
        );
        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
        result_bigint.bitAnd(lhs_bigint, rhs_bigint);
        return mod.intValue_big(ty, result_bigint.toConst());
    }

    /// operands must be (vectors of) integers; handles undefined scalars.
    pub fn bitwiseNand(lhs: Value, rhs: Value, ty: Type, arena: Allocator, mod: *Module) !Value {
        if (ty.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, ty.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try bitwiseNandScalar(lhs_elem, rhs_elem, ty.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return bitwiseNandScalar(lhs, rhs, ty, arena, mod);
    }

    /// operands must be integers; handles undefined.
    pub fn bitwiseNandScalar(lhs: Value, rhs: Value, ty: Type, arena: Allocator, mod: *Module) !Value {
        if (lhs.isUndef() or rhs.isUndef()) return Value.undef;

        const anded = try bitwiseAnd(lhs, rhs, ty, arena, mod);
        const all_ones = if (ty.isSignedInt(mod)) Value.negative_one else try ty.maxIntScalar(mod);
        return bitwiseXor(anded, all_ones, ty, arena, mod);
    }

    /// operands must be (vectors of) integers; handles undefined scalars.
    pub fn bitwiseOr(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
        if (ty.zigTypeTag(mod) == .Vector) {
            const result_data = try allocator.alloc(Value, ty.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try bitwiseOrScalar(lhs_elem, rhs_elem, ty.scalarType(mod), allocator, mod);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
        }
        return bitwiseOrScalar(lhs, rhs, ty, allocator, mod);
    }

    /// operands must be integers; handles undefined.
    pub fn bitwiseOrScalar(lhs: Value, rhs: Value, ty: Type, arena: Allocator, mod: *Module) !Value {
        if (lhs.isUndef() or rhs.isUndef()) return Value.undef;

        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        var lhs_space: Value.BigIntSpace = undefined;
        var rhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
        const rhs_bigint = rhs.toBigInt(&rhs_space, mod);
        const limbs = try arena.alloc(
            std.math.big.Limb,
            std.math.max(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
        );
        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
        result_bigint.bitOr(lhs_bigint, rhs_bigint);
        return mod.intValue_big(ty, result_bigint.toConst());
    }

    /// operands must be (vectors of) integers; handles undefined scalars.
    pub fn bitwiseXor(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
        if (ty.zigTypeTag(mod) == .Vector) {
            const result_data = try allocator.alloc(Value, ty.vectorLen(mod));
            const scalar_ty = ty.scalarType(mod);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try bitwiseXorScalar(lhs_elem, rhs_elem, scalar_ty, allocator, mod);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
        }
        return bitwiseXorScalar(lhs, rhs, ty, allocator, mod);
    }

    /// operands must be integers; handles undefined.
    pub fn bitwiseXorScalar(lhs: Value, rhs: Value, ty: Type, arena: Allocator, mod: *Module) !Value {
        if (lhs.isUndef() or rhs.isUndef()) return Value.undef;

        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        var lhs_space: Value.BigIntSpace = undefined;
        var rhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
        const rhs_bigint = rhs.toBigInt(&rhs_space, mod);
        const limbs = try arena.alloc(
            std.math.big.Limb,
            // + 1 for negatives
            std.math.max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
        );
        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
        result_bigint.bitXor(lhs_bigint, rhs_bigint);
        return mod.intValue_big(ty, result_bigint.toConst());
    }

    pub fn intDiv(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
        if (ty.zigTypeTag(mod) == .Vector) {
            const result_data = try allocator.alloc(Value, ty.vectorLen(mod));
            const scalar_ty = ty.scalarType(mod);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try intDivScalar(lhs_elem, rhs_elem, scalar_ty, allocator, mod);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
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
        return mod.intValue_big(ty, result_q.toConst());
    }

    pub fn intDivFloor(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
        if (ty.zigTypeTag(mod) == .Vector) {
            const result_data = try allocator.alloc(Value, ty.vectorLen(mod));
            const scalar_ty = ty.scalarType(mod);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try intDivFloorScalar(lhs_elem, rhs_elem, scalar_ty, allocator, mod);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
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
            const result_data = try allocator.alloc(Value, ty.vectorLen(mod));
            const scalar_ty = ty.scalarType(mod);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try intModScalar(lhs_elem, rhs_elem, scalar_ty, allocator, mod);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
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
    pub fn isNan(val: Value) bool {
        return switch (val.ip_index) {
            .none => switch (val.tag()) {
                .float_16 => std.math.isNan(val.castTag(.float_16).?.data),
                .float_32 => std.math.isNan(val.castTag(.float_32).?.data),
                .float_64 => std.math.isNan(val.castTag(.float_64).?.data),
                .float_80 => std.math.isNan(val.castTag(.float_80).?.data),
                .float_128 => std.math.isNan(val.castTag(.float_128).?.data),
                else => false,
            },
            else => false,
        };
    }

    /// Returns true if the value is a floating point type and is infinite. Returns false otherwise.
    pub fn isInf(val: Value) bool {
        return switch (val.ip_index) {
            .none => switch (val.tag()) {
                .float_16 => std.math.isInf(val.castTag(.float_16).?.data),
                .float_32 => std.math.isInf(val.castTag(.float_32).?.data),
                .float_64 => std.math.isInf(val.castTag(.float_64).?.data),
                .float_80 => std.math.isInf(val.castTag(.float_80).?.data),
                .float_128 => std.math.isInf(val.castTag(.float_128).?.data),
                else => false,
            },
            else => false,
        };
    }

    pub fn isNegativeInf(val: Value) bool {
        return switch (val.ip_index) {
            .none => switch (val.tag()) {
                .float_16 => std.math.isNegativeInf(val.castTag(.float_16).?.data),
                .float_32 => std.math.isNegativeInf(val.castTag(.float_32).?.data),
                .float_64 => std.math.isNegativeInf(val.castTag(.float_64).?.data),
                .float_80 => std.math.isNegativeInf(val.castTag(.float_80).?.data),
                .float_128 => std.math.isNegativeInf(val.castTag(.float_128).?.data),
                else => false,
            },
            else => false,
        };
    }

    pub fn floatRem(lhs: Value, rhs: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try floatRemScalar(lhs_elem, rhs_elem, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return floatRemScalar(lhs, rhs, float_type, arena, mod);
    }

    pub fn floatRemScalar(lhs: Value, rhs: Value, float_type: Type, arena: Allocator, mod: *const Module) !Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const lhs_val = lhs.toFloat(f16, mod);
                const rhs_val = rhs.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @rem(lhs_val, rhs_val));
            },
            32 => {
                const lhs_val = lhs.toFloat(f32, mod);
                const rhs_val = rhs.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @rem(lhs_val, rhs_val));
            },
            64 => {
                const lhs_val = lhs.toFloat(f64, mod);
                const rhs_val = rhs.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @rem(lhs_val, rhs_val));
            },
            80 => {
                const lhs_val = lhs.toFloat(f80, mod);
                const rhs_val = rhs.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @rem(lhs_val, rhs_val));
            },
            128 => {
                const lhs_val = lhs.toFloat(f128, mod);
                const rhs_val = rhs.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @rem(lhs_val, rhs_val));
            },
            else => unreachable,
        }
    }

    pub fn floatMod(lhs: Value, rhs: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try floatModScalar(lhs_elem, rhs_elem, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return floatModScalar(lhs, rhs, float_type, arena, mod);
    }

    pub fn floatModScalar(lhs: Value, rhs: Value, float_type: Type, arena: Allocator, mod: *const Module) !Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const lhs_val = lhs.toFloat(f16, mod);
                const rhs_val = rhs.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @mod(lhs_val, rhs_val));
            },
            32 => {
                const lhs_val = lhs.toFloat(f32, mod);
                const rhs_val = rhs.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @mod(lhs_val, rhs_val));
            },
            64 => {
                const lhs_val = lhs.toFloat(f64, mod);
                const rhs_val = rhs.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @mod(lhs_val, rhs_val));
            },
            80 => {
                const lhs_val = lhs.toFloat(f80, mod);
                const rhs_val = rhs.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @mod(lhs_val, rhs_val));
            },
            128 => {
                const lhs_val = lhs.toFloat(f128, mod);
                const rhs_val = rhs.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @mod(lhs_val, rhs_val));
            },
            else => unreachable,
        }
    }

    pub fn intMul(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
        if (ty.zigTypeTag(mod) == .Vector) {
            const result_data = try allocator.alloc(Value, ty.vectorLen(mod));
            const scalar_ty = ty.scalarType(mod);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try intMulScalar(lhs_elem, rhs_elem, scalar_ty, allocator, mod);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
        }
        return intMulScalar(lhs, rhs, ty, allocator, mod);
    }

    pub fn intMulScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
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
        var limbs_buffer = try allocator.alloc(
            std.math.big.Limb,
            std.math.big.int.calcMulLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len, 1),
        );
        defer allocator.free(limbs_buffer);
        result_bigint.mul(lhs_bigint, rhs_bigint, limbs_buffer, allocator);
        return mod.intValue_big(ty, result_bigint.toConst());
    }

    pub fn intTrunc(val: Value, ty: Type, allocator: Allocator, signedness: std.builtin.Signedness, bits: u16, mod: *Module) !Value {
        if (ty.zigTypeTag(mod) == .Vector) {
            const result_data = try allocator.alloc(Value, ty.vectorLen(mod));
            const scalar_ty = ty.scalarType(mod);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                scalar.* = try intTruncScalar(elem_val, scalar_ty, allocator, signedness, bits, mod);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
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
            const result_data = try allocator.alloc(Value, ty.vectorLen(mod));
            const scalar_ty = ty.scalarType(mod);
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                const bits_elem = try bits.elemValue(mod, i);
                scalar.* = try intTruncScalar(elem_val, scalar_ty, allocator, signedness, @intCast(u16, bits_elem.toUnsignedInt(mod)), mod);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
        }
        return intTruncScalar(val, ty, allocator, signedness, @intCast(u16, bits.toUnsignedInt(mod)), mod);
    }

    pub fn intTruncScalar(
        val: Value,
        ty: Type,
        allocator: Allocator,
        signedness: std.builtin.Signedness,
        bits: u16,
        mod: *Module,
    ) !Value {
        if (bits == 0) return Value.zero;

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
            const result_data = try allocator.alloc(Value, ty.vectorLen(mod));
            const scalar_ty = ty.scalarType(mod);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try shlScalar(lhs_elem, rhs_elem, scalar_ty, allocator, mod);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
        }
        return shlScalar(lhs, rhs, ty, allocator, mod);
    }

    pub fn shlScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        var lhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
        const shift = @intCast(usize, rhs.toUnsignedInt(mod));
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
            const overflowed_data = try allocator.alloc(Value, ty.vectorLen(mod));
            const result_data = try allocator.alloc(Value, ty.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                const of_math_result = try shlWithOverflowScalar(lhs_elem, rhs_elem, ty.scalarType(mod), allocator, mod);
                overflowed_data[i] = of_math_result.overflow_bit;
                scalar.* = of_math_result.wrapped_result;
            }
            return OverflowArithmeticResult{
                .overflow_bit = try Value.Tag.aggregate.create(allocator, overflowed_data),
                .wrapped_result = try Value.Tag.aggregate.create(allocator, result_data),
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
        const shift = @intCast(usize, rhs.toUnsignedInt(mod));
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
            .overflow_bit = boolToInt(overflowed),
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
            const result_data = try arena.alloc(Value, ty.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try shlSatScalar(lhs_elem, rhs_elem, ty.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
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
        const shift = @intCast(usize, rhs.toUnsignedInt(mod));
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
            const result_data = try arena.alloc(Value, ty.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try shlTruncScalar(lhs_elem, rhs_elem, ty.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
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
            const result_data = try allocator.alloc(Value, ty.vectorLen(mod));
            const scalar_ty = ty.scalarType(mod);
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try shrScalar(lhs_elem, rhs_elem, scalar_ty, allocator, mod);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
        }
        return shrScalar(lhs, rhs, ty, allocator, mod);
    }

    pub fn shrScalar(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        var lhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, mod);
        const shift = @intCast(usize, rhs.toUnsignedInt(mod));

        const result_limbs = lhs_bigint.limbs.len -| (shift / (@sizeOf(std.math.big.Limb) * 8));
        if (result_limbs == 0) {
            // The shift is enough to remove all the bits from the number, which means the
            // result is 0 or -1 depending on the sign.
            if (lhs_bigint.positive) {
                return Value.zero;
            } else {
                return Value.negative_one;
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
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                scalar.* = try floatNegScalar(elem_val, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return floatNegScalar(val, float_type, arena, mod);
    }

    pub fn floatNegScalar(
        val: Value,
        float_type: Type,
        arena: Allocator,
        mod: *const Module,
    ) !Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => return Value.Tag.float_16.create(arena, -val.toFloat(f16, mod)),
            32 => return Value.Tag.float_32.create(arena, -val.toFloat(f32, mod)),
            64 => return Value.Tag.float_64.create(arena, -val.toFloat(f64, mod)),
            80 => return Value.Tag.float_80.create(arena, -val.toFloat(f80, mod)),
            128 => return Value.Tag.float_128.create(arena, -val.toFloat(f128, mod)),
            else => unreachable,
        }
    }

    pub fn floatDiv(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        mod: *Module,
    ) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try floatDivScalar(lhs_elem, rhs_elem, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return floatDivScalar(lhs, rhs, float_type, arena, mod);
    }

    pub fn floatDivScalar(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        mod: *const Module,
    ) !Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const lhs_val = lhs.toFloat(f16, mod);
                const rhs_val = rhs.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, lhs_val / rhs_val);
            },
            32 => {
                const lhs_val = lhs.toFloat(f32, mod);
                const rhs_val = rhs.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, lhs_val / rhs_val);
            },
            64 => {
                const lhs_val = lhs.toFloat(f64, mod);
                const rhs_val = rhs.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, lhs_val / rhs_val);
            },
            80 => {
                const lhs_val = lhs.toFloat(f80, mod);
                const rhs_val = rhs.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, lhs_val / rhs_val);
            },
            128 => {
                const lhs_val = lhs.toFloat(f128, mod);
                const rhs_val = rhs.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, lhs_val / rhs_val);
            },
            else => unreachable,
        }
    }

    pub fn floatDivFloor(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        mod: *Module,
    ) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try floatDivFloorScalar(lhs_elem, rhs_elem, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return floatDivFloorScalar(lhs, rhs, float_type, arena, mod);
    }

    pub fn floatDivFloorScalar(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        mod: *const Module,
    ) !Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const lhs_val = lhs.toFloat(f16, mod);
                const rhs_val = rhs.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @divFloor(lhs_val, rhs_val));
            },
            32 => {
                const lhs_val = lhs.toFloat(f32, mod);
                const rhs_val = rhs.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @divFloor(lhs_val, rhs_val));
            },
            64 => {
                const lhs_val = lhs.toFloat(f64, mod);
                const rhs_val = rhs.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @divFloor(lhs_val, rhs_val));
            },
            80 => {
                const lhs_val = lhs.toFloat(f80, mod);
                const rhs_val = rhs.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @divFloor(lhs_val, rhs_val));
            },
            128 => {
                const lhs_val = lhs.toFloat(f128, mod);
                const rhs_val = rhs.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @divFloor(lhs_val, rhs_val));
            },
            else => unreachable,
        }
    }

    pub fn floatDivTrunc(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        mod: *Module,
    ) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try floatDivTruncScalar(lhs_elem, rhs_elem, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return floatDivTruncScalar(lhs, rhs, float_type, arena, mod);
    }

    pub fn floatDivTruncScalar(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        mod: *const Module,
    ) !Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const lhs_val = lhs.toFloat(f16, mod);
                const rhs_val = rhs.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @divTrunc(lhs_val, rhs_val));
            },
            32 => {
                const lhs_val = lhs.toFloat(f32, mod);
                const rhs_val = rhs.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @divTrunc(lhs_val, rhs_val));
            },
            64 => {
                const lhs_val = lhs.toFloat(f64, mod);
                const rhs_val = rhs.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @divTrunc(lhs_val, rhs_val));
            },
            80 => {
                const lhs_val = lhs.toFloat(f80, mod);
                const rhs_val = rhs.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @divTrunc(lhs_val, rhs_val));
            },
            128 => {
                const lhs_val = lhs.toFloat(f128, mod);
                const rhs_val = rhs.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @divTrunc(lhs_val, rhs_val));
            },
            else => unreachable,
        }
    }

    pub fn floatMul(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        mod: *Module,
    ) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const lhs_elem = try lhs.elemValue(mod, i);
                const rhs_elem = try rhs.elemValue(mod, i);
                scalar.* = try floatMulScalar(lhs_elem, rhs_elem, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return floatMulScalar(lhs, rhs, float_type, arena, mod);
    }

    pub fn floatMulScalar(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        mod: *const Module,
    ) !Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const lhs_val = lhs.toFloat(f16, mod);
                const rhs_val = rhs.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, lhs_val * rhs_val);
            },
            32 => {
                const lhs_val = lhs.toFloat(f32, mod);
                const rhs_val = rhs.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, lhs_val * rhs_val);
            },
            64 => {
                const lhs_val = lhs.toFloat(f64, mod);
                const rhs_val = rhs.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, lhs_val * rhs_val);
            },
            80 => {
                const lhs_val = lhs.toFloat(f80, mod);
                const rhs_val = rhs.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, lhs_val * rhs_val);
            },
            128 => {
                const lhs_val = lhs.toFloat(f128, mod);
                const rhs_val = rhs.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, lhs_val * rhs_val);
            },
            else => unreachable,
        }
    }

    pub fn sqrt(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                scalar.* = try sqrtScalar(elem_val, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return sqrtScalar(val, float_type, arena, mod);
    }

    pub fn sqrtScalar(val: Value, float_type: Type, arena: Allocator, mod: *const Module) Allocator.Error!Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @sqrt(f));
            },
            32 => {
                const f = val.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @sqrt(f));
            },
            64 => {
                const f = val.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @sqrt(f));
            },
            80 => {
                const f = val.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @sqrt(f));
            },
            128 => {
                const f = val.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @sqrt(f));
            },
            else => unreachable,
        }
    }

    pub fn sin(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                scalar.* = try sinScalar(elem_val, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return sinScalar(val, float_type, arena, mod);
    }

    pub fn sinScalar(val: Value, float_type: Type, arena: Allocator, mod: *const Module) Allocator.Error!Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @sin(f));
            },
            32 => {
                const f = val.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @sin(f));
            },
            64 => {
                const f = val.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @sin(f));
            },
            80 => {
                const f = val.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @sin(f));
            },
            128 => {
                const f = val.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @sin(f));
            },
            else => unreachable,
        }
    }

    pub fn cos(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                scalar.* = try cosScalar(elem_val, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return cosScalar(val, float_type, arena, mod);
    }

    pub fn cosScalar(val: Value, float_type: Type, arena: Allocator, mod: *const Module) Allocator.Error!Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @cos(f));
            },
            32 => {
                const f = val.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @cos(f));
            },
            64 => {
                const f = val.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @cos(f));
            },
            80 => {
                const f = val.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @cos(f));
            },
            128 => {
                const f = val.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @cos(f));
            },
            else => unreachable,
        }
    }

    pub fn tan(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                scalar.* = try tanScalar(elem_val, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return tanScalar(val, float_type, arena, mod);
    }

    pub fn tanScalar(val: Value, float_type: Type, arena: Allocator, mod: *const Module) Allocator.Error!Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @tan(f));
            },
            32 => {
                const f = val.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @tan(f));
            },
            64 => {
                const f = val.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @tan(f));
            },
            80 => {
                const f = val.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @tan(f));
            },
            128 => {
                const f = val.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @tan(f));
            },
            else => unreachable,
        }
    }

    pub fn exp(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                scalar.* = try expScalar(elem_val, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return expScalar(val, float_type, arena, mod);
    }

    pub fn expScalar(val: Value, float_type: Type, arena: Allocator, mod: *const Module) Allocator.Error!Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @exp(f));
            },
            32 => {
                const f = val.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @exp(f));
            },
            64 => {
                const f = val.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @exp(f));
            },
            80 => {
                const f = val.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @exp(f));
            },
            128 => {
                const f = val.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @exp(f));
            },
            else => unreachable,
        }
    }

    pub fn exp2(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                scalar.* = try exp2Scalar(elem_val, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return exp2Scalar(val, float_type, arena, mod);
    }

    pub fn exp2Scalar(val: Value, float_type: Type, arena: Allocator, mod: *const Module) Allocator.Error!Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @exp2(f));
            },
            32 => {
                const f = val.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @exp2(f));
            },
            64 => {
                const f = val.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @exp2(f));
            },
            80 => {
                const f = val.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @exp2(f));
            },
            128 => {
                const f = val.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @exp2(f));
            },
            else => unreachable,
        }
    }

    pub fn log(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                scalar.* = try logScalar(elem_val, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return logScalar(val, float_type, arena, mod);
    }

    pub fn logScalar(val: Value, float_type: Type, arena: Allocator, mod: *const Module) Allocator.Error!Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @log(f));
            },
            32 => {
                const f = val.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @log(f));
            },
            64 => {
                const f = val.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @log(f));
            },
            80 => {
                const f = val.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @log(f));
            },
            128 => {
                const f = val.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @log(f));
            },
            else => unreachable,
        }
    }

    pub fn log2(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                scalar.* = try log2Scalar(elem_val, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return log2Scalar(val, float_type, arena, mod);
    }

    pub fn log2Scalar(val: Value, float_type: Type, arena: Allocator, mod: *const Module) Allocator.Error!Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @log2(f));
            },
            32 => {
                const f = val.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @log2(f));
            },
            64 => {
                const f = val.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @log2(f));
            },
            80 => {
                const f = val.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @log2(f));
            },
            128 => {
                const f = val.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @log2(f));
            },
            else => unreachable,
        }
    }

    pub fn log10(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                scalar.* = try log10Scalar(elem_val, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return log10Scalar(val, float_type, arena, mod);
    }

    pub fn log10Scalar(val: Value, float_type: Type, arena: Allocator, mod: *const Module) Allocator.Error!Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @log10(f));
            },
            32 => {
                const f = val.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @log10(f));
            },
            64 => {
                const f = val.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @log10(f));
            },
            80 => {
                const f = val.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @log10(f));
            },
            128 => {
                const f = val.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @log10(f));
            },
            else => unreachable,
        }
    }

    pub fn fabs(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                scalar.* = try fabsScalar(elem_val, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return fabsScalar(val, float_type, arena, mod);
    }

    pub fn fabsScalar(val: Value, float_type: Type, arena: Allocator, mod: *const Module) Allocator.Error!Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @fabs(f));
            },
            32 => {
                const f = val.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @fabs(f));
            },
            64 => {
                const f = val.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @fabs(f));
            },
            80 => {
                const f = val.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @fabs(f));
            },
            128 => {
                const f = val.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @fabs(f));
            },
            else => unreachable,
        }
    }

    pub fn floor(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                scalar.* = try floorScalar(elem_val, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return floorScalar(val, float_type, arena, mod);
    }

    pub fn floorScalar(val: Value, float_type: Type, arena: Allocator, mod: *const Module) Allocator.Error!Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @floor(f));
            },
            32 => {
                const f = val.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @floor(f));
            },
            64 => {
                const f = val.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @floor(f));
            },
            80 => {
                const f = val.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @floor(f));
            },
            128 => {
                const f = val.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @floor(f));
            },
            else => unreachable,
        }
    }

    pub fn ceil(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                scalar.* = try ceilScalar(elem_val, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return ceilScalar(val, float_type, arena, mod);
    }

    pub fn ceilScalar(val: Value, float_type: Type, arena: Allocator, mod: *const Module) Allocator.Error!Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @ceil(f));
            },
            32 => {
                const f = val.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @ceil(f));
            },
            64 => {
                const f = val.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @ceil(f));
            },
            80 => {
                const f = val.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @ceil(f));
            },
            128 => {
                const f = val.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @ceil(f));
            },
            else => unreachable,
        }
    }

    pub fn round(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                scalar.* = try roundScalar(elem_val, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return roundScalar(val, float_type, arena, mod);
    }

    pub fn roundScalar(val: Value, float_type: Type, arena: Allocator, mod: *const Module) Allocator.Error!Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @round(f));
            },
            32 => {
                const f = val.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @round(f));
            },
            64 => {
                const f = val.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @round(f));
            },
            80 => {
                const f = val.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @round(f));
            },
            128 => {
                const f = val.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @round(f));
            },
            else => unreachable,
        }
    }

    pub fn trunc(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        if (float_type.zigTypeTag(mod) == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const elem_val = try val.elemValue(mod, i);
                scalar.* = try truncScalar(elem_val, float_type.scalarType(mod), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return truncScalar(val, float_type, arena, mod);
    }

    pub fn truncScalar(val: Value, float_type: Type, arena: Allocator, mod: *const Module) Allocator.Error!Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @trunc(f));
            },
            32 => {
                const f = val.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @trunc(f));
            },
            64 => {
                const f = val.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @trunc(f));
            },
            80 => {
                const f = val.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @trunc(f));
            },
            128 => {
                const f = val.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @trunc(f));
            },
            else => unreachable,
        }
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
            const result_data = try arena.alloc(Value, float_type.vectorLen(mod));
            for (result_data, 0..) |*scalar, i| {
                const mulend1_elem = try mulend1.elemValue(mod, i);
                const mulend2_elem = try mulend2.elemValue(mod, i);
                const addend_elem = try addend.elemValue(mod, i);
                scalar.* = try mulAddScalar(
                    float_type.scalarType(mod),
                    mulend1_elem,
                    mulend2_elem,
                    addend_elem,
                    arena,
                    mod,
                );
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return mulAddScalar(float_type, mulend1, mulend2, addend, arena, mod);
    }

    pub fn mulAddScalar(
        float_type: Type,
        mulend1: Value,
        mulend2: Value,
        addend: Value,
        arena: Allocator,
        mod: *const Module,
    ) Allocator.Error!Value {
        const target = mod.getTarget();
        switch (float_type.floatBits(target)) {
            16 => {
                const m1 = mulend1.toFloat(f16, mod);
                const m2 = mulend2.toFloat(f16, mod);
                const a = addend.toFloat(f16, mod);
                return Value.Tag.float_16.create(arena, @mulAdd(f16, m1, m2, a));
            },
            32 => {
                const m1 = mulend1.toFloat(f32, mod);
                const m2 = mulend2.toFloat(f32, mod);
                const a = addend.toFloat(f32, mod);
                return Value.Tag.float_32.create(arena, @mulAdd(f32, m1, m2, a));
            },
            64 => {
                const m1 = mulend1.toFloat(f64, mod);
                const m2 = mulend2.toFloat(f64, mod);
                const a = addend.toFloat(f64, mod);
                return Value.Tag.float_64.create(arena, @mulAdd(f64, m1, m2, a));
            },
            80 => {
                const m1 = mulend1.toFloat(f80, mod);
                const m2 = mulend2.toFloat(f80, mod);
                const a = addend.toFloat(f80, mod);
                return Value.Tag.float_80.create(arena, @mulAdd(f80, m1, m2, a));
            },
            128 => {
                const m1 = mulend1.toFloat(f128, mod);
                const m2 = mulend2.toFloat(f128, mod);
                const a = addend.toFloat(f128, mod);
                return Value.Tag.float_128.create(arena, @mulAdd(f128, m1, m2, a));
            },
            else => unreachable,
        }
    }

    /// If the value is represented in-memory as a series of bytes that all
    /// have the same value, return that byte value, otherwise null.
    pub fn hasRepeatedByteRepr(val: Value, ty: Type, mod: *Module) !?Value {
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
        return try mod.intValue(Type.u8, first_byte);
    }

    pub fn isGenericPoison(val: Value) bool {
        return val.ip_index == .generic_poison;
    }

    /// This type is not copyable since it may contain pointers to its inner data.
    pub const Payload = struct {
        tag: Tag,

        pub const U32 = struct {
            base: Payload,
            data: u32,
        };

        pub const Function = struct {
            base: Payload,
            data: *Module.Fn,
        };

        pub const ExternFn = struct {
            base: Payload,
            data: *Module.ExternFn,
        };

        pub const Decl = struct {
            base: Payload,
            data: Module.Decl.Index,
        };

        pub const Variable = struct {
            base: Payload,
            data: *Module.Var,
        };

        pub const SubValue = struct {
            base: Payload,
            data: Value,
        };

        pub const DeclRefMut = struct {
            pub const base_tag = Tag.decl_ref_mut;

            base: Payload = Payload{ .tag = base_tag },
            data: Data,

            pub const Data = struct {
                decl_index: Module.Decl.Index,
                runtime_index: RuntimeIndex,
            };
        };

        pub const PayloadPtr = struct {
            base: Payload,
            data: struct {
                container_ptr: Value,
                container_ty: Type,
            },
        };

        pub const ComptimeFieldPtr = struct {
            base: Payload,
            data: struct {
                field_val: Value,
                field_ty: Type,
            },
        };

        pub const ElemPtr = struct {
            pub const base_tag = Tag.elem_ptr;

            base: Payload = Payload{ .tag = base_tag },
            data: struct {
                array_ptr: Value,
                elem_ty: Type,
                index: usize,
            },
        };

        pub const FieldPtr = struct {
            pub const base_tag = Tag.field_ptr;

            base: Payload = Payload{ .tag = base_tag },
            data: struct {
                container_ptr: Value,
                container_ty: Type,
                field_index: usize,
            },
        };

        pub const Bytes = struct {
            base: Payload,
            /// Includes the sentinel, if any.
            data: []const u8,
        };

        pub const StrLit = struct {
            base: Payload,
            data: Module.StringLiteralContext.Key,
        };

        pub const Aggregate = struct {
            base: Payload,
            /// Field values. The types are according to the struct or array type.
            /// The length is provided here so that copying a Value does not depend on the Type.
            data: []Value,
        };

        pub const Slice = struct {
            base: Payload,
            data: struct {
                ptr: Value,
                len: Value,
            },

            pub const ptr_index = 0;
            pub const len_index = 1;
        };

        pub const Ty = struct {
            base: Payload,
            data: Type,
        };

        pub const Float_16 = struct {
            pub const base_tag = Tag.float_16;

            base: Payload = .{ .tag = base_tag },
            data: f16,
        };

        pub const Float_32 = struct {
            pub const base_tag = Tag.float_32;

            base: Payload = .{ .tag = base_tag },
            data: f32,
        };

        pub const Float_64 = struct {
            pub const base_tag = Tag.float_64;

            base: Payload = .{ .tag = base_tag },
            data: f64,
        };

        pub const Float_80 = struct {
            pub const base_tag = Tag.float_80;

            base: Payload = .{ .tag = base_tag },
            data: f80,
        };

        pub const Float_128 = struct {
            pub const base_tag = Tag.float_128;

            base: Payload = .{ .tag = base_tag },
            data: f128,
        };

        pub const Error = struct {
            base: Payload = .{ .tag = .@"error" },
            data: struct {
                /// `name` is owned by `Module` and will be valid for the entire
                /// duration of the compilation.
                /// TODO revisit this when we have the concept of the error tag type
                name: []const u8,
            },
        };

        pub const InferredAlloc = struct {
            pub const base_tag = Tag.inferred_alloc;

            base: Payload = .{ .tag = base_tag },
            data: struct {
                /// The value stored in the inferred allocation. This will go into
                /// peer type resolution. This is stored in a separate list so that
                /// the items are contiguous in memory and thus can be passed to
                /// `Module.resolvePeerTypes`.
                prongs: std.MultiArrayList(struct {
                    /// The dummy instruction used as a peer to resolve the type.
                    /// Although this has a redundant type with placeholder, this is
                    /// needed in addition because it may be a constant value, which
                    /// affects peer type resolution.
                    stored_inst: Air.Inst.Ref,
                    /// The bitcast instruction used as a placeholder when the
                    /// new result pointer type is not yet known.
                    placeholder: Air.Inst.Index,
                }) = .{},
                /// 0 means ABI-aligned.
                alignment: u32,
            },
        };

        pub const InferredAllocComptime = struct {
            pub const base_tag = Tag.inferred_alloc_comptime;

            base: Payload = .{ .tag = base_tag },
            data: struct {
                decl_index: Module.Decl.Index,
                /// 0 means ABI-aligned.
                alignment: u32,
            },
        };

        pub const Union = struct {
            pub const base_tag = Tag.@"union";

            base: Payload = .{ .tag = base_tag },
            data: struct {
                tag: Value,
                val: Value,
            },
        };
    };

    pub const BigIntSpace = InternPool.Key.Int.Storage.BigIntSpace;

    pub const zero: Value = .{ .ip_index = .zero, .legacy = undefined };
    pub const one: Value = .{ .ip_index = .one, .legacy = undefined };
    pub const negative_one: Value = .{ .ip_index = .negative_one, .legacy = undefined };
    pub const undef: Value = .{ .ip_index = .undef, .legacy = undefined };
    pub const @"void": Value = .{ .ip_index = .void_value, .legacy = undefined };
    pub const @"null": Value = .{ .ip_index = .null_value, .legacy = undefined };
    pub const @"false": Value = .{ .ip_index = .bool_false, .legacy = undefined };
    pub const @"true": Value = .{ .ip_index = .bool_true, .legacy = undefined };
    pub const @"unreachable": Value = .{ .ip_index = .unreachable_value, .legacy = undefined };

    pub const generic_poison: Value = .{ .ip_index = .generic_poison, .legacy = undefined };
    pub const generic_poison_type: Value = .{ .ip_index = .generic_poison_type, .legacy = undefined };

    pub fn makeBool(x: bool) Value {
        return if (x) Value.true else Value.false;
    }

    pub fn boolToInt(x: bool) Value {
        return if (x) Value.one else Value.zero;
    }

    pub const RuntimeIndex = enum(u32) {
        zero = 0,
        comptime_field_ptr = std.math.maxInt(u32),
        _,

        pub fn increment(ri: *RuntimeIndex) void {
            ri.* = @intToEnum(RuntimeIndex, @enumToInt(ri.*) + 1);
        }
    };

    /// This function is used in the debugger pretty formatters in tools/ to fetch the
    /// Tag to Payload mapping to facilitate fancy debug printing for this type.
    fn dbHelper(self: *Value, tag_to_payload_map: *map: {
        const tags = @typeInfo(Tag).Enum.fields;
        var fields: [tags.len]std.builtin.Type.StructField = undefined;
        for (&fields, tags) |*field, t| field.* = .{
            .name = t.name,
            .type = *if (t.value < Tag.no_payload_count) void else @field(Tag, t.name).Type(),
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
