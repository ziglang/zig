const builtin = @import("builtin");
const std = @import("std.zig");
const io = std.io;
const mem = std.mem;
const os = std.os;
const File = std.fs.File;

const ArrayList = std.ArrayList;

// CoffHeader.machine values
// see https://msdn.microsoft.com/en-us/library/windows/desktop/ms680313(v=vs.85).aspx
const IMAGE_FILE_MACHINE_I386 = 0x014c;
const IMAGE_FILE_MACHINE_IA64 = 0x0200;
const IMAGE_FILE_MACHINE_AMD64 = 0x8664;

// OptionalHeader.magic values
// see https://msdn.microsoft.com/en-us/library/windows/desktop/ms680339(v=vs.85).aspx
const IMAGE_NT_OPTIONAL_HDR32_MAGIC = 0x10b;
const IMAGE_NT_OPTIONAL_HDR64_MAGIC = 0x20b;

const IMAGE_NUMBEROF_DIRECTORY_ENTRIES = 16;
const IMAGE_DEBUG_TYPE_CODEVIEW = 2;
const DEBUG_DIRECTORY = 6;

pub const CoffError = error{
    InvalidPEMagic,
    InvalidPEHeader,
    InvalidMachine,
    MissingCoffSection,
};

// Official documentation of the format: https://docs.microsoft.com/en-us/windows/win32/debug/pe-format
pub const Coff = struct {
    in_file: File,
    allocator: *mem.Allocator,

    coff_header: CoffHeader,
    pe_header: OptionalHeader,
    sections: ArrayList(Section),

    guid: [16]u8,
    age: u32,

    pub fn init(allocator: *mem.Allocator, in_file: File) Coff {
        return Coff{
            .in_file = in_file,
            .allocator = allocator,
            .coff_header = undefined,
            .pe_header = undefined,
            .sections = ArrayList(Section).init(allocator),
            .guid = undefined,
            .age = undefined,
        };
    }

    pub fn loadHeader(self: *Coff) !void {
        const pe_pointer_offset = 0x3C;

        const in = self.in_file.inStream();

        var magic: [2]u8 = undefined;
        try in.readNoEof(magic[0..]);
        if (!mem.eql(u8, &magic, "MZ"))
            return error.InvalidPEMagic;

        // Seek to PE File Header (coff header)
        try self.in_file.seekTo(pe_pointer_offset);
        const pe_magic_offset = try in.readIntLittle(u32);
        try self.in_file.seekTo(pe_magic_offset);

        var pe_header_magic: [4]u8 = undefined;
        try in.readNoEof(pe_header_magic[0..]);
        if (!mem.eql(u8, &pe_header_magic, &[_]u8{ 'P', 'E', 0, 0 }))
            return error.InvalidPEHeader;

        self.coff_header = CoffHeader{
            .machine = try in.readIntLittle(u16),
            .number_of_sections = try in.readIntLittle(u16),
            .timedate_stamp = try in.readIntLittle(u32),
            .pointer_to_symbol_table = try in.readIntLittle(u32),
            .number_of_symbols = try in.readIntLittle(u32),
            .size_of_optional_header = try in.readIntLittle(u16),
            .characteristics = try in.readIntLittle(u16),
        };

        switch (self.coff_header.machine) {
            IMAGE_FILE_MACHINE_I386, IMAGE_FILE_MACHINE_AMD64, IMAGE_FILE_MACHINE_IA64 => {},
            else => return error.InvalidMachine,
        }

        try self.loadOptionalHeader();
    }

    fn loadOptionalHeader(self: *Coff) !void {
        const in = self.in_file.inStream();
        self.pe_header.magic = try in.readIntLittle(u16);
        // For now we're only interested in finding the reference to the .pdb,
        // so we'll skip most of this header, which size is different in 32
        // 64 bits by the way.
        var skip_size: u16 = undefined;
        if (self.pe_header.magic == IMAGE_NT_OPTIONAL_HDR32_MAGIC) {
            skip_size = 2 * @sizeOf(u8) + 8 * @sizeOf(u16) + 18 * @sizeOf(u32);
        } else if (self.pe_header.magic == IMAGE_NT_OPTIONAL_HDR64_MAGIC) {
            skip_size = 2 * @sizeOf(u8) + 8 * @sizeOf(u16) + 12 * @sizeOf(u32) + 5 * @sizeOf(u64);
        } else
            return error.InvalidPEMagic;

        try self.in_file.seekBy(skip_size);

        const number_of_rva_and_sizes = try in.readIntLittle(u32);
        if (number_of_rva_and_sizes != IMAGE_NUMBEROF_DIRECTORY_ENTRIES)
            return error.InvalidPEHeader;

        for (self.pe_header.data_directory) |*data_dir| {
            data_dir.* = OptionalHeader.DataDirectory{
                .virtual_address = try in.readIntLittle(u32),
                .size = try in.readIntLittle(u32),
            };
        }
    }

    pub fn getPdbPath(self: *Coff, buffer: []u8) !usize {
        try self.loadSections();

        const header = blk: {
            if (self.getSection(".buildid")) |section| {
                break :blk section.header;
            } else if (self.getSection(".rdata")) |section| {
                break :blk section.header;
            } else {
                return error.MissingCoffSection;
            }
        };

        const debug_dir = &self.pe_header.data_directory[DEBUG_DIRECTORY];
        const file_offset = debug_dir.virtual_address - header.virtual_address + header.pointer_to_raw_data;

        const in = self.in_file.inStream();
        try self.in_file.seekTo(file_offset);

        // Find the correct DebugDirectoryEntry, and where its data is stored.
        // It can be in any section.
        const debug_dir_entry_count = debug_dir.size / @sizeOf(DebugDirectoryEntry);
        var i: u32 = 0;
        blk: while (i < debug_dir_entry_count) : (i += 1) {
            const debug_dir_entry = try in.readStruct(DebugDirectoryEntry);
            if (debug_dir_entry.type == IMAGE_DEBUG_TYPE_CODEVIEW) {
                for (self.sections.span()) |*section| {
                    const section_start = section.header.virtual_address;
                    const section_size = section.header.misc.virtual_size;
                    const rva = debug_dir_entry.address_of_raw_data;
                    const offset = rva - section_start;
                    if (section_start <= rva and offset < section_size and debug_dir_entry.size_of_data <= section_size - offset) {
                        try self.in_file.seekTo(section.header.pointer_to_raw_data + offset);
                        break :blk;
                    }
                }
            }
        }

        var cv_signature: [4]u8 = undefined; // CodeView signature
        try in.readNoEof(cv_signature[0..]);
        // 'RSDS' indicates PDB70 format, used by lld.
        if (!mem.eql(u8, &cv_signature, "RSDS"))
            return error.InvalidPEMagic;
        try in.readNoEof(self.guid[0..]);
        self.age = try in.readIntLittle(u32);

        // Finally read the null-terminated string.
        var byte = try in.readByte();
        i = 0;
        while (byte != 0 and i < buffer.len) : (i += 1) {
            buffer[i] = byte;
            byte = try in.readByte();
        }

        if (byte != 0 and i == buffer.len)
            return error.NameTooLong;

        return @as(usize, i);
    }

    pub fn loadSections(self: *Coff) !void {
        if (self.sections.items.len == self.coff_header.number_of_sections)
            return;

        try self.sections.ensureCapacity(self.coff_header.number_of_sections);

        const in = self.in_file.inStream();

        var name: [8]u8 = undefined;

        var i: u16 = 0;
        while (i < self.coff_header.number_of_sections) : (i += 1) {
            try in.readNoEof(name[0..]);
            try self.sections.append(Section{
                .header = SectionHeader{
                    .name = name,
                    .misc = SectionHeader.Misc{ .virtual_size = try in.readIntLittle(u32) },
                    .virtual_address = try in.readIntLittle(u32),
                    .size_of_raw_data = try in.readIntLittle(u32),
                    .pointer_to_raw_data = try in.readIntLittle(u32),
                    .pointer_to_relocations = try in.readIntLittle(u32),
                    .pointer_to_line_numbers = try in.readIntLittle(u32),
                    .number_of_relocations = try in.readIntLittle(u16),
                    .number_of_line_numbers = try in.readIntLittle(u16),
                    .characteristics = try in.readIntLittle(u32),
                },
            });
        }
    }

    pub fn getSection(self: *Coff, comptime name: []const u8) ?*Section {
        for (self.sections.span()) |*sec| {
            if (mem.eql(u8, sec.header.name[0..name.len], name)) {
                return sec;
            }
        }
        return null;
    }
};

const CoffHeader = struct {
    machine: u16,
    number_of_sections: u16,
    timedate_stamp: u32,
    pointer_to_symbol_table: u32,
    number_of_symbols: u32,
    size_of_optional_header: u16,
    characteristics: u16,
};

const OptionalHeader = struct {
    const DataDirectory = struct {
        virtual_address: u32,
        size: u32,
    };

    magic: u16,
    data_directory: [IMAGE_NUMBEROF_DIRECTORY_ENTRIES]DataDirectory,
};

const DebugDirectoryEntry = packed struct {
    characteristiccs: u32,
    time_date_stamp: u32,
    major_version: u16,
    minor_version: u16,
    @"type": u32,
    size_of_data: u32,
    address_of_raw_data: u32,
    pointer_to_raw_data: u32,
};

pub const Section = struct {
    header: SectionHeader,
};

const SectionHeader = struct {
    const Misc = union {
        physical_address: u32,
        virtual_size: u32,
    };

    name: [8]u8,
    misc: Misc,
    virtual_address: u32,
    size_of_raw_data: u32,
    pointer_to_raw_data: u32,
    pointer_to_relocations: u32,
    pointer_to_line_numbers: u32,
    number_of_relocations: u16,
    number_of_line_numbers: u16,
    characteristics: u32,
};
