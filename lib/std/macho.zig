pub const mach_header = extern struct {
    magic: u32,
    cputype: cpu_type_t,
    cpusubtype: cpu_subtype_t,
    filetype: u32,
    ncmds: u32,
    sizeofcmds: u32,
    flags: u32,
};

pub const mach_header_64 = extern struct {
    magic: u32,
    cputype: cpu_type_t,
    cpusubtype: cpu_subtype_t,
    filetype: u32,
    ncmds: u32,
    sizeofcmds: u32,
    flags: u32,
    reserved: u32,
};

pub const load_command = extern struct {
    cmd: u32,
    cmdsize: u32,
};

pub const uuid_command = extern struct {
    /// LC_UUID
    cmd: u32,

    /// sizeof(struct uuid_command)
    cmdsize: u32,

    /// the 128-bit uuid
    uuid: [16]u8,
};

/// The symtab_command contains the offsets and sizes of the link-edit 4.3BSD
/// "stab" style symbol table information as described in the header files
/// <nlist.h> and <stab.h>.
pub const symtab_command = extern struct {
    /// LC_SYMTAB
    cmd: u32,

    /// sizeof(struct symtab_command)
    cmdsize: u32,

    /// symbol table offset
    symoff: u32,

    /// number of symbol table entries
    nsyms: u32,

    /// string table offset
    stroff: u32,

    /// string table size in bytes
    strsize: u32,
};

/// The linkedit_data_command contains the offsets and sizes of a blob
/// of data in the __LINKEDIT segment.
const linkedit_data_command = extern struct {
    /// LC_CODE_SIGNATURE, LC_SEGMENT_SPLIT_INFO, LC_FUNCTION_STARTS, LC_DATA_IN_CODE, LC_DYLIB_CODE_SIGN_DRS or LC_LINKER_OPTIMIZATION_HINT.
    cmd: u32,

    /// sizeof(struct linkedit_data_command)
    cmdsize: u32,

    /// file offset of data in __LINKEDIT segment
    dataoff: u32,

    /// file size of data in __LINKEDIT segment
    datasize: u32,
};

/// The segment load command indicates that a part of this file is to be
/// mapped into the task's address space.  The size of this segment in memory,
/// vmsize, maybe equal to or larger than the amount to map from this file,
/// filesize.  The file is mapped starting at fileoff to the beginning of
/// the segment in memory, vmaddr.  The rest of the memory of the segment,
/// if any, is allocated zero fill on demand.  The segment's maximum virtual
/// memory protection and initial virtual memory protection are specified
/// by the maxprot and initprot fields.  If the segment has sections then the
/// section structures directly follow the segment command and their size is
/// reflected in cmdsize.
pub const segment_command = extern struct {
    /// LC_SEGMENT
    cmd: u32,

    /// includes sizeof section structs
    cmdsize: u32,

    /// segment name
    segname: [16]u8,

    /// memory address of this segment
    vmaddr: u32,

    /// memory size of this segment
    vmsize: u32,

    /// file offset of this segment
    fileoff: u32,

    /// amount to map from the file
    filesize: u32,

    /// maximum VM protection
    maxprot: vm_prot_t,

    /// initial VM protection
    initprot: vm_prot_t,

    /// number of sections in segment
    nsects: u32,
    flags: u32,
};

/// The 64-bit segment load command indicates that a part of this file is to be
/// mapped into a 64-bit task's address space.  If the 64-bit segment has
/// sections then section_64 structures directly follow the 64-bit segment
/// command and their size is reflected in cmdsize.
pub const segment_command_64 = extern struct {
    /// LC_SEGMENT_64
    cmd: u32,

    /// includes sizeof section_64 structs
    cmdsize: u32,

    /// segment name
    segname: [16]u8,

    /// memory address of this segment
    vmaddr: u64,

    /// memory size of this segment
    vmsize: u64,

    /// file offset of this segment
    fileoff: u64,

    /// amount to map from the file
    filesize: u64,

    /// maximum VM protection
    maxprot: vm_prot_t,

    /// initial VM protection
    initprot: vm_prot_t,

    /// number of sections in segment
    nsects: u32,
    flags: u32,
};

/// A segment is made up of zero or more sections.  Non-MH_OBJECT files have
/// all of their segments with the proper sections in each, and padded to the
/// specified segment alignment when produced by the link editor.  The first
/// segment of a MH_EXECUTE and MH_FVMLIB format file contains the mach_header
/// and load commands of the object file before its first section.  The zero
/// fill sections are always last in their segment (in all formats).  This
/// allows the zeroed segment padding to be mapped into memory where zero fill
/// sections might be. The gigabyte zero fill sections, those with the section
/// type S_GB_ZEROFILL, can only be in a segment with sections of this type.
/// These segments are then placed after all other segments.
///
/// The MH_OBJECT format has all of its sections in one segment for
/// compactness.  There is no padding to a specified segment boundary and the
/// mach_header and load commands are not part of the segment.
///
/// Sections with the same section name, sectname, going into the same segment,
/// segname, are combined by the link editor.  The resulting section is aligned
/// to the maximum alignment of the combined sections and is the new section's
/// alignment.  The combined sections are aligned to their original alignment in
/// the combined section.  Any padded bytes to get the specified alignment are
/// zeroed.
///
/// The format of the relocation entries referenced by the reloff and nreloc
/// fields of the section structure for mach object files is described in the
/// header file <reloc.h>.
pub const @"section" = extern struct {
    /// name of this section
    sectname: [16]u8,

    /// segment this section goes in
    segname: [16]u8,

    /// memory address of this section
    addr: u32,

    /// size in bytes of this section
    size: u32,

    /// file offset of this section
    offset: u32,

    /// section alignment (power of 2)
    @"align": u32,

    /// file offset of relocation entries
    reloff: u32,

    /// number of relocation entries
    nreloc: u32,

    /// flags (section type and attributes
    flags: u32,

    /// reserved (for offset or index)
    reserved1: u32,

    /// reserved (for count or sizeof)
    reserved2: u32,
};

pub const section_64 = extern struct {
    /// name of this section
    sectname: [16]u8,

    /// segment this section goes in
    segname: [16]u8,

    /// memory address of this section
    addr: u64,

    /// size in bytes of this section
    size: u64,

    /// file offset of this section
    offset: u32,

    /// section alignment (power of 2)
    @"align": u32,

    /// file offset of relocation entries
    reloff: u32,

    /// number of relocation entries
    nreloc: u32,

    /// flags (section type and attributes
    flags: u32,

    /// reserved (for offset or index)
    reserved1: u32,

    /// reserved (for count or sizeof)
    reserved2: u32,

    /// reserved
    reserved3: u32,
};

pub const nlist = extern struct {
    n_strx: u32,
    n_type: u8,
    n_sect: u8,
    n_desc: i16,
    n_value: u32,
};

pub const nlist_64 = extern struct {
    n_strx: u32,
    n_type: u8,
    n_sect: u8,
    n_desc: u16,
    n_value: u64,
};

/// After MacOS X 10.1 when a new load command is added that is required to be
/// understood by the dynamic linker for the image to execute properly the
/// LC_REQ_DYLD bit will be or'ed into the load command constant.  If the dynamic
/// linker sees such a load command it it does not understand will issue a
/// "unknown load command required for execution" error and refuse to use the
/// image.  Other load commands without this bit that are not understood will
/// simply be ignored.
pub const LC_REQ_DYLD = 0x80000000;

/// segment of this file to be mapped
pub const LC_SEGMENT = 0x1;

/// link-edit stab symbol table info
pub const LC_SYMTAB = 0x2;

/// link-edit gdb symbol table info (obsolete)
pub const LC_SYMSEG = 0x3;

/// thread
pub const LC_THREAD = 0x4;

/// unix thread (includes a stack)
pub const LC_UNIXTHREAD = 0x5;

/// load a specified fixed VM shared library
pub const LC_LOADFVMLIB = 0x6;

/// fixed VM shared library identification
pub const LC_IDFVMLIB = 0x7;

/// object identification info (obsolete)
pub const LC_IDENT = 0x8;

/// fixed VM file inclusion (internal use)
pub const LC_FVMFILE = 0x9;

/// prepage command (internal use)
pub const LC_PREPAGE = 0xa;

/// dynamic link-edit symbol table info
pub const LC_DYSYMTAB = 0xb;

/// load a dynamically linked shared library
pub const LC_LOAD_DYLIB = 0xc;

/// dynamically linked shared lib ident
pub const LC_ID_DYLIB = 0xd;

/// load a dynamic linker
pub const LC_LOAD_DYLINKER = 0xe;

/// dynamic linker identification
pub const LC_ID_DYLINKER = 0xf;

/// modules prebound for a dynamically
pub const LC_PREBOUND_DYLIB = 0x10;

/// image routines
pub const LC_ROUTINES = 0x11;

/// sub framework
pub const LC_SUB_FRAMEWORK = 0x12;

/// sub umbrella
pub const LC_SUB_UMBRELLA = 0x13;

/// sub client
pub const LC_SUB_CLIENT = 0x14;

/// sub library
pub const LC_SUB_LIBRARY = 0x15;

/// two-level namespace lookup hints
pub const LC_TWOLEVEL_HINTS = 0x16;

/// prebind checksum
pub const LC_PREBIND_CKSUM = 0x17;

/// load a dynamically linked shared library that is allowed to be missing
/// (all symbols are weak imported).
pub const LC_LOAD_WEAK_DYLIB = (0x18 | LC_REQ_DYLD);

/// 64-bit segment of this file to be mapped
pub const LC_SEGMENT_64 = 0x19;

/// 64-bit image routines
pub const LC_ROUTINES_64 = 0x1a;

/// the uuid
pub const LC_UUID = 0x1b;

/// runpath additions
pub const LC_RPATH = (0x1c | LC_REQ_DYLD);

/// local of code signature
pub const LC_CODE_SIGNATURE = 0x1d;

/// local of info to split segments
pub const LC_SEGMENT_SPLIT_INFO = 0x1e;

/// load and re-export dylib
pub const LC_REEXPORT_DYLIB = (0x1f | LC_REQ_DYLD);

/// delay load of dylib until first use
pub const LC_LAZY_LOAD_DYLIB = 0x20;

/// encrypted segment information
pub const LC_ENCRYPTION_INFO = 0x21;

/// compressed dyld information
pub const LC_DYLD_INFO = 0x22;

/// compressed dyld information only
pub const LC_DYLD_INFO_ONLY = (0x22 | LC_REQ_DYLD);

/// load upward dylib
pub const LC_LOAD_UPWARD_DYLIB = (0x23 | LC_REQ_DYLD);

/// build for MacOSX min OS version
pub const LC_VERSION_MIN_MACOSX = 0x24;

/// build for iPhoneOS min OS version
pub const LC_VERSION_MIN_IPHONEOS = 0x25;

/// compressed table of function start addresses
pub const LC_FUNCTION_STARTS = 0x26;

/// string for dyld to treat like environment variable
pub const LC_DYLD_ENVIRONMENT = 0x27;

/// replacement for LC_UNIXTHREAD
pub const LC_MAIN = (0x28 | LC_REQ_DYLD);

/// table of non-instructions in __text
pub const LC_DATA_IN_CODE = 0x29;

/// source version used to build binary
pub const LC_SOURCE_VERSION = 0x2A;

/// Code signing DRs copied from linked dylibs
pub const LC_DYLIB_CODE_SIGN_DRS = 0x2B;

/// 64-bit encrypted segment information
pub const LC_ENCRYPTION_INFO_64 = 0x2C;

/// linker options in MH_OBJECT files
pub const LC_LINKER_OPTION = 0x2D;

/// optimization hints in MH_OBJECT files
pub const LC_LINKER_OPTIMIZATION_HINT = 0x2E;

/// build for AppleTV min OS version
pub const LC_VERSION_MIN_TVOS = 0x2F;

/// build for Watch min OS version
pub const LC_VERSION_MIN_WATCHOS = 0x30;

/// arbitrary data included within a Mach-O file
pub const LC_NOTE = 0x31;

/// build for platform min OS version
pub const LC_BUILD_VERSION = 0x32;

/// the mach magic number
pub const MH_MAGIC = 0xfeedface;

/// NXSwapInt(MH_MAGIC)
pub const MH_CIGAM = 0xcefaedfe;

/// the 64-bit mach magic number
pub const MH_MAGIC_64 = 0xfeedfacf;

/// NXSwapInt(MH_MAGIC_64)
pub const MH_CIGAM_64 = 0xcffaedfe;

/// relocatable object file
pub const MH_OBJECT = 0x1;

/// demand paged executable file
pub const MH_EXECUTE = 0x2;

/// fixed VM shared library file
pub const MH_FVMLIB = 0x3;

/// core file
pub const MH_CORE = 0x4;

/// preloaded executable file
pub const MH_PRELOAD = 0x5;

/// dynamically bound shared library
pub const MH_DYLIB = 0x6;

/// dynamic link editor
pub const MH_DYLINKER = 0x7;

/// dynamically bound bundle file
pub const MH_BUNDLE = 0x8;

/// shared library stub for static linking only, no section contents
pub const MH_DYLIB_STUB = 0x9;

/// companion file with only debug sections
pub const MH_DSYM = 0xa;

/// x86_64 kexts
pub const MH_KEXT_BUNDLE = 0xb;

// Constants for the flags field of the mach_header

/// the object file has no undefined references
pub const MH_NOUNDEFS = 0x1;

/// the object file is the output of an incremental link against a base file and can't be link edited again
pub const MH_INCRLINK = 0x2;

/// the object file is input for the dynamic linker and can't be staticly link edited again
pub const MH_DYLDLINK = 0x4;

/// the object file's undefined references are bound by the dynamic linker when loaded.
pub const MH_BINDATLOAD = 0x8;

/// the file has its dynamic undefined references prebound.
pub const MH_PREBOUND = 0x10;

/// the file has its read-only and read-write segments split
pub const MH_SPLIT_SEGS = 0x20;

/// the shared library init routine is to be run lazily via catching memory faults to its writeable segments (obsolete)
pub const MH_LAZY_INIT = 0x40;

/// the image is using two-level name space bindings
pub const MH_TWOLEVEL = 0x80;

/// the executable is forcing all images to use flat name space bindings
pub const MH_FORCE_FLAT = 0x100;

/// this umbrella guarantees no multiple defintions of symbols in its sub-images so the two-level namespace hints can always be used.
pub const MH_NOMULTIDEFS = 0x200;

/// do not have dyld notify the prebinding agent about this executable
pub const MH_NOFIXPREBINDING = 0x400;

/// the binary is not prebound but can have its prebinding redone. only used when MH_PREBOUND is not set.
pub const MH_PREBINDABLE = 0x800;

/// indicates that this binary binds to all two-level namespace modules of its dependent libraries. only used when MH_PREBINDABLE and MH_TWOLEVEL are both set.
pub const MH_ALLMODSBOUND = 0x1000;

/// safe to divide up the sections into sub-sections via symbols for dead code stripping
pub const MH_SUBSECTIONS_VIA_SYMBOLS = 0x2000;

/// the binary has been canonicalized via the unprebind operation
pub const MH_CANONICAL = 0x4000;

/// the final linked image contains external weak symbols
pub const MH_WEAK_DEFINES = 0x8000;

/// the final linked image uses weak symbols
pub const MH_BINDS_TO_WEAK = 0x10000;

/// When this bit is set, all stacks in the task will be given stack execution privilege.  Only used in MH_EXECUTE filetypes.
pub const MH_ALLOW_STACK_EXECUTION = 0x20000;

/// When this bit is set, the binary declares it is safe for use in processes with uid zero
pub const MH_ROOT_SAFE = 0x40000;

/// When this bit is set, the binary declares it is safe for use in processes when issetugid() is true
pub const MH_SETUID_SAFE = 0x80000;

/// When this bit is set on a dylib, the static linker does not need to examine dependent dylibs to see if any are re-exported
pub const MH_NO_REEXPORTED_DYLIBS = 0x100000;

/// When this bit is set, the OS will load the main executable at a random address.  Only used in MH_EXECUTE filetypes.
pub const MH_PIE = 0x200000;

/// Only for use on dylibs.  When linking against a dylib that has this bit set, the static linker will automatically not create a LC_LOAD_DYLIB load command to the dylib if no symbols are being referenced from the dylib.
pub const MH_DEAD_STRIPPABLE_DYLIB = 0x400000;

/// Contains a section of type S_THREAD_LOCAL_VARIABLES
pub const MH_HAS_TLV_DESCRIPTORS = 0x800000;

/// When this bit is set, the OS will run the main executable with a non-executable heap even on platforms (e.g. i386) that don't require it. Only used in MH_EXECUTE filetypes.
pub const MH_NO_HEAP_EXECUTION = 0x1000000;

/// The code was linked for use in an application extension.
pub const MH_APP_EXTENSION_SAFE = 0x02000000;

/// The external symbols listed in the nlist symbol table do not include all the symbols listed in the dyld info.
pub const MH_NLIST_OUTOFSYNC_WITH_DYLDINFO = 0x04000000;

/// The flags field of a section structure is separated into two parts a section
/// type and section attributes.  The section types are mutually exclusive (it
/// can only have one type) but the section attributes are not (it may have more
/// than one attribute).
/// 256 section types
pub const SECTION_TYPE = 0x000000ff;

///  24 section attributes
pub const SECTION_ATTRIBUTES = 0xffffff00;

/// regular section
pub const S_REGULAR = 0x0;

/// zero fill on demand section
pub const S_ZEROFILL = 0x1;

/// section with only literal C string
pub const S_CSTRING_LITERALS = 0x2;

/// section with only 4 byte literals
pub const S_4BYTE_LITERALS = 0x3;

/// section with only 8 byte literals
pub const S_8BYTE_LITERALS = 0x4;

/// section with only pointers to
pub const S_LITERAL_POINTERS = 0x5;

/// if any of these bits set, a symbolic debugging entry
pub const N_STAB = 0xe0;

/// private external symbol bit
pub const N_PEXT = 0x10;

/// mask for the type bits
pub const N_TYPE = 0x0e;

/// external symbol bit, set for external symbols
pub const N_EXT = 0x01;

/// global symbol: name,,NO_SECT,type,0
pub const N_GSYM = 0x20;

/// procedure name (f77 kludge): name,,NO_SECT,0,0
pub const N_FNAME = 0x22;

/// procedure: name,,n_sect,linenumber,address
pub const N_FUN = 0x24;

/// static symbol: name,,n_sect,type,address
pub const N_STSYM = 0x26;

/// .lcomm symbol: name,,n_sect,type,address
pub const N_LCSYM = 0x28;

/// begin nsect sym: 0,,n_sect,0,address
pub const N_BNSYM = 0x2e;

/// AST file path: name,,NO_SECT,0,0
pub const N_AST = 0x32;

/// emitted with gcc2_compiled and in gcc source
pub const N_OPT = 0x3c;

/// register sym: name,,NO_SECT,type,register
pub const N_RSYM = 0x40;

/// src line: 0,,n_sect,linenumber,address
pub const N_SLINE = 0x44;

/// end nsect sym: 0,,n_sect,0,address
pub const N_ENSYM = 0x4e;

/// structure elt: name,,NO_SECT,type,struct_offset
pub const N_SSYM = 0x60;

/// source file name: name,,n_sect,0,address
pub const N_SO = 0x64;

/// object file name: name,,0,0,st_mtime
pub const N_OSO = 0x66;

/// local sym: name,,NO_SECT,type,offset
pub const N_LSYM = 0x80;

/// include file beginning: name,,NO_SECT,0,sum
pub const N_BINCL = 0x82;

/// #included file name: name,,n_sect,0,address
pub const N_SOL = 0x84;

/// compiler parameters: name,,NO_SECT,0,0
pub const N_PARAMS = 0x86;

/// compiler version: name,,NO_SECT,0,0
pub const N_VERSION = 0x88;

/// compiler -O level: name,,NO_SECT,0,0
pub const N_OLEVEL = 0x8A;

/// parameter: name,,NO_SECT,type,offset
pub const N_PSYM = 0xa0;

/// include file end: name,,NO_SECT,0,0
pub const N_EINCL = 0xa2;

/// alternate entry: name,,n_sect,linenumber,address
pub const N_ENTRY = 0xa4;

/// left bracket: 0,,NO_SECT,nesting level,address
pub const N_LBRAC = 0xc0;

/// deleted include file: name,,NO_SECT,0,sum
pub const N_EXCL = 0xc2;

/// right bracket: 0,,NO_SECT,nesting level,address
pub const N_RBRAC = 0xe0;

/// begin common: name,,NO_SECT,0,0
pub const N_BCOMM = 0xe2;

/// end common: name,,n_sect,0,0
pub const N_ECOMM = 0xe4;

/// end common (local name): 0,,n_sect,0,address
pub const N_ECOML = 0xe8;

/// second stab entry with length information
pub const N_LENG = 0xfe;

/// If a segment contains any sections marked with S_ATTR_DEBUG then all
/// sections in that segment must have this attribute.  No section other than
/// a section marked with this attribute may reference the contents of this
/// section.  A section with this attribute may contain no symbols and must have
/// a section type S_REGULAR.  The static linker will not copy section contents
/// from sections with this attribute into its output file.  These sections
/// generally contain DWARF debugging info.
/// a debug section
pub const S_ATTR_DEBUG = 0x02000000;

pub const cpu_type_t = integer_t;
pub const cpu_subtype_t = integer_t;
pub const integer_t = c_int;
pub const vm_prot_t = c_int;
