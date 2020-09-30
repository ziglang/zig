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

pub const ArchType = extern enum(c_int) {
    UnknownArch = 0,
    arm = 1,
    armeb = 2,
    aarch64 = 3,
    aarch64_be = 4,
    aarch64_32 = 5,
    arc = 6,
    avr = 7,
    bpfel = 8,
    bpfeb = 9,
    hexagon = 10,
    mips = 11,
    mipsel = 12,
    mips64 = 13,
    mips64el = 14,
    msp430 = 15,
    ppc = 16,
    ppc64 = 17,
    ppc64le = 18,
    r600 = 19,
    amdgcn = 20,
    riscv32 = 21,
    riscv64 = 22,
    sparc = 23,
    sparcv9 = 24,
    sparcel = 25,
    systemz = 26,
    tce = 27,
    tcele = 28,
    thumb = 29,
    thumbeb = 30,
    x86 = 31,
    x86_64 = 32,
    xcore = 33,
    nvptx = 34,
    nvptx64 = 35,
    le32 = 36,
    le64 = 37,
    amdil = 38,
    amdil64 = 39,
    hsail = 40,
    hsail64 = 41,
    spir = 42,
    spir64 = 43,
    kalimba = 44,
    shave = 45,
    lanai = 46,
    wasm32 = 47,
    wasm64 = 48,
    renderscript32 = 49,
    renderscript64 = 50,
    ve = 51,
};

pub const ParseCommandLineOptions = ZigLLVMParseCommandLineOptions;
extern fn ZigLLVMParseCommandLineOptions(argc: usize, argv: [*]const [*:0]const u8) void;

pub const WriteImportLibrary = ZigLLVMWriteImportLibrary;
extern fn ZigLLVMWriteImportLibrary(
    def_path: [*:0]const u8,
    arch: ArchType,
    output_lib_path: [*c]const u8,
    kill_at: bool,
) bool;
