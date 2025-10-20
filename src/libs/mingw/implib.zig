const std = @import("std");
const def = @import("def.zig");
const Allocator = std.mem.Allocator;

// LLVM has some quirks/bugs around padding/size values.
// Emulating those quirks made it much easier to test this implementation against the LLVM
// implementation since we could just check if the .lib files are byte-for-byte identical.
// This remains set to true out of an abundance of caution.
const llvm_compat = true;

pub const WriteCoffArchiveError = error{TooManyMembers} || std.Io.Writer.Error || std.mem.Allocator.Error;

pub fn writeCoffArchive(
    allocator: std.mem.Allocator,
    writer: *std.Io.Writer,
    members: Members,
) WriteCoffArchiveError!void {
    // The second linker member of a COFF archive uses a 32-bit integer for the number of members field,
    // but only 16-bit integers for the "array of 1-based indexes that map symbol names to archive
    // member offsets." This means that the maximum number of *indexable* members is maxInt(u16) - 1.
    if (members.list.items.len > std.math.maxInt(u16) - 1) return error.TooManyMembers;

    try writer.writeAll(archive_start);

    const member_offsets = try allocator.alloc(usize, members.list.items.len);
    defer allocator.free(member_offsets);
    {
        var offset: usize = 0;
        for (member_offsets, 0..) |*elem, i| {
            elem.* = offset;
            offset += archive_header_len;
            offset += members.list.items[i].byteLenWithPadding();
        }
    }

    var long_names: StringTable = .{};
    defer long_names.deinit(allocator);

    var symbol_to_member_index = std.StringArrayHashMap(usize).init(allocator);
    defer symbol_to_member_index.deinit();
    var string_table_len: usize = 0;
    var num_symbols: usize = 0;

    for (members.list.items, 0..) |member, i| {
        for (member.symbol_names_for_import_lib) |symbol_name| {
            const gop_result = try symbol_to_member_index.getOrPut(symbol_name);
            // When building the symbol map, ignore duplicate symbol names.
            // This can happen in cases like (using .def file syntax):
            //  _foo
            //  foo == _foo
            if (gop_result.found_existing) continue;

            gop_result.value_ptr.* = i;
            string_table_len += symbol_name.len + 1;
            num_symbols += 1;
        }

        if (member.needsLongName()) {
            _ = try long_names.put(allocator, member.name);
        }
    }

    const first_linker_member_len = 4 + (4 * num_symbols) + string_table_len;
    const second_linker_member_len = 4 + (4 * members.list.items.len) + 4 + (2 * num_symbols) + string_table_len;
    const long_names_len_including_header_and_padding = blk: {
        if (long_names.map.count() == 0) break :blk 0;
        break :blk archive_header_len + std.mem.alignForward(usize, long_names.data.items.len, 2);
    };
    const first_member_offset = archive_start.len + archive_header_len + std.mem.alignForward(usize, first_linker_member_len, 2) + archive_header_len + std.mem.alignForward(usize, second_linker_member_len, 2) + long_names_len_including_header_and_padding;

    // https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#first-linker-member
    try writeArchiveMemberHeader(writer, .linker_member, memberHeaderLen(first_linker_member_len), "0");
    try writer.writeInt(u32, @intCast(num_symbols), .big);
    for (symbol_to_member_index.values()) |member_i| {
        const offset = member_offsets[member_i];
        try writer.writeInt(u32, @intCast(first_member_offset + offset), .big);
    }
    for (symbol_to_member_index.keys()) |symbol_name| {
        try writer.writeAll(symbol_name);
        try writer.writeByte(0);
    }
    if (first_linker_member_len % 2 != 0) try writer.writeByte(if (llvm_compat) 0 else archive_pad_byte);

    // https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#second-linker-member
    try writeArchiveMemberHeader(writer, .linker_member, memberHeaderLen(second_linker_member_len), "0");
    try writer.writeInt(u32, @intCast(members.list.items.len), .little);
    for (member_offsets) |offset| {
        try writer.writeInt(u32, @intCast(first_member_offset + offset), .little);
    }
    try writer.writeInt(u32, @intCast(num_symbols), .little);

    // sort lexicographically
    const C = struct {
        keys: []const []const u8,

        pub fn lessThan(ctx: @This(), a_index: usize, b_index: usize) bool {
            return std.mem.lessThan(u8, ctx.keys[a_index], ctx.keys[b_index]);
        }
    };
    symbol_to_member_index.sortUnstable(C{ .keys = symbol_to_member_index.keys() });

    for (symbol_to_member_index.values()) |member_i| {
        try writer.writeInt(u16, @intCast(member_i + 1), .little);
    }
    for (symbol_to_member_index.keys()) |symbol_name| {
        try writer.writeAll(symbol_name);
        try writer.writeByte(0);
    }
    if (first_linker_member_len % 2 != 0) try writer.writeByte(if (llvm_compat) 0 else archive_pad_byte);

    // https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#longnames-member
    if (long_names.data.items.len != 0) {
        const written_len = long_names.data.items.len;
        try writeLongNamesMemberHeader(writer, memberHeaderLen(written_len));
        try writer.writeAll(long_names.data.items);
        if (long_names.data.items.len % 2 != 0) try writer.writeByte(archive_pad_byte);
    }

    for (members.list.items) |member| {
        const name: MemberName = if (member.needsLongName())
            .{ .longname = long_names.getOffset(member.name).? }
        else
            .{ .name = member.name };
        try writeArchiveMemberHeader(writer, name, member.bytes.len, "644");
        try writer.writeAll(member.bytes);
        if (member.bytes.len % 2 != 0) try writer.writeByte(archive_pad_byte);
    }

    try writer.flush();
}

const archive_start = "!<arch>\n";
const archive_header_end = "`\n";
const archive_pad_byte = '\n';
const archive_header_len = 60;

fn memberHeaderLen(len: usize) usize {
    return if (llvm_compat)
        // LLVM writes this with the padding byte included, likely a bug/mistake
        std.mem.alignForward(usize, len, 2)
    else
        len;
}

const MemberName = union(enum) {
    name: []const u8,
    linker_member,
    longnames_member,
    longname: usize,

    pub fn write(self: MemberName, writer: *std.Io.Writer) !void {
        switch (self) {
            .name => |name| {
                try writer.writeAll(name);
                try writer.writeByte('/');
                try writer.splatByteAll(' ', 16 - (name.len + 1));
            },
            .linker_member => {
                try writer.writeAll("/               ");
            },
            .longnames_member => {
                try writer.writeAll("//              ");
            },
            .longname => |offset| {
                try writer.print("/{d: <15}", .{offset});
            },
        }
    }
};

fn writeLongNamesMemberHeader(writer: *std.Io.Writer, size: usize) !void {
    try (MemberName{ .longnames_member = {} }).write(writer);
    try writer.splatByteAll(' ', archive_header_len - 16 - 10 - archive_header_end.len);
    try writer.print("{d: <10}", .{size});
    try writer.writeAll(archive_header_end);
}

fn writeArchiveMemberHeader(writer: *std.Io.Writer, name: MemberName, size: usize, mode: []const u8) !void {
    try name.write(writer);
    try writer.writeAll("0           "); // date
    try writer.writeAll("0     "); // user id
    try writer.writeAll("0     "); // group id
    try writer.print("{s: <8}", .{mode}); // mode
    try writer.print("{d: <10}", .{size});
    try writer.writeAll(archive_header_end);
}

pub const Members = struct {
    list: std.ArrayList(Member) = .empty,
    arena: std.heap.ArenaAllocator,

    pub const Member = struct {
        bytes: []const u8,
        name: []const u8,
        symbol_names_for_import_lib: []const []const u8,

        pub fn byteLenWithPadding(self: Member) usize {
            return std.mem.alignForward(usize, self.bytes.len, 2);
        }

        pub fn needsLongName(self: Member) bool {
            return self.name.len >= 16;
        }
    };

    pub fn deinit(self: *const Members) void {
        self.arena.deinit();
    }
};

const GetMembersError = GetImportDescriptorError || GetShortImportError;

pub fn getMembers(
    allocator: std.mem.Allocator,
    module_def: def.ModuleDefinition,
    machine_type: std.coff.IMAGE.FILE.MACHINE,
) GetMembersError!Members {
    var members: Members = .{
        .arena = std.heap.ArenaAllocator.init(allocator),
    };
    const arena = members.arena.allocator();
    errdefer members.deinit();

    try members.list.ensureTotalCapacity(arena, 3 + module_def.exports.items.len);
    const module_import_name = try arena.dupe(u8, module_def.name orelse "");
    const library = std.fs.path.stem(module_import_name);

    const import_descriptor_symbol_name = try std.mem.concat(arena, u8, &.{
        import_descriptor_prefix,
        library,
    });
    const null_thunk_symbol_name = try std.mem.concat(arena, u8, &.{
        null_thunk_data_prefix,
        library,
        null_thunk_data_suffix,
    });

    members.list.appendAssumeCapacity(try getImportDescriptor(arena, machine_type, module_import_name, import_descriptor_symbol_name, null_thunk_symbol_name));
    members.list.appendAssumeCapacity(try getNullImportDescriptor(arena, machine_type, module_import_name));
    members.list.appendAssumeCapacity(try getNullThunk(arena, machine_type, module_import_name, null_thunk_symbol_name));

    const DeferredExport = struct {
        name: []const u8,
        e: *const def.ModuleDefinition.Export,
    };
    var renames: std.ArrayList(DeferredExport) = .empty;
    defer renames.deinit(allocator);
    var regular_imports: std.StringArrayHashMapUnmanaged([]const u8) = .empty;
    defer regular_imports.deinit(allocator);

    for (module_def.exports.items) |*e| {
        if (e.private) continue;

        const maybe_mangled_name = e.mangled_symbol_name orelse e.name;
        const name = maybe_mangled_name;

        if (e.ext_name) |ext_name| {
            _ = ext_name;
            @panic("TODO"); // impossible if fixupForImportLibraryGeneration is called
        }

        var import_name_type: std.coff.ImportNameType = undefined;
        var export_name: ?[]const u8 = null;
        if (e.no_name) {
            import_name_type = .ORDINAL;
        } else if (e.export_as) |export_as| {
            import_name_type = .NAME_EXPORTAS;
            export_name = export_as;
        } else if (e.import_name) |import_name| {
            if (machine_type == .I386 and std.mem.eql(u8, applyNameType(.NAME_UNDECORATE, name), import_name)) {
                import_name_type = .NAME_UNDECORATE;
            } else if (machine_type == .I386 and std.mem.eql(u8, applyNameType(.NAME_NOPREFIX, name), import_name)) {
                import_name_type = .NAME_NOPREFIX;
            } else if (isArm64EC(machine_type)) {
                import_name_type = .NAME_EXPORTAS;
                export_name = import_name;
            } else if (std.mem.eql(u8, name, import_name)) {
                import_name_type = .NAME;
            } else {
                try renames.append(allocator, .{
                    .name = name,
                    .e = e,
                });
                continue;
            }
        } else {
            import_name_type = getNameType(maybe_mangled_name, e.name, machine_type, module_def.type);
        }

        try regular_imports.put(allocator, applyNameType(import_name_type, name), name);
        try members.list.append(arena, try getShortImport(arena, module_import_name, name, export_name, machine_type, e.ordinal, e.type, import_name_type));
    }
    for (renames.items) |deferred| {
        const import_name = deferred.e.import_name.?;
        if (regular_imports.get(import_name)) |symbol| {
            if (deferred.e.type == .CODE) {
                try members.list.append(arena, try getWeakExternal(arena, module_import_name, symbol, deferred.name, .{
                    .imp_prefix = false,
                    .machine_type = machine_type,
                }));
            }
            try members.list.append(arena, try getWeakExternal(arena, module_import_name, symbol, deferred.name, .{
                .imp_prefix = true,
                .machine_type = machine_type,
            }));
        } else {
            try members.list.append(arena, try getShortImport(
                arena,
                module_import_name,
                deferred.name,
                deferred.e.import_name,
                machine_type,
                deferred.e.ordinal,
                deferred.e.type,
                .NAME_EXPORTAS,
            ));
        }
    }

    return members;
}

/// Returns a slice of `name`
fn applyNameType(name_type: std.coff.ImportNameType, name: []const u8) []const u8 {
    switch (name_type) {
        .NAME_NOPREFIX, .NAME_UNDECORATE => {
            if (name.len == 0) return name;
            const unprefixed = switch (name[0]) {
                '?', '@', '_' => name[1..],
                else => name,
            };
            if (name_type == .NAME_UNDECORATE) {
                var split = std.mem.splitScalar(u8, unprefixed, '@');
                return split.first();
            } else {
                return unprefixed;
            }
        },
        else => return name,
    }
}

fn getNameType(
    symbol: []const u8,
    ext_name: []const u8,
    machine_type: std.coff.IMAGE.FILE.MACHINE,
    module_definition_type: def.ModuleDefinitionType,
) std.coff.ImportNameType {
    // A decorated stdcall function in MSVC is exported with the
    // type IMPORT_NAME, and the exported function name includes the
    // the leading underscore. In MinGW on the other hand, a decorated
    // stdcall function still omits the underscore (IMPORT_NAME_NOPREFIX).
    if (std.mem.startsWith(u8, ext_name, "_") and
        std.mem.indexOfScalar(u8, ext_name, '@') != null and
        module_definition_type != .mingw)
        return .NAME;
    if (!std.mem.eql(u8, symbol, ext_name))
        return .NAME_UNDECORATE;
    if (machine_type == .I386 and std.mem.startsWith(u8, symbol, "_"))
        return .NAME_NOPREFIX;
    return .NAME;
}

fn is64Bit(machine_type: std.coff.IMAGE.FILE.MACHINE) bool {
    return switch (machine_type) {
        .AMD64, .ARM64, .ARM64EC, .ARM64X => true,
        else => false,
    };
}

fn isArm64EC(machine_type: std.coff.IMAGE.FILE.MACHINE) bool {
    return switch (machine_type) {
        .ARM64EC, .ARM64X => true,
        else => false,
    };
}

const null_import_descriptor_symbol_name = "__NULL_IMPORT_DESCRIPTOR";
const import_descriptor_prefix = "__IMPORT_DESCRIPTOR_";
const null_thunk_data_prefix = "\x7F";
const null_thunk_data_suffix = "_NULL_THUNK_DATA";

// past the string table length field
const first_string_table_entry_offset = @sizeOf(u32);
const first_string_table_entry = getNameBytesForStringTableOffset(first_string_table_entry_offset);

const byte_size_of_relocation = 10;

fn getNameBytesForStringTableOffset(offset: u32) [8]u8 {
    var bytes = [_]u8{0} ** 8;
    std.mem.writeInt(u32, bytes[4..8], offset, .little);
    return bytes;
}

const GetImportDescriptorError = error{UnsupportedMachineType} || std.mem.Allocator.Error;

fn getImportDescriptor(
    allocator: std.mem.Allocator,
    machine_type: std.coff.IMAGE.FILE.MACHINE,
    module_import_name: []const u8,
    import_descriptor_symbol_name: []const u8,
    null_thunk_symbol_name: []const u8,
) GetImportDescriptorError!Members.Member {
    const number_of_sections = 2;
    const number_of_symbols = 7;
    const number_of_relocations = 3;

    const pointer_to_idata2_data = @sizeOf(std.coff.Header) +
        (@sizeOf(std.coff.SectionHeader) * number_of_sections);
    const pointer_to_idata6_data = pointer_to_idata2_data +
        @sizeOf(std.coff.ImportDirectoryEntry) +
        (byte_size_of_relocation * number_of_relocations);
    const pointer_to_symbol_table = pointer_to_idata6_data +
        module_import_name.len + 1;

    const string_table_byte_len = 4 +
        (import_descriptor_symbol_name.len + 1) +
        (null_import_descriptor_symbol_name.len + 1) +
        (null_thunk_symbol_name.len + 1);
    const total_byte_len = pointer_to_symbol_table +
        (std.coff.Symbol.sizeOf() * number_of_symbols) +
        string_table_byte_len;

    const bytes = try allocator.alloc(u8, total_byte_len);
    errdefer allocator.free(bytes);
    var writer: std.Io.Writer = .fixed(bytes);

    writer.writeStruct(std.coff.Header{
        .machine = machine_type,
        .number_of_sections = number_of_sections,
        .time_date_stamp = 0,
        .pointer_to_symbol_table = @intCast(pointer_to_symbol_table),
        .number_of_symbols = number_of_symbols,
        .size_of_optional_header = 0,
        .flags = .{ .@"32BIT_MACHINE" = !is64Bit(machine_type) },
    }, .little) catch unreachable;

    writer.writeStruct(std.coff.SectionHeader{
        .name = ".idata$2".*,
        .virtual_size = 0,
        .virtual_address = 0,
        .size_of_raw_data = @sizeOf(std.coff.ImportDirectoryEntry),
        .pointer_to_raw_data = pointer_to_idata2_data,
        .pointer_to_relocations = pointer_to_idata2_data + @sizeOf(std.coff.ImportDirectoryEntry),
        .pointer_to_linenumbers = 0,
        .number_of_relocations = number_of_relocations,
        .number_of_linenumbers = 0,
        .flags = .{
            .ALIGN = .@"4BYTES",
            .CNT_INITIALIZED_DATA = true,
            .MEM_WRITE = true,
            .MEM_READ = true,
        },
    }, .little) catch unreachable;

    writer.writeStruct(std.coff.SectionHeader{
        .name = ".idata$6".*,
        .virtual_size = 0,
        .virtual_address = 0,
        .size_of_raw_data = @intCast(module_import_name.len + 1),
        .pointer_to_raw_data = pointer_to_idata6_data,
        .pointer_to_relocations = 0,
        .pointer_to_linenumbers = 0,
        .number_of_relocations = 0,
        .number_of_linenumbers = 0,
        .flags = .{
            .ALIGN = .@"2BYTES",
            .CNT_INITIALIZED_DATA = true,
            .MEM_WRITE = true,
            .MEM_READ = true,
        },
    }, .little) catch unreachable;

    // .idata$2
    writer.writeStruct(std.coff.ImportDirectoryEntry{
        .forwarder_chain = 0,
        .import_address_table_rva = 0,
        .import_lookup_table_rva = 0,
        .name_rva = 0,
        .time_date_stamp = 0,
    }, .little) catch unreachable;

    const relocation_rva_type = rvaRelocationTypeIndicator(machine_type) orelse return error.UnsupportedMachineType;
    writeRelocation(&writer, .{
        .virtual_address = @offsetOf(std.coff.ImportDirectoryEntry, "name_rva"),
        .symbol_table_index = 2,
        .type = relocation_rva_type,
    }) catch unreachable;
    writeRelocation(&writer, .{
        .virtual_address = @offsetOf(std.coff.ImportDirectoryEntry, "import_lookup_table_rva"),
        .symbol_table_index = 3,
        .type = relocation_rva_type,
    }) catch unreachable;
    writeRelocation(&writer, .{
        .virtual_address = @offsetOf(std.coff.ImportDirectoryEntry, "import_address_table_rva"),
        .symbol_table_index = 4,
        .type = relocation_rva_type,
    }) catch unreachable;

    // .idata$6
    writer.writeAll(module_import_name) catch unreachable;
    writer.writeByte(0) catch unreachable;

    var string_table_offset: usize = first_string_table_entry_offset;
    writeSymbol(&writer, .{
        .name = first_string_table_entry,
        .value = 0,
        .section_number = @enumFromInt(1),
        .type = .{
            .base_type = .NULL,
            .complex_type = .NULL,
        },
        .storage_class = .EXTERNAL,
        .number_of_aux_symbols = 0,
    }) catch unreachable;
    string_table_offset += import_descriptor_symbol_name.len + 1;
    writeSymbol(&writer, .{
        .name = ".idata$2".*,
        .value = 0,
        .section_number = @enumFromInt(1),
        .type = .{
            .base_type = .NULL,
            .complex_type = .NULL,
        },
        .storage_class = .SECTION,
        .number_of_aux_symbols = 0,
    }) catch unreachable;
    writeSymbol(&writer, .{
        .name = ".idata$6".*,
        .value = 0,
        .section_number = @enumFromInt(2),
        .type = .{
            .base_type = .NULL,
            .complex_type = .NULL,
        },
        .storage_class = .STATIC,
        .number_of_aux_symbols = 0,
    }) catch unreachable;
    writeSymbol(&writer, .{
        .name = ".idata$4".*,
        .value = 0,
        .section_number = .UNDEFINED,
        .type = .{
            .base_type = .NULL,
            .complex_type = .NULL,
        },
        .storage_class = .SECTION,
        .number_of_aux_symbols = 0,
    }) catch unreachable;
    writeSymbol(&writer, .{
        .name = ".idata$5".*,
        .value = 0,
        .section_number = .UNDEFINED,
        .type = .{
            .base_type = .NULL,
            .complex_type = .NULL,
        },
        .storage_class = .SECTION,
        .number_of_aux_symbols = 0,
    }) catch unreachable;
    writeSymbol(&writer, .{
        .name = getNameBytesForStringTableOffset(@intCast(string_table_offset)),
        .value = 0,
        .section_number = .UNDEFINED,
        .type = .{
            .base_type = .NULL,
            .complex_type = .NULL,
        },
        .storage_class = .EXTERNAL,
        .number_of_aux_symbols = 0,
    }) catch unreachable;
    string_table_offset += null_import_descriptor_symbol_name.len + 1;
    writeSymbol(&writer, .{
        .name = getNameBytesForStringTableOffset(@intCast(string_table_offset)),
        .value = 0,
        .section_number = .UNDEFINED,
        .type = .{
            .base_type = .NULL,
            .complex_type = .NULL,
        },
        .storage_class = .EXTERNAL,
        .number_of_aux_symbols = 0,
    }) catch unreachable;
    string_table_offset += null_thunk_symbol_name.len + 1;

    // string table
    writer.writeInt(u32, @intCast(string_table_byte_len), .little) catch unreachable;
    writer.writeAll(import_descriptor_symbol_name) catch unreachable;
    writer.writeByte(0) catch unreachable;
    writer.writeAll(null_import_descriptor_symbol_name) catch unreachable;
    writer.writeByte(0) catch unreachable;
    writer.writeAll(null_thunk_symbol_name) catch unreachable;
    writer.writeByte(0) catch unreachable;

    var symbol_names_for_import_lib = try allocator.alloc([]const u8, 1);
    errdefer allocator.free(symbol_names_for_import_lib);

    const duped_symbol_name = try allocator.dupe(u8, import_descriptor_symbol_name);
    errdefer allocator.free(duped_symbol_name);
    symbol_names_for_import_lib[0] = duped_symbol_name;

    // Confirm byte length was calculated exactly correctly
    std.debug.assert(writer.end == bytes.len);
    return .{
        .bytes = bytes,
        .name = module_import_name,
        .symbol_names_for_import_lib = symbol_names_for_import_lib,
    };
}

fn getNullImportDescriptor(
    allocator: std.mem.Allocator,
    machine_type: std.coff.IMAGE.FILE.MACHINE,
    module_import_name: []const u8,
) error{OutOfMemory}!Members.Member {
    const number_of_sections = 1;
    const number_of_symbols = 1;
    const pointer_to_idata3_data = @sizeOf(std.coff.Header) +
        (@sizeOf(std.coff.SectionHeader) * number_of_sections);
    const pointer_to_symbol_table = pointer_to_idata3_data +
        @sizeOf(std.coff.ImportDirectoryEntry);

    const string_table_byte_len = 4 + null_import_descriptor_symbol_name.len + 1;
    const total_byte_len = pointer_to_symbol_table +
        (std.coff.Symbol.sizeOf() * number_of_symbols) +
        string_table_byte_len;

    const bytes = try allocator.alloc(u8, total_byte_len);
    errdefer allocator.free(bytes);
    var writer: std.Io.Writer = .fixed(bytes);

    writer.writeStruct(std.coff.Header{
        .machine = machine_type,
        .number_of_sections = number_of_sections,
        .time_date_stamp = 0,
        .pointer_to_symbol_table = @intCast(pointer_to_symbol_table),
        .number_of_symbols = number_of_symbols,
        .size_of_optional_header = 0,
        .flags = .{ .@"32BIT_MACHINE" = !is64Bit(machine_type) },
    }, .little) catch unreachable;

    writer.writeStruct(std.coff.SectionHeader{
        .name = ".idata$3".*,
        .virtual_size = 0,
        .virtual_address = 0,
        .size_of_raw_data = @sizeOf(std.coff.ImportDirectoryEntry),
        .pointer_to_raw_data = pointer_to_idata3_data,
        .pointer_to_relocations = 0,
        .pointer_to_linenumbers = 0,
        .number_of_relocations = 0,
        .number_of_linenumbers = 0,
        .flags = .{
            .ALIGN = .@"4BYTES",
            .CNT_INITIALIZED_DATA = true,
            .MEM_WRITE = true,
            .MEM_READ = true,
        },
    }, .little) catch unreachable;

    writer.writeStruct(std.coff.ImportDirectoryEntry{
        .forwarder_chain = 0,
        .import_address_table_rva = 0,
        .import_lookup_table_rva = 0,
        .name_rva = 0,
        .time_date_stamp = 0,
    }, .little) catch unreachable;

    writeSymbol(&writer, .{
        .name = first_string_table_entry,
        .value = 0,
        .section_number = @enumFromInt(1),
        .type = .{
            .base_type = .NULL,
            .complex_type = .NULL,
        },
        .storage_class = .EXTERNAL,
        .number_of_aux_symbols = 0,
    }) catch unreachable;

    // string table
    writer.writeInt(u32, string_table_byte_len, .little) catch unreachable;
    writer.writeAll(null_import_descriptor_symbol_name) catch unreachable;
    writer.writeByte(0) catch unreachable;

    var symbol_names_for_import_lib = try allocator.alloc([]const u8, 1);
    errdefer allocator.free(symbol_names_for_import_lib);

    const duped_symbol_name = try allocator.dupe(u8, null_import_descriptor_symbol_name);
    errdefer allocator.free(duped_symbol_name);
    symbol_names_for_import_lib[0] = duped_symbol_name;

    // Confirm byte length was calculated exactly correctly
    std.debug.assert(writer.end == bytes.len);
    return .{
        .bytes = bytes,
        .name = module_import_name,
        .symbol_names_for_import_lib = symbol_names_for_import_lib,
    };
}

fn getNullThunk(
    allocator: std.mem.Allocator,
    machine_type: std.coff.IMAGE.FILE.MACHINE,
    module_import_name: []const u8,
    null_thunk_symbol_name: []const u8,
) error{OutOfMemory}!Members.Member {
    const number_of_sections = 2;
    const number_of_symbols = 1;
    const va_size: u32 = if (is64Bit(machine_type)) 8 else 4;
    const pointer_to_idata5_data = @sizeOf(std.coff.Header) +
        (@sizeOf(std.coff.SectionHeader) * number_of_sections);
    const pointer_to_idata4_data = pointer_to_idata5_data + va_size;
    const pointer_to_symbol_table = pointer_to_idata4_data + va_size;

    const string_table_byte_len = 4 + null_thunk_symbol_name.len + 1;
    const total_byte_len = pointer_to_symbol_table +
        (std.coff.Symbol.sizeOf() * number_of_symbols) +
        string_table_byte_len;

    const bytes = try allocator.alloc(u8, total_byte_len);
    errdefer allocator.free(bytes);
    var writer: std.Io.Writer = .fixed(bytes);

    writer.writeStruct(std.coff.Header{
        .machine = machine_type,
        .number_of_sections = number_of_sections,
        .time_date_stamp = 0,
        .pointer_to_symbol_table = @intCast(pointer_to_symbol_table),
        .number_of_symbols = number_of_symbols,
        .size_of_optional_header = 0,
        .flags = .{ .@"32BIT_MACHINE" = !is64Bit(machine_type) },
    }, .little) catch unreachable;

    writer.writeStruct(std.coff.SectionHeader{
        .name = ".idata$5".*,
        .virtual_size = 0,
        .virtual_address = 0,
        .size_of_raw_data = va_size,
        .pointer_to_raw_data = pointer_to_idata5_data,
        .pointer_to_relocations = 0,
        .pointer_to_linenumbers = 0,
        .number_of_relocations = 0,
        .number_of_linenumbers = 0,
        .flags = .{
            .ALIGN = if (is64Bit(machine_type))
                .@"8BYTES"
            else
                .@"4BYTES",
            .CNT_INITIALIZED_DATA = true,
            .MEM_WRITE = true,
            .MEM_READ = true,
        },
    }, .little) catch unreachable;

    writer.writeStruct(std.coff.SectionHeader{
        .name = ".idata$4".*,
        .virtual_size = 0,
        .virtual_address = 0,
        .size_of_raw_data = va_size,
        .pointer_to_raw_data = pointer_to_idata4_data,
        .pointer_to_relocations = 0,
        .pointer_to_linenumbers = 0,
        .number_of_relocations = 0,
        .number_of_linenumbers = 0,
        .flags = .{
            .ALIGN = if (is64Bit(machine_type))
                .@"8BYTES"
            else
                .@"4BYTES",
            .CNT_INITIALIZED_DATA = true,
            .MEM_WRITE = true,
            .MEM_READ = true,
        },
    }, .little) catch unreachable;

    // .idata$5
    writer.splatByteAll(0, va_size) catch unreachable;
    // .idata$4
    writer.splatByteAll(0, va_size) catch unreachable;

    writeSymbol(&writer, .{
        .name = first_string_table_entry,
        .value = 0,
        .section_number = @enumFromInt(1),
        .type = .{
            .base_type = .NULL,
            .complex_type = .NULL,
        },
        .storage_class = .EXTERNAL,
        .number_of_aux_symbols = 0,
    }) catch unreachable;

    // string table
    writer.writeInt(u32, @intCast(string_table_byte_len), .little) catch unreachable;
    writer.writeAll(null_thunk_symbol_name) catch unreachable;
    writer.writeByte(0) catch unreachable;

    var symbol_names_for_import_lib = try allocator.alloc([]const u8, 1);
    errdefer allocator.free(symbol_names_for_import_lib);

    const duped_symbol_name = try allocator.dupe(u8, null_thunk_symbol_name);
    errdefer allocator.free(duped_symbol_name);
    symbol_names_for_import_lib[0] = duped_symbol_name;

    // Confirm byte length was calculated exactly correctly
    std.debug.assert(writer.end == bytes.len);
    return .{
        .bytes = bytes,
        .name = module_import_name,
        .symbol_names_for_import_lib = symbol_names_for_import_lib,
    };
}

const WeakExternalOptions = struct {
    imp_prefix: bool,
    machine_type: std.coff.IMAGE.FILE.MACHINE,
};

fn getWeakExternal(
    arena: std.mem.Allocator,
    module_import_name: []const u8,
    sym: []const u8,
    weak: []const u8,
    options: WeakExternalOptions,
) error{OutOfMemory}!Members.Member {
    const number_of_sections = 1;
    const number_of_symbols = 4;
    const number_of_weak_external_defs = 1;
    const pointer_to_symbol_table = @sizeOf(std.coff.Header) +
        (@sizeOf(std.coff.SectionHeader) * number_of_sections);

    const symbol_names = try arena.alloc([]const u8, 2);

    symbol_names[0] = if (options.imp_prefix)
        try std.mem.concat(arena, u8, &.{ "__imp_", sym })
    else
        try arena.dupe(u8, sym);

    symbol_names[1] = if (options.imp_prefix)
        try std.mem.concat(arena, u8, &.{ "__imp_", weak })
    else
        try arena.dupe(u8, weak);

    const string_table_byte_len = 4 + symbol_names[0].len + 1 + symbol_names[1].len + 1;
    const total_byte_len = pointer_to_symbol_table +
        (std.coff.Symbol.sizeOf() * number_of_symbols) +
        (std.coff.WeakExternalDefinition.sizeOf() * number_of_weak_external_defs) +
        string_table_byte_len;

    const bytes = try arena.alloc(u8, total_byte_len);
    errdefer arena.free(bytes);
    var writer: std.Io.Writer = .fixed(bytes);

    writer.writeStruct(std.coff.Header{
        .machine = options.machine_type,
        .number_of_sections = number_of_sections,
        .time_date_stamp = 0,
        .pointer_to_symbol_table = @intCast(pointer_to_symbol_table),
        .number_of_symbols = number_of_symbols + number_of_weak_external_defs,
        .size_of_optional_header = 0,
        .flags = .{},
    }, .little) catch unreachable;

    writer.writeStruct(std.coff.SectionHeader{
        .name = ".drectve".*,
        .virtual_size = 0,
        .virtual_address = 0,
        .size_of_raw_data = 0,
        .pointer_to_raw_data = 0,
        .pointer_to_relocations = 0,
        .pointer_to_linenumbers = 0,
        .number_of_relocations = 0,
        .number_of_linenumbers = 0,
        .flags = .{
            .LNK_INFO = true,
            .LNK_REMOVE = true,
        },
    }, .little) catch unreachable;

    writeSymbol(&writer, .{
        .name = "@comp.id".*,
        .value = 0,
        .section_number = .ABSOLUTE,
        .type = .{
            .base_type = .NULL,
            .complex_type = .NULL,
        },
        .storage_class = .STATIC,
        .number_of_aux_symbols = 0,
    }) catch unreachable;
    writeSymbol(&writer, .{
        .name = "@feat.00".*,
        .value = 0,
        .section_number = .ABSOLUTE,
        .type = .{
            .base_type = .NULL,
            .complex_type = .NULL,
        },
        .storage_class = .STATIC,
        .number_of_aux_symbols = 0,
    }) catch unreachable;
    var string_table_offset: usize = first_string_table_entry_offset;
    writeSymbol(&writer, .{
        .name = first_string_table_entry,
        .value = 0,
        .section_number = @enumFromInt(0),
        .type = .{
            .base_type = .NULL,
            .complex_type = .NULL,
        },
        .storage_class = .EXTERNAL,
        .number_of_aux_symbols = 0,
    }) catch unreachable;
    string_table_offset += symbol_names[0].len + 1;
    writeSymbol(&writer, .{
        .name = getNameBytesForStringTableOffset(@intCast(string_table_offset)),
        .value = 0,
        .section_number = @enumFromInt(0),
        .type = .{
            .base_type = .NULL,
            .complex_type = .NULL,
        },
        .storage_class = .WEAK_EXTERNAL,
        .number_of_aux_symbols = 1,
    }) catch unreachable;
    writeWeakExternalDefinition(&writer, .{
        .tag_index = 2,
        .flag = .SEARCH_ALIAS,
        .unused = @splat(0),
    }) catch unreachable;

    // string table
    writer.writeInt(u32, @intCast(string_table_byte_len), .little) catch unreachable;
    writer.writeAll(symbol_names[0]) catch unreachable;
    writer.writeByte(0) catch unreachable;
    writer.writeAll(symbol_names[1]) catch unreachable;
    writer.writeByte(0) catch unreachable;

    // Confirm byte length was calculated exactly correctly
    std.debug.assert(writer.end == bytes.len);
    return .{
        .bytes = bytes,
        .name = module_import_name,
        .symbol_names_for_import_lib = symbol_names,
    };
}

const GetShortImportError = error{UnknownImportType} || std.mem.Allocator.Error;

fn getShortImport(
    arena: std.mem.Allocator,
    module_import_name: []const u8,
    sym: []const u8,
    export_name: ?[]const u8,
    machine_type: std.coff.IMAGE.FILE.MACHINE,
    ordinal_hint: u16,
    import_type: std.coff.ImportType,
    name_type: std.coff.ImportNameType,
) GetShortImportError!Members.Member {
    var size_of_data = module_import_name.len + 1 + sym.len + 1;
    if (export_name) |name| size_of_data += name.len + 1;
    const total_byte_len = @sizeOf(std.coff.ImportHeader) + size_of_data;

    const bytes = try arena.alloc(u8, total_byte_len);
    errdefer arena.free(bytes);
    var writer = std.Io.Writer.fixed(bytes);

    writer.writeStruct(std.coff.ImportHeader{
        .version = 0,
        .machine = machine_type,
        .time_date_stamp = 0,
        .size_of_data = @intCast(size_of_data),
        .hint = ordinal_hint,
        .types = .{
            .type = import_type,
            .name_type = name_type,
            .reserved = 0,
        },
    }, .little) catch unreachable;

    writer.writeAll(sym) catch unreachable;
    writer.writeByte(0) catch unreachable;
    writer.writeAll(module_import_name) catch unreachable;
    writer.writeByte(0) catch unreachable;
    if (export_name) |name| {
        writer.writeAll(name) catch unreachable;
        writer.writeByte(0) catch unreachable;
    }

    var symbol_names_for_import_lib: std.ArrayList([]const u8) = try .initCapacity(arena, 2);

    switch (import_type) {
        .CODE, .CONST => {
            symbol_names_for_import_lib.appendAssumeCapacity(try std.mem.concat(arena, u8, &.{ "__imp_", sym }));
            symbol_names_for_import_lib.appendAssumeCapacity(try arena.dupe(u8, sym));
        },
        .DATA => {
            symbol_names_for_import_lib.appendAssumeCapacity(try std.mem.concat(arena, u8, &.{ "__imp_", sym }));
        },
        else => return error.UnknownImportType,
    }

    // Confirm byte length was calculated exactly correctly
    std.debug.assert(writer.end == bytes.len);
    return .{
        .bytes = bytes,
        .name = module_import_name,
        .symbol_names_for_import_lib = try symbol_names_for_import_lib.toOwnedSlice(arena),
    };
}

fn writeSymbol(writer: *std.Io.Writer, symbol: std.coff.Symbol) !void {
    try writer.writeAll(&symbol.name);
    try writer.writeInt(u32, symbol.value, .little);
    try writer.writeInt(u16, @intFromEnum(symbol.section_number), .little);
    try writer.writeInt(u8, @intFromEnum(symbol.type.base_type), .little);
    try writer.writeInt(u8, @intFromEnum(symbol.type.complex_type), .little);
    try writer.writeInt(u8, @intFromEnum(symbol.storage_class), .little);
    try writer.writeInt(u8, symbol.number_of_aux_symbols, .little);
}

fn writeWeakExternalDefinition(writer: *std.Io.Writer, weak_external: std.coff.WeakExternalDefinition) !void {
    try writer.writeInt(u32, weak_external.tag_index, .little);
    try writer.writeInt(u32, @intFromEnum(weak_external.flag), .little);
    try writer.writeAll(&weak_external.unused);
}

fn writeRelocation(writer: *std.Io.Writer, relocation: std.coff.Relocation) !void {
    try writer.writeInt(u32, relocation.virtual_address, .little);
    try writer.writeInt(u32, relocation.symbol_table_index, .little);
    try writer.writeInt(u16, relocation.type, .little);
}

// https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#type-indicators
pub fn rvaRelocationTypeIndicator(target: std.coff.IMAGE.FILE.MACHINE) ?u16 {
    return switch (target) {
        .AMD64 => @intFromEnum(std.coff.IMAGE.REL.AMD64.ADDR32NB),
        .I386 => @intFromEnum(std.coff.IMAGE.REL.I386.DIR32NB),
        .ARMNT => @intFromEnum(std.coff.IMAGE.REL.ARM.ADDR32NB),
        .ARM64, .ARM64EC, .ARM64X => @intFromEnum(std.coff.IMAGE.REL.ARM64.ADDR32NB),
        .IA64 => @intFromEnum(std.coff.IMAGE.REL.IA64.DIR32NB),
        else => null,
    };
}

const StringTable = struct {
    data: std.ArrayList(u8) = .empty,
    map: std.HashMapUnmanaged(u32, void, std.hash_map.StringIndexContext, std.hash_map.default_max_load_percentage) = .empty,

    pub fn deinit(self: *StringTable, allocator: Allocator) void {
        self.data.deinit(allocator);
        self.map.deinit(allocator);
    }

    pub fn put(self: *StringTable, allocator: Allocator, value: []const u8) !u32 {
        const result = try self.map.getOrPutContextAdapted(
            allocator,
            value,
            std.hash_map.StringIndexAdapter{ .bytes = &self.data },
            .{ .bytes = &self.data },
        );
        if (result.found_existing) {
            return result.key_ptr.*;
        }

        try self.data.ensureUnusedCapacity(allocator, value.len + 1);
        const offset: u32 = @intCast(self.data.items.len);

        self.data.appendSliceAssumeCapacity(value);
        self.data.appendAssumeCapacity(0);

        result.key_ptr.* = offset;

        return offset;
    }

    pub fn get(self: StringTable, offset: u32) []const u8 {
        std.debug.assert(offset < self.data.items.len);
        return std.mem.sliceTo(@as([*:0]const u8, @ptrCast(self.data.items.ptr + offset)), 0);
    }

    pub fn getOffset(self: *StringTable, value: []const u8) ?u32 {
        return self.map.getKeyAdapted(
            value,
            std.hash_map.StringIndexAdapter{ .bytes = &self.data },
        );
    }
};
