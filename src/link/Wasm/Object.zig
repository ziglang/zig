//! Object represents a wasm object file. When initializing a new
//! `Object`, it will parse the contents of a given file handler, and verify
//! the data on correctness. The result can then be used by the linker.
const Object = @This();

const Atom = @import("Atom.zig");
const types = @import("types.zig");
const std = @import("std");
const Wasm = @import("../Wasm.zig");
const Symbol = @import("Symbol.zig");

const Allocator = std.mem.Allocator;
const leb = std.leb;
const meta = std.meta;

const log = std.log.scoped(.link);

/// Wasm spec version used for this `Object`
version: u32 = 0,
/// The file descriptor that represents the wasm object file.
file: ?std.fs.File = null,
/// Name (read path) of the object file.
name: []const u8,
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
relocations: std.AutoArrayHashMapUnmanaged(u32, []types.Relocation) = .{},
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
relocatable_data: []const RelocatableData = &.{},
/// String table for all strings required by the object file, such as symbol names,
/// import name, module name and export names. Each string will be deduplicated
/// and returns an offset into the table.
string_table: Wasm.StringTable = .{},

/// Represents a single item within a section (depending on its `type`)
const RelocatableData = struct {
    /// The type of the relocatable data
    type: enum { data, code, custom },
    /// Pointer to the data of the segment, where its length is written to `size`
    data: [*]u8,
    /// The size in bytes of the data representing the segment within the section
    size: u32,
    /// The index within the section itself
    index: u32,
    /// The offset within the section where the data starts
    offset: u32,
    /// Represents the index of the section it belongs to
    section_index: u32,

    /// Returns the alignment of the segment, by retrieving it from the segment
    /// meta data of the given object file.
    /// NOTE: Alignment is encoded as a power of 2, so we shift the symbol's
    /// alignment to retrieve the natural alignment.
    pub fn getAlignment(self: RelocatableData, object: *const Object) u32 {
        if (self.type != .data) return 1;
        const data_alignment = object.segment_info[self.index].alignment;
        if (data_alignment == 0) return 1;
        // Decode from power of 2 to natural alignment
        return @as(u32, 1) << @intCast(u5, data_alignment);
    }

    /// Returns the symbol kind that corresponds to the relocatable section
    pub fn getSymbolKind(self: RelocatableData) Symbol.Tag {
        return switch (self.type) {
            .data => .data,
            .code => .function,
            .custom => .section,
        };
    }
};

pub const InitError = error{NotObjectFile} || ParseError || std.fs.File.ReadError;

/// Initializes a new `Object` from a wasm object file.
/// This also parses and verifies the object file.
pub fn create(gpa: Allocator, file: std.fs.File, name: []const u8) InitError!Object {
    var object: Object = .{
        .file = file,
        .name = try gpa.dupe(u8, name),
    };

    var is_object_file: bool = false;
    try object.parse(gpa, file.reader(), &is_object_file);
    errdefer object.deinit(gpa);
    if (!is_object_file) return error.NotObjectFile;

    return object;
}

/// Frees all memory of `Object` at once. The given `Allocator` must be
/// the same allocator that was used when `init` was called.
pub fn deinit(self: *Object, gpa: Allocator) void {
    for (self.func_types) |func_ty| {
        gpa.free(func_ty.params);
        gpa.free(func_ty.returns);
    }
    gpa.free(self.func_types);
    gpa.free(self.functions);
    gpa.free(self.imports);
    gpa.free(self.tables);
    gpa.free(self.memories);
    gpa.free(self.globals);
    gpa.free(self.exports);
    for (self.elements) |el| {
        gpa.free(el.func_indexes);
    }
    gpa.free(self.elements);
    gpa.free(self.features);
    for (self.relocations.values()) |val| {
        gpa.free(val);
    }
    self.relocations.deinit(gpa);
    gpa.free(self.symtable);
    gpa.free(self.comdat_info);
    gpa.free(self.init_funcs);
    for (self.segment_info) |info| {
        gpa.free(info.name);
    }
    gpa.free(self.segment_info);
    for (self.relocatable_data) |rel_data| {
        gpa.free(rel_data.data[0..rel_data.size]);
    }
    gpa.free(self.relocatable_data);
    self.string_table.deinit(gpa);
    gpa.free(self.name);
    self.* = undefined;
}

/// Finds the import within the list of imports from a given kind and index of that kind.
/// Asserts the import exists
pub fn findImport(self: *const Object, import_kind: std.wasm.ExternalKind, index: u32) types.Import {
    var i: u32 = 0;
    return for (self.imports) |import| {
        if (std.meta.activeTag(import.kind) == import_kind) {
            if (i == index) return import;
            i += 1;
        }
    } else unreachable; // Only existing imports are allowed to be found
}

/// Counts the entries of imported `kind` and returns the result
pub fn importedCountByKind(self: *const Object, kind: std.wasm.ExternalKind) u32 {
    var i: u32 = 0;
    return for (self.imports) |imp| {
        if (@as(std.wasm.ExternalKind, imp.kind) == kind) i += 1;
    } else i;
}

/// Checks if the object file is an MVP version.
/// When that's the case, we check if there's an import table definiton with its name
/// set to '__indirect_function_table". When that's also the case,
/// we initialize a new table symbol that corresponds to that import and return that symbol.
///
/// When the object file is *NOT* MVP, we return `null`.
fn checkLegacyIndirectFunctionTable(self: *Object) !?Symbol {
    var table_count: usize = 0;
    for (self.symtable) |sym| {
        if (sym.tag == .table) table_count += 1;
    }

    const import_table_count = self.importedCountByKind(.table);

    // For each import table, we also have a symbol so this is not a legacy object file
    if (import_table_count == table_count) return null;

    if (table_count != 0) {
        log.err("Expected a table entry symbol for each of the {d} table(s), but instead got {d} symbols.", .{
            import_table_count,
            table_count,
        });
        return error.MissingTableSymbols;
    }

    // MVP object files cannot have any table definitions, only imports (for the indirect function table).
    if (self.tables.len > 0) {
        log.err("Unexpected table definition without representing table symbols.", .{});
        return error.UnexpectedTable;
    }

    if (import_table_count != 1) {
        log.err("Found more than one table import, but no representing table symbols", .{});
        return error.MissingTableSymbols;
    }

    var table_import: types.Import = for (self.imports) |imp| {
        if (imp.kind == .table) {
            break imp;
        }
    } else unreachable;

    if (!std.mem.eql(u8, self.string_table.get(table_import.name), "__indirect_function_table")) {
        log.err("Non-indirect function table import '{s}' is missing a corresponding symbol", .{self.string_table.get(table_import.name)});
        return error.MissingTableSymbols;
    }

    var table_symbol: Symbol = .{
        .flags = 0,
        .name = table_import.name,
        .tag = .table,
        .index = 0,
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
    /// Did not expect a table definiton, but did find one
    UnexpectedTable,
    /// Object file contains a feature that is unknown to the linker
    UnknownFeature,
};

fn parse(self: *Object, gpa: Allocator, reader: anytype, is_object_file: *bool) Parser(@TypeOf(reader)).Error!void {
    var parser = Parser(@TypeOf(reader)).init(self, reader);
    return parser.parseObject(gpa, is_object_file);
}

fn Parser(comptime ReaderType: type) type {
    return struct {
        const Self = @This();
        const Error = ReaderType.Error || ParseError;

        reader: std.io.CountingReader(ReaderType),
        /// Object file we're building
        object: *Object,

        fn init(object: *Object, reader: ReaderType) Self {
            return .{ .object = object, .reader = std.io.countingReader(reader) };
        }

        /// Verifies that the first 4 bytes contains \0Asm
        fn verifyMagicBytes(self: *Self) Error!void {
            var magic_bytes: [4]u8 = undefined;

            try self.reader.reader().readNoEof(&magic_bytes);
            if (!std.mem.eql(u8, &magic_bytes, &std.wasm.magic)) {
                log.debug("Invalid magic bytes '{s}'", .{&magic_bytes});
                return error.InvalidMagicByte;
            }
        }

        fn parseObject(self: *Self, gpa: Allocator, is_object_file: *bool) Error!void {
            errdefer self.object.deinit(gpa);
            try self.verifyMagicBytes();
            const version = try self.reader.reader().readIntLittle(u32);

            self.object.version = version;
            var relocatable_data = std.ArrayList(RelocatableData).init(gpa);

            errdefer while (relocatable_data.popOrNull()) |rel_data| {
                gpa.free(rel_data.data[0..rel_data.size]);
            } else relocatable_data.deinit();

            var section_index: u32 = 0;
            while (self.reader.reader().readByte()) |byte| : (section_index += 1) {
                const len = try readLeb(u32, self.reader.reader());
                var limited_reader = std.io.limitedReader(self.reader.reader(), len);
                const reader = limited_reader.reader();
                switch (@intToEnum(std.wasm.Section, byte)) {
                    .custom => {
                        const name_len = try readLeb(u32, reader);
                        const name = try gpa.alloc(u8, name_len);
                        defer gpa.free(name);
                        try reader.readNoEof(name);

                        if (std.mem.eql(u8, name, "linking")) {
                            is_object_file.* = true;
                            try self.parseMetadata(gpa, @intCast(usize, reader.context.bytes_left));
                        } else if (std.mem.startsWith(u8, name, "reloc")) {
                            try self.parseRelocations(gpa);
                        } else if (std.mem.eql(u8, name, "target_features")) {
                            try self.parseFeatures(gpa);
                        } else {
                            try reader.skipBytes(reader.context.bytes_left, .{});
                        }
                    },
                    .type => {
                        for (try readVec(&self.object.func_types, reader, gpa)) |*type_val| {
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
                        for (try readVec(&self.object.imports, reader, gpa)) |*import| {
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
                                .function => .{ .function = try readLeb(u32, reader) },
                                .memory => .{ .memory = try readLimits(reader) },
                                .global => .{ .global = .{
                                    .valtype = try readEnum(std.wasm.Valtype, reader),
                                    .mutable = (try reader.readByte()) == 0x01,
                                } },
                                .table => .{ .table = .{
                                    .reftype = try readEnum(std.wasm.RefType, reader),
                                    .limits = try readLimits(reader),
                                } },
                            };

                            import.* = .{
                                .module_name = try self.object.string_table.put(gpa, module_name),
                                .name = try self.object.string_table.put(gpa, name),
                                .kind = kind_value,
                            };
                        }
                        try assertEnd(reader);
                    },
                    .function => {
                        for (try readVec(&self.object.functions, reader, gpa)) |*func| {
                            func.* = .{ .type_index = try readLeb(u32, reader) };
                        }
                        try assertEnd(reader);
                    },
                    .table => {
                        for (try readVec(&self.object.tables, reader, gpa)) |*table| {
                            table.* = .{
                                .reftype = try readEnum(std.wasm.RefType, reader),
                                .limits = try readLimits(reader),
                            };
                        }
                        try assertEnd(reader);
                    },
                    .memory => {
                        for (try readVec(&self.object.memories, reader, gpa)) |*memory| {
                            memory.* = .{ .limits = try readLimits(reader) };
                        }
                        try assertEnd(reader);
                    },
                    .global => {
                        for (try readVec(&self.object.globals, reader, gpa)) |*global| {
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
                        for (try readVec(&self.object.exports, reader, gpa)) |*exp| {
                            const name_len = try readLeb(u32, reader);
                            const name = try gpa.alloc(u8, name_len);
                            defer gpa.free(name);
                            try reader.readNoEof(name);
                            exp.* = .{
                                .name = try self.object.string_table.put(gpa, name),
                                .kind = try readEnum(std.wasm.ExternalKind, reader),
                                .index = try readLeb(u32, reader),
                            };
                        }
                        try assertEnd(reader);
                    },
                    .start => {
                        self.object.start = try readLeb(u32, reader);
                        try assertEnd(reader);
                    },
                    .element => {
                        for (try readVec(&self.object.elements, reader, gpa)) |*elem| {
                            elem.table_index = try readLeb(u32, reader);
                            elem.offset = try readInit(reader);

                            for (try readVec(&elem.func_indexes, reader, gpa)) |*idx| {
                                idx.* = try readLeb(u32, reader);
                            }
                        }
                        try assertEnd(reader);
                    },
                    .code => {
                        var start = reader.context.bytes_left;
                        var index: u32 = 0;
                        const count = try readLeb(u32, reader);
                        while (index < count) : (index += 1) {
                            const code_len = try readLeb(u32, reader);
                            const offset = @intCast(u32, start - reader.context.bytes_left);
                            const data = try gpa.alloc(u8, code_len);
                            errdefer gpa.free(data);
                            try reader.readNoEof(data);
                            try relocatable_data.append(.{
                                .type = .code,
                                .data = data.ptr,
                                .size = code_len,
                                .index = self.object.importedCountByKind(.function) + index,
                                .offset = offset,
                                .section_index = section_index,
                            });
                        }
                    },
                    .data => {
                        var start = reader.context.bytes_left;
                        var index: u32 = 0;
                        const count = try readLeb(u32, reader);
                        while (index < count) : (index += 1) {
                            const flags = try readLeb(u32, reader);
                            const data_offset = try readInit(reader);
                            _ = flags; // TODO: Do we need to check flags to detect passive/active memory?
                            _ = data_offset;
                            const data_len = try readLeb(u32, reader);
                            const offset = @intCast(u32, start - reader.context.bytes_left);
                            const data = try gpa.alloc(u8, data_len);
                            errdefer gpa.free(data);
                            try reader.readNoEof(data);
                            try relocatable_data.append(.{
                                .type = .data,
                                .data = data.ptr,
                                .size = data_len,
                                .index = index,
                                .offset = offset,
                                .section_index = section_index,
                            });
                        }
                    },
                    else => try self.reader.reader().skipBytes(len, .{}),
                }
            } else |err| switch (err) {
                error.EndOfStream => {}, // finished parsing the file
                else => |e| return e,
            }
            self.object.relocatable_data = relocatable_data.toOwnedSlice();
        }

        /// Based on the "features" custom section, parses it into a list of
        /// features that tell the linker what features were enabled and may be mandatory
        /// to be able to link.
        /// Logs an info message when an undefined feature is detected.
        fn parseFeatures(self: *Self, gpa: Allocator) !void {
            const reader = self.reader.reader();
            for (try readVec(&self.object.features, reader, gpa)) |*feature| {
                const prefix = try readEnum(types.Feature.Prefix, reader);
                const name_len = try leb.readULEB128(u32, reader);
                const name = try gpa.alloc(u8, name_len);
                defer gpa.free(name);
                try reader.readNoEof(name);

                const tag = types.known_features.get(name) orelse {
                    log.err("Object file contains unknown feature: {s}", .{name});
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
        fn parseRelocations(self: *Self, gpa: Allocator) !void {
            const reader = self.reader.reader();
            const section = try leb.readULEB128(u32, reader);
            const count = try leb.readULEB128(u32, reader);
            const relocations = try gpa.alloc(types.Relocation, count);
            errdefer gpa.free(relocations);

            log.debug("Found {d} relocations for section ({d})", .{
                count,
                section,
            });

            for (relocations) |*relocation| {
                const rel_type = try leb.readULEB128(u8, reader);
                const rel_type_enum = @intToEnum(types.Relocation.RelocationType, rel_type);
                relocation.* = .{
                    .relocation_type = rel_type_enum,
                    .offset = try leb.readULEB128(u32, reader),
                    .index = try leb.readULEB128(u32, reader),
                    .addend = if (rel_type_enum.addendIsPresent()) try leb.readULEB128(u32, reader) else null,
                };
                log.debug("Found relocation: type({s}) offset({d}) index({d}) addend({d})", .{
                    @tagName(relocation.relocation_type),
                    relocation.offset,
                    relocation.index,
                    relocation.addend,
                });
            }

            try self.object.relocations.putNoClobber(gpa, section, relocations);
        }

        /// Parses the "linking" custom section. Versions that are not
        /// supported will be an error. `payload_size` is required to be able
        /// to calculate the subsections we need to parse, as that data is not
        /// available within the section itself.
        fn parseMetadata(self: *Self, gpa: Allocator, payload_size: usize) !void {
            var limited = std.io.limitedReader(self.reader.reader(), payload_size);
            const limited_reader = limited.reader();

            const version = try leb.readULEB128(u32, limited_reader);
            log.debug("Link meta data version: {d}", .{version});
            if (version != 2) return error.UnsupportedVersion;

            while (limited.bytes_left > 0) {
                try self.parseSubsection(gpa, limited_reader);
            }
        }

        /// Parses a `spec.Subsection`.
        /// The `reader` param for this is to provide a `LimitedReader`, which allows
        /// us to only read until a max length.
        ///
        /// `self` is used to provide access to other sections that may be needed,
        /// such as access to the `import` section to find the name of a symbol.
        fn parseSubsection(self: *Self, gpa: Allocator, reader: anytype) !void {
            const sub_type = try leb.readULEB128(u8, reader);
            log.debug("Found subsection: {s}", .{@tagName(@intToEnum(types.SubsectionType, sub_type))});
            const payload_len = try leb.readULEB128(u32, reader);
            if (payload_len == 0) return;

            var limited = std.io.limitedReader(reader, payload_len);
            const limited_reader = limited.reader();

            // every subsection contains a 'count' field
            const count = try leb.readULEB128(u32, limited_reader);

            switch (@intToEnum(types.SubsectionType, sub_type)) {
                .WASM_SEGMENT_INFO => {
                    const segments = try gpa.alloc(types.Segment, count);
                    errdefer gpa.free(segments);
                    for (segments) |*segment| {
                        const name_len = try leb.readULEB128(u32, reader);
                        const name = try gpa.alloc(u8, name_len);
                        errdefer gpa.free(name);
                        try reader.readNoEof(name);
                        segment.* = .{
                            .name = name,
                            .alignment = try leb.readULEB128(u32, reader),
                            .flags = try leb.readULEB128(u32, reader),
                        };
                        log.debug("Found segment: {s} align({d}) flags({b})", .{
                            segment.name,
                            segment.alignment,
                            segment.flags,
                        });
                    }
                    self.object.segment_info = segments;
                },
                .WASM_INIT_FUNCS => {
                    const funcs = try gpa.alloc(types.InitFunc, count);
                    errdefer gpa.free(funcs);
                    for (funcs) |*func| {
                        func.* = .{
                            .priority = try leb.readULEB128(u32, reader),
                            .symbol_index = try leb.readULEB128(u32, reader),
                        };
                        log.debug("Found function - prio: {d}, index: {d}", .{ func.priority, func.symbol_index });
                    }
                    self.object.init_funcs = funcs;
                },
                .WASM_COMDAT_INFO => {
                    const comdats = try gpa.alloc(types.Comdat, count);
                    errdefer gpa.free(comdats);
                    for (comdats) |*comdat| {
                        const name_len = try leb.readULEB128(u32, reader);
                        const name = try gpa.alloc(u8, name_len);
                        errdefer gpa.free(name);
                        try reader.readNoEof(name);

                        const flags = try leb.readULEB128(u32, reader);
                        if (flags != 0) {
                            return error.UnexpectedValue;
                        }

                        const symbol_count = try leb.readULEB128(u32, reader);
                        const symbols = try gpa.alloc(types.ComdatSym, symbol_count);
                        errdefer gpa.free(symbols);
                        for (symbols) |*symbol| {
                            symbol.* = .{
                                .kind = @intToEnum(types.ComdatSym.Type, try leb.readULEB128(u8, reader)),
                                .index = try leb.readULEB128(u32, reader),
                            };
                        }

                        comdat.* = .{
                            .name = name,
                            .flags = flags,
                            .symbols = symbols,
                        };
                    }

                    self.object.comdat_info = comdats;
                },
                .WASM_SYMBOL_TABLE => {
                    var symbols = try std.ArrayList(Symbol).initCapacity(gpa, count);

                    var i: usize = 0;
                    while (i < count) : (i += 1) {
                        const symbol = symbols.addOneAssumeCapacity();
                        symbol.* = try self.parseSymbol(gpa, reader);
                        log.debug("Found symbol: type({s}) name({s}) flags(0b{b:0>8})", .{
                            @tagName(symbol.tag),
                            self.object.string_table.get(symbol.name),
                            symbol.flags,
                        });
                    }

                    // we found all symbols, check for indirect function table
                    // in case of an MVP object file
                    if (try self.object.checkLegacyIndirectFunctionTable()) |symbol| {
                        try symbols.append(symbol);
                        log.debug("Found legacy indirect function table. Created symbol", .{});
                    }

                    self.object.symtable = symbols.toOwnedSlice();
                },
            }
        }

        /// Parses the symbol information based on its kind,
        /// requires access to `Object` to find the name of a symbol when it's
        /// an import and flag `WASM_SYM_EXPLICIT_NAME` is not set.
        fn parseSymbol(self: *Self, gpa: Allocator, reader: anytype) !Symbol {
            const tag = @intToEnum(Symbol.Tag, try leb.readULEB128(u8, reader));
            const flags = try leb.readULEB128(u32, reader);
            var symbol: Symbol = .{
                .flags = flags,
                .tag = tag,
                .name = undefined,
                .index = undefined,
            };

            switch (tag) {
                .data => {
                    const name_len = try leb.readULEB128(u32, reader);
                    const name = try gpa.alloc(u8, name_len);
                    defer gpa.free(name);
                    try reader.readNoEof(name);
                    symbol.name = try self.object.string_table.put(gpa, name);

                    // Data symbols only have the following fields if the symbol is defined
                    if (symbol.isDefined()) {
                        symbol.index = try leb.readULEB128(u32, reader);
                        // @TODO: We should verify those values
                        _ = try leb.readULEB128(u32, reader);
                        _ = try leb.readULEB128(u32, reader);
                    }
                },
                .section => {
                    symbol.index = try leb.readULEB128(u32, reader);
                    symbol.name = try self.object.string_table.put(gpa, @tagName(symbol.tag));
                },
                else => {
                    symbol.index = try leb.readULEB128(u32, reader);
                    var maybe_import: ?types.Import = null;

                    const is_undefined = symbol.isUndefined();
                    if (is_undefined) {
                        maybe_import = self.object.findImport(symbol.tag.externalType(), symbol.index);
                    }
                    const explicit_name = symbol.hasFlag(.WASM_SYM_EXPLICIT_NAME);
                    if (!(is_undefined and !explicit_name)) {
                        const name_len = try leb.readULEB128(u32, reader);
                        const name = try gpa.alloc(u8, name_len);
                        defer gpa.free(name);
                        try reader.readNoEof(name);
                        symbol.name = try self.object.string_table.put(gpa, name);
                    } else {
                        symbol.name = maybe_import.?.name;
                    }
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

/// Uses either `readILEB128` or `readULEB128` depending on the
/// signedness of the given type `T`.
/// Asserts `T` is an integer.
fn readLeb(comptime T: type, reader: anytype) !T {
    if (comptime std.meta.trait.isSignedInt(T)) {
        return try leb.readILEB128(T, reader);
    } else {
        return try leb.readULEB128(T, reader);
    }
}

/// Reads an enum type from the given reader.
/// Asserts `T` is an enum
fn readEnum(comptime T: type, reader: anytype) !T {
    switch (@typeInfo(T)) {
        .Enum => |enum_type| return @intToEnum(T, try readLeb(enum_type.tag_type, reader)),
        else => @compileError("T must be an enum. Instead was given type " ++ @typeName(T)),
    }
}

fn readLimits(reader: anytype) !std.wasm.Limits {
    const flags = try readLeb(u1, reader);
    const min = try readLeb(u32, reader);
    return std.wasm.Limits{
        .min = min,
        .max = if (flags == 0) null else try readLeb(u32, reader),
    };
}

fn readInit(reader: anytype) !std.wasm.InitExpression {
    const opcode = try reader.readByte();
    const init_expr: std.wasm.InitExpression = switch (@intToEnum(std.wasm.Opcode, opcode)) {
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
pub fn parseIntoAtoms(self: *Object, gpa: Allocator, object_index: u16, wasm_bin: *Wasm) !void {
    log.debug("Parsing data section into atoms", .{});
    const Key = struct {
        kind: Symbol.Tag,
        index: u32,
    };
    var symbol_for_segment = std.AutoArrayHashMap(Key, std.ArrayList(u32)).init(gpa);
    defer for (symbol_for_segment.values()) |*list| {
        list.deinit();
    } else symbol_for_segment.deinit();

    for (self.symtable) |symbol, symbol_index| {
        switch (symbol.tag) {
            .function, .data => if (!symbol.isUndefined()) {
                const gop = try symbol_for_segment.getOrPut(.{ .kind = symbol.tag, .index = symbol.index });
                const sym_idx = @intCast(u32, symbol_index);
                if (!gop.found_existing) {
                    gop.value_ptr.* = std.ArrayList(u32).init(gpa);
                }
                try gop.value_ptr.*.append(sym_idx);
            },
            else => continue,
        }
    }

    for (self.relocatable_data) |relocatable_data, index| {
        const symbols = symbol_for_segment.getPtr(.{
            .kind = relocatable_data.getSymbolKind(),
            .index = @intCast(u32, relocatable_data.index),
        }) orelse continue; // encountered a segment we do not create an atom for
        const sym_index = symbols.pop();
        const final_index = try wasm_bin.getMatchingSegment(object_index, @intCast(u32, index));

        const atom = try gpa.create(Atom);
        atom.* = Atom.empty;
        errdefer {
            atom.deinit(gpa);
            gpa.destroy(atom);
        }

        try wasm_bin.managed_atoms.append(gpa, atom);
        atom.file = object_index;
        atom.size = relocatable_data.size;
        atom.alignment = relocatable_data.getAlignment(self);
        atom.sym_index = sym_index;

        const relocations: []types.Relocation = self.relocations.get(relocatable_data.section_index) orelse &.{};
        for (relocations) |relocation| {
            if (isInbetween(relocatable_data.offset, atom.size, relocation.offset)) {
                // set the offset relative to the offset of the segment itself,
                // rather than within the entire section.
                var reloc = relocation;
                reloc.offset -= relocatable_data.offset;
                try atom.relocs.append(gpa, reloc);

                if (relocation.isTableIndex()) {
                    try wasm_bin.function_table.putNoClobber(gpa, .{
                        .file = object_index,
                        .index = relocation.index,
                    }, 0);
                }
            }
        }

        try atom.code.appendSlice(gpa, relocatable_data.data[0..relocatable_data.size]);

        // symbols referencing the same atom will be added as alias
        // or as 'parent' when they are global.
        while (symbols.popOrNull()) |idx| {
            const alias_symbol = self.symtable[idx];
            const symbol = self.symtable[atom.sym_index];
            if (alias_symbol.isGlobal() and symbol.isLocal()) {
                atom.sym_index = idx;
            }
        }
        try wasm_bin.symbol_atom.putNoClobber(gpa, atom.symbolLoc(), atom);

        const segment: *Wasm.Segment = &wasm_bin.segments.items[final_index];
        segment.alignment = std.math.max(segment.alignment, atom.alignment);

        if (wasm_bin.atoms.getPtr(final_index)) |last| {
            last.*.next = atom;
            atom.prev = last.*;
            last.* = atom;
        } else {
            try wasm_bin.atoms.putNoClobber(gpa, final_index, atom);
        }
        log.debug("Parsed into atom: '{s}'", .{self.string_table.get(self.symtable[atom.sym_index].name)});
    }
}

/// Verifies if a given value is in between a minimum -and maximum value.
/// The maxmimum value is calculated using the length, both start and end are inclusive.
inline fn isInbetween(min: u32, length: u32, value: u32) bool {
    return value >= min and value <= min + length;
}
