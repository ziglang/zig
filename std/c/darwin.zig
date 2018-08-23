extern "c" fn __error() *c_int;
pub extern "c" fn _NSGetExecutablePath(buf: [*]u8, bufsize: *u32) c_int;
pub extern "c" fn _dyld_get_image_header(image_index: u32) ?*mach_header;

pub extern "c" fn __getdirentries64(fd: c_int, buf_ptr: [*]u8, buf_len: usize, basep: *i64) usize;

pub extern "c" fn mach_absolute_time() u64;
pub extern "c" fn mach_timebase_info(tinfo: ?*mach_timebase_info_data) void;

pub extern "c" fn kqueue() c_int;
pub extern "c" fn kevent(
    kq: c_int,
    changelist: [*]const Kevent,
    nchanges: c_int,
    eventlist: [*]Kevent,
    nevents: c_int,
    timeout: ?*const timespec,
) c_int;

pub extern "c" fn kevent64(
    kq: c_int,
    changelist: [*]const kevent64_s,
    nchanges: c_int,
    eventlist: [*]kevent64_s,
    nevents: c_int,
    flags: c_uint,
    timeout: ?*const timespec,
) c_int;

pub extern "c" fn sysctl(name: [*]c_int, namelen: c_uint, oldp: ?*c_void, oldlenp: ?*usize, newp: ?*c_void, newlen: usize) c_int;
pub extern "c" fn sysctlbyname(name: [*]const u8, oldp: ?*c_void, oldlenp: ?*usize, newp: ?*c_void, newlen: usize) c_int;
pub extern "c" fn sysctlnametomib(name: [*]const u8, mibp: ?*c_int, sizep: ?*usize) c_int;

pub extern "c" fn bind(socket: c_int, address: ?*const sockaddr, address_len: socklen_t) c_int;
pub extern "c" fn socket(domain: c_int, type: c_int, protocol: c_int) c_int;

/// The value of the link editor defined symbol _MH_EXECUTE_SYM is the address
/// of the mach header in a Mach-O executable file type.  It does not appear in
/// any file type other than a MH_EXECUTE file type.  The type of the symbol is
/// absolute as the header is not part of any section.
pub extern "c" var _mh_execute_header: if (@sizeOf(usize) == 8) mach_header_64 else mach_header;

pub use @import("../os/darwin/errno.zig");

pub const _errno = __error;

pub const in_port_t = u16;
pub const sa_family_t = u8;
pub const socklen_t = u32;
pub const sockaddr = extern union {
    in: sockaddr_in,
    in6: sockaddr_in6,
};
pub const sockaddr_in = extern struct {
    len: u8,
    family: sa_family_t,
    port: in_port_t,
    addr: u32,
    zero: [8]u8,
};
pub const sockaddr_in6 = extern struct {
    len: u8,
    family: sa_family_t,
    port: in_port_t,
    flowinfo: u32,
    addr: [16]u8,
    scope_id: u32,
};

pub const timeval = extern struct {
    tv_sec: isize,
    tv_usec: isize,
};

pub const timezone = extern struct {
    tz_minuteswest: i32,
    tz_dsttime: i32,
};

pub const mach_timebase_info_data = extern struct {
    numer: u32,
    denom: u32,
};

/// Renamed to Stat to not conflict with the stat function.
pub const Stat = extern struct {
    dev: i32,
    mode: u16,
    nlink: u16,
    ino: u64,
    uid: u32,
    gid: u32,
    rdev: i32,
    atime: usize,
    atimensec: usize,
    mtime: usize,
    mtimensec: usize,
    ctime: usize,
    ctimensec: usize,
    birthtime: usize,
    birthtimensec: usize,
    size: i64,
    blocks: i64,
    blksize: i32,
    flags: u32,
    gen: u32,
    lspare: i32,
    qspare: [2]i64,
};

pub const timespec = extern struct {
    tv_sec: isize,
    tv_nsec: isize,
};

pub const sigset_t = u32;

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with function name.
pub const Sigaction = extern struct {
    handler: extern fn (c_int) void,
    sa_mask: sigset_t,
    sa_flags: c_int,
};

pub const dirent = extern struct {
    d_ino: usize,
    d_seekoff: usize,
    d_reclen: u16,
    d_namlen: u16,
    d_type: u8,
    d_name: u8, // field address is address of first byte of name
};

pub const pthread_attr_t = extern struct {
    __sig: c_long,
    __opaque: [56]u8,
};

/// Renamed from `kevent` to `Kevent` to avoid conflict with function name.
pub const Kevent = extern struct {
    ident: usize,
    filter: i16,
    flags: u16,
    fflags: u32,
    data: isize,
    udata: usize,
};

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


/// The symtab_command contains the offsets and sizes of the link-edit 4.3BSD
/// "stab" style symbol table information as described in the header files
/// <nlist.h> and <stab.h>.
pub const symtab_command = extern struct {
    cmd: u32, /// LC_SYMTAB
    cmdsize: u32, /// sizeof(struct symtab_command)
    symoff: u32, /// symbol table offset
    nsyms: u32, /// number of symbol table entries
    stroff: u32, /// string table offset
    strsize: u32, /// string table size in bytes
};

/// The linkedit_data_command contains the offsets and sizes of a blob
/// of data in the __LINKEDIT segment.  
const linkedit_data_command = extern struct {
    cmd: u32,/// LC_CODE_SIGNATURE, LC_SEGMENT_SPLIT_INFO, LC_FUNCTION_STARTS, LC_DATA_IN_CODE, LC_DYLIB_CODE_SIGN_DRS or LC_LINKER_OPTIMIZATION_HINT.
    cmdsize: u32, /// sizeof(struct linkedit_data_command)
    dataoff: u32 , /// file offset of data in __LINKEDIT segment
    datasize: u32 , /// file size of data in __LINKEDIT segment 
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
    cmd: u32,/// LC_SEGMENT
    cmdsize: u32,/// includes sizeof section structs
    segname: [16]u8,/// segment name
    vmaddr: u32,/// memory address of this segment
    vmsize: u32,/// memory size of this segment
    fileoff: u32,/// file offset of this segment
    filesize: u32,/// amount to map from the file
    maxprot: vm_prot_t,/// maximum VM protection
    initprot: vm_prot_t,/// initial VM protection
    nsects: u32,/// number of sections in segment
    flags: u32,
};

/// The 64-bit segment load command indicates that a part of this file is to be
/// mapped into a 64-bit task's address space.  If the 64-bit segment has
/// sections then section_64 structures directly follow the 64-bit segment
/// command and their size is reflected in cmdsize.
pub const segment_command_64 = extern struct {
    cmd: u32,               /// LC_SEGMENT_64
    cmdsize: u32,           /// includes sizeof section_64 structs
    segname: [16]u8,        /// segment name
    vmaddr: u64,            /// memory address of this segment
    vmsize: u64,            /// memory size of this segment
    fileoff: u64,           /// file offset of this segment
    filesize: u64,          /// amount to map from the file
    maxprot: vm_prot_t,     /// maximum VM protection
    initprot: vm_prot_t,    /// initial VM protection
    nsects: u32,            /// number of sections in segment
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
    sectname: [16]u8, /// name of this section
    segname: [16]u8,  /// segment this section goes in
    addr: u32,        /// memory address of this section
    size: u32,        /// size in bytes of this section
    offset: u32,      /// file offset of this section
    @"align": u32,    /// section alignment (power of 2)
    reloff: u32,      /// file offset of relocation entries
    nreloc: u32,      /// number of relocation entries
    flags: u32,       /// flags (section type and attributes
    reserved1: u32,   /// reserved (for offset or index)
    reserved2: u32,   /// reserved (for count or sizeof)
};

pub const section_64 = extern struct {
    sectname: [16]u8, /// name of this section
    segname: [16]u8,  /// segment this section goes in
    addr: u64,        /// memory address of this section
    size: u64,        /// size in bytes of this section
    offset: u32,      /// file offset of this section
    @"align": u32,    /// section alignment (power of 2)
    reloff: u32,      /// file offset of relocation entries
    nreloc: u32,      /// number of relocation entries
    flags: u32,       /// flags (section type and attributes
    reserved1: u32,   /// reserved (for offset or index)
    reserved2: u32,   /// reserved (for count or sizeof)
    reserved3: u32,   /// reserved
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

pub const LC_SEGMENT = 0x1; /// segment of this file to be mapped
pub const LC_SYMTAB = 0x2; /// link-edit stab symbol table info
pub const LC_SYMSEG = 0x3; /// link-edit gdb symbol table info (obsolete)
pub const LC_THREAD = 0x4; /// thread
pub const LC_UNIXTHREAD = 0x5; /// unix thread (includes a stack)
pub const LC_LOADFVMLIB = 0x6; /// load a specified fixed VM shared library
pub const LC_IDFVMLIB = 0x7; /// fixed VM shared library identification
pub const LC_IDENT = 0x8; /// object identification info (obsolete)
pub const LC_FVMFILE = 0x9; /// fixed VM file inclusion (internal use)
pub const LC_PREPAGE      = 0xa; /// prepage command (internal use)
pub const LC_DYSYMTAB = 0xb; /// dynamic link-edit symbol table info
pub const LC_LOAD_DYLIB = 0xc; /// load a dynamically linked shared library
pub const LC_ID_DYLIB = 0xd; /// dynamically linked shared lib ident
pub const LC_LOAD_DYLINKER = 0xe; /// load a dynamic linker
pub const LC_ID_DYLINKER = 0xf; /// dynamic linker identification
pub const LC_PREBOUND_DYLIB = 0x10; /// modules prebound for a dynamically
pub const LC_ROUTINES = 0x11; /// image routines
pub const LC_SUB_FRAMEWORK = 0x12; /// sub framework
pub const LC_SUB_UMBRELLA = 0x13; /// sub umbrella
pub const LC_SUB_CLIENT = 0x14; /// sub client
pub const LC_SUB_LIBRARY  = 0x15; /// sub library
pub const LC_TWOLEVEL_HINTS = 0x16; /// two-level namespace lookup hints
pub const LC_PREBIND_CKSUM  = 0x17; /// prebind checksum

/// load a dynamically linked shared library that is allowed to be missing
/// (all symbols are weak imported).
pub const LC_LOAD_WEAK_DYLIB = (0x18 | LC_REQ_DYLD);

pub const LC_SEGMENT_64 = 0x19; /// 64-bit segment of this file to be mapped
pub const LC_ROUTINES_64 = 0x1a; /// 64-bit image routines
pub const LC_UUID =  0x1b; /// the uuid
pub const LC_RPATH = (0x1c | LC_REQ_DYLD); /// runpath additions
pub const LC_CODE_SIGNATURE = 0x1d; /// local of code signature
pub const LC_SEGMENT_SPLIT_INFO = 0x1e; /// local of info to split segments
pub const LC_REEXPORT_DYLIB = (0x1f | LC_REQ_DYLD); /// load and re-export dylib
pub const LC_LAZY_LOAD_DYLIB = 0x20; /// delay load of dylib until first use
pub const LC_ENCRYPTION_INFO = 0x21; /// encrypted segment information
pub const LC_DYLD_INFO =  0x22; /// compressed dyld information
pub const LC_DYLD_INFO_ONLY = (0x22|LC_REQ_DYLD); /// compressed dyld information only
pub const LC_LOAD_UPWARD_DYLIB = (0x23 | LC_REQ_DYLD); /// load upward dylib
pub const LC_VERSION_MIN_MACOSX = 0x24; /// build for MacOSX min OS version
pub const LC_VERSION_MIN_IPHONEOS = 0x25; /// build for iPhoneOS min OS version
pub const LC_FUNCTION_STARTS = 0x26; /// compressed table of function start addresses
pub const LC_DYLD_ENVIRONMENT = 0x27; /// string for dyld to treat like environment variable
pub const LC_MAIN = (0x28|LC_REQ_DYLD); /// replacement for LC_UNIXTHREAD
pub const LC_DATA_IN_CODE = 0x29; /// table of non-instructions in __text
pub const LC_SOURCE_VERSION = 0x2A; /// source version used to build binary
pub const LC_DYLIB_CODE_SIGN_DRS = 0x2B; /// Code signing DRs copied from linked dylibs
pub const LC_ENCRYPTION_INFO_64 = 0x2C; /// 64-bit encrypted segment information
pub const LC_LINKER_OPTION = 0x2D; /// linker options in MH_OBJECT files
pub const LC_LINKER_OPTIMIZATION_HINT = 0x2E; /// optimization hints in MH_OBJECT files
pub const LC_VERSION_MIN_TVOS = 0x2F; /// build for AppleTV min OS version
pub const LC_VERSION_MIN_WATCHOS = 0x30; /// build for Watch min OS version
pub const LC_NOTE = 0x31; /// arbitrary data included within a Mach-O file
pub const LC_BUILD_VERSION = 0x32; /// build for platform min OS version

pub const MH_MAGIC = 0xfeedface; /// the mach magic number
pub const MH_CIGAM = 0xcefaedfe; /// NXSwapInt(MH_MAGIC)

pub const MH_MAGIC_64 = 0xfeedfacf; /// the 64-bit mach magic number
pub const MH_CIGAM_64 = 0xcffaedfe; /// NXSwapInt(MH_MAGIC_64)

pub const MH_OBJECT = 0x1;  /// relocatable object file
pub const MH_EXECUTE = 0x2;  /// demand paged executable file
pub const MH_FVMLIB = 0x3;  /// fixed VM shared library file
pub const MH_CORE =  0x4;  /// core file
pub const MH_PRELOAD = 0x5;  /// preloaded executable file
pub const MH_DYLIB = 0x6;  /// dynamically bound shared library
pub const MH_DYLINKER = 0x7;  /// dynamic link editor
pub const MH_BUNDLE = 0x8;  /// dynamically bound bundle file
pub const MH_DYLIB_STUB = 0x9;  /// shared library stub for static linking only, no section contents
pub const MH_DSYM =  0xa;  /// companion file with only debug sections
pub const MH_KEXT_BUNDLE = 0xb;  /// x86_64 kexts

// Constants for the flags field of the mach_header

pub const MH_NOUNDEFS = 0x1;  /// the object file has no undefined references
pub const MH_INCRLINK = 0x2;  /// the object file is the output of an incremental link against a base file and can't be link edited again
pub const MH_DYLDLINK = 0x4;  /// the object file is input for the dynamic linker and can't be staticly link edited again
pub const MH_BINDATLOAD = 0x8;  /// the object file's undefined references are bound by the dynamic linker when loaded.
pub const MH_PREBOUND = 0x10;  /// the file has its dynamic undefined references prebound.
pub const MH_SPLIT_SEGS = 0x20;  /// the file has its read-only and read-write segments split
pub const MH_LAZY_INIT = 0x40;  /// the shared library init routine is to be run lazily via catching memory faults to its writeable segments (obsolete)
pub const MH_TWOLEVEL = 0x80;  /// the image is using two-level name space bindings
pub const MH_FORCE_FLAT = 0x100;  /// the executable is forcing all images to use flat name space bindings
pub const MH_NOMULTIDEFS = 0x200;  /// this umbrella guarantees no multiple defintions of symbols in its sub-images so the two-level namespace hints can always be used.
pub const MH_NOFIXPREBINDING = 0x400; /// do not have dyld notify the prebinding agent about this executable
pub const MH_PREBINDABLE =  0x800;           /// the binary is not prebound but can have its prebinding redone. only used when MH_PREBOUND is not set.
pub const MH_ALLMODSBOUND = 0x1000;  /// indicates that this binary binds to all two-level namespace modules of its dependent libraries. only used when MH_PREBINDABLE and MH_TWOLEVEL are both set. 
pub const MH_SUBSECTIONS_VIA_SYMBOLS = 0x2000;/// safe to divide up the sections into sub-sections via symbols for dead code stripping
pub const MH_CANONICAL =    0x4000;  /// the binary has been canonicalized via the unprebind operation
pub const MH_WEAK_DEFINES = 0x8000;  /// the final linked image contains external weak symbols
pub const MH_BINDS_TO_WEAK = 0x10000; /// the final linked image uses weak symbols

pub const MH_ALLOW_STACK_EXECUTION = 0x20000;/// When this bit is set, all stacks in the task will be given stack execution privilege.  Only used in MH_EXECUTE filetypes.
pub const MH_ROOT_SAFE = 0x40000;           /// When this bit is set, the binary declares it is safe for use in processes with uid zero
                                         
pub const MH_SETUID_SAFE = 0x80000;         /// When this bit is set, the binary declares it is safe for use in processes when issetugid() is true

pub const MH_NO_REEXPORTED_DYLIBS = 0x100000; /// When this bit is set on a dylib, the static linker does not need to examine dependent dylibs to see if any are re-exported
pub const MH_PIE = 0x200000;   /// When this bit is set, the OS will load the main executable at a random address.  Only used in MH_EXECUTE filetypes.
pub const MH_DEAD_STRIPPABLE_DYLIB = 0x400000; /// Only for use on dylibs.  When linking against a dylib that has this bit set, the static linker will automatically not create a LC_LOAD_DYLIB load command to the dylib if no symbols are being referenced from the dylib.
pub const MH_HAS_TLV_DESCRIPTORS = 0x800000; /// Contains a section of type S_THREAD_LOCAL_VARIABLES

pub const MH_NO_HEAP_EXECUTION = 0x1000000; /// When this bit is set, the OS will run the main executable with a non-executable heap even on platforms (e.g. i386) that don't require it. Only used in MH_EXECUTE filetypes.

pub const MH_APP_EXTENSION_SAFE = 0x02000000; /// The code was linked for use in an application extension.

pub const MH_NLIST_OUTOFSYNC_WITH_DYLDINFO = 0x04000000; /// The external symbols listed in the nlist symbol table do not include all the symbols listed in the dyld info.


/// The flags field of a section structure is separated into two parts a section
/// type and section attributes.  The section types are mutually exclusive (it
/// can only have one type) but the section attributes are not (it may have more
/// than one attribute).
/// 256 section types
pub const SECTION_TYPE = 0x000000ff;
pub const SECTION_ATTRIBUTES = 0xffffff00; ///  24 section attributes

pub const S_REGULAR = 0x0; /// regular section
pub const S_ZEROFILL = 0x1; /// zero fill on demand section
pub const S_CSTRING_LITERALS = 0x2; /// section with only literal C string
pub const S_4BYTE_LITERALS = 0x3; /// section with only 4 byte literals
pub const S_8BYTE_LITERALS = 0x4; /// section with only 8 byte literals
pub const S_LITERAL_POINTERS = 0x5; /// section with only pointers to


pub const N_STAB = 0xe0; /// if any of these bits set, a symbolic debugging entry
pub const N_PEXT = 0x10; /// private external symbol bit
pub const N_TYPE = 0x0e; /// mask for the type bits
pub const N_EXT = 0x01; /// external symbol bit, set for external symbols


pub const N_GSYM = 0x20; /// global symbol: name,,NO_SECT,type,0
pub const N_FNAME = 0x22; /// procedure name (f77 kludge): name,,NO_SECT,0,0
pub const N_FUN = 0x24; /// procedure: name,,n_sect,linenumber,address
pub const N_STSYM = 0x26; /// static symbol: name,,n_sect,type,address
pub const N_LCSYM = 0x28; /// .lcomm symbol: name,,n_sect,type,address
pub const N_BNSYM = 0x2e; /// begin nsect sym: 0,,n_sect,0,address
pub const N_AST = 0x32; /// AST file path: name,,NO_SECT,0,0
pub const N_OPT = 0x3c; /// emitted with gcc2_compiled and in gcc source
pub const N_RSYM = 0x40; /// register sym: name,,NO_SECT,type,register
pub const N_SLINE = 0x44; /// src line: 0,,n_sect,linenumber,address
pub const N_ENSYM = 0x4e; /// end nsect sym: 0,,n_sect,0,address
pub const N_SSYM = 0x60; /// structure elt: name,,NO_SECT,type,struct_offset
pub const N_SO = 0x64; /// source file name: name,,n_sect,0,address
pub const N_OSO = 0x66; /// object file name: name,,0,0,st_mtime
pub const N_LSYM = 0x80; /// local sym: name,,NO_SECT,type,offset
pub const N_BINCL = 0x82; /// include file beginning: name,,NO_SECT,0,sum
pub const N_SOL = 0x84; /// #included file name: name,,n_sect,0,address
pub const N_PARAMS =  0x86; /// compiler parameters: name,,NO_SECT,0,0
pub const N_VERSION = 0x88; /// compiler version: name,,NO_SECT,0,0
pub const N_OLEVEL =  0x8A; /// compiler -O level: name,,NO_SECT,0,0
pub const N_PSYM = 0xa0; /// parameter: name,,NO_SECT,type,offset
pub const N_EINCL = 0xa2; /// include file end: name,,NO_SECT,0,0
pub const N_ENTRY = 0xa4; /// alternate entry: name,,n_sect,linenumber,address
pub const N_LBRAC = 0xc0; /// left bracket: 0,,NO_SECT,nesting level,address
pub const N_EXCL = 0xc2; /// deleted include file: name,,NO_SECT,0,sum
pub const N_RBRAC = 0xe0; /// right bracket: 0,,NO_SECT,nesting level,address
pub const N_BCOMM = 0xe2; /// begin common: name,,NO_SECT,0,0
pub const N_ECOMM = 0xe4; /// end common: name,,n_sect,0,0
pub const N_ECOML = 0xe8; /// end common (local name): 0,,n_sect,0,address
pub const N_LENG = 0xfe; /// second stab entry with length information

/// If a segment contains any sections marked with S_ATTR_DEBUG then all
/// sections in that segment must have this attribute.  No section other than
/// a section marked with this attribute may reference the contents of this
/// section.  A section with this attribute may contain no symbols and must have
/// a section type S_REGULAR.  The static linker will not copy section contents
/// from sections with this attribute into its output file.  These sections
/// generally contain DWARF debugging info.
pub const S_ATTR_DEBUG = 0x02000000; /// a debug section

pub const cpu_type_t = integer_t;
pub const cpu_subtype_t = integer_t;
pub const integer_t = c_int;
pub const vm_prot_t = c_int;

// sys/types.h on macos uses #pragma pack(4) so these checks are
// to make sure the struct is laid out the same. These values were
// produced from C code using the offsetof macro.
const std = @import("../index.zig");
const assert = std.debug.assert;

comptime {
    assert(@offsetOf(Kevent, "ident") == 0);
    assert(@offsetOf(Kevent, "filter") == 8);
    assert(@offsetOf(Kevent, "flags") == 10);
    assert(@offsetOf(Kevent, "fflags") == 12);
    assert(@offsetOf(Kevent, "data") == 16);
    assert(@offsetOf(Kevent, "udata") == 24);
}

pub const kevent64_s = extern struct {
    ident: u64,
    filter: i16,
    flags: u16,
    fflags: u32,
    data: i64,
    udata: u64,
    ext: [2]u64,
};

// sys/types.h on macos uses #pragma pack() so these checks are
// to make sure the struct is laid out the same. These values were
// produced from C code using the offsetof macro.
comptime {
    assert(@offsetOf(kevent64_s, "ident") == 0);
    assert(@offsetOf(kevent64_s, "filter") == 8);
    assert(@offsetOf(kevent64_s, "flags") == 10);
    assert(@offsetOf(kevent64_s, "fflags") == 12);
    assert(@offsetOf(kevent64_s, "data") == 16);
    assert(@offsetOf(kevent64_s, "udata") == 24);
    assert(@offsetOf(kevent64_s, "ext") == 32);
}
