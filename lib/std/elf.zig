const std = @import("std.zig");
const builtin = std.builtin;
const io = std.io;
const os = std.os;
const math = std.math;
const mem = std.mem;
const debug = std.debug;
const File = std.fs.File;

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

/// File types
pub const ET = extern enum(u16) {
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
const Header = struct {
    endian: builtin.Endian,
    is_64: bool,
    entry: u64,
    phoff: u64,
    shoff: u64,
    phentsize: u16,
    phnum: u16,
    shentsize: u16,
    shnum: u16,
    shstrndx: u16,
};

pub fn readHeader(file: File) !Header {
    var hdr_buf: [@sizeOf(Elf64_Ehdr)]u8 align(@alignOf(Elf64_Ehdr)) = undefined;
    try preadNoEof(file, &hdr_buf, 0);
    const hdr32 = @ptrCast(*Elf32_Ehdr, &hdr_buf);
    const hdr64 = @ptrCast(*Elf64_Ehdr, &hdr_buf);
    if (!mem.eql(u8, hdr32.e_ident[0..4], "\x7fELF")) return error.InvalidElfMagic;
    if (hdr32.e_ident[EI_VERSION] != 1) return error.InvalidElfVersion;

    const endian: std.builtin.Endian = switch (hdr32.e_ident[EI_DATA]) {
        ELFDATA2LSB => .Little,
        ELFDATA2MSB => .Big,
        else => return error.InvalidElfEndian,
    };
    const need_bswap = endian != std.builtin.endian;

    const is_64 = switch (hdr32.e_ident[EI_CLASS]) {
        ELFCLASS32 => false,
        ELFCLASS64 => true,
        else => return error.InvalidElfClass,
    };

    return @as(Header, .{
        .endian = endian,
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

/// All integers are native endian.
pub const AllHeaders = struct {
    header: Header,
    section_headers: []Elf64_Shdr,
    program_headers: []Elf64_Phdr,
    allocator: *mem.Allocator,
};

pub fn readAllHeaders(allocator: *mem.Allocator, file: File) !AllHeaders {
    var hdrs: AllHeaders = .{
        .allocator = allocator,
        .header = try readHeader(file),
        .section_headers = undefined,
        .program_headers = undefined,
    };
    const is_64 = hdrs.header.is_64;
    const need_bswap = hdrs.header.endian != std.builtin.endian;

    hdrs.section_headers = try allocator.alloc(Elf64_Shdr, hdrs.header.shnum);
    errdefer allocator.free(hdrs.section_headers);

    hdrs.program_headers = try allocator.alloc(Elf64_Phdr, hdrs.header.phnum);
    errdefer allocator.free(hdrs.program_headers);

    // If the ELF file is 64-bit and same-endianness, then all we have to do is
    // yeet the bytes into memory.
    // If only the endianness is different, they can be simply byte swapped.
    if (is_64) {
        const shdr_buf = std.mem.sliceAsBytes(hdrs.section_headers);
        const phdr_buf = std.mem.sliceAsBytes(hdrs.program_headers);
        try preadNoEof(file, shdr_buf, hdrs.header.shoff);
        try preadNoEof(file, phdr_buf, hdrs.header.phoff);

        if (need_bswap) {
            for (hdrs.section_headers) |*shdr| {
                shdr.* = .{
                    .sh_name = @byteSwap(@TypeOf(shdr.sh_name), shdr.sh_name),
                    .sh_type = @byteSwap(@TypeOf(shdr.sh_type), shdr.sh_type),
                    .sh_flags = @byteSwap(@TypeOf(shdr.sh_flags), shdr.sh_flags),
                    .sh_addr = @byteSwap(@TypeOf(shdr.sh_addr), shdr.sh_addr),
                    .sh_offset = @byteSwap(@TypeOf(shdr.sh_offset), shdr.sh_offset),
                    .sh_size = @byteSwap(@TypeOf(shdr.sh_size), shdr.sh_size),
                    .sh_link = @byteSwap(@TypeOf(shdr.sh_link), shdr.sh_link),
                    .sh_info = @byteSwap(@TypeOf(shdr.sh_info), shdr.sh_info),
                    .sh_addralign = @byteSwap(@TypeOf(shdr.sh_addralign), shdr.sh_addralign),
                    .sh_entsize = @byteSwap(@TypeOf(shdr.sh_entsize), shdr.sh_entsize),
                };
            }
            for (hdrs.program_headers) |*phdr| {
                phdr.* = .{
                    .p_type = @byteSwap(@TypeOf(phdr.p_type), phdr.p_type),
                    .p_offset = @byteSwap(@TypeOf(phdr.p_offset), phdr.p_offset),
                    .p_vaddr = @byteSwap(@TypeOf(phdr.p_vaddr), phdr.p_vaddr),
                    .p_paddr = @byteSwap(@TypeOf(phdr.p_paddr), phdr.p_paddr),
                    .p_filesz = @byteSwap(@TypeOf(phdr.p_filesz), phdr.p_filesz),
                    .p_memsz = @byteSwap(@TypeOf(phdr.p_memsz), phdr.p_memsz),
                    .p_flags = @byteSwap(@TypeOf(phdr.p_flags), phdr.p_flags),
                    .p_align = @byteSwap(@TypeOf(phdr.p_align), phdr.p_align),
                };
            }
        }

        return hdrs;
    }

    const shdrs_32 = try allocator.alloc(Elf32_Shdr, hdrs.header.shnum);
    defer allocator.free(shdrs_32);

    const phdrs_32 = try allocator.alloc(Elf32_Phdr, hdrs.header.phnum);
    defer allocator.free(phdrs_32);

    const shdr_buf = std.mem.sliceAsBytes(shdrs_32);
    const phdr_buf = std.mem.sliceAsBytes(phdrs_32);
    try preadNoEof(file, shdr_buf, hdrs.header.shoff);
    try preadNoEof(file, phdr_buf, hdrs.header.phoff);

    if (need_bswap) {
        for (hdrs.section_headers) |*shdr, i| {
            const o = shdrs_32[i];
            shdr.* = .{
                .sh_name = @byteSwap(@TypeOf(o.sh_name), o.sh_name),
                .sh_type = @byteSwap(@TypeOf(o.sh_type), o.sh_type),
                .sh_flags = @byteSwap(@TypeOf(o.sh_flags), o.sh_flags),
                .sh_addr = @byteSwap(@TypeOf(o.sh_addr), o.sh_addr),
                .sh_offset = @byteSwap(@TypeOf(o.sh_offset), o.sh_offset),
                .sh_size = @byteSwap(@TypeOf(o.sh_size), o.sh_size),
                .sh_link = @byteSwap(@TypeOf(o.sh_link), o.sh_link),
                .sh_info = @byteSwap(@TypeOf(o.sh_info), o.sh_info),
                .sh_addralign = @byteSwap(@TypeOf(o.sh_addralign), o.sh_addralign),
                .sh_entsize = @byteSwap(@TypeOf(o.sh_entsize), o.sh_entsize),
            };
        }
        for (hdrs.program_headers) |*phdr, i| {
            const o = phdrs_32[i];
            phdr.* = .{
                .p_type = @byteSwap(@TypeOf(o.p_type), o.p_type),
                .p_offset = @byteSwap(@TypeOf(o.p_offset), o.p_offset),
                .p_vaddr = @byteSwap(@TypeOf(o.p_vaddr), o.p_vaddr),
                .p_paddr = @byteSwap(@TypeOf(o.p_paddr), o.p_paddr),
                .p_filesz = @byteSwap(@TypeOf(o.p_filesz), o.p_filesz),
                .p_memsz = @byteSwap(@TypeOf(o.p_memsz), o.p_memsz),
                .p_flags = @byteSwap(@TypeOf(o.p_flags), o.p_flags),
                .p_align = @byteSwap(@TypeOf(o.p_align), o.p_align),
            };
        }
    } else {
        for (hdrs.section_headers) |*shdr, i| {
            const o = shdrs_32[i];
            shdr.* = .{
                .sh_name = o.sh_name,
                .sh_type = o.sh_type,
                .sh_flags = o.sh_flags,
                .sh_addr = o.sh_addr,
                .sh_offset = o.sh_offset,
                .sh_size = o.sh_size,
                .sh_link = o.sh_link,
                .sh_info = o.sh_info,
                .sh_addralign = o.sh_addralign,
                .sh_entsize = o.sh_entsize,
            };
        }
        for (hdrs.program_headers) |*phdr, i| {
            const o = phdrs_32[i];
            phdr.* = .{
                .p_type = o.p_type,
                .p_offset = o.p_offset,
                .p_vaddr = o.p_vaddr,
                .p_paddr = o.p_paddr,
                .p_filesz = o.p_filesz,
                .p_memsz = o.p_memsz,
                .p_flags = o.p_flags,
                .p_align = o.p_align,
            };
        }
    }

    return hdrs;
}

pub fn int(is_64: bool, need_bswap: bool, int_32: anytype, int_64: anytype) @TypeOf(int_64) {
    if (is_64) {
        if (need_bswap) {
            return @byteSwap(@TypeOf(int_64), int_64);
        } else {
            return int_64;
        }
    } else {
        return int32(need_bswap, int_32, @TypeOf(int_64));
    }
}

pub fn int32(need_bswap: bool, int_32: anytype, comptime Int64: anytype) Int64 {
    if (need_bswap) {
        return @byteSwap(@TypeOf(int_32), int_32);
    } else {
        return int_32;
    }
}

fn preadNoEof(file: std.fs.File, buf: []u8, offset: u64) !void {
    var i: u64 = 0;
    while (i < buf.len) {
        const len = file.pread(buf[i .. buf.len - i], offset + i) catch |err| switch (err) {
            error.SystemResources => return error.SystemResources,
            error.IsDir => return error.UnableToReadElfFile,
            error.OperationAborted => return error.UnableToReadElfFile,
            error.BrokenPipe => return error.UnableToReadElfFile,
            error.Unseekable => return error.UnableToReadElfFile,
            error.ConnectionResetByPeer => return error.UnableToReadElfFile,
            error.ConnectionTimedOut => return error.UnableToReadElfFile,
            error.InputOutput => return error.FileSystem,
            error.Unexpected => return error.Unexpected,
            error.WouldBlock => return error.Unexpected,
            error.AccessDenied => return error.Unexpected,
        };
        if (len == 0) return error.UnexpectedEndOfFile;
        i += len;
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

comptime {
    debug.assert(@sizeOf(Elf32_Ehdr) == 52);
    debug.assert(@sizeOf(Elf64_Ehdr) == 64);

    debug.assert(@sizeOf(Elf32_Phdr) == 32);
    debug.assert(@sizeOf(Elf64_Phdr) == 56);

    debug.assert(@sizeOf(Elf32_Shdr) == 40);
    debug.assert(@sizeOf(Elf64_Shdr) == 64);
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
pub const Shdr = switch (@sizeOf(usize)) {
    4 => Elf32_Shdr,
    8 => Elf64_Shdr,
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

/// Machine architectures
/// See current registered ELF machine architectures at:
///    http://www.uxsglobal.com/developers/gabi/latest/ch4.eheader.html
/// The underscore prefix is because many of these start with numbers.
pub const EM = extern enum(u16) {
    /// No machine
    _NONE = 0,

    /// AT&T WE 32100
    _M32 = 1,

    /// SPARC
    _SPARC = 2,

    /// Intel 386
    _386 = 3,

    /// Motorola 68000
    _68K = 4,

    /// Motorola 88000
    _88K = 5,

    /// Intel MCU
    _IAMCU = 6,

    /// Intel 80860
    _860 = 7,

    /// MIPS R3000
    _MIPS = 8,

    /// IBM System/370
    _S370 = 9,

    /// MIPS RS3000 Little-endian
    _MIPS_RS3_LE = 10,

    /// Hewlett-Packard PA-RISC
    _PARISC = 15,

    /// Fujitsu VPP500
    _VPP500 = 17,

    /// Enhanced instruction set SPARC
    _SPARC32PLUS = 18,

    /// Intel 80960
    _960 = 19,

    /// PowerPC
    _PPC = 20,

    /// PowerPC64
    _PPC64 = 21,

    /// IBM System/390
    _S390 = 22,

    /// IBM SPU/SPC
    _SPU = 23,

    /// NEC V800
    _V800 = 36,

    /// Fujitsu FR20
    _FR20 = 37,

    /// TRW RH-32
    _RH32 = 38,

    /// Motorola RCE
    _RCE = 39,

    /// ARM
    _ARM = 40,

    /// DEC Alpha
    _ALPHA = 41,

    /// Hitachi SH
    _SH = 42,

    /// SPARC V9
    _SPARCV9 = 43,

    /// Siemens TriCore
    _TRICORE = 44,

    /// Argonaut RISC Core
    _ARC = 45,

    /// Hitachi H8/300
    _H8_300 = 46,

    /// Hitachi H8/300H
    _H8_300H = 47,

    /// Hitachi H8S
    _H8S = 48,

    /// Hitachi H8/500
    _H8_500 = 49,

    /// Intel IA-64 processor architecture
    _IA_64 = 50,

    /// Stanford MIPS-X
    _MIPS_X = 51,

    /// Motorola ColdFire
    _COLDFIRE = 52,

    /// Motorola M68HC12
    _68HC12 = 53,

    /// Fujitsu MMA Multimedia Accelerator
    _MMA = 54,

    /// Siemens PCP
    _PCP = 55,

    /// Sony nCPU embedded RISC processor
    _NCPU = 56,

    /// Denso NDR1 microprocessor
    _NDR1 = 57,

    /// Motorola Star*Core processor
    _STARCORE = 58,

    /// Toyota ME16 processor
    _ME16 = 59,

    /// STMicroelectronics ST100 processor
    _ST100 = 60,

    /// Advanced Logic Corp. TinyJ embedded processor family
    _TINYJ = 61,

    /// AMD x86-64 architecture
    _X86_64 = 62,

    /// Sony DSP Processor
    _PDSP = 63,

    /// Digital Equipment Corp. PDP-10
    _PDP10 = 64,

    /// Digital Equipment Corp. PDP-11
    _PDP11 = 65,

    /// Siemens FX66 microcontroller
    _FX66 = 66,

    /// STMicroelectronics ST9+ 8/16 bit microcontroller
    _ST9PLUS = 67,

    /// STMicroelectronics ST7 8-bit microcontroller
    _ST7 = 68,

    /// Motorola MC68HC16 Microcontroller
    _68HC16 = 69,

    /// Motorola MC68HC11 Microcontroller
    _68HC11 = 70,

    /// Motorola MC68HC08 Microcontroller
    _68HC08 = 71,

    /// Motorola MC68HC05 Microcontroller
    _68HC05 = 72,

    /// Silicon Graphics SVx
    _SVX = 73,

    /// STMicroelectronics ST19 8-bit microcontroller
    _ST19 = 74,

    /// Digital VAX
    _VAX = 75,

    /// Axis Communications 32-bit embedded processor
    _CRIS = 76,

    /// Infineon Technologies 32-bit embedded processor
    _JAVELIN = 77,

    /// Element 14 64-bit DSP Processor
    _FIREPATH = 78,

    /// LSI Logic 16-bit DSP Processor
    _ZSP = 79,

    /// Donald Knuth's educational 64-bit processor
    _MMIX = 80,

    /// Harvard University machine-independent object files
    _HUANY = 81,

    /// SiTera Prism
    _PRISM = 82,

    /// Atmel AVR 8-bit microcontroller
    _AVR = 83,

    /// Fujitsu FR30
    _FR30 = 84,

    /// Mitsubishi D10V
    _D10V = 85,

    /// Mitsubishi D30V
    _D30V = 86,

    /// NEC v850
    _V850 = 87,

    /// Mitsubishi M32R
    _M32R = 88,

    /// Matsushita MN10300
    _MN10300 = 89,

    /// Matsushita MN10200
    _MN10200 = 90,

    /// picoJava
    _PJ = 91,

    /// OpenRISC 32-bit embedded processor
    _OPENRISC = 92,

    /// ARC International ARCompact processor (old spelling/synonym: EM_ARC_A5)
    _ARC_COMPACT = 93,

    /// Tensilica Xtensa Architecture
    _XTENSA = 94,

    /// Alphamosaic VideoCore processor
    _VIDEOCORE = 95,

    /// Thompson Multimedia General Purpose Processor
    _TMM_GPP = 96,

    /// National Semiconductor 32000 series
    _NS32K = 97,

    /// Tenor Network TPC processor
    _TPC = 98,

    /// Trebia SNP 1000 processor
    _SNP1K = 99,

    /// STMicroelectronics (www.st.com) ST200
    _ST200 = 100,

    /// Ubicom IP2xxx microcontroller family
    _IP2K = 101,

    /// MAX Processor
    _MAX = 102,

    /// National Semiconductor CompactRISC microprocessor
    _CR = 103,

    /// Fujitsu F2MC16
    _F2MC16 = 104,

    /// Texas Instruments embedded microcontroller msp430
    _MSP430 = 105,

    /// Analog Devices Blackfin (DSP) processor
    _BLACKFIN = 106,

    /// S1C33 Family of Seiko Epson processors
    _SE_C33 = 107,

    /// Sharp embedded microprocessor
    _SEP = 108,

    /// Arca RISC Microprocessor
    _ARCA = 109,

    /// Microprocessor series from PKU-Unity Ltd. and MPRC of Peking University
    _UNICORE = 110,

    /// eXcess: 16/32/64-bit configurable embedded CPU
    _EXCESS = 111,

    /// Icera Semiconductor Inc. Deep Execution Processor
    _DXP = 112,

    /// Altera Nios II soft-core processor
    _ALTERA_NIOS2 = 113,

    /// National Semiconductor CompactRISC CRX
    _CRX = 114,

    /// Motorola XGATE embedded processor
    _XGATE = 115,

    /// Infineon C16x/XC16x processor
    _C166 = 116,

    /// Renesas M16C series microprocessors
    _M16C = 117,

    /// Microchip Technology dsPIC30F Digital Signal Controller
    _DSPIC30F = 118,

    /// Freescale Communication Engine RISC core
    _CE = 119,

    /// Renesas M32C series microprocessors
    _M32C = 120,

    /// Altium TSK3000 core
    _TSK3000 = 131,

    /// Freescale RS08 embedded processor
    _RS08 = 132,

    /// Analog Devices SHARC family of 32-bit DSP processors
    _SHARC = 133,

    /// Cyan Technology eCOG2 microprocessor
    _ECOG2 = 134,

    /// Sunplus S+core7 RISC processor
    _SCORE7 = 135,

    /// New Japan Radio (NJR) 24-bit DSP Processor
    _DSP24 = 136,

    /// Broadcom VideoCore III processor
    _VIDEOCORE3 = 137,

    /// RISC processor for Lattice FPGA architecture
    _LATTICEMICO32 = 138,

    /// Seiko Epson C17 family
    _SE_C17 = 139,

    /// The Texas Instruments TMS320C6000 DSP family
    _TI_C6000 = 140,

    /// The Texas Instruments TMS320C2000 DSP family
    _TI_C2000 = 141,

    /// The Texas Instruments TMS320C55x DSP family
    _TI_C5500 = 142,

    /// STMicroelectronics 64bit VLIW Data Signal Processor
    _MMDSP_PLUS = 160,

    /// Cypress M8C microprocessor
    _CYPRESS_M8C = 161,

    /// Renesas R32C series microprocessors
    _R32C = 162,

    /// NXP Semiconductors TriMedia architecture family
    _TRIMEDIA = 163,

    /// Qualcomm Hexagon processor
    _HEXAGON = 164,

    /// Intel 8051 and variants
    _8051 = 165,

    /// STMicroelectronics STxP7x family of configurable and extensible RISC processors
    _STXP7X = 166,

    /// Andes Technology compact code size embedded RISC processor family
    _NDS32 = 167,

    /// Cyan Technology eCOG1X family
    _ECOG1X = 168,

    /// Dallas Semiconductor MAXQ30 Core Micro-controllers
    _MAXQ30 = 169,

    /// New Japan Radio (NJR) 16-bit DSP Processor
    _XIMO16 = 170,

    /// M2000 Reconfigurable RISC Microprocessor
    _MANIK = 171,

    /// Cray Inc. NV2 vector architecture
    _CRAYNV2 = 172,

    /// Renesas RX family
    _RX = 173,

    /// Imagination Technologies META processor architecture
    _METAG = 174,

    /// MCST Elbrus general purpose hardware architecture
    _MCST_ELBRUS = 175,

    /// Cyan Technology eCOG16 family
    _ECOG16 = 176,

    /// National Semiconductor CompactRISC CR16 16-bit microprocessor
    _CR16 = 177,

    /// Freescale Extended Time Processing Unit
    _ETPU = 178,

    /// Infineon Technologies SLE9X core
    _SLE9X = 179,

    /// Intel L10M
    _L10M = 180,

    /// Intel K10M
    _K10M = 181,

    /// ARM AArch64
    _AARCH64 = 183,

    /// Atmel Corporation 32-bit microprocessor family
    _AVR32 = 185,

    /// STMicroeletronics STM8 8-bit microcontroller
    _STM8 = 186,

    /// Tilera TILE64 multicore architecture family
    _TILE64 = 187,

    /// Tilera TILEPro multicore architecture family
    _TILEPRO = 188,

    /// NVIDIA CUDA architecture
    _CUDA = 190,

    /// Tilera TILE-Gx multicore architecture family
    _TILEGX = 191,

    /// CloudShield architecture family
    _CLOUDSHIELD = 192,

    /// KIPO-KAIST Core-A 1st generation processor family
    _COREA_1ST = 193,

    /// KIPO-KAIST Core-A 2nd generation processor family
    _COREA_2ND = 194,

    /// Synopsys ARCompact V2
    _ARC_COMPACT2 = 195,

    /// Open8 8-bit RISC soft processor core
    _OPEN8 = 196,

    /// Renesas RL78 family
    _RL78 = 197,

    /// Broadcom VideoCore V processor
    _VIDEOCORE5 = 198,

    /// Renesas 78KOR family
    _78KOR = 199,

    /// Freescale 56800EX Digital Signal Controller (DSC)
    _56800EX = 200,

    /// Beyond BA1 CPU architecture
    _BA1 = 201,

    /// Beyond BA2 CPU architecture
    _BA2 = 202,

    /// XMOS xCORE processor family
    _XCORE = 203,

    /// Microchip 8-bit PIC(r) family
    _MCHP_PIC = 204,

    /// Reserved by Intel
    _INTEL205 = 205,

    /// Reserved by Intel
    _INTEL206 = 206,

    /// Reserved by Intel
    _INTEL207 = 207,

    /// Reserved by Intel
    _INTEL208 = 208,

    /// Reserved by Intel
    _INTEL209 = 209,

    /// KM211 KM32 32-bit processor
    _KM32 = 210,

    /// KM211 KMX32 32-bit processor
    _KMX32 = 211,

    /// KM211 KMX16 16-bit processor
    _KMX16 = 212,

    /// KM211 KMX8 8-bit processor
    _KMX8 = 213,

    /// KM211 KVARC processor
    _KVARC = 214,

    /// Paneve CDP architecture family
    _CDP = 215,

    /// Cognitive Smart Memory Processor
    _COGE = 216,

    /// iCelero CoolEngine
    _COOL = 217,

    /// Nanoradio Optimized RISC
    _NORC = 218,

    /// CSR Kalimba architecture family
    _CSR_KALIMBA = 219,

    /// AMD GPU architecture
    _AMDGPU = 224,

    /// RISC-V
    _RISCV = 243,

    /// Lanai 32-bit processor
    _LANAI = 244,

    /// Linux kernel bpf virtual machine
    _BPF = 247,
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
