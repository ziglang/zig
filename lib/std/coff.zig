const std = @import("std.zig");
const assert = std.debug.assert;
const mem = std.mem;

pub const Header = extern struct {
    /// The number that identifies the type of target machine.
    machine: IMAGE.FILE.MACHINE,

    /// The number of sections. This indicates the size of the section table, which immediately follows the headers.
    number_of_sections: u16,

    /// The low 32 bits of the number of seconds since 00:00 January 1, 1970 (a C run-time time_t value),
    /// which indicates when the file was created.
    time_date_stamp: u32,

    /// The file offset of the COFF symbol table, or zero if no COFF symbol table is present.
    /// This value should be zero for an image because COFF debugging information is deprecated.
    pointer_to_symbol_table: u32,

    /// The number of entries in the symbol table.
    /// This data can be used to locate the string table, which immediately follows the symbol table.
    /// This value should be zero for an image because COFF debugging information is deprecated.
    number_of_symbols: u32,

    /// The size of the optional header, which is required for executable files but not for object files.
    /// This value should be zero for an object file. For a description of the header format, see Optional Header (Image Only).
    size_of_optional_header: u16,

    /// The flags that indicate the attributes of the file.
    flags: Header.Flags,

    pub const Flags = packed struct(u16) {
        /// Image only, Windows CE, and Microsoft Windows NT and later.
        /// This indicates that the file does not contain base relocations
        /// and must therefore be loaded at its preferred base address.
        /// If the base address is not available, the loader reports an error.
        /// The default behavior of the linker is to strip base relocations
        /// from executable (EXE) files.
        RELOCS_STRIPPED: bool = false,

        /// Image only. This indicates that the image file is valid and can be run.
        /// If this flag is not set, it indicates a linker error.
        EXECUTABLE_IMAGE: bool = false,

        /// COFF line numbers have been removed. This flag is deprecated and should be zero.
        LINE_NUMS_STRIPPED: bool = false,

        /// COFF symbol table entries for local symbols have been removed.
        /// This flag is deprecated and should be zero.
        LOCAL_SYMS_STRIPPED: bool = false,

        /// Obsolete. Aggressively trim working set.
        /// This flag is deprecated for Windows 2000 and later and must be zero.
        AGGRESSIVE_WS_TRIM: bool = false,

        /// Application can handle > 2-GB addresses.
        LARGE_ADDRESS_AWARE: bool = false,

        /// This flag is reserved for future use.
        RESERVED: bool = false,

        /// Little endian: the least significant bit (LSB) precedes the
        /// most significant bit (MSB) in memory. This flag is deprecated and should be zero.
        BYTES_REVERSED_LO: bool = false,

        /// Machine is based on a 32-bit-word architecture.
        @"32BIT_MACHINE": bool = false,

        /// Debugging information is removed from the image file.
        DEBUG_STRIPPED: bool = false,

        /// If the image is on removable media, fully load it and copy it to the swap file.
        REMOVABLE_RUN_FROM_SWAP: bool = false,

        /// If the image is on network media, fully load it and copy it to the swap file.
        NET_RUN_FROM_SWAP: bool = false,

        /// The image file is a system file, not a user program.
        SYSTEM: bool = false,

        /// The image file is a dynamic-link library (DLL).
        /// Such files are considered executable files for almost all purposes,
        /// although they cannot be directly run.
        DLL: bool = false,

        /// The file should be run only on a uniprocessor machine.
        UP_SYSTEM_ONLY: bool = false,

        /// Big endian: the MSB precedes the LSB in memory. This flag is deprecated and should be zero.
        BYTES_REVERSED_HI: bool = false,
    };
};

// OptionalHeader.magic values
// see https://msdn.microsoft.com/en-us/library/windows/desktop/ms680339(v=vs.85).aspx
pub const IMAGE_NT_OPTIONAL_HDR32_MAGIC = @intFromEnum(OptionalHeader.Magic.PE32);
pub const IMAGE_NT_OPTIONAL_HDR64_MAGIC = @intFromEnum(OptionalHeader.Magic.@"PE32+");

pub const DllFlags = packed struct(u16) {
    _reserved_0: u5 = 0,

    /// Image can handle a high entropy 64-bit virtual address space.
    HIGH_ENTROPY_VA: bool = false,

    /// DLL can be relocated at load time.
    DYNAMIC_BASE: bool = false,

    /// Code Integrity checks are enforced.
    FORCE_INTEGRITY: bool = false,

    /// Image is NX compatible.
    NX_COMPAT: bool = false,

    /// Isolation aware, but do not isolate the image.
    NO_ISOLATION: bool = false,

    /// Does not use structured exception (SE) handling. No SE handler may be called in this image.
    NO_SEH: bool = false,

    /// Do not bind the image.
    NO_BIND: bool = false,

    /// Image must execute in an AppContainer.
    APPCONTAINER: bool = false,

    /// A WDM driver.
    WDM_DRIVER: bool = false,

    /// Image supports Control Flow Guard.
    GUARD_CF: bool = false,

    /// Terminal Server aware.
    TERMINAL_SERVER_AWARE: bool = false,
};

pub const Subsystem = enum(u16) {
    /// An unknown subsystem
    UNKNOWN = 0,

    /// Device drivers and native Windows processes
    NATIVE = 1,

    /// The Windows graphical user interface (GUI) subsystem
    WINDOWS_GUI = 2,

    /// The Windows character subsystem
    WINDOWS_CUI = 3,

    /// The OS/2 character subsystem
    OS2_CUI = 5,

    /// The Posix character subsystem
    POSIX_CUI = 7,

    /// Native Win9x driver
    NATIVE_WINDOWS = 8,

    /// Windows CE
    WINDOWS_CE_GUI = 9,

    /// An Extensible Firmware Interface (EFI) application
    EFI_APPLICATION = 10,

    /// An EFI driver with boot services
    EFI_BOOT_SERVICE_DRIVER = 11,

    /// An EFI driver with run-time services
    EFI_RUNTIME_DRIVER = 12,

    /// An EFI ROM image
    EFI_ROM = 13,

    /// XBOX
    XBOX = 14,

    /// Windows boot application
    WINDOWS_BOOT_APPLICATION = 16,

    _,
};

pub const OptionalHeader = extern struct {
    magic: OptionalHeader.Magic,
    major_linker_version: u8,
    minor_linker_version: u8,
    size_of_code: u32,
    size_of_initialized_data: u32,
    size_of_uninitialized_data: u32,
    address_of_entry_point: u32,
    base_of_code: u32,

    pub const Magic = enum(u16) {
        PE32 = 0x10b,
        @"PE32+" = 0x20b,
        _,
    };

    pub const PE32 = extern struct {
        standard: OptionalHeader,
        base_of_data: u32,
        image_base: u32,
        section_alignment: u32,
        file_alignment: u32,
        major_operating_system_version: u16,
        minor_operating_system_version: u16,
        major_image_version: u16,
        minor_image_version: u16,
        major_subsystem_version: u16,
        minor_subsystem_version: u16,
        win32_version_value: u32,
        size_of_image: u32,
        size_of_headers: u32,
        checksum: u32,
        subsystem: Subsystem,
        dll_flags: DllFlags,
        size_of_stack_reserve: u32,
        size_of_stack_commit: u32,
        size_of_heap_reserve: u32,
        size_of_heap_commit: u32,
        loader_flags: u32,
        number_of_rva_and_sizes: u32,
    };

    pub const @"PE32+" = extern struct {
        standard: OptionalHeader,
        image_base: u64,
        section_alignment: u32,
        file_alignment: u32,
        major_operating_system_version: u16,
        minor_operating_system_version: u16,
        major_image_version: u16,
        minor_image_version: u16,
        major_subsystem_version: u16,
        minor_subsystem_version: u16,
        win32_version_value: u32,
        size_of_image: u32,
        size_of_headers: u32,
        checksum: u32,
        subsystem: Subsystem,
        dll_flags: DllFlags,
        size_of_stack_reserve: u64,
        size_of_stack_commit: u64,
        size_of_heap_reserve: u64,
        size_of_heap_commit: u64,
        loader_flags: u32,
        number_of_rva_and_sizes: u32,
    };
};

pub const IMAGE_NUMBEROF_DIRECTORY_ENTRIES = 16;

pub const DirectoryEntry = enum(u16) {
    /// Export Directory
    EXPORT = 0,

    /// Import Directory
    IMPORT = 1,

    /// Resource Directory
    RESOURCE = 2,

    /// Exception Directory
    EXCEPTION = 3,

    /// Security Directory
    SECURITY = 4,

    /// Base Relocation Table
    BASERELOC = 5,

    /// Debug Directory
    DEBUG = 6,

    /// Architecture Specific Data
    ARCHITECTURE = 7,

    /// RVA of GP
    GLOBALPTR = 8,

    /// TLS Directory
    TLS = 9,

    /// Load Configuration Directory
    LOAD_CONFIG = 10,

    /// Bound Import Directory in headers
    BOUND_IMPORT = 11,

    /// Import Address Table
    IAT = 12,

    /// Delay Load Import Descriptors
    DELAY_IMPORT = 13,

    /// COM Runtime descriptor
    COM_DESCRIPTOR = 14,

    _,
};

pub const ImageDataDirectory = extern struct {
    virtual_address: u32,
    size: u32,
};

pub const BaseRelocationDirectoryEntry = extern struct {
    /// The image base plus the page RVA is added to each offset to create the VA where the base relocation must be applied.
    page_rva: u32,

    /// The total number of bytes in the base relocation block, including the Page RVA and Block Size fields and the Type/Offset fields that follow.
    block_size: u32,
};

pub const BaseRelocation = packed struct(u16) {
    /// Stored in the remaining 12 bits of the WORD, an offset from the starting address that was specified in the Page RVA field for the block.
    /// This offset specifies where the base relocation is to be applied.
    offset: u12,

    /// Stored in the high 4 bits of the WORD, a value that indicates the type of base relocation to be applied.
    type: BaseRelocationType,
};

pub const BaseRelocationType = enum(u4) {
    /// The base relocation is skipped. This type can be used to pad a block.
    ABSOLUTE = 0,

    /// The base relocation adds the high 16 bits of the difference to the 16-bit field at offset. The 16-bit field represents the high value of a 32-bit word.
    HIGH = 1,

    /// The base relocation adds the low 16 bits of the difference to the 16-bit field at offset. The 16-bit field represents the low half of a 32-bit word.
    LOW = 2,

    /// The base relocation applies all 32 bits of the difference to the 32-bit field at offset.
    HIGHLOW = 3,

    /// The base relocation adds the high 16 bits of the difference to the 16-bit field at offset.
    /// The 16-bit field represents the high value of a 32-bit word.
    /// The low 16 bits of the 32-bit value are stored in the 16-bit word that follows this base relocation.
    /// This means that this base relocation occupies two slots.
    HIGHADJ = 4,

    /// When the machine type is MIPS, the base relocation applies to a MIPS jump instruction.
    MIPS_JMPADDR = 5,

    /// This relocation is meaningful only when the machine type is ARM or Thumb.
    /// The base relocation applies the 32-bit address of a symbol across a consecutive MOVW/MOVT instruction pair.
    // ARM_MOV32 = 5,

    /// This relocation is only meaningful when the machine type is RISC-V.
    /// The base relocation applies to the high 20 bits of a 32-bit absolute address.
    // RISCV_HIGH20 = 5,

    /// Reserved, must be zero.
    RESERVED = 6,

    /// This relocation is meaningful only when the machine type is Thumb.
    /// The base relocation applies the 32-bit address of a symbol to a consecutive MOVW/MOVT instruction pair.
    THUMB_MOV32 = 7,

    /// This relocation is only meaningful when the machine type is RISC-V.
    /// The base relocation applies to the low 12 bits of a 32-bit absolute address formed in RISC-V I-type instruction format.
    // RISCV_LOW12I = 7,

    /// This relocation is only meaningful when the machine type is RISC-V.
    /// The base relocation applies to the low 12 bits of a 32-bit absolute address formed in RISC-V S-type instruction format.
    RISCV_LOW12S = 8,

    /// This relocation is only meaningful when the machine type is LoongArch 32-bit.
    /// The base relocation applies to a 32-bit absolute address formed in two consecutive instructions.
    // LOONGARCH32_MARK_LA = 8,

    /// This relocation is only meaningful when the machine type is LoongArch 64-bit.
    /// The base relocation applies to a 64-bit absolute address formed in four consecutive instructions.
    // LOONGARCH64_MARK_LA = 8,

    /// The relocation is only meaningful when the machine type is MIPS.
    /// The base relocation applies to a MIPS16 jump instruction.
    MIPS_JMPADDR16 = 9,

    /// The base relocation applies the difference to the 64-bit field at offset.
    DIR64 = 10,

    _,
};

pub const DebugDirectoryEntry = extern struct {
    characteristics: u32,
    time_date_stamp: u32,
    major_version: u16,
    minor_version: u16,
    type: DebugType,
    size_of_data: u32,
    address_of_raw_data: u32,
    pointer_to_raw_data: u32,
};

pub const DebugType = enum(u32) {
    UNKNOWN = 0,
    COFF = 1,
    CODEVIEW = 2,
    FPO = 3,
    MISC = 4,
    EXCEPTION = 5,
    FIXUP = 6,
    OMAP_TO_SRC = 7,
    OMAP_FROM_SRC = 8,
    BORLAND = 9,
    RESERVED10 = 10,
    VC_FEATURE = 12,
    POGO = 13,
    ILTCG = 14,
    MPX = 15,
    REPRO = 16,
    EX_DLLCHARACTERISTICS = 20,

    _,
};

pub const ImportDirectoryEntry = extern struct {
    /// The RVA of the import lookup table.
    /// This table contains a name or ordinal for each import.
    /// (The name "Characteristics" is used in Winnt.h, but no longer describes this field.)
    import_lookup_table_rva: u32,

    /// The stamp that is set to zero until the image is bound.
    /// After the image is bound, this field is set to the time/data stamp of the DLL.
    time_date_stamp: u32,

    /// The index of the first forwarder reference.
    forwarder_chain: u32,

    /// The address of an ASCII string that contains the name of the DLL.
    /// This address is relative to the image base.
    name_rva: u32,

    /// The RVA of the import address table.
    /// The contents of this table are identical to the contents of the import lookup table until the image is bound.
    import_address_table_rva: u32,
};

pub const ImportLookupEntry32 = struct {
    pub const ByName = packed struct(u32) {
        name_table_rva: u31,
        flag: u1 = 0,
    };

    pub const ByOrdinal = packed struct(u32) {
        ordinal_number: u16,
        unused: u15 = 0,
        flag: u1 = 1,
    };

    const mask = 0x80000000;

    pub fn getImportByName(raw: u32) ?ByName {
        if (mask & raw != 0) return null;
        return @as(ByName, @bitCast(raw));
    }

    pub fn getImportByOrdinal(raw: u32) ?ByOrdinal {
        if (mask & raw == 0) return null;
        return @as(ByOrdinal, @bitCast(raw));
    }
};

pub const ImportLookupEntry64 = struct {
    pub const ByName = packed struct(u64) {
        name_table_rva: u31,
        unused: u32 = 0,
        flag: u1 = 0,
    };

    pub const ByOrdinal = packed struct(u64) {
        ordinal_number: u16,
        unused: u47 = 0,
        flag: u1 = 1,
    };

    const mask = 0x8000000000000000;

    pub fn getImportByName(raw: u64) ?ByName {
        if (mask & raw != 0) return null;
        return @as(ByName, @bitCast(raw));
    }

    pub fn getImportByOrdinal(raw: u64) ?ByOrdinal {
        if (mask & raw == 0) return null;
        return @as(ByOrdinal, @bitCast(raw));
    }
};

/// Every name ends with a NULL byte. IF the NULL byte does not fall on
/// 2byte boundary, the entry structure is padded to ensure 2byte alignment.
pub const ImportHintNameEntry = extern struct {
    /// An index into the export name pointer table.
    /// A match is attempted first with this value. If it fails, a binary search is performed on the DLL's export name pointer table.
    hint: u16,

    /// Pointer to NULL terminated ASCII name.
    /// Variable length...
    name: [1]u8,
};

pub const SectionHeader = extern struct {
    name: [8]u8,
    virtual_size: u32,
    virtual_address: u32,
    size_of_raw_data: u32,
    pointer_to_raw_data: u32,
    pointer_to_relocations: u32,
    pointer_to_linenumbers: u32,
    number_of_relocations: u16,
    number_of_linenumbers: u16,
    flags: SectionHeader.Flags,

    pub fn getName(self: *align(1) const SectionHeader) ?[]const u8 {
        if (self.name[0] == '/') return null;
        const len = std.mem.indexOfScalar(u8, &self.name, @as(u8, 0)) orelse self.name.len;
        return self.name[0..len];
    }

    pub fn getNameOffset(self: SectionHeader) ?u32 {
        if (self.name[0] != '/') return null;
        const len = std.mem.indexOfScalar(u8, &self.name, @as(u8, 0)) orelse self.name.len;
        const offset = std.fmt.parseInt(u32, self.name[1..len], 10) catch unreachable;
        return offset;
    }

    /// Applicable only to section headers in COFF objects.
    pub fn getAlignment(self: SectionHeader) ?u16 {
        return self.flags.ALIGN.toByteUnits();
    }

    pub fn setAlignment(self: *SectionHeader, new_alignment: u16) void {
        self.flags.ALIGN = .fromByteUnits(new_alignment);
    }

    pub fn isCode(self: SectionHeader) bool {
        return self.flags.CNT_CODE;
    }

    pub fn isComdat(self: SectionHeader) bool {
        return self.flags.LNK_COMDAT;
    }

    pub const Flags = packed struct(u32) {
        SCALE_INDEX: bool = false,

        unused1: u2 = 0,

        /// The section should not be padded to the next boundary.
        /// This flag is obsolete and is replaced by `.ALIGN = .@"1BYTES"`.
        /// This is valid only for object files.
        TYPE_NO_PAD: bool = false,

        unused4: u1 = 0,

        /// The section contains executable code.
        CNT_CODE: bool = false,

        /// The section contains initialized data.
        CNT_INITIALIZED_DATA: bool = false,

        /// The section contains uninitialized data.
        CNT_UNINITIALIZED_DATA: bool = false,

        /// Reserved for future use.
        LNK_OTHER: bool = false,

        /// The section contains comments or other information.
        /// The .drectve section has this type.
        /// This is valid for object files only.
        LNK_INFO: bool = false,

        unused10: u1 = 0,

        /// The section will not become part of the image.
        /// This is valid only for object files.
        LNK_REMOVE: bool = false,

        /// The section contains COMDAT data.
        /// For more information, see COMDAT Sections (Object Only).
        /// This is valid only for object files.
        LNK_COMDAT: bool = false,

        unused13: u2 = 0,

        union14: packed union {
            mask: u1,
            /// The section contains data referenced through the global pointer (GP).
            GPREL: bool,
            MEM_FARDATA: bool,
        } = .{ .mask = 0 },

        unused15: u1 = 0,

        union16: packed union {
            mask: u1,
            MEM_PURGEABLE: bool,
            MEM_16BIT: bool,
        } = .{ .mask = 0 },

        /// Reserved for future use.
        MEM_LOCKED: bool = false,

        /// Reserved for future use.
        MEM_PRELOAD: bool = false,

        ALIGN: SectionHeader.Flags.Align = .NONE,

        /// The section contains extended relocations.
        LNK_NRELOC_OVFL: bool = false,

        /// The section can be discarded as needed.
        MEM_DISCARDABLE: bool = false,

        /// The section cannot be cached.
        MEM_NOT_CACHED: bool = false,

        /// The section is not pageable.
        MEM_NOT_PAGED: bool = false,

        /// The section can be shared in memory.
        MEM_SHARED: bool = false,

        /// The section can be executed as code.
        MEM_EXECUTE: bool = false,

        /// The section can be read.
        MEM_READ: bool = false,

        /// The section can be written to.
        MEM_WRITE: bool = false,

        pub const Align = enum(u4) {
            NONE = 0,
            @"1BYTES" = 1,
            @"2BYTES" = 2,
            @"4BYTES" = 3,
            @"8BYTES" = 4,
            @"16BYTES" = 5,
            @"32BYTES" = 6,
            @"64BYTES" = 7,
            @"128BYTES" = 8,
            @"256BYTES" = 9,
            @"512BYTES" = 10,
            @"1024BYTES" = 11,
            @"2048BYTES" = 12,
            @"4096BYTES" = 13,
            @"8192BYTES" = 14,
            _,

            pub fn toByteUnits(a: Align) ?u16 {
                if (a == .NONE) return null;
                return @as(u16, 1) << (@intFromEnum(a) - 1);
            }

            pub fn fromByteUnits(n: u16) Align {
                std.debug.assert(std.math.isPowerOfTwo(n));
                return @enumFromInt(@ctz(n) + 1);
            }
        };
    };
};

pub const Symbol = struct {
    name: [8]u8,
    value: u32,
    section_number: SectionNumber,
    type: SymType,
    storage_class: StorageClass,
    number_of_aux_symbols: u8,

    pub fn sizeOf() usize {
        return 18;
    }

    pub fn getName(self: *const Symbol) ?[]const u8 {
        if (std.mem.eql(u8, self.name[0..4], "\x00\x00\x00\x00")) return null;
        const len = std.mem.indexOfScalar(u8, &self.name, @as(u8, 0)) orelse self.name.len;
        return self.name[0..len];
    }

    pub fn getNameOffset(self: Symbol) ?u32 {
        if (!std.mem.eql(u8, self.name[0..4], "\x00\x00\x00\x00")) return null;
        const offset = std.mem.readInt(u32, self.name[4..8], .little);
        return offset;
    }
};

pub const SectionNumber = enum(u16) {
    /// The symbol record is not yet assigned a section.
    /// A value of zero indicates that a reference to an external symbol is defined elsewhere.
    /// A value of non-zero is a common symbol with a size that is specified by the value.
    UNDEFINED = 0,

    /// The symbol has an absolute (non-relocatable) value and is not an address.
    ABSOLUTE = 0xffff,

    /// The symbol provides general type or debugging information but does not correspond to a section.
    /// Microsoft tools use this setting along with .file records (storage class FILE).
    DEBUG = 0xfffe,
    _,
};

pub const SymType = packed struct(u16) {
    complex_type: ComplexType,
    base_type: BaseType,
};

pub const BaseType = enum(u8) {
    /// No type information or unknown base type. Microsoft tools use this setting
    NULL = 0,

    /// No valid type; used with void pointers and functions
    VOID = 1,

    /// A character (signed byte)
    CHAR = 2,

    /// A 2-byte signed integer
    SHORT = 3,

    /// A natural integer type (normally 4 bytes in Windows)
    INT = 4,

    /// A 4-byte signed integer
    LONG = 5,

    /// A 4-byte floating-point number
    FLOAT = 6,

    /// An 8-byte floating-point number
    DOUBLE = 7,

    /// A structure
    STRUCT = 8,

    /// A union
    UNION = 9,

    /// An enumerated type
    ENUM = 10,

    /// A member of enumeration (a specified value)
    MOE = 11,

    /// A byte; unsigned 1-byte integer
    BYTE = 12,

    /// A word; unsigned 2-byte integer
    WORD = 13,

    /// An unsigned integer of natural size (normally, 4 bytes)
    UINT = 14,

    /// An unsigned 4-byte integer
    DWORD = 15,

    _,
};

pub const ComplexType = enum(u8) {
    /// No derived type; the symbol is a simple scalar variable.
    NULL = 0,

    /// The symbol is a pointer to base type.
    POINTER = 16,

    /// The symbol is a function that returns a base type.
    FUNCTION = 32,

    /// The symbol is an array of base type.
    ARRAY = 48,

    _,
};

pub const StorageClass = enum(u8) {
    /// A special symbol that represents the end of function, for debugging purposes.
    END_OF_FUNCTION = 0xff,

    /// No assigned storage class.
    NULL = 0,

    /// The automatic (stack) variable. The Value field specifies the stack frame offset.
    AUTOMATIC = 1,

    /// A value that Microsoft tools use for external symbols.
    /// The Value field indicates the size if the section number is IMAGE_SYM_UNDEFINED (0).
    /// If the section number is not zero, then the Value field specifies the offset within the section.
    EXTERNAL = 2,

    /// The offset of the symbol within the section.
    /// If the Value field is zero, then the symbol represents a section name.
    STATIC = 3,

    /// A register variable.
    /// The Value field specifies the register number.
    REGISTER = 4,

    /// A symbol that is defined externally.
    EXTERNAL_DEF = 5,

    /// A code label that is defined within the module.
    /// The Value field specifies the offset of the symbol within the section.
    LABEL = 6,

    /// A reference to a code label that is not defined.
    UNDEFINED_LABEL = 7,

    /// The structure member. The Value field specifies the n th member.
    MEMBER_OF_STRUCT = 8,

    /// A formal argument (parameter) of a function. The Value field specifies the n th argument.
    ARGUMENT = 9,

    /// The structure tag-name entry.
    STRUCT_TAG = 10,

    /// A union member. The Value field specifies the n th member.
    MEMBER_OF_UNION = 11,

    /// The Union tag-name entry.
    UNION_TAG = 12,

    /// A Typedef entry.
    TYPE_DEFINITION = 13,

    /// A static data declaration.
    UNDEFINED_STATIC = 14,

    /// An enumerated type tagname entry.
    ENUM_TAG = 15,

    /// A member of an enumeration. The Value field specifies the n th member.
    MEMBER_OF_ENUM = 16,

    /// A register parameter.
    REGISTER_PARAM = 17,

    /// A bit-field reference. The Value field specifies the n th bit in the bit field.
    BIT_FIELD = 18,

    /// A .bb (beginning of block) or .eb (end of block) record.
    /// The Value field is the relocatable address of the code location.
    BLOCK = 100,

    /// A value that Microsoft tools use for symbol records that define the extent of a function: begin function (.bf ), end function ( .ef ), and lines in function ( .lf ).
    /// For .lf records, the Value field gives the number of source lines in the function.
    /// For .ef records, the Value field gives the size of the function code.
    FUNCTION = 101,

    /// An end-of-structure entry.
    END_OF_STRUCT = 102,

    /// A value that Microsoft tools, as well as traditional COFF format, use for the source-file symbol record.
    /// The symbol is followed by auxiliary records that name the file.
    FILE = 103,

    /// A definition of a section (Microsoft tools use STATIC storage class instead).
    SECTION = 104,

    /// A weak external. For more information, see Auxiliary Format 3: Weak Externals.
    WEAK_EXTERNAL = 105,

    /// A CLR token symbol. The name is an ASCII string that consists of the hexadecimal value of the token.
    /// For more information, see CLR Token Definition (Object Only).
    CLR_TOKEN = 107,

    _,
};

pub const FunctionDefinition = struct {
    /// The symbol-table index of the corresponding .bf (begin function) symbol record.
    tag_index: u32,

    /// The size of the executable code for the function itself.
    /// If the function is in its own section, the SizeOfRawData in the section header is greater or equal to this field,
    /// depending on alignment considerations.
    total_size: u32,

    /// The file offset of the first COFF line-number entry for the function, or zero if none exists.
    pointer_to_linenumber: u32,

    /// The symbol-table index of the record for the next function.
    /// If the function is the last in the symbol table, this field is set to zero.
    pointer_to_next_function: u32,

    unused: [2]u8,
};

pub const SectionDefinition = struct {
    /// The size of section data; the same as SizeOfRawData in the section header.
    length: u32,

    /// The number of relocation entries for the section.
    number_of_relocations: u16,

    /// The number of line-number entries for the section.
    number_of_linenumbers: u16,

    /// The checksum for communal data. It is applicable if the IMAGE_SCN_LNK_COMDAT flag is set in the section header.
    checksum: u32,

    /// One-based index into the section table for the associated section. This is used when the COMDAT selection setting is 5.
    number: u16,

    /// The COMDAT selection number. This is applicable if the section is a COMDAT section.
    selection: ComdatSelection,

    unused: [3]u8,
};

pub const FileDefinition = struct {
    /// An ANSI string that gives the name of the source file.
    /// This is padded with nulls if it is less than the maximum length.
    file_name: [18]u8,

    pub fn getFileName(self: *const FileDefinition) []const u8 {
        const len = std.mem.indexOfScalar(u8, &self.file_name, @as(u8, 0)) orelse self.file_name.len;
        return self.file_name[0..len];
    }
};

pub const WeakExternalDefinition = struct {
    /// The symbol-table index of sym2, the symbol to be linked if sym1 is not found.
    tag_index: u32,

    /// A value of IMAGE_WEAK_EXTERN_SEARCH_NOLIBRARY indicates that no library search for sym1 should be performed.
    /// A value of IMAGE_WEAK_EXTERN_SEARCH_LIBRARY indicates that a library search for sym1 should be performed.
    /// A value of IMAGE_WEAK_EXTERN_SEARCH_ALIAS indicates that sym1 is an alias for sym2.
    flag: WeakExternalFlag,

    unused: [10]u8,

    pub fn sizeOf() usize {
        return 18;
    }
};

// https://github.com/tpn/winsdk-10/blob/master/Include/10.0.16299.0/km/ntimage.h
pub const WeakExternalFlag = enum(u32) {
    SEARCH_NOLIBRARY = 1,
    SEARCH_LIBRARY = 2,
    SEARCH_ALIAS = 3,
    ANTI_DEPENDENCY = 4,
    _,
};

pub const ComdatSelection = enum(u8) {
    /// Not a COMDAT section.
    NONE = 0,

    /// If this symbol is already defined, the linker issues a "multiply defined symbol" error.
    NODUPLICATES = 1,

    /// Any section that defines the same COMDAT symbol can be linked; the rest are removed.
    ANY = 2,

    /// The linker chooses an arbitrary section among the definitions for this symbol.
    /// If all definitions are not the same size, a "multiply defined symbol" error is issued.
    SAME_SIZE = 3,

    /// The linker chooses an arbitrary section among the definitions for this symbol.
    /// If all definitions do not match exactly, a "multiply defined symbol" error is issued.
    EXACT_MATCH = 4,

    /// The section is linked if a certain other COMDAT section is linked.
    /// This other section is indicated by the Number field of the auxiliary symbol record for the section definition.
    /// This setting is useful for definitions that have components in multiple sections
    /// (for example, code in one and data in another), but where all must be linked or discarded as a set.
    /// The other section this section is associated with must be a COMDAT section, which can be another
    /// associative COMDAT section. An associative COMDAT section's section association chain can't form a loop.
    /// The section association chain must eventually come to a COMDAT section that doesn't have IMAGE_COMDAT_SELECT_ASSOCIATIVE set.
    ASSOCIATIVE = 5,

    /// The linker chooses the largest definition from among all of the definitions for this symbol.
    /// If multiple definitions have this size, the choice between them is arbitrary.
    LARGEST = 6,

    _,
};

pub const DebugInfoDefinition = struct {
    unused_1: [4]u8,

    /// The actual ordinal line number (1, 2, 3, and so on) within the source file, corresponding to the .bf or .ef record.
    linenumber: u16,

    unused_2: [6]u8,

    /// The symbol-table index of the next .bf symbol record.
    /// If the function is the last in the symbol table, this field is set to zero.
    /// It is not used for .ef records.
    pointer_to_next_function: u32,

    unused_3: [2]u8,
};

pub const Error = error{
    InvalidPEMagic,
    InvalidPEHeader,
    InvalidMachine,
    MissingPEHeader,
    MissingCoffSection,
    MissingStringTable,
};

// Official documentation of the format: https://docs.microsoft.com/en-us/windows/win32/debug/pe-format
pub const Coff = struct {
    data: []const u8,
    // Set if `data` is backed by the image as loaded by the loader
    is_loaded: bool,
    is_image: bool,
    coff_header_offset: usize,

    guid: [16]u8 = undefined,
    age: u32 = undefined,

    // The lifetime of `data` must be longer than the lifetime of the returned Coff
    pub fn init(data: []const u8, is_loaded: bool) error{ EndOfStream, MissingPEHeader }!Coff {
        const pe_pointer_offset = 0x3C;
        const pe_magic = "PE\x00\x00";

        if (data.len < pe_pointer_offset + 4) return error.EndOfStream;
        const header_offset = mem.readInt(u32, data[pe_pointer_offset..][0..4], .little);
        if (data.len < header_offset + 4) return error.EndOfStream;
        const is_image = mem.eql(u8, data[header_offset..][0..4], pe_magic);

        const coff: Coff = .{
            .data = data,
            .is_image = is_image,
            .is_loaded = is_loaded,
            .coff_header_offset = o: {
                if (is_image) break :o header_offset + 4;
                break :o header_offset;
            },
        };

        // Do some basic validation upfront
        if (is_image) {
            const coff_header = coff.getHeader();
            if (coff_header.size_of_optional_header == 0) return error.MissingPEHeader;
        }

        // JK: we used to check for architecture here and throw an error if not x86 or derivative.
        // However I am willing to take a leap of faith and let aarch64 have a shot also.

        return coff;
    }

    pub fn getPdbPath(self: *Coff) !?[]const u8 {
        assert(self.is_image);

        const data_dirs = self.getDataDirectories();
        if (@intFromEnum(DirectoryEntry.DEBUG) >= data_dirs.len) return null;

        const debug_dir = data_dirs[@intFromEnum(DirectoryEntry.DEBUG)];
        var reader: std.Io.Reader = .fixed(self.data);

        if (self.is_loaded) {
            reader.seek = debug_dir.virtual_address;
        } else {
            // Find what section the debug_dir is in, in order to convert the RVA to a file offset
            for (self.getSectionHeaders()) |*sect| {
                if (debug_dir.virtual_address >= sect.virtual_address and debug_dir.virtual_address < sect.virtual_address + sect.virtual_size) {
                    reader.seek = sect.pointer_to_raw_data + (debug_dir.virtual_address - sect.virtual_address);
                    break;
                }
            } else return error.InvalidDebugDirectory;
        }

        // Find the correct DebugDirectoryEntry, and where its data is stored.
        // It can be in any section.
        const debug_dir_entry_count = debug_dir.size / @sizeOf(DebugDirectoryEntry);
        var i: u32 = 0;
        while (i < debug_dir_entry_count) : (i += 1) {
            const debug_dir_entry = try reader.takeStruct(DebugDirectoryEntry, .little);
            if (debug_dir_entry.type == .CODEVIEW) {
                const dir_offset = if (self.is_loaded) debug_dir_entry.address_of_raw_data else debug_dir_entry.pointer_to_raw_data;
                reader.seek = dir_offset;
                break;
            }
        } else return null;

        const code_view_signature = try reader.takeArray(4);
        // 'RSDS' indicates PDB70 format, used by lld.
        if (!mem.eql(u8, code_view_signature, "RSDS"))
            return error.InvalidPEMagic;
        try reader.readSliceAll(self.guid[0..]);
        self.age = try reader.takeInt(u32, .little);

        // Finally read the null-terminated string.
        const start = reader.seek;
        const len = std.mem.indexOfScalar(u8, self.data[start..], 0) orelse return null;
        return self.data[start .. start + len];
    }

    pub fn getHeader(self: Coff) Header {
        return @as(*align(1) const Header, @ptrCast(self.data[self.coff_header_offset..][0..@sizeOf(Header)])).*;
    }

    pub fn getOptionalHeader(self: Coff) OptionalHeader {
        assert(self.is_image);
        const offset = self.coff_header_offset + @sizeOf(Header);
        return @as(*align(1) const OptionalHeader, @ptrCast(self.data[offset..][0..@sizeOf(OptionalHeader)])).*;
    }

    pub fn getOptionalHeader32(self: Coff) OptionalHeader.PE32 {
        assert(self.is_image);
        const offset = self.coff_header_offset + @sizeOf(Header);
        return @as(*align(1) const OptionalHeader.PE32, @ptrCast(self.data[offset..][0..@sizeOf(OptionalHeader.PE32)])).*;
    }

    pub fn getOptionalHeader64(self: Coff) OptionalHeader.@"PE32+" {
        assert(self.is_image);
        const offset = self.coff_header_offset + @sizeOf(Header);
        return @as(*align(1) const OptionalHeader.@"PE32+", @ptrCast(self.data[offset..][0..@sizeOf(OptionalHeader.@"PE32+")])).*;
    }

    pub fn getImageBase(self: Coff) u64 {
        const hdr = self.getOptionalHeader();
        return switch (@intFromEnum(hdr.magic)) {
            IMAGE_NT_OPTIONAL_HDR32_MAGIC => self.getOptionalHeader32().image_base,
            IMAGE_NT_OPTIONAL_HDR64_MAGIC => self.getOptionalHeader64().image_base,
            else => unreachable, // We assume we have validated the header already
        };
    }

    pub fn getNumberOfDataDirectories(self: Coff) u32 {
        const hdr = self.getOptionalHeader();
        return switch (@intFromEnum(hdr.magic)) {
            IMAGE_NT_OPTIONAL_HDR32_MAGIC => self.getOptionalHeader32().number_of_rva_and_sizes,
            IMAGE_NT_OPTIONAL_HDR64_MAGIC => self.getOptionalHeader64().number_of_rva_and_sizes,
            else => unreachable, // We assume we have validated the header already
        };
    }

    pub fn getDataDirectories(self: *const Coff) []align(1) const ImageDataDirectory {
        const hdr = self.getOptionalHeader();
        const size: usize = switch (@intFromEnum(hdr.magic)) {
            IMAGE_NT_OPTIONAL_HDR32_MAGIC => @sizeOf(OptionalHeader.PE32),
            IMAGE_NT_OPTIONAL_HDR64_MAGIC => @sizeOf(OptionalHeader.@"PE32+"),
            else => unreachable, // We assume we have validated the header already
        };
        const offset = self.coff_header_offset + @sizeOf(Header) + size;
        return @as([*]align(1) const ImageDataDirectory, @ptrCast(self.data[offset..]))[0..self.getNumberOfDataDirectories()];
    }

    pub fn getSymtab(self: *const Coff) ?Symtab {
        const coff_header = self.getHeader();
        if (coff_header.pointer_to_symbol_table == 0) return null;

        const offset = coff_header.pointer_to_symbol_table;
        const size = coff_header.number_of_symbols * Symbol.sizeOf();
        return .{ .buffer = self.data[offset..][0..size] };
    }

    pub fn getStrtab(self: *const Coff) error{InvalidStrtabSize}!?Strtab {
        const coff_header = self.getHeader();
        if (coff_header.pointer_to_symbol_table == 0) return null;

        const offset = coff_header.pointer_to_symbol_table + Symbol.sizeOf() * coff_header.number_of_symbols;
        const size = mem.readInt(u32, self.data[offset..][0..4], .little);
        if ((offset + size) > self.data.len) return error.InvalidStrtabSize;

        return Strtab{ .buffer = self.data[offset..][0..size] };
    }

    pub fn strtabRequired(self: *const Coff) bool {
        for (self.getSectionHeaders()) |*sect_hdr| if (sect_hdr.getName() == null) return true;
        return false;
    }

    pub fn getSectionHeaders(self: *const Coff) []align(1) const SectionHeader {
        const coff_header = self.getHeader();
        const offset = self.coff_header_offset + @sizeOf(Header) + coff_header.size_of_optional_header;
        return @as([*]align(1) const SectionHeader, @ptrCast(self.data.ptr + offset))[0..coff_header.number_of_sections];
    }

    pub fn getSectionHeadersAlloc(self: *const Coff, allocator: mem.Allocator) ![]SectionHeader {
        const section_headers = self.getSectionHeaders();
        const out_buff = try allocator.alloc(SectionHeader, section_headers.len);
        for (out_buff, 0..) |*section_header, i| {
            section_header.* = section_headers[i];
        }

        return out_buff;
    }

    pub fn getSectionName(self: *const Coff, sect_hdr: *align(1) const SectionHeader) error{InvalidStrtabSize}![]const u8 {
        const name = sect_hdr.getName() orelse blk: {
            const strtab = (try self.getStrtab()).?;
            const name_offset = sect_hdr.getNameOffset().?;
            break :blk strtab.get(name_offset);
        };
        return name;
    }

    pub fn getSectionByName(self: *const Coff, comptime name: []const u8) ?*align(1) const SectionHeader {
        for (self.getSectionHeaders()) |*sect| {
            const section_name = self.getSectionName(sect) catch |e| switch (e) {
                error.InvalidStrtabSize => continue, //ignore invalid(?) strtab entries - see also GitHub issue #15238
            };
            if (mem.eql(u8, section_name, name)) {
                return sect;
            }
        }
        return null;
    }

    pub fn getSectionData(self: *const Coff, sec: *align(1) const SectionHeader) []const u8 {
        const offset = if (self.is_loaded) sec.virtual_address else sec.pointer_to_raw_data;
        return self.data[offset..][0..sec.virtual_size];
    }

    pub fn getSectionDataAlloc(self: *const Coff, sec: *align(1) const SectionHeader, allocator: mem.Allocator) ![]u8 {
        const section_data = self.getSectionData(sec);
        return allocator.dupe(u8, section_data);
    }
};

pub const Symtab = struct {
    buffer: []const u8,

    pub fn len(self: Symtab) usize {
        return @divExact(self.buffer.len, Symbol.sizeOf());
    }

    pub const Tag = enum {
        symbol,
        debug_info,
        func_def,
        weak_ext,
        file_def,
        sect_def,
    };

    pub const Record = union(Tag) {
        symbol: Symbol,
        debug_info: DebugInfoDefinition,
        func_def: FunctionDefinition,
        weak_ext: WeakExternalDefinition,
        file_def: FileDefinition,
        sect_def: SectionDefinition,
    };

    /// Lives as long as Symtab instance.
    pub fn at(self: Symtab, index: usize, tag: Tag) Record {
        const offset = index * Symbol.sizeOf();
        const raw = self.buffer[offset..][0..Symbol.sizeOf()];
        return switch (tag) {
            .symbol => .{ .symbol = asSymbol(raw) },
            .debug_info => .{ .debug_info = asDebugInfo(raw) },
            .func_def => .{ .func_def = asFuncDef(raw) },
            .weak_ext => .{ .weak_ext = asWeakExtDef(raw) },
            .file_def => .{ .file_def = asFileDef(raw) },
            .sect_def => .{ .sect_def = asSectDef(raw) },
        };
    }

    fn asSymbol(raw: []const u8) Symbol {
        return .{
            .name = raw[0..8].*,
            .value = mem.readInt(u32, raw[8..12], .little),
            .section_number = @as(SectionNumber, @enumFromInt(mem.readInt(u16, raw[12..14], .little))),
            .type = @as(SymType, @bitCast(mem.readInt(u16, raw[14..16], .little))),
            .storage_class = @as(StorageClass, @enumFromInt(raw[16])),
            .number_of_aux_symbols = raw[17],
        };
    }

    fn asDebugInfo(raw: []const u8) DebugInfoDefinition {
        return .{
            .unused_1 = raw[0..4].*,
            .linenumber = mem.readInt(u16, raw[4..6], .little),
            .unused_2 = raw[6..12].*,
            .pointer_to_next_function = mem.readInt(u32, raw[12..16], .little),
            .unused_3 = raw[16..18].*,
        };
    }

    fn asFuncDef(raw: []const u8) FunctionDefinition {
        return .{
            .tag_index = mem.readInt(u32, raw[0..4], .little),
            .total_size = mem.readInt(u32, raw[4..8], .little),
            .pointer_to_linenumber = mem.readInt(u32, raw[8..12], .little),
            .pointer_to_next_function = mem.readInt(u32, raw[12..16], .little),
            .unused = raw[16..18].*,
        };
    }

    fn asWeakExtDef(raw: []const u8) WeakExternalDefinition {
        return .{
            .tag_index = mem.readInt(u32, raw[0..4], .little),
            .flag = @as(WeakExternalFlag, @enumFromInt(mem.readInt(u32, raw[4..8], .little))),
            .unused = raw[8..18].*,
        };
    }

    fn asFileDef(raw: []const u8) FileDefinition {
        return .{
            .file_name = raw[0..18].*,
        };
    }

    fn asSectDef(raw: []const u8) SectionDefinition {
        return .{
            .length = mem.readInt(u32, raw[0..4], .little),
            .number_of_relocations = mem.readInt(u16, raw[4..6], .little),
            .number_of_linenumbers = mem.readInt(u16, raw[6..8], .little),
            .checksum = mem.readInt(u32, raw[8..12], .little),
            .number = mem.readInt(u16, raw[12..14], .little),
            .selection = @as(ComdatSelection, @enumFromInt(raw[14])),
            .unused = raw[15..18].*,
        };
    }

    pub const Slice = struct {
        buffer: []const u8,
        num: usize,
        count: usize = 0,

        /// Lives as long as Symtab instance.
        pub fn next(self: *Slice) ?Symbol {
            if (self.count >= self.num) return null;
            const sym = asSymbol(self.buffer[0..Symbol.sizeOf()]);
            self.count += 1;
            self.buffer = self.buffer[Symbol.sizeOf()..];
            return sym;
        }
    };

    pub fn slice(self: Symtab, start: usize, end: ?usize) Slice {
        const offset = start * Symbol.sizeOf();
        const llen = if (end) |e| e * Symbol.sizeOf() else self.buffer.len;
        const num = @divExact(llen - offset, Symbol.sizeOf());
        return Slice{ .buffer = self.buffer[offset..][0..llen], .num = num };
    }
};

pub const Strtab = struct {
    buffer: []const u8,

    pub fn get(self: Strtab, off: u32) []const u8 {
        assert(off < self.buffer.len);
        return mem.sliceTo(@as([*:0]const u8, @ptrCast(self.buffer.ptr + off)), 0);
    }
};

pub const ImportHeader = extern struct {
    /// Must be IMAGE_FILE_MACHINE_UNKNOWN
    sig1: IMAGE.FILE.MACHINE = .UNKNOWN,
    /// Must be 0xFFFF
    sig2: u16 = 0xFFFF,
    version: u16,
    machine: IMAGE.FILE.MACHINE,
    time_date_stamp: u32,
    size_of_data: u32,
    hint: u16,
    types: packed struct(u16) {
        type: ImportType,
        name_type: ImportNameType,
        reserved: u11,
    },
};

pub const ImportType = enum(u2) {
    /// Executable code.
    CODE = 0,
    /// Data.
    DATA = 1,
    /// Specified as CONST in .def file.
    CONST = 2,
    _,
};

pub const ImportNameType = enum(u3) {
    /// The import is by ordinal. This indicates that the value in the Ordinal/Hint
    /// field of the import header is the import's ordinal. If this constant is not
    /// specified, then the Ordinal/Hint field should always be interpreted as the import's hint.
    ORDINAL = 0,
    /// The import name is identical to the public symbol name.
    NAME = 1,
    /// The import name is the public symbol name, but skipping the leading ?, @, or optionally _.
    NAME_NOPREFIX = 2,
    /// The import name is the public symbol name, but skipping the leading ?, @, or optionally _,
    /// and truncating at the first @.
    NAME_UNDECORATE = 3,
    /// https://github.com/llvm/llvm-project/pull/83211
    NAME_EXPORTAS = 4,
    _,
};

pub const Relocation = extern struct {
    virtual_address: u32,
    symbol_table_index: u32,
    type: u16,
};

pub const IMAGE = struct {
    pub const FILE = struct {
        /// Machine Types
        /// The Machine field has one of the following values, which specify the CPU type.
        /// An image file can be run only on the specified machine or on a system that emulates the specified machine.
        pub const MACHINE = enum(u16) {
            /// The content of this field is assumed to be applicable to any machine type
            UNKNOWN = 0x0,
            /// Alpha AXP, 32-bit address space
            ALPHA = 0x184,
            /// Alpha 64, 64-bit address space
            ALPHA64 = 0x284,
            /// Matsushita AM33
            AM33 = 0x1d3,
            /// x64
            AMD64 = 0x8664,
            /// ARM little endian
            ARM = 0x1c0,
            /// ARM64 little endian
            ARM64 = 0xaa64,
            /// ABI that enables interoperability between native ARM64 and emulated x64 code.
            ARM64EC = 0xA641,
            /// Binary format that allows both native ARM64 and ARM64EC code to coexist in the same file.
            ARM64X = 0xA64E,
            /// ARM Thumb-2 little endian
            ARMNT = 0x1c4,
            /// EFI byte code
            EBC = 0xebc,
            /// Intel 386 or later processors and compatible processors
            I386 = 0x14c,
            /// Intel Itanium processor family
            IA64 = 0x200,
            /// LoongArch 32-bit processor family
            LOONGARCH32 = 0x6232,
            /// LoongArch 64-bit processor family
            LOONGARCH64 = 0x6264,
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
            /// MIPS I compatible 32-bit big endian
            R3000BE = 0x160,
            /// MIPS I compatible 32-bit little endian
            R3000 = 0x162,
            /// MIPS III compatible 64-bit little endian
            R4000 = 0x166,
            /// MIPS IV compatible 64-bit little endian
            R10000 = 0x168,
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
            THUMB = 0x1c2,
            /// MIPS little-endian WCE v2
            WCEMIPSV2 = 0x169,
            _,
            /// AXP 64 (Same as Alpha 64)
            pub const AXP64: IMAGE.FILE.MACHINE = .ALPHA64;
        };
    };

    pub const REL = struct {
        /// x64 Processors
        /// The following relocation type indicators are defined for x64 and compatible processors.
        pub const AMD64 = enum(u16) {
            /// The relocation is ignored.
            ABSOLUTE = 0x0000,
            /// The 64-bit VA of the relocation target.
            ADDR64 = 0x0001,
            /// The 32-bit VA of the relocation target.
            ADDR32 = 0x0002,
            /// The 32-bit address without an image base (RVA).
            ADDR32NB = 0x0003,
            /// The 32-bit relative address from the byte following the relocation.
            REL32 = 0x0004,
            /// The 32-bit address relative to byte distance 1 from the relocation.
            REL32_1 = 0x0005,
            /// The 32-bit address relative to byte distance 2 from the relocation.
            REL32_2 = 0x0006,
            /// The 32-bit address relative to byte distance 3 from the relocation.
            REL32_3 = 0x0007,
            /// The 32-bit address relative to byte distance 4 from the relocation.
            REL32_4 = 0x0008,
            /// The 32-bit address relative to byte distance 5 from the relocation.
            REL32_5 = 0x0009,
            /// The 16-bit section index of the section that contains the target.
            /// This is used to support debugging information.
            SECTION = 0x000A,
            /// The 32-bit offset of the target from the beginning of its section.
            /// This is used to support debugging information and static thread local storage.
            SECREL = 0x000B,
            /// A 7-bit unsigned offset from the base of the section that contains the target.
            SECREL7 = 0x000C,
            /// CLR tokens.
            TOKEN = 0x000D,
            /// A 32-bit signed span-dependent value emitted into the object.
            SREL32 = 0x000E,
            /// A pair that must immediately follow every span-dependent value.
            PAIR = 0x000F,
            /// A 32-bit signed span-dependent value that is applied at link time.
            SSPAN32 = 0x0010,
            _,
        };

        /// ARM Processors
        /// The following relocation type indicators are defined for ARM processors.
        pub const ARM = enum(u16) {
            /// The relocation is ignored.
            ABSOLUTE = 0x0000,
            /// The 32-bit VA of the target.
            ADDR32 = 0x0001,
            /// The 32-bit RVA of the target.
            ADDR32NB = 0x0002,
            /// The 24-bit relative displacement to the target.
            BRANCH24 = 0x0003,
            /// The reference to a subroutine call.
            /// The reference consists of two 16-bit instructions with 11-bit offsets.
            BRANCH11 = 0x0004,
            /// The 32-bit relative address from the byte following the relocation.
            REL32 = 0x000A,
            /// The 16-bit section index of the section that contains the target.
            /// This is used to support debugging information.
            SECTION = 0x000E,
            /// The 32-bit offset of the target from the beginning of its section.
            /// This is used to support debugging information and static thread local storage.
            SECREL = 0x000F,
            /// The 32-bit VA of the target.
            /// This relocation is applied using a MOVW instruction for the low 16 bits followed by a MOVT for the high 16 bits.
            MOV32 = 0x0010,
            /// The 32-bit VA of the target.
            /// This relocation is applied using a MOVW instruction for the low 16 bits followed by a MOVT for the high 16 bits.
            THUMB_MOV32 = 0x0011,
            /// The instruction is fixed up with the 21-bit relative displacement to the 2-byte aligned target.
            /// The least significant bit of the displacement is always zero and is not stored.
            /// This relocation corresponds to a Thumb-2 32-bit conditional B instruction.
            THUMB_BRANCH20 = 0x0012,
            Unused = 0x0013,
            /// The instruction is fixed up with the 25-bit relative displacement to the 2-byte aligned target.
            /// The least significant bit of the displacement is zero and is not stored.This relocation corresponds to a Thumb-2 B instruction.
            THUMB_BRANCH24 = 0x0014,
            /// The instruction is fixed up with the 25-bit relative displacement to the 4-byte aligned target.
            /// The low 2 bits of the displacement are zero and are not stored.
            /// This relocation corresponds to a Thumb-2 BLX instruction.
            THUMB_BLX23 = 0x0015,
            /// The relocation is valid only when it immediately follows a ARM_REFHI or THUMB_REFHI.
            /// Its SymbolTableIndex contains a displacement and not an index into the symbol table.
            PAIR = 0x0016,
            _,
        };

        /// ARM64 Processors
        /// The following relocation type indicators are defined for ARM64 processors.
        pub const ARM64 = enum(u16) {
            /// The relocation is ignored.
            ABSOLUTE = 0x0000,
            /// The 32-bit VA of the target.
            ADDR32 = 0x0001,
            /// The 32-bit RVA of the target.
            ADDR32NB = 0x0002,
            /// The 26-bit relative displacement to the target, for B and BL instructions.
            BRANCH26 = 0x0003,
            /// The page base of the target, for ADRP instruction.
            PAGEBASE_REL21 = 0x0004,
            /// The 12-bit relative displacement to the target, for instruction ADR
            REL21 = 0x0005,
            /// The 12-bit page offset of the target, for instructions ADD/ADDS (immediate) with zero shift.
            PAGEOFFSET_12A = 0x0006,
            /// The 12-bit page offset of the target, for instruction LDR (indexed, unsigned immediate).
            PAGEOFFSET_12L = 0x0007,
            /// The 32-bit offset of the target from the beginning of its section.
            /// This is used to support debugging information and static thread local storage.
            SECREL = 0x0008,
            /// Bit 0:11 of section offset of the target, for instructions ADD/ADDS (immediate) with zero shift.
            SECREL_LOW12A = 0x0009,
            /// Bit 12:23 of section offset of the target, for instructions ADD/ADDS (immediate) with zero shift.
            SECREL_HIGH12A = 0x000A,
            /// Bit 0:11 of section offset of the target, for instruction LDR (indexed, unsigned immediate).
            SECREL_LOW12L = 0x000B,
            /// CLR token.
            TOKEN = 0x000C,
            /// The 16-bit section index of the section that contains the target.
            /// This is used to support debugging information.
            SECTION = 0x000D,
            /// The 64-bit VA of the relocation target.
            ADDR64 = 0x000E,
            /// The 19-bit offset to the relocation target, for conditional B instruction.
            BRANCH19 = 0x000F,
            /// The 14-bit offset to the relocation target, for instructions TBZ and TBNZ.
            BRANCH14 = 0x0010,
            /// The 32-bit relative address from the byte following the relocation.
            REL32 = 0x0011,
            _,
        };

        /// Hitachi SuperH Processors
        /// The following relocation type indicators are defined for SH3 and SH4 processors.
        /// SH5-specific relocations are noted as SHM (SH Media).
        pub const SH = enum(u16) {
            /// The relocation is ignored.
            @"3_ABSOLUTE" = 0x0000,
            /// A reference to the 16-bit location that contains the VA of the target symbol.
            @"3_DIRECT16" = 0x0001,
            /// The 32-bit VA of the target symbol.
            @"3_DIRECT32" = 0x0002,
            /// A reference to the 8-bit location that contains the VA of the target symbol.
            @"3_DIRECT8" = 0x0003,
            /// A reference to the 8-bit instruction that contains the effective 16-bit VA of the target symbol.
            @"3_DIRECT8_WORD" = 0x0004,
            /// A reference to the 8-bit instruction that contains the effective 32-bit VA of the target symbol.
            @"3_DIRECT8_LONG" = 0x0005,
            /// A reference to the 8-bit location whose low 4 bits contain the VA of the target symbol.
            @"3_DIRECT4" = 0x0006,
            /// A reference to the 8-bit instruction whose low 4 bits contain the effective 16-bit VA of the target symbol.
            @"3_DIRECT4_WORD" = 0x0007,
            /// A reference to the 8-bit instruction whose low 4 bits contain the effective 32-bit VA of the target symbol.
            @"3_DIRECT4_LONG" = 0x0008,
            /// A reference to the 8-bit instruction that contains the effective 16-bit relative offset of the target symbol.
            @"3_PCREL8_WORD" = 0x0009,
            /// A reference to the 8-bit instruction that contains the effective 32-bit relative offset of the target symbol.
            @"3_PCREL8_LONG" = 0x000A,
            /// A reference to the 16-bit instruction whose low 12 bits contain the effective 16-bit relative offset of the target symbol.
            @"3_PCREL12_WORD" = 0x000B,
            /// A reference to a 32-bit location that is the VA of the section that contains the target symbol.
            @"3_STARTOF_SECTION" = 0x000C,
            /// A reference to the 32-bit location that is the size of the section that contains the target symbol.
            @"3_SIZEOF_SECTION" = 0x000D,
            /// The 16-bit section index of the section that contains the target.
            /// This is used to support debugging information.
            @"3_SECTION" = 0x000E,
            /// The 32-bit offset of the target from the beginning of its section.
            /// This is used to support debugging information and static thread local storage.
            @"3_SECREL" = 0x000F,
            /// The 32-bit RVA of the target symbol.
            @"3_DIRECT32_NB" = 0x0010,
            /// GP relative.
            @"3_GPREL4_LONG" = 0x0011,
            /// CLR token.
            @"3_TOKEN" = 0x0012,
            /// The offset from the current instruction in longwords.
            /// If the NOMODE bit is not set, insert the inverse of the low bit at bit 32 to select PTA or PTB.
            M_PCRELPT = 0x0013,
            /// The low 16 bits of the 32-bit address.
            M_REFLO = 0x0014,
            /// The high 16 bits of the 32-bit address.
            M_REFHALF = 0x0015,
            /// The low 16 bits of the relative address.
            M_RELLO = 0x0016,
            /// The high 16 bits of the relative address.
            M_RELHALF = 0x0017,
            /// The relocation is valid only when it immediately follows a REFHALF, RELHALF, or RELLO relocation.
            /// The SymbolTableIndex field of the relocation contains a displacement and not an index into the symbol table.
            M_PAIR = 0x0018,
            /// The relocation ignores section mode.
            M_NOMODE = 0x8000,
            _,
        };

        /// IBM PowerPC Processors
        /// The following relocation type indicators are defined for PowerPC processors.
        pub const PPC = enum(u16) {
            /// The relocation is ignored.
            ABSOLUTE = 0x0000,
            /// The 64-bit VA of the target.
            ADDR64 = 0x0001,
            /// The 32-bit VA of the target.
            ADDR32 = 0x0002,
            /// The low 24 bits of the VA of the target.
            /// This is valid only when the target symbol is absolute and can be sign-extended to its original value.
            ADDR24 = 0x0003,
            /// The low 16 bits of the target's VA.
            ADDR16 = 0x0004,
            /// The low 14 bits of the target's VA.
            /// This is valid only when the target symbol is absolute and can be sign-extended to its original value.
            ADDR14 = 0x0005,
            /// A 24-bit PC-relative offset to the symbol's location.
            REL24 = 0x0006,
            /// A 14-bit PC-relative offset to the symbol's location.
            REL14 = 0x0007,
            /// The 32-bit RVA of the target.
            ADDR32NB = 0x000A,
            /// The 32-bit offset of the target from the beginning of its section.
            /// This is used to support debugging information and static thread local storage.
            SECREL = 0x000B,
            /// The 16-bit section index of the section that contains the target.
            /// This is used to support debugging information.
            SECTION = 0x000C,
            /// The 16-bit offset of the target from the beginning of its section.
            /// This is used to support debugging information and static thread local storage.
            SECREL16 = 0x000F,
            /// The high 16 bits of the target's 32-bit VA.
            /// This is used for the first instruction in a two-instruction sequence that loads a full address.
            /// This relocation must be immediately followed by a PAIR relocation whose SymbolTableIndex contains a signed 16-bit displacement that is added to the upper 16 bits that was taken from the location that is being relocated.
            REFHI = 0x0010,
            /// The low 16 bits of the target's VA.
            REFLO = 0x0011,
            /// A relocation that is valid only when it immediately follows a REFHI or SECRELHI relocation.
            /// Its SymbolTableIndex contains a displacement and not an index into the symbol table.
            PAIR = 0x0012,
            /// The low 16 bits of the 32-bit offset of the target from the beginning of its section.
            SECRELLO = 0x0013,
            /// The 16-bit signed displacement of the target relative to the GP register.
            GPREL = 0x0015,
            /// The CLR token.
            TOKEN = 0x0016,
            _,
        };

        /// Intel 386 Processors
        /// The following relocation type indicators are defined for Intel 386 and compatible processors.
        pub const I386 = enum(u16) {
            /// The relocation is ignored.
            ABSOLUTE = 0x0000,
            /// Not supported.
            DIR16 = 0x0001,
            /// Not supported.
            REL16 = 0x0002,
            /// The target's 32-bit VA.
            DIR32 = 0x0006,
            /// The target's 32-bit RVA.
            DIR32NB = 0x0007,
            /// Not supported.
            SEG12 = 0x0009,
            /// The 16-bit section index of the section that contains the target.
            /// This is used to support debugging information.
            SECTION = 0x000A,
            /// The 32-bit offset of the target from the beginning of its section.
            /// This is used to support debugging information and static thread local storage.
            SECREL = 0x000B,
            /// The CLR token.
            TOKEN = 0x000C,
            /// A 7-bit offset from the base of the section that contains the target.
            SECREL7 = 0x000D,
            /// The 32-bit relative displacement to the target.
            /// This supports the x86 relative branch and call instructions.
            REL32 = 0x0014,
            _,
        };

        /// Intel Itanium Processor Family (IPF)
        /// The following relocation type indicators are defined for the Intel Itanium processor family and compatible processors.
        /// Note that relocations on instructions use the bundle's offset and slot number for the relocation offset.
        pub const IA64 = enum(u16) {
            /// The relocation is ignored.
            ABSOLUTE = 0x0000,
            /// The instruction relocation can be followed by an ADDEND relocation whose value is added to the target address before it is inserted into the specified slot in the IMM14 bundle.
            /// The relocation target must be absolute or the image must be fixed.
            IMM14 = 0x0001,
            /// The instruction relocation can be followed by an ADDEND relocation whose value is added to the target address before it is inserted into the specified slot in the IMM22 bundle.
            /// The relocation target must be absolute or the image must be fixed.
            IMM22 = 0x0002,
            /// The slot number of this relocation must be one (1).
            /// The relocation can be followed by an ADDEND relocation whose value is added to the target address before it is stored in all three slots of the IMM64 bundle.
            IMM64 = 0x0003,
            /// The target's 32-bit VA.
            /// This is supported only for /LARGEADDRESSAWARE:NO images.
            DIR32 = 0x0004,
            /// The target's 64-bit VA.
            DIR64 = 0x0005,
            /// The instruction is fixed up with the 25-bit relative displacement to the 16-bit aligned target.
            /// The low 4 bits of the displacement are zero and are not stored.
            PCREL21B = 0x0006,
            /// The instruction is fixed up with the 25-bit relative displacement to the 16-bit aligned target.
            /// The low 4 bits of the displacement, which are zero, are not stored.
            PCREL21M = 0x0007,
            /// The LSBs of this relocation's offset must contain the slot number whereas the rest is the bundle address.
            /// The bundle is fixed up with the 25-bit relative displacement to the 16-bit aligned target.
            /// The low 4 bits of the displacement are zero and are not stored.
            PCREL21F = 0x0008,
            /// The instruction relocation can be followed by an ADDEND relocation whose value is added to the target address and then a 22-bit GP-relative offset that is calculated and applied to the GPREL22 bundle.
            GPREL22 = 0x0009,
            /// The instruction is fixed up with the 22-bit GP-relative offset to the target symbol's literal table entry.
            /// The linker creates this literal table entry based on this relocation and the ADDEND relocation that might follow.
            LTOFF22 = 0x000A,
            /// The 16-bit section index of the section contains the target.
            /// This is used to support debugging information.
            SECTION = 0x000B,
            /// The instruction is fixed up with the 22-bit offset of the target from the beginning of its section.
            /// This relocation can be followed immediately by an ADDEND relocation, whose Value field contains the 32-bit unsigned offset of the target from the beginning of the section.
            SECREL22 = 0x000C,
            /// The slot number for this relocation must be one (1).
            /// The instruction is fixed up with the 64-bit offset of the target from the beginning of its section.
            /// This relocation can be followed immediately by an ADDEND relocation whose Value field contains the 32-bit unsigned offset of the target from the beginning of the section.
            SECREL64I = 0x000D,
            /// The address of data to be fixed up with the 32-bit offset of the target from the beginning of its section.
            SECREL32 = 0x000E,
            /// The target's 32-bit RVA.
            DIR32NB = 0x0010,
            /// This is applied to a signed 14-bit immediate that contains the difference between two relocatable targets.
            /// This is a declarative field for the linker that indicates that the compiler has already emitted this value.
            SREL14 = 0x0011,
            /// This is applied to a signed 22-bit immediate that contains the difference between two relocatable targets.
            /// This is a declarative field for the linker that indicates that the compiler has already emitted this value.
            SREL22 = 0x0012,
            /// This is applied to a signed 32-bit immediate that contains the difference between two relocatable values.
            /// This is a declarative field for the linker that indicates that the compiler has already emitted this value.
            SREL32 = 0x0013,
            /// This is applied to an unsigned 32-bit immediate that contains the difference between two relocatable values.
            /// This is a declarative field for the linker that indicates that the compiler has already emitted this value.
            UREL32 = 0x0014,
            /// A 60-bit PC-relative fixup that always stays as a BRL instruction of an MLX bundle.
            PCREL60X = 0x0015,
            /// A 60-bit PC-relative fixup.
            /// If the target displacement fits in a signed 25-bit field, convert the entire bundle to an MBB bundle with NOP.B in slot 1 and a 25-bit BR instruction (with the 4 lowest bits all zero and dropped) in slot 2.
            PCREL60B = 0x0016,
            /// A 60-bit PC-relative fixup.
            /// If the target displacement fits in a signed 25-bit field, convert the entire bundle to an MFB bundle with NOP.F in slot 1 and a 25-bit (4 lowest bits all zero and dropped) BR instruction in slot 2.
            PCREL60F = 0x0017,
            /// A 60-bit PC-relative fixup.
            /// If the target displacement fits in a signed 25-bit field, convert the entire bundle to an MIB bundle with NOP.I in slot 1 and a 25-bit (4 lowest bits all zero and dropped) BR instruction in slot 2.
            PCREL60I = 0x0018,
            /// A 60-bit PC-relative fixup.
            /// If the target displacement fits in a signed 25-bit field, convert the entire bundle to an MMB bundle with NOP.M in slot 1 and a 25-bit (4 lowest bits all zero and dropped) BR instruction in slot 2.
            PCREL60M = 0x0019,
            /// A 64-bit GP-relative fixup.
            IMMGPREL64 = 0x001a,
            /// A CLR token.
            TOKEN = 0x001b,
            /// A 32-bit GP-relative fixup.
            GPREL32 = 0x001c,
            /// The relocation is valid only when it immediately follows one of the following relocations: IMM14, IMM22, IMM64, GPREL22, LTOFF22, LTOFF64, SECREL22, SECREL64I, or SECREL32.
            /// Its value contains the addend to apply to instructions within a bundle, not for data.
            ADDEND = 0x001F,
            _,
        };

        /// MIPS Processors
        /// The following relocation type indicators are defined for MIPS processors.
        pub const MIPS = enum(u16) {
            /// The relocation is ignored.
            ABSOLUTE = 0x0000,
            /// The high 16 bits of the target's 32-bit VA.
            REFHALF = 0x0001,
            /// The target's 32-bit VA.
            REFWORD = 0x0002,
            /// The low 26 bits of the target's VA.
            /// This supports the MIPS J and JAL instructions.
            JMPADDR = 0x0003,
            /// The high 16 bits of the target's 32-bit VA.
            /// This is used for the first instruction in a two-instruction sequence that loads a full address.
            /// This relocation must be immediately followed by a PAIR relocation whose SymbolTableIndex contains a signed 16-bit displacement that is added to the upper 16 bits that are taken from the location that is being relocated.
            REFHI = 0x0004,
            /// The low 16 bits of the target's VA.
            REFLO = 0x0005,
            /// A 16-bit signed displacement of the target relative to the GP register.
            GPREL = 0x0006,
            /// The same as IMAGE_REL_MIPS_GPREL.
            LITERAL = 0x0007,
            /// The 16-bit section index of the section contains the target.
            /// This is used to support debugging information.
            SECTION = 0x000A,
            /// The 32-bit offset of the target from the beginning of its section.
            /// This is used to support debugging information and static thread local storage.
            SECREL = 0x000B,
            /// The low 16 bits of the 32-bit offset of the target from the beginning of its section.
            SECRELLO = 0x000C,
            /// The high 16 bits of the 32-bit offset of the target from the beginning of its section.
            /// An IMAGE_REL_MIPS_PAIR relocation must immediately follow this one.
            /// The SymbolTableIndex of the PAIR relocation contains a signed 16-bit displacement that is added to the upper 16 bits that are taken from the location that is being relocated.
            SECRELHI = 0x000D,
            /// The low 26 bits of the target's VA.
            /// This supports the MIPS16 JAL instruction.
            JMPADDR16 = 0x0010,
            /// The target's 32-bit RVA.
            REFWORDNB = 0x0022,
            /// The relocation is valid only when it immediately follows a REFHI or SECRELHI relocation.
            /// Its SymbolTableIndex contains a displacement and not an index into the symbol table.
            PAIR = 0x0025,
            _,
        };

        /// Mitsubishi M32R
        /// The following relocation type indicators are defined for the Mitsubishi M32R processors.
        pub const M32R = enum(u16) {
            /// The relocation is ignored.
            ABSOLUTE = 0x0000,
            /// The target's 32-bit VA.
            ADDR32 = 0x0001,
            /// The target's 32-bit RVA.
            ADDR32NB = 0x0002,
            /// The target's 24-bit VA.
            ADDR24 = 0x0003,
            /// The target's 16-bit offset from the GP register.
            GPREL16 = 0x0004,
            /// The target's 24-bit offset from the program counter (PC), shifted left by 2 bits and sign-extended
            PCREL24 = 0x0005,
            /// The target's 16-bit offset from the PC, shifted left by 2 bits and sign-extended
            PCREL16 = 0x0006,
            /// The target's 8-bit offset from the PC, shifted left by 2 bits and sign-extended
            PCREL8 = 0x0007,
            /// The 16 MSBs of the target VA.
            REFHALF = 0x0008,
            /// The 16 MSBs of the target VA, adjusted for LSB sign extension.
            /// This is used for the first instruction in a two-instruction sequence that loads a full 32-bit address.
            /// This relocation must be immediately followed by a PAIR relocation whose SymbolTableIndex contains a signed 16-bit displacement that is added to the upper 16 bits that are taken from the location that is being relocated.
            REFHI = 0x0009,
            /// The 16 LSBs of the target VA.
            REFLO = 0x000A,
            /// The relocation must follow the REFHI relocation.
            /// Its SymbolTableIndex contains a displacement and not an index into the symbol table.
            PAIR = 0x000B,
            /// The 16-bit section index of the section that contains the target.
            /// This is used to support debugging information.
            SECTION = 0x000C,
            /// The 32-bit offset of the target from the beginning of its section.
            /// This is used to support debugging information and static thread local storage.
            SECREL = 0x000D,
            /// The CLR token.
            TOKEN = 0x000E,
            _,
        };
    };
};
