//! Object represents a wasm object file. When initializing a new
//! `Object`, it will parse the contents of a given file handler, and verify
//! the data on correctness. The result can then be used by the linker.
const Object = @This();

const Atom = @import("Atom.zig");
const types = @import("types.zig");
const std = @import("std");
const Wasm = @import("../Wasm.zig");
const Symbol = @import("Symbol.zig");
const Alignment = types.Alignment;
const File = @import("file.zig").File;

const Allocator = std.mem.Allocator;
const leb = std.leb;
const meta = std.meta;

const log = std.log.scoped(.object);

/// Index into the list of relocatable object files within the linker driver.
index: File.Index = .null,
/// Wasm spec version used for this `Object`
version: u32 = 0,
/// The file descriptor that represents the wasm object file.
file: ?std.fs.File = null,
/// Name (read path) of the object file.
path: []const u8,
/// Parsed type section
func_types: []const std.wasm.Type = &.{},
/// A list of all imports for this module
imports: []const types.Import = &.{},
/// Parsed function section
functions: []const std.wasm.Func = &.{},
/// Parsed table section
tables: []const std.wasm.Table = &.{},
/// Parsed memory section
memories: []const std.wasm.Memory = &.{},
/// Parsed global section
globals: []const std.wasm.Global = &.{},
/// Parsed export section
exports: []const types.Export = &.{},
/// Parsed element section
elements: []const std.wasm.Element = &.{},
/// Represents the function ID that must be called on startup.
/// This is `null` by default as runtimes may determine the startup
/// function themselves. This is essentially legacy.
start: ?u32 = null,
/// A slice of features that tell the linker what features are mandatory,
/// used (or therefore missing) and must generate an error when another
/// object uses features that are not supported by the other.
features: []const types.Feature = &.{},
/// A table that maps the relocations we must perform where the key represents
/// the section that the list of relocations applies to.
relocations: std.AutoArrayHashMapUnmanaged(u32, []types.Relocation) = .empty,
/// Table of symbols belonging to this Object file
symtable: []Symbol = &.{},
/// Extra metadata about the linking section, such as alignment of segments and their name
segment_info: []const types.Segment = &.{},
/// A sequence of function initializers that must be called on startup
init_funcs: []const types.InitFunc = &.{},
/// Comdat information
comdat_info: []const types.Comdat = &.{},
/// Represents non-synthetic sections that can essentially be mem-cpy'd into place
/// after performing relocations.
relocatable_data: std.AutoHashMapUnmanaged(RelocatableData.Tag, []RelocatableData) = .empty,
/// String table for all strings required by the object file, such as symbol names,
/// import name, module name and export names. Each string will be deduplicated
/// and returns an offset into the table.
string_table: Wasm.StringTable = .{},
/// Amount of functions in the `import` sections.
imported_functions_count: u32 = 0,
/// Amount of globals in the `import` section.
imported_globals_count: u32 = 0,
/// Amount of tables in the `import` section.
imported_tables_count: u32 = 0,

/// Represents a single item within a section (depending on its `type`)
const RelocatableData = struct {
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

pub const InitError = error{NotObjectFile} || ParseError || std.fs.File.ReadError;

/// Initializes a new `Object` from a wasm object file.
/// This also parses and verifies the object file.
/// When a max size is given, will only parse up to the given size,
/// else will read until the end of the file.
pub fn create(wasm_file: *const Wasm, file: std.fs.File, name: []const u8, maybe_max_size: ?usize) InitError!Object {
    const gpa = wasm_file.base.comp.gpa;
    var object: Object = .{
        .file = file,
        .path = try gpa.dupe(u8, name),
    };

    var is_object_file: bool = false;
    const size = maybe_max_size orelse size: {
        errdefer gpa.free(object.path);
        const stat = try file.stat();
        break :size @as(usize, @intCast(stat.size));
    };

    const file_contents = try gpa.alloc(u8, size);
    defer gpa.free(file_contents);
    var file_reader = file.reader();
    var read: usize = 0;
    while (read < size) {
        const n = try file_reader.read(file_contents[read..]);
        std.debug.assert(n != 0);
        read += n;
    }
    var fbs = std.io.fixedBufferStream(file_contents);

    try object.parse(gpa, wasm_file, fbs.reader(), &is_object_file);
    errdefer object.deinit(gpa);
    if (!is_object_file) return error.NotObjectFile;

    return object;
}

/// Frees all memory of `Object` at once. The given `Allocator` must be
/// the same allocator that was used when `init` was called.
pub fn deinit(object: *Object, gpa: Allocator) void {
    if (object.file) |file| {
        file.close();
    }
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
    object.string_table.deinit(gpa);
    gpa.free(object.path);
    object.* = undefined;
}

/// Finds the import within the list of imports from a given kind and index of that kind.
/// Asserts the import exists
pub fn findImport(object: *const Object, sym: Symbol) types.Import {
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
fn checkLegacyIndirectFunctionTable(object: *Object, wasm_file: *const Wasm) !?Symbol {
    const diags = &wasm_file.base.comp.link_diags;

    var table_count: usize = 0;
    for (object.symtable) |sym| {
        if (sym.tag == .table) table_count += 1;
    }

    // For each import table, we also have a symbol so this is not a legacy object file
    if (object.imported_tables_count == table_count) return null;

    if (table_count != 0) {
        var err = try diags.addErrorWithNotes(1);
        try err.addMsg("Expected a table entry symbol for each of the {d} table(s), but instead got {d} symbols.", .{
            object.imported_tables_count,
            table_count,
        });
        try err.addNote("defined in '{s}'", .{object.path});
        return error.MissingTableSymbols;
    }

    // MVP object files cannot have any table definitions, only imports (for the indirect function table).
    if (object.tables.len > 0) {
        var err = try diags.addErrorWithNotes(1);
        try err.addMsg("Unexpected table definition without representing table symbols.", .{});
        try err.addNote("defined in '{s}'", .{object.path});
        return error.UnexpectedTable;
    }

    if (object.imported_tables_count != 1) {
        var err = try diags.addErrorWithNotes(1);
        try err.addMsg("Found more than one table import, but no representing table symbols", .{});
        try err.addNote("defined in '{s}'", .{object.path});
        return error.MissingTableSymbols;
    }

    const table_import: types.Import = for (object.imports) |imp| {
        if (imp.kind == .table) {
            break imp;
        }
    } else unreachable;

    if (!std.mem.eql(u8, object.string_table.get(table_import.name), "__indirect_function_table")) {
        var err = try diags.addErrorWithNotes(1);
        try err.addMsg("Non-indirect function table import '{s}' is missing a corresponding symbol", .{object.string_table.get(table_import.name)});
        try err.addNote("defined in '{s}'", .{object.path});
        return error.MissingTableSymbols;
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

/// Error set containing parsing errors.
/// Merged with reader's errorset by `Parser`
pub const ParseError = error{
    /// The magic byte is either missing or does not contain \0Asm
    InvalidMagicByte,
    /// The wasm version is either missing or does not match the supported version.
    InvalidWasmVersion,
    /// Expected the functype byte while parsing the Type section but did not find it.
    ExpectedFuncType,
    /// Missing an 'end' opcode when defining a constant expression.
    MissingEndForExpression,
    /// Missing an 'end' opcode at the end of a body expression.
    MissingEndForBody,
    /// The size defined in the section code mismatches with the actual payload size.
    MalformedSection,
    /// Stream has reached the end. Unreachable for caller and must be handled internally
    /// by the parser.
    EndOfStream,
    /// Ran out of memory when allocating.
    OutOfMemory,
    /// A non-zero flag was provided for comdat info
    UnexpectedValue,
    /// An import symbol contains an index to an import that does
    /// not exist, or no imports were defined.
    InvalidIndex,
    /// The section "linking" contains a version that is not supported.
    UnsupportedVersion,
    /// When reading the data in leb128 compressed format, its value was overflown.
    Overflow,
    /// Found table definitions but no corresponding table symbols
    MissingTableSymbols,
    /// Did not expect a table definition, but did find one
    UnexpectedTable,
    /// Object file contains a feature that is unknown to the linker
    UnknownFeature,
};

fn parse(object: *Object, gpa: Allocator, wasm_file: *const Wasm, reader: anytype, is_object_file: *bool) Parser(@TypeOf(reader)).Error!void {
    var parser = Parser(@TypeOf(reader)).init(object, wasm_file, reader);
    return parser.parseObject(gpa, is_object_file);
}

fn Parser(comptime ReaderType: type) type {
    return struct {
        const ObjectParser = @This();
        const Error = ReaderType.Error || ParseError;

        reader: std.io.CountingReader(ReaderType),
        /// Object file we're building
        object: *Object,
        /// Read-only reference to the WebAssembly linker
        wasm_file: *const Wasm,

        fn init(object: *Object, wasm_file: *const Wasm, reader: ReaderType) ObjectParser {
            return .{ .object = object, .wasm_file = wasm_file, .reader = std.io.countingReader(reader) };
        }

        /// Verifies that the first 4 bytes contains \0Asm
        fn verifyMagicBytes(parser: *ObjectParser) Error!void {
            var magic_bytes: [4]u8 = undefined;

            try parser.reader.reader().readNoEof(&magic_bytes);
            if (!std.mem.eql(u8, &magic_bytes, &std.wasm.magic)) {
                log.debug("Invalid magic bytes '{s}'", .{&magic_bytes});
                return error.InvalidMagicByte;
            }
        }

        fn parseObject(parser: *ObjectParser, gpa: Allocator, is_object_file: *bool) Error!void {
            errdefer parser.object.deinit(gpa);
            try parser.verifyMagicBytes();
            const version = try parser.reader.reader().readInt(u32, .little);
            parser.object.version = version;

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
                            is_object_file.* = true;
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
                                .index = try parser.object.string_table.put(gpa, name),
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
                                .module_name = try parser.object.string_table.put(gpa, module_name),
                                .name = try parser.object.string_table.put(gpa, name),
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
                                .name = try parser.object.string_table.put(gpa, name),
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
        }

        /// Based on the "features" custom section, parses it into a list of
        /// features that tell the linker what features were enabled and may be mandatory
        /// to be able to link.
        /// Logs an info message when an undefined feature is detected.
        fn parseFeatures(parser: *ObjectParser, gpa: Allocator) !void {
            const diags = &parser.wasm_file.base.comp.link_diags;
            const reader = parser.reader.reader();
            for (try readVec(&parser.object.features, reader, gpa)) |*feature| {
                const prefix = try readEnum(types.Feature.Prefix, reader);
                const name_len = try leb.readUleb128(u32, reader);
                const name = try gpa.alloc(u8, name_len);
                defer gpa.free(name);
                try reader.readNoEof(name);

                const tag = types.known_features.get(name) orelse {
                    var err = try diags.addErrorWithNotes(1);
                    try err.addMsg("Object file contains unknown feature: {s}", .{name});
                    try err.addNote("defined in '{s}'", .{parser.object.path});
                    return error.UnknownFeature;
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
        fn parseRelocations(parser: *ObjectParser, gpa: Allocator) !void {
            const reader = parser.reader.reader();
            const section = try leb.readUleb128(u32, reader);
            const count = try leb.readUleb128(u32, reader);
            const relocations = try gpa.alloc(types.Relocation, count);
            errdefer gpa.free(relocations);

            log.debug("Found {d} relocations for section ({d})", .{
                count,
                section,
            });

            for (relocations) |*relocation| {
                const rel_type = try reader.readByte();
                const rel_type_enum = std.meta.intToEnum(types.Relocation.RelocationType, rel_type) catch return error.MalformedSection;
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
        fn parseMetadata(parser: *ObjectParser, gpa: Allocator, payload_size: usize) !void {
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
        fn parseSubsection(parser: *ObjectParser, gpa: Allocator, reader: anytype) !void {
            const sub_type = try leb.readUleb128(u8, reader);
            log.debug("Found subsection: {s}", .{@tagName(@as(types.SubsectionType, @enumFromInt(sub_type)))});
            const payload_len = try leb.readUleb128(u32, reader);
            if (payload_len == 0) return;

            var limited = std.io.limitedReader(reader, payload_len);
            const limited_reader = limited.reader();

            // every subsection contains a 'count' field
            const count = try leb.readUleb128(u32, limited_reader);

            switch (@as(types.SubsectionType, @enumFromInt(sub_type))) {
                .WASM_SEGMENT_INFO => {
                    const segments = try gpa.alloc(types.Segment, count);
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
                            segment.flags |= @intFromEnum(types.Segment.Flags.WASM_SEG_FLAG_TLS);
                        }
                    }
                    parser.object.segment_info = segments;
                },
                .WASM_INIT_FUNCS => {
                    const funcs = try gpa.alloc(types.InitFunc, count);
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
                    const comdats = try gpa.alloc(types.Comdat, count);
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
                        const symbols = try gpa.alloc(types.ComdatSym, symbol_count);
                        errdefer gpa.free(symbols);
                        for (symbols) |*symbol| {
                            symbol.* = .{
                                .kind = @as(types.ComdatSym.Type, @enumFromInt(try leb.readUleb128(u8, reader))),
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
                            parser.object.string_table.get(symbol.name),
                            symbol.flags,
                        });
                    }

                    // we found all symbols, check for indirect function table
                    // in case of an MVP object file
                    if (try parser.object.checkLegacyIndirectFunctionTable(parser.wasm_file)) |symbol| {
                        try symbols.append(symbol);
                        log.debug("Found legacy indirect function table. Created symbol", .{});
                    }

                    // Not all debug sections may be represented by a symbol, for those sections
                    // we manually create a symbol.
                    if (parser.object.relocatable_data.get(.custom)) |custom_sections| {
                        for (custom_sections) |*data| {
                            if (!data.represented) {
                                try symbols.append(.{
                                    .name = data.index,
                                    .flags = @intFromEnum(Symbol.Flag.WASM_SYM_BINDING_LOCAL),
                                    .tag = .section,
                                    .virtual_address = 0,
                                    .index = data.section_index,
                                });
                                data.represented = true;
                                log.debug("Created synthetic custom section symbol for '{s}'", .{parser.object.string_table.get(data.index)});
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
        fn parseSymbol(parser: *ObjectParser, gpa: Allocator, reader: anytype) !Symbol {
            const tag = @as(Symbol.Tag, @enumFromInt(try leb.readUleb128(u8, reader)));
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
                    symbol.name = try parser.object.string_table.put(gpa, name);

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
                            symbol.name = data.index;
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
                        break :name try parser.object.string_table.put(gpa, name);
                    } else parser.object.findImport(symbol).name;
                },
            }
            return symbol;
        }
    };
}

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

/// Parses an object file into atoms, for code and data sections
pub fn parseSymbolIntoAtom(object: *Object, wasm: *Wasm, symbol_index: Symbol.Index) !Atom.Index {
    const comp = wasm.base.comp;
    const gpa = comp.gpa;
    const symbol = &object.symtable[@intFromEnum(symbol_index)];
    const relocatable_data: RelocatableData = switch (symbol.tag) {
        .function => object.relocatable_data.get(.code).?[symbol.index - object.imported_functions_count],
        .data => object.relocatable_data.get(.data).?[symbol.index],
        .section => blk: {
            const data = object.relocatable_data.get(.custom).?;
            for (data) |dat| {
                if (dat.section_index == symbol.index) {
                    break :blk dat;
                }
            }
            unreachable;
        },
        else => unreachable,
    };
    const final_index = try wasm.getMatchingSegment(object.index, symbol_index);
    const atom_index = try wasm.createAtom(symbol_index, object.index);
    try wasm.appendAtomAtIndex(final_index, atom_index);

    const atom = wasm.getAtomPtr(atom_index);
    atom.size = relocatable_data.size;
    atom.alignment = relocatable_data.getAlignment(object);
    atom.code = std.ArrayListUnmanaged(u8).fromOwnedSlice(relocatable_data.data[0..relocatable_data.size]);
    atom.original_offset = relocatable_data.offset;

    const segment: *Wasm.Segment = &wasm.segments.items[final_index];
    if (relocatable_data.type == .data) { //code section and custom sections are 1-byte aligned
        segment.alignment = segment.alignment.max(atom.alignment);
    }

    if (object.relocations.get(relocatable_data.section_index)) |relocations| {
        const start = searchRelocStart(relocations, relocatable_data.offset);
        const len = searchRelocEnd(relocations[start..], relocatable_data.offset + atom.size);
        atom.relocs = std.ArrayListUnmanaged(types.Relocation).fromOwnedSlice(relocations[start..][0..len]);
        for (atom.relocs.items) |reloc| {
            switch (reloc.relocation_type) {
                .R_WASM_TABLE_INDEX_I32,
                .R_WASM_TABLE_INDEX_I64,
                .R_WASM_TABLE_INDEX_SLEB,
                .R_WASM_TABLE_INDEX_SLEB64,
                => {
                    try wasm.function_table.put(gpa, .{
                        .file = object.index,
                        .index = @enumFromInt(reloc.index),
                    }, 0);
                },
                .R_WASM_GLOBAL_INDEX_I32,
                .R_WASM_GLOBAL_INDEX_LEB,
                => {
                    const sym = object.symtable[reloc.index];
                    if (sym.tag != .global) {
                        try wasm.got_symbols.append(gpa, .{ .file = object.index, .index = @enumFromInt(reloc.index) });
                    }
                },
                else => {},
            }
        }
    }

    return atom_index;
}

fn searchRelocStart(relocs: []const types.Relocation, address: u32) usize {
    var min: usize = 0;
    var max: usize = relocs.len;
    while (min < max) {
        const index = (min + max) / 2;
        const curr = relocs[index];
        if (curr.offset < address) {
            min = index + 1;
        } else {
            max = index;
        }
    }
    return min;
}

fn searchRelocEnd(relocs: []const types.Relocation, address: u32) usize {
    for (relocs, 0..relocs.len) |reloc, index| {
        if (reloc.offset > address) {
            return index;
        }
    }
    return relocs.len;
}
