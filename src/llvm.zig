//! We do this instead of @cImport because the self-hosted compiler is easier
//! to bootstrap if it does not depend on translate-c.

extern fn ZigLLDLinkCOFF(argc: c_int, argv: [*:null]const ?[*:0]const u8, can_exit_early: bool) c_int;
extern fn ZigLLDLinkELF(argc: c_int, argv: [*:null]const ?[*:0]const u8, can_exit_early: bool) c_int;
extern fn ZigLLDLinkMachO(argc: c_int, argv: [*:null]const ?[*:0]const u8, can_exit_early: bool) c_int;
extern fn ZigLLDLinkWasm(argc: c_int, argv: [*:null]const ?[*:0]const u8, can_exit_early: bool) c_int;

pub const LinkCOFF = ZigLLDLinkCOFF;
pub const LinkELF = ZigLLDLinkELF;
pub const LinkMachO = ZigLLDLinkMachO;
pub const LinkWasm = ZigLLDLinkWasm;

pub const ObjectFormatType = extern enum(c_int) {
    Unknown,
    COFF,
    ELF,
    GOFF,
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
    ZOS = 16,
    Haiku = 17,
    Minix = 18,
    RTEMS = 19,
    NaCl = 20,
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
    csky = 10,
    hexagon = 11,
    mips = 12,
    mipsel = 13,
    mips64 = 14,
    mips64el = 15,
    msp430 = 16,
    ppc = 17,
    ppc64 = 18,
    ppc64le = 19,
    r600 = 20,
    amdgcn = 21,
    riscv32 = 22,
    riscv64 = 23,
    sparc = 24,
    sparcv9 = 25,
    sparcel = 26,
    systemz = 27,
    tce = 28,
    tcele = 29,
    thumb = 30,
    thumbeb = 31,
    x86 = 32,
    x86_64 = 33,
    xcore = 34,
    nvptx = 35,
    nvptx64 = 36,
    le32 = 37,
    le64 = 38,
    amdil = 39,
    amdil64 = 40,
    hsail = 41,
    hsail64 = 42,
    spir = 43,
    spir64 = 44,
    kalimba = 45,
    shave = 46,
    lanai = 47,
    wasm32 = 48,
    wasm64 = 49,
    renderscript32 = 50,
    renderscript64 = 51,
    ve = 52,
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
