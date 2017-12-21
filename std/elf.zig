const builtin = @import("builtin");
const std = @import("index.zig");
const io = std.io;
const math = std.math;
const mem = std.mem;
const debug = std.debug;
const InStream = std.stream.InStream;

error InvalidFormat;

pub const SHT_NULL = 0;
pub const SHT_PROGBITS = 1;
pub const SHT_SYMTAB = 2;
pub const SHT_STRTAB = 3;
pub const SHT_RELA = 4;
pub const SHT_HASH = 5;
pub const SHT_DYNAMIC = 6;
pub const SHT_NOTE = 7;
pub const SHT_NOBITS = 8;
pub const SHT_REL = 9;
pub const SHT_SHLIB = 10;
pub const SHT_DYNSYM = 11;
pub const SHT_INIT_ARRAY = 14;
pub const SHT_FINI_ARRAY = 15;
pub const SHT_PREINIT_ARRAY = 16;
pub const SHT_GROUP = 17;
pub const SHT_SYMTAB_SHNDX = 18;
pub const SHT_LOOS = 0x60000000;
pub const SHT_HIOS = 0x6fffffff;
pub const SHT_LOPROC = 0x70000000;
pub const SHT_HIPROC = 0x7fffffff;
pub const SHT_LOUSER = 0x80000000;
pub const SHT_HIUSER = 0xffffffff;

pub const FileType = enum {
    Relocatable,
    Executable,
    Shared,
    Core,
};

pub const Arch = enum {
    Sparc,
    x86,
    Mips,
    PowerPc,
    Arm,
    SuperH,
    IA_64,
    x86_64,
    AArch64,
};

pub const SectionHeader = struct {
    name: u32,
    sh_type: u32,
    flags: u64,
    addr: u64,
    offset: u64,
    size: u64,
    link: u32,
    info: u32,
    addr_align: u64,
    ent_size: u64,
};

pub const Elf = struct {
    in_file: &io.File,
    auto_close_stream: bool,
    is_64: bool,
    endian: builtin.Endian,
    file_type: FileType,
    arch: Arch,
    entry_addr: u64,
    program_header_offset: u64,
    section_header_offset: u64,
    string_section_index: u64,
    string_section: &SectionHeader,
    section_headers: []SectionHeader,
    allocator: &mem.Allocator,
    prealloc_file: io.File,

    /// Call close when done.
    pub fn openPath(elf: &Elf, allocator: &mem.Allocator, path: []const u8) -> %void {
        %return elf.prealloc_file.open(path);
        %return elf.openFile(allocator, &elf.prealloc_file);
        elf.auto_close_stream = true;
    }

    /// Call close when done.
    pub fn openFile(elf: &Elf, allocator: &mem.Allocator, file: &io.File) -> %void {
        elf.allocator = allocator;
        elf.in_file = file;
        elf.auto_close_stream = false;

        var file_stream = io.FileInStream.init(elf.in_file);
        const in = &file_stream.stream;

        var magic: [4]u8 = undefined;
        %return in.readNoEof(magic[0..]);
        if (!mem.eql(u8, magic, "\x7fELF")) return error.InvalidFormat;

        elf.is_64 = switch (%return in.readByte()) {
            1 => false,
            2 => true,
            else => return error.InvalidFormat,
        };

        elf.endian = switch (%return in.readByte()) {
            1 => builtin.Endian.Little,
            2 => builtin.Endian.Big,
            else => return error.InvalidFormat,
        };

        const version_byte = %return in.readByte();
        if (version_byte != 1) return error.InvalidFormat;

        // skip over padding
        %return elf.in_file.seekForward(9);

        elf.file_type = switch (%return in.readInt(elf.endian, u16)) {
            1 => FileType.Relocatable,
            2 => FileType.Executable,
            3 => FileType.Shared,
            4 => FileType.Core,
            else => return error.InvalidFormat,
        };

        elf.arch = switch (%return in.readInt(elf.endian, u16)) {
            0x02 => Arch.Sparc,
            0x03 => Arch.x86,
            0x08 => Arch.Mips,
            0x14 => Arch.PowerPc,
            0x28 => Arch.Arm,
            0x2A => Arch.SuperH,
            0x32 => Arch.IA_64,
            0x3E => Arch.x86_64,
            0xb7 => Arch.AArch64,
            else => return error.InvalidFormat,
        };

        const elf_version = %return in.readInt(elf.endian, u32);
        if (elf_version != 1) return error.InvalidFormat;

        if (elf.is_64) {
            elf.entry_addr = %return in.readInt(elf.endian, u64);
            elf.program_header_offset = %return in.readInt(elf.endian, u64);
            elf.section_header_offset = %return in.readInt(elf.endian, u64);
        } else {
            elf.entry_addr = u64(%return in.readInt(elf.endian, u32));
            elf.program_header_offset = u64(%return in.readInt(elf.endian, u32));
            elf.section_header_offset = u64(%return in.readInt(elf.endian, u32));
        }

        // skip over flags
        %return elf.in_file.seekForward(4);

        const header_size = %return in.readInt(elf.endian, u16);
        if ((elf.is_64 and header_size != 64) or
            (!elf.is_64 and header_size != 52))
        {
            return error.InvalidFormat;
        }

        const ph_entry_size = %return in.readInt(elf.endian, u16);
        const ph_entry_count = %return in.readInt(elf.endian, u16);
        const sh_entry_size = %return in.readInt(elf.endian, u16);
        const sh_entry_count = %return in.readInt(elf.endian, u16);
        elf.string_section_index = u64(%return in.readInt(elf.endian, u16));

        if (elf.string_section_index >= sh_entry_count) return error.InvalidFormat;

        const sh_byte_count = u64(sh_entry_size) * u64(sh_entry_count);
        const end_sh = %return math.add(u64, elf.section_header_offset, sh_byte_count);
        const ph_byte_count = u64(ph_entry_size) * u64(ph_entry_count);
        const end_ph = %return math.add(u64, elf.program_header_offset, ph_byte_count);

        const stream_end = %return elf.in_file.getEndPos();
        if (stream_end < end_sh or stream_end < end_ph) {
            return error.InvalidFormat;
        }

        %return elf.in_file.seekTo(elf.section_header_offset);

        elf.section_headers = %return elf.allocator.alloc(SectionHeader, sh_entry_count);
        %defer elf.allocator.free(elf.section_headers);

        if (elf.is_64) {
            if (sh_entry_size != 64) return error.InvalidFormat;

            for (elf.section_headers) |*elf_section| {
                elf_section.name         = %return in.readInt(elf.endian, u32);
                elf_section.sh_type      = %return in.readInt(elf.endian, u32);
                elf_section.flags        = %return in.readInt(elf.endian, u64);
                elf_section.addr         = %return in.readInt(elf.endian, u64);
                elf_section.offset       = %return in.readInt(elf.endian, u64);
                elf_section.size         = %return in.readInt(elf.endian, u64);
                elf_section.link         = %return in.readInt(elf.endian, u32);
                elf_section.info         = %return in.readInt(elf.endian, u32);
                elf_section.addr_align   = %return in.readInt(elf.endian, u64);
                elf_section.ent_size     = %return in.readInt(elf.endian, u64);
            }
        } else {
            if (sh_entry_size != 40) return error.InvalidFormat;

            for (elf.section_headers) |*elf_section| {
                // TODO (multiple occurences) allow implicit cast from %u32 -> %u64 ?
                elf_section.name = %return in.readInt(elf.endian, u32);
                elf_section.sh_type = %return in.readInt(elf.endian, u32);
                elf_section.flags = u64(%return in.readInt(elf.endian, u32));
                elf_section.addr = u64(%return in.readInt(elf.endian, u32));
                elf_section.offset = u64(%return in.readInt(elf.endian, u32));
                elf_section.size = u64(%return in.readInt(elf.endian, u32));
                elf_section.link = %return in.readInt(elf.endian, u32);
                elf_section.info = %return in.readInt(elf.endian, u32);
                elf_section.addr_align = u64(%return in.readInt(elf.endian, u32));
                elf_section.ent_size = u64(%return in.readInt(elf.endian, u32));
            }
        }

        for (elf.section_headers) |*elf_section| {
            if (elf_section.sh_type != SHT_NOBITS) {
                const file_end_offset = %return math.add(u64, elf_section.offset, elf_section.size);
                if (stream_end < file_end_offset) return error.InvalidFormat;
            }
        }

        elf.string_section = &elf.section_headers[elf.string_section_index];
        if (elf.string_section.sh_type != SHT_STRTAB) {
            // not a string table
            return error.InvalidFormat;
        }
    }

    pub fn close(elf: &Elf) {
        elf.allocator.free(elf.section_headers);

        if (elf.auto_close_stream)
            elf.in_file.close();
    }

    pub fn findSection(elf: &Elf, name: []const u8) -> %?&SectionHeader {
        var file_stream = io.FileInStream.init(elf.in_file);
        const in = &file_stream.stream;

        section_loop: for (elf.section_headers) |*elf_section| {
            if (elf_section.sh_type == SHT_NULL) continue;

            const name_offset = elf.string_section.offset + elf_section.name;
            %return elf.in_file.seekTo(name_offset);

            for (name) |expected_c| {
                const target_c = %return in.readByte();
                if (target_c == 0 or expected_c != target_c) continue :section_loop;
            }

            {
                const null_byte = %return in.readByte();
                if (null_byte == 0) return elf_section;
            }
        }

        return null;
    }

    pub fn seekToSection(elf: &Elf, elf_section: &SectionHeader) -> %void {
        %return elf.in_file.seekTo(elf_section.offset);
    }
};
