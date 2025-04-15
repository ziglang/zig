const Object = @This();

const Wasm = @import("../Wasm.zig");
const Alignment = Wasm.Alignment;

const std = @import("std");
const Allocator = std.mem.Allocator;
const Path = std.Build.Cache.Path;
const log = std.log.scoped(.object);
const assert = std.debug.assert;

/// Wasm spec version used for this `Object`
version: u32,
/// For error reporting purposes only.
/// Name (read path) of the object or archive file.
path: Path,
/// For error reporting purposes only.
/// If this represents an object in an archive, it's the basename of the
/// object, and path refers to the archive.
archive_member_name: Wasm.OptionalString,
/// Represents the function ID that must be called on startup.
/// This is `null` by default as runtimes may determine the startup
/// function themselves. This is essentially legacy.
start_function: Wasm.OptionalObjectFunctionIndex,
/// A slice of features that tell the linker what features are mandatory, used
/// (or therefore missing) and must generate an error when another object uses
/// features that are not supported by the other.
features: Wasm.Feature.Set,
/// Points into `Wasm.object_functions`
functions: RelativeSlice,
/// Points into `Wasm.object_function_imports`
function_imports: RelativeSlice,
/// Points into `Wasm.object_global_imports`
global_imports: RelativeSlice,
/// Points into `Wasm.object_table_imports`
table_imports: RelativeSlice,
// Points into `Wasm.object_data_imports`
data_imports: RelativeSlice,
/// Points into Wasm object_custom_segments
custom_segments: RelativeSlice,
/// Points into Wasm object_init_funcs
init_funcs: RelativeSlice,
/// Points into Wasm object_comdats
comdats: RelativeSlice,
/// Guaranteed to be non-null when functions has nonzero length.
code_section_index: ?Wasm.ObjectSectionIndex,
/// Guaranteed to be non-null when globals has nonzero length.
global_section_index: ?Wasm.ObjectSectionIndex,
/// Guaranteed to be non-null when data segments has nonzero length.
data_section_index: ?Wasm.ObjectSectionIndex,
is_included: bool,

pub const RelativeSlice = struct {
    off: u32,
    len: u32,
};

pub const SegmentInfo = struct {
    name: Wasm.String,
    flags: Flags,

    /// Matches the ABI.
    pub const Flags = packed struct(u32) {
        /// Signals that the segment contains only null terminated strings allowing
        /// the linker to perform merging.
        strings: bool,
        /// The segment contains thread-local data. This means that a unique copy
        /// of this segment will be created for each thread.
        tls: bool,
        /// If the object file is included in the final link, the segment should be
        /// retained in the final output regardless of whether it is used by the
        /// program.
        retain: bool,
        alignment: Alignment,

        _: u23 = 0,
    };
};

pub const FunctionImport = struct {
    module_name: Wasm.String,
    name: Wasm.String,
    function_index: ScratchSpace.FuncTypeIndex,
};

pub const GlobalImport = struct {
    module_name: Wasm.String,
    name: Wasm.String,
    valtype: std.wasm.Valtype,
    mutable: bool,
};

pub const TableImport = struct {
    module_name: Wasm.String,
    name: Wasm.String,
    limits_min: u32,
    limits_max: u32,
    limits_has_max: bool,
    limits_is_shared: bool,
    ref_type: std.wasm.RefType,
};

pub const DataSegmentFlags = enum(u32) { active, passive, active_memidx };

pub const SubsectionType = enum(u8) {
    segment_info = 5,
    init_funcs = 6,
    comdat_info = 7,
    symbol_table = 8,
};

/// Specified by https://github.com/WebAssembly/tool-conventions/blob/main/Linking.md
pub const RelocationType = enum(u8) {
    function_index_leb = 0,
    table_index_sleb = 1,
    table_index_i32 = 2,
    memory_addr_leb = 3,
    memory_addr_sleb = 4,
    memory_addr_i32 = 5,
    type_index_leb = 6,
    global_index_leb = 7,
    function_offset_i32 = 8,
    section_offset_i32 = 9,
    event_index_leb = 10,
    memory_addr_rel_sleb = 11,
    table_index_rel_sleb = 12,
    global_index_i32 = 13,
    memory_addr_leb64 = 14,
    memory_addr_sleb64 = 15,
    memory_addr_i64 = 16,
    memory_addr_rel_sleb64 = 17,
    table_index_sleb64 = 18,
    table_index_i64 = 19,
    table_number_leb = 20,
    memory_addr_tls_sleb = 21,
    function_offset_i64 = 22,
    memory_addr_locrel_i32 = 23,
    table_index_rel_sleb64 = 24,
    memory_addr_tls_sleb64 = 25,
    function_index_i32 = 26,
};

pub const Symbol = struct {
    flags: Wasm.SymbolFlags,
    name: Wasm.OptionalString,
    pointee: Pointee,

    /// https://github.com/WebAssembly/tool-conventions/blob/df8d737539eb8a8f446ba5eab9dc670c40dfb81e/Linking.md#symbol-table-subsection
    const Tag = enum(u8) {
        function,
        data,
        global,
        section,
        event,
        table,
    };

    const Pointee = union(enum) {
        function: Wasm.ObjectFunctionIndex,
        function_import: ScratchSpace.FuncImportIndex,
        data: Wasm.ObjectData.Index,
        data_import: void,
        global: Wasm.ObjectGlobalIndex,
        global_import: ScratchSpace.GlobalImportIndex,
        section: Wasm.ObjectSectionIndex,
        table: Wasm.ObjectTableIndex,
        table_import: ScratchSpace.TableImportIndex,
    };
};

pub const ScratchSpace = struct {
    func_types: std.ArrayListUnmanaged(Wasm.FunctionType.Index) = .empty,
    func_type_indexes: std.ArrayListUnmanaged(FuncTypeIndex) = .empty,
    func_imports: std.ArrayListUnmanaged(FunctionImport) = .empty,
    global_imports: std.ArrayListUnmanaged(GlobalImport) = .empty,
    table_imports: std.ArrayListUnmanaged(TableImport) = .empty,
    symbol_table: std.ArrayListUnmanaged(Symbol) = .empty,
    segment_info: std.ArrayListUnmanaged(SegmentInfo) = .empty,
    exports: std.ArrayListUnmanaged(Export) = .empty,

    const Export = struct {
        name: Wasm.String,
        pointee: Pointee,

        const Pointee = union(std.wasm.ExternalKind) {
            function: Wasm.ObjectFunctionIndex,
            table: Wasm.ObjectTableIndex,
            memory: Wasm.ObjectMemory.Index,
            global: Wasm.ObjectGlobalIndex,
        };
    };

    /// Index into `func_imports`.
    const FuncImportIndex = enum(u32) {
        _,

        fn ptr(index: FuncImportIndex, ss: *const ScratchSpace) *FunctionImport {
            return &ss.func_imports.items[@intFromEnum(index)];
        }
    };

    /// Index into `global_imports`.
    const GlobalImportIndex = enum(u32) {
        _,

        fn ptr(index: GlobalImportIndex, ss: *const ScratchSpace) *GlobalImport {
            return &ss.global_imports.items[@intFromEnum(index)];
        }
    };

    /// Index into `table_imports`.
    const TableImportIndex = enum(u32) {
        _,

        fn ptr(index: TableImportIndex, ss: *const ScratchSpace) *TableImport {
            return &ss.table_imports.items[@intFromEnum(index)];
        }
    };

    /// Index into `func_types`.
    const FuncTypeIndex = enum(u32) {
        _,

        fn ptr(index: FuncTypeIndex, ss: *const ScratchSpace) *Wasm.FunctionType.Index {
            return &ss.func_types.items[@intFromEnum(index)];
        }
    };

    pub fn deinit(ss: *ScratchSpace, gpa: Allocator) void {
        ss.exports.deinit(gpa);
        ss.func_types.deinit(gpa);
        ss.func_type_indexes.deinit(gpa);
        ss.func_imports.deinit(gpa);
        ss.global_imports.deinit(gpa);
        ss.table_imports.deinit(gpa);
        ss.symbol_table.deinit(gpa);
        ss.segment_info.deinit(gpa);
        ss.* = undefined;
    }

    fn clear(ss: *ScratchSpace) void {
        ss.exports.clearRetainingCapacity();
        ss.func_types.clearRetainingCapacity();
        ss.func_type_indexes.clearRetainingCapacity();
        ss.func_imports.clearRetainingCapacity();
        ss.global_imports.clearRetainingCapacity();
        ss.table_imports.clearRetainingCapacity();
        ss.symbol_table.clearRetainingCapacity();
        ss.segment_info.clearRetainingCapacity();
    }
};

pub fn parse(
    wasm: *Wasm,
    br: *std.io.BufferedReader,
    path: Path,
    archive_member_name: ?[]const u8,
    host_name: Wasm.OptionalString,
    ss: *ScratchSpace,
    must_link: bool,
    gc_sections: bool,
) anyerror!Object {
    const comp = wasm.base.comp;
    const gpa = comp.gpa;
    const diags = &comp.link_diags;

    if (!std.mem.eql(u8, try br.takeArray(std.wasm.magic.len), &std.wasm.magic)) return error.BadObjectMagic;

    const version = try br.takeInt(u32, .little);

    const data_segment_start: u32 = @intCast(wasm.object_data_segments.items.len);
    const custom_segment_start: u32 = @intCast(wasm.object_custom_segments.entries.len);
    const functions_start: u32 = @intCast(wasm.object_functions.items.len);
    const tables_start: u32 = @intCast(wasm.object_tables.items.len);
    const memories_start: u32 = @intCast(wasm.object_memories.items.len);
    const globals_start: u32 = @intCast(wasm.object_globals.items.len);
    const init_funcs_start: u32 = @intCast(wasm.object_init_funcs.items.len);
    const comdats_start: u32 = @intCast(wasm.object_comdats.items.len);
    const function_imports_start: u32 = @intCast(wasm.object_function_imports.entries.len);
    const global_imports_start: u32 = @intCast(wasm.object_global_imports.entries.len);
    const table_imports_start: u32 = @intCast(wasm.object_table_imports.entries.len);
    const data_imports_start: u32 = @intCast(wasm.object_data_imports.entries.len);
    const local_section_index_base = wasm.object_total_sections;
    const object_index: Wasm.ObjectIndex = @enumFromInt(wasm.objects.items.len);
    const source_location: Wasm.SourceLocation = .fromObject(object_index, wasm);

    ss.clear();

    var start_function: Wasm.OptionalObjectFunctionIndex = .none;
    var opt_features: ?Wasm.Feature.Set = null;
    var saw_linking_section = false;
    var has_tls = false;
    var table_import_symbol_count: usize = 0;
    var code_section_index: ?Wasm.ObjectSectionIndex = null;
    var global_section_index: ?Wasm.ObjectSectionIndex = null;
    var data_section_index: ?Wasm.ObjectSectionIndex = null;
    while (br.takeEnum(std.wasm.Section, .little)) |section_tag| : (wasm.object_total_sections += 1) {
        const section_index: Wasm.ObjectSectionIndex = @enumFromInt(wasm.object_total_sections);

        const len = try br.takeLeb128(u32);
        const section_end = br.seek + len;
        switch (section_tag) {
            .custom => {
                const section_name = try br.take(try br.takeLeb128(u32));
                if (std.mem.eql(u8, section_name, "linking")) {
                    saw_linking_section = true;
                    const section_version = try br.takeLeb128(u32);
                    log.debug("link meta data version: {d}", .{section_version});
                    if (section_version != 2) return error.UnsupportedVersion;
                    while (br.seek < section_end) {
                        const sub_type = try br.takeEnum(SubsectionType, .little);
                        log.debug("found subsection: {s}", .{@tagName(sub_type)});
                        const payload_len = try br.takeLeb128(u32);
                        if (payload_len == 0) break;

                        const count = try br.takeLeb128(u32);
                        switch (sub_type) {
                            .segment_info => for (try ss.segment_info.addManyAsSlice(gpa, count)) |*segment| {
                                const name = try br.take(try br.takeLeb128(u32));
                                const alignment: Alignment = .fromLog2Units(try br.takeLeb128(u32));
                                const flags: SegmentInfo.Flags = @bitCast(try br.takeLeb128(u32));
                                const tls = flags.tls or
                                    // Supports legacy object files that specified
                                    // being TLS by the name instead of the TLS flag.
                                    std.mem.startsWith(u8, name, ".tdata") or
                                    std.mem.startsWith(u8, name, ".tbss");
                                has_tls = has_tls or tls;
                                segment.* = .{
                                    .name = try wasm.internString(name),
                                    .flags = .{
                                        .strings = flags.strings,
                                        .tls = tls,
                                        .alignment = alignment,
                                        .retain = flags.retain,
                                    },
                                };
                            },
                            .init_funcs => for (try wasm.object_init_funcs.addManyAsSlice(gpa, count)) |*func| {
                                const priority = try br.takeLeb128(u32);
                                const symbol_index = try br.takeLeb128(u32);
                                if (symbol_index > ss.symbol_table.items.len)
                                    return diags.failParse(path, "init_funcs before symbol table", .{});
                                const sym = &ss.symbol_table.items[symbol_index];
                                if (sym.pointee != .function) {
                                    return diags.failParse(path, "init_func symbol '{s}' not a function", .{
                                        sym.name.slice(wasm).?,
                                    });
                                } else if (sym.flags.undefined) {
                                    return diags.failParse(path, "init_func symbol '{s}' is an import", .{
                                        sym.name.slice(wasm).?,
                                    });
                                }
                                func.* = .{
                                    .priority = priority,
                                    .function_index = sym.pointee.function,
                                };
                            },
                            .comdat_info => for (try wasm.object_comdats.addManyAsSlice(gpa, count)) |*comdat| {
                                const name = try br.take(try br.takeLeb128(u32));
                                const flags = try br.takeLeb128(u32);
                                if (flags != 0) return error.UnexpectedComdatFlags;
                                const symbol_count = try br.takeLeb128(u32);
                                const start_off: u32 = @intCast(wasm.object_comdat_symbols.len);
                                try wasm.object_comdat_symbols.ensureUnusedCapacity(gpa, symbol_count);
                                for (0..symbol_count) |_| {
                                    const kind = try br.takeEnum(Wasm.Comdat.Symbol.Type, .little);
                                    const index = try br.takeLeb128(u32);
                                    if (true) @panic("TODO rebase index depending on kind");
                                    wasm.object_comdat_symbols.appendAssumeCapacity(.{
                                        .kind = kind,
                                        .index = index,
                                    });
                                }
                                comdat.* = .{
                                    .name = try wasm.internString(name),
                                    .flags = flags,
                                    .symbols = .{
                                        .off = start_off,
                                        .len = @intCast(wasm.object_comdat_symbols.len - start_off),
                                    },
                                };
                            },
                            .symbol_table => for (try ss.symbol_table.addManyAsSlice(gpa, count)) |*symbol| {
                                const tag = try br.takeEnum(Symbol.Tag, .little);
                                const flags: Wasm.SymbolFlags = @bitCast(try br.takeLeb128(u32));
                                symbol.* = .{
                                    .flags = flags,
                                    .name = .none,
                                    .pointee = undefined,
                                };
                                symbol.flags.initZigSpecific(must_link, gc_sections);

                                switch (tag) {
                                    .data => {
                                        const name = try br.take(try br.takeLeb128(u32));
                                        const interned_name = try wasm.internString(name);
                                        symbol.name = interned_name.toOptional();
                                        if (symbol.flags.undefined) {
                                            symbol.pointee = .data_import;
                                        } else {
                                            const segment_index = try br.takeLeb128(u32);
                                            const segment_offset = try br.takeLeb128(u32);
                                            const size = try br.takeLeb128(u32);
                                            try wasm.object_datas.append(gpa, .{
                                                .segment = @enumFromInt(data_segment_start + segment_index),
                                                .offset = segment_offset,
                                                .size = size,
                                                .name = interned_name,
                                                .flags = symbol.flags,
                                            });
                                            symbol.pointee = .{
                                                .data = @enumFromInt(wasm.object_datas.items.len - 1),
                                            };
                                        }
                                    },
                                    .section => {
                                        const local_section = try br.takeLeb128(u32);
                                        const section: Wasm.ObjectSectionIndex = @enumFromInt(local_section_index_base + local_section);
                                        symbol.pointee = .{ .section = section };
                                    },

                                    .function => {
                                        const local_index = try br.takeLeb128(u32);
                                        if (symbol.flags.undefined) {
                                            const function_import: ScratchSpace.FuncImportIndex = @enumFromInt(local_index);
                                            symbol.pointee = .{ .function_import = function_import };
                                            if (symbol.flags.explicit_name) {
                                                const name = try br.take(try br.takeLeb128(u32));
                                                symbol.name = (try wasm.internString(name)).toOptional();
                                            } else {
                                                symbol.name = function_import.ptr(ss).name.toOptional();
                                            }
                                        } else {
                                            symbol.pointee = .{ .function = @enumFromInt(functions_start + (local_index - ss.func_imports.items.len)) };
                                            const name = try br.take(try br.takeLeb128(u32));
                                            symbol.name = (try wasm.internString(name)).toOptional();
                                        }
                                    },
                                    .global => {
                                        const local_index = try br.takeLeb128(u32);
                                        if (symbol.flags.undefined) {
                                            const global_import: ScratchSpace.GlobalImportIndex = @enumFromInt(local_index);
                                            symbol.pointee = .{ .global_import = global_import };
                                            if (symbol.flags.explicit_name) {
                                                const name = try br.take(try br.takeLeb128(u32));
                                                symbol.name = (try wasm.internString(name)).toOptional();
                                            } else {
                                                symbol.name = global_import.ptr(ss).name.toOptional();
                                            }
                                        } else {
                                            symbol.pointee = .{ .global = @enumFromInt(globals_start + (local_index - ss.global_imports.items.len)) };
                                            const name = try br.take(try br.takeLeb128(u32));
                                            symbol.name = (try wasm.internString(name)).toOptional();
                                        }
                                    },
                                    .table => {
                                        const local_index = try br.takeLeb128(u32);
                                        if (symbol.flags.undefined) {
                                            table_import_symbol_count += 1;
                                            const table_import: ScratchSpace.TableImportIndex = @enumFromInt(local_index);
                                            symbol.pointee = .{ .table_import = table_import };
                                            if (symbol.flags.explicit_name) {
                                                const name = try br.take(try br.takeLeb128(u32));
                                                symbol.name = (try wasm.internString(name)).toOptional();
                                            } else {
                                                symbol.name = table_import.ptr(ss).name.toOptional();
                                            }
                                        } else {
                                            symbol.pointee = .{ .table = @enumFromInt(tables_start + (local_index - ss.table_imports.items.len)) };
                                            const name = try br.take(try br.takeLeb128(u32));
                                            symbol.name = (try wasm.internString(name)).toOptional();
                                        }
                                    },
                                    else => {
                                        log.debug("unrecognized symbol type tag: {x}", .{@intFromEnum(tag)});
                                        return error.UnrecognizedSymbolType;
                                    },
                                }
                            },
                        }
                    }
                } else if (std.mem.startsWith(u8, section_name, "reloc.")) {
                    // 'The "reloc." custom sections must come after the "linking" custom section'
                    if (!saw_linking_section) return error.RelocBeforeLinkingSection;

                    // "Relocation sections start with an identifier specifying
                    // which section they apply to, and must be sequenced in
                    // the module after that section."
                    // "Relocation sections can only target code, data and custom sections."
                    const local_section = try br.takeLeb128(u32);
                    const count = try br.takeLeb128(u32);
                    const section: Wasm.ObjectSectionIndex = @enumFromInt(local_section_index_base + local_section);

                    log.debug("found {d} relocations for section={d}", .{ count, section });

                    var prev_offset: u32 = 0;
                    try wasm.object_relocations.ensureUnusedCapacity(gpa, count);
                    for (0..count) |_| {
                        const tag = try br.takeEnum(RelocationType, .little);
                        const offset = try br.takeLeb128(u32);
                        const index = try br.takeLeb128(u32);

                        if (offset < prev_offset)
                            return diags.failParse(path, "relocation entries not sorted by offset", .{});
                        prev_offset = offset;

                        const sym = &ss.symbol_table.items[index];

                        switch (tag) {
                            .memory_addr_leb,
                            .memory_addr_sleb,
                            .memory_addr_i32,
                            .memory_addr_rel_sleb,
                            .memory_addr_leb64,
                            .memory_addr_sleb64,
                            .memory_addr_i64,
                            .memory_addr_rel_sleb64,
                            .memory_addr_tls_sleb,
                            .memory_addr_locrel_i32,
                            .memory_addr_tls_sleb64,
                            => {
                                const addend = try br.takeLeb128(i32);
                                wasm.object_relocations.appendAssumeCapacity(switch (sym.pointee) {
                                    .data => |data| .{
                                        .tag = .fromType(tag),
                                        .offset = offset,
                                        .pointee = .{ .data = data },
                                        .addend = addend,
                                    },
                                    .data_import => .{
                                        .tag = .fromTypeImport(tag),
                                        .offset = offset,
                                        .pointee = .{ .symbol_name = sym.name.unwrap().? },
                                        .addend = addend,
                                    },
                                    else => unreachable,
                                });
                            },
                            .function_offset_i32, .function_offset_i64 => {
                                const addend = try br.takeLeb128(i32);
                                wasm.object_relocations.appendAssumeCapacity(switch (sym.pointee) {
                                    .function => .{
                                        .tag = .fromType(tag),
                                        .offset = offset,
                                        .pointee = .{ .function = sym.pointee.function },
                                        .addend = addend,
                                    },
                                    .function_import => .{
                                        .tag = .fromTypeImport(tag),
                                        .offset = offset,
                                        .pointee = .{ .symbol_name = sym.name.unwrap().? },
                                        .addend = addend,
                                    },
                                    else => unreachable,
                                });
                            },
                            .section_offset_i32 => {
                                const addend = try br.takeLeb128(i32);
                                wasm.object_relocations.appendAssumeCapacity(.{
                                    .tag = .section_offset_i32,
                                    .offset = offset,
                                    .pointee = .{ .section = sym.pointee.section },
                                    .addend = addend,
                                });
                            },
                            .type_index_leb => {
                                wasm.object_relocations.appendAssumeCapacity(.{
                                    .tag = .type_index_leb,
                                    .offset = offset,
                                    .pointee = .{ .type_index = ss.func_types.items[index] },
                                    .addend = undefined,
                                });
                            },
                            .function_index_leb,
                            .function_index_i32,
                            .table_index_sleb,
                            .table_index_i32,
                            .table_index_sleb64,
                            .table_index_i64,
                            .table_index_rel_sleb,
                            .table_index_rel_sleb64,
                            => {
                                wasm.object_relocations.appendAssumeCapacity(switch (sym.pointee) {
                                    .function => .{
                                        .tag = .fromType(tag),
                                        .offset = offset,
                                        .pointee = .{ .function = sym.pointee.function },
                                        .addend = undefined,
                                    },
                                    .function_import => .{
                                        .tag = .fromTypeImport(tag),
                                        .offset = offset,
                                        .pointee = .{ .symbol_name = sym.name.unwrap().? },
                                        .addend = undefined,
                                    },
                                    else => unreachable,
                                });
                            },
                            .global_index_leb, .global_index_i32 => {
                                wasm.object_relocations.appendAssumeCapacity(switch (sym.pointee) {
                                    .global => .{
                                        .tag = .fromType(tag),
                                        .offset = offset,
                                        .pointee = .{ .global = sym.pointee.global },
                                        .addend = undefined,
                                    },
                                    .global_import => .{
                                        .tag = .fromTypeImport(tag),
                                        .offset = offset,
                                        .pointee = .{ .symbol_name = sym.name.unwrap().? },
                                        .addend = undefined,
                                    },
                                    else => unreachable,
                                });
                            },

                            .table_number_leb => {
                                wasm.object_relocations.appendAssumeCapacity(switch (sym.pointee) {
                                    .table => .{
                                        .tag = .fromType(tag),
                                        .offset = offset,
                                        .pointee = .{ .table = sym.pointee.table },
                                        .addend = undefined,
                                    },
                                    .table_import => .{
                                        .tag = .fromTypeImport(tag),
                                        .offset = offset,
                                        .pointee = .{ .symbol_name = sym.name.unwrap().? },
                                        .addend = undefined,
                                    },
                                    else => unreachable,
                                });
                            },
                            .event_index_leb => return diags.failParse(path, "unsupported relocation: R_WASM_EVENT_INDEX_LEB", .{}),
                        }
                    }

                    try wasm.object_relocations_table.putNoClobber(gpa, section, .{
                        .off = @intCast(wasm.object_relocations.len - count),
                        .len = count,
                    });
                } else if (std.mem.eql(u8, section_name, "target_features")) {
                    opt_features = try parseFeatures(wasm, br, path);
                } else if (std.mem.startsWith(u8, section_name, ".debug")) {
                    const debug_content = try br.take(len);

                    const data_off: u32 = @intCast(wasm.string_bytes.items.len);
                    try wasm.string_bytes.appendSlice(gpa, debug_content);

                    try wasm.object_custom_segments.put(gpa, section_index, .{
                        .payload = .{
                            .off = @enumFromInt(data_off),
                            .len = @intCast(len),
                        },
                        .flags = .{},
                        .section_name = try wasm.internString(section_name),
                    });
                } else br.seek = section_end;
            },
            .type => {
                const func_types_len = try br.takeLeb128(u32);
                for (try ss.func_types.addManyAsSlice(gpa, func_types_len)) |*func_type| {
                    if (try br.takeByte() != std.wasm.function_type) return error.ExpectedFuncType;

                    const params = try br.take(try br.takeLeb128(u32));
                    const returns = try br.take(try br.takeLeb128(u32));
                    func_type.* = try wasm.addFuncType(.{
                        .params = .fromString(try wasm.internString(params)),
                        .returns = .fromString(try wasm.internString(returns)),
                    });
                }
            },
            .import => {
                const imports_len = try br.takeLeb128(u32);
                for (0..imports_len) |_| {
                    const module_name = try br.take(try br.takeLeb128(u32));
                    const name = try br.take(try br.takeLeb128(u32));
                    const kind = try br.takeEnum(std.wasm.ExternalKind, .little);
                    const interned_module_name = try wasm.internString(module_name);
                    const interned_name = try wasm.internString(name);
                    switch (kind) {
                        .function => {
                            const function = try br.takeLeb128(u32);
                            try ss.func_imports.append(gpa, .{
                                .module_name = interned_module_name,
                                .name = interned_name,
                                .function_index = @enumFromInt(function),
                            });
                        },
                        .memory => {
                            const limits = try readLimits(br);
                            const gop = try wasm.object_memory_imports.getOrPut(gpa, interned_name);
                            if (gop.found_existing) {
                                if (gop.value_ptr.module_name != interned_module_name) {
                                    var err = try diags.addErrorWithNotes(2);
                                    try err.addMsg("memory '{s}' mismatching module names", .{name});
                                    gop.value_ptr.source_location.addNote(&err, "module '{s}' here", .{
                                        gop.value_ptr.module_name.slice(wasm),
                                    });
                                    source_location.addNote(&err, "module '{s}' here", .{module_name});
                                }
                                // TODO error for mismatching flags
                                gop.value_ptr.limits_min = @min(gop.value_ptr.limits_min, limits.min);
                                gop.value_ptr.limits_max = @max(gop.value_ptr.limits_max, limits.max);
                            } else {
                                gop.value_ptr.* = .{
                                    .module_name = interned_module_name,
                                    .limits_min = limits.min,
                                    .limits_max = limits.max,
                                    .limits_has_max = limits.flags.has_max,
                                    .limits_is_shared = limits.flags.is_shared,
                                    .source_location = source_location,
                                };
                            }
                        },
                        .global => {
                            const valtype = try br.takeEnum(std.wasm.Valtype, .little);
                            const mutable = switch (try br.takeByte()) {
                                0 => false,
                                1 => true,
                                else => return error.InvalidMutability,
                            };
                            try ss.global_imports.append(gpa, .{
                                .name = interned_name,
                                .valtype = valtype,
                                .mutable = mutable,
                                .module_name = interned_module_name,
                            });
                        },
                        .table => {
                            const ref_type = try br.takeEnum(std.wasm.RefType, .little);
                            const limits = try readLimits(br);
                            try ss.table_imports.append(gpa, .{
                                .name = interned_name,
                                .module_name = interned_module_name,
                                .limits_min = limits.min,
                                .limits_max = limits.max,
                                .limits_has_max = limits.flags.has_max,
                                .limits_is_shared = limits.flags.is_shared,
                                .ref_type = ref_type,
                            });
                        },
                    }
                }
            },
            .function => {
                const functions_len = try br.takeLeb128(u32);
                for (try ss.func_type_indexes.addManyAsSlice(gpa, functions_len)) |*func_type_index| {
                    func_type_index.* = @enumFromInt(try br.takeLeb128(u32));
                }
            },
            .table => {
                const tables_len = try br.takeLeb128(u32);
                for (try wasm.object_tables.addManyAsSlice(gpa, tables_len)) |*table| {
                    const ref_type = try br.takeEnum(std.wasm.RefType, .little);
                    const limits = try readLimits(br);
                    table.* = .{
                        .name = .none,
                        .module_name = .none,
                        .flags = .{
                            .ref_type = .from(ref_type),
                            .limits_has_max = limits.flags.has_max,
                            .limits_is_shared = limits.flags.is_shared,
                        },
                        .limits_min = limits.min,
                        .limits_max = limits.max,
                    };
                }
            },
            .memory => {
                const memories_len = try br.takeLeb128(u32);
                for (try wasm.object_memories.addManyAsSlice(gpa, memories_len)) |*memory| {
                    const limits = try readLimits(br);
                    memory.* = .{
                        .name = .none,
                        .flags = .{
                            .limits_has_max = limits.flags.has_max,
                            .limits_is_shared = limits.flags.is_shared,
                        },
                        .limits_min = limits.min,
                        .limits_max = limits.max,
                    };
                }
            },
            .global => {
                if (global_section_index != null)
                    return diags.failParse(path, "object has more than one global section", .{});
                global_section_index = section_index;

                const section_start = br.seek;
                const globals_len = try br.takeLeb128(u32);
                for (try wasm.object_globals.addManyAsSlice(gpa, globals_len)) |*global| {
                    const valtype = try br.takeEnum(std.wasm.Valtype, .little);
                    const mutable = switch (try br.takeByte()) {
                        0 => false,
                        1 => true,
                        else => return error.InvalidMutability,
                    };
                    const init_start = br.seek;
                    const expr = try readInit(wasm, br);
                    global.* = .{
                        .name = .none,
                        .flags = .{
                            .global_type = .{
                                .valtype = .from(valtype),
                                .mutable = mutable,
                            },
                        },
                        .expr = expr,
                        .object_index = object_index,
                        .offset = @intCast(init_start - section_start),
                        .size = @intCast(br.seek - init_start),
                    };
                }
            },
            .@"export" => {
                const exports_len = try br.takeLeb128(u32);
                // Read into scratch space, and then later add this data as if
                // it were extra symbol table entries, but allow merging with
                // existing symbol table data if the name matches.
                for (try ss.exports.addManyAsSlice(gpa, exports_len)) |*exp| {
                    const name = try br.take(try br.takeLeb128(u32));
                    const kind = try br.takeEnum(std.wasm.ExternalKind, .little);
                    const index = try br.takeLeb128(u32);
                    exp.* = .{
                        .name = try wasm.internString(name),
                        .pointee = switch (kind) {
                            .function => .{ .function = @enumFromInt(functions_start + (index - ss.func_imports.items.len)) },
                            .table => .{ .table = @enumFromInt(tables_start + (index - ss.table_imports.items.len)) },
                            .memory => .{ .memory = @enumFromInt(memories_start + index) },
                            .global => .{ .global = @enumFromInt(globals_start + (index - ss.global_imports.items.len)) },
                        },
                    };
                }
            },
            .start => {
                const index = try br.takeLeb128(u32);
                start_function = @enumFromInt(functions_start + index);
            },
            .element => {
                log.warn("unimplemented: element section in {f} {?s}", .{ path, archive_member_name });
                br.seek = section_end;
            },
            .code => {
                if (code_section_index != null)
                    return diags.failParse(path, "object has more than one code section", .{});
                code_section_index = section_index;

                const start = br.seek;
                const count = try br.takeLeb128(u32);
                for (try wasm.object_functions.addManyAsSlice(gpa, count)) |*elem| {
                    const code_len = try br.takeLeb128(u32);
                    const offset: u32 = @intCast(br.seek - start);
                    const payload = try wasm.addRelocatableDataPayload(try br.take(code_len));
                    elem.* = .{
                        .flags = .{}, // populated from symbol table
                        .name = .none, // populated from symbol table
                        .type_index = undefined, // populated from func_types
                        .code = payload,
                        .offset = offset,
                        .object_index = object_index,
                    };
                }
            },
            .data => {
                if (data_section_index != null)
                    return diags.failParse(path, "object has more than one data section", .{});
                data_section_index = section_index;

                const section_start = br.seek;
                const count = try br.takeLeb128(u32);
                for (try wasm.object_data_segments.addManyAsSlice(gpa, count)) |*elem| {
                    const flags: DataSegmentFlags = @enumFromInt(try br.takeLeb128(u32));
                    if (flags == .active_memidx) {
                        const memidx = try br.takeLeb128(u32);
                        if (memidx != 0) return diags.failParse(path, "data section uses mem index {d}", .{memidx});
                    }
                    //const expr = if (flags != .passive) try readInit(wasm, br) else .none;
                    if (flags != .passive) try skipInit(br);
                    const data_len = try br.takeLeb128(u32);
                    const segment_start = br.seek;
                    const payload = try wasm.addRelocatableDataPayload(try br.take(data_len));
                    elem.* = .{
                        .payload = payload,
                        .name = .none, // Populated from segment_info
                        .flags = .{
                            .is_passive = flags == .passive,
                        }, // Remainder populated from segment_info
                        .offset = @intCast(segment_start - section_start),
                        .object_index = object_index,
                    };
                }
            },
            else => br.seek = section_end,
        }
        if (br.seek != section_end) return error.MalformedSection;
    } else |_| {}
    if (!saw_linking_section) return error.MissingLinkingSection;

    const cpu = comp.root_mod.resolved_target.result.cpu;

    if (has_tls) {
        if (!cpu.has(.wasm, .atomics))
            return diags.failParse(path, "object has TLS segment but target CPU feature atomics is disabled", .{});
        if (!cpu.has(.wasm, .bulk_memory))
            return diags.failParse(path, "object has TLS segment but target CPU feature bulk_memory is disabled", .{});
    }

    const features = opt_features orelse return error.MissingFeatures;
    for (features.slice(wasm)) |feat| {
        log.debug("feature: {s}{s}", .{ @tagName(feat.prefix), @tagName(feat.tag) });
        switch (feat.prefix) {
            .invalid => unreachable,
            .@"-" => switch (feat.tag) {
                .@"shared-mem" => if (comp.config.shared_memory) {
                    return diags.failParse(path, "object forbids shared-mem but compilation enables it", .{});
                },
                else => {
                    const f = feat.tag.toCpuFeature().?;
                    if (cpu.has(.wasm, f)) {
                        return diags.failParse(
                            path,
                            "object forbids {s} but specified target features include {s}",
                            .{ @tagName(feat.tag), @tagName(f) },
                        );
                    }
                },
            },
            .@"+", .@"=" => switch (feat.tag) {
                .@"shared-mem" => if (!comp.config.shared_memory) {
                    return diags.failParse(path, "object requires shared-mem but compilation disables it", .{});
                },
                else => {
                    const f = feat.tag.toCpuFeature().?;
                    if (!cpu.has(.wasm, f)) {
                        return diags.failParse(
                            path,
                            "object requires {s} but specified target features exclude {s}",
                            .{ @tagName(feat.tag), @tagName(f) },
                        );
                    }
                },
            },
        }
    }

    // Apply function type information.
    for (ss.func_type_indexes.items, wasm.object_functions.items[functions_start..]) |func_type, *func| {
        func.type_index = func_type.ptr(ss).*;
    }

    // Apply symbol table information.
    for (ss.symbol_table.items) |symbol| switch (symbol.pointee) {
        .function_import => |index| {
            const ptr = index.ptr(ss);
            const name = symbol.name.unwrap() orelse ptr.name;
            if (symbol.flags.binding == .local) {
                diags.addParseError(path, "local symbol '{s}' references import", .{name.slice(wasm)});
                continue;
            }
            const gop = try wasm.object_function_imports.getOrPut(gpa, name);
            const fn_ty_index = ptr.function_index.ptr(ss).*;
            if (gop.found_existing) {
                if (gop.value_ptr.type != fn_ty_index) {
                    var err = try diags.addErrorWithNotes(2);
                    try err.addMsg("symbol '{s}' mismatching function signatures", .{name.slice(wasm)});
                    gop.value_ptr.source_location.addNote(&err, "imported as {f} here", .{
                        gop.value_ptr.type.fmt(wasm),
                    });
                    source_location.addNote(&err, "imported as {f} here", .{fn_ty_index.fmt(wasm)});
                    continue;
                }
                if (gop.value_ptr.module_name != ptr.module_name.toOptional()) {
                    var err = try diags.addErrorWithNotes(2);
                    try err.addMsg("symbol '{s}' mismatching module names", .{name.slice(wasm)});
                    if (gop.value_ptr.module_name.slice(wasm)) |module_name| {
                        gop.value_ptr.source_location.addNote(&err, "module '{s}' here", .{module_name});
                    } else {
                        gop.value_ptr.source_location.addNote(&err, "no module here", .{});
                    }
                    source_location.addNote(&err, "module '{s}' here", .{ptr.module_name.slice(wasm)});
                    continue;
                }
                if (gop.value_ptr.name != ptr.name) {
                    var err = try diags.addErrorWithNotes(2);
                    try err.addMsg("symbol '{s}' mismatching import names", .{name.slice(wasm)});
                    gop.value_ptr.source_location.addNote(&err, "imported as '{s}' here", .{gop.value_ptr.name.slice(wasm)});
                    source_location.addNote(&err, "imported as '{s}' here", .{ptr.name.slice(wasm)});
                    continue;
                }
            } else {
                gop.value_ptr.* = .{
                    .flags = symbol.flags,
                    .module_name = ptr.module_name.toOptional(),
                    .name = ptr.name,
                    .source_location = source_location,
                    .resolution = .unresolved,
                    .type = fn_ty_index,
                };
            }
        },
        .global_import => |index| {
            const ptr = index.ptr(ss);
            const name = symbol.name.unwrap() orelse ptr.name;
            if (symbol.flags.binding == .local) {
                diags.addParseError(path, "local symbol '{s}' references import", .{name.slice(wasm)});
                continue;
            }
            const gop = try wasm.object_global_imports.getOrPut(gpa, name);
            if (gop.found_existing) {
                const existing_ty = gop.value_ptr.type();
                if (ptr.valtype != existing_ty.valtype) {
                    var err = try diags.addErrorWithNotes(2);
                    try err.addMsg("symbol '{s}' mismatching global types", .{name.slice(wasm)});
                    gop.value_ptr.source_location.addNote(&err, "type {s} here", .{@tagName(existing_ty.valtype)});
                    source_location.addNote(&err, "type {s} here", .{@tagName(ptr.valtype)});
                    continue;
                }
                if (ptr.mutable != existing_ty.mutable) {
                    var err = try diags.addErrorWithNotes(2);
                    try err.addMsg("symbol '{s}' mismatching global mutability", .{name.slice(wasm)});
                    gop.value_ptr.source_location.addNote(&err, "{s} here", .{
                        if (existing_ty.mutable) "mutable" else "not mutable",
                    });
                    source_location.addNote(&err, "{s} here", .{
                        if (ptr.mutable) "mutable" else "not mutable",
                    });
                    continue;
                }
                if (gop.value_ptr.module_name != ptr.module_name.toOptional()) {
                    var err = try diags.addErrorWithNotes(2);
                    try err.addMsg("symbol '{s}' mismatching module names", .{name.slice(wasm)});
                    if (gop.value_ptr.module_name.slice(wasm)) |module_name| {
                        gop.value_ptr.source_location.addNote(&err, "module '{s}' here", .{module_name});
                    } else {
                        gop.value_ptr.source_location.addNote(&err, "no module here", .{});
                    }
                    source_location.addNote(&err, "module '{s}' here", .{ptr.module_name.slice(wasm)});
                    continue;
                }
                if (gop.value_ptr.name != ptr.name) {
                    var err = try diags.addErrorWithNotes(2);
                    try err.addMsg("symbol '{s}' mismatching import names", .{name.slice(wasm)});
                    gop.value_ptr.source_location.addNote(&err, "imported as '{s}' here", .{gop.value_ptr.name.slice(wasm)});
                    source_location.addNote(&err, "imported as '{s}' here", .{ptr.name.slice(wasm)});
                    continue;
                }
            } else {
                gop.value_ptr.* = .{
                    .flags = symbol.flags,
                    .module_name = ptr.module_name.toOptional(),
                    .name = ptr.name,
                    .source_location = source_location,
                    .resolution = .unresolved,
                };
                gop.value_ptr.flags.global_type = .{
                    .valtype = .from(ptr.valtype),
                    .mutable = ptr.mutable,
                };
            }
        },
        .table_import => |index| {
            const ptr = index.ptr(ss);
            const name = symbol.name.unwrap() orelse ptr.name;
            if (symbol.flags.binding == .local) {
                diags.addParseError(path, "local symbol '{s}' references import", .{name.slice(wasm)});
                continue;
            }
            const gop = try wasm.object_table_imports.getOrPut(gpa, name);
            if (gop.found_existing) {
                const existing_reftype = gop.value_ptr.flags.ref_type.to();
                if (ptr.ref_type != existing_reftype) {
                    var err = try diags.addErrorWithNotes(2);
                    try err.addMsg("symbol '{s}' mismatching table reftypes", .{name.slice(wasm)});
                    gop.value_ptr.source_location.addNote(&err, "{s} here", .{@tagName(existing_reftype)});
                    source_location.addNote(&err, "{s} here", .{@tagName(ptr.ref_type)});
                    continue;
                }
                if (gop.value_ptr.module_name != ptr.module_name) {
                    var err = try diags.addErrorWithNotes(2);
                    try err.addMsg("symbol '{s}' mismatching module names", .{name.slice(wasm)});
                    gop.value_ptr.source_location.addNote(&err, "module '{s}' here", .{
                        gop.value_ptr.module_name.slice(wasm),
                    });
                    source_location.addNote(&err, "module '{s}' here", .{ptr.module_name.slice(wasm)});
                    continue;
                }
                if (gop.value_ptr.name != ptr.name) {
                    var err = try diags.addErrorWithNotes(2);
                    try err.addMsg("symbol '{s}' mismatching import names", .{name.slice(wasm)});
                    gop.value_ptr.source_location.addNote(&err, "imported as '{s}' here", .{gop.value_ptr.name.slice(wasm)});
                    source_location.addNote(&err, "imported as '{s}' here", .{ptr.name.slice(wasm)});
                    continue;
                }
                if (symbol.flags.binding == .strong) gop.value_ptr.flags.binding = .strong;
                if (!symbol.flags.visibility_hidden) gop.value_ptr.flags.visibility_hidden = false;
                if (symbol.flags.no_strip) gop.value_ptr.flags.no_strip = true;
            } else {
                gop.value_ptr.* = .{
                    .flags = symbol.flags,
                    .module_name = ptr.module_name,
                    .name = ptr.name,
                    .source_location = source_location,
                    .resolution = .unresolved,
                    .limits_min = ptr.limits_min,
                    .limits_max = ptr.limits_max,
                };
                gop.value_ptr.flags.limits_has_max = ptr.limits_has_max;
                gop.value_ptr.flags.limits_is_shared = ptr.limits_is_shared;
                gop.value_ptr.flags.ref_type = .from(ptr.ref_type);
            }
        },
        .data_import => {
            const name = symbol.name.unwrap().?;
            if (symbol.flags.binding == .local) {
                diags.addParseError(path, "local symbol '{s}' references import", .{name.slice(wasm)});
                continue;
            }
            const gop = try wasm.object_data_imports.getOrPut(gpa, name);
            if (!gop.found_existing) gop.value_ptr.* = .{
                .flags = symbol.flags,
                .source_location = source_location,
                .resolution = .unresolved,
            };
        },
        .function => |index| {
            assert(!symbol.flags.undefined);
            const ptr = index.ptr(wasm);
            ptr.name = symbol.name;
            ptr.flags = symbol.flags;
            if (symbol.flags.binding == .local) continue; // No participation in symbol resolution.
            const name = symbol.name.unwrap().?;
            const gop = try wasm.object_function_imports.getOrPut(gpa, name);
            if (gop.found_existing) {
                if (gop.value_ptr.type != ptr.type_index) {
                    var err = try diags.addErrorWithNotes(2);
                    try err.addMsg("function signature mismatch: {s}", .{name.slice(wasm)});
                    gop.value_ptr.source_location.addNote(&err, "exported as {f} here", .{
                        ptr.type_index.fmt(wasm),
                    });
                    const word = if (gop.value_ptr.resolution == .unresolved) "imported" else "exported";
                    source_location.addNote(&err, "{s} as {f} here", .{ word, gop.value_ptr.type.fmt(wasm) });
                    continue;
                }
                if (gop.value_ptr.resolution == .unresolved or gop.value_ptr.flags.binding == .weak) {
                    // Intentional: if they're both weak, take the last one.
                    gop.value_ptr.source_location = source_location;
                    gop.value_ptr.module_name = host_name;
                    gop.value_ptr.resolution = .fromObjectFunction(wasm, index);
                    gop.value_ptr.flags = symbol.flags;
                    continue;
                }
                if (ptr.flags.binding == .weak) {
                    // Keep the existing one.
                    continue;
                }
                var err = try diags.addErrorWithNotes(2);
                try err.addMsg("symbol collision: {s}", .{name.slice(wasm)});
                gop.value_ptr.source_location.addNote(&err, "exported as {f} here", .{ptr.type_index.fmt(wasm)});
                source_location.addNote(&err, "exported as {f} here", .{gop.value_ptr.type.fmt(wasm)});
                continue;
            } else {
                gop.value_ptr.* = .{
                    .flags = symbol.flags,
                    .module_name = host_name,
                    .name = name,
                    .source_location = source_location,
                    .resolution = .fromObjectFunction(wasm, index),
                    .type = ptr.type_index,
                };
            }
        },
        .global => |index| {
            assert(!symbol.flags.undefined);
            const ptr = index.ptr(wasm);
            ptr.name = symbol.name;
            ptr.flags = symbol.flags;
            if (symbol.flags.binding == .local) continue; // No participation in symbol resolution.
            const name = symbol.name.unwrap().?;
            const new_ty = ptr.type();
            const gop = try wasm.object_global_imports.getOrPut(gpa, name);
            if (gop.found_existing) {
                const existing_ty = gop.value_ptr.type();
                if (new_ty.valtype != existing_ty.valtype) {
                    var err = try diags.addErrorWithNotes(2);
                    try err.addMsg("symbol '{s}' mismatching global types", .{name.slice(wasm)});
                    gop.value_ptr.source_location.addNote(&err, "type {s} here", .{@tagName(existing_ty.valtype)});
                    source_location.addNote(&err, "type {s} here", .{@tagName(new_ty.valtype)});
                    continue;
                }
                if (new_ty.mutable != existing_ty.mutable) {
                    var err = try diags.addErrorWithNotes(2);
                    try err.addMsg("symbol '{s}' mismatching global mutability", .{name.slice(wasm)});
                    gop.value_ptr.source_location.addNote(&err, "{s} here", .{
                        if (existing_ty.mutable) "mutable" else "not mutable",
                    });
                    source_location.addNote(&err, "{s} here", .{
                        if (new_ty.mutable) "mutable" else "not mutable",
                    });
                    continue;
                }
                if (gop.value_ptr.resolution == .unresolved or gop.value_ptr.flags.binding == .weak) {
                    // Intentional: if they're both weak, take the last one.
                    gop.value_ptr.source_location = source_location;
                    gop.value_ptr.module_name = host_name;
                    gop.value_ptr.resolution = .fromObjectGlobal(wasm, index);
                    gop.value_ptr.flags = symbol.flags;
                    continue;
                }
                if (ptr.flags.binding == .weak) {
                    // Keep the existing one.
                    continue;
                }
                var err = try diags.addErrorWithNotes(2);
                try err.addMsg("symbol collision: {s}", .{name.slice(wasm)});
                gop.value_ptr.source_location.addNote(&err, "exported as {s} here", .{@tagName(existing_ty.valtype)});
                source_location.addNote(&err, "exported as {s} here", .{@tagName(new_ty.valtype)});
                continue;
            } else {
                gop.value_ptr.* = .{
                    .flags = symbol.flags,
                    .module_name = .none,
                    .name = name,
                    .source_location = source_location,
                    .resolution = .fromObjectGlobal(wasm, index),
                };
                gop.value_ptr.flags.global_type = .{
                    .valtype = .from(new_ty.valtype),
                    .mutable = new_ty.mutable,
                };
            }
        },
        .table => |i| {
            assert(!symbol.flags.undefined);
            const ptr = i.ptr(wasm);
            ptr.name = symbol.name;
            ptr.flags = symbol.flags;
        },
        .data => |index| {
            assert(!symbol.flags.undefined);
            const ptr = index.ptr(wasm);
            const name = ptr.name;
            assert(name.toOptional() == symbol.name);
            ptr.flags = symbol.flags;
            if (symbol.flags.binding == .local) continue; // No participation in symbol resolution.
            const gop = try wasm.object_data_imports.getOrPut(gpa, name);
            if (gop.found_existing) {
                if (gop.value_ptr.resolution == .unresolved or gop.value_ptr.flags.binding == .weak) {
                    // Intentional: if they're both weak, take the last one.
                    gop.value_ptr.source_location = source_location;
                    gop.value_ptr.resolution = .fromObjectDataIndex(wasm, index);
                    gop.value_ptr.flags = symbol.flags;
                    continue;
                }
                if (ptr.flags.binding == .weak) {
                    // Keep the existing one.
                    continue;
                }
                var err = try diags.addErrorWithNotes(2);
                try err.addMsg("symbol collision: {s}", .{name.slice(wasm)});
                gop.value_ptr.source_location.addNote(&err, "exported here", .{});
                source_location.addNote(&err, "exported here", .{});
                continue;
            } else {
                gop.value_ptr.* = .{
                    .flags = symbol.flags,
                    .source_location = source_location,
                    .resolution = .fromObjectDataIndex(wasm, index),
                };
            }
        },
        .section => |i| {
            // Name is provided by the section directly; symbol table does not have it.
            //const ptr = i.ptr(wasm);
            //ptr.flags = symbol.flags;
            _ = i;
            if (symbol.flags.undefined and symbol.flags.binding == .local) {
                const name = symbol.name.slice(wasm).?;
                diags.addParseError(path, "local symbol '{s}' references import", .{name});
            }
        },
    };

    // Apply export section info. This is done after the symbol table above so
    // that the symbol table can take precedence, overriding the export name.
    for (ss.exports.items) |*exp| {
        switch (exp.pointee) {
            inline .function, .table, .memory, .global => |index| {
                const ptr = index.ptr(wasm);
                ptr.name = exp.name.toOptional();
                ptr.flags.exported = true;
            },
        }
    }

    // Apply segment_info.
    const data_segments = wasm.object_data_segments.items[data_segment_start..];
    if (data_segments.len != ss.segment_info.items.len) {
        return diags.failParse(path, "expected {d} segment_info entries; found {d}", .{
            data_segments.len, ss.segment_info.items.len,
        });
    }
    for (data_segments, ss.segment_info.items) |*data, info| {
        data.name = info.name.toOptional();
        data.flags = .{
            .is_passive = data.flags.is_passive,
            .strings = info.flags.strings,
            .tls = info.flags.tls,
            .retain = info.flags.retain,
            .alignment = info.flags.alignment,
        };
    }

    // Check for indirect function table in case of an MVP object file.
    legacy_indirect_function_table: {
        // If there is a symbol for each import table, this is not a legacy object file.
        if (ss.table_imports.items.len == table_import_symbol_count) break :legacy_indirect_function_table;
        if (table_import_symbol_count != 0) {
            return diags.failParse(path, "expected a table entry symbol for each of the {d} table(s), but instead got {d} symbols.", .{
                ss.table_imports.items.len, table_import_symbol_count,
            });
        }
        // MVP object files cannot have any table definitions, only imports
        // (for the indirect function table).
        const tables = wasm.object_tables.items[tables_start..];
        if (tables.len > 0) {
            return diags.failParse(path, "table definition without representing table symbols", .{});
        }
        if (ss.table_imports.items.len != 1) {
            return diags.failParse(path, "found more than one table import, but no representing table symbols", .{});
        }
        const table_import_name = ss.table_imports.items[0].name;
        if (table_import_name != wasm.preloaded_strings.__indirect_function_table) {
            return diags.failParse(path, "non-indirect function table import '{s}' is missing a corresponding symbol", .{
                table_import_name.slice(wasm),
            });
        }
        const ptr = wasm.object_table_imports.getPtr(table_import_name).?;
        ptr.flags = .{
            .undefined = true,
            .no_strip = true,
        };
    }

    for (wasm.object_init_funcs.items[init_funcs_start..]) |init_func| {
        const func = init_func.function_index.ptr(wasm);
        const params = func.type_index.ptr(wasm).params.slice(wasm);
        if (params.len != 0) diags.addError("constructor function '{s}' has non-empty parameter list", .{
            func.name.slice(wasm).?,
        });
    }

    const functions_len: u32 = @intCast(wasm.object_functions.items.len - functions_start);
    if (functions_len > 0 and code_section_index == null)
        return diags.failParse(path, "code section missing ({d} functions)", .{functions_len});

    return .{
        .version = version,
        .path = path,
        .archive_member_name = try wasm.internOptionalString(archive_member_name),
        .start_function = start_function,
        .features = features,
        .functions = .{
            .off = functions_start,
            .len = functions_len,
        },
        .function_imports = .{
            .off = function_imports_start,
            .len = @intCast(wasm.object_function_imports.entries.len - function_imports_start),
        },
        .global_imports = .{
            .off = global_imports_start,
            .len = @intCast(wasm.object_global_imports.entries.len - global_imports_start),
        },
        .table_imports = .{
            .off = table_imports_start,
            .len = @intCast(wasm.object_table_imports.entries.len - table_imports_start),
        },
        .data_imports = .{
            .off = data_imports_start,
            .len = @intCast(wasm.object_data_imports.entries.len - data_imports_start),
        },
        .init_funcs = .{
            .off = init_funcs_start,
            .len = @intCast(wasm.object_init_funcs.items.len - init_funcs_start),
        },
        .comdats = .{
            .off = comdats_start,
            .len = @intCast(wasm.object_comdats.items.len - comdats_start),
        },
        .custom_segments = .{
            .off = custom_segment_start,
            .len = @intCast(wasm.object_custom_segments.entries.len - custom_segment_start),
        },
        .code_section_index = code_section_index,
        .global_section_index = global_section_index,
        .data_section_index = data_section_index,
        .is_included = must_link,
    };
}

/// Based on the "features" custom section, parses it into a list of
/// features that tell the linker what features were enabled and may be mandatory
/// to be able to link.
fn parseFeatures(wasm: *Wasm, br: *std.io.BufferedReader, path: Path) anyerror!Wasm.Feature.Set {
    const gpa = wasm.base.comp.gpa;
    const diags = &wasm.base.comp.link_diags;
    const features_len = try br.takeLeb128(u32);
    // This temporary allocation could be avoided by using the string_bytes buffer as a scratch space.
    const feature_buffer = try gpa.alloc(Wasm.Feature, features_len);
    defer gpa.free(feature_buffer);
    for (feature_buffer) |*feature| {
        const prefix: Wasm.Feature.Prefix = switch (try br.takeByte()) {
            '-' => .@"-",
            '+' => .@"+",
            '=' => .@"=",
            else => |b| return diags.failParse(path, "invalid feature prefix: 0x{x}", .{b}),
        };
        const name = try br.take(try br.takeLeb128(u32));
        const tag = std.meta.stringToEnum(Wasm.Feature.Tag, name) orelse {
            return diags.failParse(path, "unrecognized wasm feature in object: {s}", .{name});
        };
        feature.* = .{
            .prefix = prefix,
            .tag = tag,
        };
    }
    std.mem.sortUnstable(Wasm.Feature, feature_buffer, {}, Wasm.Feature.lessThan);

    return .fromString(try wasm.internString(@ptrCast(feature_buffer)));
}

fn readLimits(br: *std.io.BufferedReader) anyerror!std.wasm.Limits {
    const flags: std.wasm.Limits.Flags = @bitCast(try br.takeByte());
    const min = try br.takeLeb128(u32);
    const max = if (flags.has_max) try br.takeLeb128(u32) else 0;
    return .{
        .flags = flags,
        .min = min,
        .max = max,
    };
}

fn readInit(wasm: *Wasm, br: *std.io.BufferedReader) anyerror!Wasm.Expr {
    const start = br.seek;
    try skipInit(br); // one after the end opcode
    return wasm.addExpr(br.storageBuffer()[start..br.seek]);
}

pub fn skipInit(br: *std.io.BufferedReader) anyerror!void {
    switch (try br.takeEnum(std.wasm.Opcode, .little)) {
        .i32_const => _ = try br.takeLeb128(i32),
        .i64_const => _ = try br.takeLeb128(i64),
        .f32_const => try br.discard(5),
        .f64_const => try br.discard(9),
        .global_get => _ = try br.takeLeb128(u32),
        else => return error.InvalidInitOpcode,
    }
    if (try br.takeEnum(std.wasm.Opcode, .little) != .end) return error.InitExprMissingEnd;
}
