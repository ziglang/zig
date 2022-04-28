const std = @import("std.zig");
const io = std.io;
const mem = std.mem;
const os = std.os;
const File = std.fs.File;

// CoffHeader.machine values
// see https://msdn.microsoft.com/en-us/library/windows/desktop/ms680313(v=vs.85).aspx
const IMAGE_FILE_MACHINE_I386 = 0x014c;
const IMAGE_FILE_MACHINE_IA64 = 0x0200;
const IMAGE_FILE_MACHINE_AMD64 = 0x8664;

pub const MachineType = enum(u16) {
    Unknown = 0x0,
    /// Matsushita AM33
    AM33 = 0x1d3,
    /// x64
    X64 = 0x8664,
    /// ARM little endian
    ARM = 0x1c0,
    /// ARM64 little endian
    ARM64 = 0xaa64,
    /// ARM Thumb-2 little endian
    ARMNT = 0x1c4,
    /// EFI byte code
    EBC = 0xebc,
    /// Intel 386 or later processors and compatible processors
    I386 = 0x14c,
    /// Intel Itanium processor family
    IA64 = 0x200,
    /// Mitsubishi M32R little endian
    M32R = 0x9041,
    /// MIPS16
    MIPS16 = 0x266,
    /// MIPS with FPU
    MIPSFPU = 0x366,
    /// MIPS16 with FPU
    MIPSFPU16 = 0x466,
    /// Power PC little endian
    POWERPC = 0x1f0,
    /// Power PC with floating point support
    POWERPCFP = 0x1f1,
    /// MIPS little endian
    R4000 = 0x166,
    /// RISC-V 32-bit address space
    RISCV32 = 0x5032,
    /// RISC-V 64-bit address space
    RISCV64 = 0x5064,
    /// RISC-V 128-bit address space
    RISCV128 = 0x5128,
    /// Hitachi SH3
    SH3 = 0x1a2,
    /// Hitachi SH3 DSP
    SH3DSP = 0x1a3,
    /// Hitachi SH4
    SH4 = 0x1a6,
    /// Hitachi SH5
    SH5 = 0x1a8,
    /// Thumb
    Thumb = 0x1c2,
    /// MIPS little-endian WCE v2
    WCEMIPSV2 = 0x169,

    pub fn toTargetCpuArch(machine_type: MachineType) ?std.Target.Cpu.Arch {
        return switch (machine_type) {
            .ARM => .arm,
            .POWERPC => .powerpc,
            .RISCV32 => .riscv32,
            .Thumb => .thumb,
            .I386 => .i386,
            .ARM64 => .aarch64,
            .RISCV64 => .riscv64,
            .X64 => .x86_64,
            // there's cases we don't (yet) handle
            else => null,
        };
    }
};

// OptionalHeader.magic values
// see https://msdn.microsoft.com/en-us/library/windows/desktop/ms680339(v=vs.85).aspx
const IMAGE_NT_OPTIONAL_HDR32_MAGIC = 0x10b;
const IMAGE_NT_OPTIONAL_HDR64_MAGIC = 0x20b;

// Image Characteristics
pub const IMAGE_FILE_RELOCS_STRIPPED = 0x1;
pub const IMAGE_FILE_DEBUG_STRIPPED = 0x200;
pub const IMAGE_FILE_EXECUTABLE_IMAGE = 0x2;
pub const IMAGE_FILE_32BIT_MACHINE = 0x100;
pub const IMAGE_FILE_LARGE_ADDRESS_AWARE = 0x20;

// Section flags
pub const IMAGE_SCN_CNT_INITIALIZED_DATA = 0x40;
pub const IMAGE_SCN_MEM_READ = 0x40000000;
pub const IMAGE_SCN_CNT_CODE = 0x20;
pub const IMAGE_SCN_MEM_EXECUTE = 0x20000000;
pub const IMAGE_SCN_MEM_WRITE = 0x80000000;

const IMAGE_NUMBEROF_DIRECTORY_ENTRIES = 16;
const IMAGE_DEBUG_TYPE_CODEVIEW = 2;
const DEBUG_DIRECTORY = 6;

pub const CoffError = error{
    InvalidPEMagic,
    InvalidPEHeader,
    InvalidMachine,
    MissingCoffSection,
    MissingStringTable,
};

// Official documentation of the format: https://docs.microsoft.com/en-us/windows/win32/debug/pe-format
pub const Coff = struct {
    in_file: File,
    allocator: mem.Allocator,

    coff_header: CoffHeader,
    pe_header: OptionalHeader,
    sections: std.ArrayListUnmanaged(Section) = .{},

    guid: [16]u8,
    age: u32,

    pub fn init(allocator: mem.Allocator, in_file: File) Coff {
        return Coff{
            .in_file = in_file,
            .allocator = allocator,
            .coff_header = undefined,
            .pe_header = undefined,
            .guid = undefined,
            .age = undefined,
        };
    }

    pub fn deinit(self: *Coff) void {
        self.sections.deinit(self.allocator);
    }

    pub fn loadHeader(self: *Coff) !void {
        const pe_pointer_offset = 0x3C;

        const in = self.in_file.reader();

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

    fn readStringFromTable(self: *Coff, offset: usize, buf: []u8) ![]const u8 {
        if (self.coff_header.pointer_to_symbol_table == 0) {
            // No symbol table therefore no string table
            return error.MissingStringTable;
        }
        // The string table is at the end of the symbol table and symbols are 18 bytes long
        const string_table_offset = self.coff_header.pointer_to_symbol_table + (self.coff_header.number_of_symbols * 18) + offset;
        const in = self.in_file.reader();
        const old_pos = try self.in_file.getPos();

        try self.in_file.seekTo(string_table_offset);
        defer {
            self.in_file.seekTo(old_pos) catch unreachable;
        }

        const str = try in.readUntilDelimiterOrEof(buf, 0);
        return str orelse "";
    }

    fn loadOptionalHeader(self: *Coff) !void {
        const in = self.in_file.reader();
        const opt_header_pos = try self.in_file.getPos();

        self.pe_header.magic = try in.readIntLittle(u16);
        try self.in_file.seekTo(opt_header_pos + 16);
        self.pe_header.entry_addr = try in.readIntLittle(u32);
        try self.in_file.seekTo(opt_header_pos + 20);
        self.pe_header.code_base = try in.readIntLittle(u32);

        // The header structure is different for 32 or 64 bit
        var num_rva_pos: u64 = undefined;
        if (self.pe_header.magic == IMAGE_NT_OPTIONAL_HDR32_MAGIC) {
            num_rva_pos = opt_header_pos + 92;

            try self.in_file.seekTo(opt_header_pos + 28);
            const image_base32 = try in.readIntLittle(u32);
            self.pe_header.image_base = image_base32;
        } else if (self.pe_header.magic == IMAGE_NT_OPTIONAL_HDR64_MAGIC) {
            num_rva_pos = opt_header_pos + 108;

            try self.in_file.seekTo(opt_header_pos + 24);
            self.pe_header.image_base = try in.readIntLittle(u64);
        } else return error.InvalidPEMagic;

        try self.in_file.seekTo(num_rva_pos);

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

        const in = self.in_file.reader();
        try self.in_file.seekTo(file_offset);

        // Find the correct DebugDirectoryEntry, and where its data is stored.
        // It can be in any section.
        const debug_dir_entry_count = debug_dir.size / @sizeOf(DebugDirectoryEntry);
        var i: u32 = 0;
        blk: while (i < debug_dir_entry_count) : (i += 1) {
            const debug_dir_entry = try in.readStruct(DebugDirectoryEntry);
            if (debug_dir_entry.type == IMAGE_DEBUG_TYPE_CODEVIEW) {
                for (self.sections.items) |*section| {
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

        try self.sections.ensureTotalCapacityPrecise(self.allocator, self.coff_header.number_of_sections);

        const in = self.in_file.reader();

        var name: [32]u8 = undefined;

        var i: u16 = 0;
        while (i < self.coff_header.number_of_sections) : (i += 1) {
            try in.readNoEof(name[0..8]);

            if (name[0] == '/') {
                // This is a long name and stored in the string table
                const offset_len = mem.indexOfScalar(u8, name[1..], 0) orelse 7;

                const str_offset = try std.fmt.parseInt(u32, name[1 .. offset_len + 1], 10);
                const str = try self.readStringFromTable(str_offset, &name);
                std.mem.set(u8, name[str.len..], 0);
            } else {
                std.mem.set(u8, name[8..], 0);
            }

            self.sections.appendAssumeCapacity(Section{
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
        for (self.sections.items) |*sec| {
            if (mem.eql(u8, sec.header.name[0..name.len], name)) {
                return sec;
            }
        }
        return null;
    }

    // Return an owned slice full of the section data
    pub fn getSectionData(self: *Coff, comptime name: []const u8, allocator: mem.Allocator) ![]u8 {
        const sec = for (self.sections.items) |*sec| {
            if (mem.eql(u8, sec.header.name[0..name.len], name)) {
                break sec;
            }
        } else {
            return error.MissingCoffSection;
        };
        const in = self.in_file.reader();
        try self.in_file.seekTo(sec.header.pointer_to_raw_data);
        const out_buff = try allocator.alloc(u8, sec.header.misc.virtual_size);
        try in.readNoEof(out_buff);
        return out_buff;
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
    entry_addr: u32,
    code_base: u32,
    image_base: u64,
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

    name: [32]u8,
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
