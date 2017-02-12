const io = @import("io.zig");
const math = @import("math.zig");
const mem = @import("mem.zig");
const debug = @import("debug.zig");

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

// TODO rename this to Arch when the builtin Arch enum is namespaced
// or make debug info work for builtin enums
pub const ElfArch = enum {
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
    in_stream: &io.InStream,
    auto_close_stream: bool,
    is_64: bool,
    is_big_endian: bool,
    file_type: FileType,
    arch: ElfArch,
    entry_addr: u64,
    program_header_offset: u64,
    section_header_offset: u64,
    string_section_index: u64,
    string_section: &SectionHeader,
    section_headers: []SectionHeader,
    allocator: &mem.Allocator,
    prealloc_stream: io.InStream,

    /// Call close when done.
    pub fn openFile(elf: &Elf, allocator: &mem.Allocator, path: []const u8) -> %void {
        %return elf.prealloc_stream.open(path);
        %return elf.openStream(allocator, &elf.prealloc_stream);
        elf.auto_close_stream = true;
    }

    /// Call close when done.
    pub fn openStream(elf: &Elf, allocator: &mem.Allocator, stream: &io.InStream) -> %void {
        elf.allocator = allocator;
        elf.in_stream = stream;
        elf.auto_close_stream = false;

        var magic: [4]u8 = undefined;
        %return elf.in_stream.readNoEof(magic[0...]);
        if (!mem.eql(u8, magic, "\x7fELF")) return error.InvalidFormat;

        elf.is_64 = switch (%return elf.in_stream.readByte()) {
            1 => false,
            2 => true,
            else => return error.InvalidFormat,
        };

        elf.is_big_endian = switch (%return elf.in_stream.readByte()) {
            1 => false,
            2 => true,
            else => return error.InvalidFormat,
        };

        const version_byte = %return elf.in_stream.readByte();
        if (version_byte != 1) return error.InvalidFormat;

        // skip over padding
        %return elf.in_stream.seekForward(9);

        elf.file_type = switch (%return elf.in_stream.readInt(elf.is_big_endian, u16)) {
            1 => FileType.Relocatable,
            2 => FileType.Executable,
            3 => FileType.Shared,
            4 => FileType.Core,
            else => return error.InvalidFormat,
        };

        elf.arch = switch (%return elf.in_stream.readInt(elf.is_big_endian, u16)) {
            0x02 => ElfArch.Sparc,
            0x03 => ElfArch.x86,
            0x08 => ElfArch.Mips,
            0x14 => ElfArch.PowerPc,
            0x28 => ElfArch.Arm,
            0x2A => ElfArch.SuperH,
            0x32 => ElfArch.IA_64,
            0x3E => ElfArch.x86_64,
            0xb7 => ElfArch.AArch64,
            else => return error.InvalidFormat,
        };

        const elf_version = %return elf.in_stream.readInt(elf.is_big_endian, u32);
        if (elf_version != 1) return error.InvalidFormat;

        if (elf.is_64) {
            elf.entry_addr = %return elf.in_stream.readInt(elf.is_big_endian, u64);
            elf.program_header_offset = %return elf.in_stream.readInt(elf.is_big_endian, u64);
            elf.section_header_offset = %return elf.in_stream.readInt(elf.is_big_endian, u64);
        } else {
            elf.entry_addr = u64(%return elf.in_stream.readInt(elf.is_big_endian, u32));
            elf.program_header_offset = u64(%return elf.in_stream.readInt(elf.is_big_endian, u32));
            elf.section_header_offset = u64(%return elf.in_stream.readInt(elf.is_big_endian, u32));
        }

        // skip over flags
        %return elf.in_stream.seekForward(4);

        const header_size = %return elf.in_stream.readInt(elf.is_big_endian, u16);
        if ((elf.is_64 && header_size != 64) ||
            (!elf.is_64 && header_size != 52))
        {
            return error.InvalidFormat;
        }

        const ph_entry_size = %return elf.in_stream.readInt(elf.is_big_endian, u16);
        const ph_entry_count = %return elf.in_stream.readInt(elf.is_big_endian, u16);
        const sh_entry_size = %return elf.in_stream.readInt(elf.is_big_endian, u16);
        const sh_entry_count = %return elf.in_stream.readInt(elf.is_big_endian, u16);
        elf.string_section_index = u64(%return elf.in_stream.readInt(elf.is_big_endian, u16));

        if (elf.string_section_index >= sh_entry_count) return error.InvalidFormat;

        const sh_byte_count = u64(sh_entry_size) * u64(sh_entry_count);
        const end_sh = %return math.addOverflow(u64, elf.section_header_offset, sh_byte_count);
        const ph_byte_count = u64(ph_entry_size) * u64(ph_entry_count);
        const end_ph = %return math.addOverflow(u64, elf.program_header_offset, ph_byte_count);

        const stream_end = %return elf.in_stream.getEndPos();
        if (stream_end < end_sh || stream_end < end_ph) {
            return error.InvalidFormat;
        }

        %return elf.in_stream.seekTo(elf.section_header_offset);

        elf.section_headers = %return elf.allocator.alloc(SectionHeader, sh_entry_count);
        %defer elf.allocator.free(elf.section_headers);

        if (elf.is_64) {
            if (sh_entry_size != 64) return error.InvalidFormat;

            for (elf.section_headers) |*section| {
                section.name         = %return elf.in_stream.readInt(elf.is_big_endian, u32);
                section.sh_type      = %return elf.in_stream.readInt(elf.is_big_endian, u32);
                section.flags        = %return elf.in_stream.readInt(elf.is_big_endian, u64);
                section.addr         = %return elf.in_stream.readInt(elf.is_big_endian, u64);
                section.offset       = %return elf.in_stream.readInt(elf.is_big_endian, u64);
                section.size         = %return elf.in_stream.readInt(elf.is_big_endian, u64);
                section.link         = %return elf.in_stream.readInt(elf.is_big_endian, u32);
                section.info         = %return elf.in_stream.readInt(elf.is_big_endian, u32);
                section.addr_align   = %return elf.in_stream.readInt(elf.is_big_endian, u64);
                section.ent_size     = %return elf.in_stream.readInt(elf.is_big_endian, u64);
            }
        } else {
            if (sh_entry_size != 40) return error.InvalidFormat;

            for (elf.section_headers) |*section| {
                // TODO (multiple occurences) allow implicit cast from %u32 -> %u64 ?
                section.name = %return elf.in_stream.readInt(elf.is_big_endian, u32);
                section.sh_type = %return elf.in_stream.readInt(elf.is_big_endian, u32);
                section.flags = u64(%return elf.in_stream.readInt(elf.is_big_endian, u32));
                section.addr = u64(%return elf.in_stream.readInt(elf.is_big_endian, u32));
                section.offset = u64(%return elf.in_stream.readInt(elf.is_big_endian, u32));
                section.size = u64(%return elf.in_stream.readInt(elf.is_big_endian, u32));
                section.link = %return elf.in_stream.readInt(elf.is_big_endian, u32);
                section.info = %return elf.in_stream.readInt(elf.is_big_endian, u32);
                section.addr_align = u64(%return elf.in_stream.readInt(elf.is_big_endian, u32));
                section.ent_size = u64(%return elf.in_stream.readInt(elf.is_big_endian, u32));
            }
        }

        for (elf.section_headers) |*section| {
            if (section.sh_type != SHT_NOBITS) {
                const file_end_offset = %return math.addOverflow(u64,
                    section.offset, section.size);
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
            elf.in_stream.close();
    }

    pub fn findSection(elf: &Elf, name: []const u8) -> %?&SectionHeader {
        for (elf.section_headers) |*section| {
            if (section.sh_type == SHT_NULL) continue;

            const name_offset = elf.string_section.offset + section.name;
            %return elf.in_stream.seekTo(name_offset);

            for (name) |expected_c| {
                const target_c = %return elf.in_stream.readByte();
                if (target_c == 0 || expected_c != target_c) goto next_section;
            }

            {
                const null_byte = %return elf.in_stream.readByte();
                if (null_byte == 0) return (?&SectionHeader)(section);
            }

            next_section:
        }

        const null_sh: ?&SectionHeader = null;
        return null_sh;
    }

    pub fn seekToSection(elf: &Elf, section: &SectionHeader) -> %void {
        %return elf.in_stream.seekTo(section.offset);
    }
};
