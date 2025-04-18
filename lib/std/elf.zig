//! Executable and Linkable Format.

const std = @import("std.zig");
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;
const native_endian = @import("builtin").target.cpu.arch.endian();
const Endian = std.builtin.Endian;

pub const MAGIC = "\x7fELF";

pub const DF = packed struct(u5) {
    origin: bool = false,
    symbolic: bool = false,
    textrel: bool = false,
    bind_now: bool = false,
    static_tls: bool = false,
};

pub const DF1 = packed struct(u28) {
    now: bool = false,
    global: bool = false,
    group: bool = false,
    nodelete: bool = false,
    loadfltr: bool = false,
    initfirst: bool = false,
    noopen: bool = false,
    origin: bool = false,
    direct: bool = false,
    trans: bool = false,
    interpose: bool = false,
    nodeflib: bool = false,
    nodump: bool = false,
    confalt: bool = false,
    endfiltee: bool = false,
    dispreldne: bool = false,
    disprelpnd: bool = false,
    nodirect: bool = false,
    ignmuldef: bool = false,
    noksyms: bool = false,
    nohdr: bool = false,
    edited: bool = false,
    symintpose: bool = false,
    globaudit: bool = false,
    singleton: bool = false,
    stub: bool = false,
    pie: bool = false,
};

pub const Versym = packed struct(u16) {
    version: u15,
    hidden: bool,

    pub const local: Versym = .fromIndex(.local);
    pub const global: Versym = .fromIndex(.global);

    pub fn fromIndex(index: VersionIndex) Versym {
        const idx = @intFromEnum(index);
        return @bitCast(idx);
    }

    pub fn toIndex(symbol: Versym) VersionIndex {
        const sym: u16 = @bitCast(symbol);
        return @enumFromInt(sym);
    }
};

pub const VersionIndex = enum(u16) {
    const Reserve = EnumRange(VersionIndex, .loreserve, .hireserve);
    pub const ReserveRange = Reserve.Range;
    pub const reserve = Reserve.fromInt;
    pub const getReserve = Reserve.toInt;

    /// Symbol is local
    local = 0,
    /// Symbol is global
    global = 1,
    loreserve = 0xff00,
    hireserve = 0xffff,
    _,

    /// Symbol is to be eliminated
    pub const eliminate = reserve(0x01);
};

/// Version definition of the file itself
pub const VER_FLG_BASE = 1;
/// Weak version identifier
pub const VER_FLG_WEAK = 2;

pub const PT = enum(Word) {
    const Os = EnumRange(PT, .LOOS, .HIOS);
    pub const OsRange = Os.Range;
    pub const os = Os.fromInt;
    pub const getOs = Os.toInt;

    const Proc = EnumRange(PT, .LOPROC, .HIPROC);
    pub const ProcRange = Proc.Range;
    pub const proc = Proc.fromInt;
    pub const getProc = Proc.toInt;

    /// Program header table entry unused
    NULL = 0,
    /// Loadable program segment
    LOAD = 1,
    /// Dynamic linking information
    DYNAMIC = 2,
    /// Program interpreter
    INTERP = 3,
    /// Auxiliary information
    NOTE = 4,
    /// Reserved
    SHLIB = 5,
    /// Entry for header table itself
    PHDR = 6,
    /// Thread-local storage segment
    TLS = 7,
    /// Start of OS-specific
    LOOS = 0x60000000,
    /// End of OS-specific
    HIOS = 0x6fffffff,
    /// Start of processor-specific
    LOPROC = 0x70000000,
    /// End of processor-specific
    HIPROC = 0x7fffffff,
    _,

    /// GCC .eh_frame_hdr segment
    pub const GNU_EH_FRAME = os(0x474e550);
    /// Indicates stack executability
    pub const GNU_STACK = os(0x474e551);
    /// Read-only after relocation
    pub const GNU_RELRO = os(0x474e552);
    pub const LOSUNW = os(0xffffffa);
    /// Sun specific segment
    pub const SUNWBSS = os(0xffffffa);
    /// Stack segment
    pub const SUNWSTACK = os(0xffffffb);
    pub const HISUNW = os(0xfffffff);

    pub fn format(
        p_type: PT,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const name = switch (p_type) {
            .NULL, .LOAD, .DYNAMIC, .INTERP, .NOTE, .SHLIB, .PHDR, .TLS => @tagName(p_type),

            GNU_EH_FRAME => "GNU_EH_FRAME",
            GNU_STACK => "GNU_STACK",
            GNU_RELRO => "GNU_RELRO",
            SUNWBSS => "SUNWBSS",
            SUNWSTACK => "SUNWSTACK",

            else => name: {
                if (p_type.getOs()) |osval|
                    try writer.print("OS(0x{X})", .{osval})
                else if (p_type.getProc()) |procval|
                    try writer.print("PROC(0x{X})", .{procval})
                else
                    break :name "UNKNOWN";
                return;
            },
        };

        try writer.writeAll(name);
    }
};

pub const SHT = enum(Word) {
    const Os = EnumRange(SHT, .LOOS, .HIOS);
    pub const OsRange = Os.Range;
    pub const os = Os.fromInt;
    pub const getOs = Os.toInt;

    const Proc = EnumRange(SHT, .LOPROC, .HIPROC);
    pub const ProcRange = Proc.Range;
    pub const proc = Proc.fromInt;
    pub const getProc = Proc.toInt;

    const User = EnumRange(SHT, .LOUSER, .HIUSER);
    pub const UserRange = User.Range;
    pub const user = User.fromInt;
    pub const getUser = User.toInt;

    /// Section header table entry unused
    NULL = 0,
    /// Program data
    PROGBITS = 1,
    /// Symbol table
    SYMTAB = 2,
    /// String table
    STRTAB = 3,
    /// Relocation entries with addends
    RELA = 4,
    /// Symbol hash table
    HASH = 5,
    /// Dynamic linking information
    DYNAMIC = 6,
    /// Notes
    NOTE = 7,
    /// Program space with no data (bss)
    NOBITS = 8,
    /// Relocation entries, no addends
    REL = 9,
    /// Reserved
    SHLIB = 10,
    /// Dynamic linker symbol table
    DYNSYM = 11,
    /// Array of constructors
    INIT_ARRAY = 14,
    /// Array of destructors
    FINI_ARRAY = 15,
    /// Array of pre-constructors
    PREINIT_ARRAY = 16,
    /// Section group
    GROUP = 17,
    /// Extended section indices
    SYMTAB_SHNDX = 18,
    /// Start of OS-specific
    LOOS = 0x60000000,
    /// End of OS-specific
    HIOS = 0x6fffffff,
    /// Start of processor-specific
    LOPROC = 0x70000000,
    /// End of processor-specific
    HIPROC = 0x7fffffff,
    /// Start of application-specific
    LOUSER = 0x80000000,
    /// End of application-specific
    HIUSER = 0xffffffff,
    _,

    /// LLVM address-significance table
    pub const LLVM_ADDRSIG = os(0xfff4c03);
    /// GNU hash table
    pub const GNU_HASH = os(0xffffff6);
    /// GNU version definition table
    pub const GNU_VERDEF = os(0xffffffd);
    /// GNU needed versions table
    pub const GNU_VERNEED = os(0xffffffe);
    /// GNU symbol version table
    pub const GNU_VERSYM = os(0xfffffff);
    /// Unwind information
    pub const X86_64_UNWIND = proc(0x1);

    pub fn format(
        sh_type: SHT,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const name = switch (sh_type) {
            .NULL,
            .PROGBITS,
            .SYMTAB,
            .STRTAB,
            .RELA,
            .HASH,
            .DYNAMIC,
            .NOTE,
            .NOBITS,
            .REL,
            .SHLIB,
            .DYNSYM,
            .INIT_ARRAY,
            .FINI_ARRAY,
            .PREINIT_ARRAY,
            .GROUP,
            .SYMTAB_SHNDX,
            => @tagName(sh_type),

            LLVM_ADDRSIG => "LLVM_ADDRSIG",
            GNU_HASH => "GNU_HASH",
            GNU_VERDEF => "GNU_VERDEF",
            GNU_VERNEED => "GNU_VERNEED",
            GNU_VERSYM => "GNU_VERSYM",
            X86_64_UNWIND => "X86_64_UNWIND",

            else => name: {
                if (sh_type.getOs()) |osval|
                    try writer.print("OS(0x{X})", .{osval})
                else if (sh_type.getProc()) |procval|
                    try writer.print("PROC(0x{X})", .{procval})
                else
                    break :name "UNKNOWN";
                return;
            },
        };

        try writer.writeAll(name);
    }
};

pub const NT = enum(u32) {
    _,

    pub fn of(value: u32) NT {
        return @enumFromInt(value);
    }

    // Note type for .note.gnu.build_id
    pub const GNU_BUILD_ID: NT = .of(3);
};

pub const STB = enum(u4) {
    const Os = EnumRange(STB, .LOOS, .HIOS);
    pub const OsRange = Os.Range;
    pub const os = Os.fromInt;
    pub const getOs = Os.toInt;

    const Proc = EnumRange(STB, .LOPROC, .HIPROC);
    pub const ProcRange = Proc.Range;
    pub const proc = Proc.fromInt;
    pub const getProc = Proc.toInt;

    /// Local symbol
    LOCAL = 0,
    /// Global symbol
    GLOBAL = 1,
    /// Weak symbol
    WEAK = 2,
    /// Start of OS-specific
    LOOS = 10,
    /// End of OS-specific
    HIOS = 12,
    /// Start of processor-specific
    LOPROC = 13,
    /// End of processor-specific
    HIPROC = 15,
    _,

    /// Unique symbol
    pub const GNU_UNIQUE = os(0);
    pub const MIPS_SPLIT_COMMON = proc(0);
};

pub const STT = enum(u4) {
    const Os = EnumRange(STT, .LOOS, .HIOS);
    pub const OsRange = Os.Range;
    pub const os = Os.fromInt;
    pub const getOs = Os.toInt;

    const Proc = EnumRange(STT, .LOPROC, .HIPROC);
    pub const ProcRange = Proc.Range;
    pub const proc = Proc.fromInt;
    pub const getProc = Proc.toInt;

    /// Symbol type is unspecified
    NOTYPE = 0,
    /// Symbol is a data object
    OBJECT = 1,
    /// Symbol is a code object
    FUNC = 2,
    /// Symbol associated with a section
    SECTION = 3,
    /// Symbol's name is file name
    FILE = 4,
    /// Symbol is a common data object
    COMMON = 5,
    /// Symbol is thread-local data object
    TLS = 6,
    /// Start of OS-specific
    LOOS = 10,
    /// End of OS-specific
    HIOS = 12,
    /// Start of processor-specific
    LOPROC = 13,
    /// End of processor-specific
    HIPROC = 15,
    _,

    /// Symbol is indirect code object
    pub const GNU_IFUNC = os(0x0);

    pub const SPARC_REGISTER = proc(0x0);

    pub const PARISC_MILLICODE = proc(0x0);

    pub const HP_OPAQUE = os(0x1);
    pub const HP_STUB = os(0x2);

    pub const ARM_TFUNC = proc(0x0);
    pub const ARM_16BIT = proc(0x2);

    pub fn format(
        st_type: STT,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const name = switch (st_type) {
            .NOTYPE,
            .OBJECT,
            .FUNC,
            .SECTION,
            .FILE,
            .COMMON,
            .TLS,
            => @tagName(st_type),

            GNU_IFUNC => "GNU_IFUNC",

            else => name: {
                if (st_type.getOs()) |osval|
                    try writer.print("OS({d})", .{osval})
                else if (st_type.getProc()) |procval|
                    try writer.print("PROC({d})", .{procval})
                else
                    break :name "UNKNOWN";
                return;
            },
        };

        try writer.writeAll(name);
    }
};

/// File types
pub const ET = enum(u16) {
    const Os = EnumRange(ET, .LOOS, .HIOS);
    pub const OsRange = Os.Range;
    pub const os = Os.fromInt;
    pub const getOs = Os.toInt;

    const Proc = EnumRange(ET, .LOOS, .HIOS);
    pub const ProcRange = Proc.Range;
    pub const proc = Proc.fromInt;
    pub const getProc = Proc.toInt;

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

    LOOS = 0xfe00,
    HIOS = 0xfeff,
    LOPROC = 0xff00,
    HIPROC = 0xffff,

    _,
};

/// All integers are native endian.
pub const Header = struct {
    is_64: bool,
    endian: Endian,
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

    pub fn programHeaders(
        self: *const Header,
        parse_source: anytype,
    ) ProgramHeaders(@TypeOf(parse_source)) {
        return .new(self, parse_source);
    }

    pub fn sectionHeaders(
        self: *const Header,
        parse_source: anytype,
    ) SectionHeaders(@TypeOf(parse_source)) {
        return .new(self, parse_source);
    }

    pub fn symbolTable(
        self: *const Header,
        symtab_header: *const elf64.Shdr,
        parse_source: anytype,
    ) SymbolTable(@TypeOf(parse_source)) {
        return .new(self, symtab_header, parse_source);
    }

    pub fn findSymbolTable(
        self: *const Header,
        parse_source: anytype,
    ) !?SymbolTable(@TypeOf(parse_source)) {
        var sheaders = self.sectionHeaders(parse_source).iterator();
        const symtab_header = while (try sheaders.next()) |shdr| {
            if (shdr.sh_type == .SYMTAB) break shdr;
        } else return null;
        return self.symbolTable(&symtab_header, parse_source);
    }

    pub fn stringTable(
        self: *const Header,
        strtab_header: *const elf64.Shdr,
        parse_source: anytype,
    ) StringTable(@TypeOf(parse_source)) {
        _ = self;
        return .new(strtab_header, parse_source);
    }

    pub fn sectionNames(
        self: *const Header,
        parse_source: anytype,
    ) !?StringTable(@TypeOf(parse_source)) {
        const sheaders = self.sectionHeaders(parse_source);
        const shstr_tab = try sheaders.get(self.shstrndx) orelse return null;
        return self.stringTable(&shstr_tab, parse_source);
    }

    pub fn read(parse_source: anytype) !Header {
        var hdr_buf: [@sizeOf(elf64.Ehdr)]u8 align(@alignOf(elf64.Ehdr)) = undefined;
        try parse_source.seekableStream().seekTo(0);
        try parse_source.reader().readNoEof(&hdr_buf);
        return Header.parse(&hdr_buf);
    }

    pub fn parse(hdr_buf: *align(@alignOf(elf64.Ehdr)) const [@sizeOf(elf64.Ehdr)]u8) !Header {
        const hdr32 = @as(*const elf32.Ehdr, @ptrCast(hdr_buf));
        const hdr64 = @as(*const elf64.Ehdr, @ptrCast(hdr_buf));
        if (!mem.eql(u8, hdr32.e_ident.magic(), MAGIC)) return error.InvalidElfMagic;
        if (hdr32.e_ident.ei_version != .CURRENT) return error.InvalidElfVersion;

        const is_64 = switch (hdr32.e_ident.ei_class) {
            .@"32" => false,
            .@"64" => true,
            else => return error.InvalidElfClass,
        };

        const endian: Endian = switch (hdr32.e_ident.ei_data) {
            .LSB => .little,
            .MSB => .big,
            else => return error.InvalidElfEndian,
        };
        const need_bswap = endian != native_endian;

        // Converting integers to exhaustive enums using `@enumFromInt` could cause a panic.
        comptime assert(!@typeInfo(OSABI).@"enum".is_exhaustive);
        const os_abi: OSABI = hdr32.e_ident.ei_osabi;

        // The meaning of this value depends on `os_abi` so just make it available as `u8`.
        const abi_version = hdr32.e_ident.ei_abiversion;

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

pub fn ProgramHeaders(ParseSource: type) type {
    return struct {
        const PHeaders = @This();

        len: u16,
        _parse_source: ParseSource,
        _phoff: u64,
        _is_64: bool,
        _endian: Endian,

        pub fn new(header: *const Header, parse_source: ParseSource) PHeaders {
            return .{
                .len = header.phnum,
                ._parse_source = parse_source,
                ._phoff = header.phoff,
                ._is_64 = header.is_64,
                ._endian = header.endian,
            };
        }

        pub fn get(self: *const PHeaders, index: u16) !?elf64.Phdr {
            if (index >= self.len) return null;

            if (self._is_64) {
                var phdr: elf64.Phdr = undefined;
                const offset = self._phoff + @sizeOf(@TypeOf(phdr)) * index;
                try self._parse_source.seekableStream().seekTo(offset);
                try self._parse_source.reader().readNoEof(mem.asBytes(&phdr));

                // ELF endianness matches native endianness.
                if (self._endian == native_endian) return phdr;

                // Convert fields to native endianness.
                mem.byteSwapAllFields(elf64.Phdr, &phdr);
                return phdr;
            }

            var phdr: elf32.Phdr = undefined;
            const offset = self._phoff + @sizeOf(@TypeOf(phdr)) * index;
            try self._parse_source.seekableStream().seekTo(offset);
            try self._parse_source.reader().readNoEof(mem.asBytes(&phdr));

            // ELF endianness does NOT match native endianness.
            if (self._endian != native_endian) {
                // Convert fields to native endianness.
                mem.byteSwapAllFields(elf32.Phdr, &phdr);
            }

            // Convert 32-bit header to 64-bit.
            return elf64.Phdr{
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

        pub fn iterator(self: PHeaders) Iterator {
            return .{ .pheaders = self };
        }

        pub const Iterator = struct {
            pheaders: PHeaders,
            index: u16 = 0,

            pub fn next(self: *Iterator) !?elf64.Phdr {
                const result = try self.pheaders.get(self.index) orelse return null;
                self.index += 1;
                return result;
            }
        };
    };
}

pub fn SectionHeaders(ParseSource: type) type {
    return struct {
        const SHeaders = @This();

        len: u16,
        _parse_source: ParseSource,
        _shoff: u64,
        _is_64: bool,
        _endian: Endian,

        pub fn new(header: *const Header, parse_source: ParseSource) SHeaders {
            return .{
                .len = header.shnum,
                ._parse_source = parse_source,
                ._shoff = header.shoff,
                ._is_64 = header.is_64,
                ._endian = header.endian,
            };
        }

        pub fn get(self: *const SHeaders, index: u16) !?elf64.Shdr {
            if (index >= self.len) return null;

            if (self._is_64) {
                var shdr: elf64.Shdr = undefined;
                const offset = self._shoff + @sizeOf(@TypeOf(shdr)) * index;
                try self._parse_source.seekableStream().seekTo(offset);
                try self._parse_source.reader().readNoEof(mem.asBytes(&shdr));

                // ELF endianness matches native endianness.
                if (self._endian == native_endian) return shdr;

                // Convert fields to native endianness.
                mem.byteSwapAllFields(elf64.Shdr, &shdr);
                return shdr;
            }

            var shdr: elf32.Shdr = undefined;
            const offset = self._shoff + @sizeOf(@TypeOf(shdr)) * index;
            try self._parse_source.seekableStream().seekTo(offset);
            try self._parse_source.reader().readNoEof(mem.asBytes(&shdr));

            // ELF endianness does NOT match native endianness.
            if (self._endian != native_endian) {
                // Convert fields to native endianness.
                mem.byteSwapAllFields(elf32.Shdr, &shdr);
            }

            const sh_flags_orig: Word = @bitCast(shdr.sh_flags);
            const sh_flags: Xword = @intCast(sh_flags_orig);
            // Convert 32-bit header to 64-bit.
            return elf64.Shdr{
                .sh_name = shdr.sh_name,
                .sh_type = shdr.sh_type,
                .sh_flags = @bitCast(sh_flags),
                .sh_addr = shdr.sh_addr,
                .sh_offset = shdr.sh_offset,
                .sh_size = shdr.sh_size,
                .sh_link = shdr.sh_link,
                .sh_info = shdr.sh_info,
                .sh_addralign = shdr.sh_addralign,
                .sh_entsize = shdr.sh_entsize,
            };
        }

        pub fn iterator(self: SHeaders) Iterator {
            return .{ .sheaders = self };
        }

        pub const Iterator = struct {
            sheaders: SHeaders,
            index: u16 = 0,

            pub fn next(self: *Iterator) !?elf64.Shdr {
                const shdr = try self.sheaders.get(self.index) orelse return null;
                self.index += 1;
                return shdr;
            }
        };
    };
}

pub fn SymbolTable(ParseSource: type) type {
    return struct {
        const SymTab = @This();

        len: u64,
        string_table_index: u32,
        last_local_symbol: ?u32,
        _parse_source: ParseSource,
        _shoff: u64,
        _entsize: u64,
        _is_64: bool,
        _endian: Endian,

        pub fn new(
            elf_header: *const Header,
            symtab_header: *const elf64.Shdr,
            parse_source: ParseSource,
        ) SymTab {
            return .{
                .string_table_index = symtab_header.sh_link,
                .last_local_symbol = if (symtab_header.sh_info > 0) symtab_header.sh_info - 1 else null,
                .len = @divExact(symtab_header.sh_size, symtab_header.sh_entsize),
                ._parse_source = parse_source,
                ._shoff = symtab_header.sh_offset,
                ._entsize = symtab_header.sh_entsize,
                ._is_64 = elf_header.is_64,
                ._endian = elf_header.endian,
            };
        }

        pub fn get(self: *const SymTab, index: usize) !?elf64.Sym {
            if (index >= self.len) return null;
            const offset = self._shoff + self._entsize * index;

            if (self._is_64) {
                var sym: elf64.Sym = undefined;
                try self._parse_source.seekableStream().seekTo(offset);
                try self._parse_source.reader().readNoEof(mem.asBytes(&sym));

                // ELF endianness matches native endianness.
                if (self._endian == native_endian) return sym;

                // Convert fields to native endianness.
                mem.byteSwapAllFields(elf64.Sym, &sym);
                return sym;
            }

            var sym: elf32.Sym = undefined;
            try self._parse_source.seekableStream().seekTo(offset);
            try self._parse_source.reader().readNoEof(mem.asBytes(&sym));

            // ELF endianness matches native endianness.
            if (self._endian != native_endian)
                // Convert fields to native endianness.
                mem.byteSwapAllFields(elf32.Sym, &sym);

            return elf64.Sym{
                .st_name = sym.st_name,
                .st_info = sym.st_info,
                .st_other = sym.st_other,
                .st_shndx = sym.st_shndx,
                .st_value = @intCast(sym.st_value),
                .st_size = @intCast(sym.st_size),
            };
        }

        pub fn iterator(self: SymTab) SymTab.Iterator {
            return .{ .symtab = self };
        }

        pub const Iterator = struct {
            symtab: SymTab,
            index: u64 = 0,

            pub fn next(self: *Iterator) !?elf64.Sym {
                const sym = try self.symtab.get(self.index) orelse return null;
                self.index += 1;
                return sym;
            }
        };
    };
}

pub fn StringTable(ParseSource: type) type {
    return struct {
        const StrTab = @This();

        len: u64,
        _parse_source: ParseSource,
        _shoff: u64,

        pub fn new(
            strtab_header: *const elf64.Shdr,
            parse_source: ParseSource,
        ) StrTab {
            return .{
                .len = strtab_header.sh_size,
                ._parse_source = parse_source,
                ._shoff = strtab_header.sh_offset,
            };
        }

        pub fn get(
            self: *const StrTab,
            strndx: usize,
            buffer: []u8,
        ) !?[:0]u8 {
            if (strndx == 0) return null;
            var stream = std.io.fixedBufferStream(buffer);
            try self._parse_source.seekableStream().seekTo(self._shoff + strndx);
            try self._parse_source.reader().streamUntilDelimiter(stream.writer(), 0, self.len);
            buffer[stream.pos] = 0;
            return buffer[0..stream.pos :0];
        }

        pub fn getAlloc(
            self: *const StrTab,
            strndx: usize,
            alloc: std.mem.Allocator,
        ) !?[:0]u8 {
            if (strndx == 0) return null;
            var bytes: std.ArrayListUnmanaged(u8) = .empty;
            try self._parse_source.seekableStream().seekTo(self._shoff + strndx);
            try self._parse_source.reader().streamUntilDelimiter(bytes.writer(alloc), 0, self.len);
            return try bytes.toOwnedSliceSentinel(alloc, 0);
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

pub const Half = u16;
pub const Word = u32;
pub const Sword = i32;
pub const Xword = u64;
pub const Sxword = i64;
pub const Section = u16;

pub const Verdef = extern struct {
    version: Half,
    flags: Half,
    ndx: VersionIndex,
    cnt: Half,
    hash: Word,
    aux: Word,
    next: Word,
};
pub const Verdaux = extern struct {
    name: Word,
    next: Word,
};
pub const Vernaux = extern struct {
    hash: Word,
    flags: Half,
    other: Half,
    name: Word,
    next: Word,
};
pub const Elf_Options = extern struct {
    kind: u8,
    size: u8,
    section: Section,
    info: Word,
};
pub const Elf_Options_Hw = extern struct {
    hwp_flags1: Word,
    hwp_flags2: Word,
};
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

pub const ELFCLASS = enum(u8) {
    NONE = 0,
    @"32" = 1,
    @"64" = 2,
    _,
};

pub const ELFDATA = enum(u8) {
    NONE = 0,
    LSB = 1,
    MSB = 2,
    _,
};

pub const EV = enum(u8) {
    NONE = 0,
    CURRENT = 1,
    _,
};

pub const EIdent = packed struct(u128) {
    ei_magic: u32,
    ei_class: ELFCLASS,
    ei_data: ELFDATA,
    ei_version: EV,
    ei_osabi: OSABI,
    ei_abiversion: u8,
    _pad: u56 = 0,

    pub fn magic(ei: *align(1) const EIdent) *const [4]u8 {
        return mem.asBytes(&ei.ei_magic);
    }
};

pub const SymInfo = packed struct(u8) {
    type: STT = .NOTYPE,
    bind: STB = .LOCAL,
};

pub const SHF_OSBITS = packed struct(u8) {
    bits: u8,

    /// Not to be GCed by the linker
    ///
    /// For os bits.
    pub const GNU_RETAIN: SHF_OSBITS = .{ .bits = 0x2 };

    /// Section contains text/data which may be replicated in other sections.
    /// Linker must retain only one copy.
    pub const MIPS_NODUPES: SHF_OSBITS = .{ .bits = 0x10 };

    /// Linker must generate implicit hidden weak names.
    pub const MIPS_NAMES: SHF_OSBITS = .{ .bits = 0x20 };

    /// Section data local to process.
    pub const MIPS_LOCAL: SHF_OSBITS = .{ .bits = 0x40 };

    /// Do not strip this section.
    pub const MIPS_NOSTRIP: SHF_OSBITS = .{ .bits = 0x80 };

    /// Make code section unreadable when in execute-only mode
    /// TODO: according to https://llvm.org/doxygen/namespacellvm_1_1ELF.html this should be a proc bit
    pub const ARM_PURECODE: SHF_OSBITS = .{ .bits = 0x20 };
};

pub const SHF_PROCBITS = packed struct(u4) {
    bits: u4,

    /// This section is excluded from the final executable or shared library.
    ///
    /// For proc bits.
    pub const EXCLUDE: SHF_PROCBITS = .{ .bits = 8 };

    /// If an object file section does not have this flag set, then it may not hold
    /// more than 2GB and can be freely referred to in objects using smaller code
    /// models. Otherwise, only objects using larger code models can refer to them.
    /// For example, a medium code model object can refer to data in a section that
    /// sets this flag besides being able to refer to data in a section that does
    /// not set it; likewise, a small code model object can refer only to code in a
    /// section that does not set this flag.
    pub const X86_64_LARGE: SHF_PROCBITS = .{ .bits = 1 };

    /// All sections with the GPREL flag are grouped into a global data area
    /// for faster accesses
    pub const HEX_GPREL: SHF_PROCBITS = .{ .bits = 1 };

    /// Section must be part of global data area.
    pub const MIPS_GPREL: SHF_PROCBITS = .{ .bits = 1 };

    /// This section should be merged.
    pub const MIPS_MERGE: SHF_PROCBITS = .{ .bits = 2 };

    /// Address size to be inferred from section entry size.
    pub const MIPS_ADDR: SHF_PROCBITS = .{ .bits = 4 };

    /// Section data is string data by default.
    pub const MIPS_STRING: SHF_PROCBITS = .{ .bits = 8 };

    /// All sections with the "d" flag are grouped together by the linker to form
    /// the data section and the dp register is set to the start of the section by
    /// the boot code.
    pub const XCORE_DP_SECTION = .{ .bits = 1 };

    /// All sections with the "c" flag are grouped together by the linker to form
    /// the constant pool and the cp register is set to the start of the constant
    /// pool by the boot code.
    pub const XCORE_CP_SECTION = .{ .bits = 2 };
};

pub const elf32 = struct {
    pub const Addr = u32;
    pub const Off = u32;

    pub const Ehdr = extern struct {
        e_ident: EIdent align(1),
        e_type: ET,
        e_machine: EM,
        e_version: Word,
        e_entry: Addr,
        e_phoff: Off,
        e_shoff: Off,
        e_flags: Word,
        e_ehsize: Half,
        e_phentsize: Half,
        e_phnum: Half,
        e_shentsize: Half,
        e_shnum: Half,
        e_shstrndx: Half,
    };

    pub const Phdr = extern struct {
        p_type: PT,
        p_offset: Off,
        p_vaddr: Addr,
        p_paddr: Addr,
        p_filesz: Word,
        p_memsz: Word,
        p_flags: PF,
        p_align: Word,
    };

    pub const SHF = packed struct(Word) {
        /// Section data should be writable during execution.
        write: bool = false,
        /// Section occupies memory during program execution.
        alloc: bool = false,
        /// Section contains executable machine instructions.
        execinstr: bool = false,
        _pad0: u1 = 0,
        /// The data in this section may be merged.
        merge: bool = false,
        /// The data in this section is null-terminated strings.
        strings: bool = false,
        /// A field in this section holds a section header table index.
        info_link: bool = false,
        /// Adds special ordering requirements for link editors.
        link_order: bool = false,
        /// This section requires special OS-specific processing to avoid incorrect
        /// behavior.
        os_nonconforming: bool = false,
        /// This section is a member of a section group.
        group: bool = false,
        /// This section holds Thread-Local Storage.
        tls: bool = false,
        /// Identifies a section containing compressed data.
        compressed: bool = false,
        _pad1: u8 = 0,
        os: SHF_OSBITS = .{ .bits = 0 },
        proc: SHF_PROCBITS = .{ .bits = 0 },

        pub fn format(
            sh_flags: SHF,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            if (sh_flags.write) try writer.writeAll("W");
            if (sh_flags.alloc) try writer.writeAll("A");
            if (sh_flags.execinstr) try writer.writeAll("X");
            if (sh_flags.merge) try writer.writeAll("M");
            if (sh_flags.strings) try writer.writeAll("S");
            if (sh_flags.info_link) try writer.writeAll("I");
            if (sh_flags.link_order) try writer.writeAll("L");
            if (sh_flags.execinstr) try writer.writeAll("E");
            if (sh_flags.compressed) try writer.writeAll("C");
            if (sh_flags.group) try writer.writeAll("G");
            if (sh_flags.os_nonconforming) try writer.writeAll("O");
            if (sh_flags.tls) try writer.writeAll("T");
            if (sh_flags.os.bits != 0) try writer.print(" OS({x})", .{sh_flags.os.bits});
            if (sh_flags.proc.bits != 0) try writer.print(" PROC({x})", .{sh_flags.proc.bits});
        }
    };

    pub const Shdr = extern struct {
        sh_name: Word,
        sh_type: SHT,
        sh_flags: SHF,
        sh_addr: Addr,
        sh_offset: Off,
        sh_size: Word,
        sh_link: Word,
        sh_info: Word,
        sh_addralign: Word,
        sh_entsize: Word,
    };

    pub const Chdr = extern struct {
        ch_type: COMPRESS,
        ch_size: Word,
        ch_addralign: Word,
    };

    pub const Sym = extern struct {
        st_name: Word,
        st_value: Addr,
        st_size: Word,
        st_info: SymInfo,
        st_other: u8,
        st_shndx: SHN,
    };

    pub const Syminfo = extern struct {
        si_boundto: Half,
        si_flags: Half,
    };

    pub const Rel = extern struct {
        pub const Info = packed struct(Word) {
            type: u8,
            sym: u24,
        };

        r_offset: Addr,
        r_info: Info,
    };

    pub const Rela = extern struct {
        r_offset: Addr,
        r_info: Rel.Info,
        r_addend: Sword,
    };

    pub const Relr = Word;

    pub const DT = enum(Sword) {
        /// Note that this range includes the 0xd offset for .LOOS (since it's easier to compare to documentation).
        pub const OsRange = math.IntFittingRange(0, @intFromEnum(DT.LOOS) - @intFromEnum(DT.HIOS) + 0xd);

        /// Note that this function automatically subtracts 0xd from the value (since it's easier to compare to documentation).
        pub fn os(comptime value: OsRange) DT {
            comptime if (value < 0xd)
                @compileError("invalid OS value");

            const loos = @intFromEnum(DT.LOOS);
            return @enumFromInt(loos + value - 0xd);
        }

        /// Note that this function automatically adds 0xd to the value (since it's easier to compare to documentation).
        pub fn getOs(d_tag: DT) ?OsRange {
            const as_int = @intFromEnum(d_tag);
            const loos = @intFromEnum(DT.LOOS);
            if (as_int < loos or as_int > @intFromEnum(DT.HIOS))
                return null;
            return as_int - loos + 0xd;
        }

        const Reserve = EnumRange(DT, .LOPROC, .HIPROC);
        pub const ReserveRange = Reserve.Range;
        pub const reserve = Reserve.fromInt;
        pub const getReserve = Reserve.toInt;

        const Proc = EnumRange(DT, .LOPROC, .HIPROC);
        pub const ProcRange = Proc.Range;
        pub const proc = Proc.fromInt;
        pub const getProc = Proc.toInt;

        NULL = 0,
        NEEDED = 1,
        PLTRELSZ = 2,
        PLTGOT = 3,
        HASH = 4,
        STRTAB = 5,
        SYMTAB = 6,
        RELA = 7,
        RELASZ = 8,
        RELAENT = 9,
        STRSZ = 10,
        SYMENT = 11,
        INIT = 12,
        FINI = 13,
        SONAME = 14,
        RPATH = 15,
        SYMBOLIC = 16,
        REL = 17,
        RELSZ = 18,
        RELENT = 19,
        PLTREL = 20,
        DEBUG = 21,
        TEXTREL = 22,
        JMPREL = 23,
        BIND_NOW = 24,
        INIT_ARRAY = 25,
        FINI_ARRAY = 26,
        INIT_ARRAYSZ = 27,
        FINI_ARRAYSZ = 28,
        RUNPATH = 29,
        FLAGS = 30,
        PREINIT_ARRAY = 32,
        PREINIT_ARRAYSZ = 33,
        SYMTAB_SHNDX = 34,
        RELRSZ = 35,
        RELR = 36,
        RELRENT = 37,
        NUM = 38,
        LOOS = 0x6000000d,
        HIOS = 0x6fffefff,
        LORESERVE = 0x6ffff000,
        HIRESERVE = 0x6fffffff,
        LOPROC = 0x70000000,
        HIPROC = 0x7fffffff,
        _,

        pub const ENCODING: DT = @enumFromInt(32);
        pub const PROCNUM: DT = @enumFromInt(36);

        pub const VALRNGLO: DT = reserve(0xd00);
        pub const GNU_PRELINKED: DT = reserve(0xdf5);
        pub const GNU_CONFLICTSZ: DT = reserve(0xdf6);
        pub const GNU_LIBLISTSZ: DT = reserve(0xdf7);
        pub const CHECKSUM: DT = reserve(0xdf8);
        pub const PLTPADSZ: DT = reserve(0xdf9);
        pub const MOVEENT: DT = reserve(0xdfa);
        pub const MOVESZ: DT = reserve(0xdfb);
        pub const FEATURE_1: DT = reserve(0xdfc);
        pub const POSFLAG_1: DT = reserve(0xdfd);

        pub const SYMINSZ: DT = reserve(0xdfe);
        pub const SYMINENT: DT = reserve(0xdff);
        pub const VALRNGHI: DT = reserve(0xdff);
        pub const VALNUM: DT = @enumFromInt(12);

        pub const ADDRRNGLO: DT = reserve(0xe00);
        pub const GNU_HASH: DT = reserve(0xef5);
        pub const TLSDESC_PLT: DT = reserve(0xef6);
        pub const TLSDESC_GOT: DT = reserve(0xef7);
        pub const GNU_CONFLICT: DT = reserve(0xef8);
        pub const GNU_LIBLIST: DT = reserve(0xef9);
        pub const CONFIG: DT = reserve(0xefa);
        pub const DEPAUDIT: DT = reserve(0xefb);
        pub const AUDIT: DT = reserve(0xefc);
        pub const PLTPAD: DT = reserve(0xefd);
        pub const MOVETAB: DT = reserve(0xefe);
        pub const SYMINFO: DT = reserve(0xeff);
        pub const ADDRRNGHI: DT = reserve(0xeff);
        pub const ADDRNUM: DT = @enumFromInt(11);

        pub const VERSYM: DT = reserve(0xff0);

        pub const RELACOUNT: DT = reserve(0xff9);
        pub const RELCOUNT: DT = reserve(0xffa);

        pub const FLAGS_1: DT = reserve(0xffb);
        pub const VERDEF: DT = reserve(0xffc);

        pub const VERDEFNUM: DT = reserve(0xffd);
        pub const VERNEED: DT = reserve(0xffe);

        pub const VERNEEDNUM: DT = reserve(0xfff);
        pub const VERSIONTAGNUM: DT = @enumFromInt(16);

        pub const AUXILIARY: DT = proc(0xffffffd);
        pub const FILTER: DT = proc(0xfffffff);
        pub const EXTRANUM: DT = @enumFromInt(3);

        pub const SPARC_REGISTER: DT = proc(0x1);
        pub const SPARC_NUM: DT = @enumFromInt(2);

        pub const MIPS_RLD_VERSION: DT = proc(0x1);
        pub const MIPS_TIME_STAMP: DT = proc(0x2);
        pub const MIPS_ICHECKSUM: DT = proc(0x3);
        pub const MIPS_IVERSION: DT = proc(0x4);
        pub const MIPS_FLAGS: DT = proc(0x5);
        pub const MIPS_BASE_ADDRESS: DT = proc(0x6);
        pub const MIPS_MSYM: DT = proc(0x7);
        pub const MIPS_CONFLICT: DT = proc(0x8);
        pub const MIPS_LIBLIST: DT = proc(0x9);
        pub const MIPS_LOCAL_GOTNO: DT = proc(0xa);
        pub const MIPS_CONFLICTNO: DT = proc(0xb);
        pub const MIPS_LIBLISTNO: DT = proc(0x10);
        pub const MIPS_SYMTABNO: DT = proc(0x11);
        pub const MIPS_UNREFEXTNO: DT = proc(0x12);
        pub const MIPS_GOTSYM: DT = proc(0x13);
        pub const MIPS_HIPAGENO: DT = proc(0x14);
        pub const MIPS_RLD_MAP: DT = proc(0x16);
        pub const MIPS_DELTA_CLASS: DT = proc(0x17);
        pub const MIPS_DELTA_CLASS_NO: DT = proc(0x18);

        pub const MIPS_DELTA_INSTANCE: DT = proc(0x19);
        pub const MIPS_DELTA_INSTANCE_NO: DT = proc(0x1a);

        pub const MIPS_DELTA_RELOC: DT = proc(0x1b);
        pub const MIPS_DELTA_RELOC_NO: DT = proc(0x1c);

        pub const MIPS_DELTA_SYM: DT = proc(0x1d);

        pub const MIPS_DELTA_SYM_NO: DT = proc(0x1e);

        pub const MIPS_DELTA_CLASSSYM: DT = proc(0x20);

        pub const MIPS_DELTA_CLASSSYM_NO: DT = proc(0x21);

        pub const MIPS_CXX_FLAGS: DT = proc(0x22);
        pub const MIPS_PIXIE_INIT: DT = proc(0x23);
        pub const MIPS_SYMBOL_LIB: DT = proc(0x24);
        pub const MIPS_LOCALPAGE_GOTIDX: DT = proc(0x25);
        pub const MIPS_LOCAL_GOTIDX: DT = proc(0x26);
        pub const MIPS_HIDDEN_GOTIDX: DT = proc(0x27);
        pub const MIPS_PROTECTED_GOTIDX: DT = proc(0x28);
        pub const MIPS_OPTIONS: DT = proc(0x29);
        pub const MIPS_INTERFACE: DT = proc(0x2a);
        pub const MIPS_DYNSTR_ALIGN: DT = proc(0x2b);
        pub const MIPS_INTERFACE_SIZE: DT = proc(0x2c);
        pub const MIPS_RLD_TEXT_RESOLVE_ADDR: DT = proc(0x2d);

        pub const MIPS_PERF_SUFFIX: DT = proc(0x2e);

        pub const MIPS_COMPACT_SIZE: DT = proc(0x2f);
        pub const MIPS_GP_VALUE: DT = proc(0x30);
        pub const MIPS_AUX_DYNAMIC: DT = proc(0x31);

        pub const MIPS_PLTGOT: DT = proc(0x32);

        pub const MIPS_RWPLT: DT = proc(0x34);
        pub const MIPS_RLD_MAP_REL: DT = proc(0x35);
        pub const MIPS_NUM: DT = @enumFromInt(0x36);

        pub const ALPHA_PLTRO: DT = proc(0x0);
        pub const ALPHA_NUM: DT = @enumFromInt(1);

        pub const PPC_GOT: DT = proc(0x0);
        pub const PPC_OPT: DT = proc(0x1);
        pub const PPC_NUM: DT = @enumFromInt(2);

        pub const PPC64_GLINK: DT = proc(0x0);
        pub const PPC64_OPD: DT = proc(0x1);
        pub const PPC64_OPDSZ: DT = proc(0x2);
        pub const PPC64_OPT: DT = proc(0x3);
        pub const PPC64_NUM: DT = @enumFromInt(4);

        pub const IA_64_PLT_RESERVE: DT = proc(0x0);
        pub const IA_64_NUM: DT = @enumFromInt(1);

        pub const NIOS2_GP: DT = proc(0x2);
    };

    pub const Dyn = extern struct {
        d_tag: DT,
        d_val: Addr,
    };

    pub const Verneed = extern struct {
        vn_version: Half,
        vn_cnt: Half,
        vn_file: Word,
        vn_aux: Word,
        vn_next: Word,
    };

    pub const AT = enum(u32) {
        NULL = 0,
        IGNORE = 1,
        EXECFD = 2,
        PHDR = 3,
        PHENT = 4,
        PHNUM = 5,
        PAGESZ = 6,
        BASE = 7,
        FLAGS = 8,
        ENTRY = 9,
        NOTELF = 10,
        UID = 11,
        EUID = 12,
        GID = 13,
        EGID = 14,
        CLKTCK = 17,
        PLATFORM = 15,
        HWCAP = 16,
        FPUCW = 18,
        DCACHEBSIZE = 19,
        ICACHEBSIZE = 20,
        UCACHEBSIZE = 21,
        IGNOREPPC = 22,
        SECURE = 23,
        BASE_PLATFORM = 24,
        RANDOM = 25,
        HWCAP2 = 26,
        EXECFN = 31,
        SYSINFO = 32,
        SYSINFO_EHDR = 33,
        L1I_CACHESHAPE = 34,
        L1D_CACHESHAPE = 35,
        L2_CACHESHAPE = 36,
        L3_CACHESHAPE = 37,
        L1I_CACHESIZE = 40,
        L1I_CACHEGEOMETRY = 41,
        L1D_CACHESIZE = 42,
        L1D_CACHEGEOMETRY = 43,
        L2_CACHESIZE = 44,
        L2_CACHEGEOMETRY = 45,
        L3_CACHESIZE = 46,
        L3_CACHEGEOMETRY = 47,
    };

    pub const auxv_t = extern struct {
        a_type: AT,
        a_un: extern union {
            a_val: u32,
        },
    };

    pub const Nhdr = extern struct {
        n_namesz: Word,
        n_descsz: Word,
        n_type: Word,
    };

    pub const Move = extern struct {
        m_value: Xword,
        m_info: Word,
        m_poffset: Word,
        m_repeat: Half,
        m_stride: Half,
    };

    pub const gptab = extern union {
        gt_header: extern struct {
            gt_current_g_value: Word,
            gt_unused: Word,
        },
        gt_entry: extern struct {
            gt_g_value: Word,
            gt_bytes: Word,
        },
    };

    pub const RegInfo = extern struct {
        ri_gprmask: Word,
        ri_cprmask: [4]Word,
        ri_gp_value: Sword,
    };

    pub const Lib = extern struct {
        l_name: Word,
        l_time_stamp: Word,
        l_checksum: Word,
        l_version: Word,
        l_flags: Word,
    };

    pub const Conflict = Addr;
};

pub const elf64 = struct {
    pub const Addr = u64;
    pub const Off = u64;

    pub const Ehdr = extern struct {
        e_ident: EIdent align(1),
        e_type: ET,
        e_machine: EM,
        e_version: Word,
        e_entry: Addr,
        e_phoff: Off,
        e_shoff: Off,
        e_flags: Word,
        e_ehsize: Half,
        e_phentsize: Half,
        e_phnum: Half,
        e_shentsize: Half,
        e_shnum: Half,
        e_shstrndx: Half,
    };

    pub const Phdr = extern struct {
        p_type: PT,
        p_flags: PF,
        p_offset: Off,
        p_vaddr: Addr,
        p_paddr: Addr,
        p_filesz: Xword,
        p_memsz: Xword,
        p_align: Xword,
    };

    pub const SHF = packed struct(Xword) {
        /// Section data should be writable during execution.
        write: bool = false,
        /// Section occupies memory during program execution.
        alloc: bool = false,
        /// Section contains executable machine instructions.
        execinstr: bool = false,
        _pad0: u1 = 0,
        /// The data in this section may be merged.
        merge: bool = false,
        /// The data in this section is null-terminated strings.
        strings: bool = false,
        /// A field in this section holds a section header table index.
        info_link: bool = false,
        /// Adds special ordering requirements for link editors.
        link_order: bool = false,
        /// This section requires special OS-specific processing to avoid incorrect
        /// behavior.
        os_nonconforming: bool = false,
        /// This section is a member of a section group.
        group: bool = false,
        /// This section holds Thread-Local Storage.
        tls: bool = false,
        /// Identifies a section containing compressed data.
        compressed: bool = false,
        _pad1: u8 = 0,
        os: SHF_OSBITS = .{ .bits = 0 },
        proc: SHF_PROCBITS = .{ .bits = 0 },
        _pad2: u32 = 0,

        pub fn format(
            sh_flags: SHF,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            if (sh_flags.write) try writer.writeAll("W");
            if (sh_flags.alloc) try writer.writeAll("A");
            if (sh_flags.execinstr) try writer.writeAll("X");
            if (sh_flags.merge) try writer.writeAll("M");
            if (sh_flags.strings) try writer.writeAll("S");
            if (sh_flags.info_link) try writer.writeAll("I");
            if (sh_flags.link_order) try writer.writeAll("L");
            if (sh_flags.execinstr) try writer.writeAll("E");
            if (sh_flags.compressed) try writer.writeAll("C");
            if (sh_flags.group) try writer.writeAll("G");
            if (sh_flags.os_nonconforming) try writer.writeAll("O");
            if (sh_flags.tls) try writer.writeAll("T");
            if (sh_flags.os.bits != 0) try writer.print(" OS({x})", .{sh_flags.os.bits});
            if (sh_flags.proc.bits != 0) try writer.print(" PROC({x})", .{sh_flags.proc.bits});
        }
    };

    pub const Shdr = extern struct {
        sh_name: Word,
        sh_type: SHT,
        sh_flags: SHF,
        sh_addr: Addr,
        sh_offset: Off,
        sh_size: Xword,
        sh_link: Word,
        sh_info: Word,
        sh_addralign: Xword,
        sh_entsize: Xword,
    };

    pub const Chdr = extern struct {
        ch_type: COMPRESS,
        ch_reserved: Word = 0,
        ch_size: Xword,
        ch_addralign: Xword,
    };

    pub const Sym = extern struct {
        st_name: Word,
        st_info: SymInfo,
        st_other: u8,
        st_shndx: SHN,
        st_value: Addr,
        st_size: Xword,

        pub fn shndx(sym: Sym) std.meta.Tag(SHN) {
            return @intFromEnum(sym.st_shndx);
        }
    };

    pub const Syminfo = extern struct {
        si_boundto: Half,
        si_flags: Half,
    };

    pub const Rel = extern struct {
        pub const Info = packed struct(Xword) {
            type: u32,
            sym: u32,
        };

        r_offset: Addr,
        r_info: Info,
    };

    pub const Rela = extern struct {
        r_offset: Addr,
        r_info: Rel.Info,
        r_addend: Sxword,
    };

    pub const Relr = Xword;

    pub const DT = @Type(Type: {
        var @"enum" = @typeInfo(elf32.DT).@"enum";
        @"enum".tag_type = Sxword;
        break :Type .{ .@"enum" = @"enum" };
    });

    pub const Dyn = extern struct {
        d_tag: DT,
        d_val: Addr,
    };

    pub const Verneed = extern struct {
        vn_version: Half,
        vn_cnt: Half,
        vn_file: Word,
        vn_aux: Word,
        vn_next: Word,
    };

    pub const AT = @Type(Type: {
        var @"enum" = @typeInfo(elf32.AT).@"enum";
        @"enum".tag_type = u64;
        break :Type .{ .@"enum" = @"enum" };
    });

    pub const auxv_t = extern struct {
        a_type: AT,
        a_un: extern union {
            a_val: u64,
        },
    };

    pub const Nhdr = extern struct {
        n_namesz: Word,
        n_descsz: Word,
        n_type: Word,
    };

    pub const Move = extern struct {
        m_value: Xword,
        m_info: Xword,
        m_poffset: Xword,
        m_repeat: Half,
        m_stride: Half,
    };

    pub const Lib = extern struct {
        l_name: Word,
        l_time_stamp: Word,
        l_checksum: Word,
        l_version: Word,
        l_flags: Word,
    };
};

comptime {
    assert(@sizeOf(elf32.Ehdr) == 52);
    assert(@sizeOf(elf64.Ehdr) == 64);

    assert(@sizeOf(elf32.Phdr) == 32);
    assert(@sizeOf(elf64.Phdr) == 56);

    assert(@sizeOf(elf32.Shdr) == 40);
    assert(@sizeOf(elf64.Shdr) == 64);
}

pub const native = switch (@sizeOf(usize)) {
    4 => elf32,
    8 => elf64,
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

pub const PF = packed struct(Word) {
    execute: bool = false,
    write: bool = false,
    read: bool = false,
    _pad: u17 = 0,
    /// Bits for operating system-specific semantics.
    os: u8 = 0,
    /// Bits for processor-specific semantics.
    proc: u4 = 0,

    pub fn format(
        p_flags: PF,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.writeAll(if (p_flags.read) "R" else "-");
        try writer.writeAll(if (p_flags.write) "W" else "-");
        try writer.writeAll(if (p_flags.execute) "X" else "-");
        if (p_flags.os != 0) try writer.print(" OS({x})", .{p_flags.os});
        if (p_flags.proc != 0) try writer.print(" PROC({x})", .{p_flags.proc});
    }
};

pub const SHN = enum(Section) {
    const Reserve = EnumRange(SHN, .LORESERVE, .HIRESERVE);
    pub const ReserveRange = Reserve.Range;
    pub const reserve = Reserve.fromInt;
    pub const getReserve = Reserve.toInt;

    /// Undefined section
    UNDEF = 0,
    LORESERVE = 0xff00,
    HIRESERVE = 0xffff,
    _,

    pub const LOPROC = reserve(0x00);
    pub const HIPROC = reserve(0x1f);

    pub const LIVEPATCH = reserve(0x20);
    /// Associated symbol is absolute
    pub const ABS = reserve(0xf1);
    /// Associated symbol is common
    pub const COMMON = reserve(0xf2);
};

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

pub const gnu_hash = struct {

    // See https://flapenguin.me/elf-dt-gnu-hash

    pub const Header = extern struct {
        nbuckets: u32,
        symoffset: u32,
        bloom_size: u32,
        bloom_shift: u32,
    };

    pub const ChainEntry = packed struct(u32) {
        end_of_chain: bool,
        /// Contains the top bits of the hash value.
        hash: u31,
    };

    /// Calculate the hash value for a name
    pub fn calculate(name: []const u8) u32 {
        var hash: u32 = 5381;

        for (name) |char| {
            hash = (hash << 5) +% hash +% char;
        }

        return hash;
    }

    test calculate {
        try std.testing.expectEqual(0x00001505, calculate(""));
        try std.testing.expectEqual(0x156b2bb8, calculate("printf"));
        try std.testing.expectEqual(0x7c967e3f, calculate("exit"));
        try std.testing.expectEqual(0xbac212a0, calculate("syscall"));
        try std.testing.expectEqual(0x8ae9f18e, calculate("flapenguin.me"));
    }
};

fn EnumRange(E: type, start: E, end: E) type {
    const start_int = @intFromEnum(start);
    const end_int = @intFromEnum(end);

    return struct {
        pub const Range = math.IntFittingRange(0, end_int - start_int);

        pub fn toInt(value: E) ?Range {
            const as_int = @intFromEnum(value);
            if (as_int < start_int or as_int > end_int) return null;
            return @truncate(as_int - start_int);
        }

        pub fn fromInt(comptime value: Range) E {
            comptime assert(value <= end_int - start_int);
            return @enumFromInt(start_int + value);
        }
    };
}
