const std = @import("std.zig");
const assert = std.debug.assert;
const io = std.io;
const mem = std.mem;
const os = std.os;
const fs = std.fs;

pub const CoffHeaderFlags = packed struct {
    /// Image only, Windows CE, and Microsoft Windows NT and later.
    /// This indicates that the file does not contain base relocations
    /// and must therefore be loaded at its preferred base address.
    /// If the base address is not available, the loader reports an error.
    /// The default behavior of the linker is to strip base relocations
    /// from executable (EXE) files.
    RELOCS_STRIPPED: u1 = 0,

    /// Image only. This indicates that the image file is valid and can be run.
    /// If this flag is not set, it indicates a linker error.
    EXECUTABLE_IMAGE: u1 = 0,

    /// COFF line numbers have been removed. This flag is deprecated and should be zero.
    LINE_NUMS_STRIPPED: u1 = 0,

    /// COFF symbol table entries for local symbols have been removed.
    /// This flag is deprecated and should be zero.
    LOCAL_SYMS_STRIPPED: u1 = 0,

    /// Obsolete. Aggressively trim working set.
    /// This flag is deprecated for Windows 2000 and later and must be zero.
    AGGRESSIVE_WS_TRIM: u1 = 0,

    /// Application can handle > 2-GB addresses.
    LARGE_ADDRESS_AWARE: u1 = 0,

    /// This flag is reserved for future use.
    RESERVED: u1 = 0,

    /// Little endian: the least significant bit (LSB) precedes the
    /// most significant bit (MSB) in memory. This flag is deprecated and should be zero.
    BYTES_REVERSED_LO: u1 = 0,

    /// Machine is based on a 32-bit-word architecture.
    @"32BIT_MACHINE": u1 = 0,

    /// Debugging information is removed from the image file.
    DEBUG_STRIPPED: u1 = 0,

    /// If the image is on removable media, fully load it and copy it to the swap file.
    REMOVABLE_RUN_FROM_SWAP: u1 = 0,

    /// If the image is on network media, fully load it and copy it to the swap file.
    NET_RUN_FROM_SWAP: u1 = 0,

    /// The image file is a system file, not a user program.
    SYSTEM: u1 = 0,

    /// The image file is a dynamic-link library (DLL).
    /// Such files are considered executable files for almost all purposes,
    /// although they cannot be directly run.
    DLL: u1 = 0,

    /// The file should be run only on a uniprocessor machine.
    UP_SYSTEM_ONLY: u1 = 0,

    /// Big endian: the MSB precedes the LSB in memory. This flag is deprecated and should be zero.
    BYTES_REVERSED_HI: u1 = 0,
};

pub const CoffHeader = extern struct {
    /// The number that identifies the type of target machine.
    machine: MachineType,

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
    flags: CoffHeaderFlags,
};

// OptionalHeader.magic values
// see https://msdn.microsoft.com/en-us/library/windows/desktop/ms680339(v=vs.85).aspx
pub const IMAGE_NT_OPTIONAL_HDR32_MAGIC = 0x10b;
pub const IMAGE_NT_OPTIONAL_HDR64_MAGIC = 0x20b;

pub const DllFlags = packed struct {
    _reserved_0: u5 = 0,

    /// Image can handle a high entropy 64-bit virtual address space.
    HIGH_ENTROPY_VA: u1 = 0,

    /// DLL can be relocated at load time.
    DYNAMIC_BASE: u1 = 0,

    /// Code Integrity checks are enforced.
    FORCE_INTEGRITY: u1 = 0,

    /// Image is NX compatible.
    NX_COMPAT: u1 = 0,

    /// Isolation aware, but do not isolate the image.
    NO_ISOLATION: u1 = 0,

    /// Does not use structured exception (SE) handling. No SE handler may be called in this image.
    NO_SEH: u1 = 0,

    /// Do not bind the image.
    NO_BIND: u1 = 0,

    /// Image must execute in an AppContainer.
    APPCONTAINER: u1 = 0,

    /// A WDM driver.
    WDM_DRIVER: u1 = 0,

    /// Image supports Control Flow Guard.
    GUARD_CF: u1 = 0,

    /// Terminal Server aware.
    TERMINAL_SERVER_AWARE: u1 = 0,
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
};

pub const OptionalHeader = extern struct {
    magic: u16,
    major_linker_version: u8,
    minor_linker_version: u8,
    size_of_code: u32,
    size_of_initialized_data: u32,
    size_of_uninitialized_data: u32,
    address_of_entry_point: u32,
    base_of_code: u32,
};

pub const OptionalHeaderPE32 = extern struct {
    magic: u16,
    major_linker_version: u8,
    minor_linker_version: u8,
    size_of_code: u32,
    size_of_initialized_data: u32,
    size_of_uninitialized_data: u32,
    address_of_entry_point: u32,
    base_of_code: u32,
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

pub const OptionalHeaderPE64 = extern struct {
    magic: u16,
    major_linker_version: u8,
    minor_linker_version: u8,
    size_of_code: u32,
    size_of_initialized_data: u32,
    size_of_uninitialized_data: u32,
    address_of_entry_point: u32,
    base_of_code: u32,
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

pub const BaseRelocation = packed struct {
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
    pub const ByName = packed struct {
        name_table_rva: u31,
        flag: u1 = 0,
    };

    pub const ByOrdinal = packed struct {
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
    pub const ByName = packed struct {
        name_table_rva: u31,
        unused: u32 = 0,
        flag: u1 = 0,
    };

    pub const ByOrdinal = packed struct {
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
    flags: SectionHeaderFlags,

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
        if (self.flags.ALIGN == 0) return null;
        return std.math.powi(u16, 2, self.flags.ALIGN - 1) catch unreachable;
    }

    pub fn setAlignment(self: *SectionHeader, new_alignment: u16) void {
        assert(new_alignment > 0 and new_alignment <= 8192);
        self.flags.ALIGN = std.math.log2(new_alignment);
    }

    pub fn isCode(self: SectionHeader) bool {
        return self.flags.CNT_CODE == 0b1;
    }

    pub fn isComdat(self: SectionHeader) bool {
        return self.flags.LNK_COMDAT == 0b1;
    }
};

pub const SectionHeaderFlags = packed struct {
    _reserved_0: u3 = 0,

    /// The section should not be padded to the next boundary.
    /// This flag is obsolete and is replaced by IMAGE_SCN_ALIGN_1BYTES.
    /// This is valid only for object files.
    TYPE_NO_PAD: u1 = 0,

    _reserved_1: u1 = 0,

    /// The section contains executable code.
    CNT_CODE: u1 = 0,

    /// The section contains initialized data.
    CNT_INITIALIZED_DATA: u1 = 0,

    /// The section contains uninitialized data.
    CNT_UNINITIALIZED_DATA: u1 = 0,

    /// Reserved for future use.
    LNK_OTHER: u1 = 0,

    /// The section contains comments or other information.
    /// The .drectve section has this type.
    /// This is valid for object files only.
    LNK_INFO: u1 = 0,

    _reserverd_2: u1 = 0,

    /// The section will not become part of the image.
    /// This is valid only for object files.
    LNK_REMOVE: u1 = 0,

    /// The section contains COMDAT data.
    /// For more information, see COMDAT Sections (Object Only).
    /// This is valid only for object files.
    LNK_COMDAT: u1 = 0,

    _reserved_3: u2 = 0,

    /// The section contains data referenced through the global pointer (GP).
    GPREL: u1 = 0,

    /// Reserved for future use.
    MEM_PURGEABLE: u1 = 0,

    /// Reserved for future use.
    MEM_16BIT: u1 = 0,

    /// Reserved for future use.
    MEM_LOCKED: u1 = 0,

    /// Reserved for future use.
    MEM_PRELOAD: u1 = 0,

    /// Takes on multiple values according to flags:
    /// pub const IMAGE_SCN_ALIGN_1BYTES: u32 = 0x100000;
    /// pub const IMAGE_SCN_ALIGN_2BYTES: u32 = 0x200000;
    /// pub const IMAGE_SCN_ALIGN_4BYTES: u32 = 0x300000;
    /// pub const IMAGE_SCN_ALIGN_8BYTES: u32 = 0x400000;
    /// pub const IMAGE_SCN_ALIGN_16BYTES: u32 = 0x500000;
    /// pub const IMAGE_SCN_ALIGN_32BYTES: u32 = 0x600000;
    /// pub const IMAGE_SCN_ALIGN_64BYTES: u32 = 0x700000;
    /// pub const IMAGE_SCN_ALIGN_128BYTES: u32 = 0x800000;
    /// pub const IMAGE_SCN_ALIGN_256BYTES: u32 = 0x900000;
    /// pub const IMAGE_SCN_ALIGN_512BYTES: u32 = 0xA00000;
    /// pub const IMAGE_SCN_ALIGN_1024BYTES: u32 = 0xB00000;
    /// pub const IMAGE_SCN_ALIGN_2048BYTES: u32 = 0xC00000;
    /// pub const IMAGE_SCN_ALIGN_4096BYTES: u32 = 0xD00000;
    /// pub const IMAGE_SCN_ALIGN_8192BYTES: u32 = 0xE00000;
    ALIGN: u4 = 0,

    /// The section contains extended relocations.
    LNK_NRELOC_OVFL: u1 = 0,

    /// The section can be discarded as needed.
    MEM_DISCARDABLE: u1 = 0,

    /// The section cannot be cached.
    MEM_NOT_CACHED: u1 = 0,

    /// The section is not pageable.
    MEM_NOT_PAGED: u1 = 0,

    /// The section can be shared in memory.
    MEM_SHARED: u1 = 0,

    /// The section can be executed as code.
    MEM_EXECUTE: u1 = 0,

    /// The section can be read.
    MEM_READ: u1 = 0,

    /// The section can be written to.
    MEM_WRITE: u1 = 0,
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
        const offset = std.mem.readIntLittle(u32, self.name[4..8]);
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

pub const SymType = packed struct {
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
};

// https://github.com/tpn/winsdk-10/blob/master/Include/10.0.16299.0/km/ntimage.h
pub const WeakExternalFlag = enum(u32) {
    SEARCH_NOLIBRARY = 1,
    SEARCH_LIBRARY = 2,
    SEARCH_ALIAS = 3,
    ANTI_DEPENDENCY = 4,
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

    pub fn fromTargetCpuArch(arch: std.Target.Cpu.Arch) MachineType {
        return switch (arch) {
            .arm => .ARM,
            .powerpc => .POWERPC,
            .riscv32 => .RISCV32,
            .thumb => .Thumb,
            .x86 => .I386,
            .aarch64 => .ARM64,
            .riscv64 => .RISCV64,
            .x86_64 => .X64,
            // there's cases we don't (yet) handle
            else => unreachable,
        };
    }

    pub fn toTargetCpuArch(machine_type: MachineType) ?std.Target.Cpu.Arch {
        return switch (machine_type) {
            .ARM => .arm,
            .POWERPC => .powerpc,
            .RISCV32 => .riscv32,
            .Thumb => .thumb,
            .I386 => .x86,
            .ARM64 => .aarch64,
            .RISCV64 => .riscv64,
            .X64 => .x86_64,
            // there's cases we don't (yet) handle
            else => null,
        };
    }
};

pub const CoffError = error{
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
    is_image: bool,
    coff_header_offset: usize,

    guid: [16]u8 = undefined,
    age: u32 = undefined,

    // The lifetime of `data` must be longer than the lifetime of the returned Coff
    pub fn init(data: []const u8) !Coff {
        const pe_pointer_offset = 0x3C;
        const pe_magic = "PE\x00\x00";

        var stream = std.io.fixedBufferStream(data);
        const reader = stream.reader();
        try stream.seekTo(pe_pointer_offset);
        var coff_header_offset = try reader.readIntLittle(u32);
        try stream.seekTo(coff_header_offset);
        var buf: [4]u8 = undefined;
        try reader.readNoEof(&buf);
        const is_image = mem.eql(u8, pe_magic, &buf);

        var coff = @This(){
            .data = data,
            .is_image = is_image,
            .coff_header_offset = coff_header_offset,
        };

        // Do some basic validation upfront
        if (is_image) {
            coff.coff_header_offset = coff.coff_header_offset + 4;
            const coff_header = coff.getCoffHeader();
            if (coff_header.size_of_optional_header == 0) return error.MissingPEHeader;
        }

        // JK: we used to check for architecture here and throw an error if not x86 or derivative.
        // However I am willing to take a leap of faith and let aarch64 have a shot also.

        return coff;
    }

    pub fn getPdbPath(self: *Coff, buffer: []u8) !usize {
        assert(self.is_image);

        const data_dirs = self.getDataDirectories();
        const debug_dir = data_dirs[@intFromEnum(DirectoryEntry.DEBUG)];

        var stream = std.io.fixedBufferStream(self.data);
        const reader = stream.reader();
        try stream.seekTo(debug_dir.virtual_address);

        // Find the correct DebugDirectoryEntry, and where its data is stored.
        // It can be in any section.
        const debug_dir_entry_count = debug_dir.size / @sizeOf(DebugDirectoryEntry);
        var i: u32 = 0;
        blk: while (i < debug_dir_entry_count) : (i += 1) {
            const debug_dir_entry = try reader.readStruct(DebugDirectoryEntry);
            if (debug_dir_entry.type == .CODEVIEW) {
                try stream.seekTo(debug_dir_entry.address_of_raw_data);
                break :blk;
            }
        }

        var cv_signature: [4]u8 = undefined; // CodeView signature
        try reader.readNoEof(cv_signature[0..]);
        // 'RSDS' indicates PDB70 format, used by lld.
        if (!mem.eql(u8, &cv_signature, "RSDS"))
            return error.InvalidPEMagic;
        try reader.readNoEof(self.guid[0..]);
        self.age = try reader.readIntLittle(u32);

        // Finally read the null-terminated string.
        var byte = try reader.readByte();
        i = 0;
        while (byte != 0 and i < buffer.len) : (i += 1) {
            buffer[i] = byte;
            byte = try reader.readByte();
        }

        if (byte != 0 and i == buffer.len)
            return error.NameTooLong;

        return @as(usize, i);
    }

    pub fn getCoffHeader(self: Coff) CoffHeader {
        return @as(*align(1) const CoffHeader, @ptrCast(self.data[self.coff_header_offset..][0..@sizeOf(CoffHeader)])).*;
    }

    pub fn getOptionalHeader(self: Coff) OptionalHeader {
        assert(self.is_image);
        const offset = self.coff_header_offset + @sizeOf(CoffHeader);
        return @as(*align(1) const OptionalHeader, @ptrCast(self.data[offset..][0..@sizeOf(OptionalHeader)])).*;
    }

    pub fn getOptionalHeader32(self: Coff) OptionalHeaderPE32 {
        assert(self.is_image);
        const offset = self.coff_header_offset + @sizeOf(CoffHeader);
        return @as(*align(1) const OptionalHeaderPE32, @ptrCast(self.data[offset..][0..@sizeOf(OptionalHeaderPE32)])).*;
    }

    pub fn getOptionalHeader64(self: Coff) OptionalHeaderPE64 {
        assert(self.is_image);
        const offset = self.coff_header_offset + @sizeOf(CoffHeader);
        return @as(*align(1) const OptionalHeaderPE64, @ptrCast(self.data[offset..][0..@sizeOf(OptionalHeaderPE64)])).*;
    }

    pub fn getImageBase(self: Coff) u64 {
        const hdr = self.getOptionalHeader();
        return switch (hdr.magic) {
            IMAGE_NT_OPTIONAL_HDR32_MAGIC => self.getOptionalHeader32().image_base,
            IMAGE_NT_OPTIONAL_HDR64_MAGIC => self.getOptionalHeader64().image_base,
            else => unreachable, // We assume we have validated the header already
        };
    }

    pub fn getNumberOfDataDirectories(self: Coff) u32 {
        const hdr = self.getOptionalHeader();
        return switch (hdr.magic) {
            IMAGE_NT_OPTIONAL_HDR32_MAGIC => self.getOptionalHeader32().number_of_rva_and_sizes,
            IMAGE_NT_OPTIONAL_HDR64_MAGIC => self.getOptionalHeader64().number_of_rva_and_sizes,
            else => unreachable, // We assume we have validated the header already
        };
    }

    pub fn getDataDirectories(self: *const Coff) []align(1) const ImageDataDirectory {
        const hdr = self.getOptionalHeader();
        const size: usize = switch (hdr.magic) {
            IMAGE_NT_OPTIONAL_HDR32_MAGIC => @sizeOf(OptionalHeaderPE32),
            IMAGE_NT_OPTIONAL_HDR64_MAGIC => @sizeOf(OptionalHeaderPE64),
            else => unreachable, // We assume we have validated the header already
        };
        const offset = self.coff_header_offset + @sizeOf(CoffHeader) + size;
        return @as([*]align(1) const ImageDataDirectory, @ptrCast(self.data[offset..]))[0..self.getNumberOfDataDirectories()];
    }

    pub fn getSymtab(self: *const Coff) ?Symtab {
        const coff_header = self.getCoffHeader();
        if (coff_header.pointer_to_symbol_table == 0) return null;

        const offset = coff_header.pointer_to_symbol_table;
        const size = coff_header.number_of_symbols * Symbol.sizeOf();
        return .{ .buffer = self.data[offset..][0..size] };
    }

    pub fn getStrtab(self: *const Coff) error{InvalidStrtabSize}!?Strtab {
        const coff_header = self.getCoffHeader();
        if (coff_header.pointer_to_symbol_table == 0) return null;

        const offset = coff_header.pointer_to_symbol_table + Symbol.sizeOf() * coff_header.number_of_symbols;
        const size = mem.readIntLittle(u32, self.data[offset..][0..4]);
        if ((offset + size) > self.data.len) return error.InvalidStrtabSize;

        return Strtab{ .buffer = self.data[offset..][0..size] };
    }

    pub fn strtabRequired(self: *const Coff) bool {
        for (self.getSectionHeaders()) |*sect_hdr| if (sect_hdr.getName() == null) return true;
        return false;
    }

    pub fn getSectionHeaders(self: *const Coff) []align(1) const SectionHeader {
        const coff_header = self.getCoffHeader();
        const offset = self.coff_header_offset + @sizeOf(CoffHeader) + coff_header.size_of_optional_header;
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
        return self.data[sec.pointer_to_raw_data..][0..sec.virtual_size];
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
        func_def,
        debug_info,
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
            .value = mem.readIntLittle(u32, raw[8..12]),
            .section_number = @as(SectionNumber, @enumFromInt(mem.readIntLittle(u16, raw[12..14]))),
            .type = @as(SymType, @bitCast(mem.readIntLittle(u16, raw[14..16]))),
            .storage_class = @as(StorageClass, @enumFromInt(raw[16])),
            .number_of_aux_symbols = raw[17],
        };
    }

    fn asDebugInfo(raw: []const u8) DebugInfoDefinition {
        return .{
            .unused_1 = raw[0..4].*,
            .linenumber = mem.readIntLittle(u16, raw[4..6]),
            .unused_2 = raw[6..12].*,
            .pointer_to_next_function = mem.readIntLittle(u32, raw[12..16]),
            .unused_3 = raw[16..18].*,
        };
    }

    fn asFuncDef(raw: []const u8) FunctionDefinition {
        return .{
            .tag_index = mem.readIntLittle(u32, raw[0..4]),
            .total_size = mem.readIntLittle(u32, raw[4..8]),
            .pointer_to_linenumber = mem.readIntLittle(u32, raw[8..12]),
            .pointer_to_next_function = mem.readIntLittle(u32, raw[12..16]),
            .unused = raw[16..18].*,
        };
    }

    fn asWeakExtDef(raw: []const u8) WeakExternalDefinition {
        return .{
            .tag_index = mem.readIntLittle(u32, raw[0..4]),
            .flag = @as(WeakExternalFlag, @enumFromInt(mem.readIntLittle(u32, raw[4..8]))),
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
            .length = mem.readIntLittle(u32, raw[0..4]),
            .number_of_relocations = mem.readIntLittle(u16, raw[4..6]),
            .number_of_linenumbers = mem.readIntLittle(u16, raw[6..8]),
            .checksum = mem.readIntLittle(u32, raw[8..12]),
            .number = mem.readIntLittle(u16, raw[12..14]),
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
