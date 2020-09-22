//! We do this instead of @cImport because the self-hosted compiler is easier
//! to bootstrap if it does not depend on translate-c.

pub const Link = ZigLLDLink;
extern fn ZigLLDLink(
    oformat: ObjectFormatType,
    args: [*:null]const ?[*:0]const u8,
    arg_count: usize,
    append_diagnostic: fn (context: usize, ptr: [*]const u8, len: usize) callconv(.C) void,
    context_stdout: usize,
    context_stderr: usize,
) bool;

pub const ObjectFormatType = extern enum(c_int) {
    Unknown,
    COFF,
    ELF,
    MachO,
    Wasm,
    XCOFF,
};

pub const GetHostCPUName = LLVMGetHostCPUName;
extern fn LLVMGetHostCPUName() ?[*:0]u8;

pub const GetNativeFeatures = ZigLLVMGetNativeFeatures;
extern fn ZigLLVMGetNativeFeatures() ?[*:0]u8;

pub const WriteArchive = ZigLLVMWriteArchive;
extern fn ZigLLVMWriteArchive(
    archive_name: [*:0]const u8,
    file_names_ptr: [*]const [*:0]const u8,
    file_names_len: usize,
    os_type: OSType,
) bool;

pub const OSType = extern enum(c_int) {
    UnknownOS = 0,
    Ananas = 1,
    CloudABI = 2,
    Darwin = 3,
    DragonFly = 4,
    FreeBSD = 5,
    Fuchsia = 6,
    IOS = 7,
    KFreeBSD = 8,
    Linux = 9,
    Lv2 = 10,
    MacOSX = 11,
    NetBSD = 12,
    OpenBSD = 13,
    Solaris = 14,
    Win32 = 15,
    Haiku = 16,
    Minix = 17,
    RTEMS = 18,
    NaCl = 19,
    CNK = 20,
    AIX = 21,
    CUDA = 22,
    NVCL = 23,
    AMDHSA = 24,
    PS4 = 25,
    ELFIAMCU = 26,
    TvOS = 27,
    WatchOS = 28,
    Mesa3D = 29,
    Contiki = 30,
    AMDPAL = 31,
    HermitCore = 32,
    Hurd = 33,
    WASI = 34,
    Emscripten = 35,
};
