//! Executable and Linkable Format.

const std = @import("std.zig");
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;
const native_endian = @import("builtin").target.cpu.arch.endian();

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
pub const DT_RELRSZ = 35;
pub const DT_RELR = 36;
pub const DT_RELRENT = 37;
pub const DT_NUM = 38;
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

pub const DF_ORIGIN = 0x00000001;
pub const DF_SYMBOLIC = 0x00000002;
pub const DF_TEXTREL = 0x00000004;
pub const DF_BIND_NOW = 0x00000008;
pub const DF_STATIC_TLS = 0x00000010;

pub const DF_1_NOW = 0x00000001;
pub const DF_1_GLOBAL = 0x00000002;
pub const DF_1_GROUP = 0x00000004;
pub const DF_1_NODELETE = 0x00000008;
pub const DF_1_LOADFLTR = 0x00000010;
pub const DF_1_INITFIRST = 0x00000020;
pub const DF_1_NOOPEN = 0x00000040;
pub const DF_1_ORIGIN = 0x00000080;
pub const DF_1_DIRECT = 0x00000100;
pub const DF_1_TRANS = 0x00000200;
pub const DF_1_INTERPOSE = 0x00000400;
pub const DF_1_NODEFLIB = 0x00000800;
pub const DF_1_NODUMP = 0x00001000;
pub const DF_1_CONFALT = 0x00002000;
pub const DF_1_ENDFILTEE = 0x00004000;
pub const DF_1_DISPRELDNE = 0x00008000;
pub const DF_1_DISPRELPND = 0x00010000;
pub const DF_1_NODIRECT = 0x00020000;
pub const DF_1_IGNMULDEF = 0x00040000;
pub const DF_1_NOKSYMS = 0x00080000;
pub const DF_1_NOHDR = 0x00100000;
pub const DF_1_EDITED = 0x00200000;
pub const DF_1_NORELOC = 0x00400000;
pub const DF_1_SYMINTPOSE = 0x00800000;
pub const DF_1_GLOBAUDIT = 0x01000000;
pub const DF_1_SINGLETON = 0x02000000;
pub const DF_1_STUB = 0x04000000;
pub const DF_1_PIE = 0x08000000;

pub const Versym = packed struct(u16) {
    VERSION: u15,
    HIDDEN: bool,

    pub const LOCAL: Versym = @bitCast(@intFromEnum(VER_NDX.LOCAL));
    pub const GLOBAL: Versym = @bitCast(@intFromEnum(VER_NDX.GLOBAL));
};

pub const VER_NDX = enum(u16) {
    /// Symbol is local
    LOCAL = 0,
    /// Symbol is global
    GLOBAL = 1,
    /// Beginning of reserved entries
    LORESERVE = 0xff00,
    /// Symbol is to be eliminated
    ELIMINATE = 0xff01,
    UNSPECIFIED = 0xffff,
    _,
};

/// Version definition of the file itself
pub const VER_FLG_BASE = 1;
/// Weak version identifier
pub const VER_FLG_WEAK = 2;

/// Program header table entry unused
pub const PT_NULL = 0;
/// Loadable program segment
pub const PT_LOAD = 1;
/// Dynamic linking information
pub const PT_DYNAMIC = 2;
/// Program interpreter
pub const PT_INTERP = 3;
/// Auxiliary information
pub const PT_NOTE = 4;
/// Reserved
pub const PT_SHLIB = 5;
/// Entry for header table itself
pub const PT_PHDR = 6;
/// Thread-local storage segment
pub const PT_TLS = 7;
/// Number of defined types
pub const PT_NUM = 8;
/// Start of OS-specific
pub const PT_LOOS = 0x60000000;
/// GCC .eh_frame_hdr segment
pub const PT_GNU_EH_FRAME = 0x6474e550;
/// Indicates stack executability
pub const PT_GNU_STACK = 0x6474e551;
/// Read-only after relocation
pub const PT_GNU_RELRO = 0x6474e552;
pub const PT_LOSUNW = 0x6ffffffa;
/// Sun specific segment
pub const PT_SUNWBSS = 0x6ffffffa;
/// Stack segment
pub const PT_SUNWSTACK = 0x6ffffffb;
pub const PT_HISUNW = 0x6fffffff;
/// End of OS-specific
pub const PT_HIOS = 0x6fffffff;
/// Start of processor-specific
pub const PT_LOPROC = 0x70000000;
/// End of processor-specific
pub const PT_HIPROC = 0x7fffffff;

/// Section header table entry unused
pub const SHT_NULL = 0;
/// Program data
pub const SHT_PROGBITS = 1;
/// Symbol table
pub const SHT_SYMTAB = 2;
/// String table
pub const SHT_STRTAB = 3;
/// Relocation entries with addends
pub const SHT_RELA = 4;
/// Symbol hash table
pub const SHT_HASH = 5;
/// Dynamic linking information
pub const SHT_DYNAMIC = 6;
/// Notes
pub const SHT_NOTE = 7;
/// Program space with no data (bss)
pub const SHT_NOBITS = 8;
/// Relocation entries, no addends
pub const SHT_REL = 9;
/// Reserved
pub const SHT_SHLIB = 10;
/// Dynamic linker symbol table
pub const SHT_DYNSYM = 11;
/// Array of constructors
pub const SHT_INIT_ARRAY = 14;
/// Array of destructors
pub const SHT_FINI_ARRAY = 15;
/// Array of pre-constructors
pub const SHT_PREINIT_ARRAY = 16;
/// Section group
pub const SHT_GROUP = 17;
/// Extended section indices
pub const SHT_SYMTAB_SHNDX = 18;
/// Start of OS-specific
pub const SHT_LOOS = 0x60000000;
/// LLVM address-significance table
pub const SHT_LLVM_ADDRSIG = 0x6fff4c03;
/// GNU hash table
pub const SHT_GNU_HASH = 0x6ffffff6;
/// GNU version definition table
pub const SHT_GNU_VERDEF = 0x6ffffffd;
/// GNU needed versions table
pub const SHT_GNU_VERNEED = 0x6ffffffe;
/// GNU symbol version table
pub const SHT_GNU_VERSYM = 0x6fffffff;
/// End of OS-specific
pub const SHT_HIOS = 0x6fffffff;
/// Start of processor-specific
pub const SHT_LOPROC = 0x70000000;
/// Unwind information
pub const SHT_X86_64_UNWIND = 0x70000001;
/// End of processor-specific
pub const SHT_HIPROC = 0x7fffffff;
/// Start of application-specific
pub const SHT_LOUSER = 0x80000000;
/// End of application-specific
pub const SHT_HIUSER = 0xffffffff;

// Note type for .note.gnu.build_id
pub const NT_GNU_BUILD_ID = 3;

/// Local symbol
pub const STB_LOCAL = 0;
/// Global symbol
pub const STB_GLOBAL = 1;
/// Weak symbol
pub const STB_WEAK = 2;
/// Number of defined types
pub const STB_NUM = 3;
/// Start of OS-specific
pub const STB_LOOS = 10;
/// Unique symbol
pub const STB_GNU_UNIQUE = 10;
/// End of OS-specific
pub const STB_HIOS = 12;
/// Start of processor-specific
pub const STB_LOPROC = 13;
/// End of processor-specific
pub const STB_HIPROC = 15;

pub const STB_MIPS_SPLIT_COMMON = 13;

/// Symbol type is unspecified
pub const STT_NOTYPE = 0;
/// Symbol is a data object
pub const STT_OBJECT = 1;
/// Symbol is a code object
pub const STT_FUNC = 2;
/// Symbol associated with a section
pub const STT_SECTION = 3;
/// Symbol's name is file name
pub const STT_FILE = 4;
/// Symbol is a common data object
pub const STT_COMMON = 5;
/// Symbol is thread-local data object
pub const STT_TLS = 6;
/// Number of defined types
pub const STT_NUM = 7;
/// Start of OS-specific
pub const STT_LOOS = 10;
/// Symbol is indirect code object
pub const STT_GNU_IFUNC = 10;
/// End of OS-specific
pub const STT_HIOS = 12;
/// Start of processor-specific
pub const STT_LOPROC = 13;
/// End of processor-specific
pub const STT_HIPROC = 15;

pub const STT_SPARC_REGISTER = 13;

pub const STT_PARISC_MILLICODE = 13;

pub const STT_HP_OPAQUE = (STT_LOOS + 0x1);
pub const STT_HP_STUB = (STT_LOOS + 0x2);

pub const STT_ARM_TFUNC = STT_LOPROC;
pub const STT_ARM_16BIT = STT_HIPROC;

pub const MAGIC = "\x7fELF";

/// File types
pub const ET = enum(u16) {
    /// No file type
    NONE = 0,

    /// Relocatable file
    REL = 1,

    /// Executable file
    EXEC = 2,

    /// Shared object file
    DYN = 3,

    /// Core file
    CORE = 4,

    _,

    /// Beginning of OS-specific codes
    pub const LOOS = 0xfe00;

    /// End of OS-specific codes
    pub const HIOS = 0xfeff;

    /// Beginning of processor-specific codes
    pub const LOPROC = 0xff00;

    /// End of processor-specific codes
    pub const HIPROC = 0xffff;
};

/// All integers are native endian.
pub const Header = struct {
    is_64: bool,
    endian: std.builtin.Endian,
    os_abi: OSABI,
    abi_version: u8,
    type: ET,
    machine: EM,
    entry: u64,
    phoff: u64,
    shoff: u64,
    phentsize: u16,
    phnum: u16,
    shentsize: u16,
    shnum: u16,
    shstrndx: u16,

    pub fn program_header_iterator(self: Header, parse_source: anytype) ProgramHeaderIterator(@TypeOf(parse_source)) {
        return ProgramHeaderIterator(@TypeOf(parse_source)){
            .elf_header = self,
            .parse_source = parse_source,
        };
    }

    pub fn section_header_iterator(self: Header, parse_source: anytype) SectionHeaderIterator(@TypeOf(parse_source)) {
        return SectionHeaderIterator(@TypeOf(parse_source)){
            .elf_header = self,
            .parse_source = parse_source,
        };
    }

    pub fn read(parse_source: anytype) !Header {
        var hdr_buf: [@sizeOf(Elf64_Ehdr)]u8 align(@alignOf(Elf64_Ehdr)) = undefined;
        try parse_source.seekableStream().seekTo(0);
        try parse_source.reader().readNoEof(&hdr_buf);
        return Header.parse(&hdr_buf);
    }

    pub fn parse(hdr_buf: *align(@alignOf(Elf64_Ehdr)) const [@sizeOf(Elf64_Ehdr)]u8) !Header {
        const hdr32 = @as(*const Elf32_Ehdr, @ptrCast(hdr_buf));
        const hdr64 = @as(*const Elf64_Ehdr, @ptrCast(hdr_buf));
        if (!mem.eql(u8, hdr32.e_ident[0..4], MAGIC)) return error.InvalidElfMagic;
        if (hdr32.e_ident[EI_VERSION] != 1) return error.InvalidElfVersion;

        const is_64 = switch (hdr32.e_ident[EI_CLASS]) {
            ELFCLASS32 => false,
            ELFCLASS64 => true,
            else => return error.InvalidElfClass,
        };

        const endian: std.builtin.Endian = switch (hdr32.e_ident[EI_DATA]) {
            ELFDATA2LSB => .little,
            ELFDATA2MSB => .big,
            else => return error.InvalidElfEndian,
        };
        const need_bswap = endian != native_endian;

        // Converting integers to exhaustive enums using `@enumFromInt` could cause a panic.
        comptime assert(!@typeInfo(OSABI).@"enum".is_exhaustive);
        const os_abi: OSABI = @enumFromInt(hdr32.e_ident[EI_OSABI]);

        // The meaning of this value depends on `os_abi` so just make it available as `u8`.
        const abi_version = hdr32.e_ident[EI_ABIVERSION];

        const @"type" = if (need_bswap) blk: {
            comptime assert(!@typeInfo(ET).@"enum".is_exhaustive);
            const value = @intFromEnum(hdr32.e_type);
            break :blk @as(ET, @enumFromInt(@byteSwap(value)));
        } else hdr32.e_type;

        const machine = if (need_bswap) blk: {
            comptime assert(!@typeInfo(EM).@"enum".is_exhaustive);
            const value = @intFromEnum(hdr32.e_machine);
            break :blk @as(EM, @enumFromInt(@byteSwap(value)));
        } else hdr32.e_machine;

        return @as(Header, .{
            .is_64 = is_64,
            .endian = endian,
            .os_abi = os_abi,
            .abi_version = abi_version,
            .type = @"type",
            .machine = machine,
            .entry = int(is_64, need_bswap, hdr32.e_entry, hdr64.e_entry),
            .phoff = int(is_64, need_bswap, hdr32.e_phoff, hdr64.e_phoff),
            .shoff = int(is_64, need_bswap, hdr32.e_shoff, hdr64.e_shoff),
            .phentsize = int(is_64, need_bswap, hdr32.e_phentsize, hdr64.e_phentsize),
            .phnum = int(is_64, need_bswap, hdr32.e_phnum, hdr64.e_phnum),
            .shentsize = int(is_64, need_bswap, hdr32.e_shentsize, hdr64.e_shentsize),
            .shnum = int(is_64, need_bswap, hdr32.e_shnum, hdr64.e_shnum),
            .shstrndx = int(is_64, need_bswap, hdr32.e_shstrndx, hdr64.e_shstrndx),
        });
    }
};

pub fn ProgramHeaderIterator(comptime ParseSource: anytype) type {
    return struct {
        elf_header: Header,
        parse_source: ParseSource,
        index: usize = 0,

        pub fn next(self: *@This()) !?Elf64_Phdr {
            if (self.index >= self.elf_header.phnum) return null;
            defer self.index += 1;

            if (self.elf_header.is_64) {
                var phdr: Elf64_Phdr = undefined;
                const offset = self.elf_header.phoff + @sizeOf(@TypeOf(phdr)) * self.index;
                try self.parse_source.seekableStream().seekTo(offset);
                try self.parse_source.reader().readNoEof(mem.asBytes(&phdr));

                // ELF endianness matches native endianness.
                if (self.elf_header.endian == native_endian) return phdr;

                // Convert fields to native endianness.
                mem.byteSwapAllFields(Elf64_Phdr, &phdr);
                return phdr;
            }

            var phdr: Elf32_Phdr = undefined;
            const offset = self.elf_header.phoff + @sizeOf(@TypeOf(phdr)) * self.index;
            try self.parse_source.seekableStream().seekTo(offset);
            try self.parse_source.reader().readNoEof(mem.asBytes(&phdr));

            // ELF endianness does NOT match native endianness.
            if (self.elf_header.endian != native_endian) {
                // Convert fields to native endianness.
                mem.byteSwapAllFields(Elf32_Phdr, &phdr);
            }

            // Convert 32-bit header to 64-bit.
            return Elf64_Phdr{
                .p_type = phdr.p_type,
                .p_offset = phdr.p_offset,
                .p_vaddr = phdr.p_vaddr,
                .p_paddr = phdr.p_paddr,
                .p_filesz = phdr.p_filesz,
                .p_memsz = phdr.p_memsz,
                .p_flags = phdr.p_flags,
                .p_align = phdr.p_align,
            };
        }
    };
}

pub fn SectionHeaderIterator(comptime ParseSource: anytype) type {
    return struct {
        elf_header: Header,
        parse_source: ParseSource,
        index: usize = 0,

        pub fn next(self: *@This()) !?Elf64_Shdr {
            if (self.index >= self.elf_header.shnum) return null;
            defer self.index += 1;

            if (self.elf_header.is_64) {
                var shdr: Elf64_Shdr = undefined;
                const offset = self.elf_header.shoff + @sizeOf(@TypeOf(shdr)) * self.index;
                try self.parse_source.seekableStream().seekTo(offset);
                try self.parse_source.reader().readNoEof(mem.asBytes(&shdr));

                // ELF endianness matches native endianness.
                if (self.elf_header.endian == native_endian) return shdr;

                // Convert fields to native endianness.
                mem.byteSwapAllFields(Elf64_Shdr, &shdr);
                return shdr;
            }

            var shdr: Elf32_Shdr = undefined;
            const offset = self.elf_header.shoff + @sizeOf(@TypeOf(shdr)) * self.index;
            try self.parse_source.seekableStream().seekTo(offset);
            try self.parse_source.reader().readNoEof(mem.asBytes(&shdr));

            // ELF endianness does NOT match native endianness.
            if (self.elf_header.endian != native_endian) {
                // Convert fields to native endianness.
                mem.byteSwapAllFields(Elf32_Shdr, &shdr);
            }

            // Convert 32-bit header to 64-bit.
            return Elf64_Shdr{
                .sh_name = shdr.sh_name,
                .sh_type = shdr.sh_type,
                .sh_flags = shdr.sh_flags,
                .sh_addr = shdr.sh_addr,
                .sh_offset = shdr.sh_offset,
                .sh_size = shdr.sh_size,
                .sh_link = shdr.sh_link,
                .sh_info = shdr.sh_info,
                .sh_addralign = shdr.sh_addralign,
                .sh_entsize = shdr.sh_entsize,
            };
        }
    };
}

fn int(is_64: bool, need_bswap: bool, int_32: anytype, int_64: anytype) @TypeOf(int_64) {
    if (is_64) {
        if (need_bswap) {
            return @byteSwap(int_64);
        } else {
            return int_64;
        }
    } else {
        return int32(need_bswap, int_32, @TypeOf(int_64));
    }
}

fn int32(need_bswap: bool, int_32: anytype, comptime Int64: anytype) Int64 {
    if (need_bswap) {
        return @byteSwap(int_32);
    } else {
        return int_32;
    }
}

pub const ELFCLASSNONE = 0;
pub const ELFCLASS32 = 1;
pub const ELFCLASS64 = 2;
pub const ELFCLASSNUM = 3;

pub const ELFDATANONE = 0;
pub const ELFDATA2LSB = 1;
pub const ELFDATA2MSB = 2;
pub const ELFDATANUM = 3;

pub const EI_CLASS = 4;
pub const EI_DATA = 5;
pub const EI_VERSION = 6;
pub const EI_OSABI = 7;
pub const EI_ABIVERSION = 8;
pub const EI_PAD = 9;

pub const EI_NIDENT = 16;

pub const Half = u16;
pub const Word = u32;
pub const Sword = i32;
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
pub const Elf32_Ehdr = extern struct {
    e_ident: [EI_NIDENT]u8,
    e_type: ET,
    e_machine: EM,
    e_version: Word,
    e_entry: Elf32_Addr,
    e_phoff: Elf32_Off,
    e_shoff: Elf32_Off,
    e_flags: Word,
    e_ehsize: Half,
    e_phentsize: Half,
    e_phnum: Half,
    e_shentsize: Half,
    e_shnum: Half,
    e_shstrndx: Half,
};
pub const Elf64_Ehdr = extern struct {
    e_ident: [EI_NIDENT]u8,
    e_type: ET,
    e_machine: EM,
    e_version: Word,
    e_entry: Elf64_Addr,
    e_phoff: Elf64_Off,
    e_shoff: Elf64_Off,
    e_flags: Word,
    e_ehsize: Half,
    e_phentsize: Half,
    e_phnum: Half,
    e_shentsize: Half,
    e_shnum: Half,
    e_shstrndx: Half,
};
pub const Elf32_Phdr = extern struct {
    p_type: Word,
    p_offset: Elf32_Off,
    p_vaddr: Elf32_Addr,
    p_paddr: Elf32_Addr,
    p_filesz: Word,
    p_memsz: Word,
    p_flags: Word,
    p_align: Word,
};
pub const Elf64_Phdr = extern struct {
    p_type: Word,
    p_flags: Word,
    p_offset: Elf64_Off,
    p_vaddr: Elf64_Addr,
    p_paddr: Elf64_Addr,
    p_filesz: Elf64_Xword,
    p_memsz: Elf64_Xword,
    p_align: Elf64_Xword,
};
pub const Elf32_Shdr = extern struct {
    sh_name: Word,
    sh_type: Word,
    sh_flags: Word,
    sh_addr: Elf32_Addr,
    sh_offset: Elf32_Off,
    sh_size: Word,
    sh_link: Word,
    sh_info: Word,
    sh_addralign: Word,
    sh_entsize: Word,
};
pub const Elf64_Shdr = extern struct {
    sh_name: Word,
    sh_type: Word,
    sh_flags: Elf64_Xword,
    sh_addr: Elf64_Addr,
    sh_offset: Elf64_Off,
    sh_size: Elf64_Xword,
    sh_link: Word,
    sh_info: Word,
    sh_addralign: Elf64_Xword,
    sh_entsize: Elf64_Xword,
};
pub const Elf32_Chdr = extern struct {
    ch_type: COMPRESS,
    ch_size: Word,
    ch_addralign: Word,
};
pub const Elf64_Chdr = extern struct {
    ch_type: COMPRESS,
    ch_reserved: Word = 0,
    ch_size: Elf64_Xword,
    ch_addralign: Elf64_Xword,
};
pub const Elf32_Sym = extern struct {
    st_name: Word,
    st_value: Elf32_Addr,
    st_size: Word,
    st_info: u8,
    st_other: u8,
    st_shndx: Elf32_Section,

    pub inline fn st_type(self: @This()) u4 {
        return @truncate(self.st_info);
    }
    pub inline fn st_bind(self: @This()) u4 {
        return @truncate(self.st_info >> 4);
    }
};
pub const Elf64_Sym = extern struct {
    st_name: Word,
    st_info: u8,
    st_other: u8,
    st_shndx: Elf64_Section,
    st_value: Elf64_Addr,
    st_size: Elf64_Xword,

    pub inline fn st_type(self: @This()) u4 {
        return @truncate(self.st_info);
    }
    pub inline fn st_bind(self: @This()) u4 {
        return @truncate(self.st_info >> 4);
    }
};
pub const Elf32_Syminfo = extern struct {
    si_boundto: Half,
    si_flags: Half,
};
pub const Elf64_Syminfo = extern struct {
    si_boundto: Half,
    si_flags: Half,
};
pub const Elf32_Rel = extern struct {
    r_offset: Elf32_Addr,
    r_info: Word,

    pub inline fn r_sym(self: @This()) u24 {
        return @truncate(self.r_info >> 8);
    }
    pub inline fn r_type(self: @This()) u8 {
        return @truncate(self.r_info);
    }
};
pub const Elf64_Rel = extern struct {
    r_offset: Elf64_Addr,
    r_info: Elf64_Xword,

    pub inline fn r_sym(self: @This()) u32 {
        return @truncate(self.r_info >> 32);
    }
    pub inline fn r_type(self: @This()) u32 {
        return @truncate(self.r_info);
    }
};
pub const Elf32_Rela = extern struct {
    r_offset: Elf32_Addr,
    r_info: Word,
    r_addend: Sword,

    pub inline fn r_sym(self: @This()) u24 {
        return @truncate(self.r_info >> 8);
    }
    pub inline fn r_type(self: @This()) u8 {
        return @truncate(self.r_info);
    }
};
pub const Elf64_Rela = extern struct {
    r_offset: Elf64_Addr,
    r_info: Elf64_Xword,
    r_addend: Elf64_Sxword,

    pub inline fn r_sym(self: @This()) u32 {
        return @truncate(self.r_info >> 32);
    }
    pub inline fn r_type(self: @This()) u32 {
        return @truncate(self.r_info);
    }
};
pub const Elf32_Relr = Word;
pub const Elf64_Relr = Elf64_Xword;
pub const Elf32_Dyn = extern struct {
    d_tag: Sword,
    d_val: Elf32_Addr,
};
pub const Elf64_Dyn = extern struct {
    d_tag: Elf64_Sxword,
    d_val: Elf64_Addr,
};
pub const Verdef = extern struct {
    version: Half,
    flags: Half,
    ndx: VER_NDX,
    cnt: Half,
    hash: Word,
    aux: Word,
    next: Word,
};
pub const Verdaux = extern struct {
    name: Word,
    next: Word,
};
pub const Elf32_Verneed = extern struct {
    vn_version: Half,
    vn_cnt: Half,
    vn_file: Word,
    vn_aux: Word,
    vn_next: Word,
};
pub const Elf64_Verneed = extern struct {
    vn_version: Half,
    vn_cnt: Half,
    vn_file: Word,
    vn_aux: Word,
    vn_next: Word,
};
pub const Vernaux = extern struct {
    hash: Word,
    flags: Half,
    other: Half,
    name: Word,
    next: Word,
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
    n_namesz: Word,
    n_descsz: Word,
    n_type: Word,
};
pub const Elf64_Nhdr = extern struct {
    n_namesz: Word,
    n_descsz: Word,
    n_type: Word,
};
pub const Elf32_Move = extern struct {
    m_value: Elf32_Xword,
    m_info: Word,
    m_poffset: Word,
    m_repeat: Half,
    m_stride: Half,
};
pub const Elf64_Move = extern struct {
    m_value: Elf64_Xword,
    m_info: Elf64_Xword,
    m_poffset: Elf64_Xword,
    m_repeat: Half,
    m_stride: Half,
};
pub const Elf32_gptab = extern union {
    gt_header: extern struct {
        gt_current_g_value: Word,
        gt_unused: Word,
    },
    gt_entry: extern struct {
        gt_g_value: Word,
        gt_bytes: Word,
    },
};
pub const Elf32_RegInfo = extern struct {
    ri_gprmask: Word,
    ri_cprmask: [4]Word,
    ri_gp_value: Sword,
};
pub const Elf_Options = extern struct {
    kind: u8,
    size: u8,
    section: Elf32_Section,
    info: Word,
};
pub const Elf_Options_Hw = extern struct {
    hwp_flags1: Word,
    hwp_flags2: Word,
};
pub const Elf32_Lib = extern struct {
    l_name: Word,
    l_time_stamp: Word,
    l_checksum: Word,
    l_version: Word,
    l_flags: Word,
};
pub const Elf64_Lib = extern struct {
    l_name: Word,
    l_time_stamp: Word,
    l_checksum: Word,
    l_version: Word,
    l_flags: Word,
};
pub const Elf32_Conflict = Elf32_Addr;
pub const Elf_MIPS_ABIFlags_v0 = extern struct {
    version: Half,
    isa_level: u8,
    isa_rev: u8,
    gpr_size: u8,
    cpr1_size: u8,
    cpr2_size: u8,
    fp_abi: u8,
    isa_ext: Word,
    ases: Word,
    flags1: Word,
    flags2: Word,
};

comptime {
    assert(@sizeOf(Elf32_Ehdr) == 52);
    assert(@sizeOf(Elf64_Ehdr) == 64);

    assert(@sizeOf(Elf32_Phdr) == 32);
    assert(@sizeOf(Elf64_Phdr) == 56);

    assert(@sizeOf(Elf32_Shdr) == 40);
    assert(@sizeOf(Elf64_Shdr) == 64);
}

pub const Auxv = switch (@sizeOf(usize)) {
    4 => Elf32_auxv_t,
    8 => Elf64_auxv_t,
    else => @compileError("expected pointer size of 32 or 64"),
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
pub const Dyn = switch (@sizeOf(usize)) {
    4 => Elf32_Dyn,
    8 => Elf64_Dyn,
    else => @compileError("expected pointer size of 32 or 64"),
};
pub const Rel = switch (@sizeOf(usize)) {
    4 => Elf32_Rel,
    8 => Elf64_Rel,
    else => @compileError("expected pointer size of 32 or 64"),
};
pub const Rela = switch (@sizeOf(usize)) {
    4 => Elf32_Rela,
    8 => Elf64_Rela,
    else => @compileError("expected pointer size of 32 or 64"),
};
pub const Relr = switch (@sizeOf(usize)) {
    4 => Elf32_Relr,
    8 => Elf64_Relr,
    else => @compileError("expected pointer size of 32 or 64"),
};
pub const Shdr = switch (@sizeOf(usize)) {
    4 => Elf32_Shdr,
    8 => Elf64_Shdr,
    else => @compileError("expected pointer size of 32 or 64"),
};
pub const Chdr = switch (@sizeOf(usize)) {
    4 => Elf32_Chdr,
    8 => Elf64_Chdr,
    else => @compileError("expected pointer size of 32 or 64"),
};
pub const Sym = switch (@sizeOf(usize)) {
    4 => Elf32_Sym,
    8 => Elf64_Sym,
    else => @compileError("expected pointer size of 32 or 64"),
};
pub const Addr = switch (@sizeOf(usize)) {
    4 => Elf32_Addr,
    8 => Elf64_Addr,
    else => @compileError("expected pointer size of 32 or 64"),
};

pub const OSABI = enum(u8) {
    /// UNIX System V ABI
    NONE = 0,
    /// HP-UX operating system
    HPUX = 1,
    /// NetBSD
    NETBSD = 2,
    /// GNU (Hurd/Linux)
    GNU = 3,
    /// Solaris
    SOLARIS = 6,
    /// AIX
    AIX = 7,
    /// IRIX
    IRIX = 8,
    /// FreeBSD
    FREEBSD = 9,
    /// TRU64 UNIX
    TRU64 = 10,
    /// Novell Modesto
    MODESTO = 11,
    /// OpenBSD
    OPENBSD = 12,
    /// OpenVMS
    OPENVMS = 13,
    /// Hewlett-Packard Non-Stop Kernel
    NSK = 14,
    /// AROS
    AROS = 15,
    /// FenixOS
    FENIXOS = 16,
    /// Nuxi CloudABI
    CLOUDABI = 17,
    /// Stratus Technologies OpenVOS
    OPENVOS = 18,
    /// NVIDIA CUDA architecture
    CUDA = 51,
    /// AMD HSA Runtime
    AMDGPU_HSA = 64,
    /// AMD PAL Runtime
    AMDGPU_PAL = 65,
    /// AMD Mesa3D Runtime
    AMDGPU_MESA3D = 66,
    /// ARM
    ARM = 97,
    /// Standalone (embedded) application
    STANDALONE = 255,

    _,
};

/// Machine architectures.
///
/// See current registered ELF machine architectures at:
/// http://www.sco.com/developers/gabi/latest/ch4.eheader.html
pub const EM = enum(u16) {
    /// No machine
    NONE = 0,
    /// AT&T WE 32100
    M32 = 1,
    /// SUN SPARC
    SPARC = 2,
    /// Intel 80386
    @"386" = 3,
    /// Motorola m68k family
    @"68K" = 4,
    /// Motorola m88k family
    @"88K" = 5,
    /// Intel MCU
    IAMCU = 6,
    /// Intel 80860
    @"860" = 7,
    /// MIPS R3000 (officially, big-endian only)
    MIPS = 8,
    /// IBM System/370
    S370 = 9,
    /// MIPS R3000 (and R4000) little-endian, Oct 4 1993 Draft (deprecated)
    MIPS_RS3_LE = 10,
    /// Old version of Sparc v9, from before the ABI (deprecated)
    OLD_SPARCV9 = 11,
    /// SPU Mark II
    SPU_2 = 13,
    /// HPPA
    PARISC = 15,
    /// Fujitsu VPP500 (also old version of PowerPC; deprecated)
    VPP500 = 17,
    /// Sun's "v8plus"
    SPARC32PLUS = 18,
    /// Intel 80960
    @"960" = 19,
    /// PowerPC
    PPC = 20,
    /// 64-bit PowerPC
    PPC64 = 21,
    /// IBM S/390
    S390 = 22,
    /// Sony/Toshiba/IBM SPU
    SPU = 23,
    /// NEC V800 series
    V800 = 36,
    /// Fujitsu FR20
    FR20 = 37,
    /// TRW RH32
    RH32 = 38,
    /// Motorola M*Core, aka RCE (also Fujitsu MMA)
    MCORE = 39,
    /// ARM
    ARM = 40,
    /// Digital Alpha
    OLD_ALPHA = 41,
    /// Renesas (formerly Hitachi) / SuperH SH
    SH = 42,
    /// SPARC v9 64-bit
    SPARCV9 = 43,
    /// Siemens Tricore embedded processor
    TRICORE = 44,
    /// ARC Cores
    ARC = 45,
    /// Renesas (formerly Hitachi) H8/300
    H8_300 = 46,
    /// Renesas (formerly Hitachi) H8/300H
    H8_300H = 47,
    /// Renesas (formerly Hitachi) H8S
    H8S = 48,
    /// Renesas (formerly Hitachi) H8/500
    H8_500 = 49,
    /// Intel IA-64 Processor
    IA_64 = 50,
    /// Stanford MIPS-X
    MIPS_X = 51,
    /// Motorola Coldfire
    COLDFIRE = 52,
    /// Motorola M68HC12
    @"68HC12" = 53,
    /// Fujitsu Multimedia Accelerator
    MMA = 54,
    /// Siemens PCP
    PCP = 55,
    /// Sony nCPU embedded RISC processor
    NCPU = 56,
    /// Denso NDR1 microprocessor
    NDR1 = 57,
    /// Motorola Star*Core processor
    STARCORE = 58,
    /// Toyota ME16 processor
    ME16 = 59,
    /// STMicroelectronics ST100 processor
    ST100 = 60,
    /// Advanced Logic Corp. TinyJ embedded processor
    TINYJ = 61,
    /// Advanced Micro Devices X86-64 processor
    X86_64 = 62,
    /// Sony DSP Processor
    PDSP = 63,
    /// Digital Equipment Corp. PDP-10
    PDP10 = 64,
    /// Digital Equipment Corp. PDP-11
    PDP11 = 65,
    /// Siemens FX66 microcontroller
    FX66 = 66,
    /// STMicroelectronics ST9+ 8/16 bit microcontroller
    ST9PLUS = 67,
    /// STMicroelectronics ST7 8-bit microcontroller
    ST7 = 68,
    /// Motorola MC68HC16 Microcontroller
    @"68HC16" = 69,
    /// Motorola MC68HC11 Microcontroller
    @"68HC11" = 70,
    /// Motorola MC68HC08 Microcontroller
    @"68HC08" = 71,
    /// Motorola MC68HC05 Microcontroller
    @"68HC05" = 72,
    /// Silicon Graphics SVx
    SVX = 73,
    /// STMicroelectronics ST19 8-bit cpu
    ST19 = 74,
    /// Digital VAX
    VAX = 75,
    /// Axis Communications 32-bit embedded processor
    CRIS = 76,
    /// Infineon Technologies 32-bit embedded cpu
    JAVELIN = 77,
    /// Element 14 64-bit DSP processor
    FIREPATH = 78,
    /// LSI Logic's 16-bit DSP processor
    ZSP = 79,
    /// Donald Knuth's educational 64-bit processor
    MMIX = 80,
    /// Harvard's machine-independent format
    HUANY = 81,
    /// SiTera Prism
    PRISM = 82,
    /// Atmel AVR 8-bit microcontroller
    AVR = 83,
    /// Fujitsu FR30
    FR30 = 84,
    /// Mitsubishi D10V
    D10V = 85,
    /// Mitsubishi D30V
    D30V = 86,
    /// Renesas V850 (formerly NEC V850)
    V850 = 87,
    /// Renesas M32R (formerly Mitsubishi M32R)
    M32R = 88,
    /// Matsushita MN10300
    MN10300 = 89,
    /// Matsushita MN10200
    MN10200 = 90,
    /// picoJava
    PJ = 91,
    /// OpenRISC 1000 32-bit embedded processor
    OR1K = 92,
    /// ARC International ARCompact processor
    ARC_COMPACT = 93,
    /// Tensilica Xtensa Architecture
    XTENSA = 94,
    /// Alphamosaic VideoCore processor (also old Sunplus S+core7 backend magic number)
    VIDEOCORE = 95,
    /// Thompson Multimedia General Purpose Processor
    TMM_GPP = 96,
    /// National Semiconductor 32000 series
    NS32K = 97,
    /// Tenor Network TPC processor
    TPC = 98,
    /// Trebia SNP 1000 processor (also old value for picoJava; deprecated)
    SNP1K = 99,
    /// STMicroelectronics ST200 microcontroller
    ST200 = 100,
    /// Ubicom IP2022 micro controller
    IP2K = 101,
    /// MAX Processor
    MAX = 102,
    /// National Semiconductor CompactRISC
    CR = 103,
    /// Fujitsu F2MC16
    F2MC16 = 104,
    /// TI msp430 micro controller
    MSP430 = 105,
    /// ADI Blackfin
    BLACKFIN = 106,
    /// S1C33 Family of Seiko Epson processors
    SE_C33 = 107,
    /// Sharp embedded microprocessor
    SEP = 108,
    /// Arca RISC Microprocessor
    ARCA = 109,
    /// Microprocessor series from PKU-Unity Ltd. and MPRC of Peking University
    UNICORE = 110,
    /// eXcess: 16/32/64-bit configurable embedded CPU
    EXCESS = 111,
    /// Icera Semiconductor Inc. Deep Execution Processor
    DXP = 112,
    /// Altera Nios II soft-core processor
    ALTERA_NIOS2 = 113,
    /// National Semiconductor CRX
    CRX = 114,
    /// Motorola XGATE embedded processor (also old value for National Semiconductor CompactRISC; deprecated)
    XGATE = 115,
    /// Infineon C16x/XC16x processor
    C166 = 116,
    /// Renesas M16C series microprocessors
    M16C = 117,
    /// Microchip Technology dsPIC30F Digital Signal Controller
    DSPIC30F = 118,
    /// Freescale Communication Engine RISC core
    CE = 119,
    /// Renesas M32C series microprocessors
    M32C = 120,
    /// Altium TSK3000 core
    TSK3000 = 131,
    /// Freescale RS08 embedded processor
    RS08 = 132,
    /// Analog Devices SHARC family of 32-bit DSP processors
    SHARC = 133,
    /// Cyan Technology eCOG2 microprocessor
    ECOG2 = 134,
    /// Sunplus S+core (and S+core7) RISC processor
    SCORE = 135,
    /// New Japan Radio (NJR) 24-bit DSP Processor
    DSP24 = 136,
    /// Broadcom VideoCore III processor
    VIDEOCORE3 = 137,
    /// RISC processor for Lattice FPGA architecture
    LATTICEMICO32 = 138,
    /// Seiko Epson C17 family
    SE_C17 = 139,
    /// Texas Instruments TMS320C6000 DSP family
    TI_C6000 = 140,
    /// Texas Instruments TMS320C2000 DSP family
    TI_C2000 = 141,
    /// Texas Instruments TMS320C55x DSP family
    TI_C5500 = 142,
    /// Texas Instruments Programmable Realtime Unit
    TI_PRU = 144,
    /// STMicroelectronics 64bit VLIW Data Signal Processor
    MMDSP_PLUS = 160,
    /// Cypress M8C microprocessor
    CYPRESS_M8C = 161,
    /// Renesas R32C series microprocessors
    R32C = 162,
    /// NXP Semiconductors TriMedia architecture family
    TRIMEDIA = 163,
    /// QUALCOMM DSP6 Processor
    QDSP6 = 164,
    /// Intel 8051 and variants
    @"8051" = 165,
    /// STMicroelectronics STxP7x family
    STXP7X = 166,
    /// Andes Technology compact code size embedded RISC processor family
    NDS32 = 167,
    /// Cyan Technology eCOG1X family
    ECOG1X = 168,
    /// Dallas Semiconductor MAXQ30 Core Micro-controllers
    MAXQ30 = 169,
    /// New Japan Radio (NJR) 16-bit DSP Processor
    XIMO16 = 170,
    /// M2000 Reconfigurable RISC Microprocessor
    MANIK = 171,
    /// Cray Inc. NV2 vector architecture
    CRAYNV2 = 172,
    /// Renesas RX family
    RX = 173,
    /// Imagination Technologies Meta processor architecture
    METAG = 174,
    /// MCST Elbrus general purpose hardware architecture
    MCST_ELBRUS = 175,
    /// Cyan Technology eCOG16 family
    ECOG16 = 176,
    /// National Semiconductor CompactRISC 16-bit processor
    CR16 = 177,
    /// Freescale Extended Time Processing Unit
    ETPU = 178,
    /// Infineon Technologies SLE9X core
    SLE9X = 179,
    /// Intel L10M
    L10M = 180,
    /// Intel K10M
    K10M = 181,
    /// ARM 64-bit architecture
    AARCH64 = 183,
    /// Atmel Corporation 32-bit microprocessor family
    AVR32 = 185,
    /// STMicroeletronics STM8 8-bit microcontroller
    STM8 = 186,
    /// Tilera TILE64 multicore architecture family
    TILE64 = 187,
    /// Tilera TILEPro multicore architecture family
    TILEPRO = 188,
    /// Xilinx MicroBlaze 32-bit RISC soft processor core
    MICROBLAZE = 189,
    /// NVIDIA CUDA architecture
    CUDA = 190,
    /// Tilera TILE-Gx multicore architecture family
    TILEGX = 191,
    /// CloudShield architecture family
    CLOUDSHIELD = 192,
    /// KIPO-KAIST Core-A 1st generation processor family
    COREA_1ST = 193,
    /// KIPO-KAIST Core-A 2nd generation processor family
    COREA_2ND = 194,
    /// Synopsys ARCompact V2
    ARC_COMPACT2 = 195,
    /// Open8 8-bit RISC soft processor core
    OPEN8 = 196,
    /// Renesas RL78 family
    RL78 = 197,
    /// Broadcom VideoCore V processor
    VIDEOCORE5 = 198,
    /// Renesas 78K0R
    @"78K0R" = 199,
    /// Freescale 56800EX Digital Signal Controller (DSC)
    @"56800EX" = 200,
    /// Beyond BA1 CPU architecture
    BA1 = 201,
    /// Beyond BA2 CPU architecture
    BA2 = 202,
    /// XMOS xCORE processor family
    XCORE = 203,
    /// Microchip 8-bit PIC(r) family
    MCHP_PIC = 204,
    /// Intel Graphics Technology
    INTELGT = 205,
    /// KM211 KM32 32-bit processor
    KM32 = 210,
    /// KM211 KMX32 32-bit processor
    KMX32 = 211,
    /// KM211 KMX16 16-bit processor
    KMX16 = 212,
    /// KM211 KMX8 8-bit processor
    KMX8 = 213,
    /// KM211 KVARC processor
    KVARC = 214,
    /// Paneve CDP architecture family
    CDP = 215,
    /// Cognitive Smart Memory Processor
    COGE = 216,
    /// Bluechip Systems CoolEngine
    COOL = 217,
    /// Nanoradio Optimized RISC
    NORC = 218,
    /// CSR Kalimba architecture family
    CSR_KALIMBA = 219,
    /// Zilog Z80
    Z80 = 220,
    /// Controls and Data Services VISIUMcore processor
    VISIUM = 221,
    /// FTDI Chip FT32 high performance 32-bit RISC architecture
    FT32 = 222,
    /// Moxie processor family
    MOXIE = 223,
    /// AMD GPU architecture
    AMDGPU = 224,
    /// RISC-V
    RISCV = 243,
    /// Lanai 32-bit processor
    LANAI = 244,
    /// CEVA Processor Architecture Family
    CEVA = 245,
    /// CEVA X2 Processor Family
    CEVA_X2 = 246,
    /// Linux BPF - in-kernel virtual machine
    BPF = 247,
    /// Graphcore Intelligent Processing Unit
    GRAPHCORE_IPU = 248,
    /// Imagination Technologies
    IMG1 = 249,
    /// Netronome Flow Processor
    NFP = 250,
    /// NEC Vector Engine
    VE = 251,
    /// C-SKY processor family
    CSKY = 252,
    /// Synopsys ARCv2.3 64-bit
    ARC_COMPACT3_64 = 253,
    /// MOS Technology MCS 6502 processor
    MCS6502 = 254,
    /// Synopsys ARCv2.3 32-bit
    ARC_COMPACT3 = 255,
    /// Kalray VLIW core of the MPPA processor family
    KVX = 256,
    /// WDC 65816/65C816
    @"65816" = 257,
    /// LoongArch
    LOONGARCH = 258,
    /// ChipON KungFu32
    KF32 = 259,
    /// LAPIS nX-U16/U8
    U16_U8CORE = 260,
    /// Tachyum
    TACHYUM = 261,
    /// NXP 56800EF Digital Signal Controller (DSC)
    @"56800EF" = 262,
    /// AVR
    AVR_OLD = 0x1057,
    /// MSP430
    MSP430_OLD = 0x1059,
    /// Morpho MT
    MT = 0x2530,
    /// FR30
    CYGNUS_FR30 = 0x3330,
    /// WebAssembly (as used by LLVM)
    WEBASSEMBLY = 0x4157,
    /// Infineon Technologies 16-bit microcontroller with C166-V2 core
    XC16X = 0x4688,
    /// Freescale S12Z
    S12Z = 0x4def,
    /// DLX
    DLX = 0x5aa5,
    /// FRV
    CYGNUS_FRV = 0x5441,
    /// D10V
    CYGNUS_D10V = 0x7650,
    /// D30V
    CYGNUS_D30V = 0x7676,
    /// Ubicom IP2xxx
    IP2K_OLD = 0x8217,
    /// Cygnus PowerPC ELF
    CYGNUS_POWERPC = 0x9025,
    /// Alpha
    ALPHA = 0x9026,
    /// Cygnus M32R ELF
    CYGNUS_M32R = 0x9041,
    /// V850
    CYGNUS_V850 = 0x9080,
    /// Old S/390
    S390_OLD = 0xa390,
    /// Old unofficial value for Xtensa
    XTENSA_OLD = 0xabc7,
    /// Xstormy16
    XSTORMY16 = 0xad45,
    /// MN10300
    CYGNUS_MN10300 = 0xbeef,
    /// MN10200
    CYGNUS_MN10200 = 0xdead,
    /// Renesas M32C and M16C
    M32C_OLD = 0xfeb0,
    /// Vitesse IQ2000
    IQ2000 = 0xfeba,
    /// NIOS
    NIOS32 = 0xfebb,
    /// Toshiba MeP
    CYGNUS_MEP = 0xf00d,
    /// Old unofficial value for Moxie
    MOXIE_OLD = 0xfeed,
    /// Old MicroBlaze
    MICROBLAZE_OLD = 0xbaab,
    /// Adapteva's Epiphany architecture
    ADAPTEVA_EPIPHANY = 0x1223,

    /// Parallax Propeller (P1)
    /// This value is an unofficial ELF value used in: https://github.com/parallaxinc/propgcc
    PROPELLER = 0x5072,

    /// Parallax Propeller 2 (P2)
    /// This value is an unofficial ELF value used in: https://github.com/ne75/llvm-project
    PROPELLER2 = 300,

    _,
};

pub const GRP_COMDAT = 1;

/// Section data should be writable during execution.
pub const SHF_WRITE = 0x1;

/// Section occupies memory during program execution.
pub const SHF_ALLOC = 0x2;

/// Section contains executable machine instructions.
pub const SHF_EXECINSTR = 0x4;

/// The data in this section may be merged.
pub const SHF_MERGE = 0x10;

/// The data in this section is null-terminated strings.
pub const SHF_STRINGS = 0x20;

/// A field in this section holds a section header table index.
pub const SHF_INFO_LINK = 0x40;

/// Adds special ordering requirements for link editors.
pub const SHF_LINK_ORDER = 0x80;

/// This section requires special OS-specific processing to avoid incorrect
/// behavior.
pub const SHF_OS_NONCONFORMING = 0x100;

/// This section is a member of a section group.
pub const SHF_GROUP = 0x200;

/// This section holds Thread-Local Storage.
pub const SHF_TLS = 0x400;

/// Identifies a section containing compressed data.
pub const SHF_COMPRESSED = 0x800;

/// Not to be GCed by the linker
pub const SHF_GNU_RETAIN = 0x200000;

/// This section is excluded from the final executable or shared library.
pub const SHF_EXCLUDE = 0x80000000;

/// Start of target-specific flags.
pub const SHF_MASKOS = 0x0ff00000;

/// Bits indicating processor-specific flags.
pub const SHF_MASKPROC = 0xf0000000;

/// All sections with the "d" flag are grouped together by the linker to form
/// the data section and the dp register is set to the start of the section by
/// the boot code.
pub const XCORE_SHF_DP_SECTION = 0x10000000;

/// All sections with the "c" flag are grouped together by the linker to form
/// the constant pool and the cp register is set to the start of the constant
/// pool by the boot code.
pub const XCORE_SHF_CP_SECTION = 0x20000000;

/// If an object file section does not have this flag set, then it may not hold
/// more than 2GB and can be freely referred to in objects using smaller code
/// models. Otherwise, only objects using larger code models can refer to them.
/// For example, a medium code model object can refer to data in a section that
/// sets this flag besides being able to refer to data in a section that does
/// not set it; likewise, a small code model object can refer only to code in a
/// section that does not set this flag.
pub const SHF_X86_64_LARGE = 0x10000000;

/// All sections with the GPREL flag are grouped into a global data area
/// for faster accesses
pub const SHF_HEX_GPREL = 0x10000000;

/// Section contains text/data which may be replicated in other sections.
/// Linker must retain only one copy.
pub const SHF_MIPS_NODUPES = 0x01000000;

/// Linker must generate implicit hidden weak names.
pub const SHF_MIPS_NAMES = 0x02000000;

/// Section data local to process.
pub const SHF_MIPS_LOCAL = 0x04000000;

/// Do not strip this section.
pub const SHF_MIPS_NOSTRIP = 0x08000000;

/// Section must be part of global data area.
pub const SHF_MIPS_GPREL = 0x10000000;

/// This section should be merged.
pub const SHF_MIPS_MERGE = 0x20000000;

/// Address size to be inferred from section entry size.
pub const SHF_MIPS_ADDR = 0x40000000;

/// Section data is string data by default.
pub const SHF_MIPS_STRING = 0x80000000;

/// Make code section unreadable when in execute-only mode
pub const SHF_ARM_PURECODE = 0x2000000;

/// Execute
pub const PF_X = 1;

/// Write
pub const PF_W = 2;

/// Read
pub const PF_R = 4;

/// Bits for operating system-specific semantics.
pub const PF_MASKOS = 0x0ff00000;

/// Bits for processor-specific semantics.
pub const PF_MASKPROC = 0xf0000000;

/// Undefined section
pub const SHN_UNDEF = 0;
/// Start of reserved indices
pub const SHN_LORESERVE = 0xff00;
/// Start of processor-specific
pub const SHN_LOPROC = 0xff00;
/// End of processor-specific
pub const SHN_HIPROC = 0xff1f;
pub const SHN_LIVEPATCH = 0xff20;
/// Associated symbol is absolute
pub const SHN_ABS = 0xfff1;
/// Associated symbol is common
pub const SHN_COMMON = 0xfff2;
/// End of reserved indices
pub const SHN_HIRESERVE = 0xffff;

// Legal values for ch_type (compression algorithm).
pub const COMPRESS = enum(u32) {
    ZLIB = 1,
    ZSTD = 2,
    LOOS = 0x60000000,
    HIOS = 0x6fffffff,
    LOPROC = 0x70000000,
    HIPROC = 0x7fffffff,
    _,
};

/// AMD x86-64 relocations.
pub const R_X86_64 = enum(u32) {
    /// No reloc
    NONE = 0,
    /// Direct 64 bit
    @"64" = 1,
    /// PC relative 32 bit signed
    PC32 = 2,
    /// 32 bit GOT entry
    GOT32 = 3,
    /// 32 bit PLT address
    PLT32 = 4,
    /// Copy symbol at runtime
    COPY = 5,
    /// Create GOT entry
    GLOB_DAT = 6,
    /// Create PLT entry
    JUMP_SLOT = 7,
    /// Adjust by program base
    RELATIVE = 8,
    /// 32 bit signed PC relative offset to GOT
    GOTPCREL = 9,
    /// Direct 32 bit zero extended
    @"32" = 10,
    /// Direct 32 bit sign extended
    @"32S" = 11,
    /// Direct 16 bit zero extended
    @"16" = 12,
    /// 16 bit sign extended pc relative
    PC16 = 13,
    /// Direct 8 bit sign extended
    @"8" = 14,
    /// 8 bit sign extended pc relative
    PC8 = 15,
    /// ID of module containing symbol
    DTPMOD64 = 16,
    /// Offset in module's TLS block
    DTPOFF64 = 17,
    /// Offset in initial TLS block
    TPOFF64 = 18,
    /// 32 bit signed PC relative offset to two GOT entries for GD symbol
    TLSGD = 19,
    /// 32 bit signed PC relative offset to two GOT entries for LD symbol
    TLSLD = 20,
    /// Offset in TLS block
    DTPOFF32 = 21,
    /// 32 bit signed PC relative offset to GOT entry for IE symbol
    GOTTPOFF = 22,
    /// Offset in initial TLS block
    TPOFF32 = 23,
    /// PC relative 64 bit
    PC64 = 24,
    /// 64 bit offset to GOT
    GOTOFF64 = 25,
    /// 32 bit signed pc relative offset to GOT
    GOTPC32 = 26,
    /// 64 bit GOT entry offset
    GOT64 = 27,
    /// 64 bit PC relative offset to GOT entry
    GOTPCREL64 = 28,
    /// 64 bit PC relative offset to GOT
    GOTPC64 = 29,
    /// Like GOT64, says PLT entry needed
    GOTPLT64 = 30,
    /// 64-bit GOT relative offset to PLT entry
    PLTOFF64 = 31,
    /// Size of symbol plus 32-bit addend
    SIZE32 = 32,
    /// Size of symbol plus 64-bit addend
    SIZE64 = 33,
    /// GOT offset for TLS descriptor
    GOTPC32_TLSDESC = 34,
    /// Marker for call through TLS descriptor
    TLSDESC_CALL = 35,
    /// TLS descriptor
    TLSDESC = 36,
    /// Adjust indirectly by program base
    IRELATIVE = 37,
    /// 64-bit adjust by program base
    RELATIVE64 = 38,
    /// 39 Reserved was PC32_BND
    /// 40 Reserved was PLT32_BND
    /// Load from 32 bit signed pc relative offset to GOT entry without REX prefix, relaxable
    GOTPCRELX = 41,
    /// Load from 32 bit signed PC relative offset to GOT entry with REX prefix, relaxable
    REX_GOTPCRELX = 42,
    _,
};

/// AArch64 relocations.
pub const R_AARCH64 = enum(u32) {
    /// No relocation.
    NONE = 0,
    /// ILP32 AArch64 relocs.
    /// Direct 32 bit.
    P32_ABS32 = 1,
    /// Copy symbol at runtime.
    P32_COPY = 180,
    /// Create GOT entry.
    P32_GLOB_DAT = 181,
    /// Create PLT entry.
    P32_JUMP_SLOT = 182,
    /// Adjust by program base.
    P32_RELATIVE = 183,
    /// Module number, 32 bit.
    P32_TLS_DTPMOD = 184,
    /// Module-relative offset, 32 bit.
    P32_TLS_DTPREL = 185,
    /// TP-relative offset, 32 bit.
    P32_TLS_TPREL = 186,
    /// TLS Descriptor.
    P32_TLSDESC = 187,
    /// STT_GNU_IFUNC relocation.
    P32_IRELATIVE = 188,
    /// LP64 AArch64 relocs.
    /// Direct 64 bit.
    ABS64 = 257,
    /// Direct 32 bit.
    ABS32 = 258,
    /// Direct 16-bit.
    ABS16 = 259,
    /// PC-relative 64-bit.
    PREL64 = 260,
    /// PC-relative 32-bit.
    PREL32 = 261,
    /// PC-relative 16-bit.
    PREL16 = 262,
    /// Dir. MOVZ imm. from bits 15:0.
    MOVW_UABS_G0 = 263,
    /// Likewise for MOVK; no check.
    MOVW_UABS_G0_NC = 264,
    /// Dir. MOVZ imm. from bits 31:16.
    MOVW_UABS_G1 = 265,
    /// Likewise for MOVK; no check.
    MOVW_UABS_G1_NC = 266,
    /// Dir. MOVZ imm. from bits 47:32.
    MOVW_UABS_G2 = 267,
    /// Likewise for MOVK; no check.
    MOVW_UABS_G2_NC = 268,
    /// Dir. MOV{K,Z} imm. from 63:48.
    MOVW_UABS_G3 = 269,
    /// Dir. MOV{N,Z} imm. from 15:0.
    MOVW_SABS_G0 = 270,
    /// Dir. MOV{N,Z} imm. from 31:16.
    MOVW_SABS_G1 = 271,
    /// Dir. MOV{N,Z} imm. from 47:32.
    MOVW_SABS_G2 = 272,
    /// PC-rel. LD imm. from bits 20:2.
    LD_PREL_LO19 = 273,
    /// PC-rel. ADR imm. from bits 20:0.
    ADR_PREL_LO21 = 274,
    /// Page-rel. ADRP imm. from 32:12.
    ADR_PREL_PG_HI21 = 275,
    /// Likewise; no overflow check.
    ADR_PREL_PG_HI21_NC = 276,
    /// Dir. ADD imm. from bits 11:0.
    ADD_ABS_LO12_NC = 277,
    /// Likewise for LD/ST; no check.
    LDST8_ABS_LO12_NC = 278,
    /// PC-rel. TBZ/TBNZ imm. from 15:2.
    TSTBR14 = 279,
    /// PC-rel. cond. br. imm. from 20:2.
    CONDBR19 = 280,
    /// PC-rel. B imm. from bits 27:2.
    JUMP26 = 282,
    /// Likewise for CALL.
    CALL26 = 283,
    /// Dir. ADD imm. from bits 11:1.
    LDST16_ABS_LO12_NC = 284,
    /// Likewise for bits 11:2.
    LDST32_ABS_LO12_NC = 285,
    /// Likewise for bits 11:3.
    LDST64_ABS_LO12_NC = 286,
    /// PC-rel. MOV{N,Z} imm. from 15:0.
    MOVW_PREL_G0 = 287,
    /// Likewise for MOVK; no check.
    MOVW_PREL_G0_NC = 288,
    /// PC-rel. MOV{N,Z} imm. from 31:16.
    MOVW_PREL_G1 = 289,
    /// Likewise for MOVK; no check.
    MOVW_PREL_G1_NC = 290,
    /// PC-rel. MOV{N,Z} imm. from 47:32.
    MOVW_PREL_G2 = 291,
    /// Likewise for MOVK; no check.
    MOVW_PREL_G2_NC = 292,
    /// PC-rel. MOV{N,Z} imm. from 63:48.
    MOVW_PREL_G3 = 293,
    /// Dir. ADD imm. from bits 11:4.
    LDST128_ABS_LO12_NC = 299,
    /// GOT-rel. off. MOV{N,Z} imm. 15:0.
    MOVW_GOTOFF_G0 = 300,
    /// Likewise for MOVK; no check.
    MOVW_GOTOFF_G0_NC = 301,
    /// GOT-rel. o. MOV{N,Z} imm. 31:16.
    MOVW_GOTOFF_G1 = 302,
    /// Likewise for MOVK; no check.
    MOVW_GOTOFF_G1_NC = 303,
    /// GOT-rel. o. MOV{N,Z} imm. 47:32.
    MOVW_GOTOFF_G2 = 304,
    /// Likewise for MOVK; no check.
    MOVW_GOTOFF_G2_NC = 305,
    /// GOT-rel. o. MOV{N,Z} imm. 63:48.
    MOVW_GOTOFF_G3 = 306,
    /// GOT-relative 64-bit.
    GOTREL64 = 307,
    /// GOT-relative 32-bit.
    GOTREL32 = 308,
    /// PC-rel. GOT off. load imm. 20:2.
    GOT_LD_PREL19 = 309,
    /// GOT-rel. off. LD/ST imm. 14:3.
    LD64_GOTOFF_LO15 = 310,
    /// P-page-rel. GOT off. ADRP 32:12.
    ADR_GOT_PAGE = 311,
    /// Dir. GOT off. LD/ST imm. 11:3.
    LD64_GOT_LO12_NC = 312,
    /// GOT-page-rel. GOT off. LD/ST 14:3
    LD64_GOTPAGE_LO15 = 313,
    /// PC-relative ADR imm. 20:0.
    TLSGD_ADR_PREL21 = 512,
    /// page-rel. ADRP imm. 32:12.
    TLSGD_ADR_PAGE21 = 513,
    /// direct ADD imm. from 11:0.
    TLSGD_ADD_LO12_NC = 514,
    /// GOT-rel. MOV{N,Z} 31:16.
    TLSGD_MOVW_G1 = 515,
    /// GOT-rel. MOVK imm. 15:0.
    TLSGD_MOVW_G0_NC = 516,
    /// Like 512; local dynamic model.
    TLSLD_ADR_PREL21 = 517,
    /// Like 513; local dynamic model.
    TLSLD_ADR_PAGE21 = 518,
    /// Like 514; local dynamic model.
    TLSLD_ADD_LO12_NC = 519,
    /// Like 515; local dynamic model.
    TLSLD_MOVW_G1 = 520,
    /// Like 516; local dynamic model.
    TLSLD_MOVW_G0_NC = 521,
    /// TLS PC-rel. load imm. 20:2.
    TLSLD_LD_PREL19 = 522,
    /// TLS DTP-rel. MOV{N,Z} 47:32.
    TLSLD_MOVW_DTPREL_G2 = 523,
    /// TLS DTP-rel. MOV{N,Z} 31:16.
    TLSLD_MOVW_DTPREL_G1 = 524,
    /// Likewise; MOVK; no check.
    TLSLD_MOVW_DTPREL_G1_NC = 525,
    /// TLS DTP-rel. MOV{N,Z} 15:0.
    TLSLD_MOVW_DTPREL_G0 = 526,
    /// Likewise; MOVK; no check.
    TLSLD_MOVW_DTPREL_G0_NC = 527,
    /// DTP-rel. ADD imm. from 23:12.
    TLSLD_ADD_DTPREL_HI12 = 528,
    /// DTP-rel. ADD imm. from 11:0.
    TLSLD_ADD_DTPREL_LO12 = 529,
    /// Likewise; no ovfl. check.
    TLSLD_ADD_DTPREL_LO12_NC = 530,
    /// DTP-rel. LD/ST imm. 11:0.
    TLSLD_LDST8_DTPREL_LO12 = 531,
    /// Likewise; no check.
    TLSLD_LDST8_DTPREL_LO12_NC = 532,
    /// DTP-rel. LD/ST imm. 11:1.
    TLSLD_LDST16_DTPREL_LO12 = 533,
    /// Likewise; no check.
    TLSLD_LDST16_DTPREL_LO12_NC = 534,
    /// DTP-rel. LD/ST imm. 11:2.
    TLSLD_LDST32_DTPREL_LO12 = 535,
    /// Likewise; no check.
    TLSLD_LDST32_DTPREL_LO12_NC = 536,
    /// DTP-rel. LD/ST imm. 11:3.
    TLSLD_LDST64_DTPREL_LO12 = 537,
    /// Likewise; no check.
    TLSLD_LDST64_DTPREL_LO12_NC = 538,
    /// GOT-rel. MOV{N,Z} 31:16.
    TLSIE_MOVW_GOTTPREL_G1 = 539,
    /// GOT-rel. MOVK 15:0.
    TLSIE_MOVW_GOTTPREL_G0_NC = 540,
    /// Page-rel. ADRP 32:12.
    TLSIE_ADR_GOTTPREL_PAGE21 = 541,
    /// Direct LD off. 11:3.
    TLSIE_LD64_GOTTPREL_LO12_NC = 542,
    /// PC-rel. load imm. 20:2.
    TLSIE_LD_GOTTPREL_PREL19 = 543,
    /// TLS TP-rel. MOV{N,Z} 47:32.
    TLSLE_MOVW_TPREL_G2 = 544,
    /// TLS TP-rel. MOV{N,Z} 31:16.
    TLSLE_MOVW_TPREL_G1 = 545,
    /// Likewise; MOVK; no check.
    TLSLE_MOVW_TPREL_G1_NC = 546,
    /// TLS TP-rel. MOV{N,Z} 15:0.
    TLSLE_MOVW_TPREL_G0 = 547,
    /// Likewise; MOVK; no check.
    TLSLE_MOVW_TPREL_G0_NC = 548,
    /// TP-rel. ADD imm. 23:12.
    TLSLE_ADD_TPREL_HI12 = 549,
    /// TP-rel. ADD imm. 11:0.
    TLSLE_ADD_TPREL_LO12 = 550,
    /// Likewise; no ovfl. check.
    TLSLE_ADD_TPREL_LO12_NC = 551,
    /// TP-rel. LD/ST off. 11:0.
    TLSLE_LDST8_TPREL_LO12 = 552,
    /// Likewise; no ovfl. check.
    TLSLE_LDST8_TPREL_LO12_NC = 553,
    /// TP-rel. LD/ST off. 11:1.
    TLSLE_LDST16_TPREL_LO12 = 554,
    /// Likewise; no check.
    TLSLE_LDST16_TPREL_LO12_NC = 555,
    /// TP-rel. LD/ST off. 11:2.
    TLSLE_LDST32_TPREL_LO12 = 556,
    /// Likewise; no check.
    TLSLE_LDST32_TPREL_LO12_NC = 557,
    /// TP-rel. LD/ST off. 11:3.
    TLSLE_LDST64_TPREL_LO12 = 558,
    /// Likewise; no check.
    TLSLE_LDST64_TPREL_LO12_NC = 559,
    ///  PC-rel. load immediate 20:2.
    TLSDESC_LD_PREL19 = 560,
    /// PC-rel. ADR immediate 20:0.
    TLSDESC_ADR_PREL21 = 561,
    /// Page-rel. ADRP imm. 32:12.
    TLSDESC_ADR_PAGE21 = 562,
    /// Direct LD off. from 11:3.
    TLSDESC_LD64_LO12 = 563,
    /// Direct ADD imm. from 11:0.
    TLSDESC_ADD_LO12 = 564,
    /// GOT-rel. MOV{N,Z} imm. 31:16.
    TLSDESC_OFF_G1 = 565,
    /// GOT-rel. MOVK imm. 15:0; no ck.
    TLSDESC_OFF_G0_NC = 566,
    /// Relax LDR.
    TLSDESC_LDR = 567,
    /// Relax ADD.
    TLSDESC_ADD = 568,
    /// Relax BLR.
    TLSDESC_CALL = 569,
    /// TP-rel. LD/ST off. 11:4.
    TLSLE_LDST128_TPREL_LO12 = 570,
    /// Likewise; no check.
    TLSLE_LDST128_TPREL_LO12_NC = 571,
    /// DTP-rel. LD/ST imm. 11:4.
    TLSLD_LDST128_DTPREL_LO12 = 572,
    /// Likewise; no check.
    TLSLD_LDST128_DTPREL_LO12_NC = 573,
    /// Copy symbol at runtime.
    COPY = 1024,
    /// Create GOT entry.
    GLOB_DAT = 1025,
    /// Create PLT entry.
    JUMP_SLOT = 1026,
    /// Adjust by program base.
    RELATIVE = 1027,
    /// Module number, 64 bit.
    TLS_DTPMOD = 1028,
    /// Module-relative offset, 64 bit.
    TLS_DTPREL = 1029,
    /// TP-relative offset, 64 bit.
    TLS_TPREL = 1030,
    /// TLS Descriptor.
    TLSDESC = 1031,
    /// STT_GNU_IFUNC relocation.
    IRELATIVE = 1032,
    _,
};

/// RISC-V relocations.
pub const R_RISCV = enum(u32) {
    NONE = 0,
    @"32" = 1,
    @"64" = 2,
    RELATIVE = 3,
    COPY = 4,
    JUMP_SLOT = 5,
    TLS_DTPMOD32 = 6,
    TLS_DTPMOD64 = 7,
    TLS_DTPREL32 = 8,
    TLS_DTPREL64 = 9,
    TLS_TPREL32 = 10,
    TLS_TPREL64 = 11,
    TLSDESC = 12,
    BRANCH = 16,
    JAL = 17,
    CALL = 18,
    CALL_PLT = 19,
    GOT_HI20 = 20,
    TLS_GOT_HI20 = 21,
    TLS_GD_HI20 = 22,
    PCREL_HI20 = 23,
    PCREL_LO12_I = 24,
    PCREL_LO12_S = 25,
    HI20 = 26,
    LO12_I = 27,
    LO12_S = 28,
    TPREL_HI20 = 29,
    TPREL_LO12_I = 30,
    TPREL_LO12_S = 31,
    TPREL_ADD = 32,
    ADD8 = 33,
    ADD16 = 34,
    ADD32 = 35,
    ADD64 = 36,
    SUB8 = 37,
    SUB16 = 38,
    SUB32 = 39,
    SUB64 = 40,
    GNU_VTINHERIT = 41,
    GNU_VTENTRY = 42,
    ALIGN = 43,
    RVC_BRANCH = 44,
    RVC_JUMP = 45,
    RVC_LUI = 46,
    GPREL_I = 47,
    GPREL_S = 48,
    TPREL_I = 49,
    TPREL_S = 50,
    RELAX = 51,
    SUB6 = 52,
    SET6 = 53,
    SET8 = 54,
    SET16 = 55,
    SET32 = 56,
    @"32_PCREL" = 57,
    IRELATIVE = 58,
    PLT32 = 59,
    SET_ULEB128 = 60,
    SUB_ULEB128 = 61,
    _,
};

/// PowerPC64 relocations.
pub const R_PPC64 = enum(u32) {
    NONE = 0,
    ADDR32 = 1,
    ADDR24 = 2,
    ADDR16 = 3,
    ADDR16_LO = 4,
    ADDR16_HI = 5,
    ADDR16_HA = 6,
    ADDR14 = 7,
    ADDR14_BRTAKEN = 8,
    ADDR14_BRNTAKEN = 9,
    REL24 = 10,
    REL14 = 11,
    REL14_BRTAKEN = 12,
    REL14_BRNTAKEN = 13,
    GOT16 = 14,
    GOT16_LO = 15,
    GOT16_HI = 16,
    GOT16_HA = 17,
    COPY = 19,
    GLOB_DAT = 20,
    JMP_SLOT = 21,
    RELATIVE = 22,
    REL32 = 26,
    PLT16_LO = 29,
    PLT16_HI = 30,
    PLT16_HA = 31,
    ADDR64 = 38,
    ADDR16_HIGHER = 39,
    ADDR16_HIGHERA = 40,
    ADDR16_HIGHEST = 41,
    ADDR16_HIGHESTA = 42,
    REL64 = 44,
    TOC16 = 47,
    TOC16_LO = 48,
    TOC16_HI = 49,
    TOC16_HA = 50,
    TOC = 51,
    ADDR16_DS = 56,
    ADDR16_LO_DS = 57,
    GOT16_DS = 58,
    GOT16_LO_DS = 59,
    PLT16_LO_DS = 60,
    TOC16_DS = 63,
    TOC16_LO_DS = 64,
    TLS = 67,
    DTPMOD64 = 68,
    TPREL16 = 69,
    TPREL16_LO = 70,
    TPREL16_HI = 71,
    TPREL16_HA = 72,
    TPREL64 = 73,
    DTPREL16 = 74,
    DTPREL16_LO = 75,
    DTPREL16_HI = 76,
    DTPREL16_HA = 77,
    DTPREL64 = 78,
    GOT_TLSGD16 = 79,
    GOT_TLSGD16_LO = 80,
    GOT_TLSGD16_HI = 81,
    GOT_TLSGD16_HA = 82,
    GOT_TLSLD16 = 83,
    GOT_TLSLD16_LO = 84,
    GOT_TLSLD16_HI = 85,
    GOT_TLSLD16_HA = 86,
    GOT_TPREL16_DS = 87,
    GOT_TPREL16_LO_DS = 88,
    GOT_TPREL16_HI = 89,
    GOT_TPREL16_HA = 90,
    GOT_DTPREL16_DS = 91,
    GOT_DTPREL16_LO_DS = 92,
    GOT_DTPREL16_HI = 93,
    GOT_DTPREL16_HA = 94,
    TPREL16_DS = 95,
    TPREL16_LO_DS = 96,
    TPREL16_HIGHER = 97,
    TPREL16_HIGHERA = 98,
    TPREL16_HIGHEST = 99,
    TPREL16_HIGHESTA = 100,
    DTPREL16_DS = 101,
    DTPREL16_LO_DS = 102,
    DTPREL16_HIGHER = 103,
    DTPREL16_HIGHERA = 104,
    DTPREL16_HIGHEST = 105,
    DTPREL16_HIGHESTA = 106,
    TLSGD = 107,
    TLSLD = 108,
    ADDR16_HIGH = 110,
    ADDR16_HIGHA = 111,
    TPREL16_HIGH = 112,
    TPREL16_HIGHA = 113,
    DTPREL16_HIGH = 114,
    DTPREL16_HIGHA = 115,
    REL24_NOTOC = 116,
    PLTSEQ = 119,
    PLTCALL = 120,
    PLTSEQ_NOTOC = 121,
    PLTCALL_NOTOC = 122,
    PCREL_OPT = 123,
    PCREL34 = 132,
    GOT_PCREL34 = 133,
    PLT_PCREL34 = 134,
    PLT_PCREL34_NOTOC = 135,
    TPREL34 = 146,
    DTPREL34 = 147,
    GOT_TLSGD_PCREL34 = 148,
    GOT_TLSLD_PCREL34 = 149,
    GOT_TPREL_PCREL34 = 150,
    IRELATIVE = 248,
    REL16 = 249,
    REL16_LO = 250,
    REL16_HI = 251,
    REL16_HA = 252,
    _,
};

pub const STV = enum(u2) {
    DEFAULT = 0,
    INTERNAL = 1,
    HIDDEN = 2,
    PROTECTED = 3,
};

pub const ar_hdr = extern struct {
    /// Member file name, sometimes / terminated.
    ar_name: [16]u8,

    /// File date, decimal seconds since Epoch.
    ar_date: [12]u8,

    /// User ID, in ASCII format.
    ar_uid: [6]u8,

    /// Group ID, in ASCII format.
    ar_gid: [6]u8,

    /// File mode, in ASCII octal.
    ar_mode: [8]u8,

    /// File size, in ASCII decimal.
    ar_size: [10]u8,

    /// Always contains ARFMAG.
    ar_fmag: [2]u8,

    pub fn date(self: ar_hdr) std.fmt.ParseIntError!u64 {
        const value = mem.trimRight(u8, &self.ar_date, &[_]u8{0x20});
        return std.fmt.parseInt(u64, value, 10);
    }

    pub fn size(self: ar_hdr) std.fmt.ParseIntError!u32 {
        const value = mem.trimRight(u8, &self.ar_size, &[_]u8{0x20});
        return std.fmt.parseInt(u32, value, 10);
    }

    pub fn isStrtab(self: ar_hdr) bool {
        return mem.eql(u8, &self.ar_name, STRNAME);
    }

    pub fn isSymtab(self: ar_hdr) bool {
        return mem.eql(u8, &self.ar_name, SYMNAME);
    }

    pub fn isSymtab64(self: ar_hdr) bool {
        return mem.eql(u8, &self.ar_name, SYM64NAME);
    }

    pub fn isSymdef(self: ar_hdr) bool {
        return mem.eql(u8, &self.ar_name, SYMDEFNAME);
    }

    pub fn isSymdefSorted(self: ar_hdr) bool {
        return mem.eql(u8, &self.ar_name, SYMDEFSORTEDNAME);
    }

    pub fn name(self: *const ar_hdr) ?[]const u8 {
        const value = &self.ar_name;
        if (value[0] == '/') return null;
        const sentinel = mem.indexOfScalar(u8, value, '/') orelse value.len;
        return value[0..sentinel];
    }

    pub fn nameOffset(self: ar_hdr) std.fmt.ParseIntError!?u32 {
        const value = &self.ar_name;
        if (value[0] != '/') return null;
        const trimmed = mem.trimRight(u8, value, &[_]u8{0x20});
        return try std.fmt.parseInt(u32, trimmed[1..], 10);
    }
};

fn genSpecialMemberName(comptime name: []const u8) *const [16]u8 {
    assert(name.len <= 16);
    const padding = 16 - name.len;
    return name ++ &[_]u8{0x20} ** padding;
}

// Archive files start with the ARMAG identifying string.  Then follows a
// `struct ar_hdr', and as many bytes of member file data as its `ar_size'
// member indicates, for each member file.
/// String that begins an archive file.
pub const ARMAG = "!<arch>\n";
/// String in ar_fmag at the end of each header.
pub const ARFMAG = "`\n";
/// 32-bit symtab identifier
pub const SYMNAME = genSpecialMemberName("/");
/// Strtab identifier
pub const STRNAME = genSpecialMemberName("//");
/// 64-bit symtab identifier
pub const SYM64NAME = genSpecialMemberName("/SYM64/");
pub const SYMDEFNAME = genSpecialMemberName("__.SYMDEF");
pub const SYMDEFSORTEDNAME = genSpecialMemberName("__.SYMDEF SORTED");
