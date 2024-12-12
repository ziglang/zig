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
archive_member_name: ?[]const u8,
/// Represents the function ID that must be called on startup.
/// This is `null` by default as runtimes may determine the startup
/// function themselves. This is essentially legacy.
start_function: Wasm.OptionalObjectFunctionIndex,
/// A slice of features that tell the linker what features are mandatory, used
/// (or therefore missing) and must generate an error when another object uses
/// features that are not supported by the other.
features: Wasm.Feature.Set,
/// Points into Wasm object_functions
functions: RelativeSlice,
/// Points into Wasm object_function_imports
function_imports: RelativeSlice,
/// Points into Wasm object_global_imports
global_imports: RelativeSlice,
/// Points into Wasm object_table_imports
table_imports: RelativeSlice,
/// Points into Wasm object_custom_segments
custom_segments: RelativeSlice,
/// For calculating local section index from `Wasm.ObjectSectionIndex`.
local_section_index_base: u32,
/// Points into Wasm object_init_funcs
init_funcs: RelativeSlice,
/// Points into Wasm object_comdats
comdats: RelativeSlice,

pub const RelativeSlice = struct {
    off: u32,
    len: u32,
};

pub const SegmentInfo = struct {
    name: Wasm.String,
    flags: Flags,

    const Flags = packed struct(u32) {
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

pub const DataSegmentFlags = enum(u32) { active, passive, active_memidx };

pub const SubsectionType = enum(u8) {
    segment_info = 5,
    init_funcs = 6,
    comdat_info = 7,
    symbol_table = 8,
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
        data: struct {
            segment_index: Wasm.DataSegment.Index,
            segment_offset: u32,
            size: u32,
        },
        data_import: void,
        global: Wasm.ObjectGlobalIndex,
        global_import: Wasm.GlobalImport.Index,
        section: Wasm.ObjectSectionIndex,
        table: Wasm.ObjectTableIndex,
        table_import: Wasm.TableImport.Index,
    };
};

pub const ScratchSpace = struct {
    func_types: std.ArrayListUnmanaged(Wasm.FunctionType.Index) = .empty,
    func_type_indexes: std.ArrayListUnmanaged(FuncTypeIndex) = .empty,
    func_imports: std.ArrayListUnmanaged(FunctionImport) = .empty,
    symbol_table: std.ArrayListUnmanaged(Symbol) = .empty,
    segment_info: std.ArrayListUnmanaged(SegmentInfo) = .empty,
    exports: std.ArrayListUnmanaged(Export) = .empty,

    const Export = struct {
        name: Wasm.String,
        pointee: Pointee,

        const Pointee = union(std.wasm.ExternalKind) {
            function: Wasm.ObjectFunctionIndex,
            table: Wasm.ObjectTableIndex,
            memory: Wasm.ObjectMemoryIndex,
            global: Wasm.ObjectGlobalIndex,
        };
    };

    /// Index into `func_imports`.
    const FuncImportIndex = enum(u32) {
        _,

        fn ptr(index: FunctionImport, ss: *const ScratchSpace) *FunctionImport {
            return &ss.func_imports.items[@intFromEnum(index)];
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
        ss.symbol_table.deinit(gpa);
        ss.segment_info.deinit(gpa);
        ss.* = undefined;
    }

    fn clear(ss: *ScratchSpace) void {
        ss.exports.clearRetainingCapacity();
        ss.func_types.clearRetainingCapacity();
        ss.func_type_indexes.clearRetainingCapacity();
        ss.func_imports.clearRetainingCapacity();
        ss.symbol_table.clearRetainingCapacity();
        ss.segment_info.clearRetainingCapacity();
    }
};

pub fn parse(
    wasm: *Wasm,
    bytes: []const u8,
    path: Path,
    archive_member_name: ?[]const u8,
    host_name: Wasm.String,
    ss: *ScratchSpace,
    must_link: bool,
    gc_sections: bool,
) anyerror!Object {
    const gpa = wasm.base.comp.gpa;
    const diags = &wasm.base.comp.link_diags;

    var pos: usize = 0;

    if (!std.mem.eql(u8, bytes[0..std.wasm.magic.len], &std.wasm.magic)) return error.BadObjectMagic;
    pos += std.wasm.magic.len;

    const version = std.mem.readInt(u32, bytes[pos..][0..4], .little);
    pos += 4;

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
    const local_section_index_base = wasm.object_total_sections;
    const source_location: Wasm.SourceLocation = .fromObject(@enumFromInt(wasm.objects.items.len), wasm);

    ss.clear();

    var start_function: Wasm.OptionalObjectFunctionIndex = .none;
    var opt_features: ?Wasm.Feature.Set = null;
    var saw_linking_section = false;
    var has_tls = false;
    var table_count: usize = 0;
    while (pos < bytes.len) : (wasm.object_total_sections += 1) {
        const section_index: Wasm.ObjectSectionIndex = @enumFromInt(wasm.object_total_sections);

        const section_tag: std.wasm.Section = @enumFromInt(bytes[pos]);
        pos += 1;

        const len, pos = readLeb(u32, bytes, pos);
        const section_end = pos + len;
        switch (section_tag) {
            .custom => {
                const section_name, pos = readBytes(bytes, pos);
                if (std.mem.eql(u8, section_name, "linking")) {
                    saw_linking_section = true;
                    const section_version, pos = readLeb(u32, bytes, pos);
                    log.debug("link meta data version: {d}", .{section_version});
                    if (section_version != 2) return error.UnsupportedVersion;
                    while (pos < section_end) {
                        const sub_type, pos = readLeb(u8, bytes, pos);
                        log.debug("found subsection: {s}", .{@tagName(@as(SubsectionType, @enumFromInt(sub_type)))});
                        const payload_len, pos = readLeb(u32, bytes, pos);
                        if (payload_len == 0) break;

                        const count, pos = readLeb(u32, bytes, pos);

                        switch (@as(SubsectionType, @enumFromInt(sub_type))) {
                            .segment_info => {
                                for (try ss.segment_info.addManyAsSlice(gpa, count)) |*segment| {
                                    const name, pos = readBytes(bytes, pos);
                                    const alignment, pos = readLeb(u32, bytes, pos);
                                    const flags_u32, pos = readLeb(u32, bytes, pos);
                                    const flags: SegmentInfo.Flags = @bitCast(flags_u32);
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
                                            .alignment = @enumFromInt(alignment),
                                            .retain = flags.retain,
                                        },
                                    };
                                }
                            },
                            .init_funcs => {
                                for (try wasm.object_init_funcs.addManyAsSlice(gpa, count)) |*func| {
                                    const priority, pos = readLeb(u32, bytes, pos);
                                    const symbol_index, pos = readLeb(u32, bytes, pos);
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
                                }
                            },
                            .comdat_info => {
                                for (try wasm.object_comdats.addManyAsSlice(gpa, count)) |*comdat| {
                                    const name, pos = readBytes(bytes, pos);
                                    const flags, pos = readLeb(u32, bytes, pos);
                                    if (flags != 0) return error.UnexpectedComdatFlags;
                                    const symbol_count, pos = readLeb(u32, bytes, pos);
                                    const start_off: u32 = @intCast(wasm.object_comdat_symbols.len);
                                    try wasm.object_comdat_symbols.ensureUnusedCapacity(gpa, symbol_count);
                                    for (0..symbol_count) |_| {
                                        const kind, pos = readEnum(Wasm.Comdat.Symbol.Type, bytes, pos);
                                        const index, pos = readLeb(u32, bytes, pos);
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
                                }
                            },
                            .symbol_table => {
                                for (try ss.symbol_table.addManyAsSlice(gpa, count)) |*symbol| {
                                    const tag, pos = readEnum(Symbol.Tag, bytes, pos);
                                    const flags, pos = readLeb(u32, bytes, pos);
                                    symbol.* = .{
                                        .flags = @bitCast(flags),
                                        .name = .none,
                                        .pointee = undefined,
                                    };
                                    symbol.flags.initZigSpecific(must_link, gc_sections);

                                    switch (tag) {
                                        .data => {
                                            const name, pos = readBytes(bytes, pos);
                                            symbol.name = (try wasm.internString(name)).toOptional();
                                            if (symbol.flags.undefined) {
                                                symbol.pointee = .data_import;
                                            } else {
                                                const segment_index, pos = readLeb(u32, bytes, pos);
                                                const segment_offset, pos = readLeb(u32, bytes, pos);
                                                const size, pos = readLeb(u32, bytes, pos);

                                                symbol.pointee = .{ .data = .{
                                                    .segment_index = @enumFromInt(data_segment_start + segment_index),
                                                    .segment_offset = segment_offset,
                                                    .size = size,
                                                } };
                                            }
                                        },
                                        .section => {
                                            const local_section, pos = readLeb(u32, bytes, pos);
                                            const section: Wasm.ObjectSectionIndex = @enumFromInt(local_section_index_base + local_section);
                                            symbol.pointee = .{ .section = section };
                                        },

                                        .function => {
                                            const local_index, pos = readLeb(u32, bytes, pos);
                                            if (symbol.flags.undefined) {
                                                symbol.pointee = .{ .function_import = @enumFromInt(local_index) };
                                                if (symbol.flags.explicit_name) {
                                                    const name, pos = readBytes(bytes, pos);
                                                    symbol.name = (try wasm.internString(name)).toOptional();
                                                }
                                            } else {
                                                symbol.pointee = .{ .function = @enumFromInt(functions_start + local_index) };
                                                const name, pos = readBytes(bytes, pos);
                                                symbol.name = (try wasm.internString(name)).toOptional();
                                            }
                                        },
                                        .global => {
                                            const local_index, pos = readLeb(u32, bytes, pos);
                                            if (symbol.flags.undefined) {
                                                symbol.pointee = .{ .global_import = @enumFromInt(global_imports_start + local_index) };
                                                if (symbol.flags.explicit_name) {
                                                    const name, pos = readBytes(bytes, pos);
                                                    symbol.name = (try wasm.internString(name)).toOptional();
                                                }
                                            } else {
                                                symbol.pointee = .{ .global = @enumFromInt(globals_start + local_index) };
                                                const name, pos = readBytes(bytes, pos);
                                                symbol.name = (try wasm.internString(name)).toOptional();
                                            }
                                        },
                                        .table => {
                                            table_count += 1;
                                            const local_index, pos = readLeb(u32, bytes, pos);
                                            if (symbol.flags.undefined) {
                                                symbol.pointee = .{ .table_import = @enumFromInt(table_imports_start + local_index) };
                                                if (symbol.flags.explicit_name) {
                                                    const name, pos = readBytes(bytes, pos);
                                                    symbol.name = (try wasm.internString(name)).toOptional();
                                                }
                                            } else {
                                                symbol.pointee = .{ .table = @enumFromInt(tables_start + local_index) };
                                                const name, pos = readBytes(bytes, pos);
                                                symbol.name = (try wasm.internString(name)).toOptional();
                                            }
                                        },
                                        else => {
                                            log.debug("unrecognized symbol type tag: {x}", .{@intFromEnum(tag)});
                                            return error.UnrecognizedSymbolType;
                                        },
                                    }
                                    log.debug("found symbol: {}", .{symbol});
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
                    const local_section, pos = readLeb(u32, bytes, pos);
                    const count, pos = readLeb(u32, bytes, pos);
                    const section: Wasm.ObjectSectionIndex = @enumFromInt(local_section_index_base + local_section);

                    log.debug("found {d} relocations for section={d}", .{ count, section });

                    var prev_offset: u32 = 0;
                    try wasm.object_relocations.ensureUnusedCapacity(gpa, count);
                    for (0..count) |_| {
                        const tag: Wasm.ObjectRelocation.Tag = @enumFromInt(bytes[pos]);
                        pos += 1;
                        const offset, pos = readLeb(u32, bytes, pos);
                        const index, pos = readLeb(u32, bytes, pos);

                        if (offset < prev_offset)
                            return diags.failParse(path, "relocation entries not sorted by offset", .{});
                        prev_offset = offset;

                        switch (tag) {
                            .MEMORY_ADDR_LEB,
                            .MEMORY_ADDR_SLEB,
                            .MEMORY_ADDR_I32,
                            .MEMORY_ADDR_REL_SLEB,
                            .MEMORY_ADDR_LEB64,
                            .MEMORY_ADDR_SLEB64,
                            .MEMORY_ADDR_I64,
                            .MEMORY_ADDR_REL_SLEB64,
                            .MEMORY_ADDR_TLS_SLEB,
                            .MEMORY_ADDR_LOCREL_I32,
                            .MEMORY_ADDR_TLS_SLEB64,
                            .FUNCTION_OFFSET_I32,
                            .SECTION_OFFSET_I32,
                            .FUNCTION_OFFSET_I64,
                            => {
                                const addend: i32, pos = readLeb(i32, bytes, pos);
                                wasm.object_relocations.appendAssumeCapacity(.{
                                    .tag = tag,
                                    .offset = offset,
                                    .pointee = .{ .section = ss.symbol_table.items[index].pointee.section },
                                    .addend = addend,
                                });
                            },
                            .TYPE_INDEX_LEB => {
                                wasm.object_relocations.appendAssumeCapacity(.{
                                    .tag = tag,
                                    .offset = offset,
                                    .pointee = .{ .type_index = ss.func_types.items[index] },
                                    .addend = undefined,
                                });
                            },
                            .FUNCTION_INDEX_LEB,
                            .FUNCTION_INDEX_I32,
                            .GLOBAL_INDEX_LEB,
                            .GLOBAL_INDEX_I32,
                            .TABLE_INDEX_SLEB,
                            .TABLE_INDEX_I32,
                            .TABLE_INDEX_SLEB64,
                            .TABLE_INDEX_I64,
                            .TABLE_NUMBER_LEB,
                            .TABLE_INDEX_REL_SLEB,
                            .TABLE_INDEX_REL_SLEB64,
                            .TAG_INDEX_LEB,
                            => {
                                wasm.object_relocations.appendAssumeCapacity(.{
                                    .tag = tag,
                                    .offset = offset,
                                    .pointee = .{ .symbol_name = ss.symbol_table.items[index].name.unwrap().? },
                                    .addend = undefined,
                                });
                            },
                        }
                    }

                    try wasm.object_relocations_table.putNoClobber(gpa, section, .{
                        .off = @intCast(wasm.object_relocations.len - count),
                        .len = count,
                    });
                } else if (std.mem.eql(u8, section_name, "target_features")) {
                    opt_features, pos = try parseFeatures(wasm, bytes, pos, path);
                } else if (std.mem.startsWith(u8, section_name, ".debug")) {
                    const debug_content = bytes[pos..section_end];
                    pos = section_end;

                    const data_off: u32 = @intCast(wasm.string_bytes.items.len);
                    try wasm.string_bytes.appendSlice(gpa, debug_content);

                    try wasm.object_custom_segments.put(gpa, section_index, .{
                        .payload = .{
                            .off = data_off,
                            .len = @intCast(debug_content.len),
                        },
                        .flags = .{},
                        .section_name = try wasm.internString(section_name),
                    });
                } else {
                    pos = section_end;
                }
            },
            .type => {
                const func_types_len, pos = readLeb(u32, bytes, pos);
                for (try ss.func_types.addManyAsSlice(gpa, func_types_len)) |*func_type| {
                    if (bytes[pos] != std.wasm.function_type) return error.ExpectedFuncType;
                    pos += 1;

                    const params, pos = readBytes(bytes, pos);
                    const returns, pos = readBytes(bytes, pos);
                    func_type.* = try wasm.addFuncType(.{
                        .params = .fromString(try wasm.internString(params)),
                        .returns = .fromString(try wasm.internString(returns)),
                    });
                }
            },
            .import => {
                const imports_len, pos = readLeb(u32, bytes, pos);
                for (0..imports_len) |_| {
                    const module_name, pos = readBytes(bytes, pos);
                    const name, pos = readBytes(bytes, pos);
                    const kind, pos = readEnum(std.wasm.ExternalKind, bytes, pos);
                    const interned_module_name = try wasm.internString(module_name);
                    const interned_name = try wasm.internString(name);
                    switch (kind) {
                        .function => {
                            const function, pos = readLeb(u32, bytes, pos);
                            try ss.func_imports.append(gpa, .{
                                .module_name = interned_module_name,
                                .name = interned_name,
                                .function_index = @enumFromInt(function),
                            });
                        },
                        .memory => {
                            const limits, pos = readLimits(bytes, pos);
                            try wasm.object_memory_imports.append(gpa, .{
                                .module_name = interned_module_name,
                                .name = interned_name,
                                .limits_min = limits.min,
                                .limits_max = limits.max,
                                .limits_has_max = limits.flags.has_max,
                                .limits_is_shared = limits.flags.is_shared,
                            });
                        },
                        .global => {
                            const valtype, pos = readEnum(std.wasm.Valtype, bytes, pos);
                            const mutable = bytes[pos] == 0x01;
                            pos += 1;
                            try wasm.object_global_imports.put(gpa, interned_name, .{
                                .flags = .{
                                    .global_type = .{
                                        .valtype = .from(valtype),
                                        .mutable = mutable,
                                    },
                                },
                                .module_name = interned_module_name,
                                .source_location = source_location,
                                .resolution = .unresolved,
                            });
                        },
                        .table => {
                            const ref_type, pos = readEnum(std.wasm.RefType, bytes, pos);
                            const limits, pos = readLimits(bytes, pos);
                            try wasm.object_table_imports.put(gpa, interned_name, .{
                                .flags = .{
                                    .limits_has_max = limits.flags.has_max,
                                    .limits_is_shared = limits.flags.is_shared,
                                    .ref_type = .from(ref_type),
                                },
                                .module_name = interned_module_name,
                                .source_location = source_location,
                                .resolution = .unresolved,
                                .limits_min = limits.min,
                                .limits_max = limits.max,
                            });
                        },
                    }
                }
            },
            .function => {
                const functions_len, pos = readLeb(u32, bytes, pos);
                for (try ss.func_type_indexes.addManyAsSlice(gpa, functions_len)) |*func_type_index| {
                    const i, pos = readLeb(u32, bytes, pos);
                    func_type_index.* = @enumFromInt(i);
                }
            },
            .table => {
                const tables_len, pos = readLeb(u32, bytes, pos);
                for (try wasm.object_tables.addManyAsSlice(gpa, tables_len)) |*table| {
                    const ref_type, pos = readEnum(std.wasm.RefType, bytes, pos);
                    const limits, pos = readLimits(bytes, pos);
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
                const memories_len, pos = readLeb(u32, bytes, pos);
                for (try wasm.object_memories.addManyAsSlice(gpa, memories_len)) |*memory| {
                    const limits, pos = readLimits(bytes, pos);
                    memory.* = .{ .limits = limits };
                }
            },
            .global => {
                const globals_len, pos = readLeb(u32, bytes, pos);
                for (try wasm.object_globals.addManyAsSlice(gpa, globals_len)) |*global| {
                    const valtype, pos = readEnum(std.wasm.Valtype, bytes, pos);
                    const mutable = bytes[pos] == 0x01;
                    pos += 1;
                    const expr, pos = try readInit(wasm, bytes, pos);
                    global.* = .{
                        .name = .none,
                        .flags = .{
                            .global_type = .{
                                .valtype = .from(valtype),
                                .mutable = mutable,
                            },
                        },
                        .expr = expr,
                    };
                }
            },
            .@"export" => {
                const exports_len, pos = readLeb(u32, bytes, pos);
                // Read into scratch space, and then later add this data as if
                // it were extra symbol table entries, but allow merging with
                // existing symbol table data if the name matches.
                for (try ss.exports.addManyAsSlice(gpa, exports_len)) |*exp| {
                    const name, pos = readBytes(bytes, pos);
                    const kind: std.wasm.ExternalKind = @enumFromInt(bytes[pos]);
                    pos += 1;
                    const index, pos = readLeb(u32, bytes, pos);
                    exp.* = .{
                        .name = try wasm.internString(name),
                        .pointee = switch (kind) {
                            .function => .{ .function = @enumFromInt(functions_start + index) },
                            .table => .{ .table = @enumFromInt(tables_start + index) },
                            .memory => .{ .memory = @enumFromInt(memories_start + index) },
                            .global => .{ .global = @enumFromInt(globals_start + index) },
                        },
                    };
                }
            },
            .start => {
                const index, pos = readLeb(u32, bytes, pos);
                start_function = @enumFromInt(functions_start + index);
            },
            .element => {
                log.warn("unimplemented: element section in {}", .{path});
                pos = section_end;
            },
            .code => {
                const start = pos;
                const count, pos = readLeb(u32, bytes, pos);
                for (try wasm.object_functions.addManyAsSlice(gpa, count)) |*elem| {
                    const code_len, pos = readLeb(u32, bytes, pos);
                    const offset: u32 = @intCast(pos - start);
                    const payload = try wasm.addRelocatableDataPayload(bytes[pos..][0..code_len]);
                    pos += code_len;
                    elem.* = .{
                        .flags = .{}, // populated from symbol table
                        .name = .none, // populated from symbol table
                        .type_index = undefined, // populated from func_types
                        .code = payload,
                        .offset = offset,
                        .section_index = section_index,
                        .source_location = source_location,
                    };
                }
            },
            .data => {
                const start = pos;
                const count, pos = readLeb(u32, bytes, pos);
                for (try wasm.object_data_segments.addManyAsSlice(gpa, count)) |*elem| {
                    const flags, pos = readEnum(DataSegmentFlags, bytes, pos);
                    if (flags == .active_memidx) {
                        const memidx, pos = readLeb(u32, bytes, pos);
                        if (memidx != 0) return diags.failParse(path, "data section uses mem index {d}", .{memidx});
                    }
                    //const expr, pos = if (flags != .passive) try readInit(wasm, bytes, pos) else .{ .none, pos };
                    if (flags != .passive) pos = try skipInit(bytes, pos);
                    const data_len, pos = readLeb(u32, bytes, pos);
                    const segment_offset: u32 = @intCast(pos - start);
                    const payload = try wasm.addRelocatableDataPayload(bytes[pos..][0..data_len]);
                    pos += data_len;
                    elem.* = .{
                        .payload = payload,
                        .segment_offset = segment_offset,
                        .section_index = section_index,
                        .name = .none, // Populated from symbol table
                        .flags = .{}, // Populated from symbol table and segment_info
                    };
                }
            },
            else => pos = section_end,
        }
        if (pos != section_end) return error.MalformedSection;
    }
    if (!saw_linking_section) return error.MissingLinkingSection;

    if (has_tls) {
        const cpu_features = wasm.base.comp.root_mod.resolved_target.result.cpu.features;
        if (!std.Target.wasm.featureSetHas(cpu_features, .atomics))
            return diags.failParse(path, "object has TLS segment but target CPU feature atomics is disabled", .{});
        if (!std.Target.wasm.featureSetHas(cpu_features, .bulk_memory))
            return diags.failParse(path, "object has TLS segment but target CPU feature bulk_memory is disabled", .{});
    }

    const features = opt_features orelse return error.MissingFeatures;
    if (true) @panic("iterate features, match against target features");

    // Apply function type information.
    for (ss.func_types.items, wasm.object_functions.items[functions_start..]) |func_type, *func| {
        func.type_index = func_type;
    }

    // Apply symbol table information.
    for (ss.symbol_table.items) |symbol| switch (symbol.pointee) {
        .function_import => |index| {
            const ptr = index.ptr(ss);
            const name = symbol.name.unwrap().?;
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
                    try err.addSrcNote(gop.value_ptr.source_location, "imported as {} here", .{gop.value_ptr.type.fmt(wasm)});
                    try err.addSrcNote(source_location, "imported as {} here", .{fn_ty_index.fmt(wasm)});
                    continue;
                }
                if (gop.value_ptr.module_name != ptr.module_name) {
                    var err = try diags.addErrorWithNotes(2);
                    try err.addMsg("symbol '{s}' mismatching module names", .{name.slice(wasm)});
                    try err.addSrcNote(gop.value_ptr.source_location, "module '{s}' here", .{gop.value_ptr.module_name.slice(wasm)});
                    try err.addSrcNote(source_location, "module '{s}' here", .{ptr.module_name.slice(wasm)});
                    continue;
                }
                if (symbol.flags.binding == .strong) gop.value_ptr.flags.binding = .strong;
                if (!symbol.flags.visibility_hidden) gop.value_ptr.flags.visibility_hidden = false;
                if (symbol.flags.no_strip) gop.value_ptr.flags.no_strip = true;
            } else {
                gop.value_ptr.* = .{
                    .flags = symbol.flags,
                    .module_name = ptr.module_name,
                    .source_location = source_location,
                    .resolution = .unresolved,
                    .type = fn_ty_index,
                };
            }
        },
        .function => |index| {
            assert(!symbol.flags.undefined);
            const ptr = index.ptr();
            ptr.name = symbol.name;
            ptr.flags = symbol.flags;
            if (symbol.flags.binding == .local) continue; // No participation in symbol resolution.
            const name = symbol.name.unwrap().?;
            const gop = try wasm.object_function_imports.getOrPut(gpa, name);
            if (gop.found_existing) {
                if (gop.value_ptr.type != ptr.type_index) {
                    var err = try diags.addErrorWithNotes(2);
                    try err.addMsg("function signature mismatch: {s}", .{name.slice(wasm)});
                    try err.addSrcNote(gop.value_ptr.source_location, "exported as {} here", .{ptr.type_index.fmt(wasm)});
                    const word = if (gop.value_ptr.resolution == .none) "imported" else "exported";
                    try err.addSrcNote(source_location, "{s} as {} here", .{ word, gop.value_ptr.type.fmt(wasm) });
                    continue;
                }
                if (gop.value_ptr.resolution == .none or gop.value_ptr.flags.binding == .weak) {
                    // Intentional: if they're both weak, take the last one.
                    gop.value_ptr.source_location = source_location;
                    gop.value_ptr.module_name = host_name;
                    gop.value_ptr.resolution = .fromObjectFunction(index);
                    continue;
                }
                var err = try diags.addErrorWithNotes(2);
                try err.addMsg("symbol collision: {s}", .{name.slice(wasm)});
                try err.addSrcNote(gop.value_ptr.source_location, "exported as {} here", .{ptr.type_index.fmt(wasm)});
                try err.addSrcNote(source_location, "exported as {} here", .{gop.value_ptr.type.fmt(wasm)});
                continue;
            } else {
                gop.value_ptr.* = .{
                    .flags = symbol.flags,
                    .module_name = host_name,
                    .source_location = source_location,
                    .resolution = .fromObjectFunction(index),
                    .type = ptr.type_index,
                };
            }
        },

        inline .global, .global_import, .table, .table_import => |i| {
            const ptr = i.ptr(wasm);
            ptr.name = symbol.name;
            ptr.flags = symbol.flags;
            if (symbol.flags.undefined and symbol.flags.binding == .local) {
                const name = ptr.name.slice(wasm).?;
                diags.addParseError(path, "local symbol '{s}' references import", .{name});
            }
        },
        .section => |i| {
            // Name is provided by the section directly; symbol table does not have it.
            const ptr = i.ptr(wasm);
            ptr.flags = symbol.flags;
            if (symbol.flags.undefined and symbol.flags.binding == .local) {
                const name = ptr.name.slice(wasm);
                diags.addParseError(path, "local symbol '{s}' references import", .{name});
            }
        },
        .data_import => {
            const name = symbol.name.unwrap().?;
            log.warn("TODO data import '{s}'", .{name.slice(wasm)});
        },
        .data => |data| {
            const ptr = data.ptr(wasm);
            const is_passive = ptr.flags.is_passive;
            ptr.name = symbol.name;
            ptr.flags = symbol.flags;
            ptr.flags.is_passive = is_passive;
            ptr.offset = data.segment_offset;
            ptr.size = data.size;
        },
    };

    // Apply export section info. This is done after the symbol table above so
    // that the symbol table can take precedence, overriding the export name.
    for (ss.exports.items) |*exp| {
        switch (exp.pointee) {
            inline .function, .table, .memory, .global => |index| {
                const ptr = index.ptr(wasm);
                if (ptr.name == .none) {
                    // Missng symbol table entry; use defaults for exported things.
                    ptr.name = exp.name.toOptional();
                    ptr.flags.exported = true;
                }
            },
        }
    }

    // Apply segment_info.
    for (wasm.object_data_segments.items[data_segment_start..], ss.segment_info.items) |*data, info| {
        data.name = info.name.toOptional();
        data.flags.strings = info.flags.strings;
        data.flags.tls = data.flags.tls or info.flags.tls;
        data.flags.no_strip = info.flags.retain;
        data.flags.alignment = info.flags.alignment;
        if (data.flags.undefined and data.flags.binding == .local) {
            const name = info.name.slice(wasm);
            diags.addParseError(path, "local symbol '{s}' references import", .{name});
        }
    }

    // Check for indirect function table in case of an MVP object file.
    legacy_indirect_function_table: {
        const table_import_names = wasm.object_table_imports.keys()[table_imports_start..];
        const table_import_values = wasm.object_table_imports.values()[table_imports_start..];
        // If there is a symbol for each import table, this is not a legacy object file.
        if (table_import_names.len == table_count) break :legacy_indirect_function_table;
        if (table_count != 0) {
            return diags.failParse(path, "expected a table entry symbol for each of the {d} table(s), but instead got {d} symbols.", .{
                table_import_names.len, table_count,
            });
        }
        // MVP object files cannot have any table definitions, only
        // imports (for the indirect function table).
        const tables = wasm.object_tables.items[tables_start..];
        if (tables.len > 0) {
            return diags.failParse(path, "table definition without representing table symbols", .{});
        }
        if (table_import_names.len != 1) {
            return diags.failParse(path, "found more than one table import, but no representing table symbols", .{});
        }
        const table_import_name = table_import_names[0];
        if (table_import_name != wasm.preloaded_strings.__indirect_function_table) {
            return diags.failParse(path, "non-indirect function table import '{s}' is missing a corresponding symbol", .{
                table_import_name.slice(wasm),
            });
        }
        table_import_values[0].flags = .{
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

    return .{
        .version = version,
        .path = path,
        .archive_member_name = archive_member_name,
        .start_function = start_function,
        .features = features,
        .functions = .{
            .off = functions_start,
            .len = @intCast(wasm.object_functions.items.len - functions_start),
        },
        .globals = .{
            .off = globals_start,
            .len = @intCast(wasm.object_globals.items.len - globals_start),
        },
        .tables = .{
            .off = tables_start,
            .len = @intCast(wasm.object_tables.items.len - tables_start),
        },
        .memories = .{
            .off = memories_start,
            .len = @intCast(wasm.object_memories.items.len - memories_start),
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
            .len = @intCast(wasm.object_table_imports.items.len - table_imports_start),
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
        .local_section_index_base = local_section_index_base,
    };
}

/// Based on the "features" custom section, parses it into a list of
/// features that tell the linker what features were enabled and may be mandatory
/// to be able to link.
fn parseFeatures(
    wasm: *Wasm,
    bytes: []const u8,
    start_pos: usize,
    path: Path,
) error{ OutOfMemory, LinkFailure }!struct { Wasm.Feature.Set, usize } {
    const gpa = wasm.base.comp.gpa;
    const diags = &wasm.base.comp.link_diags;
    const features_len, var pos = readLeb(u32, bytes, start_pos);
    // This temporary allocation could be avoided by using the string_bytes buffer as a scratch space.
    const feature_buffer = try gpa.alloc(Wasm.Feature, features_len);
    defer gpa.free(feature_buffer);
    for (feature_buffer) |*feature| {
        const prefix: Wasm.Feature.Prefix = switch (bytes[pos]) {
            '-' => .@"-",
            '+' => .@"+",
            '=' => .@"=",
            else => |b| return diags.failParse(path, "invalid feature prefix: 0x{x}", .{b}),
        };
        pos += 1;
        const name, pos = readBytes(bytes, pos);
        const tag = std.meta.stringToEnum(Wasm.Feature.Tag, name) orelse {
            return diags.failParse(path, "unrecognized wasm feature in object: {s}", .{name});
        };
        feature.* = .{
            .prefix = prefix,
            .tag = tag,
        };
    }
    std.mem.sortUnstable(Wasm.Feature, feature_buffer, {}, Wasm.Feature.lessThan);

    return .{
        .fromString(try wasm.internString(@ptrCast(feature_buffer))),
        pos,
    };
}

fn readLeb(comptime T: type, bytes: []const u8, pos: usize) struct { T, usize } {
    var fbr = std.io.fixedBufferStream(bytes[pos..]);
    return .{
        switch (@typeInfo(T).int.signedness) {
            .signed => std.leb.readIleb128(T, fbr.reader()) catch unreachable,
            .unsigned => std.leb.readUleb128(T, fbr.reader()) catch unreachable,
        },
        pos + fbr.pos,
    };
}

fn readBytes(bytes: []const u8, start_pos: usize) struct { []const u8, usize } {
    const len, const pos = readLeb(u32, bytes, start_pos);
    return .{
        bytes[pos..][0..len],
        pos + len,
    };
}

fn readEnum(comptime T: type, bytes: []const u8, pos: usize) struct { T, usize } {
    const Tag = @typeInfo(T).@"enum".tag_type;
    const int, const new_pos = readLeb(Tag, bytes, pos);
    return .{ @enumFromInt(int), new_pos };
}

fn readLimits(bytes: []const u8, start_pos: usize) struct { std.wasm.Limits, usize } {
    const flags: std.wasm.Limits.Flags = @bitCast(bytes[start_pos]);
    const min, const max_pos = readLeb(u32, bytes, start_pos + 1);
    const max, const end_pos = if (flags.has_max) readLeb(u32, bytes, max_pos) else .{ 0, max_pos };
    return .{ .{
        .flags = flags,
        .min = min,
        .max = max,
    }, end_pos };
}

fn readInit(wasm: *Wasm, bytes: []const u8, pos: usize) !struct { Wasm.Expr, usize } {
    const end_pos = try skipInit(bytes, pos); // one after the end opcode
    return .{ try wasm.addExpr(bytes[pos..end_pos]), end_pos };
}

pub fn exprEndPos(bytes: []const u8, pos: usize) error{InvalidInitOpcode}!usize {
    const opcode = bytes[pos];
    return switch (@as(std.wasm.Opcode, @enumFromInt(opcode))) {
        .i32_const => readLeb(i32, bytes, pos + 1)[1],
        .i64_const => readLeb(i64, bytes, pos + 1)[1],
        .f32_const => pos + 5,
        .f64_const => pos + 9,
        .global_get => readLeb(u32, bytes, pos + 1)[1],
        else => return error.InvalidInitOpcode,
    };
}

fn skipInit(bytes: []const u8, pos: usize) !usize {
    const end_pos = try exprEndPos(bytes, pos);
    const op, const final_pos = readEnum(std.wasm.Opcode, bytes, end_pos);
    if (op != .end) return error.InitExprMissingEnd;
    return final_pos;
}
