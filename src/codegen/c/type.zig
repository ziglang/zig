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
        //  - stdbool.h
        bool,
        //  - stddef.h
        size_t,
        ptrdiff_t,
        //  - stdint.h
        uint8_t,
        int8_t,
        uint16_t,
        int16_t,
        uint32_t,
        int32_t,
        uint64_t,
        int64_t,
        uintptr_t,
        intptr_t,

        // zig.h types
        zig_u128,
        zig_i128,
        zig_f16,
        zig_f32,
        zig_f64,
        zig_f80,
        zig_f128,
        zig_c_longdouble, // Keep last_no_payload_tag updated!

        // After this, the tag requires a payload.
        pointer,
        pointer_const,
        pointer_volatile,
        pointer_const_volatile,
        array,
        vector,
        fwd_anon_struct,
        fwd_anon_union,
        fwd_struct,
        fwd_union,
        unnamed_struct,
        unnamed_union,
        packed_unnamed_struct,
        packed_unnamed_union,
        anon_struct,
        anon_union,
        @"struct",
        @"union",
        packed_struct,
        packed_union,
        function,
        varargs_function,

        pub const last_no_payload_tag = Tag.zig_c_longdouble;
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
                .uint8_t,
                .int8_t,
                .uint16_t,
                .int16_t,
                .uint32_t,
                .int32_t,
                .uint64_t,
                .int64_t,
                .uintptr_t,
                .intptr_t,
                .zig_u128,
                .zig_i128,
                .zig_f16,
                .zig_f32,
                .zig_f64,
                .zig_f80,
                .zig_f128,
                .zig_c_longdouble,
                => @compileError("Type Tag " ++ @tagName(self) ++ " has no payload"),

                .pointer,
                .pointer_const,
                .pointer_volatile,
                .pointer_const_volatile,
                => Payload.Child,

                .array,
                .vector,
                => Payload.Sequence,

                .fwd_anon_struct,
                .fwd_anon_union,
                => Payload.Fields,

                .fwd_struct,
                .fwd_union,
                => Payload.FwdDecl,

                .unnamed_struct,
                .unnamed_union,
                .packed_unnamed_struct,
                .packed_unnamed_union,
                => Payload.Unnamed,

                .anon_struct,
                .anon_union,
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

            pub const Data = []const Field;
            pub const Field = struct {
                name: [*:0]const u8,
                type: Index,
                alignas: AlignAs,
            };
            pub const AlignAs = struct {
                @"align": std.math.Log2Int(u32),
                abi: std.math.Log2Int(u32),

                pub fn init(alignment: u32, abi_alignment: u32) AlignAs {
                    assert(std.math.isPowerOfTwo(alignment));
                    assert(std.math.isPowerOfTwo(abi_alignment));
                    return .{
                        .@"align" = std.math.log2_int(u32, alignment),
                        .abi = std.math.log2_int(u32, abi_alignment),
                    };
                }
                pub fn abiAlign(ty: Type, target: Target) AlignAs {
                    const abi_align = ty.abiAlignment(target);
                    return init(abi_align, abi_align);
                }
                pub fn fieldAlign(struct_ty: Type, field_i: usize, target: Target) AlignAs {
                    return init(
                        struct_ty.structFieldAlign(field_i, target),
                        struct_ty.structFieldType(field_i).abiAlignment(target),
                    );
                }
                pub fn unionPayloadAlign(union_ty: Type, target: Target) AlignAs {
                    const union_obj = union_ty.cast(Type.Payload.Union).?.data;
                    const union_payload_align = union_obj.abiAlignment(target, false);
                    return init(union_payload_align, union_payload_align);
                }

                pub fn getAlign(self: AlignAs) u32 {
                    return @as(u32, 1) << self.@"align";
                }
            };
        };

        pub const Unnamed = struct {
            base: Payload,
            data: struct {
                fields: Fields.Data,
                owner_decl: Module.Decl.Index,
                id: u32,
            },
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

        pub const Set = struct {
            pub const Map = std.ArrayHashMapUnmanaged(CType, void, HashContext32, true);

            map: Map = .{},

            pub fn indexToCType(self: Set, index: Index) CType {
                if (index < Tag.no_payload_count) return initTag(@intToEnum(Tag, index));
                return self.map.keys()[index - Tag.no_payload_count];
            }

            pub fn indexToHash(self: Set, index: Index) Map.Hash {
                if (index < Tag.no_payload_count)
                    return (HashContext32{ .store = &self }).hash(self.indexToCType(index));
                return self.map.entries.items(.hash)[index - Tag.no_payload_count];
            }

            pub fn typeToIndex(self: Set, ty: Type, target: Target, kind: Kind) ?Index {
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

        pub const Promoted = struct {
            arena: std.heap.ArenaAllocator,
            set: Set,

            pub fn gpa(self: *Promoted) Allocator {
                return self.arena.child_allocator;
            }

            pub fn cTypeToIndex(self: *Promoted, cty: CType) Allocator.Error!Index {
                const t = cty.tag();
                if (@enumToInt(t) < Tag.no_payload_count) return @intCast(Index, @enumToInt(t));

                const gop = try self.set.map.getOrPutContext(self.gpa(), cty, .{ .store = &self.set });
                if (!gop.found_existing) gop.key_ptr.* = cty;
                if (std.debug.runtime_safety) {
                    const key = &self.set.map.entries.items(.key)[gop.index];
                    assert(key == gop.key_ptr);
                    assert(cty.eql(key.*));
                    assert(cty.hash(self.set) == key.hash(self.set));
                }
                return @intCast(Index, Tag.no_payload_count + gop.index);
            }

            pub fn typeToIndex(
                self: *Promoted,
                ty: Type,
                mod: *Module,
                kind: Kind,
            ) Allocator.Error!Index {
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
                    const cty = &self.set.map.entries.items(.key)[gop.index];
                    assert(cty == gop.key_ptr);
                    assert(adapter.eql(ty, cty.*));
                    assert(adapter.hash(ty) == cty.hash(self.set));
                }
                return @intCast(Index, Tag.no_payload_count + gop.index);
            }
        };

        pub fn promote(self: Store, gpa: Allocator) Promoted {
            return .{ .arena = self.arena.promote(gpa), .set = self.set };
        }

        pub fn demote(self: *Store, promoted: Promoted) void {
            self.arena = promoted.arena.state;
            self.set = promoted.set;
        }

        pub fn indexToCType(self: Store, index: Index) CType {
            return self.set.indexToCType(index);
        }

        pub fn indexToHash(self: Store, index: Index) Set.Map.Hash {
            return self.set.indexToHash(index);
        }

        pub fn cTypeToIndex(self: *Store, gpa: Allocator, cty: CType) !Index {
            var promoted = self.promote(gpa);
            defer self.demote(promoted);
            return promoted.cTypeToIndex(cty);
        }

        pub fn typeToCType(self: *Store, gpa: Allocator, ty: Type, mod: *Module, kind: Kind) !CType {
            const idx = try self.typeToIndex(gpa, ty, mod, kind);
            return self.indexToCType(idx);
        }

        pub fn typeToIndex(self: *Store, gpa: Allocator, ty: Type, mod: *Module, kind: Kind) !Index {
            var promoted = self.promote(gpa);
            defer self.demote(promoted);
            return promoted.typeToIndex(ty, mod, kind);
        }

        pub fn clearRetainingCapacity(self: *Store, gpa: Allocator) void {
            var promoted = self.promote(gpa);
            defer self.demote(promoted);
            promoted.set.map.clearRetainingCapacity();
            _ = promoted.arena.reset(.retain_capacity);
        }

        pub fn clearAndFree(self: *Store, gpa: Allocator) void {
            var promoted = self.promote(gpa);
            defer self.demote(promoted);
            promoted.set.map.clearAndFree(gpa);
            _ = promoted.arena.reset(.free_all);
        }

        pub fn shrinkRetainingCapacity(self: *Store, gpa: Allocator, new_len: usize) void {
            self.set.map.shrinkRetainingCapacity(gpa, new_len);
        }

        pub fn shrinkAndFree(self: *Store, gpa: Allocator, new_len: usize) void {
            self.set.map.shrinkAndFree(gpa, new_len);
        }

        pub fn count(self: Store) usize {
            return self.set.map.count();
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

    pub fn isPacked(self: CType) bool {
        return switch (self.tag()) {
            else => false,
            .packed_unnamed_struct,
            .packed_unnamed_union,
            .packed_struct,
            .packed_union,
            => true,
        };
    }

    pub fn fields(self: CType) Payload.Fields.Data {
        return if (self.cast(Payload.Aggregate)) |pl|
            pl.data.fields
        else if (self.cast(Payload.Unnamed)) |pl|
            pl.data.fields
        else if (self.cast(Payload.Fields)) |pl|
            pl.data
        else
            unreachable;
    }

    pub fn eql(lhs: CType, rhs: CType) bool {
        return lhs.eqlContext(rhs, struct {
            pub fn eqlIndex(_: @This(), lhs_idx: Index, rhs_idx: Index) bool {
                return lhs_idx == rhs_idx;
            }
        }{});
    }

    pub fn eqlContext(lhs: CType, rhs: CType, ctx: anytype) bool {
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
            .uint8_t,
            .int8_t,
            .uint16_t,
            .int16_t,
            .uint32_t,
            .int32_t,
            .uint64_t,
            .int64_t,
            .uintptr_t,
            .intptr_t,
            .zig_u128,
            .zig_i128,
            .zig_f16,
            .zig_f32,
            .zig_f64,
            .zig_f80,
            .zig_f128,
            .zig_c_longdouble,
            => false,

            .pointer,
            .pointer_const,
            .pointer_volatile,
            .pointer_const_volatile,
            => ctx.eqlIndex(lhs.cast(Payload.Child).?.data, rhs.cast(Payload.Child).?.data),

            .array,
            .vector,
            => {
                const lhs_data = lhs.cast(Payload.Sequence).?.data;
                const rhs_data = rhs.cast(Payload.Sequence).?.data;
                return lhs_data.len == rhs_data.len and
                    ctx.eqlIndex(lhs_data.elem_type, rhs_data.elem_type);
            },

            .fwd_anon_struct,
            .fwd_anon_union,
            => {
                const lhs_data = lhs.cast(Payload.Fields).?.data;
                const rhs_data = rhs.cast(Payload.Fields).?.data;
                if (lhs_data.len != rhs_data.len) return false;
                for (lhs_data, rhs_data) |lhs_field, rhs_field| {
                    if (!ctx.eqlIndex(lhs_field.type, rhs_field.type)) return false;
                    if (lhs_field.alignas.@"align" != rhs_field.alignas.@"align") return false;
                    if (cstr.cmp(lhs_field.name, rhs_field.name) != 0) return false;
                }
                return true;
            },

            .fwd_struct,
            .fwd_union,
            => lhs.cast(Payload.FwdDecl).?.data == rhs.cast(Payload.FwdDecl).?.data,

            .unnamed_struct,
            .unnamed_union,
            .packed_unnamed_struct,
            .packed_unnamed_union,
            => {
                const lhs_data = lhs.cast(Payload.Unnamed).?.data;
                const rhs_data = rhs.cast(Payload.Unnamed).?.data;
                return lhs_data.owner_decl == rhs_data.owner_decl and lhs_data.id == rhs_data.id;
            },

            .anon_struct,
            .anon_union,
            .@"struct",
            .@"union",
            .packed_struct,
            .packed_union,
            => ctx.eqlIndex(
                lhs.cast(Payload.Aggregate).?.data.fwd_decl,
                rhs.cast(Payload.Aggregate).?.data.fwd_decl,
            ),

            .function,
            .varargs_function,
            => {
                const lhs_data = lhs.cast(Payload.Function).?.data;
                const rhs_data = rhs.cast(Payload.Function).?.data;
                if (lhs_data.param_types.len != rhs_data.param_types.len) return false;
                if (!ctx.eqlIndex(lhs_data.return_type, rhs_data.return_type)) return false;
                for (lhs_data.param_types, rhs_data.param_types) |lhs_param_idx, rhs_param_idx| {
                    if (!ctx.eqlIndex(lhs_param_idx, rhs_param_idx)) return false;
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
            .uint8_t,
            .int8_t,
            .uint16_t,
            .int16_t,
            .uint32_t,
            .int32_t,
            .uint64_t,
            .int64_t,
            .uintptr_t,
            .intptr_t,
            .zig_u128,
            .zig_i128,
            .zig_f16,
            .zig_f32,
            .zig_f64,
            .zig_f80,
            .zig_f128,
            .zig_c_longdouble,
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

            .fwd_anon_struct,
            .fwd_anon_union,
            => for (self.cast(Payload.Fields).?.data) |field| {
                store.indexToCType(field.type).updateHasher(hasher, store);
                hasher.update(mem.span(field.name));
                autoHash(hasher, field.alignas.@"align");
            },

            .fwd_struct,
            .fwd_union,
            => autoHash(hasher, self.cast(Payload.FwdDecl).?.data),

            .unnamed_struct,
            .unnamed_union,
            .packed_unnamed_struct,
            .packed_unnamed_union,
            => {
                const data = self.cast(Payload.Unnamed).?.data;
                autoHash(hasher, data.owner_decl);
                autoHash(hasher, data.id);
            },

            .anon_struct,
            .anon_union,
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

    pub const Kind = enum { forward, forward_parameter, complete, global, parameter, payload };

    const Convert = struct {
        storage: union {
            none: void,
            child: Payload.Child,
            seq: Payload.Sequence,
            fwd: Payload.FwdDecl,
            anon: struct {
                fields: [2]Payload.Fields.Field,
                pl: union {
                    forward: Payload.Fields,
                    complete: Payload.Aggregate,
                },
            },
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
                    .unsigned => .uint8_t,
                    .signed => .int8_t,
                },
                9...16 => switch (signedness) {
                    .unsigned => .uint16_t,
                    .signed => .int16_t,
                },
                17...32 => switch (signedness) {
                    .unsigned => .uint32_t,
                    .signed => .int32_t,
                },
                33...64 => switch (signedness) {
                    .unsigned => .uint64_t,
                    .signed => .int64_t,
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

        fn sortFields(self: *@This(), fields_len: usize) []Payload.Fields.Field {
            const Field = Payload.Fields.Field;
            const slice = self.storage.anon.fields[0..fields_len];
            std.sort.sort(Field, slice, {}, struct {
                fn before(_: void, lhs: Field, rhs: Field) bool {
                    return lhs.alignas.@"align" > rhs.alignas.@"align";
                }
            }.before);
            return slice;
        }

        fn initAnon(self: *@This(), kind: Kind, fwd_idx: Index, fields_len: usize) void {
            switch (kind) {
                .forward, .forward_parameter => {
                    self.storage.anon.pl = .{ .forward = .{
                        .base = .{ .tag = .fwd_anon_struct },
                        .data = self.sortFields(fields_len),
                    } };
                    self.value = .{ .cty = initPayload(&self.storage.anon.pl.forward) };
                },
                .complete, .parameter, .global => {
                    self.storage.anon.pl = .{ .complete = .{
                        .base = .{ .tag = .anon_struct },
                        .data = .{
                            .fields = self.sortFields(fields_len),
                            .fwd_decl = fwd_idx,
                        },
                    } };
                    self.value = .{ .cty = initPayload(&self.storage.anon.pl.complete) };
                },
                .payload => unreachable,
            }
        }

        fn initArrayParameter(self: *@This(), ty: Type, kind: Kind, lookup: Lookup) !void {
            if (switch (kind) {
                .forward_parameter => @as(Index, undefined),
                .parameter => try lookup.typeToIndex(ty, .forward_parameter),
                .forward, .complete, .global, .payload => unreachable,
            }) |fwd_idx| {
                if (try lookup.typeToIndex(ty, switch (kind) {
                    .forward_parameter => .forward,
                    .parameter => .complete,
                    .forward, .complete, .global, .payload => unreachable,
                })) |array_idx| {
                    self.storage = .{ .anon = undefined };
                    self.storage.anon.fields[0] = .{
                        .name = "array",
                        .type = array_idx,
                        .alignas = Payload.Fields.AlignAs.abiAlign(ty, lookup.getTarget()),
                    };
                    self.initAnon(kind, fwd_idx, 1);
                } else self.init(switch (kind) {
                    .forward_parameter => .fwd_anon_struct,
                    .parameter => .anon_struct,
                    .forward, .complete, .global, .payload => unreachable,
                });
            } else self.init(.anon_struct);
        }

        pub fn initType(self: *@This(), ty: Type, kind: Kind, lookup: Lookup) !void {
            const target = lookup.getTarget();

            self.* = undefined;
            if (!ty.isFnOrHasRuntimeBitsIgnoreComptime())
                self.init(.void)
            else if (ty.isAbiInt()) switch (ty.tag()) {
                .usize => self.init(.uintptr_t),
                .isize => self.init(.intptr_t),
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
                        .array => switch (kind) {
                            .forward, .complete, .global => {
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
                            .forward_parameter,
                            .parameter,
                            => try self.initArrayParameter(ty, kind, lookup),
                            .payload => unreachable,
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
                    .c_longdouble => .zig_c_longdouble,
                    else => unreachable,
                }),

                .Pointer => {
                    const info = ty.ptrInfo().data;
                    switch (info.size) {
                        .Slice => {
                            if (switch (kind) {
                                .forward, .forward_parameter => @as(Index, undefined),
                                .complete, .parameter, .global => try lookup.typeToIndex(ty, .forward),
                                .payload => unreachable,
                            }) |fwd_idx| {
                                var buf: Type.SlicePtrFieldTypeBuffer = undefined;
                                const ptr_ty = ty.slicePtrFieldType(&buf);
                                if (try lookup.typeToIndex(ptr_ty, kind)) |ptr_idx| {
                                    self.storage = .{ .anon = undefined };
                                    self.storage.anon.fields[0] = .{
                                        .name = "ptr",
                                        .type = ptr_idx,
                                        .alignas = Payload.Fields.AlignAs.abiAlign(ptr_ty, target),
                                    };
                                    self.storage.anon.fields[1] = .{
                                        .name = "len",
                                        .type = Tag.uintptr_t.toIndex(),
                                        .alignas = Payload.Fields.AlignAs.abiAlign(Type.usize, target),
                                    };
                                    self.initAnon(kind, fwd_idx, 2);
                                } else self.init(switch (kind) {
                                    .forward, .forward_parameter => .fwd_anon_struct,
                                    .complete, .parameter, .global => .anon_struct,
                                    .payload => unreachable,
                                });
                            } else self.init(.anon_struct);
                        },

                        .One, .Many, .C => {
                            const t: Tag = switch (info.@"volatile") {
                                false => switch (info.mutable) {
                                    true => .pointer,
                                    false => .pointer_const,
                                },
                                true => switch (info.mutable) {
                                    true => .pointer_volatile,
                                    false => .pointer_const_volatile,
                                },
                            };

                            var host_int_pl = Type.Payload.Bits{
                                .base = .{ .tag = .int_unsigned },
                                .data = info.host_size * 8,
                            };
                            const pointee_ty = if (info.host_size > 0)
                                Type.initPayload(&host_int_pl.base)
                            else
                                info.pointee_type;

                            if (if (info.size == .C and pointee_ty.tag() == .u8)
                                Tag.char.toIndex()
                            else
                                try lookup.typeToIndex(pointee_ty, .forward)) |child_idx|
                            {
                                self.storage = .{ .child = .{
                                    .base = .{ .tag = t },
                                    .data = child_idx,
                                } };
                                self.value = .{ .cty = initPayload(&self.storage.child) };
                            } else self.init(t);
                        },
                    }
                },

                .Struct, .Union => |zig_ty_tag| if (ty.containerLayout() == .Packed) {
                    if (ty.castTag(.@"struct")) |struct_obj| {
                        try self.initType(struct_obj.data.backing_int_ty, kind, lookup);
                    } else {
                        var buf: Type.Payload.Bits = .{
                            .base = .{ .tag = .int_unsigned },
                            .data = @intCast(u16, ty.bitSize(target)),
                        };
                        try self.initType(Type.initPayload(&buf.base), kind, lookup);
                    }
                } else if (ty.isTupleOrAnonStruct()) {
                    if (lookup.isMutable()) {
                        for (0..switch (zig_ty_tag) {
                            .Struct => ty.structFieldCount(),
                            .Union => ty.unionFields().count(),
                            else => unreachable,
                        }) |field_i| {
                            const field_ty = ty.structFieldType(field_i);
                            if ((zig_ty_tag == .Struct and ty.structFieldIsComptime(field_i)) or
                                !field_ty.hasRuntimeBitsIgnoreComptime()) continue;
                            _ = try lookup.typeToIndex(field_ty, switch (kind) {
                                .forward, .forward_parameter => .forward,
                                .complete, .parameter => .complete,
                                .global => .global,
                                .payload => unreachable,
                            });
                        }
                        switch (kind) {
                            .forward, .forward_parameter => {},
                            .complete, .parameter, .global => _ = try lookup.typeToIndex(ty, .forward),
                            .payload => unreachable,
                        }
                    }
                    self.init(switch (kind) {
                        .forward, .forward_parameter => switch (zig_ty_tag) {
                            .Struct => .fwd_anon_struct,
                            .Union => .fwd_anon_union,
                            else => unreachable,
                        },
                        .complete, .parameter, .global => switch (zig_ty_tag) {
                            .Struct => .anon_struct,
                            .Union => .anon_union,
                            else => unreachable,
                        },
                        .payload => unreachable,
                    });
                } else {
                    const tag_ty = ty.unionTagTypeSafety();
                    const is_tagged_union_wrapper = kind != .payload and tag_ty != null;
                    const is_struct = zig_ty_tag == .Struct or is_tagged_union_wrapper;
                    switch (kind) {
                        .forward, .forward_parameter => {
                            self.storage = .{ .fwd = .{
                                .base = .{ .tag = if (is_struct) .fwd_struct else .fwd_union },
                                .data = ty.getOwnerDecl(),
                            } };
                            self.value = .{ .cty = initPayload(&self.storage.fwd) };
                        },
                        .complete, .parameter, .global, .payload => if (is_tagged_union_wrapper) {
                            const fwd_idx = try lookup.typeToIndex(ty, .forward);
                            const payload_idx = try lookup.typeToIndex(ty, .payload);
                            const tag_idx = try lookup.typeToIndex(tag_ty.?, kind);
                            if (fwd_idx != null and payload_idx != null and tag_idx != null) {
                                self.storage = .{ .anon = undefined };
                                var field_count: usize = 0;
                                if (payload_idx != Tag.void.toIndex()) {
                                    self.storage.anon.fields[field_count] = .{
                                        .name = "payload",
                                        .type = payload_idx.?,
                                        .alignas = Payload.Fields.AlignAs.unionPayloadAlign(ty, target),
                                    };
                                    field_count += 1;
                                }
                                if (tag_idx != Tag.void.toIndex()) {
                                    self.storage.anon.fields[field_count] = .{
                                        .name = "tag",
                                        .type = tag_idx.?,
                                        .alignas = Payload.Fields.AlignAs.abiAlign(tag_ty.?, target),
                                    };
                                    field_count += 1;
                                }
                                self.storage.anon.pl = .{ .complete = .{
                                    .base = .{ .tag = .@"struct" },
                                    .data = .{
                                        .fields = self.sortFields(field_count),
                                        .fwd_decl = fwd_idx.?,
                                    },
                                } };
                                self.value = .{ .cty = initPayload(&self.storage.anon.pl.complete) };
                            } else self.init(.@"struct");
                        } else if (kind == .payload and ty.unionHasAllZeroBitFieldTypes()) {
                            self.init(.void);
                        } else {
                            var is_packed = false;
                            for (0..switch (zig_ty_tag) {
                                .Struct => ty.structFieldCount(),
                                .Union => ty.unionFields().count(),
                                else => unreachable,
                            }) |field_i| {
                                const field_ty = ty.structFieldType(field_i);
                                if (!field_ty.hasRuntimeBitsIgnoreComptime()) continue;

                                const field_align = Payload.Fields.AlignAs.fieldAlign(
                                    ty,
                                    field_i,
                                    target,
                                );
                                if (field_align.@"align" < field_align.abi) {
                                    is_packed = true;
                                    if (!lookup.isMutable()) break;
                                }

                                if (lookup.isMutable()) {
                                    _ = try lookup.typeToIndex(field_ty, switch (kind) {
                                        .forward, .forward_parameter => unreachable,
                                        .complete, .parameter, .payload => .complete,
                                        .global => .global,
                                    });
                                }
                            }
                            switch (kind) {
                                .forward, .forward_parameter => unreachable,
                                .complete, .parameter, .global => {
                                    _ = try lookup.typeToIndex(ty, .forward);
                                    self.init(if (is_struct)
                                        if (is_packed) .packed_struct else .@"struct"
                                    else if (is_packed) .packed_union else .@"union");
                                },
                                .payload => self.init(if (is_packed)
                                    .packed_unnamed_union
                                else
                                    .unnamed_union),
                            }
                        },
                    }
                },

                .Array, .Vector => |zig_ty_tag| {
                    switch (kind) {
                        .forward, .complete, .global => {
                            const t: Tag = switch (zig_ty_tag) {
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
                        .forward_parameter, .parameter => try self.initArrayParameter(ty, kind, lookup),
                        .payload => unreachable,
                    }
                },

                .Optional => {
                    var buf: Type.Payload.ElemType = undefined;
                    const payload_ty = ty.optionalChild(&buf);
                    if (payload_ty.hasRuntimeBitsIgnoreComptime()) {
                        if (ty.optionalReprIsPayload()) {
                            try self.initType(payload_ty, kind, lookup);
                        } else if (switch (kind) {
                            .forward, .forward_parameter => @as(Index, undefined),
                            .complete, .parameter, .global => try lookup.typeToIndex(ty, .forward),
                            .payload => unreachable,
                        }) |fwd_idx| {
                            if (try lookup.typeToIndex(payload_ty, switch (kind) {
                                .forward, .forward_parameter => .forward,
                                .complete, .parameter => .complete,
                                .global => .global,
                                .payload => unreachable,
                            })) |payload_idx| {
                                self.storage = .{ .anon = undefined };
                                self.storage.anon.fields[0] = .{
                                    .name = "payload",
                                    .type = payload_idx,
                                    .alignas = Payload.Fields.AlignAs.abiAlign(payload_ty, target),
                                };
                                self.storage.anon.fields[1] = .{
                                    .name = "is_null",
                                    .type = Tag.bool.toIndex(),
                                    .alignas = Payload.Fields.AlignAs.abiAlign(Type.bool, target),
                                };
                                self.initAnon(kind, fwd_idx, 2);
                            } else self.init(switch (kind) {
                                .forward, .forward_parameter => .fwd_anon_struct,
                                .complete, .parameter, .global => .anon_struct,
                                .payload => unreachable,
                            });
                        } else self.init(.anon_struct);
                    } else self.init(.bool);
                },

                .ErrorUnion => {
                    if (switch (kind) {
                        .forward, .forward_parameter => @as(Index, undefined),
                        .complete, .parameter, .global => try lookup.typeToIndex(ty, .forward),
                        .payload => unreachable,
                    }) |fwd_idx| {
                        const payload_ty = ty.errorUnionPayload();
                        if (try lookup.typeToIndex(payload_ty, switch (kind) {
                            .forward, .forward_parameter => .forward,
                            .complete, .parameter => .complete,
                            .global => .global,
                            .payload => unreachable,
                        })) |payload_idx| {
                            const error_ty = ty.errorUnionSet();
                            if (payload_idx == Tag.void.toIndex()) {
                                try self.initType(error_ty, kind, lookup);
                            } else if (try lookup.typeToIndex(error_ty, kind)) |error_idx| {
                                self.storage = .{ .anon = undefined };
                                self.storage.anon.fields[0] = .{
                                    .name = "payload",
                                    .type = payload_idx,
                                    .alignas = Payload.Fields.AlignAs.abiAlign(payload_ty, target),
                                };
                                self.storage.anon.fields[1] = .{
                                    .name = "error",
                                    .type = error_idx,
                                    .alignas = Payload.Fields.AlignAs.abiAlign(error_ty, target),
                                };
                                self.initAnon(kind, fwd_idx, 2);
                            } else self.init(switch (kind) {
                                .forward, .forward_parameter => .fwd_anon_struct,
                                .complete, .parameter, .global => .anon_struct,
                                .payload => unreachable,
                            });
                        } else self.init(switch (kind) {
                            .forward, .forward_parameter => .fwd_anon_struct,
                            .complete, .parameter, .global => .anon_struct,
                            .payload => unreachable,
                        });
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
                    if (!info.is_generic) {
                        if (lookup.isMutable()) {
                            const param_kind: Kind = switch (kind) {
                                .forward, .forward_parameter => .forward_parameter,
                                .complete, .parameter, .global => .parameter,
                                .payload => unreachable,
                            };
                            _ = try lookup.typeToIndex(info.return_type, param_kind);
                            for (info.param_types) |param_type| {
                                if (!param_type.hasRuntimeBitsIgnoreComptime()) continue;
                                _ = try lookup.typeToIndex(param_type, param_kind);
                            }
                        }
                        self.init(if (info.is_var_args) .varargs_function else .function);
                    } else self.init(.void);
                },
            }
        }
    };

    pub fn copy(self: CType, arena: Allocator) !CType {
        return self.copyContext(struct {
            arena: Allocator,
            pub fn copyIndex(_: @This(), idx: Index) Index {
                return idx;
            }
        }{ .arena = arena });
    }

    fn copyFields(ctx: anytype, old_fields: Payload.Fields.Data) !Payload.Fields.Data {
        const new_fields = try ctx.arena.alloc(Payload.Fields.Field, old_fields.len);
        for (new_fields, old_fields) |*new_field, old_field| {
            new_field.name = try ctx.arena.dupeZ(u8, mem.span(old_field.name));
            new_field.type = ctx.copyIndex(old_field.type);
            new_field.alignas = old_field.alignas;
        }
        return new_fields;
    }

    fn copyParams(ctx: anytype, old_param_types: []const Index) ![]const Index {
        const new_param_types = try ctx.arena.alloc(Index, old_param_types.len);
        for (new_param_types, old_param_types) |*new_param_type, old_param_type|
            new_param_type.* = ctx.copyIndex(old_param_type);
        return new_param_types;
    }

    pub fn copyContext(self: CType, ctx: anytype) !CType {
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
            .uint8_t,
            .int8_t,
            .uint16_t,
            .int16_t,
            .uint32_t,
            .int32_t,
            .uint64_t,
            .int64_t,
            .uintptr_t,
            .intptr_t,
            .zig_u128,
            .zig_i128,
            .zig_f16,
            .zig_f32,
            .zig_f64,
            .zig_f80,
            .zig_f128,
            .zig_c_longdouble,
            => return self,

            .pointer,
            .pointer_const,
            .pointer_volatile,
            .pointer_const_volatile,
            => {
                const pl = self.cast(Payload.Child).?;
                const new_pl = try ctx.arena.create(Payload.Child);
                new_pl.* = .{ .base = .{ .tag = pl.base.tag }, .data = ctx.copyIndex(pl.data) };
                return initPayload(new_pl);
            },

            .array,
            .vector,
            => {
                const pl = self.cast(Payload.Sequence).?;
                const new_pl = try ctx.arena.create(Payload.Sequence);
                new_pl.* = .{
                    .base = .{ .tag = pl.base.tag },
                    .data = .{ .len = pl.data.len, .elem_type = ctx.copyIndex(pl.data.elem_type) },
                };
                return initPayload(new_pl);
            },

            .fwd_anon_struct,
            .fwd_anon_union,
            => {
                const pl = self.cast(Payload.Fields).?;
                const new_pl = try ctx.arena.create(Payload.Fields);
                new_pl.* = .{
                    .base = .{ .tag = pl.base.tag },
                    .data = try copyFields(ctx, pl.data),
                };
                return initPayload(new_pl);
            },

            .fwd_struct,
            .fwd_union,
            => {
                const pl = self.cast(Payload.FwdDecl).?;
                const new_pl = try ctx.arena.create(Payload.FwdDecl);
                new_pl.* = .{ .base = .{ .tag = pl.base.tag }, .data = pl.data };
                return initPayload(new_pl);
            },

            .unnamed_struct,
            .unnamed_union,
            .packed_unnamed_struct,
            .packed_unnamed_union,
            => {
                const pl = self.cast(Payload.Unnamed).?;
                const new_pl = try ctx.arena.create(Payload.Unnamed);
                new_pl.* = .{ .base = .{ .tag = pl.base.tag }, .data = .{
                    .fields = try copyFields(ctx, pl.data.fields),
                    .owner_decl = pl.data.owner_decl,
                    .id = pl.data.id,
                } };
                return initPayload(new_pl);
            },

            .anon_struct,
            .anon_union,
            .@"struct",
            .@"union",
            .packed_struct,
            .packed_union,
            => {
                const pl = self.cast(Payload.Aggregate).?;
                const new_pl = try ctx.arena.create(Payload.Aggregate);
                new_pl.* = .{ .base = .{ .tag = pl.base.tag }, .data = .{
                    .fields = try copyFields(ctx, pl.data.fields),
                    .fwd_decl = ctx.copyIndex(pl.data.fwd_decl),
                } };
                return initPayload(new_pl);
            },

            .function,
            .varargs_function,
            => {
                const pl = self.cast(Payload.Function).?;
                const new_pl = try ctx.arena.create(Payload.Function);
                new_pl.* = .{ .base = .{ .tag = pl.base.tag }, .data = .{
                    .return_type = ctx.copyIndex(pl.data.return_type),
                    .param_types = try copyParams(ctx, pl.data.param_types),
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
                .fwd_anon_struct,
                .fwd_anon_union,
                .unnamed_struct,
                .unnamed_union,
                .packed_unnamed_struct,
                .packed_unnamed_union,
                .anon_struct,
                .anon_union,
                .@"struct",
                .@"union",
                .packed_struct,
                .packed_union,
                => {
                    const zig_ty_tag = ty.zigTypeTag();
                    const fields_len = switch (zig_ty_tag) {
                        .Struct => ty.structFieldCount(),
                        .Union => ty.unionFields().count(),
                        else => unreachable,
                    };

                    var c_fields_len: usize = 0;
                    for (0..fields_len) |field_i| {
                        const field_ty = ty.structFieldType(field_i);
                        if ((zig_ty_tag == .Struct and ty.structFieldIsComptime(field_i)) or
                            !field_ty.hasRuntimeBitsIgnoreComptime()) continue;
                        c_fields_len += 1;
                    }

                    const fields_pl = try arena.alloc(Payload.Fields.Field, c_fields_len);
                    var c_field_i: usize = 0;
                    for (0..fields_len) |field_i| {
                        const field_ty = ty.structFieldType(field_i);
                        if ((zig_ty_tag == .Struct and ty.structFieldIsComptime(field_i)) or
                            !field_ty.hasRuntimeBitsIgnoreComptime()) continue;

                        defer c_field_i += 1;
                        fields_pl[c_field_i] = .{
                            .name = try if (ty.isSimpleTuple())
                                std.fmt.allocPrintZ(arena, "f{}", .{field_i})
                            else
                                arena.dupeZ(u8, switch (zig_ty_tag) {
                                    .Struct => ty.structFieldName(field_i),
                                    .Union => ty.unionFields().keys()[field_i],
                                    else => unreachable,
                                }),
                            .type = store.set.typeToIndex(field_ty, target, switch (kind) {
                                .forward, .forward_parameter => .forward,
                                .complete, .parameter, .payload => .complete,
                                .global => .global,
                            }).?,
                            .alignas = Payload.Fields.AlignAs.fieldAlign(ty, field_i, target),
                        };
                    }

                    switch (t) {
                        .fwd_anon_struct,
                        .fwd_anon_union,
                        => {
                            const anon_pl = try arena.create(Payload.Fields);
                            anon_pl.* = .{ .base = .{ .tag = t }, .data = fields_pl };
                            return initPayload(anon_pl);
                        },

                        .unnamed_struct,
                        .unnamed_union,
                        .packed_unnamed_struct,
                        .packed_unnamed_union,
                        => {
                            const unnamed_pl = try arena.create(Payload.Unnamed);
                            unnamed_pl.* = .{ .base = .{ .tag = t }, .data = .{
                                .fields = fields_pl,
                                .owner_decl = ty.getOwnerDecl(),
                                .id = if (ty.unionTagTypeSafety()) |_| 0 else unreachable,
                            } };
                            return initPayload(unnamed_pl);
                        },

                        .anon_struct,
                        .anon_union,
                        .@"struct",
                        .@"union",
                        .packed_struct,
                        .packed_union,
                        => {
                            const struct_pl = try arena.create(Payload.Aggregate);
                            struct_pl.* = .{ .base = .{ .tag = t }, .data = .{
                                .fields = fields_pl,
                                .fwd_decl = store.set.typeToIndex(ty, target, .forward).?,
                            } };
                            return initPayload(struct_pl);
                        },

                        else => unreachable,
                    }
                },

                .function,
                .varargs_function,
                => {
                    const info = ty.fnInfo();
                    assert(!info.is_generic);
                    const param_kind: Kind = switch (kind) {
                        .forward, .forward_parameter => .forward_parameter,
                        .complete, .parameter, .global => .parameter,
                        .payload => unreachable,
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
                        params_pl[c_param_i] = store.set.typeToIndex(param_type, target, param_kind).?;
                        c_param_i += 1;
                    }

                    const fn_pl = try arena.create(Payload.Function);
                    fn_pl.* = .{ .base = .{ .tag = t }, .data = .{
                        .return_type = store.set.typeToIndex(info.return_type, target, param_kind).?,
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

        pub fn hash(self: @This(), cty: CType) u64 {
            return cty.hash(self.store.*);
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
                        .fwd_anon_struct,
                        .fwd_anon_union,
                        => {
                            if (!ty.isTupleOrAnonStruct()) return false;

                            var name_buf: [
                                std.fmt.count("f{}", .{std.math.maxInt(usize)})
                            ]u8 = undefined;
                            const c_fields = cty.cast(Payload.Fields).?.data;

                            const zig_ty_tag = ty.zigTypeTag();
                            var c_field_i: usize = 0;
                            for (0..switch (zig_ty_tag) {
                                .Struct => ty.structFieldCount(),
                                .Union => ty.unionFields().count(),
                                else => unreachable,
                            }) |field_i| {
                                const field_ty = ty.structFieldType(field_i);
                                if ((zig_ty_tag == .Struct and ty.structFieldIsComptime(field_i)) or
                                    !field_ty.hasRuntimeBitsIgnoreComptime()) continue;

                                defer c_field_i += 1;
                                const c_field = &c_fields[c_field_i];

                                if (!self.eqlRecurse(field_ty, c_field.type, switch (self.kind) {
                                    .forward, .forward_parameter => .forward,
                                    .complete, .parameter => .complete,
                                    .global => .global,
                                    .payload => unreachable,
                                }) or !mem.eql(
                                    u8,
                                    if (ty.isSimpleTuple())
                                        std.fmt.bufPrint(&name_buf, "f{}", .{field_i}) catch unreachable
                                    else switch (zig_ty_tag) {
                                        .Struct => ty.structFieldName(field_i),
                                        .Union => ty.unionFields().keys()[field_i],
                                        else => unreachable,
                                    },
                                    mem.span(c_field.name),
                                ) or Payload.Fields.AlignAs.fieldAlign(ty, field_i, target).@"align" !=
                                    c_field.alignas.@"align") return false;
                            }
                            return true;
                        },

                        .unnamed_struct,
                        .unnamed_union,
                        .packed_unnamed_struct,
                        .packed_unnamed_union,
                        => switch (self.kind) {
                            .forward, .forward_parameter, .complete, .parameter, .global => unreachable,
                            .payload => if (ty.unionTagTypeSafety()) |_| {
                                const data = cty.cast(Payload.Unnamed).?.data;
                                return ty.getOwnerDecl() == data.owner_decl and data.id == 0;
                            } else unreachable,
                        },

                        .anon_struct,
                        .anon_union,
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
                            assert(!info.is_generic);
                            const data = cty.cast(Payload.Function).?.data;
                            const param_kind: Kind = switch (self.kind) {
                                .forward, .forward_parameter => .forward_parameter,
                                .complete, .parameter, .global => .parameter,
                                .payload => unreachable,
                            };

                            if (!self.eqlRecurse(info.return_type, data.return_type, param_kind))
                                return false;

                            var c_param_i: usize = 0;
                            for (info.param_types) |param_type| {
                                if (!param_type.hasRuntimeBitsIgnoreComptime()) continue;

                                if (c_param_i >= data.param_types.len) return false;
                                const param_cty = data.param_types[c_param_i];
                                c_param_i += 1;

                                if (!self.eqlRecurse(param_type, param_cty, param_kind))
                                    return false;
                            }
                            return c_param_i == data.param_types.len;
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
                        .fwd_anon_struct,
                        .fwd_anon_union,
                        => {
                            var name_buf: [
                                std.fmt.count("f{}", .{std.math.maxInt(usize)})
                            ]u8 = undefined;

                            const zig_ty_tag = ty.zigTypeTag();
                            for (0..switch (ty.zigTypeTag()) {
                                .Struct => ty.structFieldCount(),
                                .Union => ty.unionFields().count(),
                                else => unreachable,
                            }) |field_i| {
                                const field_ty = ty.structFieldType(field_i);
                                if ((zig_ty_tag == .Struct and ty.structFieldIsComptime(field_i)) or
                                    !field_ty.hasRuntimeBitsIgnoreComptime()) continue;

                                self.updateHasherRecurse(hasher, field_ty, switch (self.kind) {
                                    .forward, .forward_parameter => .forward,
                                    .complete, .parameter => .complete,
                                    .global => .global,
                                    .payload => unreachable,
                                });
                                hasher.update(if (ty.isSimpleTuple())
                                    std.fmt.bufPrint(&name_buf, "f{}", .{field_i}) catch unreachable
                                else switch (zig_ty_tag) {
                                    .Struct => ty.structFieldName(field_i),
                                    .Union => ty.unionFields().keys()[field_i],
                                    else => unreachable,
                                });
                                autoHash(
                                    hasher,
                                    Payload.Fields.AlignAs.fieldAlign(ty, field_i, target).@"align",
                                );
                            }
                        },

                        .unnamed_struct,
                        .unnamed_union,
                        .packed_unnamed_struct,
                        .packed_unnamed_union,
                        => switch (self.kind) {
                            .forward, .forward_parameter, .complete, .parameter, .global => unreachable,
                            .payload => if (ty.unionTagTypeSafety()) |_| {
                                autoHash(hasher, ty.getOwnerDecl());
                                autoHash(hasher, @as(u32, 0));
                            } else unreachable,
                        },

                        .anon_struct,
                        .anon_union,
                        .@"struct",
                        .@"union",
                        .packed_struct,
                        .packed_union,
                        => self.updateHasherRecurse(hasher, ty, .forward),

                        .function,
                        .varargs_function,
                        => {
                            const info = ty.fnInfo();
                            assert(!info.is_generic);
                            const param_kind: Kind = switch (self.kind) {
                                .forward, .forward_parameter => .forward_parameter,
                                .complete, .parameter, .global => .parameter,
                                .payload => unreachable,
                            };

                            self.updateHasherRecurse(hasher, info.return_type, param_kind);
                            for (info.param_types) |param_type| {
                                if (!param_type.hasRuntimeBitsIgnoreComptime()) continue;
                                self.updateHasherRecurse(hasher, param_type, param_kind);
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
