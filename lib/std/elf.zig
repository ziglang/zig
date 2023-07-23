const std = @import("std.zig");
const io = std.io;
const os = std.os;
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;
const File = std.fs.File;
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

pub const VERSYM_HIDDEN = 0x8000;
pub const VERSYM_VERSION = 0x7fff;

/// Symbol is local
pub const VER_NDX_LOCAL = 0;
/// Symbol is global
pub const VER_NDX_GLOBAL = 1;
/// Beginning of reserved entries
pub const VER_NDX_LORESERVE = 0xff00;
/// Symbol is to be eliminated
pub const VER_NDX_ELIMINATE = 0xff01;

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

    /// Beginning of processor-specific codes
    pub const LOPROC = 0xff00;

    /// Processor-specific
    pub const HIPROC = 0xffff;
};

/// All integers are native endian.
pub const Header = struct {
    endian: std.builtin.Endian,
    machine: EM,
    is_64: bool,
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

        const endian: std.builtin.Endian = switch (hdr32.e_ident[EI_DATA]) {
            ELFDATA2LSB => .Little,
            ELFDATA2MSB => .Big,
            else => return error.InvalidElfEndian,
        };
        const need_bswap = endian != native_endian;

        const is_64 = switch (hdr32.e_ident[EI_CLASS]) {
            ELFCLASS32 => false,
            ELFCLASS64 => true,
            else => return error.InvalidElfClass,
        };

        const machine = if (need_bswap) blk: {
            const value = @intFromEnum(hdr32.e_machine);
            break :blk @as(EM, @enumFromInt(@byteSwap(value)));
        } else hdr32.e_machine;

        return @as(Header, .{
            .endian = endian,
            .machine = machine,
            .is_64 = is_64,
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

pub fn int(is_64: bool, need_bswap: bool, int_32: anytype, int_64: anytype) @TypeOf(int_64) {
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

pub fn int32(need_bswap: bool, int_32: anytype, comptime Int64: anytype) Int64 {
    if (need_bswap) {
        return @byteSwap(int_32);
    } else {
        return int_32;
    }
}

pub const EI_NIDENT = 16;

pub const EI_CLASS = 4;
pub const ELFCLASSNONE = 0;
pub const ELFCLASS32 = 1;
pub const ELFCLASS64 = 2;
pub const ELFCLASSNUM = 3;

pub const EI_DATA = 5;
pub const ELFDATANONE = 0;
pub const ELFDATA2LSB = 1;
pub const ELFDATA2MSB = 2;
pub const ELFDATANUM = 3;

pub const EI_VERSION = 6;

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
    e_type: ET,
    e_machine: EM,
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
    e_type: ET,
    e_machine: EM,
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
    ch_type: COMPRESS,
    ch_size: Elf32_Word,
    ch_addralign: Elf32_Word,
};
pub const Elf64_Chdr = extern struct {
    ch_type: COMPRESS,
    ch_reserved: Elf64_Word = 0,
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

    pub inline fn st_type(self: @This()) u4 {
        return @as(u4, @truncate(self.st_info));
    }
    pub inline fn st_bind(self: @This()) u4 {
        return @as(u4, @truncate(self.st_info >> 4));
    }
};
pub const Elf64_Sym = extern struct {
    st_name: Elf64_Word,
    st_info: u8,
    st_other: u8,
    st_shndx: Elf64_Section,
    st_value: Elf64_Addr,
    st_size: Elf64_Xword,

    pub inline fn st_type(self: @This()) u4 {
        return @as(u4, @truncate(self.st_info));
    }
    pub inline fn st_bind(self: @This()) u4 {
        return @as(u4, @truncate(self.st_info >> 4));
    }
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

    pub inline fn r_sym(self: @This()) u24 {
        return @as(u24, @truncate(self.r_info >> 8));
    }
    pub inline fn r_type(self: @This()) u8 {
        return @as(u8, @truncate(self.r_info));
    }
};
pub const Elf64_Rel = extern struct {
    r_offset: Elf64_Addr,
    r_info: Elf64_Xword,

    pub inline fn r_sym(self: @This()) u32 {
        return @as(u32, @truncate(self.r_info >> 32));
    }
    pub inline fn r_type(self: @This()) u32 {
        return @as(u32, @truncate(self.r_info));
    }
};
pub const Elf32_Rela = extern struct {
    r_offset: Elf32_Addr,
    r_info: Elf32_Word,
    r_addend: Elf32_Sword,

    pub inline fn r_sym(self: @This()) u24 {
        return @as(u24, @truncate(self.r_info >> 8));
    }
    pub inline fn r_type(self: @This()) u8 {
        return @as(u8, @truncate(self.r_info));
    }
};
pub const Elf64_Rela = extern struct {
    r_offset: Elf64_Addr,
    r_info: Elf64_Xword,
    r_addend: Elf64_Sxword,

    pub inline fn r_sym(self: @This()) u32 {
        return @as(u32, @truncate(self.r_info >> 32));
    }
    pub inline fn r_type(self: @This()) u32 {
        return @as(u32, @truncate(self.r_info));
    }
};
pub const Elf32_Dyn = extern struct {
    d_tag: Elf32_Sword,
    d_val: Elf32_Addr,
};
pub const Elf64_Dyn = extern struct {
    d_tag: Elf64_Sxword,
    d_val: Elf64_Addr,
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
    section: Elf32_Section,
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
pub const Addr = switch (@sizeOf(usize)) {
    4 => Elf32_Addr,
    8 => Elf64_Addr,
    else => @compileError("expected pointer size of 32 or 64"),
};
pub const Half = switch (@sizeOf(usize)) {
    4 => Elf32_Half,
    8 => Elf64_Half,
    else => @compileError("expected pointer size of 32 or 64"),
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

    /// SPARC
    SPARC = 2,

    /// Intel 386
    @"386" = 3,

    /// Motorola 68000
    @"68K" = 4,

    /// Motorola 88000
    @"88K" = 5,

    /// Intel MCU
    IAMCU = 6,

    /// Intel 80860
    @"860" = 7,

    /// MIPS R3000
    MIPS = 8,

    /// IBM System/370
    S370 = 9,

    /// MIPS RS3000 Little-endian
    MIPS_RS3_LE = 10,

    /// SPU Mark II
    SPU_2 = 13,

    /// Hewlett-Packard PA-RISC
    PARISC = 15,

    /// Fujitsu VPP500
    VPP500 = 17,

    /// Enhanced instruction set SPARC
    SPARC32PLUS = 18,

    /// Intel 80960
    @"960" = 19,

    /// PowerPC
    PPC = 20,

    /// PowerPC64
    PPC64 = 21,

    /// IBM System/390
    S390 = 22,

    /// IBM SPU/SPC
    SPU = 23,

    /// NEC V800
    V800 = 36,

    /// Fujitsu FR20
    FR20 = 37,

    /// TRW RH-32
    RH32 = 38,

    /// Motorola RCE
    RCE = 39,

    /// ARM
    ARM = 40,

    /// DEC Alpha
    ALPHA = 41,

    /// Hitachi SH
    SH = 42,

    /// SPARC V9
    SPARCV9 = 43,

    /// Siemens TriCore
    TRICORE = 44,

    /// Argonaut RISC Core
    ARC = 45,

    /// Hitachi H8/300
    H8_300 = 46,

    /// Hitachi H8/300H
    H8_300H = 47,

    /// Hitachi H8S
    H8S = 48,

    /// Hitachi H8/500
    H8_500 = 49,

    /// Intel IA-64 processor architecture
    IA_64 = 50,

    /// Stanford MIPS-X
    MIPS_X = 51,

    /// Motorola ColdFire
    COLDFIRE = 52,

    /// Motorola M68HC12
    @"68HC12" = 53,

    /// Fujitsu MMA Multimedia Accelerator
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

    /// Advanced Logic Corp. TinyJ embedded processor family
    TINYJ = 61,

    /// AMD x86-64 architecture
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

    /// STMicroelectronics ST19 8-bit microcontroller
    ST19 = 74,

    /// Digital VAX
    VAX = 75,

    /// Axis Communications 32-bit embedded processor
    CRIS = 76,

    /// Infineon Technologies 32-bit embedded processor
    JAVELIN = 77,

    /// Element 14 64-bit DSP Processor
    FIREPATH = 78,

    /// LSI Logic 16-bit DSP Processor
    ZSP = 79,

    /// Donald Knuth's educational 64-bit processor
    MMIX = 80,

    /// Harvard University machine-independent object files
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

    /// NEC v850
    V850 = 87,

    /// Mitsubishi M32R
    M32R = 88,

    /// Matsushita MN10300
    MN10300 = 89,

    /// Matsushita MN10200
    MN10200 = 90,

    /// picoJava
    PJ = 91,

    /// OpenRISC 32-bit embedded processor
    OPENRISC = 92,

    /// ARC International ARCompact processor (old spelling/synonym: EM_ARC_A5)
    ARC_COMPACT = 93,

    /// Tensilica Xtensa Architecture
    XTENSA = 94,

    /// Alphamosaic VideoCore processor
    VIDEOCORE = 95,

    /// Thompson Multimedia General Purpose Processor
    TMM_GPP = 96,

    /// National Semiconductor 32000 series
    NS32K = 97,

    /// Tenor Network TPC processor
    TPC = 98,

    /// Trebia SNP 1000 processor
    SNP1K = 99,

    /// STMicroelectronics (www.st.com) ST200
    ST200 = 100,

    /// Ubicom IP2xxx microcontroller family
    IP2K = 101,

    /// MAX Processor
    MAX = 102,

    /// National Semiconductor CompactRISC microprocessor
    CR = 103,

    /// Fujitsu F2MC16
    F2MC16 = 104,

    /// Texas Instruments embedded microcontroller msp430
    MSP430 = 105,

    /// Analog Devices Blackfin (DSP) processor
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

    /// National Semiconductor CompactRISC CRX
    CRX = 114,

    /// Motorola XGATE embedded processor
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

    /// Sunplus S+core7 RISC processor
    SCORE7 = 135,

    /// New Japan Radio (NJR) 24-bit DSP Processor
    DSP24 = 136,

    /// Broadcom VideoCore III processor
    VIDEOCORE3 = 137,

    /// RISC processor for Lattice FPGA architecture
    LATTICEMICO32 = 138,

    /// Seiko Epson C17 family
    SE_C17 = 139,

    /// The Texas Instruments TMS320C6000 DSP family
    TI_C6000 = 140,

    /// The Texas Instruments TMS320C2000 DSP family
    TI_C2000 = 141,

    /// The Texas Instruments TMS320C55x DSP family
    TI_C5500 = 142,

    /// STMicroelectronics 64bit VLIW Data Signal Processor
    MMDSP_PLUS = 160,

    /// Cypress M8C microprocessor
    CYPRESS_M8C = 161,

    /// Renesas R32C series microprocessors
    R32C = 162,

    /// NXP Semiconductors TriMedia architecture family
    TRIMEDIA = 163,

    /// Qualcomm Hexagon processor
    HEXAGON = 164,

    /// Intel 8051 and variants
    @"8051" = 165,

    /// STMicroelectronics STxP7x family of configurable and extensible RISC processors
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

    /// Imagination Technologies META processor architecture
    METAG = 174,

    /// MCST Elbrus general purpose hardware architecture
    MCST_ELBRUS = 175,

    /// Cyan Technology eCOG16 family
    ECOG16 = 176,

    /// National Semiconductor CompactRISC CR16 16-bit microprocessor
    CR16 = 177,

    /// Freescale Extended Time Processing Unit
    ETPU = 178,

    /// Infineon Technologies SLE9X core
    SLE9X = 179,

    /// Intel L10M
    L10M = 180,

    /// Intel K10M
    K10M = 181,

    /// ARM AArch64
    AARCH64 = 183,

    /// Atmel Corporation 32-bit microprocessor family
    AVR32 = 185,

    /// STMicroeletronics STM8 8-bit microcontroller
    STM8 = 186,

    /// Tilera TILE64 multicore architecture family
    TILE64 = 187,

    /// Tilera TILEPro multicore architecture family
    TILEPRO = 188,

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

    /// Renesas 78KOR family
    @"78KOR" = 199,

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

    /// Reserved by Intel
    INTEL205 = 205,

    /// Reserved by Intel
    INTEL206 = 206,

    /// Reserved by Intel
    INTEL207 = 207,

    /// Reserved by Intel
    INTEL208 = 208,

    /// Reserved by Intel
    INTEL209 = 209,

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

    /// iCelero CoolEngine
    COOL = 217,

    /// Nanoradio Optimized RISC
    NORC = 218,

    /// CSR Kalimba architecture family
    CSR_KALIMBA = 219,

    /// AMD GPU architecture
    AMDGPU = 224,

    /// RISC-V
    RISCV = 243,

    /// Lanai 32-bit processor
    LANAI = 244,

    /// Linux kernel bpf virtual machine
    BPF = 247,

    /// C-SKY
    CSKY = 252,

    /// Fujitsu FR-V
    FRV = 0x5441,

    _,

    pub fn toTargetCpuArch(em: EM) ?std.Target.Cpu.Arch {
        return switch (em) {
            .AVR => .avr,
            .MSP430 => .msp430,
            .ARC => .arc,
            .ARM => .arm,
            .HEXAGON => .hexagon,
            .@"68K" => .m68k,
            .MIPS => .mips,
            .MIPS_RS3_LE => .mipsel,
            .PPC => .powerpc,
            .SPARC => .sparc,
            .@"386" => .x86,
            .XCORE => .xcore,
            .CSR_KALIMBA => .kalimba,
            .LANAI => .lanai,
            .AARCH64 => .aarch64,
            .PPC64 => .powerpc64,
            .RISCV => .riscv64,
            .X86_64 => .x86_64,
            .BPF => .bpfel,
            .SPARCV9 => .sparc64,
            .S390 => .s390x,
            .SPU_2 => .spu_2,
            // there's many cases we don't (yet) handle, or will never have a
            // zig target cpu arch equivalent (such as null).
            else => null,
        };
    }
};

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
/// No reloc
pub const R_X86_64_NONE = 0;
/// Direct 64 bit
pub const R_X86_64_64 = 1;
/// PC relative 32 bit signed
pub const R_X86_64_PC32 = 2;
/// 32 bit GOT entry
pub const R_X86_64_GOT32 = 3;
/// 32 bit PLT address
pub const R_X86_64_PLT32 = 4;
/// Copy symbol at runtime
pub const R_X86_64_COPY = 5;
/// Create GOT entry
pub const R_X86_64_GLOB_DAT = 6;
/// Create PLT entry
pub const R_X86_64_JUMP_SLOT = 7;
/// Adjust by program base
pub const R_X86_64_RELATIVE = 8;
/// 32 bit signed PC relative offset to GOT
pub const R_X86_64_GOTPCREL = 9;
/// Direct 32 bit zero extended
pub const R_X86_64_32 = 10;
/// Direct 32 bit sign extended
pub const R_X86_64_32S = 11;
/// Direct 16 bit zero extended
pub const R_X86_64_16 = 12;
/// 16 bit sign extended pc relative
pub const R_X86_64_PC16 = 13;
/// Direct 8 bit sign extended
pub const R_X86_64_8 = 14;
/// 8 bit sign extended pc relative
pub const R_X86_64_PC8 = 15;
/// ID of module containing symbol
pub const R_X86_64_DTPMOD64 = 16;
/// Offset in module's TLS block
pub const R_X86_64_DTPOFF64 = 17;
/// Offset in initial TLS block
pub const R_X86_64_TPOFF64 = 18;
/// 32 bit signed PC relative offset to two GOT entries for GD symbol
pub const R_X86_64_TLSGD = 19;
/// 32 bit signed PC relative offset to two GOT entries for LD symbol
pub const R_X86_64_TLSLD = 20;
/// Offset in TLS block
pub const R_X86_64_DTPOFF32 = 21;
/// 32 bit signed PC relative offset to GOT entry for IE symbol
pub const R_X86_64_GOTTPOFF = 22;
/// Offset in initial TLS block
pub const R_X86_64_TPOFF32 = 23;
/// PC relative 64 bit
pub const R_X86_64_PC64 = 24;
/// 64 bit offset to GOT
pub const R_X86_64_GOTOFF64 = 25;
/// 32 bit signed pc relative offset to GOT
pub const R_X86_64_GOTPC32 = 26;
/// 64 bit GOT entry offset
pub const R_X86_64_GOT64 = 27;
/// 64 bit PC relative offset to GOT entry
pub const R_X86_64_GOTPCREL64 = 28;
/// 64 bit PC relative offset to GOT
pub const R_X86_64_GOTPC64 = 29;
/// Like GOT64, says PLT entry needed
pub const R_X86_64_GOTPLT64 = 30;
/// 64-bit GOT relative offset to PLT entry
pub const R_X86_64_PLTOFF64 = 31;
/// Size of symbol plus 32-bit addend
pub const R_X86_64_SIZE32 = 32;
/// Size of symbol plus 64-bit addend
pub const R_X86_64_SIZE64 = 33;
/// GOT offset for TLS descriptor
pub const R_X86_64_GOTPC32_TLSDESC = 34;
/// Marker for call through TLS descriptor
pub const R_X86_64_TLSDESC_CALL = 35;
/// TLS descriptor
pub const R_X86_64_TLSDESC = 36;
/// Adjust indirectly by program base
pub const R_X86_64_IRELATIVE = 37;
/// 64-bit adjust by program base
pub const R_X86_64_RELATIVE64 = 38;
/// 39 Reserved was R_X86_64_PC32_BND
/// 40 Reserved was R_X86_64_PLT32_BND
/// Load from 32 bit signed pc relative offset to GOT entry without REX prefix, relaxable
pub const R_X86_64_GOTPCRELX = 41;
/// Load from 32 bit signed PC relative offset to GOT entry with REX prefix, relaxable
pub const R_X86_64_REX_GOTPCRELX = 42;
pub const R_X86_64_NUM = 43;

pub const STV = enum(u2) {
    DEFAULT = 0,
    INTERNAL = 1,
    HIDDEN = 2,
    PROTECTED = 3,
};
