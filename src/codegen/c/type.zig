const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const autoHash = std.hash.autoHash;
const Target = std.Target;

const Alignment = @import("../../InternPool.zig").Alignment;
const Module = @import("../../Module.zig");
const InternPool = @import("../../InternPool.zig");
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
        pub const no_payload_count = @intFromEnum(last_no_payload_tag) + 1;

        pub fn hasPayload(self: Tag) bool {
            return @intFromEnum(self) >= no_payload_count;
        }

        pub fn toIndex(self: Tag) Index {
            assert(!self.hasPayload());
            return @as(Index, @intCast(@intFromEnum(self)));
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
            data: InternPool.DeclIndex,
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
        };

        pub const Unnamed = struct {
            base: Payload,
            data: struct {
                fields: Fields.Data,
                owner_decl: InternPool.DeclIndex,
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

    pub const AlignAs = struct {
        @"align": Alignment,
        abi: Alignment,

        pub fn init(@"align": Alignment, abi_align: Alignment) AlignAs {
            assert(abi_align != .none);
            return .{
                .@"align" = if (@"align" != .none) @"align" else abi_align,
                .abi = abi_align,
            };
        }

        pub fn initByteUnits(alignment: u64, abi_alignment: u32) AlignAs {
            return init(
                Alignment.fromByteUnits(alignment),
                Alignment.fromNonzeroByteUnits(abi_alignment),
            );
        }
        pub fn abiAlign(ty: Type, mod: *Module) AlignAs {
            const abi_align = ty.abiAlignment(mod);
            return init(abi_align, abi_align);
        }
        pub fn fieldAlign(struct_ty: Type, field_i: usize, mod: *Module) AlignAs {
            return init(
                struct_ty.structFieldAlign(field_i, mod),
                struct_ty.structFieldType(field_i, mod).abiAlignment(mod),
            );
        }
        pub fn unionPayloadAlign(union_ty: Type, mod: *Module) AlignAs {
            const union_obj = mod.typeToUnion(union_ty).?;
            const union_payload_align = mod.unionAbiAlignment(union_obj);
            return init(union_payload_align, union_payload_align);
        }

        pub fn order(lhs: AlignAs, rhs: AlignAs) std.math.Order {
            return lhs.@"align".order(rhs.@"align");
        }
        pub fn abiOrder(self: AlignAs) std.math.Order {
            return self.@"align".order(self.abi);
        }
        pub fn toByteUnits(self: AlignAs) u64 {
            return self.@"align".toByteUnitsOptional().?;
        }
    };

    pub const Index = u32;
    pub const Store = struct {
        arena: std.heap.ArenaAllocator.State = .{},
        set: Set = .{},

        pub const Set = struct {
            pub const Map = std.ArrayHashMapUnmanaged(CType, void, HashContext, true);
            const HashContext = struct {
                store: *const Set,

                pub fn hash(self: @This(), cty: CType) Map.Hash {
                    return @as(Map.Hash, @truncate(cty.hash(self.store.*)));
                }
                pub fn eql(_: @This(), lhs: CType, rhs: CType, _: usize) bool {
                    return lhs.eql(rhs);
                }
            };

            map: Map = .{},

            pub fn indexToCType(self: Set, index: Index) CType {
                if (index < Tag.no_payload_count) return initTag(@as(Tag, @enumFromInt(index)));
                return self.map.keys()[index - Tag.no_payload_count];
            }

            pub fn indexToHash(self: Set, index: Index) Map.Hash {
                if (index < Tag.no_payload_count)
                    return (HashContext{ .store = &self }).hash(self.indexToCType(index));
                return self.map.entries.items(.hash)[index - Tag.no_payload_count];
            }

            pub fn typeToIndex(self: Set, ty: Type, mod: *Module, kind: Kind) ?Index {
                const lookup = Convert.Lookup{ .imm = .{ .set = &self, .mod = mod } };

                var convert: Convert = undefined;
                convert.initType(ty, kind, lookup) catch unreachable;

                const t = convert.tag();
                if (!t.hasPayload()) return t.toIndex();

                return if (self.map.getIndexAdapted(
                    ty,
                    TypeAdapter32{ .kind = kind, .lookup = lookup, .convert = &convert },
                )) |idx| @as(Index, @intCast(Tag.no_payload_count + idx)) else null;
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
                if (@intFromEnum(t) < Tag.no_payload_count) return @as(Index, @intCast(@intFromEnum(t)));

                const gop = try self.set.map.getOrPutContext(self.gpa(), cty, .{ .store = &self.set });
                if (!gop.found_existing) gop.key_ptr.* = cty;
                if (std.debug.runtime_safety) {
                    const key = &self.set.map.entries.items(.key)[gop.index];
                    assert(key == gop.key_ptr);
                    assert(cty.eql(key.*));
                    assert(cty.hash(self.set) == key.hash(self.set));
                }
                return @as(Index, @intCast(Tag.no_payload_count + gop.index));
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
                    gop.key_ptr.* = try createFromConvert(self, ty, lookup.getModule(), kind, convert);
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
                return @as(Index, @intCast(Tag.no_payload_count + gop.index));
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

    pub fn isBool(self: CType) bool {
        return switch (self.tag()) {
            ._Bool,
            .bool,
            => true,
            else => false,
        };
    }

    pub fn isInteger(self: CType) bool {
        return switch (self.tag()) {
            .char,
            .@"signed char",
            .short,
            .int,
            .long,
            .@"long long",
            .@"unsigned char",
            .@"unsigned short",
            .@"unsigned int",
            .@"unsigned long",
            .@"unsigned long long",
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
            => true,
            else => false,
        };
    }

    pub fn signedness(self: CType, target: std.Target) std.builtin.Signedness {
        return switch (self.tag()) {
            .char => target.charSignedness(),
            .@"signed char",
            .short,
            .int,
            .long,
            .@"long long",
            .ptrdiff_t,
            .int8_t,
            .int16_t,
            .int32_t,
            .int64_t,
            .intptr_t,
            .zig_i128,
            => .signed,
            .@"unsigned char",
            .@"unsigned short",
            .@"unsigned int",
            .@"unsigned long",
            .@"unsigned long long",
            .size_t,
            .uint8_t,
            .uint16_t,
            .uint32_t,
            .uint64_t,
            .uintptr_t,
            .zig_u128,
            => .unsigned,
            else => unreachable,
        };
    }

    pub fn isFloat(self: CType) bool {
        return switch (self.tag()) {
            .float,
            .double,
            .@"long double",
            .zig_f16,
            .zig_f32,
            .zig_f64,
            .zig_f80,
            .zig_f128,
            .zig_c_longdouble,
            => true,
            else => false,
        };
    }

    pub fn isPointer(self: CType) bool {
        return switch (self.tag()) {
            .pointer,
            .pointer_const,
            .pointer_volatile,
            .pointer_const_volatile,
            => true,
            else => false,
        };
    }

    pub fn isFunction(self: CType) bool {
        return switch (self.tag()) {
            .function,
            .varargs_function,
            => true,
            else => false,
        };
    }

    pub fn toSigned(self: CType) CType {
        return CType.initTag(switch (self.tag()) {
            .char, .@"signed char", .@"unsigned char" => .@"signed char",
            .short, .@"unsigned short" => .short,
            .int, .@"unsigned int" => .int,
            .long, .@"unsigned long" => .long,
            .@"long long", .@"unsigned long long" => .@"long long",
            .size_t, .ptrdiff_t => .ptrdiff_t,
            .uint8_t, .int8_t => .int8_t,
            .uint16_t, .int16_t => .int16_t,
            .uint32_t, .int32_t => .int32_t,
            .uint64_t, .int64_t => .int64_t,
            .uintptr_t, .intptr_t => .intptr_t,
            .zig_u128, .zig_i128 => .zig_i128,
            .float,
            .double,
            .@"long double",
            .zig_f16,
            .zig_f32,
            .zig_f80,
            .zig_f128,
            .zig_c_longdouble,
            => |t| t,
            else => unreachable,
        });
    }

    pub fn toUnsigned(self: CType) CType {
        return CType.initTag(switch (self.tag()) {
            .char, .@"signed char", .@"unsigned char" => .@"unsigned char",
            .short, .@"unsigned short" => .@"unsigned short",
            .int, .@"unsigned int" => .@"unsigned int",
            .long, .@"unsigned long" => .@"unsigned long",
            .@"long long", .@"unsigned long long" => .@"unsigned long long",
            .size_t, .ptrdiff_t => .size_t,
            .uint8_t, .int8_t => .uint8_t,
            .uint16_t, .int16_t => .uint16_t,
            .uint32_t, .int32_t => .uint32_t,
            .uint64_t, .int64_t => .uint64_t,
            .uintptr_t, .intptr_t => .uintptr_t,
            .zig_u128, .zig_i128 => .zig_u128,
            else => unreachable,
        });
    }

    pub fn toSignedness(self: CType, s: std.builtin.Signedness) CType {
        return switch (s) {
            .unsigned => self.toUnsigned(),
            .signed => self.toSigned(),
        };
    }

    pub fn getStandardDefineAbbrev(self: CType) ?[]const u8 {
        return switch (self.tag()) {
            .char => "CHAR",
            .@"signed char" => "SCHAR",
            .short => "SHRT",
            .int => "INT",
            .long => "LONG",
            .@"long long" => "LLONG",
            .@"unsigned char" => "UCHAR",
            .@"unsigned short" => "USHRT",
            .@"unsigned int" => "UINT",
            .@"unsigned long" => "ULONG",
            .@"unsigned long long" => "ULLONG",
            .float => "FLT",
            .double => "DBL",
            .@"long double" => "LDBL",
            .size_t => "SIZE",
            .ptrdiff_t => "PTRDIFF",
            .uint8_t => "UINT8",
            .int8_t => "INT8",
            .uint16_t => "UINT16",
            .int16_t => "INT16",
            .uint32_t => "UINT32",
            .int32_t => "INT32",
            .uint64_t => "UINT64",
            .int64_t => "INT64",
            .uintptr_t => "UINTPTR",
            .intptr_t => "INTPTR",
            else => null,
        };
    }

    pub fn renderLiteralPrefix(self: CType, writer: anytype, kind: Kind) @TypeOf(writer).Error!void {
        switch (self.tag()) {
            .void => unreachable,
            ._Bool,
            .char,
            .@"signed char",
            .short,
            .@"unsigned short",
            .bool,
            .size_t,
            .ptrdiff_t,
            .uintptr_t,
            .intptr_t,
            => |t| switch (kind) {
                else => try writer.print("({s})", .{@tagName(t)}),
                .global => {},
            },
            .int,
            .long,
            .@"long long",
            .@"unsigned char",
            .@"unsigned int",
            .@"unsigned long",
            .@"unsigned long long",
            .float,
            .double,
            .@"long double",
            => {},
            .uint8_t,
            .int8_t,
            .uint16_t,
            .int16_t,
            .uint32_t,
            .int32_t,
            .uint64_t,
            .int64_t,
            => try writer.print("{s}_C(", .{self.getStandardDefineAbbrev().?}),
            .zig_u128,
            .zig_i128,
            .zig_f16,
            .zig_f32,
            .zig_f64,
            .zig_f80,
            .zig_f128,
            .zig_c_longdouble,
            => |t| try writer.print("zig_{s}_{s}(", .{
                switch (kind) {
                    else => "make",
                    .global => "init",
                },
                @tagName(t)["zig_".len..],
            }),
            .pointer,
            .pointer_const,
            .pointer_volatile,
            .pointer_const_volatile,
            => unreachable,
            .array,
            .vector,
            => try writer.writeByte('{'),
            .fwd_anon_struct,
            .fwd_anon_union,
            .fwd_struct,
            .fwd_union,
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
            .function,
            .varargs_function,
            => unreachable,
        }
    }

    pub fn renderLiteralSuffix(self: CType, writer: anytype) @TypeOf(writer).Error!void {
        switch (self.tag()) {
            .void => unreachable,
            ._Bool => {},
            .char,
            .@"signed char",
            .short,
            .int,
            => {},
            .long => try writer.writeByte('l'),
            .@"long long" => try writer.writeAll("ll"),
            .@"unsigned char",
            .@"unsigned short",
            .@"unsigned int",
            => try writer.writeByte('u'),
            .@"unsigned long",
            .size_t,
            .uintptr_t,
            => try writer.writeAll("ul"),
            .@"unsigned long long" => try writer.writeAll("ull"),
            .float => try writer.writeByte('f'),
            .double => {},
            .@"long double" => try writer.writeByte('l'),
            .bool,
            .ptrdiff_t,
            .intptr_t,
            => {},
            .uint8_t,
            .int8_t,
            .uint16_t,
            .int16_t,
            .uint32_t,
            .int32_t,
            .uint64_t,
            .int64_t,
            .zig_u128,
            .zig_i128,
            .zig_f16,
            .zig_f32,
            .zig_f64,
            .zig_f80,
            .zig_f128,
            .zig_c_longdouble,
            => try writer.writeByte(')'),
            .pointer,
            .pointer_const,
            .pointer_volatile,
            .pointer_const_volatile,
            => unreachable,
            .array,
            .vector,
            => try writer.writeByte('}'),
            .fwd_anon_struct,
            .fwd_anon_union,
            .fwd_struct,
            .fwd_union,
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
            .function,
            .varargs_function,
            => unreachable,
        }
    }

    pub fn floatActiveBits(self: CType, target: Target) u16 {
        return switch (self.tag()) {
            .float => target.c_type_bit_size(.float),
            .double => target.c_type_bit_size(.double),
            .@"long double", .zig_c_longdouble => target.c_type_bit_size(.longdouble),
            .zig_f16 => 16,
            .zig_f32 => 32,
            .zig_f64 => 64,
            .zig_f80 => 80,
            .zig_f128 => 128,
            else => unreachable,
        };
    }

    pub fn byteSize(self: CType, store: Store.Set, target: Target) u64 {
        return switch (self.tag()) {
            .void => 0,
            .char, .@"signed char", ._Bool, .@"unsigned char", .bool, .uint8_t, .int8_t => 1,
            .short => target.c_type_byte_size(.short),
            .int => target.c_type_byte_size(.int),
            .long => target.c_type_byte_size(.long),
            .@"long long" => target.c_type_byte_size(.longlong),
            .@"unsigned short" => target.c_type_byte_size(.ushort),
            .@"unsigned int" => target.c_type_byte_size(.uint),
            .@"unsigned long" => target.c_type_byte_size(.ulong),
            .@"unsigned long long" => target.c_type_byte_size(.ulonglong),
            .float => target.c_type_byte_size(.float),
            .double => target.c_type_byte_size(.double),
            .@"long double" => target.c_type_byte_size(.longdouble),
            .size_t,
            .ptrdiff_t,
            .uintptr_t,
            .intptr_t,
            .pointer,
            .pointer_const,
            .pointer_volatile,
            .pointer_const_volatile,
            => @divExact(target.ptrBitWidth(), 8),
            .uint16_t, .int16_t, .zig_f16 => 2,
            .uint32_t, .int32_t, .zig_f32 => 4,
            .uint64_t, .int64_t, .zig_f64 => 8,
            .zig_u128, .zig_i128, .zig_f128 => 16,
            .zig_f80 => if (target.c_type_bit_size(.longdouble) == 80)
                target.c_type_byte_size(.longdouble)
            else
                16,
            .zig_c_longdouble => target.c_type_byte_size(.longdouble),

            .array,
            .vector,
            => {
                const data = self.cast(Payload.Sequence).?.data;
                return data.len * store.indexToCType(data.elem_type).byteSize(store, target);
            },

            .fwd_anon_struct,
            .fwd_anon_union,
            .fwd_struct,
            .fwd_union,
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
            .function,
            .varargs_function,
            => unreachable,
        };
    }

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
                    if (std.mem.orderZ(u8, lhs_field.name, rhs_field.name) != .eq) return false;
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

        fn tagFromIntInfo(int_info: std.builtin.Type.Int) Tag {
            return switch (int_info.bits) {
                0 => .void,
                1...8 => switch (int_info.signedness) {
                    .unsigned => .uint8_t,
                    .signed => .int8_t,
                },
                9...16 => switch (int_info.signedness) {
                    .unsigned => .uint16_t,
                    .signed => .int16_t,
                },
                17...32 => switch (int_info.signedness) {
                    .unsigned => .uint32_t,
                    .signed => .int32_t,
                },
                33...64 => switch (int_info.signedness) {
                    .unsigned => .uint64_t,
                    .signed => .int64_t,
                },
                65...128 => switch (int_info.signedness) {
                    .unsigned => .zig_u128,
                    .signed => .zig_i128,
                },
                else => .array,
            };
        }

        pub const Lookup = union(enum) {
            fail: *Module,
            imm: struct {
                set: *const Store.Set,
                mod: *Module,
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
                return self.getModule().getTarget();
            }

            pub fn getModule(self: @This()) *Module {
                return switch (self) {
                    .fail => |mod| mod,
                    .imm => |imm| imm.mod,
                    .mut => |mut| mut.mod,
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
                    .imm => |imm| imm.set.typeToIndex(ty, imm.mod, kind),
                    .mut => |mut| try mut.promoted.typeToIndex(ty, mut.mod, kind),
                };
            }

            pub fn indexToCType(self: @This(), index: Index) ?CType {
                return if (self.getSet()) |set| set.indexToCType(index) else null;
            }

            pub fn freeze(self: @This()) @This() {
                return switch (self) {
                    .fail, .imm => self,
                    .mut => |mut| .{ .imm = .{ .set = &mut.promoted.set, .mod = mut.mod } },
                };
            }
        };

        fn sortFields(self: *@This(), fields_len: usize) []Payload.Fields.Field {
            const Field = Payload.Fields.Field;
            const slice = self.storage.anon.fields[0..fields_len];
            mem.sort(Field, slice, {}, struct {
                fn before(_: void, lhs: Field, rhs: Field) bool {
                    return lhs.alignas.order(rhs.alignas).compare(.gt);
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
                        .alignas = AlignAs.abiAlign(ty, lookup.getModule()),
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
            const mod = lookup.getModule();
            const ip = &mod.intern_pool;

            self.* = undefined;
            if (!ty.isFnOrHasRuntimeBitsIgnoreComptime(mod))
                self.init(.void)
            else if (ty.isAbiInt(mod)) switch (ty.ip_index) {
                .usize_type => self.init(.uintptr_t),
                .isize_type => self.init(.intptr_t),
                .c_char_type => self.init(.char),
                .c_short_type => self.init(.short),
                .c_ushort_type => self.init(.@"unsigned short"),
                .c_int_type => self.init(.int),
                .c_uint_type => self.init(.@"unsigned int"),
                .c_long_type => self.init(.long),
                .c_ulong_type => self.init(.@"unsigned long"),
                .c_longlong_type => self.init(.@"long long"),
                .c_ulonglong_type => self.init(.@"unsigned long long"),
                else => switch (tagFromIntInfo(ty.intInfo(mod))) {
                    .void => unreachable,
                    else => |t| self.init(t),
                    .array => switch (kind) {
                        .forward, .complete, .global => {
                            const abi_size = ty.abiSize(mod);
                            const abi_align = ty.abiAlignment(mod).toByteUnits(0);
                            self.storage = .{ .seq = .{ .base = .{ .tag = .array }, .data = .{
                                .len = @divExact(abi_size, abi_align),
                                .elem_type = tagFromIntInfo(.{
                                    .signedness = .unsigned,
                                    .bits = @intCast(abi_align * 8),
                                }).toIndex(),
                            } } };
                            self.value = .{ .cty = initPayload(&self.storage.seq) };
                        },
                        .forward_parameter,
                        .parameter,
                        => try self.initArrayParameter(ty, kind, lookup),
                        .payload => unreachable,
                    },
                },
            } else switch (ty.zigTypeTag(mod)) {
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

                .Float => self.init(switch (ty.ip_index) {
                    .f16_type => .zig_f16,
                    .f32_type => .zig_f32,
                    .f64_type => .zig_f64,
                    .f80_type => .zig_f80,
                    .f128_type => .zig_f128,
                    .c_longdouble_type => .zig_c_longdouble,
                    else => unreachable,
                }),

                .Pointer => {
                    const info = ty.ptrInfo(mod);
                    switch (info.flags.size) {
                        .Slice => {
                            if (switch (kind) {
                                .forward, .forward_parameter => @as(Index, undefined),
                                .complete, .parameter, .global => try lookup.typeToIndex(ty, .forward),
                                .payload => unreachable,
                            }) |fwd_idx| {
                                const ptr_ty = ty.slicePtrFieldType(mod);
                                if (try lookup.typeToIndex(ptr_ty, kind)) |ptr_idx| {
                                    self.storage = .{ .anon = undefined };
                                    self.storage.anon.fields[0] = .{
                                        .name = "ptr",
                                        .type = ptr_idx,
                                        .alignas = AlignAs.abiAlign(ptr_ty, mod),
                                    };
                                    self.storage.anon.fields[1] = .{
                                        .name = "len",
                                        .type = Tag.uintptr_t.toIndex(),
                                        .alignas = AlignAs.abiAlign(Type.usize, mod),
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
                            const t: Tag = switch (info.flags.is_volatile) {
                                false => switch (info.flags.is_const) {
                                    false => .pointer,
                                    true => .pointer_const,
                                },
                                true => switch (info.flags.is_const) {
                                    false => .pointer_volatile,
                                    true => .pointer_const_volatile,
                                },
                            };

                            const pointee_ty = if (info.packed_offset.host_size > 0 and
                                info.flags.vector_index == .none)
                                try mod.intType(.unsigned, info.packed_offset.host_size * 8)
                            else
                                Type.fromInterned(info.child);

                            if (try lookup.typeToIndex(pointee_ty, .forward)) |child_idx| {
                                self.storage = .{ .child = .{
                                    .base = .{ .tag = t },
                                    .data = child_idx,
                                } };
                                self.value = .{ .cty = initPayload(&self.storage.child) };
                            } else self.init(t);
                        },
                    }
                },

                .Struct, .Union => |zig_ty_tag| if (ty.containerLayout(mod) == .Packed) {
                    if (mod.typeToPackedStruct(ty)) |packed_struct| {
                        try self.initType(Type.fromInterned(packed_struct.backingIntType(ip).*), kind, lookup);
                    } else {
                        const bits: u16 = @intCast(ty.bitSize(mod));
                        const int_ty = try mod.intType(.unsigned, bits);
                        try self.initType(int_ty, kind, lookup);
                    }
                } else if (ty.isTupleOrAnonStruct(mod)) {
                    if (lookup.isMutable()) {
                        for (0..switch (zig_ty_tag) {
                            .Struct => ty.structFieldCount(mod),
                            .Union => mod.typeToUnion(ty).?.field_names.len,
                            else => unreachable,
                        }) |field_i| {
                            const field_ty = ty.structFieldType(field_i, mod);
                            if ((zig_ty_tag == .Struct and ty.structFieldIsComptime(field_i, mod)) or
                                !field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;
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
                    const tag_ty = ty.unionTagTypeSafety(mod);
                    const is_tagged_union_wrapper = kind != .payload and tag_ty != null;
                    const is_struct = zig_ty_tag == .Struct or is_tagged_union_wrapper;
                    switch (kind) {
                        .forward, .forward_parameter => {
                            self.storage = .{ .fwd = .{
                                .base = .{ .tag = if (is_struct) .fwd_struct else .fwd_union },
                                .data = ty.getOwnerDecl(mod),
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
                                        .alignas = AlignAs.unionPayloadAlign(ty, mod),
                                    };
                                    field_count += 1;
                                }
                                if (tag_idx != Tag.void.toIndex()) {
                                    self.storage.anon.fields[field_count] = .{
                                        .name = "tag",
                                        .type = tag_idx.?,
                                        .alignas = AlignAs.abiAlign(tag_ty.?, mod),
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
                        } else if (kind == .payload and ty.unionHasAllZeroBitFieldTypes(mod)) {
                            self.init(.void);
                        } else {
                            var is_packed = false;
                            for (0..switch (zig_ty_tag) {
                                .Struct => ty.structFieldCount(mod),
                                .Union => mod.typeToUnion(ty).?.field_names.len,
                                else => unreachable,
                            }) |field_i| {
                                const field_ty = ty.structFieldType(field_i, mod);
                                if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

                                const field_align = AlignAs.fieldAlign(ty, field_i, mod);
                                if (field_align.abiOrder().compare(.lt)) {
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
                            if (try lookup.typeToIndex(ty.childType(mod), kind)) |child_idx| {
                                self.storage = .{ .seq = .{ .base = .{ .tag = t }, .data = .{
                                    .len = ty.arrayLenIncludingSentinel(mod),
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
                    const payload_ty = ty.optionalChild(mod);
                    if (payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                        if (ty.optionalReprIsPayload(mod)) {
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
                                    .alignas = AlignAs.abiAlign(payload_ty, mod),
                                };
                                self.storage.anon.fields[1] = .{
                                    .name = "is_null",
                                    .type = Tag.bool.toIndex(),
                                    .alignas = AlignAs.abiAlign(Type.bool, mod),
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
                        const payload_ty = ty.errorUnionPayload(mod);
                        if (try lookup.typeToIndex(payload_ty, switch (kind) {
                            .forward, .forward_parameter => .forward,
                            .complete, .parameter => .complete,
                            .global => .global,
                            .payload => unreachable,
                        })) |payload_idx| {
                            const error_ty = ty.errorUnionSet(mod);
                            if (payload_idx == Tag.void.toIndex()) {
                                try self.initType(error_ty, kind, lookup);
                            } else if (try lookup.typeToIndex(error_ty, kind)) |error_idx| {
                                self.storage = .{ .anon = undefined };
                                self.storage.anon.fields[0] = .{
                                    .name = "payload",
                                    .type = payload_idx,
                                    .alignas = AlignAs.abiAlign(payload_ty, mod),
                                };
                                self.storage.anon.fields[1] = .{
                                    .name = "error",
                                    .type = error_idx,
                                    .alignas = AlignAs.abiAlign(error_ty, mod),
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

                .Opaque => self.init(.void),

                .Fn => {
                    const info = mod.typeToFunc(ty).?;
                    if (!info.is_generic) {
                        if (lookup.isMutable()) {
                            const param_kind: Kind = switch (kind) {
                                .forward, .forward_parameter => .forward_parameter,
                                .complete, .parameter, .global => .parameter,
                                .payload => unreachable,
                            };
                            _ = try lookup.typeToIndex(Type.fromInterned(info.return_type), param_kind);
                            for (info.param_types.get(ip)) |param_type| {
                                if (!Type.fromInterned(param_type).hasRuntimeBitsIgnoreComptime(mod)) continue;
                                _ = try lookup.typeToIndex(Type.fromInterned(param_type), param_kind);
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

    fn createFromType(store: *Store.Promoted, ty: Type, mod: *Module, kind: Kind) !CType {
        var convert: Convert = undefined;
        try convert.initType(ty, kind, .{ .imm = .{ .set = &store.set, .mod = mod } });
        return createFromConvert(store, ty, mod, kind, &convert);
    }

    fn createFromConvert(
        store: *Store.Promoted,
        ty: Type,
        mod: *Module,
        kind: Kind,
        convert: Convert,
    ) !CType {
        const ip = &mod.intern_pool;
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
                    const zig_ty_tag = ty.zigTypeTag(mod);
                    const fields_len = switch (zig_ty_tag) {
                        .Struct => ty.structFieldCount(mod),
                        .Union => mod.typeToUnion(ty).?.field_names.len,
                        else => unreachable,
                    };

                    var c_fields_len: usize = 0;
                    for (0..fields_len) |field_i| {
                        const field_ty = ty.structFieldType(field_i, mod);
                        if ((zig_ty_tag == .Struct and ty.structFieldIsComptime(field_i, mod)) or
                            !field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;
                        c_fields_len += 1;
                    }

                    const fields_pl = try arena.alloc(Payload.Fields.Field, c_fields_len);
                    var c_field_i: usize = 0;
                    for (0..fields_len) |field_i_usize| {
                        const field_i: u32 = @intCast(field_i_usize);
                        const field_ty = ty.structFieldType(field_i, mod);
                        if ((zig_ty_tag == .Struct and ty.structFieldIsComptime(field_i, mod)) or
                            !field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

                        defer c_field_i += 1;
                        fields_pl[c_field_i] = .{
                            .name = try if (ty.isSimpleTuple(mod))
                                std.fmt.allocPrintZ(arena, "f{}", .{field_i})
                            else
                                arena.dupeZ(u8, ip.stringToSlice(switch (zig_ty_tag) {
                                    .Struct => ty.legacyStructFieldName(field_i, mod),
                                    .Union => mod.typeToUnion(ty).?.field_names.get(ip)[field_i],
                                    else => unreachable,
                                })),
                            .type = store.set.typeToIndex(field_ty, mod, switch (kind) {
                                .forward, .forward_parameter => .forward,
                                .complete, .parameter, .payload => .complete,
                                .global => .global,
                            }).?,
                            .alignas = AlignAs.fieldAlign(ty, field_i, mod),
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
                                .owner_decl = ty.getOwnerDecl(mod),
                                .id = if (ty.unionTagTypeSafety(mod)) |_| 0 else unreachable,
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
                                .fwd_decl = store.set.typeToIndex(ty, mod, .forward).?,
                            } };
                            return initPayload(struct_pl);
                        },

                        else => unreachable,
                    }
                },

                .function,
                .varargs_function,
                => {
                    const info = mod.typeToFunc(ty).?;
                    assert(!info.is_generic);
                    const param_kind: Kind = switch (kind) {
                        .forward, .forward_parameter => .forward_parameter,
                        .complete, .parameter, .global => .parameter,
                        .payload => unreachable,
                    };

                    var c_params_len: usize = 0;
                    for (info.param_types.get(ip)) |param_type| {
                        if (!Type.fromInterned(param_type).hasRuntimeBitsIgnoreComptime(mod)) continue;
                        c_params_len += 1;
                    }

                    const params_pl = try arena.alloc(Index, c_params_len);
                    var c_param_i: usize = 0;
                    for (info.param_types.get(ip)) |param_type| {
                        if (!Type.fromInterned(param_type).hasRuntimeBitsIgnoreComptime(mod)) continue;
                        params_pl[c_param_i] = store.set.typeToIndex(Type.fromInterned(param_type), mod, param_kind).?;
                        c_param_i += 1;
                    }

                    const fn_pl = try arena.create(Payload.Function);
                    fn_pl.* = .{ .base = .{ .tag = t }, .data = .{
                        .return_type = store.set.typeToIndex(Type.fromInterned(info.return_type), mod, param_kind).?,
                        .param_types = params_pl,
                    } };
                    return initPayload(fn_pl);
                },

                else => unreachable,
            },
        }
    }

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
            const mod = self.lookup.getModule();
            const ip = &mod.intern_pool;
            switch (self.convert.value) {
                .cty => |c| return c.eql(cty),
                .tag => |t| {
                    if (t != cty.tag()) return false;

                    switch (t) {
                        .fwd_anon_struct,
                        .fwd_anon_union,
                        => {
                            if (!ty.isTupleOrAnonStruct(mod)) return false;

                            var name_buf: [
                                std.fmt.count("f{}", .{std.math.maxInt(usize)})
                            ]u8 = undefined;
                            const c_fields = cty.cast(Payload.Fields).?.data;

                            const zig_ty_tag = ty.zigTypeTag(mod);
                            var c_field_i: usize = 0;
                            for (0..switch (zig_ty_tag) {
                                .Struct => ty.structFieldCount(mod),
                                .Union => mod.typeToUnion(ty).?.field_names.len,
                                else => unreachable,
                            }) |field_i_usize| {
                                const field_i: u32 = @intCast(field_i_usize);
                                const field_ty = ty.structFieldType(field_i, mod);
                                if ((zig_ty_tag == .Struct and ty.structFieldIsComptime(field_i, mod)) or
                                    !field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

                                defer c_field_i += 1;
                                const c_field = &c_fields[c_field_i];

                                if (!self.eqlRecurse(field_ty, c_field.type, switch (self.kind) {
                                    .forward, .forward_parameter => .forward,
                                    .complete, .parameter => .complete,
                                    .global => .global,
                                    .payload => unreachable,
                                }) or !mem.eql(
                                    u8,
                                    if (ty.isSimpleTuple(mod))
                                        std.fmt.bufPrintZ(&name_buf, "f{}", .{field_i}) catch unreachable
                                    else
                                        ip.stringToSlice(switch (zig_ty_tag) {
                                            .Struct => ty.legacyStructFieldName(field_i, mod),
                                            .Union => mod.typeToUnion(ty).?.field_names.get(ip)[field_i],
                                            else => unreachable,
                                        }),
                                    mem.span(c_field.name),
                                ) or AlignAs.fieldAlign(ty, field_i, mod).@"align" !=
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
                            .payload => if (ty.unionTagTypeSafety(mod)) |_| {
                                const data = cty.cast(Payload.Unnamed).?.data;
                                return ty.getOwnerDecl(mod) == data.owner_decl and data.id == 0;
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
                            if (ty.zigTypeTag(mod) != .Fn) return false;

                            const info = mod.typeToFunc(ty).?;
                            assert(!info.is_generic);
                            const data = cty.cast(Payload.Function).?.data;
                            const param_kind: Kind = switch (self.kind) {
                                .forward, .forward_parameter => .forward_parameter,
                                .complete, .parameter, .global => .parameter,
                                .payload => unreachable,
                            };

                            if (!self.eqlRecurse(Type.fromInterned(info.return_type), data.return_type, param_kind))
                                return false;

                            var c_param_i: usize = 0;
                            for (info.param_types.get(ip)) |param_type| {
                                if (!Type.fromInterned(param_type).hasRuntimeBitsIgnoreComptime(mod)) continue;

                                if (c_param_i >= data.param_types.len) return false;
                                const param_cty = data.param_types[c_param_i];
                                c_param_i += 1;

                                if (!self.eqlRecurse(Type.fromInterned(param_type), param_cty, param_kind))
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

                    const mod = self.lookup.getModule();
                    const ip = &mod.intern_pool;
                    switch (t) {
                        .fwd_anon_struct,
                        .fwd_anon_union,
                        => {
                            var name_buf: [
                                std.fmt.count("f{}", .{std.math.maxInt(usize)})
                            ]u8 = undefined;

                            const zig_ty_tag = ty.zigTypeTag(mod);
                            for (0..switch (ty.zigTypeTag(mod)) {
                                .Struct => ty.structFieldCount(mod),
                                .Union => mod.typeToUnion(ty).?.field_names.len,
                                else => unreachable,
                            }) |field_i_usize| {
                                const field_i: u32 = @intCast(field_i_usize);
                                const field_ty = ty.structFieldType(field_i, mod);
                                if ((zig_ty_tag == .Struct and ty.structFieldIsComptime(field_i, mod)) or
                                    !field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

                                self.updateHasherRecurse(hasher, field_ty, switch (self.kind) {
                                    .forward, .forward_parameter => .forward,
                                    .complete, .parameter => .complete,
                                    .global => .global,
                                    .payload => unreachable,
                                });
                                hasher.update(if (ty.isSimpleTuple(mod))
                                    std.fmt.bufPrint(&name_buf, "f{}", .{field_i}) catch unreachable
                                else
                                    mod.intern_pool.stringToSlice(switch (zig_ty_tag) {
                                        .Struct => ty.legacyStructFieldName(field_i, mod),
                                        .Union => mod.typeToUnion(ty).?.field_names.get(ip)[field_i],
                                        else => unreachable,
                                    }));
                                autoHash(hasher, AlignAs.fieldAlign(ty, field_i, mod).@"align");
                            }
                        },

                        .unnamed_struct,
                        .unnamed_union,
                        .packed_unnamed_struct,
                        .packed_unnamed_union,
                        => switch (self.kind) {
                            .forward, .forward_parameter, .complete, .parameter, .global => unreachable,
                            .payload => if (ty.unionTagTypeSafety(mod)) |_| {
                                autoHash(hasher, ty.getOwnerDecl(mod));
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
                            const info = mod.typeToFunc(ty).?;
                            assert(!info.is_generic);
                            const param_kind: Kind = switch (self.kind) {
                                .forward, .forward_parameter => .forward_parameter,
                                .complete, .parameter, .global => .parameter,
                                .payload => unreachable,
                            };

                            self.updateHasherRecurse(hasher, Type.fromInterned(info.return_type), param_kind);
                            for (info.param_types.get(ip)) |param_type| {
                                if (!Type.fromInterned(param_type).hasRuntimeBitsIgnoreComptime(mod)) continue;
                                self.updateHasherRecurse(hasher, Type.fromInterned(param_type), param_kind);
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
            return @as(u32, @truncate(self.to64().hash(ty)));
        }
    };
};
