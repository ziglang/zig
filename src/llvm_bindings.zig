//! We do this instead of @cImport because the self-hosted compiler is easier
//! to bootstrap if it does not depend on translate-c.

const std = @import("std");
const assert = std.debug.assert;

const LLVMBool = bool;
pub const LLVMAttributeIndex = c_uint;

pub const ValueRef = opaque {
    pub const addAttributeAtIndex = LLVMAddAttributeAtIndex;
    extern fn LLVMAddAttributeAtIndex(*const ValueRef, Idx: LLVMAttributeIndex, A: *const AttributeRef) void;

    pub const appendBasicBlock = LLVMAppendBasicBlock;
    extern fn LLVMAppendBasicBlock(Fn: *const ValueRef, Name: [*:0]const u8) *const BasicBlockRef;

    pub const getFirstBasicBlock = LLVMGetFirstBasicBlock;
    extern fn LLVMGetFirstBasicBlock(Fn: *const ValueRef) ?*const BasicBlockRef;

    // Helper functions
    // TODO: Do we want to put these functions here? It allows for convienient function calls
    //       on ValueRef: llvm_fn.addFnAttr("noreturn")
    fn addAttr(val: *const ValueRef, index: LLVMAttributeIndex, name: []const u8) void {
        const kind_id = getEnumAttributeKindForName(name.ptr, name.len);
        assert(kind_id != 0);
        const llvm_attr = ContextRef.getGlobal().createEnumAttribute(kind_id, 0);
        val.addAttributeAtIndex(index, llvm_attr);
    }

    pub fn addFnAttr(val: *const ValueRef, attr_name: []const u8) void {
        // TODO: improve this API, `addAttr(-1, attr_name)`
        val.addAttr(std.math.maxInt(LLVMAttributeIndex), attr_name);
    }
};

pub const TypeRef = opaque {
    pub const functionType = LLVMFunctionType;
    extern fn LLVMFunctionType(ReturnType: *const TypeRef, ParamTypes: ?[*]*const TypeRef, ParamCount: c_uint, IsVarArg: LLVMBool) *const TypeRef;

    pub const constNull = LLVMConstNull;
    extern fn LLVMConstNull(Ty: *const TypeRef) *const ValueRef;

    pub const constAllOnes = LLVMConstAllOnes;
    extern fn LLVMConstAllOnes(Ty: *const TypeRef) *const ValueRef;

    pub const getUndef = LLVMGetUndef;
    extern fn LLVMGetUndef(Ty: *const TypeRef) *const ValueRef;
};

pub const ModuleRef = opaque {
    pub const createWithName = LLVMModuleCreateWithName;
    extern fn LLVMModuleCreateWithName(ModuleID: [*:0]const u8) *const ModuleRef;

    pub const disposeModule = LLVMDisposeModule;
    extern fn LLVMDisposeModule(*const ModuleRef) void;

    pub const verifyModule = LLVMVerifyModule;
    extern fn LLVMVerifyModule(*const ModuleRef, Action: VerifierFailureAction, OutMessage: *[*:0]const u8) LLVMBool;

    pub const addFunction = LLVMAddFunction;
    extern fn LLVMAddFunction(*const ModuleRef, Name: [*:0]const u8, FunctionTy: *const TypeRef) *const ValueRef;

    pub const getNamedFunction = LLVMGetNamedFunction;
    extern fn LLVMGetNamedFunction(*const ModuleRef, Name: [*:0]const u8) ?*const ValueRef;

    pub const printToString = LLVMPrintModuleToString;
    extern fn LLVMPrintModuleToString(*const ModuleRef) [*:0]const u8;
};

pub const disposeMessage = LLVMDisposeMessage;
extern fn LLVMDisposeMessage(Message: [*:0]const u8) void;

pub const VerifierFailureAction = extern enum {
    AbortProcess,
    PrintMessage,
    ReturnStatus,
};

pub const voidType = LLVMVoidType;
extern fn LLVMVoidType() *const TypeRef;

pub const getEnumAttributeKindForName = LLVMGetEnumAttributeKindForName;
extern fn LLVMGetEnumAttributeKindForName(Name: [*]const u8, SLen: usize) c_uint;

pub const AttributeRef = opaque {};

pub const ContextRef = opaque {
    pub const createEnumAttribute = LLVMCreateEnumAttribute;
    extern fn LLVMCreateEnumAttribute(*const ContextRef, KindID: c_uint, Val: u64) *const AttributeRef;

    pub const getGlobal = LLVMGetGlobalContext;
    extern fn LLVMGetGlobalContext() *const ContextRef;
};

pub const intType = LLVMIntType;
extern fn LLVMIntType(NumBits: c_uint) *const TypeRef;

pub const BuilderRef = opaque {
    pub const createBuilder = LLVMCreateBuilder;
    extern fn LLVMCreateBuilder() *const BuilderRef;

    pub const disposeBuilder = LLVMDisposeBuilder;
    extern fn LLVMDisposeBuilder(Builder: *const BuilderRef) void;

    pub const positionBuilderAtEnd = LLVMPositionBuilderAtEnd;
    extern fn LLVMPositionBuilderAtEnd(Builder: *const BuilderRef, Block: *const BasicBlockRef) void;

    pub const getInsertBlock = LLVMGetInsertBlock;
    extern fn LLVMGetInsertBlock(Builder: *const BuilderRef) *const BasicBlockRef;

    pub const buildCall = LLVMBuildCall;
    extern fn LLVMBuildCall(*const BuilderRef, Fn: *const ValueRef, Args: ?[*]*const ValueRef, NumArgs: c_uint, Name: [*:0]const u8) *const ValueRef;

    pub const buildCall2 = LLVMBuildCall2;
    extern fn LLVMBuildCall2(*const BuilderRef, *const TypeRef, Fn: *const ValueRef, Args: [*]*const ValueRef, NumArgs: c_uint, Name: [*:0]const u8) *const ValueRef;

    pub const buildRetVoid = LLVMBuildRetVoid;
    extern fn LLVMBuildRetVoid(*const BuilderRef) *const ValueRef;

    pub const buildUnreachable = LLVMBuildUnreachable;
    extern fn LLVMBuildUnreachable(*const BuilderRef) *const ValueRef;

    pub const buildAlloca = LLVMBuildAlloca;
    extern fn LLVMBuildAlloca(*const BuilderRef, Ty: *const TypeRef, Name: [*:0]const u8) *const ValueRef;
};

pub const BasicBlockRef = opaque {
    pub const deleteBasicBlock = LLVMDeleteBasicBlock;
    extern fn LLVMDeleteBasicBlock(BB: *const BasicBlockRef) void;
};

pub const TargetMachineRef = opaque {
    pub const createTargetMachine = LLVMCreateTargetMachine;
    extern fn LLVMCreateTargetMachine(
        T: *const TargetRef,
        Triple: [*:0]const u8,
        CPU: [*:0]const u8,
        Features: [*:0]const u8,
        Level: CodeGenOptLevel,
        Reloc: RelocMode,
        CodeModel: CodeMode,
    ) *const TargetMachineRef;

    pub const disposeTargetMachine = LLVMDisposeTargetMachine;
    extern fn LLVMDisposeTargetMachine(T: *const TargetMachineRef) void;

    pub const emitToFile = LLVMTargetMachineEmitToFile;
    extern fn LLVMTargetMachineEmitToFile(*const TargetMachineRef, M: *const ModuleRef, Filename: [*:0]const u8, codegen: CodeGenFileType, ErrorMessage: *[*:0]const u8) LLVMBool;
};

pub const CodeMode = extern enum {
    Default,
    JITDefault,
    Tiny,
    Small,
    Kernel,
    Medium,
    Large,
};

pub const CodeGenOptLevel = extern enum {
    None,
    Less,
    Default,
    Aggressive,
};

pub const RelocMode = extern enum {
    Default,
    Static,
    PIC,
    DynamicNoPic,
    ROPI,
    RWPI,
    ROPI_RWPI,
};

pub const CodeGenFileType = extern enum {
    AssemblyFile,
    ObjectFile,
};

pub const TargetRef = opaque {
    pub const getTargetFromTriple = LLVMGetTargetFromTriple;
    extern fn LLVMGetTargetFromTriple(Triple: [*:0]const u8, T: **const TargetRef, ErrorMessage: *[*:0]const u8) LLVMBool;
};

extern fn LLVMInitializeAArch64TargetInfo() void;
extern fn LLVMInitializeAMDGPUTargetInfo() void;
extern fn LLVMInitializeARMTargetInfo() void;
extern fn LLVMInitializeAVRTargetInfo() void;
extern fn LLVMInitializeBPFTargetInfo() void;
extern fn LLVMInitializeHexagonTargetInfo() void;
extern fn LLVMInitializeLanaiTargetInfo() void;
extern fn LLVMInitializeMipsTargetInfo() void;
extern fn LLVMInitializeMSP430TargetInfo() void;
extern fn LLVMInitializeNVPTXTargetInfo() void;
extern fn LLVMInitializePowerPCTargetInfo() void;
extern fn LLVMInitializeRISCVTargetInfo() void;
extern fn LLVMInitializeSparcTargetInfo() void;
extern fn LLVMInitializeSystemZTargetInfo() void;
extern fn LLVMInitializeWebAssemblyTargetInfo() void;
extern fn LLVMInitializeX86TargetInfo() void;
extern fn LLVMInitializeXCoreTargetInfo() void;
extern fn LLVMInitializeAArch64Target() void;
extern fn LLVMInitializeAMDGPUTarget() void;
extern fn LLVMInitializeARMTarget() void;
extern fn LLVMInitializeAVRTarget() void;
extern fn LLVMInitializeBPFTarget() void;
extern fn LLVMInitializeHexagonTarget() void;
extern fn LLVMInitializeLanaiTarget() void;
extern fn LLVMInitializeMipsTarget() void;
extern fn LLVMInitializeMSP430Target() void;
extern fn LLVMInitializeNVPTXTarget() void;
extern fn LLVMInitializePowerPCTarget() void;
extern fn LLVMInitializeRISCVTarget() void;
extern fn LLVMInitializeSparcTarget() void;
extern fn LLVMInitializeSystemZTarget() void;
extern fn LLVMInitializeWebAssemblyTarget() void;
extern fn LLVMInitializeX86Target() void;
extern fn LLVMInitializeXCoreTarget() void;
extern fn LLVMInitializeAArch64TargetMC() void;
extern fn LLVMInitializeAMDGPUTargetMC() void;
extern fn LLVMInitializeARMTargetMC() void;
extern fn LLVMInitializeAVRTargetMC() void;
extern fn LLVMInitializeBPFTargetMC() void;
extern fn LLVMInitializeHexagonTargetMC() void;
extern fn LLVMInitializeLanaiTargetMC() void;
extern fn LLVMInitializeMipsTargetMC() void;
extern fn LLVMInitializeMSP430TargetMC() void;
extern fn LLVMInitializeNVPTXTargetMC() void;
extern fn LLVMInitializePowerPCTargetMC() void;
extern fn LLVMInitializeRISCVTargetMC() void;
extern fn LLVMInitializeSparcTargetMC() void;
extern fn LLVMInitializeSystemZTargetMC() void;
extern fn LLVMInitializeWebAssemblyTargetMC() void;
extern fn LLVMInitializeX86TargetMC() void;
extern fn LLVMInitializeXCoreTargetMC() void;
extern fn LLVMInitializeAArch64AsmPrinter() void;
extern fn LLVMInitializeAMDGPUAsmPrinter() void;
extern fn LLVMInitializeARMAsmPrinter() void;
extern fn LLVMInitializeAVRAsmPrinter() void;
extern fn LLVMInitializeBPFAsmPrinter() void;
extern fn LLVMInitializeHexagonAsmPrinter() void;
extern fn LLVMInitializeLanaiAsmPrinter() void;
extern fn LLVMInitializeMipsAsmPrinter() void;
extern fn LLVMInitializeMSP430AsmPrinter() void;
extern fn LLVMInitializeNVPTXAsmPrinter() void;
extern fn LLVMInitializePowerPCAsmPrinter() void;
extern fn LLVMInitializeRISCVAsmPrinter() void;
extern fn LLVMInitializeSparcAsmPrinter() void;
extern fn LLVMInitializeSystemZAsmPrinter() void;
extern fn LLVMInitializeWebAssemblyAsmPrinter() void;
extern fn LLVMInitializeX86AsmPrinter() void;
extern fn LLVMInitializeXCoreAsmPrinter() void;
extern fn LLVMInitializeAArch64AsmParser() void;
extern fn LLVMInitializeAMDGPUAsmParser() void;
extern fn LLVMInitializeARMAsmParser() void;
extern fn LLVMInitializeAVRAsmParser() void;
extern fn LLVMInitializeBPFAsmParser() void;
extern fn LLVMInitializeHexagonAsmParser() void;
extern fn LLVMInitializeLanaiAsmParser() void;
extern fn LLVMInitializeMipsAsmParser() void;
extern fn LLVMInitializeMSP430AsmParser() void;
extern fn LLVMInitializePowerPCAsmParser() void;
extern fn LLVMInitializeRISCVAsmParser() void;
extern fn LLVMInitializeSparcAsmParser() void;
extern fn LLVMInitializeSystemZAsmParser() void;
extern fn LLVMInitializeWebAssemblyAsmParser() void;
extern fn LLVMInitializeX86AsmParser() void;

pub const initializeAllTargetInfos = LLVMInitializeAllTargetInfos;
fn LLVMInitializeAllTargetInfos() callconv(.C) void {
    LLVMInitializeAArch64TargetInfo();
    LLVMInitializeAMDGPUTargetInfo();
    LLVMInitializeARMTargetInfo();
    LLVMInitializeAVRTargetInfo();
    LLVMInitializeBPFTargetInfo();
    LLVMInitializeHexagonTargetInfo();
    LLVMInitializeLanaiTargetInfo();
    LLVMInitializeMipsTargetInfo();
    LLVMInitializeMSP430TargetInfo();
    LLVMInitializeNVPTXTargetInfo();
    LLVMInitializePowerPCTargetInfo();
    LLVMInitializeRISCVTargetInfo();
    LLVMInitializeSparcTargetInfo();
    LLVMInitializeSystemZTargetInfo();
    LLVMInitializeWebAssemblyTargetInfo();
    LLVMInitializeX86TargetInfo();
    LLVMInitializeXCoreTargetInfo();
}
pub const initializeAllTargets = LLVMInitializeAllTargets;
fn LLVMInitializeAllTargets() callconv(.C) void {
    LLVMInitializeAArch64Target();
    LLVMInitializeAMDGPUTarget();
    LLVMInitializeARMTarget();
    LLVMInitializeAVRTarget();
    LLVMInitializeBPFTarget();
    LLVMInitializeHexagonTarget();
    LLVMInitializeLanaiTarget();
    LLVMInitializeMipsTarget();
    LLVMInitializeMSP430Target();
    LLVMInitializeNVPTXTarget();
    LLVMInitializePowerPCTarget();
    LLVMInitializeRISCVTarget();
    LLVMInitializeSparcTarget();
    LLVMInitializeSystemZTarget();
    LLVMInitializeWebAssemblyTarget();
    LLVMInitializeX86Target();
    LLVMInitializeXCoreTarget();
}
pub const initializeAllTargetMCs = LLVMInitializeAllTargetMCs;
fn LLVMInitializeAllTargetMCs() callconv(.C) void {
    LLVMInitializeAArch64TargetMC();
    LLVMInitializeAMDGPUTargetMC();
    LLVMInitializeARMTargetMC();
    LLVMInitializeAVRTargetMC();
    LLVMInitializeBPFTargetMC();
    LLVMInitializeHexagonTargetMC();
    LLVMInitializeLanaiTargetMC();
    LLVMInitializeMipsTargetMC();
    LLVMInitializeMSP430TargetMC();
    LLVMInitializeNVPTXTargetMC();
    LLVMInitializePowerPCTargetMC();
    LLVMInitializeRISCVTargetMC();
    LLVMInitializeSparcTargetMC();
    LLVMInitializeSystemZTargetMC();
    LLVMInitializeWebAssemblyTargetMC();
    LLVMInitializeX86TargetMC();
    LLVMInitializeXCoreTargetMC();
}
pub const initializeAllAsmPrinters = LLVMInitializeAllAsmPrinters;
fn LLVMInitializeAllAsmPrinters() callconv(.C) void {
    LLVMInitializeAArch64AsmPrinter();
    LLVMInitializeAMDGPUAsmPrinter();
    LLVMInitializeARMAsmPrinter();
    LLVMInitializeAVRAsmPrinter();
    LLVMInitializeBPFAsmPrinter();
    LLVMInitializeHexagonAsmPrinter();
    LLVMInitializeLanaiAsmPrinter();
    LLVMInitializeMipsAsmPrinter();
    LLVMInitializeMSP430AsmPrinter();
    LLVMInitializeNVPTXAsmPrinter();
    LLVMInitializePowerPCAsmPrinter();
    LLVMInitializeRISCVAsmPrinter();
    LLVMInitializeSparcAsmPrinter();
    LLVMInitializeSystemZAsmPrinter();
    LLVMInitializeWebAssemblyAsmPrinter();
    LLVMInitializeX86AsmPrinter();
    LLVMInitializeXCoreAsmPrinter();
}
pub const initializeAllAsmParsers = LLVMInitializeAllAsmParsers;
fn LLVMInitializeAllAsmParsers() callconv(.C) void {
    LLVMInitializeAArch64AsmParser();
    LLVMInitializeAMDGPUAsmParser();
    LLVMInitializeARMAsmParser();
    LLVMInitializeAVRAsmParser();
    LLVMInitializeBPFAsmParser();
    LLVMInitializeHexagonAsmParser();
    LLVMInitializeLanaiAsmParser();
    LLVMInitializeMipsAsmParser();
    LLVMInitializeMSP430AsmParser();
    LLVMInitializePowerPCAsmParser();
    LLVMInitializeRISCVAsmParser();
    LLVMInitializeSparcAsmParser();
    LLVMInitializeSystemZAsmParser();
    LLVMInitializeWebAssemblyAsmParser();
    LLVMInitializeX86AsmParser();
}

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
