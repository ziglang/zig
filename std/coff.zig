const builtin = @import("builtin");
const std = @import("index.zig");
const io = std.io;
const mem = std.mem;
const os = std.os;

const ArrayList = std.ArrayList;

// CoffHeader.machine values
// see https://msdn.microsoft.com/en-us/library/windows/desktop/ms680313(v=vs.85).aspx
const IMAGE_FILE_MACHINE_I386   = 0x014c;
const IMAGE_FILE_MACHINE_IA64   = 0x0200;
const IMAGE_FILE_MACHINE_AMD64  = 0x8664;

// OptionalHeader.magic values
// see https://msdn.microsoft.com/en-us/library/windows/desktop/ms680339(v=vs.85).aspx
const IMAGE_NT_OPTIONAL_HDR32_MAGIC = 0x10b;
const IMAGE_NT_OPTIONAL_HDR64_MAGIC = 0x20b;

const IMAGE_NUMBEROF_DIRECTORY_ENTRIES = 16;
const DEBUG_DIRECTORY = 6;

pub const CoffError = error {
    InvalidPEMagic,
    InvalidPEHeader,
    InvalidMachine,
    MissingCoffSection,
};

pub const Coff = struct {
    in_file: os.File,
    allocator: *mem.Allocator,

    coff_header: CoffHeader,
    pe_header: OptionalHeader,
    sections: ArrayList(Section),

    guid: [16]u8,
    age: u32,

    pub fn loadHeader(self: *Coff) !void {
        const pe_pointer_offset = 0x3C;

        var file_stream = io.FileInStream.init(&self.in_file);
        const in = &file_stream.stream;

        var magic: [2]u8 = undefined;
        try in.readNoEof(magic[0..]);
        if (!mem.eql(u8, magic, "MZ"))
            return error.InvalidPEMagic;

        // Seek to PE File Header (coff header)
        try self.in_file.seekTo(pe_pointer_offset);
        const pe_magic_offset = try in.readIntLe(u32);
        try self.in_file.seekTo(pe_magic_offset);

        var pe_header_magic: [4]u8 = undefined;
        try in.readNoEof(pe_header_magic[0..]);
        if (!mem.eql(u8, pe_header_magic, []u8{'P', 'E', 0, 0}))
            return error.InvalidPEHeader;

        self.coff_header = CoffHeader {
            .machine = try in.readIntLe(u16),
            .number_of_sections = try in.readIntLe(u16),           
            .timedate_stamp = try in.readIntLe(u32),           
            .pointer_to_symbol_table = try in.readIntLe(u32),           
            .number_of_symbols = try in.readIntLe(u32),           
            .size_of_optional_header = try in.readIntLe(u16),           
            .characteristics = try in.readIntLe(u16),           
        };

        switch (self.coff_header.machine) {
            IMAGE_FILE_MACHINE_I386,
            IMAGE_FILE_MACHINE_AMD64,
            IMAGE_FILE_MACHINE_IA64
                => {},
            else => return error.InvalidMachine,
        }

        try self.loadOptionalHeader(&file_stream);
    }

    fn loadOptionalHeader(self: *Coff, file_stream: *io.FileInStream) !void {
        const in = &file_stream.stream;
        self.pe_header.magic = try in.readIntLe(u16);
        std.debug.warn("reading pe optional\n");
        // For now we're only interested in finding the reference to the .pdb,
        // so we'll skip most of this header, which size is different in 32
        // 64 bits by the way.
        var skip_size: u16 = undefined;
        if (self.pe_header.magic == IMAGE_NT_OPTIONAL_HDR32_MAGIC) {
            skip_size = 2 * @sizeOf(u8) + 8 * @sizeOf(u16) + 18 * @sizeOf(u32);
        }
        else if (self.pe_header.magic == IMAGE_NT_OPTIONAL_HDR64_MAGIC) {
            skip_size = 2 * @sizeOf(u8) + 8 * @sizeOf(u16) + 12 * @sizeOf(u32) + 5 * @sizeOf(u64);
        }
        else
            return error.InvalidPEMagic;

        std.debug.warn("skipping {}\n", skip_size);
        try self.in_file.seekForward(skip_size);

        const number_of_rva_and_sizes = try in.readIntLe(u32);
        //std.debug.warn("indicating {} data dirs\n", number_of_rva_and_sizes);
        if (number_of_rva_and_sizes != IMAGE_NUMBEROF_DIRECTORY_ENTRIES)
            return error.InvalidPEHeader;

        for (self.pe_header.data_directory) |*data_dir| {
            data_dir.* = OptionalHeader.DataDirectory {
                .virtual_address = try in.readIntLe(u32),
                .size = try in.readIntLe(u32),
            };
            //std.debug.warn("data_dir @ {x}, size {}\n", data_dir.virtual_address, data_dir.size);
        }
        std.debug.warn("loaded data directories\n");
    }

    pub fn getPdbPath(self: *Coff, buffer: []u8) !usize {
        try self.loadSections();
        const header = (self.getSection(".rdata") orelse return error.MissingCoffSection).header;

        // The linker puts a chunk that contains the .pdb path right after the 
        // debug_directory.
        const debug_dir = &self.pe_header.data_directory[DEBUG_DIRECTORY];
        const file_offset = debug_dir.virtual_address - header.virtual_address + header.pointer_to_raw_data;
        std.debug.warn("file offset {x}\n", file_offset);
        try self.in_file.seekTo(file_offset + debug_dir.size);

        var file_stream = io.FileInStream.init(&self.in_file);
        const in = &file_stream.stream;

        var cv_signature: [4]u8 = undefined; // CodeView signature
        try in.readNoEof(cv_signature[0..]);
        // 'RSDS' indicates PDB70 format, used by lld.
        if (!mem.eql(u8, cv_signature, "RSDS"))
            return error.InvalidPEMagic;
        std.debug.warn("cv_signature {}\n", cv_signature);
        try in.readNoEof(self.guid[0..]);
        self.age = try in.readIntLe(u32);

        // Finally read the null-terminated string.
        var byte = try in.readByte();
        var i: usize = 0;
        while (byte != 0 and i < buffer.len) : (i += 1) {
            buffer[i] = byte;
            byte = try in.readByte();
        }

        if (byte != 0 and i == buffer.len)
            return error.NameTooLong;

        return i;
    }

    pub fn loadSections(self: *Coff) !void {
        if (self.sections.len != 0)
            return;

        self.sections = ArrayList(Section).init(self.allocator);

        var file_stream = io.FileInStream.init(&self.in_file);
        const in = &file_stream.stream;

        var name: [8]u8 = undefined;

        var i: u16 = 0;
        while (i < self.coff_header.number_of_sections) : (i += 1) {
            try in.readNoEof(name[0..]);
            try self.sections.append(Section {
                .header = SectionHeader {
                    .name = name,
                    .misc = SectionHeader.Misc { .physical_address = try in.readIntLe(u32) },
                    .virtual_address = try in.readIntLe(u32),
                    .size_of_raw_data = try in.readIntLe(u32),
                    .pointer_to_raw_data = try in.readIntLe(u32),
                    .pointer_to_relocations = try in.readIntLe(u32),
                    .pointer_to_line_numbers = try in.readIntLe(u32),
                    .number_of_relocations = try in.readIntLe(u16),
                    .number_of_line_numbers = try in.readIntLe(u16),
                    .characteristics = try in.readIntLe(u32),
                },
            });
        }
        std.debug.warn("loaded {} sections\n", self.coff_header.number_of_sections);
    }

    pub fn getSection(self: *Coff, comptime name: []const u8) ?*Section {
        for (self.sections.toSlice()) |*sec| {
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
    characteristics: u16
};

const OptionalHeader = struct {
    const DataDirectory = struct {
        virtual_address: u32,
        size: u32
    };

    magic: u16,
    data_directory: [IMAGE_NUMBEROF_DIRECTORY_ENTRIES]DataDirectory,
};

const Section = struct {
    header: SectionHeader,
};

const SectionHeader = struct {
    const Misc = union {
        physical_address: u32,
        virtual_size: u32
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