const std = @import("std");
const cstr = std.cstr;
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const autoHash = std.hash.autoHash;
const Target = std.Target;

const Module = @import("../../Module.zig");
const Type = @import("../../type.zig").Type;

pub const CType = extern union {
    /// If the tag value is less than Tag.no_payload_count, then no pointer
    /// dereference is needed.
    tag_if_small_enough: Tag,
    ptr_otherwise: *const Payload,

    pub fn initTag(small_tag: Tag) CType {
        assert(!small_tag.hasPayload());
        return .{ .tag_if_small_enough = small_tag };
    }

    pub fn initPayload(pl: anytype) CType {
        const T = @typeInfo(@TypeOf(pl)).Pointer.child;
        return switch (pl.base.tag) {
            inline else => |t| if (comptime t.hasPayload() and t.Type() == T) .{
                .ptr_otherwise = &pl.base,
            } else unreachable,
        };
    }

    pub fn hasPayload(self: CType) bool {
        return self.tag_if_small_enough.hasPayload();
    }

    pub fn tag(self: CType) Tag {
        return if (self.hasPayload()) self.ptr_otherwise.tag else self.tag_if_small_enough;
    }

    pub fn cast(self: CType, comptime T: type) ?*const T {
        if (!self.hasPayload()) return null;
        const pl = self.ptr_otherwise;
        return switch (pl.tag) {
            inline else => |t| if (comptime t.hasPayload() and t.Type() == T)
                @fieldParentPtr(T, "base", pl)
            else
                null,
        };
    }

    pub fn castTag(self: CType, comptime t: Tag) ?*const t.Type() {
        return if (self.tag() == t) @fieldParentPtr(t.Type(), "base", self.ptr_otherwise) else null;
    }

    pub const Tag = enum(usize) {
        // The first section of this enum are tags that require no payload.
        void,

        // C basic types
        char,

        @"signed char",
        short,
        int,
        long,
        @"long long",

        _Bool,
        @"unsigned char",
        @"unsigned short",
        @"unsigned int",
        @"unsigned long",
        @"unsigned long long",

        float,
        double,
        @"long double",

        // C header types
        bool, // stdbool.h
        size_t, // stddef.h
        ptrdiff_t, // stddef.h

        // zig.h types
        zig_u8,
        zig_i8,
        zig_u16,
        zig_i16,
        zig_u32,
        zig_i32,
        zig_u64,
        zig_i64,
        zig_u128,
        zig_i128,
        zig_f16,
        zig_f32,
        zig_f64,
        zig_f80,
        zig_f128,

        // After this, the tag requires a payload.
        pointer,
        pointer_const,
        pointer_volatile,
        pointer_const_volatile,
        array,
        vector,
        fwd_struct,
        fwd_union,
        anon_struct,
        packed_anon_struct,
        @"struct",
        @"union",
        packed_struct,
        packed_union,
        function,
        varargs_function,

        pub const last_no_payload_tag = Tag.zig_f128;
        pub const no_payload_count = @enumToInt(last_no_payload_tag) + 1;

        pub fn hasPayload(self: Tag) bool {
            return @enumToInt(self) >= no_payload_count;
        }

        pub fn toIndex(self: Tag) Index {
            assert(!self.hasPayload());
            return @intCast(Index, @enumToInt(self));
        }

        pub fn Type(comptime self: Tag) type {
            return switch (self) {
                .void,
                .char,
                .@"signed char",
                .short,
                .int,
                .long,
                .@"long long",
                ._Bool,
                .@"unsigned char",
                .@"unsigned short",
                .@"unsigned int",
                .@"unsigned long",
                .@"unsigned long long",
                .float,
                .double,
                .@"long double",
                .bool,
                .size_t,
                .ptrdiff_t,
                .zig_u8,
                .zig_i8,
                .zig_u16,
                .zig_i16,
                .zig_u32,
                .zig_i32,
                .zig_u64,
                .zig_i64,
                .zig_u128,
                .zig_i128,
                .zig_f16,
                .zig_f32,
                .zig_f64,
                .zig_f80,
                .zig_f128,
                => @compileError("Type Tag " ++ @tagName(self) ++ " has no payload"),

                .pointer,
                .pointer_const,
                .pointer_volatile,
                .pointer_const_volatile,
                => Payload.Child,

                .array,
                .vector,
                => Payload.Sequence,

                .fwd_struct,
                .fwd_union,
                => Payload.FwdDecl,

                .anon_struct,
                .packed_anon_struct,
                => Payload.Fields,

                .@"struct",
                .@"union",
                .packed_struct,
                .packed_union,
                => Payload.Aggregate,

                .function,
                .varargs_function,
                => Payload.Function,
            };
        }
    };

    pub const Payload = struct {
        tag: Tag,

        pub const Child = struct {
            base: Payload,
            data: Index,
        };

        pub const Sequence = struct {
            base: Payload,
            data: struct {
                len: u64,
                elem_type: Index,
            },
        };

        pub const FwdDecl = struct {
            base: Payload,
            data: Module.Decl.Index,
        };

        pub const Fields = struct {
            base: Payload,
            data: Data,

            const Data = []const Field;
            const Field = struct {
                name: [*:0]const u8,
                type: Index,
                alignas: u32,
            };
        };

        pub const Aggregate = struct {
            base: Payload,
            data: struct {
                fields: Fields.Data,
                fwd_decl: Index,
            },
        };

        pub const Function = struct {
            base: Payload,
            data: struct {
                return_type: Index,
                param_types: []const Index,
            },
        };
    };

    pub const Index = u32;
    pub const Store = struct {
        arena: std.heap.ArenaAllocator.State = .{},
        set: Set = .{},

        const Set = struct {
            const Map = std.ArrayHashMapUnmanaged(CType, void, HashContext32, true);

            map: Map = .{},

            fn indexToCType(self: Set, index: Index) CType {
                if (index < Tag.no_payload_count) return initTag(@intToEnum(Tag, index));
                return self.map.keys()[index - Tag.no_payload_count];
            }

            fn indexToHash(self: Set, index: Index) Map.Hash {
                if (index < Tag.no_payload_count) return self.indexToCType(index).hash(self);
                return self.map.entries.items(.hash)[index - Tag.no_payload_count];
            }

            fn typeToIndex(self: Set, ty: Type, target: Target, kind: Kind) ?Index {
                const lookup = Convert.Lookup{ .imm = .{ .set = &self, .target = target } };

                var convert: Convert = undefined;
                convert.initType(ty, kind, lookup) catch unreachable;

                const t = convert.tag();
                if (!t.hasPayload()) return t.toIndex();

                return if (self.map.getIndexAdapted(
                    ty,
                    TypeAdapter32{ .kind = kind, .lookup = lookup, .convert = &convert },
                )) |idx| @intCast(Index, Tag.no_payload_count + idx) else null;
            }
        };

        const Promoted = struct {
            arena: std.heap.ArenaAllocator,
            set: Set,

            fn gpa(self: *Promoted) Allocator {
                return self.arena.child_allocator;
            }

            fn cTypeToIndex(self: *Promoted, cty: CType) Allocator.Error!Index {
                const t = cty.tag();
                if (@enumToInt(t) < Tag.no_payload_count) return @intCast(Index, @enumToInt(t));

                const gop = try self.set.map.getOrPutContext(self.gpa(), cty, .{ .store = &self.set });
                if (!gop.found_existing) gop.key_ptr.* = cty;
                if (std.debug.runtime_safety) {
                    const key = self.set.map.entries.items(.key)[gop.index];
                    assert(key.eql(cty));
                    assert(cty.hash(self.set) == key.hash(self.set));
                }
                return @intCast(Index, Tag.no_payload_count + gop.index);
            }

            fn typeToIndex(self: *Promoted, ty: Type, mod: *Module, kind: Kind) Allocator.Error!Index {
                const lookup = Convert.Lookup{ .mut = .{ .promoted = self, .mod = mod } };

                var convert: Convert = undefined;
                try convert.initType(ty, kind, lookup);

                const t = convert.tag();
                if (!t.hasPayload()) return t.toIndex();

                const gop = try self.set.map.getOrPutContextAdapted(
                    self.gpa(),
                    ty,
                    TypeAdapter32{ .kind = kind, .lookup = lookup.freeze(), .convert = &convert },
                    .{ .store = &self.set },
                );
                if (!gop.found_existing) {
                    errdefer _ = self.set.map.pop();
                    gop.key_ptr.* = try createFromConvert(self, ty, lookup.getTarget(), kind, convert);
                }
                if (std.debug.runtime_safety) {
                    const adapter = TypeAdapter64{
                        .kind = kind,
                        .lookup = lookup.freeze(),
                        .convert = &convert,
                    };
                    const key = self.set.map.entries.items(.key)[gop.index];
                    assert(adapter.eql(ty, key));
                    assert(adapter.hash(ty) == key.hash(self.set));
                }
                return @intCast(Index, Tag.no_payload_count + gop.index);
            }
        };

        fn promote(self: Store, gpa: Allocator) Promoted {
            return .{ .arena = self.arena.promote(gpa), .set = self.set };
        }

        fn demote(self: *Store, promoted: Promoted) void {
            self.arena = promoted.arena.state;
            self.set = promoted.set;
        }

        pub fn indexToCType(self: Store, index: Index) CType {
            return self.set.indexToCType(index);
        }

        pub fn cTypeToIndex(self: *Store, gpa: Allocator, cty: CType) !Index {
            var promoted = self.promote(gpa);
            defer self.demote(promoted);
            return promoted.cTypeToIndex(cty);
        }

        pub fn typeToCType(self: *Store, gpa: Allocator, ty: Type, mod: *Module) !CType {
            const idx = try self.typeToIndex(gpa, ty, mod);
            return self.indexToCType(idx);
        }

        pub fn typeToIndex(self: *Store, gpa: Allocator, ty: Type, mod: *Module) !Index {
            var promoted = self.promote(gpa);
            defer self.demote(promoted);
            return promoted.typeToIndex(ty, mod, .complete);
        }

        pub fn clearRetainingCapacity(self: *Store, gpa: Allocator) void {
            var promoted = self.promote(gpa);
            defer self.demote(promoted);
            promoted.set.map.clearRetainingCapacity();
            _ = promoted.arena.reset(.retain_capacity);
        }

        pub fn shrinkToFit(self: *Store, gpa: Allocator) void {
            self.map.shrinkAndFree(gpa, self.map.entries.len);
        }

        pub fn shrinkAndFree(self: *Store, gpa: Allocator) void {
            var promoted = self.promote(gpa);
            defer self.demote(promoted);
            promoted.set.map.clearAndFree(gpa);
            _ = promoted.arena.reset(.free_all);
        }

        pub fn move(self: *Store) Store {
            const moved = self.*;
            self.* = .{};
            return moved;
        }

        pub fn deinit(self: *Store, gpa: Allocator) void {
            var promoted = self.promote(gpa);
            promoted.set.map.deinit(gpa);
            _ = promoted.arena.deinit();
            self.* = undefined;
        }
    };

    pub fn eql(lhs: CType, rhs: CType) bool {
        // As a shortcut, if the small tags / addresses match, we're done.
        if (lhs.tag_if_small_enough == rhs.tag_if_small_enough) return true;

        const lhs_tag = lhs.tag();
        const rhs_tag = rhs.tag();
        if (lhs_tag != rhs_tag) return false;

        return switch (lhs_tag) {
            .void,
            .char,
            .@"signed char",
            .short,
            .int,
            .long,
            .@"long long",
            ._Bool,
            .@"unsigned char",
            .@"unsigned short",
            .@"unsigned int",
            .@"unsigned long",
            .@"unsigned long long",
            .float,
            .double,
            .@"long double",
            .bool,
            .size_t,
            .ptrdiff_t,
            .zig_u8,
            .zig_i8,
            .zig_u16,
            .zig_i16,
            .zig_u32,
            .zig_i32,
            .zig_u64,
            .zig_i64,
            .zig_u128,
            .zig_i128,
            .zig_f16,
            .zig_f32,
            .zig_f64,
            .zig_f80,
            .zig_f128,
            => false,

            .pointer,
            .pointer_const,
            .pointer_volatile,
            .pointer_const_volatile,
            => lhs.cast(Payload.Child).?.data == rhs.cast(Payload.Child).?.data,

            .array,
            .vector,
            => std.meta.eql(lhs.cast(Payload.Sequence).?.data, rhs.cast(Payload.Sequence).?.data),

            .fwd_struct,
            .fwd_union,
            => lhs.cast(Payload.FwdDecl).?.data == rhs.cast(Payload.FwdDecl).?.data,

            .anon_struct,
            .packed_anon_struct,
            => {
                const lhs_data = lhs.cast(Payload.Fields).?.data;
                const rhs_data = rhs.cast(Payload.Fields).?.data;
                if (lhs_data.len != rhs_data.len) return false;
                for (lhs_data, rhs_data) |lhs_field, rhs_field| {
                    if (lhs_field.type != rhs_field.type) return false;
                    if (lhs_field.alignas != rhs_field.alignas) return false;
                    if (cstr.cmp(lhs_field.name, rhs_field.name) != 0) return false;
                }
                return true;
            },

            .@"struct",
            .@"union",
            .packed_struct,
            .packed_union,
            => std.meta.eql(
                lhs.cast(Payload.Aggregate).?.data.fwd_decl,
                rhs.cast(Payload.Aggregate).?.data.fwd_decl,
            ),

            .function,
            .varargs_function,
            => {
                const lhs_data = lhs.cast(Payload.Function).?.data;
                const rhs_data = rhs.cast(Payload.Function).?.data;
                if (lhs_data.return_type != rhs_data.return_type) return false;
                if (lhs_data.param_types.len != rhs_data.param_types.len) return false;
                for (lhs_data.param_types, rhs_data.param_types) |lhs_param_cty, rhs_param_cty| {
                    if (lhs_param_cty != rhs_param_cty) return false;
                }
                return true;
            },
        };
    }

    pub fn hash(self: CType, store: Store.Set) u64 {
        var hasher = std.hash.Wyhash.init(0);
        self.updateHasher(&hasher, store);
        return hasher.final();
    }

    pub fn updateHasher(self: CType, hasher: anytype, store: Store.Set) void {
        const t = self.tag();
        autoHash(hasher, t);
        switch (t) {
            .void,
            .char,
            .@"signed char",
            .short,
            .int,
            .long,
            .@"long long",
            ._Bool,
            .@"unsigned char",
            .@"unsigned short",
            .@"unsigned int",
            .@"unsigned long",
            .@"unsigned long long",
            .float,
            .double,
            .@"long double",
            .bool,
            .size_t,
            .ptrdiff_t,
            .zig_u8,
            .zig_i8,
            .zig_u16,
            .zig_i16,
            .zig_u32,
            .zig_i32,
            .zig_u64,
            .zig_i64,
            .zig_u128,
            .zig_i128,
            .zig_f16,
            .zig_f32,
            .zig_f64,
            .zig_f80,
            .zig_f128,
            => {},

            .pointer,
            .pointer_const,
            .pointer_volatile,
            .pointer_const_volatile,
            => store.indexToCType(self.cast(Payload.Child).?.data).updateHasher(hasher, store),

            .array,
            .vector,
            => {
                const data = self.cast(Payload.Sequence).?.data;
                autoHash(hasher, data.len);
                store.indexToCType(data.elem_type).updateHasher(hasher, store);
            },

            .fwd_struct,
            .fwd_union,
            => autoHash(hasher, self.cast(Payload.FwdDecl).?.data),

            .anon_struct,
            .packed_anon_struct,
            => for (self.cast(Payload.Fields).?.data) |field| {
                store.indexToCType(field.type).updateHasher(hasher, store);
                hasher.update(mem.span(field.name));
                autoHash(hasher, field.alignas);
            },

            .@"struct",
            .@"union",
            .packed_struct,
            .packed_union,
            => store.indexToCType(self.cast(Payload.Aggregate).?.data.fwd_decl)
                .updateHasher(hasher, store),

            .function,
            .varargs_function,
            => {
                const data = self.cast(Payload.Function).?.data;
                store.indexToCType(data.return_type).updateHasher(hasher, store);
                for (data.param_types) |param_ty| {
                    store.indexToCType(param_ty).updateHasher(hasher, store);
                }
            },
        }
    }

    pub const Kind = enum { forward, complete, global, parameter };

    const Convert = struct {
        storage: union {
            none: void,
            child: Payload.Child,
            seq: Payload.Sequence,
            fwd: Payload.FwdDecl,
            anon: struct {
                fields: [2]Payload.Fields.Field,
                pl: Payload.Fields,
            },
            agg: Payload.Aggregate,
        },
        value: union(enum) {
            tag: Tag,
            cty: CType,
        },

        pub fn init(self: *@This(), t: Tag) void {
            self.* = if (t.hasPayload()) .{
                .storage = .{ .none = {} },
                .value = .{ .tag = t },
            } else .{
                .storage = .{ .none = {} },
                .value = .{ .cty = initTag(t) },
            };
        }

        pub fn tag(self: @This()) Tag {
            return switch (self.value) {
                .tag => |t| t,
                .cty => |c| c.tag(),
            };
        }

        fn tagFromIntInfo(signedness: std.builtin.Signedness, bits: u16) Tag {
            return switch (bits) {
                0 => .void,
                1...8 => switch (signedness) {
                    .unsigned => .zig_u8,
                    .signed => .zig_i8,
                },
                9...16 => switch (signedness) {
                    .unsigned => .zig_u16,
                    .signed => .zig_i16,
                },
                17...32 => switch (signedness) {
                    .unsigned => .zig_u32,
                    .signed => .zig_i32,
                },
                33...64 => switch (signedness) {
                    .unsigned => .zig_u64,
                    .signed => .zig_i64,
                },
                65...128 => switch (signedness) {
                    .unsigned => .zig_u128,
                    .signed => .zig_i128,
                },
                else => .array,
            };
        }

        pub const Lookup = union(enum) {
            fail: Target,
            imm: struct {
                set: *const Store.Set,
                target: Target,
            },
            mut: struct {
                promoted: *Store.Promoted,
                mod: *Module,
            },

            pub fn isMutable(self: @This()) bool {
                return switch (self) {
                    .fail, .imm => false,
                    .mut => true,
                };
            }

            pub fn getTarget(self: @This()) Target {
                return switch (self) {
                    .fail => |target| target,
                    .imm => |imm| imm.target,
                    .mut => |mut| mut.mod.getTarget(),
                };
            }

            pub fn getSet(self: @This()) ?*const Store.Set {
                return switch (self) {
                    .fail => null,
                    .imm => |imm| imm.set,
                    .mut => |mut| &mut.promoted.set,
                };
            }

            pub fn typeToIndex(self: @This(), ty: Type, kind: Kind) !?Index {
                return switch (self) {
                    .fail => null,
                    .imm => |imm| imm.set.typeToIndex(ty, imm.target, kind),
                    .mut => |mut| try mut.promoted.typeToIndex(ty, mut.mod, kind),
                };
            }

            pub fn indexToCType(self: @This(), index: Index) ?CType {
                return if (self.getSet()) |set| set.indexToCType(index) else null;
            }

            pub fn freeze(self: @This()) @This() {
                return switch (self) {
                    .fail, .imm => self,
                    .mut => |mut| .{ .imm = .{ .set = &mut.promoted.set, .target = self.getTarget() } },
                };
            }
        };

        pub fn initType(self: *@This(), ty: Type, kind: Kind, lookup: Lookup) !void {
            const target = lookup.getTarget();

            self.* = undefined;
            if (!ty.isFnOrHasRuntimeBitsIgnoreComptime())
                self.init(.void)
            else if (ty.isAbiInt()) switch (ty.tag()) {
                .usize => self.init(.size_t),
                .isize => self.init(.ptrdiff_t),
                .c_short => self.init(.short),
                .c_ushort => self.init(.@"unsigned short"),
                .c_int => self.init(.int),
                .c_uint => self.init(.@"unsigned int"),
                .c_long => self.init(.long),
                .c_ulong => self.init(.@"unsigned long"),
                .c_longlong => self.init(.@"long long"),
                .c_ulonglong => self.init(.@"unsigned long long"),
                else => {
                    const info = ty.intInfo(target);
                    const t = tagFromIntInfo(info.signedness, info.bits);
                    switch (t) {
                        .void => unreachable,
                        else => self.init(t),
                        .array => {
                            const abi_size = ty.abiSize(target);
                            const abi_align = ty.abiAlignment(target);
                            self.storage = .{ .seq = .{ .base = .{ .tag = .array }, .data = .{
                                .len = @divExact(abi_size, abi_align),
                                .elem_type = tagFromIntInfo(
                                    .unsigned,
                                    @intCast(u16, abi_align * 8),
                                ).toIndex(),
                            } } };
                            self.value = .{ .cty = initPayload(&self.storage.seq) };
                        },
                    }
                },
            } else switch (ty.zigTypeTag()) {
                .Frame => unreachable,
                .AnyFrame => unreachable,

                .Int,
                .Enum,
                .ErrorSet,
                .Type,
                .Void,
                .NoReturn,
                .ComptimeFloat,
                .ComptimeInt,
                .Undefined,
                .Null,
                .EnumLiteral,
                => unreachable,

                .Bool => self.init(.bool),

                .Float => self.init(switch (ty.tag()) {
                    .f16 => .zig_f16,
                    .f32 => .zig_f32,
                    .f64 => .zig_f64,
                    .f80 => .zig_f80,
                    .f128 => .zig_f128,
                    .c_longdouble => .@"long double",
                    else => unreachable,
                }),

                .Pointer => switch (ty.ptrSize()) {
                    .Slice => {
                        var buf: Type.SlicePtrFieldTypeBuffer = undefined;
                        const ptr_ty = ty.slicePtrFieldType(&buf);
                        if (try lookup.typeToIndex(ptr_ty, kind)) |ptr_idx| {
                            self.storage = .{ .anon = .{ .fields = .{
                                .{
                                    .name = "ptr",
                                    .type = ptr_idx,
                                    .alignas = ptr_ty.abiAlignment(target),
                                },
                                .{
                                    .name = "len",
                                    .type = Tag.size_t.toIndex(),
                                    .alignas = Type.usize.abiAlignment(target),
                                },
                            }, .pl = undefined } };
                            self.storage.anon.pl = .{
                                .base = .{ .tag = .anon_struct },
                                .data = self.storage.anon.fields[0..2],
                            };
                            self.value = .{ .cty = initPayload(&self.storage.anon.pl) };
                        } else self.init(.anon_struct);
                    },

                    .One, .Many, .C => {
                        const t: Tag = switch (ty.isVolatilePtr()) {
                            false => switch (ty.isConstPtr()) {
                                false => .pointer,
                                true => .pointer_const,
                            },
                            true => switch (ty.isConstPtr()) {
                                false => .pointer_volatile,
                                true => .pointer_const_volatile,
                            },
                        };
                        if (try lookup.typeToIndex(ty.childType(), .forward)) |child_idx| {
                            self.storage = .{ .child = .{ .base = .{ .tag = t }, .data = child_idx } };
                            self.value = .{ .cty = initPayload(&self.storage.child) };
                        } else self.init(t);
                    },
                },

                .Struct, .Union => |zig_tag| if (ty.isTupleOrAnonStruct()) {
                    if (lookup.isMutable()) {
                        for (0..ty.structFieldCount()) |field_i| {
                            const field_ty = ty.structFieldType(field_i);
                            if (ty.structFieldIsComptime(field_i) or
                                !field_ty.hasRuntimeBitsIgnoreComptime()) continue;
                            _ = try lookup.typeToIndex(field_ty, switch (kind) {
                                .forward, .complete, .parameter => .complete,
                                .global => .global,
                            });
                        }
                    }
                    self.init(.anon_struct);
                } else {
                    const is_struct = zig_tag == .Struct or ty.unionTagTypeSafety() != null;
                    switch (kind) {
                        .forward => {
                            self.storage = .{ .fwd = .{
                                .base = .{ .tag = if (is_struct) .fwd_struct else .fwd_union },
                                .data = ty.getOwnerDecl(),
                            } };
                            self.value = .{ .cty = initPayload(&self.storage.fwd) };
                        },
                        else => {
                            if (lookup.isMutable()) {
                                for (0..switch (zig_tag) {
                                    .Struct => ty.structFieldCount(),
                                    .Union => ty.cast(Type.Payload.Union).?.data.fields.count(),
                                    else => unreachable,
                                }) |field_i| {
                                    const field_ty = ty.structFieldType(field_i);
                                    if (!field_ty.hasRuntimeBitsIgnoreComptime()) continue;
                                    _ = try lookup.typeToIndex(field_ty, switch (kind) {
                                        .forward => unreachable,
                                        .complete, .parameter => .complete,
                                        .global => .global,
                                    });
                                }
                                _ = try lookup.typeToIndex(ty, .forward);
                            }
                            self.init(if (is_struct) .@"struct" else .@"union");
                        },
                    }
                },

                .Array, .Vector => |zig_tag| {
                    const t: Tag = switch (zig_tag) {
                        .Array => .array,
                        .Vector => .vector,
                        else => unreachable,
                    };
                    if (try lookup.typeToIndex(ty.childType(), kind)) |child_idx| {
                        self.storage = .{ .seq = .{ .base = .{ .tag = t }, .data = .{
                            .len = ty.arrayLenIncludingSentinel(),
                            .elem_type = child_idx,
                        } } };
                        self.value = .{ .cty = initPayload(&self.storage.seq) };
                    } else self.init(t);
                },

                .Optional => {
                    var buf: Type.Payload.ElemType = undefined;
                    const payload_ty = ty.optionalChild(&buf);
                    if (payload_ty.hasRuntimeBitsIgnoreComptime()) {
                        if (ty.optionalReprIsPayload())
                            try self.initType(payload_ty, kind, lookup)
                        else if (try lookup.typeToIndex(payload_ty, kind)) |payload_idx| {
                            self.storage = .{ .anon = .{ .fields = .{
                                .{
                                    .name = "payload",
                                    .type = payload_idx,
                                    .alignas = payload_ty.abiAlignment(target),
                                },
                                .{
                                    .name = "is_null",
                                    .type = Tag.bool.toIndex(),
                                    .alignas = Type.bool.abiAlignment(target),
                                },
                            }, .pl = undefined } };
                            self.storage.anon.pl = .{
                                .base = .{ .tag = .anon_struct },
                                .data = self.storage.anon.fields[0..2],
                            };
                            self.value = .{ .cty = initPayload(&self.storage.anon.pl) };
                        } else self.init(.anon_struct);
                    } else self.init(.bool);
                },

                .ErrorUnion => {
                    const payload_ty = ty.errorUnionPayload();
                    if (try lookup.typeToIndex(payload_ty, switch (kind) {
                        .forward, .complete, .parameter => .complete,
                        .global => .global,
                    })) |payload_idx| {
                        const error_ty = ty.errorUnionSet();
                        if (payload_idx == Tag.void.toIndex())
                            try self.initType(error_ty, kind, lookup)
                        else if (try lookup.typeToIndex(error_ty, kind)) |error_idx| {
                            self.storage = .{ .anon = .{ .fields = .{
                                .{
                                    .name = "payload",
                                    .type = payload_idx,
                                    .alignas = payload_ty.abiAlignment(target),
                                },
                                .{
                                    .name = "error",
                                    .type = error_idx,
                                    .alignas = error_ty.abiAlignment(target),
                                },
                            }, .pl = undefined } };
                            self.storage.anon.pl = .{
                                .base = .{ .tag = .anon_struct },
                                .data = self.storage.anon.fields[0..2],
                            };
                            self.value = .{ .cty = initPayload(&self.storage.anon.pl) };
                        } else self.init(.anon_struct);
                    } else self.init(.anon_struct);
                },

                .Opaque => switch (ty.tag()) {
                    .anyopaque => self.init(.void),
                    .@"opaque" => {
                        self.storage = .{ .fwd = .{
                            .base = .{ .tag = .fwd_struct },
                            .data = ty.getOwnerDecl(),
                        } };
                        self.value = .{ .cty = initPayload(&self.storage.fwd) };
                    },
                    else => unreachable,
                },

                .Fn => {
                    const info = ty.fnInfo();
                    if (lookup.isMutable()) {
                        _ = try lookup.typeToIndex(info.return_type, switch (kind) {
                            .forward => .forward,
                            .complete, .parameter, .global => .complete,
                        });
                        for (info.param_types) |param_type| {
                            if (!param_type.hasRuntimeBitsIgnoreComptime()) continue;
                            _ = try lookup.typeToIndex(param_type, switch (kind) {
                                .forward => .forward,
                                .complete, .parameter, .global => unreachable,
                            });
                        }
                    }
                    self.init(if (info.is_var_args) .varargs_function else .function);
                },
            }
        }
    };

    fn copyFields(arena: Allocator, fields: Payload.Fields.Data) !Payload.Fields.Data {
        const new_fields = try arena.dupe(Payload.Fields.Field, fields);
        for (new_fields) |*new_field| {
            new_field.name = try arena.dupeZ(u8, mem.span(new_field.name));
            new_field.type = new_field.type;
        }
        return new_fields;
    }

    pub fn copy(self: CType, arena: Allocator) !CType {
        switch (self.tag()) {
            .void,
            .char,
            .@"signed char",
            .short,
            .int,
            .long,
            .@"long long",
            ._Bool,
            .@"unsigned char",
            .@"unsigned short",
            .@"unsigned int",
            .@"unsigned long",
            .@"unsigned long long",
            .float,
            .double,
            .@"long double",
            .bool,
            .size_t,
            .ptrdiff_t,
            .zig_u8,
            .zig_i8,
            .zig_u16,
            .zig_i16,
            .zig_u32,
            .zig_i32,
            .zig_u64,
            .zig_i64,
            .zig_u128,
            .zig_i128,
            .zig_f16,
            .zig_f32,
            .zig_f64,
            .zig_f80,
            .zig_f128,
            => return self,

            .pointer,
            .pointer_const,
            .pointer_volatile,
            .pointer_const_volatile,
            => {
                const pl = self.cast(Payload.Child).?;
                const new_pl = try arena.create(Payload.Child);
                new_pl.* = .{ .base = .{ .tag = pl.base.tag }, .data = pl.data };
                return initPayload(new_pl);
            },

            .array,
            .vector,
            => {
                const pl = self.cast(Payload.Sequence).?;
                const new_pl = try arena.create(Payload.Sequence);
                new_pl.* = .{
                    .base = .{ .tag = pl.base.tag },
                    .data = .{ .len = pl.data.len, .elem_type = pl.data.elem_type },
                };
                return initPayload(new_pl);
            },

            .fwd_struct,
            .fwd_union,
            => {
                const pl = self.cast(Payload.FwdDecl).?;
                const new_pl = try arena.create(Payload.FwdDecl);
                new_pl.* = .{
                    .base = .{ .tag = pl.base.tag },
                    .data = pl.data,
                };
                return initPayload(new_pl);
            },

            .anon_struct,
            .packed_anon_struct,
            => {
                const pl = self.cast(Payload.Fields).?;
                const new_pl = try arena.create(Payload.Fields);
                new_pl.* = .{
                    .base = .{ .tag = pl.base.tag },
                    .data = try copyFields(arena, pl.data),
                };
                return initPayload(new_pl);
            },

            .@"struct",
            .@"union",
            .packed_struct,
            .packed_union,
            => {
                const pl = self.cast(Payload.Aggregate).?;
                const new_pl = try arena.create(Payload.Aggregate);
                new_pl.* = .{ .base = .{ .tag = pl.base.tag }, .data = .{
                    .fields = try copyFields(arena, pl.data.fields),
                    .fwd_decl = pl.data.fwd_decl,
                } };
                return initPayload(new_pl);
            },

            .function,
            .varargs_function,
            => {
                const pl = self.cast(Payload.Function).?;
                const new_pl = try arena.create(Payload.Function);
                new_pl.* = .{ .base = .{ .tag = pl.base.tag }, .data = .{
                    .return_type = pl.data.return_type,
                    .param_types = try arena.dupe(Index, pl.data.param_types),
                } };
                return initPayload(new_pl);
            },
        }
    }

    fn createFromType(store: *Store.Promoted, ty: Type, target: Target, kind: Kind) !CType {
        var convert: Convert = undefined;
        try convert.initType(ty, kind, .{ .imm = .{ .set = &store.set, .target = target } });
        return createFromConvert(store, ty, target, kind, &convert);
    }

    fn createFromConvert(
        store: *Store.Promoted,
        ty: Type,
        target: Target,
        kind: Kind,
        convert: Convert,
    ) !CType {
        const arena = store.arena.allocator();
        switch (convert.value) {
            .cty => |c| return c.copy(arena),
            .tag => |t| switch (t) {
                .anon_struct,
                .packed_anon_struct,
                .@"struct",
                .@"union",
                .packed_struct,
                .packed_union,
                => switch (ty.zigTypeTag()) {
                    .Struct => {
                        const fields_len = ty.structFieldCount();

                        var c_fields_len: usize = 0;
                        for (0..fields_len) |field_i| {
                            const field_ty = ty.structFieldType(field_i);
                            if (ty.structFieldIsComptime(field_i) or
                                !field_ty.hasRuntimeBitsIgnoreComptime()) continue;
                            c_fields_len += 1;
                        }

                        const fields_pl = try arena.alloc(Payload.Fields.Field, c_fields_len);
                        var c_field_i: usize = 0;
                        for (0..fields_len) |field_i| {
                            const field_ty = ty.structFieldType(field_i);
                            if (ty.structFieldIsComptime(field_i) or
                                !field_ty.hasRuntimeBitsIgnoreComptime()) continue;

                            fields_pl[c_field_i] = .{
                                .name = try if (ty.isSimpleTuple())
                                    std.fmt.allocPrintZ(arena, "f{}", .{field_i})
                                else
                                    arena.dupeZ(u8, ty.structFieldName(field_i)),
                                .type = store.set.typeToIndex(field_ty, target, switch (kind) {
                                    .forward, .complete, .parameter => .complete,
                                    .global => .global,
                                }).?,
                                .alignas = ty.structFieldAlign(field_i, target),
                            };
                            c_field_i += 1;
                        }

                        if (ty.isTupleOrAnonStruct()) {
                            const anon_pl = try arena.create(Payload.Fields);
                            anon_pl.* = .{ .base = .{ .tag = .anon_struct }, .data = fields_pl };
                            return initPayload(anon_pl);
                        }

                        const struct_pl = try arena.create(Payload.Aggregate);
                        struct_pl.* = .{ .base = .{ .tag = t }, .data = .{
                            .fields = fields_pl,
                            .fwd_decl = store.set.typeToIndex(ty, target, .forward).?,
                        } };
                        return initPayload(struct_pl);
                    },

                    .Union => {
                        const fields = ty.unionFields();
                        const fields_len = fields.count();

                        var c_fields_len: usize = 0;
                        for (0..fields_len) |field_i| {
                            const field_ty = ty.structFieldType(field_i);
                            if (!field_ty.hasRuntimeBitsIgnoreComptime()) continue;
                            c_fields_len += 1;
                        }

                        const fields_pl = try arena.alloc(Payload.Fields.Field, c_fields_len);
                        var field_i: usize = 0;
                        var c_field_i: usize = 0;
                        var field_it = fields.iterator();
                        while (field_it.next()) |field| {
                            defer field_i += 1;
                            if (!field.value_ptr.ty.hasRuntimeBitsIgnoreComptime()) continue;

                            fields_pl[c_field_i] = .{
                                .name = try arena.dupeZ(u8, field.key_ptr.*),
                                .type = store.set.typeToIndex(field.value_ptr.ty, target, switch (kind) {
                                    .forward => unreachable,
                                    .complete, .parameter => .complete,
                                    .global => .global,
                                }).?,
                                .alignas = ty.structFieldAlign(field_i, target),
                            };
                            c_field_i += 1;
                        }

                        const union_pl = try arena.create(Payload.Aggregate);
                        union_pl.* = .{ .base = .{ .tag = t }, .data = .{
                            .fields = fields_pl,
                            .fwd_decl = store.set.typeToIndex(ty, target, .forward).?,
                        } };
                        return initPayload(union_pl);
                    },

                    else => unreachable,
                },

                .function,
                .varargs_function,
                => {
                    const info = ty.fnInfo();
                    const recurse_kind: Kind = switch (kind) {
                        .forward => .forward,
                        .complete, .parameter, .global => unreachable,
                    };

                    var c_params_len: usize = 0;
                    for (info.param_types) |param_type| {
                        if (!param_type.hasRuntimeBitsIgnoreComptime()) continue;
                        c_params_len += 1;
                    }

                    const params_pl = try arena.alloc(Index, c_params_len);
                    var c_param_i: usize = 0;
                    for (info.param_types) |param_type| {
                        if (!param_type.hasRuntimeBitsIgnoreComptime()) continue;
                        params_pl[c_param_i] = store.set.typeToIndex(param_type, target, recurse_kind).?;
                        c_param_i += 1;
                    }

                    const fn_pl = try arena.create(Payload.Function);
                    fn_pl.* = .{ .base = .{ .tag = t }, .data = .{
                        .return_type = store.set.typeToIndex(info.return_type, target, recurse_kind).?,
                        .param_types = params_pl,
                    } };
                    return initPayload(fn_pl);
                },

                else => unreachable,
            },
        }
    }

    pub const HashContext64 = struct {
        store: *const Store.Set,

        pub fn hash(_: @This(), cty: CType) u64 {
            return cty.hash();
        }
        pub fn eql(_: @This(), lhs: CType, rhs: CType) bool {
            return lhs.eql(rhs);
        }
    };

    pub const HashContext32 = struct {
        store: *const Store.Set,

        pub fn hash(self: @This(), cty: CType) u32 {
            return @truncate(u32, cty.hash(self.store.*));
        }
        pub fn eql(_: @This(), lhs: CType, rhs: CType, _: usize) bool {
            return lhs.eql(rhs);
        }
    };

    pub const TypeAdapter64 = struct {
        kind: Kind,
        lookup: Convert.Lookup,
        convert: *const Convert,

        fn eqlRecurse(self: @This(), ty: Type, cty: Index, kind: Kind) bool {
            assert(!self.lookup.isMutable());

            var convert: Convert = undefined;
            convert.initType(ty, kind, self.lookup) catch unreachable;

            const self_recurse = @This(){ .kind = kind, .lookup = self.lookup, .convert = &convert };
            return self_recurse.eql(ty, self.lookup.indexToCType(cty).?);
        }

        pub fn eql(self: @This(), ty: Type, cty: CType) bool {
            switch (self.convert.value) {
                .cty => |c| return c.eql(cty),
                .tag => |t| {
                    if (t != cty.tag()) return false;

                    const target = self.lookup.getTarget();
                    switch (t) {
                        .anon_struct,
                        .packed_anon_struct,
                        => {
                            if (!ty.isTupleOrAnonStruct()) return false;

                            var name_buf: [
                                std.fmt.count("f{}", .{std.math.maxInt(usize)})
                            ]u8 = undefined;
                            const c_fields = cty.cast(Payload.Fields).?.data;

                            var c_field_i: usize = 0;
                            for (0..ty.structFieldCount()) |field_i| {
                                const field_ty = ty.structFieldType(field_i);
                                if (ty.structFieldIsComptime(field_i) or
                                    !field_ty.hasRuntimeBitsIgnoreComptime()) continue;

                                const c_field = &c_fields[c_field_i];
                                c_field_i += 1;

                                if (!self.eqlRecurse(
                                    ty.structFieldType(field_i),
                                    c_field.type,
                                    switch (self.kind) {
                                        .forward, .complete, .parameter => .complete,
                                        .global => .global,
                                    },
                                ) or !mem.eql(
                                    u8,
                                    if (ty.isSimpleTuple())
                                        std.fmt.bufPrint(&name_buf, "f{}", .{field_i}) catch unreachable
                                    else
                                        ty.structFieldName(field_i),
                                    mem.span(c_field.name),
                                ) or ty.structFieldAlign(field_i, target) != c_field.alignas)
                                    return false;
                            }
                            return true;
                        },

                        .@"struct",
                        .@"union",
                        .packed_struct,
                        .packed_union,
                        => return self.eqlRecurse(
                            ty,
                            cty.cast(Payload.Aggregate).?.data.fwd_decl,
                            .forward,
                        ),

                        .function,
                        .varargs_function,
                        => {
                            if (ty.zigTypeTag() != .Fn) return false;

                            const info = ty.fnInfo();
                            const data = cty.cast(Payload.Function).?.data;
                            const recurse_kind: Kind = switch (self.kind) {
                                .forward => .forward,
                                .complete, .parameter, .global => unreachable,
                            };

                            if (info.param_types.len != data.param_types.len or
                                !self.eqlRecurse(info.return_type, data.return_type, recurse_kind))
                                return false;
                            for (info.param_types, data.param_types) |param_ty, param_cty| {
                                if (!param_ty.hasRuntimeBitsIgnoreComptime()) continue;
                                if (!self.eqlRecurse(param_ty, param_cty, recurse_kind)) return false;
                            }
                            return true;
                        },

                        else => unreachable,
                    }
                },
            }
        }

        pub fn hash(self: @This(), ty: Type) u64 {
            var hasher = std.hash.Wyhash.init(0);
            self.updateHasher(&hasher, ty);
            return hasher.final();
        }

        fn updateHasherRecurse(self: @This(), hasher: anytype, ty: Type, kind: Kind) void {
            assert(!self.lookup.isMutable());

            var convert: Convert = undefined;
            convert.initType(ty, kind, self.lookup) catch unreachable;

            const self_recurse = @This(){ .kind = kind, .lookup = self.lookup, .convert = &convert };
            self_recurse.updateHasher(hasher, ty);
        }

        pub fn updateHasher(self: @This(), hasher: anytype, ty: Type) void {
            switch (self.convert.value) {
                .cty => |c| return c.updateHasher(hasher, self.lookup.getSet().?.*),
                .tag => |t| {
                    autoHash(hasher, t);

                    const target = self.lookup.getTarget();
                    switch (t) {
                        .anon_struct,
                        .packed_anon_struct,
                        => {
                            var name_buf: [
                                std.fmt.count("f{}", .{std.math.maxInt(usize)})
                            ]u8 = undefined;
                            for (0..ty.structFieldCount()) |field_i| {
                                const field_ty = ty.structFieldType(field_i);
                                if (ty.structFieldIsComptime(field_i) or
                                    !field_ty.hasRuntimeBitsIgnoreComptime()) continue;

                                self.updateHasherRecurse(
                                    hasher,
                                    ty.structFieldType(field_i),
                                    switch (self.kind) {
                                        .forward, .complete, .parameter => .complete,
                                        .global => .global,
                                    },
                                );
                                hasher.update(if (ty.isSimpleTuple())
                                    std.fmt.bufPrint(&name_buf, "f{}", .{field_i}) catch unreachable
                                else
                                    ty.structFieldName(field_i));
                                autoHash(hasher, ty.structFieldAlign(field_i, target));
                            }
                        },

                        .@"struct",
                        .@"union",
                        .packed_struct,
                        .packed_union,
                        => self.updateHasherRecurse(hasher, ty, .forward),

                        .function,
                        .varargs_function,
                        => {
                            const info = ty.fnInfo();
                            const recurse_kind: Kind = switch (self.kind) {
                                .forward => .forward,
                                .complete, .parameter, .global => unreachable,
                            };

                            self.updateHasherRecurse(hasher, info.return_type, recurse_kind);
                            for (info.param_types) |param_type| {
                                if (!param_type.hasRuntimeBitsIgnoreComptime()) continue;
                                self.updateHasherRecurse(hasher, param_type, recurse_kind);
                            }
                        },

                        else => unreachable,
                    }
                },
            }
        }
    };

    pub const TypeAdapter32 = struct {
        kind: Kind,
        lookup: Convert.Lookup,
        convert: *const Convert,

        fn to64(self: @This()) TypeAdapter64 {
            return .{ .kind = self.kind, .lookup = self.lookup, .convert = self.convert };
        }

        pub fn eql(self: @This(), ty: Type, cty: CType, cty_index: usize) bool {
            _ = cty_index;
            return self.to64().eql(ty, cty);
        }

        pub fn hash(self: @This(), ty: Type) u32 {
            return @truncate(u32, self.to64().hash(ty));
        }
    };
};
