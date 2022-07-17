const Dwarf = @This();

const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const fs = std.fs;
const leb128 = std.leb;
const log = std.log.scoped(.dwarf);
const mem = std.mem;

const link = @import("../link.zig");
const trace = @import("../tracy.zig").trace;

const Allocator = mem.Allocator;
const DW = std.dwarf;
const File = link.File;
const LinkBlock = File.LinkBlock;
const LinkFn = File.LinkFn;
const Module = @import("../Module.zig");
const Value = @import("../value.zig").Value;
const Type = @import("../type.zig").Type;

allocator: Allocator,
tag: File.Tag,
ptr_width: PtrWidth,
target: std.Target,

/// A list of `File.LinkFn` whose Line Number Programs have surplus capacity.
/// This is the same concept as `text_block_free_list`; see those doc comments.
dbg_line_fn_free_list: std.AutoHashMapUnmanaged(*SrcFn, void) = .{},
dbg_line_fn_first: ?*SrcFn = null,
dbg_line_fn_last: ?*SrcFn = null,

/// A list of `Atom`s whose corresponding .debug_info tags have surplus capacity.
/// This is the same concept as `text_block_free_list`; see those doc comments.
atom_free_list: std.AutoHashMapUnmanaged(*Atom, void) = .{},
atom_first: ?*Atom = null,
atom_last: ?*Atom = null,

abbrev_table_offset: ?u64 = null,

/// TODO replace with InternPool
/// Table of debug symbol names.
strtab: std.ArrayListUnmanaged(u8) = .{},

/// List of atoms that are owned directly by the DWARF module.
/// TODO convert links in DebugInfoAtom into indices and make
/// sure every atom is owned by this module.
managed_atoms: std.ArrayListUnmanaged(*Atom) = .{},

global_abbrev_relocs: std.ArrayListUnmanaged(AbbrevRelocation) = .{},

pub const Atom = struct {
    /// Previous/next linked list pointers.
    /// This is the linked list node for this Decl's corresponding .debug_info tag.
    prev: ?*Atom,
    next: ?*Atom,
    /// Offset into .debug_info pointing to the tag for this Decl.
    off: u32,
    /// Size of the .debug_info tag for this Decl, not including padding.
    len: u32,
};

/// Represents state of the analysed Decl.
/// Includes Decl's abbrev table of type Types, matching arena
/// and a set of relocations that will be resolved once this
/// Decl's inner Atom is assigned an offset within the DWARF section.
pub const DeclState = struct {
    gpa: Allocator,
    mod: *Module,
    dbg_line: std.ArrayList(u8),
    dbg_info: std.ArrayList(u8),
    abbrev_type_arena: std.heap.ArenaAllocator,
    abbrev_table: std.ArrayListUnmanaged(AbbrevEntry) = .{},
    abbrev_resolver: std.HashMapUnmanaged(
        Type,
        u32,
        Type.HashContext64,
        std.hash_map.default_max_load_percentage,
    ) = .{},
    abbrev_relocs: std.ArrayListUnmanaged(AbbrevRelocation) = .{},
    exprloc_relocs: std.ArrayListUnmanaged(ExprlocRelocation) = .{},

    fn init(gpa: Allocator, mod: *Module) DeclState {
        return .{
            .gpa = gpa,
            .mod = mod,
            .dbg_line = std.ArrayList(u8).init(gpa),
            .dbg_info = std.ArrayList(u8).init(gpa),
            .abbrev_type_arena = std.heap.ArenaAllocator.init(gpa),
        };
    }

    pub fn deinit(self: *DeclState) void {
        self.dbg_line.deinit();
        self.dbg_info.deinit();
        self.abbrev_type_arena.deinit();
        self.abbrev_table.deinit(self.gpa);
        self.abbrev_resolver.deinit(self.gpa);
        self.abbrev_relocs.deinit(self.gpa);
        self.exprloc_relocs.deinit(self.gpa);
    }

    pub fn addExprlocReloc(self: *DeclState, target: u32, offset: u32, is_ptr: bool) !void {
        log.debug("{x}: target sym @{d}, via GOT {}", .{ offset, target, is_ptr });
        try self.exprloc_relocs.append(self.gpa, .{
            .@"type" = if (is_ptr) .got_load else .direct_load,
            .target = target,
            .offset = offset,
        });
    }

    /// Adds local type relocation of the form: @offset => @this + addend
    /// @this signifies the offset within the .debug_abbrev section of the containing atom.
    pub fn addTypeRelocLocal(self: *DeclState, atom: *const Atom, offset: u32, addend: u32) !void {
        log.debug("{x}: @this + {x}", .{ offset, addend });
        try self.abbrev_relocs.append(self.gpa, .{
            .target = null,
            .atom = atom,
            .offset = offset,
            .addend = addend,
        });
    }

    /// Adds global type relocation of the form: @offset => @symbol + 0
    /// @symbol signifies a type abbreviation posititioned somewhere in the .debug_abbrev section
    /// which we use as our target of the relocation.
    pub fn addTypeRelocGlobal(self: *DeclState, atom: *const Atom, ty: Type, offset: u32) !void {
        const resolv = self.abbrev_resolver.getContext(ty, .{
            .mod = self.mod,
        }) orelse blk: {
            const sym_index = @intCast(u32, self.abbrev_table.items.len);
            try self.abbrev_table.append(self.gpa, .{
                .atom = atom,
                .@"type" = ty,
                .offset = undefined,
            });
            log.debug("@{d}: {}", .{ sym_index, ty.fmtDebug() });
            try self.abbrev_resolver.putNoClobberContext(self.gpa, ty, sym_index, .{
                .mod = self.mod,
            });
            break :blk self.abbrev_resolver.getContext(ty, .{
                .mod = self.mod,
            }).?;
        };
        log.debug("{x}: @{d} + 0", .{ offset, resolv });
        try self.abbrev_relocs.append(self.gpa, .{
            .target = resolv,
            .atom = atom,
            .offset = offset,
            .addend = 0,
        });
    }

    fn addDbgInfoType(
        self: *DeclState,
        module: *Module,
        atom: *Atom,
        ty: Type,
    ) error{OutOfMemory}!void {
        const arena = self.abbrev_type_arena.allocator();
        const dbg_info_buffer = &self.dbg_info;
        const target = module.getTarget();
        const target_endian = target.cpu.arch.endian();

        switch (ty.zigTypeTag()) {
            .NoReturn => unreachable,
            .Void => {
                try dbg_info_buffer.append(@enumToInt(AbbrevKind.pad1));
            },
            .Bool => {
                try dbg_info_buffer.appendSlice(&[_]u8{
                    @enumToInt(AbbrevKind.base_type),
                    DW.ATE.boolean, // DW.AT.encoding ,  DW.FORM.data1
                    1, // DW.AT.byte_size,  DW.FORM.data1
                    'b', 'o', 'o', 'l', 0, // DW.AT.name,  DW.FORM.string
                });
            },
            .Int => {
                const info = ty.intInfo(target);
                try dbg_info_buffer.ensureUnusedCapacity(12);
                dbg_info_buffer.appendAssumeCapacity(@enumToInt(AbbrevKind.base_type));
                // DW.AT.encoding, DW.FORM.data1
                dbg_info_buffer.appendAssumeCapacity(switch (info.signedness) {
                    .signed => DW.ATE.signed,
                    .unsigned => DW.ATE.unsigned,
                });
                // DW.AT.byte_size,  DW.FORM.data1
                dbg_info_buffer.appendAssumeCapacity(@intCast(u8, ty.abiSize(target)));
                // DW.AT.name,  DW.FORM.string
                try dbg_info_buffer.writer().print("{}\x00", .{ty.fmt(module)});
            },
            .Optional => {
                if (ty.isPtrLikeOptional()) {
                    try dbg_info_buffer.ensureUnusedCapacity(12);
                    dbg_info_buffer.appendAssumeCapacity(@enumToInt(AbbrevKind.base_type));
                    // DW.AT.encoding, DW.FORM.data1
                    dbg_info_buffer.appendAssumeCapacity(DW.ATE.address);
                    // DW.AT.byte_size,  DW.FORM.data1
                    dbg_info_buffer.appendAssumeCapacity(@intCast(u8, ty.abiSize(target)));
                    // DW.AT.name,  DW.FORM.string
                    try dbg_info_buffer.writer().print("{}\x00", .{ty.fmt(module)});
                } else {
                    // Non-pointer optionals are structs: struct { .maybe = *, .val = * }
                    var buf = try arena.create(Type.Payload.ElemType);
                    const payload_ty = ty.optionalChild(buf);
                    // DW.AT.structure_type
                    try dbg_info_buffer.append(@enumToInt(AbbrevKind.struct_type));
                    // DW.AT.byte_size, DW.FORM.sdata
                    const abi_size = ty.abiSize(target);
                    try leb128.writeULEB128(dbg_info_buffer.writer(), abi_size);
                    // DW.AT.name, DW.FORM.string
                    try dbg_info_buffer.writer().print("{}\x00", .{ty.fmt(module)});
                    // DW.AT.member
                    try dbg_info_buffer.ensureUnusedCapacity(7);
                    dbg_info_buffer.appendAssumeCapacity(@enumToInt(AbbrevKind.struct_member));
                    // DW.AT.name, DW.FORM.string
                    dbg_info_buffer.appendSliceAssumeCapacity("maybe");
                    dbg_info_buffer.appendAssumeCapacity(0);
                    // DW.AT.type, DW.FORM.ref4
                    var index = dbg_info_buffer.items.len;
                    try dbg_info_buffer.resize(index + 4);
                    try self.addTypeRelocGlobal(atom, Type.bool, @intCast(u32, index));
                    // DW.AT.data_member_location, DW.FORM.sdata
                    try dbg_info_buffer.ensureUnusedCapacity(6);
                    dbg_info_buffer.appendAssumeCapacity(0);
                    // DW.AT.member
                    dbg_info_buffer.appendAssumeCapacity(@enumToInt(AbbrevKind.struct_member));
                    // DW.AT.name, DW.FORM.string
                    dbg_info_buffer.appendSliceAssumeCapacity("val");
                    dbg_info_buffer.appendAssumeCapacity(0);
                    // DW.AT.type, DW.FORM.ref4
                    index = dbg_info_buffer.items.len;
                    try dbg_info_buffer.resize(index + 4);
                    try self.addTypeRelocGlobal(atom, payload_ty, @intCast(u32, index));
                    // DW.AT.data_member_location, DW.FORM.sdata
                    const offset = abi_size - payload_ty.abiSize(target);
                    try leb128.writeULEB128(dbg_info_buffer.writer(), offset);
                    // DW.AT.structure_type delimit children
                    try dbg_info_buffer.append(0);
                }
            },
            .Pointer => {
                if (ty.isSlice()) {
                    // Slices are structs: struct { .ptr = *, .len = N }
                    // DW.AT.structure_type
                    try dbg_info_buffer.ensureUnusedCapacity(2);
                    dbg_info_buffer.appendAssumeCapacity(@enumToInt(AbbrevKind.struct_type));
                    // DW.AT.byte_size, DW.FORM.sdata
                    dbg_info_buffer.appendAssumeCapacity(@sizeOf(usize) * 2);
                    // DW.AT.name, DW.FORM.string
                    try dbg_info_buffer.writer().print("{}\x00", .{ty.fmt(module)});
                    // DW.AT.member
                    try dbg_info_buffer.ensureUnusedCapacity(5);
                    dbg_info_buffer.appendAssumeCapacity(@enumToInt(AbbrevKind.struct_member));
                    // DW.AT.name, DW.FORM.string
                    dbg_info_buffer.appendSliceAssumeCapacity("ptr");
                    dbg_info_buffer.appendAssumeCapacity(0);
                    // DW.AT.type, DW.FORM.ref4
                    var index = dbg_info_buffer.items.len;
                    try dbg_info_buffer.resize(index + 4);
                    var buf = try arena.create(Type.SlicePtrFieldTypeBuffer);
                    const ptr_ty = ty.slicePtrFieldType(buf);
                    try self.addTypeRelocGlobal(atom, ptr_ty, @intCast(u32, index));
                    // DW.AT.data_member_location, DW.FORM.sdata
                    try dbg_info_buffer.ensureUnusedCapacity(6);
                    dbg_info_buffer.appendAssumeCapacity(0);
                    // DW.AT.member
                    dbg_info_buffer.appendAssumeCapacity(@enumToInt(AbbrevKind.struct_member));
                    // DW.AT.name, DW.FORM.string
                    dbg_info_buffer.appendSliceAssumeCapacity("len");
                    dbg_info_buffer.appendAssumeCapacity(0);
                    // DW.AT.type, DW.FORM.ref4
                    index = dbg_info_buffer.items.len;
                    try dbg_info_buffer.resize(index + 4);
                    try self.addTypeRelocGlobal(atom, Type.usize, @intCast(u32, index));
                    // DW.AT.data_member_location, DW.FORM.sdata
                    try dbg_info_buffer.ensureUnusedCapacity(2);
                    dbg_info_buffer.appendAssumeCapacity(@sizeOf(usize));
                    // DW.AT.structure_type delimit children
                    dbg_info_buffer.appendAssumeCapacity(0);
                } else {
                    try dbg_info_buffer.ensureUnusedCapacity(5);
                    dbg_info_buffer.appendAssumeCapacity(@enumToInt(AbbrevKind.ptr_type));
                    // DW.AT.type, DW.FORM.ref4
                    const index = dbg_info_buffer.items.len;
                    try dbg_info_buffer.resize(index + 4);
                    try self.addTypeRelocGlobal(atom, ty.childType(), @intCast(u32, index));
                }
            },
            .Array => {
                // DW.AT.array_type
                try dbg_info_buffer.append(@enumToInt(AbbrevKind.array_type));
                // DW.AT.name, DW.FORM.string
                try dbg_info_buffer.writer().print("{}\x00", .{ty.fmt(module)});
                // DW.AT.type, DW.FORM.ref4
                var index = dbg_info_buffer.items.len;
                try dbg_info_buffer.resize(index + 4);
                try self.addTypeRelocGlobal(atom, ty.childType(), @intCast(u32, index));
                // DW.AT.subrange_type
                try dbg_info_buffer.append(@enumToInt(AbbrevKind.array_dim));
                // DW.AT.type, DW.FORM.ref4
                index = dbg_info_buffer.items.len;
                try dbg_info_buffer.resize(index + 4);
                try self.addTypeRelocGlobal(atom, Type.usize, @intCast(u32, index));
                // DW.AT.count, DW.FORM.udata
                const len = ty.arrayLenIncludingSentinel();
                try leb128.writeULEB128(dbg_info_buffer.writer(), len);
                // DW.AT.array_type delimit children
                try dbg_info_buffer.append(0);
            },
            .Struct => blk: {
                // DW.AT.structure_type
                try dbg_info_buffer.append(@enumToInt(AbbrevKind.struct_type));
                // DW.AT.byte_size, DW.FORM.sdata
                const abi_size = ty.abiSize(target);
                try leb128.writeULEB128(dbg_info_buffer.writer(), abi_size);

                switch (ty.tag()) {
                    .tuple, .anon_struct => {
                        // DW.AT.name, DW.FORM.string
                        try dbg_info_buffer.writer().print("{}\x00", .{ty.fmt(module)});

                        const fields = ty.tupleFields();
                        for (fields.types) |field, field_index| {
                            // DW.AT.member
                            try dbg_info_buffer.append(@enumToInt(AbbrevKind.struct_member));
                            // DW.AT.name, DW.FORM.string
                            try dbg_info_buffer.writer().print("{d}\x00", .{field_index});
                            // DW.AT.type, DW.FORM.ref4
                            var index = dbg_info_buffer.items.len;
                            try dbg_info_buffer.resize(index + 4);
                            try self.addTypeRelocGlobal(atom, field, @intCast(u32, index));
                            // DW.AT.data_member_location, DW.FORM.sdata
                            const field_off = ty.structFieldOffset(field_index, target);
                            try leb128.writeULEB128(dbg_info_buffer.writer(), field_off);
                        }
                    },
                    else => {
                        // DW.AT.name, DW.FORM.string
                        const struct_name = try ty.nameAllocArena(arena, module);
                        try dbg_info_buffer.ensureUnusedCapacity(struct_name.len + 1);
                        dbg_info_buffer.appendSliceAssumeCapacity(struct_name);
                        dbg_info_buffer.appendAssumeCapacity(0);

                        const struct_obj = ty.castTag(.@"struct").?.data;
                        if (struct_obj.layout == .Packed) {
                            log.debug("TODO implement .debug_info for packed structs", .{});
                            break :blk;
                        }

                        const fields = ty.structFields();
                        for (fields.keys()) |field_name, field_index| {
                            const field = fields.get(field_name).?;
                            if (!field.ty.hasRuntimeBits()) continue;
                            // DW.AT.member
                            try dbg_info_buffer.ensureUnusedCapacity(field_name.len + 2);
                            dbg_info_buffer.appendAssumeCapacity(@enumToInt(AbbrevKind.struct_member));
                            // DW.AT.name, DW.FORM.string
                            dbg_info_buffer.appendSliceAssumeCapacity(field_name);
                            dbg_info_buffer.appendAssumeCapacity(0);
                            // DW.AT.type, DW.FORM.ref4
                            var index = dbg_info_buffer.items.len;
                            try dbg_info_buffer.resize(index + 4);
                            try self.addTypeRelocGlobal(atom, field.ty, @intCast(u32, index));
                            // DW.AT.data_member_location, DW.FORM.sdata
                            const field_off = ty.structFieldOffset(field_index, target);
                            try leb128.writeULEB128(dbg_info_buffer.writer(), field_off);
                        }
                    },
                }

                // DW.AT.structure_type delimit children
                try dbg_info_buffer.append(0);
            },
            .Enum => {
                // DW.AT.enumeration_type
                try dbg_info_buffer.append(@enumToInt(AbbrevKind.enum_type));
                // DW.AT.byte_size, DW.FORM.sdata
                const abi_size = ty.abiSize(target);
                try leb128.writeULEB128(dbg_info_buffer.writer(), abi_size);
                // DW.AT.name, DW.FORM.string
                const enum_name = try ty.nameAllocArena(arena, module);
                try dbg_info_buffer.ensureUnusedCapacity(enum_name.len + 1);
                dbg_info_buffer.appendSliceAssumeCapacity(enum_name);
                dbg_info_buffer.appendAssumeCapacity(0);

                const fields = ty.enumFields();
                const values: ?Module.EnumFull.ValueMap = switch (ty.tag()) {
                    .enum_full, .enum_nonexhaustive => ty.cast(Type.Payload.EnumFull).?.data.values,
                    .enum_simple => null,
                    .enum_numbered => ty.castTag(.enum_numbered).?.data.values,
                    else => unreachable,
                };
                for (fields.keys()) |field_name, field_i| {
                    // DW.AT.enumerator
                    try dbg_info_buffer.ensureUnusedCapacity(field_name.len + 2 + @sizeOf(u64));
                    dbg_info_buffer.appendAssumeCapacity(@enumToInt(AbbrevKind.enum_variant));
                    // DW.AT.name, DW.FORM.string
                    dbg_info_buffer.appendSliceAssumeCapacity(field_name);
                    dbg_info_buffer.appendAssumeCapacity(0);
                    // DW.AT.const_value, DW.FORM.data8
                    const value: u64 = if (values) |vals| value: {
                        if (vals.count() == 0) break :value @intCast(u64, field_i); // auto-numbered
                        const value = vals.keys()[field_i];
                        var int_buffer: Value.Payload.U64 = undefined;
                        break :value value.enumToInt(ty, &int_buffer).toUnsignedInt(target);
                    } else @intCast(u64, field_i);
                    mem.writeInt(u64, dbg_info_buffer.addManyAsArrayAssumeCapacity(8), value, target_endian);
                }

                // DW.AT.enumeration_type delimit children
                try dbg_info_buffer.append(0);
            },
            .Union => {
                const layout = ty.unionGetLayout(target);
                const union_obj = ty.cast(Type.Payload.Union).?.data;
                const payload_offset = if (layout.tag_align >= layout.payload_align) layout.tag_size else 0;
                const tag_offset = if (layout.tag_align >= layout.payload_align) 0 else layout.payload_size;
                const is_tagged = layout.tag_size > 0;
                const union_name = try ty.nameAllocArena(arena, module);

                // TODO this is temporary to match current state of unions in Zig - we don't yet have
                // safety checks implemented meaning the implicit tag is not yet stored and generated
                // for untagged unions.
                if (is_tagged) {
                    // DW.AT.structure_type
                    try dbg_info_buffer.append(@enumToInt(AbbrevKind.struct_type));
                    // DW.AT.byte_size, DW.FORM.sdata
                    try leb128.writeULEB128(dbg_info_buffer.writer(), layout.abi_size);
                    // DW.AT.name, DW.FORM.string
                    try dbg_info_buffer.ensureUnusedCapacity(union_name.len + 1);
                    dbg_info_buffer.appendSliceAssumeCapacity(union_name);
                    dbg_info_buffer.appendAssumeCapacity(0);

                    // DW.AT.member
                    try dbg_info_buffer.ensureUnusedCapacity(9);
                    dbg_info_buffer.appendAssumeCapacity(@enumToInt(AbbrevKind.struct_member));
                    // DW.AT.name, DW.FORM.string
                    dbg_info_buffer.appendSliceAssumeCapacity("payload");
                    dbg_info_buffer.appendAssumeCapacity(0);
                    // DW.AT.type, DW.FORM.ref4
                    const inner_union_index = dbg_info_buffer.items.len;
                    try dbg_info_buffer.resize(inner_union_index + 4);
                    try self.addTypeRelocLocal(atom, @intCast(u32, inner_union_index), 5);
                    // DW.AT.data_member_location, DW.FORM.sdata
                    try leb128.writeULEB128(dbg_info_buffer.writer(), payload_offset);
                }

                // DW.AT.union_type
                try dbg_info_buffer.append(@enumToInt(AbbrevKind.union_type));
                // DW.AT.byte_size, DW.FORM.sdata,
                try leb128.writeULEB128(dbg_info_buffer.writer(), layout.payload_size);
                // DW.AT.name, DW.FORM.string
                if (is_tagged) {
                    try dbg_info_buffer.writer().print("AnonUnion\x00", .{});
                } else {
                    try dbg_info_buffer.writer().print("{s}\x00", .{union_name});
                }

                const fields = ty.unionFields();
                for (fields.keys()) |field_name| {
                    const field = fields.get(field_name).?;
                    if (!field.ty.hasRuntimeBits()) continue;
                    // DW.AT.member
                    try dbg_info_buffer.append(@enumToInt(AbbrevKind.struct_member));
                    // DW.AT.name, DW.FORM.string
                    try dbg_info_buffer.writer().print("{s}\x00", .{field_name});
                    // DW.AT.type, DW.FORM.ref4
                    const index = dbg_info_buffer.items.len;
                    try dbg_info_buffer.resize(index + 4);
                    try self.addTypeRelocGlobal(atom, field.ty, @intCast(u32, index));
                    // DW.AT.data_member_location, DW.FORM.sdata
                    try dbg_info_buffer.append(0);
                }
                // DW.AT.union_type delimit children
                try dbg_info_buffer.append(0);

                if (is_tagged) {
                    // DW.AT.member
                    try dbg_info_buffer.ensureUnusedCapacity(5);
                    dbg_info_buffer.appendAssumeCapacity(@enumToInt(AbbrevKind.struct_member));
                    // DW.AT.name, DW.FORM.string
                    dbg_info_buffer.appendSliceAssumeCapacity("tag");
                    dbg_info_buffer.appendAssumeCapacity(0);
                    // DW.AT.type, DW.FORM.ref4
                    const index = dbg_info_buffer.items.len;
                    try dbg_info_buffer.resize(index + 4);
                    try self.addTypeRelocGlobal(atom, union_obj.tag_ty, @intCast(u32, index));
                    // DW.AT.data_member_location, DW.FORM.sdata
                    try leb128.writeULEB128(dbg_info_buffer.writer(), tag_offset);

                    // DW.AT.structure_type delimit children
                    try dbg_info_buffer.append(0);
                }
            },
            .ErrorSet => {
                try addDbgInfoErrorSet(
                    self.abbrev_type_arena.allocator(),
                    module,
                    ty,
                    target,
                    &self.dbg_info,
                );
            },
            .ErrorUnion => {
                const error_ty = ty.errorUnionSet();
                const payload_ty = ty.errorUnionPayload();
                const payload_align = payload_ty.abiAlignment(target);
                const error_align = Type.anyerror.abiAlignment(target);
                const abi_size = ty.abiSize(target);
                const payload_off = if (error_align >= payload_align) Type.anyerror.abiSize(target) else 0;
                const error_off = if (error_align >= payload_align) 0 else payload_ty.abiSize(target);

                // DW.AT.structure_type
                try dbg_info_buffer.append(@enumToInt(AbbrevKind.struct_type));
                // DW.AT.byte_size, DW.FORM.sdata
                try leb128.writeULEB128(dbg_info_buffer.writer(), abi_size);
                // DW.AT.name, DW.FORM.string
                const name = try ty.nameAllocArena(arena, module);
                try dbg_info_buffer.writer().print("{s}\x00", .{name});

                // DW.AT.member
                try dbg_info_buffer.ensureUnusedCapacity(7);
                dbg_info_buffer.appendAssumeCapacity(@enumToInt(AbbrevKind.struct_member));
                // DW.AT.name, DW.FORM.string
                dbg_info_buffer.appendSliceAssumeCapacity("value");
                dbg_info_buffer.appendAssumeCapacity(0);
                // DW.AT.type, DW.FORM.ref4
                var index = dbg_info_buffer.items.len;
                try dbg_info_buffer.resize(index + 4);
                try self.addTypeRelocGlobal(atom, payload_ty, @intCast(u32, index));
                // DW.AT.data_member_location, DW.FORM.sdata
                try leb128.writeULEB128(dbg_info_buffer.writer(), payload_off);

                // DW.AT.member
                try dbg_info_buffer.ensureUnusedCapacity(5);
                dbg_info_buffer.appendAssumeCapacity(@enumToInt(AbbrevKind.struct_member));
                // DW.AT.name, DW.FORM.string
                dbg_info_buffer.appendSliceAssumeCapacity("err");
                dbg_info_buffer.appendAssumeCapacity(0);
                // DW.AT.type, DW.FORM.ref4
                index = dbg_info_buffer.items.len;
                try dbg_info_buffer.resize(index + 4);
                try self.addTypeRelocGlobal(atom, error_ty, @intCast(u32, index));
                // DW.AT.data_member_location, DW.FORM.sdata
                try leb128.writeULEB128(dbg_info_buffer.writer(), error_off);

                // DW.AT.structure_type delimit children
                try dbg_info_buffer.append(0);
            },
            else => {
                log.debug("TODO implement .debug_info for type '{}'", .{ty.fmtDebug()});
                try dbg_info_buffer.append(@enumToInt(AbbrevKind.pad1));
            },
        }
    }
};

pub const AbbrevEntry = struct {
    atom: *const Atom,
    @"type": Type,
    offset: u32,
};

pub const AbbrevRelocation = struct {
    /// If target is null, we deal with a local relocation that is based on simple offset + addend
    /// only.
    target: ?u32,
    atom: *const Atom,
    offset: u32,
    addend: u32,
};

pub const ExprlocRelocation = struct {
    /// Type of the relocation: direct load ref, or GOT load ref (via GOT table)
    @"type": enum {
        direct_load,
        got_load,
    },
    /// Index of the target in the linker's locals symbol table.
    target: u32,
    /// Offset within the debug info buffer where to patch up the address value.
    offset: u32,
};

pub const SrcFn = struct {
    /// Offset from the beginning of the Debug Line Program header that contains this function.
    off: u32,
    /// Size of the line number program component belonging to this function, not
    /// including padding.
    len: u32,

    /// Points to the previous and next neighbors, based on the offset from .debug_line.
    /// This can be used to find, for example, the capacity of this `SrcFn`.
    prev: ?*SrcFn,
    next: ?*SrcFn,

    pub const empty: SrcFn = .{
        .off = 0,
        .len = 0,
        .prev = null,
        .next = null,
    };
};

pub const PtrWidth = enum { p32, p64 };

pub const AbbrevKind = enum(u8) {
    compile_unit = 1,
    subprogram,
    subprogram_retvoid,
    base_type,
    ptr_type,
    struct_type,
    struct_member,
    enum_type,
    enum_variant,
    union_type,
    pad1,
    parameter,
    variable,
    array_type,
    array_dim,
};

/// The reloc offset for the virtual address of a function in its Line Number Program.
/// Size is a virtual address integer.
const dbg_line_vaddr_reloc_index = 3;
/// The reloc offset for the virtual address of a function in its .debug_info TAG.subprogram.
/// Size is a virtual address integer.
const dbg_info_low_pc_reloc_index = 1;

const min_nop_size = 2;

/// When allocating, the ideal_capacity is calculated by
/// actual_capacity + (actual_capacity / ideal_factor)
const ideal_factor = 3;

pub fn init(allocator: Allocator, tag: File.Tag, target: std.Target) Dwarf {
    const ptr_width: PtrWidth = switch (target.cpu.arch.ptrBitWidth()) {
        0...32 => .p32,
        33...64 => .p64,
        else => unreachable,
    };
    return Dwarf{
        .allocator = allocator,
        .tag = tag,
        .ptr_width = ptr_width,
        .target = target,
    };
}

pub fn deinit(self: *Dwarf) void {
    const gpa = self.allocator;
    self.dbg_line_fn_free_list.deinit(gpa);
    self.atom_free_list.deinit(gpa);
    self.strtab.deinit(gpa);
    self.global_abbrev_relocs.deinit(gpa);

    for (self.managed_atoms.items) |atom| {
        gpa.destroy(atom);
    }
    self.managed_atoms.deinit(gpa);
}

/// Initializes Decl's state and its matching output buffers.
/// Call this before `commitDeclState`.
pub fn initDeclState(self: *Dwarf, mod: *Module, decl: *Module.Decl) !DeclState {
    const tracy = trace(@src());
    defer tracy.end();

    const decl_name = try decl.getFullyQualifiedName(mod);
    defer self.allocator.free(decl_name);

    log.debug("initDeclState {s}{*}", .{ decl_name, decl });

    const gpa = self.allocator;
    var decl_state = DeclState.init(gpa, mod);
    errdefer decl_state.deinit();
    const dbg_line_buffer = &decl_state.dbg_line;
    const dbg_info_buffer = &decl_state.dbg_info;

    assert(decl.has_tv);

    switch (decl.ty.zigTypeTag()) {
        .Fn => {
            // For functions we need to add a prologue to the debug line program.
            try dbg_line_buffer.ensureTotalCapacity(26);

            const func = decl.val.castTag(.function).?.data;
            log.debug("decl.src_line={d}, func.lbrace_line={d}, func.rbrace_line={d}", .{
                decl.src_line,
                func.lbrace_line,
                func.rbrace_line,
            });
            const line = @intCast(u28, decl.src_line + func.lbrace_line);

            const ptr_width_bytes = self.ptrWidthBytes();
            dbg_line_buffer.appendSliceAssumeCapacity(&[_]u8{
                DW.LNS.extended_op,
                ptr_width_bytes + 1,
                DW.LNE.set_address,
            });
            // This is the "relocatable" vaddr, corresponding to `code_buffer` index `0`.
            assert(dbg_line_vaddr_reloc_index == dbg_line_buffer.items.len);
            dbg_line_buffer.items.len += ptr_width_bytes;

            dbg_line_buffer.appendAssumeCapacity(DW.LNS.advance_line);
            // This is the "relocatable" relative line offset from the previous function's end curly
            // to this function's begin curly.
            assert(self.getRelocDbgLineOff() == dbg_line_buffer.items.len);
            // Here we use a ULEB128-fixed-4 to make sure this field can be overwritten later.
            leb128.writeUnsignedFixed(4, dbg_line_buffer.addManyAsArrayAssumeCapacity(4), line);

            dbg_line_buffer.appendAssumeCapacity(DW.LNS.set_file);
            assert(self.getRelocDbgFileIndex() == dbg_line_buffer.items.len);
            // Once we support more than one source file, this will have the ability to be more
            // than one possible value.
            const file_index = 1;
            leb128.writeUnsignedFixed(4, dbg_line_buffer.addManyAsArrayAssumeCapacity(4), file_index);

            // Emit a line for the begin curly with prologue_end=false. The codegen will
            // do the work of setting prologue_end=true and epilogue_begin=true.
            dbg_line_buffer.appendAssumeCapacity(DW.LNS.copy);

            // .debug_info subprogram
            const decl_name_with_null = decl_name[0 .. decl_name.len + 1];
            try dbg_info_buffer.ensureUnusedCapacity(25 + decl_name_with_null.len);

            const fn_ret_type = decl.ty.fnReturnType();
            const fn_ret_has_bits = fn_ret_type.hasRuntimeBits();
            if (fn_ret_has_bits) {
                dbg_info_buffer.appendAssumeCapacity(@enumToInt(AbbrevKind.subprogram));
            } else {
                dbg_info_buffer.appendAssumeCapacity(@enumToInt(AbbrevKind.subprogram_retvoid));
            }
            // These get overwritten after generating the machine code. These values are
            // "relocations" and have to be in this fixed place so that functions can be
            // moved in virtual address space.
            assert(dbg_info_low_pc_reloc_index == dbg_info_buffer.items.len);
            dbg_info_buffer.items.len += ptr_width_bytes; // DW.AT.low_pc,  DW.FORM.addr
            assert(self.getRelocDbgInfoSubprogramHighPC() == dbg_info_buffer.items.len);
            dbg_info_buffer.items.len += 4; // DW.AT.high_pc,  DW.FORM.data4
            //
            if (fn_ret_has_bits) {
                const atom = switch (self.tag) {
                    .elf => &decl.link.elf.dbg_info_atom,
                    .macho => &decl.link.macho.dbg_info_atom,
                    .wasm => &decl.link.wasm.dbg_info_atom,
                    else => unreachable,
                };
                try decl_state.addTypeRelocGlobal(atom, fn_ret_type, @intCast(u32, dbg_info_buffer.items.len));
                dbg_info_buffer.items.len += 4; // DW.AT.type,  DW.FORM.ref4
            }

            dbg_info_buffer.appendSliceAssumeCapacity(decl_name_with_null); // DW.AT.name, DW.FORM.string

        },
        else => {
            // TODO implement .debug_info for global variables
        },
    }

    return decl_state;
}

pub fn commitDeclState(
    self: *Dwarf,
    file: *File,
    module: *Module,
    decl: *Module.Decl,
    sym_addr: u64,
    sym_size: u64,
    decl_state: *DeclState,
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.allocator;
    var dbg_line_buffer = &decl_state.dbg_line;
    var dbg_info_buffer = &decl_state.dbg_info;

    const target_endian = self.target.cpu.arch.endian();

    assert(decl.has_tv);
    switch (decl.ty.zigTypeTag()) {
        .Fn => {
            // Since the Decl is a function, we need to update the .debug_line program.
            // Perform the relocations based on vaddr.
            switch (self.ptr_width) {
                .p32 => {
                    {
                        const ptr = dbg_line_buffer.items[dbg_line_vaddr_reloc_index..][0..4];
                        mem.writeInt(u32, ptr, @intCast(u32, sym_addr), target_endian);
                    }
                    {
                        const ptr = dbg_info_buffer.items[dbg_info_low_pc_reloc_index..][0..4];
                        mem.writeInt(u32, ptr, @intCast(u32, sym_addr), target_endian);
                    }
                },
                .p64 => {
                    {
                        const ptr = dbg_line_buffer.items[dbg_line_vaddr_reloc_index..][0..8];
                        mem.writeInt(u64, ptr, sym_addr, target_endian);
                    }
                    {
                        const ptr = dbg_info_buffer.items[dbg_info_low_pc_reloc_index..][0..8];
                        mem.writeInt(u64, ptr, sym_addr, target_endian);
                    }
                },
            }
            {
                const ptr = dbg_info_buffer.items[self.getRelocDbgInfoSubprogramHighPC()..][0..4];
                mem.writeInt(u32, ptr, @intCast(u32, sym_size), target_endian);
            }

            try dbg_line_buffer.appendSlice(&[_]u8{ DW.LNS.extended_op, 1, DW.LNE.end_sequence });

            // Now we have the full contents and may allocate a region to store it.

            // This logic is nearly identical to the logic below in `updateDeclDebugInfo` for
            // `TextBlock` and the .debug_info. If you are editing this logic, you
            // probably need to edit that logic too.
            const src_fn = switch (self.tag) {
                .elf => &decl.fn_link.elf,
                .macho => &decl.fn_link.macho,
                .wasm => &decl.fn_link.wasm.src_fn,
                else => unreachable, // TODO
            };
            src_fn.len = @intCast(u32, dbg_line_buffer.items.len);

            if (self.dbg_line_fn_last) |last| blk: {
                if (src_fn == last) break :blk;
                if (src_fn.next) |next| {
                    // Update existing function - non-last item.
                    if (src_fn.off + src_fn.len + min_nop_size > next.off) {
                        // It grew too big, so we move it to a new location.
                        if (src_fn.prev) |prev| {
                            self.dbg_line_fn_free_list.put(gpa, prev, {}) catch {};
                            prev.next = src_fn.next;
                        }
                        next.prev = src_fn.prev;
                        src_fn.next = null;
                        // Populate where it used to be with NOPs.
                        switch (self.tag) {
                            .elf => {
                                const elf_file = file.cast(File.Elf).?;
                                const debug_line_sect = &elf_file.sections.items[elf_file.debug_line_section_index.?];
                                const file_pos = debug_line_sect.sh_offset + src_fn.off;
                                try pwriteDbgLineNops(elf_file.base.file.?, file_pos, 0, &[0]u8{}, src_fn.len);
                            },
                            .macho => {
                                const macho_file = file.cast(File.MachO).?;
                                const d_sym = &macho_file.d_sym.?;
                                const dwarf_segment = &d_sym.load_commands.items[d_sym.dwarf_segment_cmd_index.?].segment;
                                const debug_line_sect = &dwarf_segment.sections.items[d_sym.debug_line_section_index.?];
                                const file_pos = debug_line_sect.offset + src_fn.off;
                                try pwriteDbgLineNops(d_sym.file, file_pos, 0, &[0]u8{}, src_fn.len);
                            },
                            .wasm => {
                                const wasm_file = file.cast(File.Wasm).?;
                                writeDbgLineNopsBuffered(wasm_file.debug_line.items, src_fn.off, 0, &.{}, src_fn.len);
                            },
                            else => unreachable,
                        }
                        // TODO Look at the free list before appending at the end.
                        src_fn.prev = last;
                        last.next = src_fn;
                        self.dbg_line_fn_last = src_fn;

                        src_fn.off = last.off + padToIdeal(last.len);
                    }
                } else if (src_fn.prev == null) {
                    // Append new function.
                    // TODO Look at the free list before appending at the end.
                    src_fn.prev = last;
                    last.next = src_fn;
                    self.dbg_line_fn_last = src_fn;

                    src_fn.off = last.off + padToIdeal(last.len);
                }
            } else {
                // This is the first function of the Line Number Program.
                self.dbg_line_fn_first = src_fn;
                self.dbg_line_fn_last = src_fn;

                src_fn.off = padToIdeal(self.dbgLineNeededHeaderBytes(module));
            }

            const last_src_fn = self.dbg_line_fn_last.?;
            const needed_size = last_src_fn.off + last_src_fn.len;
            const prev_padding_size: u32 = if (src_fn.prev) |prev| src_fn.off - (prev.off + prev.len) else 0;
            const next_padding_size: u32 = if (src_fn.next) |next| next.off - (src_fn.off + src_fn.len) else 0;

            // We only have support for one compilation unit so far, so the offsets are directly
            // from the .debug_line section.
            switch (self.tag) {
                .elf => {
                    const elf_file = file.cast(File.Elf).?;
                    const debug_line_sect = &elf_file.sections.items[elf_file.debug_line_section_index.?];
                    if (needed_size != debug_line_sect.sh_size) {
                        if (needed_size > elf_file.allocatedSize(debug_line_sect.sh_offset)) {
                            const new_offset = elf_file.findFreeSpace(needed_size, 1);
                            const existing_size = last_src_fn.off;
                            log.debug("moving .debug_line section: {d} bytes from 0x{x} to 0x{x}", .{
                                existing_size,
                                debug_line_sect.sh_offset,
                                new_offset,
                            });
                            const amt = try elf_file.base.file.?.copyRangeAll(
                                debug_line_sect.sh_offset,
                                elf_file.base.file.?,
                                new_offset,
                                existing_size,
                            );
                            if (amt != existing_size) return error.InputOutput;
                            debug_line_sect.sh_offset = new_offset;
                        }
                        debug_line_sect.sh_size = needed_size;
                        elf_file.shdr_table_dirty = true; // TODO look into making only the one section dirty
                        elf_file.debug_line_header_dirty = true;
                    }
                    const file_pos = debug_line_sect.sh_offset + src_fn.off;
                    try pwriteDbgLineNops(
                        elf_file.base.file.?,
                        file_pos,
                        prev_padding_size,
                        dbg_line_buffer.items,
                        next_padding_size,
                    );
                },
                .macho => {
                    const macho_file = file.cast(File.MachO).?;
                    const d_sym = &macho_file.d_sym.?;
                    const dwarf_segment = &d_sym.load_commands.items[d_sym.dwarf_segment_cmd_index.?].segment;
                    const debug_line_sect = &dwarf_segment.sections.items[d_sym.debug_line_section_index.?];
                    if (needed_size != debug_line_sect.size) {
                        if (needed_size > d_sym.allocatedSize(debug_line_sect.offset)) {
                            const new_offset = d_sym.findFreeSpace(needed_size, 1);
                            const existing_size = last_src_fn.off;

                            log.debug("moving __debug_line section: {} bytes from 0x{x} to 0x{x}", .{
                                existing_size,
                                debug_line_sect.offset,
                                new_offset,
                            });

                            try File.MachO.copyRangeAllOverlappingAlloc(
                                gpa,
                                d_sym.file,
                                debug_line_sect.offset,
                                new_offset,
                                existing_size,
                            );

                            debug_line_sect.offset = @intCast(u32, new_offset);
                            debug_line_sect.addr = dwarf_segment.inner.vmaddr + new_offset - dwarf_segment.inner.fileoff;
                        }
                        debug_line_sect.size = needed_size;
                        d_sym.load_commands_dirty = true; // TODO look into making only the one section dirty
                        d_sym.debug_line_header_dirty = true;
                    }
                    const file_pos = debug_line_sect.offset + src_fn.off;
                    try pwriteDbgLineNops(
                        d_sym.file,
                        file_pos,
                        prev_padding_size,
                        dbg_line_buffer.items,
                        next_padding_size,
                    );
                },
                .wasm => {
                    const wasm_file = file.cast(File.Wasm).?;
                    const segment_index = try wasm_file.getDebugLineIndex();
                    const segment = &wasm_file.segments.items[segment_index];
                    const debug_line = &wasm_file.debug_line;
                    if (needed_size != segment.size) {
                        log.debug(" needed size does not equal allocated size: {d}", .{needed_size});
                        if (needed_size > segment.size) {
                            log.debug("  allocating {d} bytes for 'debug line' information", .{needed_size - segment.size});
                            try debug_line.resize(self.allocator, needed_size);
                            mem.set(u8, debug_line.items[segment.size..], 0);
                        }
                        segment.size = needed_size;
                        debug_line.items.len = needed_size;
                    }
                    const offset = segment.offset + src_fn.off;
                    writeDbgLineNopsBuffered(
                        debug_line.items,
                        offset,
                        prev_padding_size,
                        dbg_line_buffer.items,
                        next_padding_size,
                    );
                },
                else => unreachable,
            }

            // .debug_info - End the TAG.subprogram children.
            try dbg_info_buffer.append(0);
        },
        else => {},
    }

    if (dbg_info_buffer.items.len == 0)
        return;

    const atom = switch (self.tag) {
        .elf => &decl.link.elf.dbg_info_atom,
        .macho => &decl.link.macho.dbg_info_atom,
        .wasm => &decl.link.wasm.dbg_info_atom,
        else => unreachable,
    };

    if (decl_state.abbrev_table.items.len > 0) {
        // Now we emit the .debug_info types of the Decl. These will count towards the size of
        // the buffer, so we have to do it before computing the offset, and we can't perform the actual
        // relocations yet.
        var sym_index: usize = 0;
        while (sym_index < decl_state.abbrev_table.items.len) : (sym_index += 1) {
            const symbol = &decl_state.abbrev_table.items[sym_index];
            const ty = symbol.@"type";
            const deferred: bool = blk: {
                if (ty.isAnyError()) break :blk true;
                switch (ty.tag()) {
                    .error_set_inferred => {
                        if (!ty.castTag(.error_set_inferred).?.data.is_resolved) break :blk true;
                    },
                    else => {},
                }
                break :blk false;
            };
            if (deferred) continue;

            symbol.offset = @intCast(u32, dbg_info_buffer.items.len);
            try decl_state.addDbgInfoType(module, atom, ty);
        }
    }

    log.debug("updateDeclDebugInfoAllocation for '{s}'", .{decl.name});
    try self.updateDeclDebugInfoAllocation(file, atom, @intCast(u32, dbg_info_buffer.items.len));

    while (decl_state.abbrev_relocs.popOrNull()) |reloc| {
        if (reloc.target) |target| {
            const symbol = decl_state.abbrev_table.items[target];
            const ty = symbol.@"type";
            const deferred: bool = blk: {
                if (ty.isAnyError()) break :blk true;
                switch (ty.tag()) {
                    .error_set_inferred => {
                        if (!ty.castTag(.error_set_inferred).?.data.is_resolved) break :blk true;
                    },
                    else => {},
                }
                break :blk false;
            };
            if (deferred) {
                try self.global_abbrev_relocs.append(gpa, .{
                    .target = null,
                    .offset = reloc.offset,
                    .atom = reloc.atom,
                    .addend = reloc.addend,
                });
            } else {
                mem.writeInt(
                    u32,
                    dbg_info_buffer.items[reloc.offset..][0..@sizeOf(u32)],
                    symbol.atom.off + symbol.offset + reloc.addend,
                    target_endian,
                );
            }
        } else {
            mem.writeInt(
                u32,
                dbg_info_buffer.items[reloc.offset..][0..@sizeOf(u32)],
                reloc.atom.off + reloc.offset + reloc.addend,
                target_endian,
            );
        }
    }

    while (decl_state.exprloc_relocs.popOrNull()) |reloc| {
        switch (self.tag) {
            .macho => {
                const macho_file = file.cast(File.MachO).?;
                const d_sym = &macho_file.d_sym.?;
                try d_sym.relocs.append(d_sym.base.base.allocator, .{
                    .@"type" = switch (reloc.@"type") {
                        .direct_load => .direct_load,
                        .got_load => .got_load,
                    },
                    .target = reloc.target,
                    .offset = reloc.offset + atom.off,
                    .addend = 0,
                    .prev_vaddr = 0,
                });
            },
            else => unreachable,
        }
    }

    log.debug("writeDeclDebugInfo for '{s}", .{decl.name});
    try self.writeDeclDebugInfo(file, atom, dbg_info_buffer.items);
}

fn updateDeclDebugInfoAllocation(self: *Dwarf, file: *File, atom: *Atom, len: u32) !void {
    const tracy = trace(@src());
    defer tracy.end();

    // This logic is nearly identical to the logic above in `updateDecl` for
    // `SrcFn` and the line number programs. If you are editing this logic, you
    // probably need to edit that logic too.
    const gpa = self.allocator;

    atom.len = len;
    if (self.atom_last) |last| blk: {
        if (atom == last) break :blk;
        if (atom.next) |next| {
            // Update existing Decl - non-last item.
            if (atom.off + atom.len + min_nop_size > next.off) {
                // It grew too big, so we move it to a new location.
                if (atom.prev) |prev| {
                    self.atom_free_list.put(gpa, prev, {}) catch {};
                    prev.next = atom.next;
                }
                next.prev = atom.prev;
                atom.next = null;
                // Populate where it used to be with NOPs.
                switch (self.tag) {
                    .elf => {
                        const elf_file = file.cast(File.Elf).?;
                        const debug_info_sect = &elf_file.sections.items[elf_file.debug_info_section_index.?];
                        const file_pos = debug_info_sect.sh_offset + atom.off;
                        try pwriteDbgInfoNops(elf_file.base.file.?, file_pos, 0, &[0]u8{}, atom.len, false);
                    },
                    .macho => {
                        const macho_file = file.cast(File.MachO).?;
                        const d_sym = &macho_file.d_sym.?;
                        const dwarf_segment = &d_sym.load_commands.items[d_sym.dwarf_segment_cmd_index.?].segment;
                        const debug_info_sect = &dwarf_segment.sections.items[d_sym.debug_info_section_index.?];
                        const file_pos = debug_info_sect.offset + atom.off;
                        try pwriteDbgInfoNops(d_sym.file, file_pos, 0, &[0]u8{}, atom.len, false);
                    },
                    .wasm => {
                        const wasm_file = file.cast(File.Wasm).?;
                        const segment_index = try wasm_file.getDebugInfoIndex();
                        const segment = &wasm_file.segments.items[segment_index];
                        const offset = segment.offset + atom.off;
                        try writeDbgInfoNopsToArrayList(gpa, &wasm_file.debug_info, offset, 0, &.{0}, atom.len, false);
                    },
                    else => unreachable,
                }
                // TODO Look at the free list before appending at the end.
                atom.prev = last;
                last.next = atom;
                self.atom_last = atom;

                atom.off = last.off + padToIdeal(last.len);
            }
        } else if (atom.prev == null) {
            // Append new Decl.
            // TODO Look at the free list before appending at the end.
            atom.prev = last;
            last.next = atom;
            self.atom_last = atom;

            atom.off = last.off + padToIdeal(last.len);
        }
    } else {
        // This is the first Decl of the .debug_info
        self.atom_first = atom;
        self.atom_last = atom;

        atom.off = @intCast(u32, padToIdeal(self.dbgInfoHeaderBytes()));
    }
}

fn writeDeclDebugInfo(self: *Dwarf, file: *File, atom: *Atom, dbg_info_buf: []const u8) !void {
    const tracy = trace(@src());
    defer tracy.end();

    // This logic is nearly identical to the logic above in `updateDecl` for
    // `SrcFn` and the line number programs. If you are editing this logic, you
    // probably need to edit that logic too.
    const gpa = self.allocator;

    const last_decl = self.atom_last.?;
    // +1 for a trailing zero to end the children of the decl tag.
    const needed_size = last_decl.off + last_decl.len + 1;
    const prev_padding_size: u32 = if (atom.prev) |prev| atom.off - (prev.off + prev.len) else 0;
    const next_padding_size: u32 = if (atom.next) |next| next.off - (atom.off + atom.len) else 0;

    // To end the children of the decl tag.
    const trailing_zero = atom.next == null;

    // We only have support for one compilation unit so far, so the offsets are directly
    // from the .debug_info section.
    switch (self.tag) {
        .elf => {
            const elf_file = file.cast(File.Elf).?;
            const debug_info_sect = &elf_file.sections.items[elf_file.debug_info_section_index.?];
            if (needed_size != debug_info_sect.sh_size) {
                if (needed_size > elf_file.allocatedSize(debug_info_sect.sh_offset)) {
                    const new_offset = elf_file.findFreeSpace(needed_size, 1);
                    const existing_size = last_decl.off;
                    log.debug("moving .debug_info section: {d} bytes from 0x{x} to 0x{x}", .{
                        existing_size,
                        debug_info_sect.sh_offset,
                        new_offset,
                    });
                    const amt = try elf_file.base.file.?.copyRangeAll(
                        debug_info_sect.sh_offset,
                        elf_file.base.file.?,
                        new_offset,
                        existing_size,
                    );
                    if (amt != existing_size) return error.InputOutput;
                    debug_info_sect.sh_offset = new_offset;
                }
                debug_info_sect.sh_size = needed_size;
                elf_file.shdr_table_dirty = true; // TODO look into making only the one section dirty
                elf_file.debug_info_header_dirty = true;
            }
            const file_pos = debug_info_sect.sh_offset + atom.off;
            try pwriteDbgInfoNops(
                elf_file.base.file.?,
                file_pos,
                prev_padding_size,
                dbg_info_buf,
                next_padding_size,
                trailing_zero,
            );
        },
        .macho => {
            const macho_file = file.cast(File.MachO).?;
            const d_sym = &macho_file.d_sym.?;
            const dwarf_segment = &d_sym.load_commands.items[d_sym.dwarf_segment_cmd_index.?].segment;
            const debug_info_sect = &dwarf_segment.sections.items[d_sym.debug_info_section_index.?];
            if (needed_size != debug_info_sect.size) {
                if (needed_size > d_sym.allocatedSize(debug_info_sect.offset)) {
                    const new_offset = d_sym.findFreeSpace(needed_size, 1);
                    const existing_size = last_decl.off;

                    log.debug("moving __debug_info section: {} bytes from 0x{x} to 0x{x}", .{
                        existing_size,
                        debug_info_sect.offset,
                        new_offset,
                    });

                    try File.MachO.copyRangeAllOverlappingAlloc(
                        gpa,
                        d_sym.file,
                        debug_info_sect.offset,
                        new_offset,
                        existing_size,
                    );

                    debug_info_sect.offset = @intCast(u32, new_offset);
                    debug_info_sect.addr = dwarf_segment.inner.vmaddr + new_offset - dwarf_segment.inner.fileoff;
                }
                debug_info_sect.size = needed_size;
                d_sym.load_commands_dirty = true; // TODO look into making only the one section dirty
                d_sym.debug_line_header_dirty = true;
            }
            const file_pos = debug_info_sect.offset + atom.off;
            try pwriteDbgInfoNops(
                d_sym.file,
                file_pos,
                prev_padding_size,
                dbg_info_buf,
                next_padding_size,
                trailing_zero,
            );
        },
        .wasm => {
            const wasm_file = file.cast(File.Wasm).?;
            const segment_index = try wasm_file.getDebugInfoIndex();
            const segment = &wasm_file.segments.items[segment_index];
            const debug_info = &wasm_file.debug_info;
            if (needed_size != segment.size) {
                log.debug(" needed size does not equal allocated size: {d}", .{needed_size});
                if (needed_size > segment.size) {
                    log.debug("  allocating {d} bytes for 'debug info' information", .{needed_size - segment.size});
                    try debug_info.resize(self.allocator, needed_size);
                    mem.set(u8, debug_info.items[segment.size..], 0);
                }
                segment.size = needed_size;
                debug_info.items.len = needed_size;
            }
            const offset = segment.offset + atom.off;
            log.debug(" writeDbgInfoNopsToArrayList debug_info_len={d} offset={d} content_len={d} next_padding_size={d}", .{
                debug_info.items.len, offset, dbg_info_buf.len, next_padding_size,
            });
            try writeDbgInfoNopsToArrayList(
                gpa,
                debug_info,
                offset,
                prev_padding_size,
                dbg_info_buf,
                next_padding_size,
                trailing_zero,
            );
        },
        else => unreachable,
    }
}

pub fn updateDeclLineNumber(self: *Dwarf, file: *File, decl: *const Module.Decl) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const func = decl.val.castTag(.function).?.data;
    log.debug("decl.src_line={d}, func.lbrace_line={d}, func.rbrace_line={d}", .{
        decl.src_line,
        func.lbrace_line,
        func.rbrace_line,
    });
    const line = @intCast(u28, decl.src_line + func.lbrace_line);
    var data: [4]u8 = undefined;
    leb128.writeUnsignedFixed(4, &data, line);

    switch (self.tag) {
        .elf => {
            const elf_file = file.cast(File.Elf).?;
            const shdr = elf_file.sections.items[elf_file.debug_line_section_index.?];
            const file_pos = shdr.sh_offset + decl.fn_link.elf.off + self.getRelocDbgLineOff();
            try elf_file.base.file.?.pwriteAll(&data, file_pos);
        },
        .macho => {
            const macho_file = file.cast(File.MachO).?;
            const d_sym = macho_file.d_sym.?;
            const dwarf_seg = d_sym.load_commands.items[d_sym.dwarf_segment_cmd_index.?].segment;
            const sect = dwarf_seg.sections.items[d_sym.debug_line_section_index.?];
            const file_pos = sect.offset + decl.fn_link.macho.off + self.getRelocDbgLineOff();
            try d_sym.file.pwriteAll(&data, file_pos);
        },
        .wasm => {
            const wasm_file = file.cast(File.Wasm).?;
            const segment_index = wasm_file.getDebugLineIndex() catch unreachable;
            const segment = wasm_file.segments.items[segment_index];
            const offset = segment.offset + decl.fn_link.wasm.src_fn.off + self.getRelocDbgLineOff();
            mem.copy(u8, wasm_file.debug_line.items[offset..], &data);
        },
        else => unreachable,
    }
}

pub fn freeAtom(self: *Dwarf, atom: *Atom) void {
    if (self.atom_first == atom) {
        self.atom_first = atom.next;
    }
    if (self.atom_last == atom) {
        // TODO shrink the .debug_info section size here
        self.atom_last = atom.prev;
    }

    if (atom.prev) |prev| {
        prev.next = atom.next;

        // TODO the free list logic like we do for text blocks above
    } else {
        atom.prev = null;
    }

    if (atom.next) |next| {
        next.prev = atom.prev;
    } else {
        atom.next = null;
    }
}

pub fn freeDecl(self: *Dwarf, decl: *Module.Decl) void {
    // TODO make this logic match freeTextBlock. Maybe abstract the logic out since the same thing
    // is desired for both.
    const gpa = self.allocator;
    const fn_link = switch (self.tag) {
        .elf => &decl.fn_link.elf,
        .macho => &decl.fn_link.macho,
        .wasm => &decl.fn_link.wasm.src_fn,
        else => unreachable,
    };
    _ = self.dbg_line_fn_free_list.remove(fn_link);

    if (fn_link.prev) |prev| {
        self.dbg_line_fn_free_list.put(gpa, prev, {}) catch {};
        prev.next = fn_link.next;
        if (fn_link.next) |next| {
            next.prev = prev;
        } else {
            self.dbg_line_fn_last = prev;
        }
    } else if (fn_link.next) |next| {
        self.dbg_line_fn_first = next;
        next.prev = null;
    }
    if (self.dbg_line_fn_first == fn_link) {
        self.dbg_line_fn_first = fn_link.next;
    }
    if (self.dbg_line_fn_last == fn_link) {
        self.dbg_line_fn_last = fn_link.prev;
    }
}

pub fn writeDbgAbbrev(self: *Dwarf, file: *File) !void {
    // These are LEB encoded but since the values are all less than 127
    // we can simply append these bytes.
    const abbrev_buf = [_]u8{
        @enumToInt(AbbrevKind.compile_unit), DW.TAG.compile_unit, DW.CHILDREN.yes, // header
        DW.AT.stmt_list,                     DW.FORM.sec_offset,  DW.AT.low_pc,
        DW.FORM.addr,                        DW.AT.high_pc,       DW.FORM.addr,
        DW.AT.name,                          DW.FORM.strp,        DW.AT.comp_dir,
        DW.FORM.strp,                        DW.AT.producer,      DW.FORM.strp,
        DW.AT.language,                      DW.FORM.data2,       0,
        0, // table sentinel
        @enumToInt(AbbrevKind.subprogram),
        DW.TAG.subprogram,
        DW.CHILDREN.yes, // header
        DW.AT.low_pc,
        DW.FORM.addr,
        DW.AT.high_pc,
        DW.FORM.data4,
        DW.AT.type,
        DW.FORM.ref4,
        DW.AT.name,
        DW.FORM.string,
        0,                                         0, // table sentinel
        @enumToInt(AbbrevKind.subprogram_retvoid),
        DW.TAG.subprogram, DW.CHILDREN.yes, // header
        DW.AT.low_pc,      DW.FORM.addr,
        DW.AT.high_pc,     DW.FORM.data4,
        DW.AT.name,        DW.FORM.string,
        0,
        0, // table sentinel
        @enumToInt(AbbrevKind.base_type),
        DW.TAG.base_type,
        DW.CHILDREN.no, // header
        DW.AT.encoding,
        DW.FORM.data1,
        DW.AT.byte_size,
        DW.FORM.data1,
        DW.AT.name,
        DW.FORM.string,
        0,
        0, // table sentinel
        @enumToInt(AbbrevKind.ptr_type),
        DW.TAG.pointer_type,
        DW.CHILDREN.no, // header
        DW.AT.type,
        DW.FORM.ref4,
        0,
        0, // table sentinel
        @enumToInt(AbbrevKind.struct_type),
        DW.TAG.structure_type,
        DW.CHILDREN.yes, // header
        DW.AT.byte_size,
        DW.FORM.sdata,
        DW.AT.name,
        DW.FORM.string,
        0,
        0, // table sentinel
        @enumToInt(AbbrevKind.struct_member),
        DW.TAG.member,
        DW.CHILDREN.no, // header
        DW.AT.name,
        DW.FORM.string,
        DW.AT.type,
        DW.FORM.ref4,
        DW.AT.data_member_location,
        DW.FORM.sdata,
        0,
        0, // table sentinel
        @enumToInt(AbbrevKind.enum_type),
        DW.TAG.enumeration_type,
        DW.CHILDREN.yes, // header
        DW.AT.byte_size,
        DW.FORM.sdata,
        DW.AT.name,
        DW.FORM.string,
        0,
        0, // table sentinel
        @enumToInt(AbbrevKind.enum_variant),
        DW.TAG.enumerator,
        DW.CHILDREN.no, // header
        DW.AT.name,
        DW.FORM.string,
        DW.AT.const_value,
        DW.FORM.data8,
        0,
        0, // table sentinel
        @enumToInt(AbbrevKind.union_type),
        DW.TAG.union_type,
        DW.CHILDREN.yes, // header
        DW.AT.byte_size,
        DW.FORM.sdata,
        DW.AT.name,
        DW.FORM.string,
        0,
        0, // table sentinel
        @enumToInt(AbbrevKind.pad1),
        DW.TAG.unspecified_type,
        DW.CHILDREN.no, // header
        0,
        0, // table sentinel
        @enumToInt(AbbrevKind.parameter),
        DW.TAG.formal_parameter, DW.CHILDREN.no, // header
        DW.AT.location,          DW.FORM.exprloc,
        DW.AT.type,              DW.FORM.ref4,
        DW.AT.name,              DW.FORM.string,
        0,
        0, // table sentinel
        @enumToInt(AbbrevKind.variable),
        DW.TAG.variable, DW.CHILDREN.no, // header
        DW.AT.location,  DW.FORM.exprloc,
        DW.AT.type,      DW.FORM.ref4,
        DW.AT.name,      DW.FORM.string,
        0,
        0, // table sentinel
        @enumToInt(AbbrevKind.array_type),
        DW.TAG.array_type, DW.CHILDREN.yes, // header
        DW.AT.name,        DW.FORM.string,
        DW.AT.type,        DW.FORM.ref4,
        0,
        0, // table sentinel
        @enumToInt(AbbrevKind.array_dim),
        DW.TAG.subrange_type, DW.CHILDREN.no, // header
        DW.AT.type,           DW.FORM.ref4,
        DW.AT.count,          DW.FORM.udata,
        0,
        0, // table sentinel
        0,
        0,
        0, // section sentinel
    };
    const abbrev_offset = 0;
    self.abbrev_table_offset = abbrev_offset;

    const needed_size = abbrev_buf.len;
    switch (self.tag) {
        .elf => {
            const elf_file = file.cast(File.Elf).?;
            const debug_abbrev_sect = &elf_file.sections.items[elf_file.debug_abbrev_section_index.?];
            const allocated_size = elf_file.allocatedSize(debug_abbrev_sect.sh_offset);
            if (needed_size > allocated_size) {
                debug_abbrev_sect.sh_size = 0; // free the space
                debug_abbrev_sect.sh_offset = elf_file.findFreeSpace(needed_size, 1);
            }
            debug_abbrev_sect.sh_size = needed_size;
            log.debug(".debug_abbrev start=0x{x} end=0x{x}", .{
                debug_abbrev_sect.sh_offset,
                debug_abbrev_sect.sh_offset + needed_size,
            });

            const file_pos = debug_abbrev_sect.sh_offset + abbrev_offset;
            try elf_file.base.file.?.pwriteAll(&abbrev_buf, file_pos);
        },
        .macho => {
            const macho_file = file.cast(File.MachO).?;
            const d_sym = &macho_file.d_sym.?;
            const dwarf_segment = &d_sym.load_commands.items[d_sym.dwarf_segment_cmd_index.?].segment;
            const debug_abbrev_sect = &dwarf_segment.sections.items[d_sym.debug_abbrev_section_index.?];
            const allocated_size = d_sym.allocatedSize(debug_abbrev_sect.offset);
            if (needed_size > allocated_size) {
                debug_abbrev_sect.size = 0; // free the space
                const offset = d_sym.findFreeSpace(needed_size, 1);
                debug_abbrev_sect.offset = @intCast(u32, offset);
                debug_abbrev_sect.addr = dwarf_segment.inner.vmaddr + offset - dwarf_segment.inner.fileoff;
            }
            debug_abbrev_sect.size = needed_size;
            log.debug("__debug_abbrev start=0x{x} end=0x{x}", .{
                debug_abbrev_sect.offset,
                debug_abbrev_sect.offset + needed_size,
            });
            const file_pos = debug_abbrev_sect.offset + abbrev_offset;
            try d_sym.file.pwriteAll(&abbrev_buf, file_pos);
        },
        .wasm => {
            const wasm_file = file.cast(File.Wasm).?;
            try wasm_file.debug_abbrev.resize(wasm_file.base.allocator, needed_size);
            mem.copy(u8, wasm_file.debug_abbrev.items, &abbrev_buf);
        },
        else => unreachable,
    }
}

fn dbgInfoHeaderBytes(self: *Dwarf) usize {
    _ = self;
    return 120;
}

pub fn writeDbgInfoHeader(self: *Dwarf, file: *File, module: *Module, low_pc: u64, high_pc: u64) !void {
    // If this value is null it means there is an error in the module;
    // leave debug_info_header_dirty=true.
    const first_dbg_info_off = self.getDebugInfoOff() orelse return;

    // We have a function to compute the upper bound size, because it's needed
    // for determining where to put the offset of the first `LinkBlock`.
    const needed_bytes = self.dbgInfoHeaderBytes();
    var di_buf = try std.ArrayList(u8).initCapacity(self.allocator, needed_bytes);
    defer di_buf.deinit();

    const target_endian = self.target.cpu.arch.endian();
    const init_len_size: usize = if (self.tag == .macho)
        4
    else switch (self.ptr_width) {
        .p32 => @as(usize, 4),
        .p64 => 12,
    };

    // initial length - length of the .debug_info contribution for this compilation unit,
    // not including the initial length itself.
    // We have to come back and write it later after we know the size.
    const after_init_len = di_buf.items.len + init_len_size;
    // +1 for the final 0 that ends the compilation unit children.
    const dbg_info_end = self.getDebugInfoEnd().? + 1;
    const init_len = dbg_info_end - after_init_len;
    if (self.tag == .macho) {
        mem.writeIntLittle(u32, di_buf.addManyAsArrayAssumeCapacity(4), @intCast(u32, init_len));
    } else switch (self.ptr_width) {
        .p32 => {
            mem.writeInt(u32, di_buf.addManyAsArrayAssumeCapacity(4), @intCast(u32, init_len), target_endian);
        },
        .p64 => {
            di_buf.appendNTimesAssumeCapacity(0xff, 4);
            mem.writeInt(u64, di_buf.addManyAsArrayAssumeCapacity(8), init_len, target_endian);
        },
    }
    mem.writeInt(u16, di_buf.addManyAsArrayAssumeCapacity(2), 4, target_endian); // DWARF version
    const abbrev_offset = self.abbrev_table_offset.?;
    if (self.tag == .macho) {
        mem.writeIntLittle(u32, di_buf.addManyAsArrayAssumeCapacity(4), @intCast(u32, abbrev_offset));
        di_buf.appendAssumeCapacity(8); // address size
    } else switch (self.ptr_width) {
        .p32 => {
            mem.writeInt(u32, di_buf.addManyAsArrayAssumeCapacity(4), @intCast(u32, abbrev_offset), target_endian);
            di_buf.appendAssumeCapacity(4); // address size
        },
        .p64 => {
            mem.writeInt(u64, di_buf.addManyAsArrayAssumeCapacity(8), abbrev_offset, target_endian);
            di_buf.appendAssumeCapacity(8); // address size
        },
    }
    // Write the form for the compile unit, which must match the abbrev table above.
    const name_strp = try self.makeString(module.root_pkg.root_src_path);
    const comp_dir_strp = try self.makeString(module.root_pkg.root_src_directory.path orelse ".");
    const producer_strp = try self.makeString(link.producer_string);

    di_buf.appendAssumeCapacity(@enumToInt(AbbrevKind.compile_unit));
    if (self.tag == .macho) {
        mem.writeIntLittle(u32, di_buf.addManyAsArrayAssumeCapacity(4), 0); // DW.AT.stmt_list, DW.FORM.sec_offset
        mem.writeIntLittle(u64, di_buf.addManyAsArrayAssumeCapacity(8), low_pc);
        mem.writeIntLittle(u64, di_buf.addManyAsArrayAssumeCapacity(8), high_pc);
        mem.writeIntLittle(u32, di_buf.addManyAsArrayAssumeCapacity(4), @intCast(u32, name_strp));
        mem.writeIntLittle(u32, di_buf.addManyAsArrayAssumeCapacity(4), @intCast(u32, comp_dir_strp));
        mem.writeIntLittle(u32, di_buf.addManyAsArrayAssumeCapacity(4), @intCast(u32, producer_strp));
    } else {
        self.writeAddrAssumeCapacity(&di_buf, 0); // DW.AT.stmt_list, DW.FORM.sec_offset
        self.writeAddrAssumeCapacity(&di_buf, low_pc);
        self.writeAddrAssumeCapacity(&di_buf, high_pc);
        self.writeAddrAssumeCapacity(&di_buf, name_strp);
        self.writeAddrAssumeCapacity(&di_buf, comp_dir_strp);
        self.writeAddrAssumeCapacity(&di_buf, producer_strp);
    }
    // We are still waiting on dwarf-std.org to assign DW_LANG_Zig a number:
    // http://dwarfstd.org/ShowIssue.php?issue=171115.1
    // Until then we say it is C99.
    mem.writeInt(u16, di_buf.addManyAsArrayAssumeCapacity(2), DW.LANG.C99, target_endian);

    if (di_buf.items.len > first_dbg_info_off) {
        // Move the first N decls to the end to make more padding for the header.
        @panic("TODO: handle .debug_info header exceeding its padding");
    }
    const jmp_amt = first_dbg_info_off - di_buf.items.len;
    switch (self.tag) {
        .elf => {
            const elf_file = file.cast(File.Elf).?;
            const debug_info_sect = elf_file.sections.items[elf_file.debug_info_section_index.?];
            const file_pos = debug_info_sect.sh_offset;
            try pwriteDbgInfoNops(elf_file.base.file.?, file_pos, 0, di_buf.items, jmp_amt, false);
        },
        .macho => {
            const macho_file = file.cast(File.MachO).?;
            const d_sym = &macho_file.d_sym.?;
            const dwarf_seg = d_sym.load_commands.items[d_sym.dwarf_segment_cmd_index.?].segment;
            const debug_info_sect = dwarf_seg.sections.items[d_sym.debug_info_section_index.?];
            const file_pos = debug_info_sect.offset;
            try pwriteDbgInfoNops(d_sym.file, file_pos, 0, di_buf.items, jmp_amt, false);
        },
        .wasm => {
            const wasm_file = file.cast(File.Wasm).?;
            try writeDbgInfoNopsToArrayList(self.allocator, &wasm_file.debug_info, 0, 0, di_buf.items, jmp_amt, false);
        },
        else => unreachable,
    }
}

fn writeAddrAssumeCapacity(self: *Dwarf, buf: *std.ArrayList(u8), addr: u64) void {
    const target_endian = self.target.cpu.arch.endian();
    switch (self.ptr_width) {
        .p32 => mem.writeInt(u32, buf.addManyAsArrayAssumeCapacity(4), @intCast(u32, addr), target_endian),
        .p64 => mem.writeInt(u64, buf.addManyAsArrayAssumeCapacity(8), addr, target_endian),
    }
}

/// Writes to the file a buffer, prefixed and suffixed by the specified number of
/// bytes of NOPs. Asserts each padding size is at least `min_nop_size` and total padding bytes
/// are less than 1044480 bytes (if this limit is ever reached, this function can be
/// improved to make more than one pwritev call, or the limit can be raised by a fixed
/// amount by increasing the length of `vecs`).
fn pwriteDbgLineNops(
    file: fs.File,
    offset: u64,
    prev_padding_size: usize,
    buf: []const u8,
    next_padding_size: usize,
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const page_of_nops = [1]u8{DW.LNS.negate_stmt} ** 4096;
    const three_byte_nop = [3]u8{ DW.LNS.advance_pc, 0b1000_0000, 0 };
    var vecs: [512]std.os.iovec_const = undefined;
    var vec_index: usize = 0;
    {
        var padding_left = prev_padding_size;
        if (padding_left % 2 != 0) {
            vecs[vec_index] = .{
                .iov_base = &three_byte_nop,
                .iov_len = three_byte_nop.len,
            };
            vec_index += 1;
            padding_left -= three_byte_nop.len;
        }
        while (padding_left > page_of_nops.len) {
            vecs[vec_index] = .{
                .iov_base = &page_of_nops,
                .iov_len = page_of_nops.len,
            };
            vec_index += 1;
            padding_left -= page_of_nops.len;
        }
        if (padding_left > 0) {
            vecs[vec_index] = .{
                .iov_base = &page_of_nops,
                .iov_len = padding_left,
            };
            vec_index += 1;
        }
    }

    vecs[vec_index] = .{
        .iov_base = buf.ptr,
        .iov_len = buf.len,
    };
    vec_index += 1;

    {
        var padding_left = next_padding_size;
        if (padding_left % 2 != 0) {
            vecs[vec_index] = .{
                .iov_base = &three_byte_nop,
                .iov_len = three_byte_nop.len,
            };
            vec_index += 1;
            padding_left -= three_byte_nop.len;
        }
        while (padding_left > page_of_nops.len) {
            vecs[vec_index] = .{
                .iov_base = &page_of_nops,
                .iov_len = page_of_nops.len,
            };
            vec_index += 1;
            padding_left -= page_of_nops.len;
        }
        if (padding_left > 0) {
            vecs[vec_index] = .{
                .iov_base = &page_of_nops,
                .iov_len = padding_left,
            };
            vec_index += 1;
        }
    }
    try file.pwritevAll(vecs[0..vec_index], offset - prev_padding_size);
}

fn writeDbgLineNopsBuffered(
    buf: []u8,
    offset: u32,
    prev_padding_size: usize,
    content: []const u8,
    next_padding_size: usize,
) void {
    assert(buf.len >= content.len + prev_padding_size + next_padding_size);
    const tracy = trace(@src());
    defer tracy.end();

    const three_byte_nop = [3]u8{ DW.LNS.advance_pc, 0b1000_0000, 0 };
    {
        var padding_left = prev_padding_size;
        if (padding_left % 2 != 0) {
            buf[offset - padding_left ..][0..3].* = three_byte_nop;
            padding_left -= 3;
        }

        while (padding_left > 0) : (padding_left -= 1) {
            buf[offset - padding_left] = DW.LNS.negate_stmt;
        }
    }

    mem.copy(u8, buf[offset..], content);

    {
        var padding_left = next_padding_size;
        if (padding_left % 2 != 0) {
            buf[offset + content.len + padding_left ..][0..3].* = three_byte_nop;
            padding_left -= 3;
        }

        while (padding_left > 0) : (padding_left -= 1) {
            buf[offset + content.len + padding_left] = DW.LNS.negate_stmt;
        }
    }
}

/// Writes to the file a buffer, prefixed and suffixed by the specified number of
/// bytes of padding.
fn pwriteDbgInfoNops(
    file: fs.File,
    offset: u64,
    prev_padding_size: usize,
    buf: []const u8,
    next_padding_size: usize,
    trailing_zero: bool,
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const page_of_nops = [1]u8{@enumToInt(AbbrevKind.pad1)} ** 4096;
    var vecs: [32]std.os.iovec_const = undefined;
    var vec_index: usize = 0;
    {
        var padding_left = prev_padding_size;
        while (padding_left > page_of_nops.len) {
            vecs[vec_index] = .{
                .iov_base = &page_of_nops,
                .iov_len = page_of_nops.len,
            };
            vec_index += 1;
            padding_left -= page_of_nops.len;
        }
        if (padding_left > 0) {
            vecs[vec_index] = .{
                .iov_base = &page_of_nops,
                .iov_len = padding_left,
            };
            vec_index += 1;
        }
    }

    vecs[vec_index] = .{
        .iov_base = buf.ptr,
        .iov_len = buf.len,
    };
    vec_index += 1;

    {
        var padding_left = next_padding_size;
        while (padding_left > page_of_nops.len) {
            vecs[vec_index] = .{
                .iov_base = &page_of_nops,
                .iov_len = page_of_nops.len,
            };
            vec_index += 1;
            padding_left -= page_of_nops.len;
        }
        if (padding_left > 0) {
            vecs[vec_index] = .{
                .iov_base = &page_of_nops,
                .iov_len = padding_left,
            };
            vec_index += 1;
        }
    }

    if (trailing_zero) {
        var zbuf = [1]u8{0};
        vecs[vec_index] = .{
            .iov_base = &zbuf,
            .iov_len = zbuf.len,
        };
        vec_index += 1;
    }

    try file.pwritevAll(vecs[0..vec_index], offset - prev_padding_size);
}

fn writeDbgInfoNopsToArrayList(
    gpa: Allocator,
    buffer: *std.ArrayListUnmanaged(u8),
    offset: u32,
    prev_padding_size: usize,
    content: []const u8,
    next_padding_size: usize,
    trailing_zero: bool,
) Allocator.Error!void {
    try buffer.resize(gpa, @maximum(
        buffer.items.len,
        offset + content.len + next_padding_size + 1,
    ));
    mem.set(u8, buffer.items[offset - prev_padding_size .. offset], @enumToInt(AbbrevKind.pad1));
    mem.copy(u8, buffer.items[offset..], content);
    mem.set(u8, buffer.items[offset + content.len ..][0..next_padding_size], @enumToInt(AbbrevKind.pad1));

    if (trailing_zero) {
        buffer.items[offset + content.len + next_padding_size] = 0;
    }
}

pub fn writeDbgAranges(self: *Dwarf, file: *File, addr: u64, size: u64) !void {
    const target_endian = self.target.cpu.arch.endian();
    const init_len_size: usize = if (self.tag == .macho)
        4
    else switch (self.ptr_width) {
        .p32 => @as(usize, 4),
        .p64 => 12,
    };
    const ptr_width_bytes = self.ptrWidthBytes();

    // Enough for all the data without resizing. When support for more compilation units
    // is added, the size of this section will become more variable.
    var di_buf = try std.ArrayList(u8).initCapacity(self.allocator, 100);
    defer di_buf.deinit();

    // initial length - length of the .debug_aranges contribution for this compilation unit,
    // not including the initial length itself.
    // We have to come back and write it later after we know the size.
    const init_len_index = di_buf.items.len;
    di_buf.items.len += init_len_size;
    const after_init_len = di_buf.items.len;
    mem.writeInt(u16, di_buf.addManyAsArrayAssumeCapacity(2), 2, target_endian); // version
    // When more than one compilation unit is supported, this will be the offset to it.
    // For now it is always at offset 0 in .debug_info.
    if (self.tag == .macho) {
        mem.writeIntLittle(u32, di_buf.addManyAsArrayAssumeCapacity(4), 0); // __debug_info offset
    } else {
        self.writeAddrAssumeCapacity(&di_buf, 0); // .debug_info offset
    }
    di_buf.appendAssumeCapacity(ptr_width_bytes); // address_size
    di_buf.appendAssumeCapacity(0); // segment_selector_size

    const end_header_offset = di_buf.items.len;
    const begin_entries_offset = mem.alignForward(end_header_offset, ptr_width_bytes * 2);
    di_buf.appendNTimesAssumeCapacity(0, begin_entries_offset - end_header_offset);

    // Currently only one compilation unit is supported, so the address range is simply
    // identical to the main program header virtual address and memory size.
    self.writeAddrAssumeCapacity(&di_buf, addr);
    self.writeAddrAssumeCapacity(&di_buf, size);

    // Sentinel.
    self.writeAddrAssumeCapacity(&di_buf, 0);
    self.writeAddrAssumeCapacity(&di_buf, 0);

    // Go back and populate the initial length.
    const init_len = di_buf.items.len - after_init_len;
    if (self.tag == .macho) {
        mem.writeIntLittle(u32, di_buf.items[init_len_index..][0..4], @intCast(u32, init_len));
    } else switch (self.ptr_width) {
        .p32 => {
            mem.writeInt(u32, di_buf.items[init_len_index..][0..4], @intCast(u32, init_len), target_endian);
        },
        .p64 => {
            // initial length - length of the .debug_aranges contribution for this compilation unit,
            // not including the initial length itself.
            di_buf.items[init_len_index..][0..4].* = [_]u8{ 0xff, 0xff, 0xff, 0xff };
            mem.writeInt(u64, di_buf.items[init_len_index + 4 ..][0..8], init_len, target_endian);
        },
    }

    const needed_size = di_buf.items.len;
    switch (self.tag) {
        .elf => {
            const elf_file = file.cast(File.Elf).?;
            const debug_aranges_sect = &elf_file.sections.items[elf_file.debug_aranges_section_index.?];
            const allocated_size = elf_file.allocatedSize(debug_aranges_sect.sh_offset);
            if (needed_size > allocated_size) {
                debug_aranges_sect.sh_size = 0; // free the space
                debug_aranges_sect.sh_offset = elf_file.findFreeSpace(needed_size, 16);
            }
            debug_aranges_sect.sh_size = needed_size;
            log.debug(".debug_aranges start=0x{x} end=0x{x}", .{
                debug_aranges_sect.sh_offset,
                debug_aranges_sect.sh_offset + needed_size,
            });
            const file_pos = debug_aranges_sect.sh_offset;
            try elf_file.base.file.?.pwriteAll(di_buf.items, file_pos);
        },
        .macho => {
            const macho_file = file.cast(File.MachO).?;
            const d_sym = &macho_file.d_sym.?;
            const dwarf_seg = &d_sym.load_commands.items[d_sym.dwarf_segment_cmd_index.?].segment;
            const debug_aranges_sect = &dwarf_seg.sections.items[d_sym.debug_aranges_section_index.?];
            const allocated_size = d_sym.allocatedSize(debug_aranges_sect.offset);
            if (needed_size > allocated_size) {
                debug_aranges_sect.size = 0; // free the space
                const new_offset = d_sym.findFreeSpace(needed_size, 16);
                debug_aranges_sect.addr = dwarf_seg.inner.vmaddr + new_offset - dwarf_seg.inner.fileoff;
                debug_aranges_sect.offset = @intCast(u32, new_offset);
            }
            debug_aranges_sect.size = needed_size;
            log.debug("__debug_aranges start=0x{x} end=0x{x}", .{
                debug_aranges_sect.offset,
                debug_aranges_sect.offset + needed_size,
            });
            const file_pos = debug_aranges_sect.offset;
            try d_sym.file.pwriteAll(di_buf.items, file_pos);
        },
        .wasm => {
            const wasm_file = file.cast(File.Wasm).?;
            try wasm_file.debug_aranges.resize(wasm_file.base.allocator, needed_size);
            mem.copy(u8, wasm_file.debug_aranges.items, di_buf.items);
        },
        else => unreachable,
    }
}

pub fn writeDbgLineHeader(self: *Dwarf, file: *File, module: *Module) !void {
    const ptr_width_bytes: u8 = self.ptrWidthBytes();
    const target_endian = self.target.cpu.arch.endian();
    const init_len_size: usize = if (self.tag == .macho)
        4
    else switch (self.ptr_width) {
        .p32 => @as(usize, 4),
        .p64 => 12,
    };

    const dbg_line_prg_off = self.getDebugLineProgramOff() orelse return;
    const dbg_line_prg_end = self.getDebugLineProgramEnd().?;
    assert(dbg_line_prg_end != 0);

    // The size of this header is variable, depending on the number of directories,
    // files, and padding. We have a function to compute the upper bound size, however,
    // because it's needed for determining where to put the offset of the first `SrcFn`.
    const needed_bytes = self.dbgLineNeededHeaderBytes(module);
    var di_buf = try std.ArrayList(u8).initCapacity(self.allocator, needed_bytes);
    defer di_buf.deinit();

    // initial length - length of the .debug_line contribution for this compilation unit,
    // not including the initial length itself.
    const after_init_len = di_buf.items.len + init_len_size;
    const init_len = dbg_line_prg_end - after_init_len;
    if (self.tag == .macho) {
        mem.writeIntLittle(u32, di_buf.addManyAsArrayAssumeCapacity(4), @intCast(u32, init_len));
    } else switch (self.ptr_width) {
        .p32 => {
            mem.writeInt(u32, di_buf.addManyAsArrayAssumeCapacity(4), @intCast(u32, init_len), target_endian);
        },
        .p64 => {
            di_buf.appendNTimesAssumeCapacity(0xff, 4);
            mem.writeInt(u64, di_buf.addManyAsArrayAssumeCapacity(8), init_len, target_endian);
        },
    }

    mem.writeInt(u16, di_buf.addManyAsArrayAssumeCapacity(2), 4, target_endian); // version

    // Empirically, debug info consumers do not respect this field, or otherwise
    // consider it to be an error when it does not point exactly to the end of the header.
    // Therefore we rely on the NOP jump at the beginning of the Line Number Program for
    // padding rather than this field.
    const before_header_len = di_buf.items.len;
    di_buf.items.len += if (self.tag == .macho) @sizeOf(u32) else ptr_width_bytes; // We will come back and write this.
    const after_header_len = di_buf.items.len;

    const opcode_base = DW.LNS.set_isa + 1;
    di_buf.appendSliceAssumeCapacity(&[_]u8{
        1, // minimum_instruction_length
        1, // maximum_operations_per_instruction
        1, // default_is_stmt
        1, // line_base (signed)
        1, // line_range
        opcode_base,

        // Standard opcode lengths. The number of items here is based on `opcode_base`.
        // The value is the number of LEB128 operands the instruction takes.
        0, // `DW.LNS.copy`
        1, // `DW.LNS.advance_pc`
        1, // `DW.LNS.advance_line`
        1, // `DW.LNS.set_file`
        1, // `DW.LNS.set_column`
        0, // `DW.LNS.negate_stmt`
        0, // `DW.LNS.set_basic_block`
        0, // `DW.LNS.const_add_pc`
        1, // `DW.LNS.fixed_advance_pc`
        0, // `DW.LNS.set_prologue_end`
        0, // `DW.LNS.set_epilogue_begin`
        1, // `DW.LNS.set_isa`
        0, // include_directories (none except the compilation unit cwd)
    });
    // file_names[0]
    di_buf.appendSliceAssumeCapacity(module.root_pkg.root_src_path); // relative path name
    di_buf.appendSliceAssumeCapacity(&[_]u8{
        0, // null byte for the relative path name
        0, // directory_index
        0, // mtime (TODO supply this)
        0, // file size bytes (TODO supply this)
        0, // file_names sentinel
    });

    const header_len = di_buf.items.len - after_header_len;
    if (self.tag == .macho) {
        mem.writeIntLittle(u32, di_buf.items[before_header_len..][0..4], @intCast(u32, header_len));
    } else switch (self.ptr_width) {
        .p32 => {
            mem.writeInt(u32, di_buf.items[before_header_len..][0..4], @intCast(u32, header_len), target_endian);
        },
        .p64 => {
            mem.writeInt(u64, di_buf.items[before_header_len..][0..8], header_len, target_endian);
        },
    }

    // We use NOPs because consumers empirically do not respect the header length field.
    if (di_buf.items.len > dbg_line_prg_off) {
        // Move the first N files to the end to make more padding for the header.
        @panic("TODO: handle .debug_line header exceeding its padding");
    }
    const jmp_amt = dbg_line_prg_off - di_buf.items.len;
    switch (self.tag) {
        .elf => {
            const elf_file = file.cast(File.Elf).?;
            const debug_line_sect = elf_file.sections.items[elf_file.debug_line_section_index.?];
            const file_pos = debug_line_sect.sh_offset;
            try pwriteDbgLineNops(elf_file.base.file.?, file_pos, 0, di_buf.items, jmp_amt);
        },
        .macho => {
            const macho_file = file.cast(File.MachO).?;
            const d_sym = &macho_file.d_sym.?;
            const dwarf_seg = d_sym.load_commands.items[d_sym.dwarf_segment_cmd_index.?].segment;
            const debug_line_sect = dwarf_seg.sections.items[d_sym.debug_line_section_index.?];
            const file_pos = debug_line_sect.offset;
            try pwriteDbgLineNops(d_sym.file, file_pos, 0, di_buf.items, jmp_amt);
        },
        .wasm => {
            const wasm_file = file.cast(File.Wasm).?;
            writeDbgLineNopsBuffered(wasm_file.debug_line.items, 0, 0, di_buf.items, jmp_amt);
        },
        else => unreachable,
    }
}

fn getDebugInfoOff(self: Dwarf) ?u32 {
    const first = self.atom_first orelse return null;
    return first.off;
}

fn getDebugInfoEnd(self: Dwarf) ?u32 {
    const last = self.atom_last orelse return null;
    return last.off + last.len;
}

fn getDebugLineProgramOff(self: Dwarf) ?u32 {
    const first = self.dbg_line_fn_first orelse return null;
    return first.off;
}

fn getDebugLineProgramEnd(self: Dwarf) ?u32 {
    const last = self.dbg_line_fn_last orelse return null;
    return last.off + last.len;
}

/// Always 4 or 8 depending on whether this is 32-bit or 64-bit format.
fn ptrWidthBytes(self: Dwarf) u8 {
    return switch (self.ptr_width) {
        .p32 => 4,
        .p64 => 8,
    };
}

fn dbgLineNeededHeaderBytes(self: Dwarf, module: *Module) u32 {
    _ = self;
    const directory_entry_format_count = 1;
    const file_name_entry_format_count = 1;
    const directory_count = 1;
    const file_name_count = 1;
    const root_src_dir_path_len = if (module.root_pkg.root_src_directory.path) |p| p.len else 1; // "."
    return @intCast(u32, 53 + directory_entry_format_count * 2 + file_name_entry_format_count * 2 +
        directory_count * 8 + file_name_count * 8 +
        // These are encoded as DW.FORM.string rather than DW.FORM.strp as we would like
        // because of a workaround for readelf and gdb failing to understand DWARFv5 correctly.
        root_src_dir_path_len +
        module.root_pkg.root_src_path.len);
}

/// The reloc offset for the line offset of a function from the previous function's line.
/// It's a fixed-size 4-byte ULEB128.
fn getRelocDbgLineOff(self: Dwarf) usize {
    return dbg_line_vaddr_reloc_index + self.ptrWidthBytes() + 1;
}

fn getRelocDbgFileIndex(self: Dwarf) usize {
    return self.getRelocDbgLineOff() + 5;
}

fn getRelocDbgInfoSubprogramHighPC(self: Dwarf) u32 {
    return dbg_info_low_pc_reloc_index + self.ptrWidthBytes();
}

/// TODO Improve this to use a table.
fn makeString(self: *Dwarf, bytes: []const u8) !u32 {
    try self.strtab.ensureUnusedCapacity(self.allocator, bytes.len + 1);
    const result = self.strtab.items.len;
    self.strtab.appendSliceAssumeCapacity(bytes);
    self.strtab.appendAssumeCapacity(0);
    return @intCast(u32, result);
}

fn padToIdeal(actual_size: anytype) @TypeOf(actual_size) {
    // TODO https://github.com/ziglang/zig/issues/1284
    return std.math.add(@TypeOf(actual_size), actual_size, actual_size / ideal_factor) catch
        std.math.maxInt(@TypeOf(actual_size));
}

pub fn flushModule(self: *Dwarf, file: *File, module: *Module) !void {
    if (self.global_abbrev_relocs.items.len > 0) {
        const gpa = self.allocator;
        var arena_alloc = std.heap.ArenaAllocator.init(gpa);
        defer arena_alloc.deinit();
        const arena = arena_alloc.allocator();

        const error_set = try arena.create(Module.ErrorSet);
        const error_ty = try Type.Tag.error_set.create(arena, error_set);
        var names = Module.ErrorSet.NameMap{};
        try names.ensureUnusedCapacity(arena, module.global_error_set.count());
        var it = module.global_error_set.keyIterator();
        while (it.next()) |key| {
            names.putAssumeCapacityNoClobber(key.*, {});
        }
        error_set.names = names;

        const atom = try gpa.create(Atom);
        errdefer gpa.destroy(atom);
        atom.* = .{
            .prev = null,
            .next = null,
            .off = 0,
            .len = 0,
        };

        var dbg_info_buffer = std.ArrayList(u8).init(arena);
        try addDbgInfoErrorSet(arena, module, error_ty, self.target, &dbg_info_buffer);

        try self.managed_atoms.append(gpa, atom);
        log.debug("updateDeclDebugInfoAllocation in flushModule", .{});
        try self.updateDeclDebugInfoAllocation(file, atom, @intCast(u32, dbg_info_buffer.items.len));
        log.debug("writeDeclDebugInfo in flushModule", .{});
        try self.writeDeclDebugInfo(file, atom, dbg_info_buffer.items);

        const file_pos = blk: {
            switch (self.tag) {
                .elf => {
                    const elf_file = file.cast(File.Elf).?;
                    const debug_info_sect = &elf_file.sections.items[elf_file.debug_info_section_index.?];
                    break :blk debug_info_sect.sh_offset;
                },
                .macho => {
                    const macho_file = file.cast(File.MachO).?;
                    const d_sym = &macho_file.d_sym.?;
                    const dwarf_segment = &d_sym.load_commands.items[d_sym.dwarf_segment_cmd_index.?].segment;
                    const debug_info_sect = &dwarf_segment.sections.items[d_sym.debug_info_section_index.?];
                    break :blk debug_info_sect.offset;
                },
                // for wasm, the offset is always 0 as we write to memory first
                .wasm => break :blk @as(u32, 0),
                else => unreachable,
            }
        };

        var buf: [@sizeOf(u32)]u8 = undefined;
        mem.writeInt(u32, &buf, atom.off, self.target.cpu.arch.endian());

        while (self.global_abbrev_relocs.popOrNull()) |reloc| {
            switch (self.tag) {
                .elf => {
                    const elf_file = file.cast(File.Elf).?;
                    try elf_file.base.file.?.pwriteAll(&buf, file_pos + reloc.atom.off + reloc.offset);
                },
                .macho => {
                    const macho_file = file.cast(File.MachO).?;
                    const d_sym = &macho_file.d_sym.?;
                    try d_sym.file.pwriteAll(&buf, file_pos + reloc.atom.off + reloc.offset);
                },
                .wasm => {
                    const wasm_file = file.cast(File.Wasm).?;
                    mem.copy(u8, wasm_file.debug_info.items[reloc.atom.off + reloc.offset ..], &buf);
                },
                else => unreachable,
            }
        }
    }
}

fn addDbgInfoErrorSet(
    arena: Allocator,
    module: *Module,
    ty: Type,
    target: std.Target,
    dbg_info_buffer: *std.ArrayList(u8),
) !void {
    const target_endian = target.cpu.arch.endian();

    // DW.AT.enumeration_type
    try dbg_info_buffer.append(@enumToInt(AbbrevKind.enum_type));
    // DW.AT.byte_size, DW.FORM.sdata
    const abi_size = Type.anyerror.abiSize(target);
    try leb128.writeULEB128(dbg_info_buffer.writer(), abi_size);
    // DW.AT.name, DW.FORM.string
    const name = try ty.nameAllocArena(arena, module);
    try dbg_info_buffer.writer().print("{s}\x00", .{name});

    // DW.AT.enumerator
    const no_error = "(no error)";
    try dbg_info_buffer.ensureUnusedCapacity(no_error.len + 2 + @sizeOf(u64));
    dbg_info_buffer.appendAssumeCapacity(@enumToInt(AbbrevKind.enum_variant));
    // DW.AT.name, DW.FORM.string
    dbg_info_buffer.appendSliceAssumeCapacity(no_error);
    dbg_info_buffer.appendAssumeCapacity(0);
    // DW.AT.const_value, DW.FORM.data8
    mem.writeInt(u64, dbg_info_buffer.addManyAsArrayAssumeCapacity(8), 0, target_endian);

    const error_names = ty.errorSetNames();
    for (error_names) |error_name| {
        const kv = module.getErrorValue(error_name) catch unreachable;
        // DW.AT.enumerator
        try dbg_info_buffer.ensureUnusedCapacity(error_name.len + 2 + @sizeOf(u64));
        dbg_info_buffer.appendAssumeCapacity(@enumToInt(AbbrevKind.enum_variant));
        // DW.AT.name, DW.FORM.string
        dbg_info_buffer.appendSliceAssumeCapacity(error_name);
        dbg_info_buffer.appendAssumeCapacity(0);
        // DW.AT.const_value, DW.FORM.data8
        mem.writeInt(u64, dbg_info_buffer.addManyAsArrayAssumeCapacity(8), kv.value, target_endian);
    }

    // DW.AT.enumeration_type delimit children
    try dbg_info_buffer.append(0);
}
