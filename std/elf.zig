const builtin = @import("builtin");
const std = @import("index.zig");
const io = std.io;
const os = std.os;
const math = std.math;
const mem = std.mem;
const debug = std.debug;
const InStream = std.stream.InStream;

pub const AT_NULL = 0;
pub const AT_IGNORE = 1;
pub const AT_EXECFD = 2;
pub const AT_PHDR = 3;
pub const AT_PHENT = 4;
pub const AT_PHNUM = 5;
pub const AT_PAGESZ = 6;
pub const AT_BASE = 7;
pub const AT_FLAGS = 8;
pub const AT_ENTRY = 9;
pub const AT_NOTELF = 10;
pub const AT_UID = 11;
pub const AT_EUID = 12;
pub const AT_GID = 13;
pub const AT_EGID = 14;
pub const AT_CLKTCK = 17;
pub const AT_PLATFORM = 15;
pub const AT_HWCAP = 16;
pub const AT_FPUCW = 18;
pub const AT_DCACHEBSIZE = 19;
pub const AT_ICACHEBSIZE = 20;
pub const AT_UCACHEBSIZE = 21;
pub const AT_IGNOREPPC = 22;
pub const AT_SECURE = 23;
pub const AT_BASE_PLATFORM = 24;
pub const AT_RANDOM = 25;
pub const AT_HWCAP2 = 26;
pub const AT_EXECFN = 31;
pub const AT_SYSINFO = 32;
pub const AT_SYSINFO_EHDR = 33;
pub const AT_L1I_CACHESHAPE = 34;
pub const AT_L1D_CACHESHAPE = 35;
pub const AT_L2_CACHESHAPE = 36;
pub const AT_L3_CACHESHAPE = 37;
pub const AT_L1I_CACHESIZE = 40;
pub const AT_L1I_CACHEGEOMETRY = 41;
pub const AT_L1D_CACHESIZE = 42;
pub const AT_L1D_CACHEGEOMETRY = 43;
pub const AT_L2_CACHESIZE = 44;
pub const AT_L2_CACHEGEOMETRY = 45;
pub const AT_L3_CACHESIZE = 46;
pub const AT_L3_CACHEGEOMETRY = 47;

pub const DT_NULL = 0;
pub const DT_NEEDED = 1;
pub const DT_PLTRELSZ = 2;
pub const DT_PLTGOT = 3;
pub const DT_HASH = 4;
pub const DT_STRTAB = 5;
pub const DT_SYMTAB = 6;
pub const DT_RELA = 7;
pub const DT_RELASZ = 8;
pub const DT_RELAENT = 9;
pub const DT_STRSZ = 10;
pub const DT_SYMENT = 11;
pub const DT_INIT = 12;
pub const DT_FINI = 13;
pub const DT_SONAME = 14;
pub const DT_RPATH = 15;
pub const DT_SYMBOLIC = 16;
pub const DT_REL = 17;
pub const DT_RELSZ = 18;
pub const DT_RELENT = 19;
pub const DT_PLTREL = 20;
pub const DT_DEBUG = 21;
pub const DT_TEXTREL = 22;
pub const DT_JMPREL = 23;
pub const DT_BIND_NOW = 24;
pub const DT_INIT_ARRAY = 25;
pub const DT_FINI_ARRAY = 26;
pub const DT_INIT_ARRAYSZ = 27;
pub const DT_FINI_ARRAYSZ = 28;
pub const DT_RUNPATH = 29;
pub const DT_FLAGS = 30;
pub const DT_ENCODING = 32;
pub const DT_PREINIT_ARRAY = 32;
pub const DT_PREINIT_ARRAYSZ = 33;
pub const DT_SYMTAB_SHNDX = 34;
pub const DT_NUM = 35;
pub const DT_LOOS = 0x6000000d;
pub const DT_HIOS = 0x6ffff000;
pub const DT_LOPROC = 0x70000000;
pub const DT_HIPROC = 0x7fffffff;
pub const DT_PROCNUM = DT_MIPS_NUM;

pub const DT_VALRNGLO = 0x6ffffd00;
pub const DT_GNU_PRELINKED = 0x6ffffdf5;
pub const DT_GNU_CONFLICTSZ = 0x6ffffdf6;
pub const DT_GNU_LIBLISTSZ = 0x6ffffdf7;
pub const DT_CHECKSUM = 0x6ffffdf8;
pub const DT_PLTPADSZ = 0x6ffffdf9;
pub const DT_MOVEENT = 0x6ffffdfa;
pub const DT_MOVESZ = 0x6ffffdfb;
pub const DT_FEATURE_1 = 0x6ffffdfc;
pub const DT_POSFLAG_1 = 0x6ffffdfd;

pub const DT_SYMINSZ = 0x6ffffdfe;
pub const DT_SYMINENT = 0x6ffffdff;
pub const DT_VALRNGHI = 0x6ffffdff;
pub const DT_VALNUM = 12;

pub const DT_ADDRRNGLO = 0x6ffffe00;
pub const DT_GNU_HASH = 0x6ffffef5;
pub const DT_TLSDESC_PLT = 0x6ffffef6;
pub const DT_TLSDESC_GOT = 0x6ffffef7;
pub const DT_GNU_CONFLICT = 0x6ffffef8;
pub const DT_GNU_LIBLIST = 0x6ffffef9;
pub const DT_CONFIG = 0x6ffffefa;
pub const DT_DEPAUDIT = 0x6ffffefb;
pub const DT_AUDIT = 0x6ffffefc;
pub const DT_PLTPAD = 0x6ffffefd;
pub const DT_MOVETAB = 0x6ffffefe;
pub const DT_SYMINFO = 0x6ffffeff;
pub const DT_ADDRRNGHI = 0x6ffffeff;
pub const DT_ADDRNUM = 11;

pub const DT_VERSYM = 0x6ffffff0;

pub const DT_RELACOUNT = 0x6ffffff9;
pub const DT_RELCOUNT = 0x6ffffffa;

pub const DT_FLAGS_1 = 0x6ffffffb;
pub const DT_VERDEF = 0x6ffffffc;

pub const DT_VERDEFNUM = 0x6ffffffd;
pub const DT_VERNEED = 0x6ffffffe;

pub const DT_VERNEEDNUM = 0x6fffffff;
pub const DT_VERSIONTAGNUM = 16;

pub const DT_AUXILIARY = 0x7ffffffd;
pub const DT_FILTER = 0x7fffffff;
pub const DT_EXTRANUM = 3;

pub const DT_SPARC_REGISTER = 0x70000001;
pub const DT_SPARC_NUM = 2;

pub const DT_MIPS_RLD_VERSION = 0x70000001;
pub const DT_MIPS_TIME_STAMP = 0x70000002;
pub const DT_MIPS_ICHECKSUM = 0x70000003;
pub const DT_MIPS_IVERSION = 0x70000004;
pub const DT_MIPS_FLAGS = 0x70000005;
pub const DT_MIPS_BASE_ADDRESS = 0x70000006;
pub const DT_MIPS_MSYM = 0x70000007;
pub const DT_MIPS_CONFLICT = 0x70000008;
pub const DT_MIPS_LIBLIST = 0x70000009;
pub const DT_MIPS_LOCAL_GOTNO = 0x7000000a;
pub const DT_MIPS_CONFLICTNO = 0x7000000b;
pub const DT_MIPS_LIBLISTNO = 0x70000010;
pub const DT_MIPS_SYMTABNO = 0x70000011;
pub const DT_MIPS_UNREFEXTNO = 0x70000012;
pub const DT_MIPS_GOTSYM = 0x70000013;
pub const DT_MIPS_HIPAGENO = 0x70000014;
pub const DT_MIPS_RLD_MAP = 0x70000016;
pub const DT_MIPS_DELTA_CLASS = 0x70000017;
pub const DT_MIPS_DELTA_CLASS_NO = 0x70000018;

pub const DT_MIPS_DELTA_INSTANCE = 0x70000019;
pub const DT_MIPS_DELTA_INSTANCE_NO = 0x7000001a;

pub const DT_MIPS_DELTA_RELOC = 0x7000001b;
pub const DT_MIPS_DELTA_RELOC_NO = 0x7000001c;

pub const DT_MIPS_DELTA_SYM = 0x7000001d;

pub const DT_MIPS_DELTA_SYM_NO = 0x7000001e;

pub const DT_MIPS_DELTA_CLASSSYM = 0x70000020;

pub const DT_MIPS_DELTA_CLASSSYM_NO = 0x70000021;

pub const DT_MIPS_CXX_FLAGS = 0x70000022;
pub const DT_MIPS_PIXIE_INIT = 0x70000023;
pub const DT_MIPS_SYMBOL_LIB = 0x70000024;
pub const DT_MIPS_LOCALPAGE_GOTIDX = 0x70000025;
pub const DT_MIPS_LOCAL_GOTIDX = 0x70000026;
pub const DT_MIPS_HIDDEN_GOTIDX = 0x70000027;
pub const DT_MIPS_PROTECTED_GOTIDX = 0x70000028;
pub const DT_MIPS_OPTIONS = 0x70000029;
pub const DT_MIPS_INTERFACE = 0x7000002a;
pub const DT_MIPS_DYNSTR_ALIGN = 0x7000002b;
pub const DT_MIPS_INTERFACE_SIZE = 0x7000002c;
pub const DT_MIPS_RLD_TEXT_RESOLVE_ADDR = 0x7000002d;

pub const DT_MIPS_PERF_SUFFIX = 0x7000002e;

pub const DT_MIPS_COMPACT_SIZE = 0x7000002f;
pub const DT_MIPS_GP_VALUE = 0x70000030;
pub const DT_MIPS_AUX_DYNAMIC = 0x70000031;

pub const DT_MIPS_PLTGOT = 0x70000032;

pub const DT_MIPS_RWPLT = 0x70000034;
pub const DT_MIPS_RLD_MAP_REL = 0x70000035;
pub const DT_MIPS_NUM = 0x36;

pub const DT_ALPHA_PLTRO = (DT_LOPROC + 0);
pub const DT_ALPHA_NUM = 1;

pub const DT_PPC_GOT = (DT_LOPROC + 0);
pub const DT_PPC_OPT = (DT_LOPROC + 1);
pub const DT_PPC_NUM = 2;

pub const DT_PPC64_GLINK = (DT_LOPROC + 0);
pub const DT_PPC64_OPD = (DT_LOPROC + 1);
pub const DT_PPC64_OPDSZ = (DT_LOPROC + 2);
pub const DT_PPC64_OPT = (DT_LOPROC + 3);
pub const DT_PPC64_NUM = 4;

pub const DT_IA_64_PLT_RESERVE = (DT_LOPROC + 0);
pub const DT_IA_64_NUM = 1;

pub const DT_NIOS2_GP = 0x70000002;

pub const PT_NULL = 0;
pub const PT_LOAD = 1;
pub const PT_DYNAMIC = 2;
pub const PT_INTERP = 3;
pub const PT_NOTE = 4;
pub const PT_SHLIB = 5;
pub const PT_PHDR = 6;
pub const PT_TLS = 7;
pub const PT_NUM = 8;
pub const PT_LOOS = 0x60000000;
pub const PT_GNU_EH_FRAME = 0x6474e550;
pub const PT_GNU_STACK = 0x6474e551;
pub const PT_GNU_RELRO = 0x6474e552;
pub const PT_LOSUNW = 0x6ffffffa;
pub const PT_SUNWBSS = 0x6ffffffa;
pub const PT_SUNWSTACK = 0x6ffffffb;
pub const PT_HISUNW = 0x6fffffff;
pub const PT_HIOS = 0x6fffffff;
pub const PT_LOPROC = 0x70000000;
pub const PT_HIPROC = 0x7fffffff;

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

pub const STB_LOCAL = 0;
pub const STB_GLOBAL = 1;
pub const STB_WEAK = 2;
pub const STB_NUM = 3;
pub const STB_LOOS = 10;
pub const STB_GNU_UNIQUE = 10;
pub const STB_HIOS = 12;
pub const STB_LOPROC = 13;
pub const STB_HIPROC = 15;

pub const STB_MIPS_SPLIT_COMMON = 13;

pub const STT_NOTYPE = 0;
pub const STT_OBJECT = 1;
pub const STT_FUNC = 2;
pub const STT_SECTION = 3;
pub const STT_FILE = 4;
pub const STT_COMMON = 5;
pub const STT_TLS = 6;
pub const STT_NUM = 7;
pub const STT_LOOS = 10;
pub const STT_GNU_IFUNC = 10;
pub const STT_HIOS = 12;
pub const STT_LOPROC = 13;
pub const STT_HIPROC = 15;

pub const STT_SPARC_REGISTER = 13;

pub const STT_PARISC_MILLICODE = 13;

pub const STT_HP_OPAQUE = (STT_LOOS + 0x1);
pub const STT_HP_STUB = (STT_LOOS + 0x2);

pub const STT_ARM_TFUNC = STT_LOPROC;
pub const STT_ARM_16BIT = STT_HIPROC;

pub const VER_FLG_BASE = 0x1;
pub const VER_FLG_WEAK = 0x2;

/// An unknown type.
pub const ET_NONE = 0;

/// A relocatable file.
pub const ET_REL = 1;

/// An executable file.
pub const ET_EXEC = 2;

/// A shared object.
pub const ET_DYN = 3;

/// A core file.
pub const ET_CORE = 4;

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
    in_file: *os.File,
    auto_close_stream: bool,
    is_64: bool,
    endian: builtin.Endian,
    file_type: FileType,
    arch: Arch,
    entry_addr: u64,
    program_header_offset: u64,
    section_header_offset: u64,
    string_section_index: u64,
    string_section: *SectionHeader,
    section_headers: []SectionHeader,
    allocator: *mem.Allocator,
    prealloc_file: os.File,

    /// Call close when done.
    pub fn openPath(elf: *Elf, allocator: *mem.Allocator, path: []const u8) !void {
        try elf.prealloc_file.open(path);
        try elf.openFile(allocator, *elf.prealloc_file);
        elf.auto_close_stream = true;
    }

    /// Call close when done.
    pub fn openFile(elf: *Elf, allocator: *mem.Allocator, file: *os.File) !void {
        elf.allocator = allocator;
        elf.in_file = file;
        elf.auto_close_stream = false;

        var file_stream = io.FileInStream.init(elf.in_file);
        const in = &file_stream.stream;

        var magic: [4]u8 = undefined;
        try in.readNoEof(magic[0..]);
        if (!mem.eql(u8, magic, "\x7fELF")) return error.InvalidFormat;

        elf.is_64 = switch (try in.readByte()) {
            1 => false,
            2 => true,
            else => return error.InvalidFormat,
        };

        elf.endian = switch (try in.readByte()) {
            1 => builtin.Endian.Little,
            2 => builtin.Endian.Big,
            else => return error.InvalidFormat,
        };

        const version_byte = try in.readByte();
        if (version_byte != 1) return error.InvalidFormat;

        // skip over padding
        try elf.in_file.seekForward(9);

        elf.file_type = switch (try in.readInt(elf.endian, u16)) {
            1 => FileType.Relocatable,
            2 => FileType.Executable,
            3 => FileType.Shared,
            4 => FileType.Core,
            else => return error.InvalidFormat,
        };

        elf.arch = switch (try in.readInt(elf.endian, u16)) {
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

        const elf_version = try in.readInt(elf.endian, u32);
        if (elf_version != 1) return error.InvalidFormat;

        if (elf.is_64) {
            elf.entry_addr = try in.readInt(elf.endian, u64);
            elf.program_header_offset = try in.readInt(elf.endian, u64);
            elf.section_header_offset = try in.readInt(elf.endian, u64);
        } else {
            elf.entry_addr = u64(try in.readInt(elf.endian, u32));
            elf.program_header_offset = u64(try in.readInt(elf.endian, u32));
            elf.section_header_offset = u64(try in.readInt(elf.endian, u32));
        }

        // skip over flags
        try elf.in_file.seekForward(4);

        const header_size = try in.readInt(elf.endian, u16);
        if ((elf.is_64 and header_size != 64) or (!elf.is_64 and header_size != 52)) {
            return error.InvalidFormat;
        }

        const ph_entry_size = try in.readInt(elf.endian, u16);
        const ph_entry_count = try in.readInt(elf.endian, u16);
        const sh_entry_size = try in.readInt(elf.endian, u16);
        const sh_entry_count = try in.readInt(elf.endian, u16);
        elf.string_section_index = u64(try in.readInt(elf.endian, u16));

        if (elf.string_section_index >= sh_entry_count) return error.InvalidFormat;

        const sh_byte_count = u64(sh_entry_size) * u64(sh_entry_count);
        const end_sh = try math.add(u64, elf.section_header_offset, sh_byte_count);
        const ph_byte_count = u64(ph_entry_size) * u64(ph_entry_count);
        const end_ph = try math.add(u64, elf.program_header_offset, ph_byte_count);

        const stream_end = try elf.in_file.getEndPos();
        if (stream_end < end_sh or stream_end < end_ph) {
            return error.InvalidFormat;
        }

        try elf.in_file.seekTo(elf.section_header_offset);

        elf.section_headers = try elf.allocator.alloc(SectionHeader, sh_entry_count);
        errdefer elf.allocator.free(elf.section_headers);

        if (elf.is_64) {
            if (sh_entry_size != 64) return error.InvalidFormat;

            for (elf.section_headers) |*elf_section| {
                elf_section.name = try in.readInt(elf.endian, u32);
                elf_section.sh_type = try in.readInt(elf.endian, u32);
                elf_section.flags = try in.readInt(elf.endian, u64);
                elf_section.addr = try in.readInt(elf.endian, u64);
                elf_section.offset = try in.readInt(elf.endian, u64);
                elf_section.size = try in.readInt(elf.endian, u64);
                elf_section.link = try in.readInt(elf.endian, u32);
                elf_section.info = try in.readInt(elf.endian, u32);
                elf_section.addr_align = try in.readInt(elf.endian, u64);
                elf_section.ent_size = try in.readInt(elf.endian, u64);
            }
        } else {
            if (sh_entry_size != 40) return error.InvalidFormat;

            for (elf.section_headers) |*elf_section| {
                // TODO (multiple occurences) allow implicit cast from %u32 -> %u64 ?
                elf_section.name = try in.readInt(elf.endian, u32);
                elf_section.sh_type = try in.readInt(elf.endian, u32);
                elf_section.flags = u64(try in.readInt(elf.endian, u32));
                elf_section.addr = u64(try in.readInt(elf.endian, u32));
                elf_section.offset = u64(try in.readInt(elf.endian, u32));
                elf_section.size = u64(try in.readInt(elf.endian, u32));
                elf_section.link = try in.readInt(elf.endian, u32);
                elf_section.info = try in.readInt(elf.endian, u32);
                elf_section.addr_align = u64(try in.readInt(elf.endian, u32));
                elf_section.ent_size = u64(try in.readInt(elf.endian, u32));
            }
        }

        for (elf.section_headers) |*elf_section| {
            if (elf_section.sh_type != SHT_NOBITS) {
                const file_end_offset = try math.add(u64, elf_section.offset, elf_section.size);
                if (stream_end < file_end_offset) return error.InvalidFormat;
            }
        }

        elf.string_section = &elf.section_headers[elf.string_section_index];
        if (elf.string_section.sh_type != SHT_STRTAB) {
            // not a string table
            return error.InvalidFormat;
        }
    }

    pub fn close(elf: *Elf) void {
        elf.allocator.free(elf.section_headers);

        if (elf.auto_close_stream) elf.in_file.close();
    }

    pub fn findSection(elf: *Elf, name: []const u8) !?*SectionHeader {
        var file_stream = io.FileInStream.init(elf.in_file);
        const in = &file_stream.stream;

        section_loop: for (elf.section_headers) |*elf_section| {
            if (elf_section.sh_type == SHT_NULL) continue;

            const name_offset = elf.string_section.offset + elf_section.name;
            try elf.in_file.seekTo(name_offset);

            for (name) |expected_c| {
                const target_c = try in.readByte();
                if (target_c == 0 or expected_c != target_c) continue :section_loop;
            }

            {
                const null_byte = try in.readByte();
                if (null_byte == 0) return elf_section;
            }
        }

        return null;
    }

    pub fn seekToSection(elf: *Elf, elf_section: *SectionHeader) !void {
        try elf.in_file.seekTo(elf_section.offset);
    }
};

pub const EI_NIDENT = 16;
pub const Elf32_Half = u16;
pub const Elf64_Half = u16;
pub const Elf32_Word = u32;
pub const Elf32_Sword = i32;
pub const Elf64_Word = u32;
pub const Elf64_Sword = i32;
pub const Elf32_Xword = u64;
pub const Elf32_Sxword = i64;
pub const Elf64_Xword = u64;
pub const Elf64_Sxword = i64;
pub const Elf32_Addr = u32;
pub const Elf64_Addr = u64;
pub const Elf32_Off = u32;
pub const Elf64_Off = u64;
pub const Elf32_Section = u16;
pub const Elf64_Section = u16;
pub const Elf32_Versym = Elf32_Half;
pub const Elf64_Versym = Elf64_Half;
pub const Elf32_Ehdr = extern struct {
    e_ident: [EI_NIDENT]u8,
    e_type: Elf32_Half,
    e_machine: Elf32_Half,
    e_version: Elf32_Word,
    e_entry: Elf32_Addr,
    e_phoff: Elf32_Off,
    e_shoff: Elf32_Off,
    e_flags: Elf32_Word,
    e_ehsize: Elf32_Half,
    e_phentsize: Elf32_Half,
    e_phnum: Elf32_Half,
    e_shentsize: Elf32_Half,
    e_shnum: Elf32_Half,
    e_shstrndx: Elf32_Half,
};
pub const Elf64_Ehdr = extern struct {
    e_ident: [EI_NIDENT]u8,
    e_type: Elf64_Half,
    e_machine: Elf64_Half,
    e_version: Elf64_Word,
    e_entry: Elf64_Addr,
    e_phoff: Elf64_Off,
    e_shoff: Elf64_Off,
    e_flags: Elf64_Word,
    e_ehsize: Elf64_Half,
    e_phentsize: Elf64_Half,
    e_phnum: Elf64_Half,
    e_shentsize: Elf64_Half,
    e_shnum: Elf64_Half,
    e_shstrndx: Elf64_Half,
};
pub const Elf32_Shdr = extern struct {
    sh_name: Elf32_Word,
    sh_type: Elf32_Word,
    sh_flags: Elf32_Word,
    sh_addr: Elf32_Addr,
    sh_offset: Elf32_Off,
    sh_size: Elf32_Word,
    sh_link: Elf32_Word,
    sh_info: Elf32_Word,
    sh_addralign: Elf32_Word,
    sh_entsize: Elf32_Word,
};
pub const Elf64_Shdr = extern struct {
    sh_name: Elf64_Word,
    sh_type: Elf64_Word,
    sh_flags: Elf64_Xword,
    sh_addr: Elf64_Addr,
    sh_offset: Elf64_Off,
    sh_size: Elf64_Xword,
    sh_link: Elf64_Word,
    sh_info: Elf64_Word,
    sh_addralign: Elf64_Xword,
    sh_entsize: Elf64_Xword,
};
pub const Elf32_Chdr = extern struct {
    ch_type: Elf32_Word,
    ch_size: Elf32_Word,
    ch_addralign: Elf32_Word,
};
pub const Elf64_Chdr = extern struct {
    ch_type: Elf64_Word,
    ch_reserved: Elf64_Word,
    ch_size: Elf64_Xword,
    ch_addralign: Elf64_Xword,
};
pub const Elf32_Sym = extern struct {
    st_name: Elf32_Word,
    st_value: Elf32_Addr,
    st_size: Elf32_Word,
    st_info: u8,
    st_other: u8,
    st_shndx: Elf32_Section,
};
pub const Elf64_Sym = extern struct {
    st_name: Elf64_Word,
    st_info: u8,
    st_other: u8,
    st_shndx: Elf64_Section,
    st_value: Elf64_Addr,
    st_size: Elf64_Xword,
};
pub const Elf32_Syminfo = extern struct {
    si_boundto: Elf32_Half,
    si_flags: Elf32_Half,
};
pub const Elf64_Syminfo = extern struct {
    si_boundto: Elf64_Half,
    si_flags: Elf64_Half,
};
pub const Elf32_Rel = extern struct {
    r_offset: Elf32_Addr,
    r_info: Elf32_Word,
};
pub const Elf64_Rel = extern struct {
    r_offset: Elf64_Addr,
    r_info: Elf64_Xword,
};
pub const Elf32_Rela = extern struct {
    r_offset: Elf32_Addr,
    r_info: Elf32_Word,
    r_addend: Elf32_Sword,
};
pub const Elf64_Rela = extern struct {
    r_offset: Elf64_Addr,
    r_info: Elf64_Xword,
    r_addend: Elf64_Sxword,
};
pub const Elf32_Phdr = extern struct {
    p_type: Elf32_Word,
    p_offset: Elf32_Off,
    p_vaddr: Elf32_Addr,
    p_paddr: Elf32_Addr,
    p_filesz: Elf32_Word,
    p_memsz: Elf32_Word,
    p_flags: Elf32_Word,
    p_align: Elf32_Word,
};
pub const Elf64_Phdr = extern struct {
    p_type: Elf64_Word,
    p_flags: Elf64_Word,
    p_offset: Elf64_Off,
    p_vaddr: Elf64_Addr,
    p_paddr: Elf64_Addr,
    p_filesz: Elf64_Xword,
    p_memsz: Elf64_Xword,
    p_align: Elf64_Xword,
};
pub const Elf32_Dyn = extern struct {
    d_tag: Elf32_Sword,
    d_un: extern union {
        d_val: Elf32_Word,
        d_ptr: Elf32_Addr,
    },
};
pub const Elf64_Dyn = extern struct {
    d_tag: Elf64_Sxword,
    d_un: extern union {
        d_val: Elf64_Xword,
        d_ptr: Elf64_Addr,
    },
};
pub const Elf32_Verdef = extern struct {
    vd_version: Elf32_Half,
    vd_flags: Elf32_Half,
    vd_ndx: Elf32_Half,
    vd_cnt: Elf32_Half,
    vd_hash: Elf32_Word,
    vd_aux: Elf32_Word,
    vd_next: Elf32_Word,
};
pub const Elf64_Verdef = extern struct {
    vd_version: Elf64_Half,
    vd_flags: Elf64_Half,
    vd_ndx: Elf64_Half,
    vd_cnt: Elf64_Half,
    vd_hash: Elf64_Word,
    vd_aux: Elf64_Word,
    vd_next: Elf64_Word,
};
pub const Elf32_Verdaux = extern struct {
    vda_name: Elf32_Word,
    vda_next: Elf32_Word,
};
pub const Elf64_Verdaux = extern struct {
    vda_name: Elf64_Word,
    vda_next: Elf64_Word,
};
pub const Elf32_Verneed = extern struct {
    vn_version: Elf32_Half,
    vn_cnt: Elf32_Half,
    vn_file: Elf32_Word,
    vn_aux: Elf32_Word,
    vn_next: Elf32_Word,
};
pub const Elf64_Verneed = extern struct {
    vn_version: Elf64_Half,
    vn_cnt: Elf64_Half,
    vn_file: Elf64_Word,
    vn_aux: Elf64_Word,
    vn_next: Elf64_Word,
};
pub const Elf32_Vernaux = extern struct {
    vna_hash: Elf32_Word,
    vna_flags: Elf32_Half,
    vna_other: Elf32_Half,
    vna_name: Elf32_Word,
    vna_next: Elf32_Word,
};
pub const Elf64_Vernaux = extern struct {
    vna_hash: Elf64_Word,
    vna_flags: Elf64_Half,
    vna_other: Elf64_Half,
    vna_name: Elf64_Word,
    vna_next: Elf64_Word,
};
pub const Elf32_auxv_t = extern struct {
    a_type: u32,
    a_un: extern union {
        a_val: u32,
    },
};
pub const Elf64_auxv_t = extern struct {
    a_type: u64,
    a_un: extern union {
        a_val: u64,
    },
};
pub const Elf32_Nhdr = extern struct {
    n_namesz: Elf32_Word,
    n_descsz: Elf32_Word,
    n_type: Elf32_Word,
};
pub const Elf64_Nhdr = extern struct {
    n_namesz: Elf64_Word,
    n_descsz: Elf64_Word,
    n_type: Elf64_Word,
};
pub const Elf32_Move = extern struct {
    m_value: Elf32_Xword,
    m_info: Elf32_Word,
    m_poffset: Elf32_Word,
    m_repeat: Elf32_Half,
    m_stride: Elf32_Half,
};
pub const Elf64_Move = extern struct {
    m_value: Elf64_Xword,
    m_info: Elf64_Xword,
    m_poffset: Elf64_Xword,
    m_repeat: Elf64_Half,
    m_stride: Elf64_Half,
};
pub const Elf32_gptab = extern union {
    gt_header: extern struct {
        gt_current_g_value: Elf32_Word,
        gt_unused: Elf32_Word,
    },
    gt_entry: extern struct {
        gt_g_value: Elf32_Word,
        gt_bytes: Elf32_Word,
    },
};
pub const Elf32_RegInfo = extern struct {
    ri_gprmask: Elf32_Word,
    ri_cprmask: [4]Elf32_Word,
    ri_gp_value: Elf32_Sword,
};
pub const Elf_Options = extern struct {
    kind: u8,
    size: u8,
    @"section": Elf32_Section,
    info: Elf32_Word,
};
pub const Elf_Options_Hw = extern struct {
    hwp_flags1: Elf32_Word,
    hwp_flags2: Elf32_Word,
};
pub const Elf32_Lib = extern struct {
    l_name: Elf32_Word,
    l_time_stamp: Elf32_Word,
    l_checksum: Elf32_Word,
    l_version: Elf32_Word,
    l_flags: Elf32_Word,
};
pub const Elf64_Lib = extern struct {
    l_name: Elf64_Word,
    l_time_stamp: Elf64_Word,
    l_checksum: Elf64_Word,
    l_version: Elf64_Word,
    l_flags: Elf64_Word,
};
pub const Elf32_Conflict = Elf32_Addr;
pub const Elf_MIPS_ABIFlags_v0 = extern struct {
    version: Elf32_Half,
    isa_level: u8,
    isa_rev: u8,
    gpr_size: u8,
    cpr1_size: u8,
    cpr2_size: u8,
    fp_abi: u8,
    isa_ext: Elf32_Word,
    ases: Elf32_Word,
    flags1: Elf32_Word,
    flags2: Elf32_Word,
};

pub const Ehdr = switch (@sizeOf(usize)) {
    4 => Elf32_Ehdr,
    8 => Elf64_Ehdr,
    else => @compileError("expected pointer size of 32 or 64"),
};
pub const Phdr = switch (@sizeOf(usize)) {
    4 => Elf32_Phdr,
    8 => Elf64_Phdr,
    else => @compileError("expected pointer size of 32 or 64"),
};
pub const Sym = switch (@sizeOf(usize)) {
    4 => Elf32_Sym,
    8 => Elf64_Sym,
    else => @compileError("expected pointer size of 32 or 64"),
};
pub const Verdef = switch (@sizeOf(usize)) {
    4 => Elf32_Verdef,
    8 => Elf64_Verdef,
    else => @compileError("expected pointer size of 32 or 64"),
};
pub const Verdaux = switch (@sizeOf(usize)) {
    4 => Elf32_Verdaux,
    8 => Elf64_Verdaux,
    else => @compileError("expected pointer size of 32 or 64"),
};
