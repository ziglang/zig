//! Object represents a wasm object file. When initializing a new
//! `Object`, it will parse the contents of a given file handler, and verify
//! the data on correctness. The result can then be used by the linker.
const Object = @This();

const Wasm = @import("../Wasm.zig");
const Atom = Wasm.Atom;
const Alignment = Wasm.Alignment;
const Symbol = @import("Symbol.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;
const leb = std.leb;
const meta = std.meta;
const Path = std.Build.Cache.Path;

const log = std.log.scoped(.object);

/// Wasm spec version used for this `Object`
version: u32 = 0,
/// For error reporting purposes only.
/// Name (read path) of the object or archive file.
path: Path,
/// For error reporting purposes only.
/// If this represents an object in an archive, it's the basename of the
/// object, and path refers to the archive.
archive_member_name: ?[]const u8,
/// Parsed type section
func_types: []const std.wasm.Type = &.{},
/// A list of all imports for this module
imports: []const Wasm.Import = &.{},
/// Parsed function section
functions: []const std.wasm.Func = &.{},
/// Parsed table section
tables: []const std.wasm.Table = &.{},
/// Parsed memory section
memories: []const std.wasm.Memory = &.{},
/// Parsed global section
globals: []const std.wasm.Global = &.{},
/// Parsed export section
exports: []const Wasm.Export = &.{},
/// Parsed element section
elements: []const std.wasm.Element = &.{},
/// Represents the function ID that must be called on startup.
/// This is `null` by default as runtimes may determine the startup
/// function themselves. This is essentially legacy.
start: ?u32 = null,
/// A slice of features that tell the linker what features are mandatory,
/// used (or therefore missing) and must generate an error when another
/// object uses features that are not supported by the other.
features: []const Wasm.Feature = &.{},
/// A table that maps the relocations we must perform where the key represents
/// the section that the list of relocations applies to.
relocations: std.AutoArrayHashMapUnmanaged(u32, []Wasm.Relocation) = .empty,
/// Table of symbols belonging to this Object file
symtable: []Symbol = &.{},
/// Extra metadata about the linking section, such as alignment of segments and their name
segment_info: []const Wasm.NamedSegment = &.{},
/// A sequence of function initializers that must be called on startup
init_funcs: []const Wasm.InitFunc = &.{},
/// Comdat information
comdat_info: []const Wasm.Comdat = &.{},
/// Represents non-synthetic sections that can essentially be mem-cpy'd into place
/// after performing relocations.
relocatable_data: std.AutoHashMapUnmanaged(RelocatableData.Tag, []RelocatableData) = .empty,
/// Amount of functions in the `import` sections.
imported_functions_count: u32 = 0,
/// Amount of globals in the `import` section.
imported_globals_count: u32 = 0,
/// Amount of tables in the `import` section.
imported_tables_count: u32 = 0,

/// Represents a single item within a section (depending on its `type`)
pub const RelocatableData = struct {
    /// The type of the relocatable data
    type: Tag,
    /// Pointer to the data of the segment, where its length is written to `size`
    data: [*]u8,
    /// The size in bytes of the data representing the segment within the section
    size: u32,
    /// The index within the section itself, or in case of a debug section,
    /// the offset within the `string_table`.
    index: u32,
    /// The offset within the section where the data starts
    offset: u32,
    /// Represents the index of the section it belongs to
    section_index: u32,
    /// Whether the relocatable section is represented by a symbol or not.
    /// Can only be `true` for custom sections.
    represented: bool = false,

    const Tag = enum { data, code, custom };

    /// Returns the alignment of the segment, by retrieving it from the segment
    /// meta data of the given object file.
    /// NOTE: Alignment is encoded as a power of 2, so we shift the symbol's
    /// alignment to retrieve the natural alignment.
    pub fn getAlignment(relocatable_data: RelocatableData, object: *const Object) Alignment {
        if (relocatable_data.type != .data) return .@"1";
        return object.segment_info[relocatable_data.index].alignment;
    }

    /// Returns the symbol kind that corresponds to the relocatable section
    pub fn getSymbolKind(relocatable_data: RelocatableData) Symbol.Tag {
        return switch (relocatable_data.type) {
            .data => .data,
            .code => .function,
            .custom => .section,
        };
    }

    /// Returns the index within a section, or in case of a custom section,
    /// returns the section index within the object file.
    pub fn getIndex(relocatable_data: RelocatableData) u32 {
        if (relocatable_data.type == .custom) return relocatable_data.section_index;
        return relocatable_data.index;
    }
};

/// Initializes a new `Object` from a wasm object file.
/// This also parses and verifies the object file.
/// When a max size is given, will only parse up to the given size,
/// else will read until the end of the file.
pub fn create(
    wasm: *Wasm,
    file_contents: []const u8,
    path: Path,
    archive_member_name: ?[]const u8,
) !Object {
    const gpa = wasm.base.comp.gpa;
    var object: Object = .{
        .path = path,
        .archive_member_name = archive_member_name,
    };

    var parser: Parser = .{
        .object = &object,
        .wasm = wasm,
        .reader = std.io.fixedBufferStream(file_contents),
    };
    try parser.parseObject(gpa);

    return object;
}

/// Frees all memory of `Object` at once. The given `Allocator` must be
/// the same allocator that was used when `init` was called.
pub fn deinit(object: *Object, gpa: Allocator) void {
    for (object.func_types) |func_ty| {
        gpa.free(func_ty.params);
        gpa.free(func_ty.returns);
    }
    gpa.free(object.func_types);
    gpa.free(object.functions);
    gpa.free(object.imports);
    gpa.free(object.tables);
    gpa.free(object.memories);
    gpa.free(object.globals);
    gpa.free(object.exports);
    for (object.elements) |el| {
        gpa.free(el.func_indexes);
    }
    gpa.free(object.elements);
    gpa.free(object.features);
    for (object.relocations.values()) |val| {
        gpa.free(val);
    }
    object.relocations.deinit(gpa);
    gpa.free(object.symtable);
    gpa.free(object.comdat_info);
    gpa.free(object.init_funcs);
    for (object.segment_info) |info| {
        gpa.free(info.name);
    }
    gpa.free(object.segment_info);
    {
        var it = object.relocatable_data.valueIterator();
        while (it.next()) |relocatable_data| {
            for (relocatable_data.*) |rel_data| {
                gpa.free(rel_data.data[0..rel_data.size]);
            }
            gpa.free(relocatable_data.*);
        }
    }
    object.relocatable_data.deinit(gpa);
    object.* = undefined;
}

/// Finds the import within the list of imports from a given kind and index of that kind.
/// Asserts the import exists
pub fn findImport(object: *const Object, sym: Symbol) Wasm.Import {
    var i: u32 = 0;
    return for (object.imports) |import| {
        if (std.meta.activeTag(import.kind) == sym.tag.externalType()) {
            if (i == sym.index) return import;
            i += 1;
        }
    } else unreachable; // Only existing imports are allowed to be found
}

/// Checks if the object file is an MVP version.
/// When that's the case, we check if there's an import table definition with its name
/// set to '__indirect_function_table". When that's also the case,
/// we initialize a new table symbol that corresponds to that import and return that symbol.
///
/// When the object file is *NOT* MVP, we return `null`.
fn checkLegacyIndirectFunctionTable(object: *Object, wasm: *const Wasm) !?Symbol {
    const diags = &wasm.base.comp.link_diags;

    var table_count: usize = 0;
    for (object.symtable) |sym| {
        if (sym.tag == .table) table_count += 1;
    }

    // For each import table, we also have a symbol so this is not a legacy object file
    if (object.imported_tables_count == table_count) return null;

    if (table_count != 0) {
        return diags.failParse(object.path, "expected a table entry symbol for each of the {d} table(s), but instead got {d} symbols.", .{
            object.imported_tables_count,
            table_count,
        });
    }

    // MVP object files cannot have any table definitions, only imports (for the indirect function table).
    if (object.tables.len > 0) {
        return diags.failParse(object.path, "unexpected table definition without representing table symbols.", .{});
    }

    if (object.imported_tables_count != 1) {
        return diags.failParse(object.path, "found more than one table import, but no representing table symbols", .{});
    }

    const table_import: Wasm.Import = for (object.imports) |imp| {
        if (imp.kind == .table) {
            break imp;
        }
    } else unreachable;

    if (table_import.name != wasm.preloaded_strings.__indirect_function_table) {
        return diags.failParse(object.path, "non-indirect function table import '{s}' is missing a corresponding symbol", .{
            wasm.stringSlice(table_import.name),
        });
    }

    var table_symbol: Symbol = .{
        .flags = 0,
        .name = table_import.name,
        .tag = .table,
        .index = 0,
        .virtual_address = undefined,
    };
    table_symbol.setFlag(.WASM_SYM_UNDEFINED);
    table_symbol.setFlag(.WASM_SYM_NO_STRIP);
    return table_symbol;
}

const Parser = struct {
    reader: std.io.FixedBufferStream([]const u8),
    /// Object file we're building
    object: *Object,
    /// Mutable so that the string table can be modified.
    wasm: *Wasm,

    fn parseObject(parser: *Parser, gpa: Allocator) anyerror!void {
        const wasm = parser.wasm;

        {
            var magic_bytes: [4]u8 = undefined;
            try parser.reader.reader().readNoEof(&magic_bytes);
            if (!std.mem.eql(u8, &magic_bytes, &std.wasm.magic)) return error.BadObjectMagic;
        }

        const version = try parser.reader.reader().readInt(u32, .little);
        parser.object.version = version;

        var saw_linking_section = false;

        var section_index: u32 = 0;
        while (parser.reader.reader().readByte()) |byte| : (section_index += 1) {
            const len = try readLeb(u32, parser.reader.reader());
            var limited_reader = std.io.limitedReader(parser.reader.reader(), len);
            const reader = limited_reader.reader();
            switch (@as(std.wasm.Section, @enumFromInt(byte))) {
                .custom => {
                    const name_len = try readLeb(u32, reader);
                    const name = try gpa.alloc(u8, name_len);
                    defer gpa.free(name);
                    try reader.readNoEof(name);

                    if (std.mem.eql(u8, name, "linking")) {
                        saw_linking_section = true;
                        try parser.parseMetadata(gpa, @as(usize, @intCast(reader.context.bytes_left)));
                    } else if (std.mem.startsWith(u8, name, "reloc")) {
                        try parser.parseRelocations(gpa);
                    } else if (std.mem.eql(u8, name, "target_features")) {
                        try parser.parseFeatures(gpa);
                    } else if (std.mem.startsWith(u8, name, ".debug")) {
                        const gop = try parser.object.relocatable_data.getOrPut(gpa, .custom);
                        var relocatable_data: std.ArrayListUnmanaged(RelocatableData) = .empty;
                        defer relocatable_data.deinit(gpa);
                        if (!gop.found_existing) {
                            gop.value_ptr.* = &.{};
                        } else {
                            relocatable_data = std.ArrayListUnmanaged(RelocatableData).fromOwnedSlice(gop.value_ptr.*);
                        }
                        const debug_size = @as(u32, @intCast(reader.context.bytes_left));
                        const debug_content = try gpa.alloc(u8, debug_size);
                        errdefer gpa.free(debug_content);
                        try reader.readNoEof(debug_content);

                        try relocatable_data.append(gpa, .{
                            .type = .custom,
                            .data = debug_content.ptr,
                            .size = debug_size,
                            .index = @intFromEnum(try wasm.internString(name)),
                            .offset = 0, // debug sections only contain 1 entry, so no need to calculate offset
                            .section_index = section_index,
                        });
                        gop.value_ptr.* = try relocatable_data.toOwnedSlice(gpa);
                    } else {
                        try reader.skipBytes(reader.context.bytes_left, .{});
                    }
                },
                .type => {
                    for (try readVec(&parser.object.func_types, reader, gpa)) |*type_val| {
                        if ((try reader.readByte()) != std.wasm.function_type) return error.ExpectedFuncType;

                        for (try readVec(&type_val.params, reader, gpa)) |*param| {
                            param.* = try readEnum(std.wasm.Valtype, reader);
                        }

                        for (try readVec(&type_val.returns, reader, gpa)) |*result| {
                            result.* = try readEnum(std.wasm.Valtype, reader);
                        }
                    }
                    try assertEnd(reader);
                },
                .import => {
                    for (try readVec(&parser.object.imports, reader, gpa)) |*import| {
                        const module_len = try readLeb(u32, reader);
                        const module_name = try gpa.alloc(u8, module_len);
                        defer gpa.free(module_name);
                        try reader.readNoEof(module_name);

                        const name_len = try readLeb(u32, reader);
                        const name = try gpa.alloc(u8, name_len);
                        defer gpa.free(name);
                        try reader.readNoEof(name);

                        const kind = try readEnum(std.wasm.ExternalKind, reader);
                        const kind_value: std.wasm.Import.Kind = switch (kind) {
                            .function => val: {
                                parser.object.imported_functions_count += 1;
                                break :val .{ .function = try readLeb(u32, reader) };
                            },
                            .memory => .{ .memory = try readLimits(reader) },
                            .global => val: {
                                parser.object.imported_globals_count += 1;
                                break :val .{ .global = .{
                                    .valtype = try readEnum(std.wasm.Valtype, reader),
                                    .mutable = (try reader.readByte()) == 0x01,
                                } };
                            },
                            .table => val: {
                                parser.object.imported_tables_count += 1;
                                break :val .{ .table = .{
                                    .reftype = try readEnum(std.wasm.RefType, reader),
                                    .limits = try readLimits(reader),
                                } };
                            },
                        };

                        import.* = .{
                            .module_name = try wasm.internString(module_name),
                            .name = try wasm.internString(name),
                            .kind = kind_value,
                        };
                    }
                    try assertEnd(reader);
                },
                .function => {
                    for (try readVec(&parser.object.functions, reader, gpa)) |*func| {
                        func.* = .{ .type_index = try readLeb(u32, reader) };
                    }
                    try assertEnd(reader);
                },
                .table => {
                    for (try readVec(&parser.object.tables, reader, gpa)) |*table| {
                        table.* = .{
                            .reftype = try readEnum(std.wasm.RefType, reader),
                            .limits = try readLimits(reader),
                        };
                    }
                    try assertEnd(reader);
                },
                .memory => {
                    for (try readVec(&parser.object.memories, reader, gpa)) |*memory| {
                        memory.* = .{ .limits = try readLimits(reader) };
                    }
                    try assertEnd(reader);
                },
                .global => {
                    for (try readVec(&parser.object.globals, reader, gpa)) |*global| {
                        global.* = .{
                            .global_type = .{
                                .valtype = try readEnum(std.wasm.Valtype, reader),
                                .mutable = (try reader.readByte()) == 0x01,
                            },
                            .init = try readInit(reader),
                        };
                    }
                    try assertEnd(reader);
                },
                .@"export" => {
                    for (try readVec(&parser.object.exports, reader, gpa)) |*exp| {
                        const name_len = try readLeb(u32, reader);
                        const name = try gpa.alloc(u8, name_len);
                        defer gpa.free(name);
                        try reader.readNoEof(name);
                        exp.* = .{
                            .name = try wasm.internString(name),
                            .kind = try readEnum(std.wasm.ExternalKind, reader),
                            .index = try readLeb(u32, reader),
                        };
                    }
                    try assertEnd(reader);
                },
                .start => {
                    parser.object.start = try readLeb(u32, reader);
                    try assertEnd(reader);
                },
                .element => {
                    for (try readVec(&parser.object.elements, reader, gpa)) |*elem| {
                        elem.table_index = try readLeb(u32, reader);
                        elem.offset = try readInit(reader);

                        for (try readVec(&elem.func_indexes, reader, gpa)) |*idx| {
                            idx.* = try readLeb(u32, reader);
                        }
                    }
                    try assertEnd(reader);
                },
                .code => {
                    const start = reader.context.bytes_left;
                    var index: u32 = 0;
                    const count = try readLeb(u32, reader);
                    const imported_function_count = parser.object.imported_functions_count;
                    var relocatable_data = try std.ArrayList(RelocatableData).initCapacity(gpa, count);
                    defer relocatable_data.deinit();
                    while (index < count) : (index += 1) {
                        const code_len = try readLeb(u32, reader);
                        const offset = @as(u32, @intCast(start - reader.context.bytes_left));
                        const data = try gpa.alloc(u8, code_len);
                        errdefer gpa.free(data);
                        try reader.readNoEof(data);
                        relocatable_data.appendAssumeCapacity(.{
                            .type = .code,
                            .data = data.ptr,
                            .size = code_len,
                            .index = imported_function_count + index,
                            .offset = offset,
                            .section_index = section_index,
                        });
                    }
                    try parser.object.relocatable_data.put(gpa, .code, try relocatable_data.toOwnedSlice());
                },
                .data => {
                    const start = reader.context.bytes_left;
                    var index: u32 = 0;
                    const count = try readLeb(u32, reader);
                    var relocatable_data = try std.ArrayList(RelocatableData).initCapacity(gpa, count);
                    defer relocatable_data.deinit();
                    while (index < count) : (index += 1) {
                        const flags = try readLeb(u32, reader);
                        const data_offset = try readInit(reader);
                        _ = flags; // TODO: Do we need to check flags to detect passive/active memory?
                        _ = data_offset;
                        const data_len = try readLeb(u32, reader);
                        const offset = @as(u32, @intCast(start - reader.context.bytes_left));
                        const data = try gpa.alloc(u8, data_len);
                        errdefer gpa.free(data);
                        try reader.readNoEof(data);
                        relocatable_data.appendAssumeCapacity(.{
                            .type = .data,
                            .data = data.ptr,
                            .size = data_len,
                            .index = index,
                            .offset = offset,
                            .section_index = section_index,
                        });
                    }
                    try parser.object.relocatable_data.put(gpa, .data, try relocatable_data.toOwnedSlice());
                },
                else => try parser.reader.reader().skipBytes(len, .{}),
            }
        } else |err| switch (err) {
            error.EndOfStream => {}, // finished parsing the file
            else => |e| return e,
        }
        if (!saw_linking_section) return error.MissingLinkingSection;
    }

    /// Based on the "features" custom section, parses it into a list of
    /// features that tell the linker what features were enabled and may be mandatory
    /// to be able to link.
    /// Logs an info message when an undefined feature is detected.
    fn parseFeatures(parser: *Parser, gpa: Allocator) !void {
        const diags = &parser.wasm.base.comp.link_diags;
        const reader = parser.reader.reader();
        for (try readVec(&parser.object.features, reader, gpa)) |*feature| {
            const prefix = try readEnum(Wasm.Feature.Prefix, reader);
            const name_len = try leb.readUleb128(u32, reader);
            const name = try gpa.alloc(u8, name_len);
            defer gpa.free(name);
            try reader.readNoEof(name);

            const tag = Wasm.known_features.get(name) orelse {
                return diags.failParse(parser.object.path, "object file contains unknown feature: {s}", .{name});
            };
            feature.* = .{
                .prefix = prefix,
                .tag = tag,
            };
        }
    }

    /// Parses a "reloc" custom section into a list of relocations.
    /// The relocations are mapped into `Object` where the key is the section
    /// they apply to.
    fn parseRelocations(parser: *Parser, gpa: Allocator) !void {
        const reader = parser.reader.reader();
        const section = try leb.readUleb128(u32, reader);
        const count = try leb.readUleb128(u32, reader);
        const relocations = try gpa.alloc(Wasm.Relocation, count);
        errdefer gpa.free(relocations);

        log.debug("Found {d} relocations for section ({d})", .{
            count,
            section,
        });

        for (relocations) |*relocation| {
            const rel_type = try reader.readByte();
            const rel_type_enum = std.meta.intToEnum(Wasm.Relocation.RelocationType, rel_type) catch return error.MalformedSection;
            relocation.* = .{
                .relocation_type = rel_type_enum,
                .offset = try leb.readUleb128(u32, reader),
                .index = try leb.readUleb128(u32, reader),
                .addend = if (rel_type_enum.addendIsPresent()) try leb.readIleb128(i32, reader) else 0,
            };
            log.debug("Found relocation: type({s}) offset({d}) index({d}) addend({?d})", .{
                @tagName(relocation.relocation_type),
                relocation.offset,
                relocation.index,
                relocation.addend,
            });
        }

        try parser.object.relocations.putNoClobber(gpa, section, relocations);
    }

    /// Parses the "linking" custom section. Versions that are not
    /// supported will be an error. `payload_size` is required to be able
    /// to calculate the subsections we need to parse, as that data is not
    /// available within the section itparser.
    fn parseMetadata(parser: *Parser, gpa: Allocator, payload_size: usize) !void {
        var limited = std.io.limitedReader(parser.reader.reader(), payload_size);
        const limited_reader = limited.reader();

        const version = try leb.readUleb128(u32, limited_reader);
        log.debug("Link meta data version: {d}", .{version});
        if (version != 2) return error.UnsupportedVersion;

        while (limited.bytes_left > 0) {
            try parser.parseSubsection(gpa, limited_reader);
        }
    }

    /// Parses a `spec.Subsection`.
    /// The `reader` param for this is to provide a `LimitedReader`, which allows
    /// us to only read until a max length.
    ///
    /// `parser` is used to provide access to other sections that may be needed,
    /// such as access to the `import` section to find the name of a symbol.
    fn parseSubsection(parser: *Parser, gpa: Allocator, reader: anytype) !void {
        const wasm = parser.wasm;
        const sub_type = try leb.readUleb128(u8, reader);
        log.debug("Found subsection: {s}", .{@tagName(@as(Wasm.SubsectionType, @enumFromInt(sub_type)))});
        const payload_len = try leb.readUleb128(u32, reader);
        if (payload_len == 0) return;

        var limited = std.io.limitedReader(reader, payload_len);
        const limited_reader = limited.reader();

        // every subsection contains a 'count' field
        const count = try leb.readUleb128(u32, limited_reader);

        switch (@as(Wasm.SubsectionType, @enumFromInt(sub_type))) {
            .WASM_SEGMENT_INFO => {
                const segments = try gpa.alloc(Wasm.NamedSegment, count);
                errdefer gpa.free(segments);
                for (segments) |*segment| {
                    const name_len = try leb.readUleb128(u32, reader);
                    const name = try gpa.alloc(u8, name_len);
                    errdefer gpa.free(name);
                    try reader.readNoEof(name);
                    segment.* = .{
                        .name = name,
                        .alignment = @enumFromInt(try leb.readUleb128(u32, reader)),
                        .flags = try leb.readUleb128(u32, reader),
                    };
                    log.debug("Found segment: {s} align({d}) flags({b})", .{
                        segment.name,
                        segment.alignment,
                        segment.flags,
                    });

                    // support legacy object files that specified being TLS by the name instead of the TLS flag.
                    if (!segment.isTLS() and (std.mem.startsWith(u8, segment.name, ".tdata") or std.mem.startsWith(u8, segment.name, ".tbss"))) {
                        // set the flag so we can simply check for the flag in the rest of the linker.
                        segment.flags |= @intFromEnum(Wasm.NamedSegment.Flags.WASM_SEG_FLAG_TLS);
                    }
                }
                parser.object.segment_info = segments;
            },
            .WASM_INIT_FUNCS => {
                const funcs = try gpa.alloc(Wasm.InitFunc, count);
                errdefer gpa.free(funcs);
                for (funcs) |*func| {
                    func.* = .{
                        .priority = try leb.readUleb128(u32, reader),
                        .symbol_index = try leb.readUleb128(u32, reader),
                    };
                    log.debug("Found function - prio: {d}, index: {d}", .{ func.priority, func.symbol_index });
                }
                parser.object.init_funcs = funcs;
            },
            .WASM_COMDAT_INFO => {
                const comdats = try gpa.alloc(Wasm.Comdat, count);
                errdefer gpa.free(comdats);
                for (comdats) |*comdat| {
                    const name_len = try leb.readUleb128(u32, reader);
                    const name = try gpa.alloc(u8, name_len);
                    errdefer gpa.free(name);
                    try reader.readNoEof(name);

                    const flags = try leb.readUleb128(u32, reader);
                    if (flags != 0) {
                        return error.UnexpectedValue;
                    }

                    const symbol_count = try leb.readUleb128(u32, reader);
                    const symbols = try gpa.alloc(Wasm.ComdatSym, symbol_count);
                    errdefer gpa.free(symbols);
                    for (symbols) |*symbol| {
                        symbol.* = .{
                            .kind = @as(Wasm.ComdatSym.Type, @enumFromInt(try leb.readUleb128(u8, reader))),
                            .index = try leb.readUleb128(u32, reader),
                        };
                    }

                    comdat.* = .{
                        .name = name,
                        .flags = flags,
                        .symbols = symbols,
                    };
                }

                parser.object.comdat_info = comdats;
            },
            .WASM_SYMBOL_TABLE => {
                var symbols = try std.ArrayList(Symbol).initCapacity(gpa, count);

                var i: usize = 0;
                while (i < count) : (i += 1) {
                    const symbol = symbols.addOneAssumeCapacity();
                    symbol.* = try parser.parseSymbol(gpa, reader);
                    log.debug("Found symbol: type({s}) name({s}) flags(0b{b:0>8})", .{
                        @tagName(symbol.tag),
                        wasm.stringSlice(symbol.name),
                        symbol.flags,
                    });
                }

                // we found all symbols, check for indirect function table
                // in case of an MVP object file
                if (try parser.object.checkLegacyIndirectFunctionTable(parser.wasm)) |symbol| {
                    try symbols.append(symbol);
                    log.debug("Found legacy indirect function table. Created symbol", .{});
                }

                // Not all debug sections may be represented by a symbol, for those sections
                // we manually create a symbol.
                if (parser.object.relocatable_data.get(.custom)) |custom_sections| {
                    for (custom_sections) |*data| {
                        if (!data.represented) {
                            const name = wasm.castToString(data.index);
                            try symbols.append(.{
                                .name = name,
                                .flags = @intFromEnum(Symbol.Flag.WASM_SYM_BINDING_LOCAL),
                                .tag = .section,
                                .virtual_address = 0,
                                .index = data.section_index,
                            });
                            data.represented = true;
                            log.debug("Created synthetic custom section symbol for '{s}'", .{
                                wasm.stringSlice(name),
                            });
                        }
                    }
                }

                parser.object.symtable = try symbols.toOwnedSlice();
            },
        }
    }

    /// Parses the symbol information based on its kind,
    /// requires access to `Object` to find the name of a symbol when it's
    /// an import and flag `WASM_SYM_EXPLICIT_NAME` is not set.
    fn parseSymbol(parser: *Parser, gpa: Allocator, reader: anytype) !Symbol {
        const wasm = parser.wasm;
        const tag: Symbol.Tag = @enumFromInt(try leb.readUleb128(u8, reader));
        const flags = try leb.readUleb128(u32, reader);
        var symbol: Symbol = .{
            .flags = flags,
            .tag = tag,
            .name = undefined,
            .index = undefined,
            .virtual_address = undefined,
        };

        switch (tag) {
            .data => {
                const name_len = try leb.readUleb128(u32, reader);
                const name = try gpa.alloc(u8, name_len);
                defer gpa.free(name);
                try reader.readNoEof(name);
                symbol.name = try wasm.internString(name);

                // Data symbols only have the following fields if the symbol is defined
                if (symbol.isDefined()) {
                    symbol.index = try leb.readUleb128(u32, reader);
                    // @TODO: We should verify those values
                    _ = try leb.readUleb128(u32, reader);
                    _ = try leb.readUleb128(u32, reader);
                }
            },
            .section => {
                symbol.index = try leb.readUleb128(u32, reader);
                const section_data = parser.object.relocatable_data.get(.custom).?;
                for (section_data) |*data| {
                    if (data.section_index == symbol.index) {
                        symbol.name = wasm.castToString(data.index);
                        data.represented = true;
                        break;
                    }
                }
            },
            else => {
                symbol.index = try leb.readUleb128(u32, reader);
                const is_undefined = symbol.isUndefined();
                const explicit_name = symbol.hasFlag(.WASM_SYM_EXPLICIT_NAME);
                symbol.name = if (!is_undefined or (is_undefined and explicit_name)) name: {
                    const name_len = try leb.readUleb128(u32, reader);
                    const name = try gpa.alloc(u8, name_len);
                    defer gpa.free(name);
                    try reader.readNoEof(name);
                    break :name try wasm.internString(name);
                } else parser.object.findImport(symbol).name;
            },
        }
        return symbol;
    }
};

/// First reads the count from the reader and then allocate
/// a slice of ptr child's element type.
fn readVec(ptr: anytype, reader: anytype, gpa: Allocator) ![]ElementType(@TypeOf(ptr)) {
    const len = try readLeb(u32, reader);
    const slice = try gpa.alloc(ElementType(@TypeOf(ptr)), len);
    ptr.* = slice;
    return slice;
}

fn ElementType(comptime ptr: type) type {
    return meta.Elem(meta.Child(ptr));
}

/// Uses either `readIleb128` or `readUleb128` depending on the
/// signedness of the given type `T`.
/// Asserts `T` is an integer.
fn readLeb(comptime T: type, reader: anytype) !T {
    return switch (@typeInfo(T).int.signedness) {
        .signed => try leb.readIleb128(T, reader),
        .unsigned => try leb.readUleb128(T, reader),
    };
}

/// Reads an enum type from the given reader.
/// Asserts `T` is an enum
fn readEnum(comptime T: type, reader: anytype) !T {
    switch (@typeInfo(T)) {
        .@"enum" => |enum_type| return @as(T, @enumFromInt(try readLeb(enum_type.tag_type, reader))),
        else => @compileError("T must be an enum. Instead was given type " ++ @typeName(T)),
    }
}

fn readLimits(reader: anytype) !std.wasm.Limits {
    const flags = try reader.readByte();
    const min = try readLeb(u32, reader);
    var limits: std.wasm.Limits = .{
        .flags = flags,
        .min = min,
        .max = undefined,
    };
    if (limits.hasFlag(.WASM_LIMITS_FLAG_HAS_MAX)) {
        limits.max = try readLeb(u32, reader);
    }
    return limits;
}

fn readInit(reader: anytype) !std.wasm.InitExpression {
    const opcode = try reader.readByte();
    const init_expr: std.wasm.InitExpression = switch (@as(std.wasm.Opcode, @enumFromInt(opcode))) {
        .i32_const => .{ .i32_const = try readLeb(i32, reader) },
        .global_get => .{ .global_get = try readLeb(u32, reader) },
        else => @panic("TODO: initexpression for other opcodes"),
    };

    if ((try readEnum(std.wasm.Opcode, reader)) != .end) return error.MissingEndForExpression;
    return init_expr;
}

fn assertEnd(reader: anytype) !void {
    var buf: [1]u8 = undefined;
    const len = try reader.read(&buf);
    if (len != 0) return error.MalformedSection;
    if (reader.context.bytes_left != 0) return error.MalformedSection;
}
