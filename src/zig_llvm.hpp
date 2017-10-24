/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_ZIG_LLVM_HPP
#define ZIG_ZIG_LLVM_HPP

#include <llvm-c/Core.h>
#include <llvm-c/Analysis.h>
#include <llvm-c/Target.h>
#include <llvm-c/Initialization.h>
#include <llvm-c/TargetMachine.h>

struct ZigLLVMDIType;
struct ZigLLVMDIBuilder;
struct ZigLLVMDICompileUnit;
struct ZigLLVMDIScope;
struct ZigLLVMDIFile;
struct ZigLLVMDILexicalBlock;
struct ZigLLVMDISubprogram;
struct ZigLLVMDISubroutineType;
struct ZigLLVMDILocalVariable;
struct ZigLLVMDIGlobalVariable;
struct ZigLLVMDILocation;
struct ZigLLVMDIEnumerator;
struct ZigLLVMInsertionPoint;

void ZigLLVMInitializeLoopStrengthReducePass(LLVMPassRegistryRef R);
void ZigLLVMInitializeLowerIntrinsicsPass(LLVMPassRegistryRef R);

char *ZigLLVMGetHostCPUName(void);
char *ZigLLVMGetNativeFeatures(void);

bool ZigLLVMTargetMachineEmitToFile(LLVMTargetMachineRef targ_machine_ref, LLVMModuleRef module_ref,
        const char *filename, LLVMCodeGenFileType file_type, char **error_message, bool is_debug);

LLVMValueRef ZigLLVMBuildCall(LLVMBuilderRef B, LLVMValueRef Fn, LLVMValueRef *Args,
        unsigned NumArgs, unsigned CC, bool always_inline, const char *Name);

LLVMValueRef ZigLLVMBuildCmpXchg(LLVMBuilderRef builder, LLVMValueRef ptr, LLVMValueRef cmp,
        LLVMValueRef new_val, LLVMAtomicOrdering success_ordering,
        LLVMAtomicOrdering failure_ordering);

LLVMValueRef ZigLLVMBuildNSWShl(LLVMBuilderRef builder, LLVMValueRef LHS, LLVMValueRef RHS,
        const char *name);
LLVMValueRef ZigLLVMBuildNUWShl(LLVMBuilderRef builder, LLVMValueRef LHS, LLVMValueRef RHS,
        const char *name);
LLVMValueRef ZigLLVMBuildLShrExact(LLVMBuilderRef builder, LLVMValueRef LHS, LLVMValueRef RHS,
        const char *name);
LLVMValueRef ZigLLVMBuildAShrExact(LLVMBuilderRef builder, LLVMValueRef LHS, LLVMValueRef RHS,
        const char *name);

ZigLLVMDIType *ZigLLVMCreateDebugPointerType(ZigLLVMDIBuilder *dibuilder, ZigLLVMDIType *pointee_type,
        uint64_t size_in_bits, uint64_t align_in_bits, const char *name);

ZigLLVMDIType *ZigLLVMCreateDebugBasicType(ZigLLVMDIBuilder *dibuilder, const char *name,
        uint64_t size_in_bits, unsigned encoding);

ZigLLVMDIType *ZigLLVMCreateDebugArrayType(ZigLLVMDIBuilder *dibuilder,
        uint64_t size_in_bits, uint64_t align_in_bits, ZigLLVMDIType *elem_type,
        int elem_count);

ZigLLVMDIEnumerator *ZigLLVMCreateDebugEnumerator(ZigLLVMDIBuilder *dibuilder, const char *name, int64_t val);

ZigLLVMDIType *ZigLLVMCreateDebugEnumerationType(ZigLLVMDIBuilder *dibuilder, ZigLLVMDIScope *scope,
        const char *name, ZigLLVMDIFile *file, unsigned line_number, uint64_t size_in_bits,
        uint64_t align_in_bits, ZigLLVMDIEnumerator **enumerator_array, int enumerator_array_len,
        ZigLLVMDIType *underlying_type, const char *unique_id);

ZigLLVMDIType *ZigLLVMCreateDebugStructType(ZigLLVMDIBuilder *dibuilder, ZigLLVMDIScope *scope,
        const char *name, ZigLLVMDIFile *file, unsigned line_number, uint64_t size_in_bits,
        uint64_t align_in_bits, unsigned flags, ZigLLVMDIType *derived_from,
        ZigLLVMDIType **types_array, int types_array_len, unsigned run_time_lang, ZigLLVMDIType *vtable_holder,
        const char *unique_id);

ZigLLVMDIType *ZigLLVMCreateDebugUnionType(ZigLLVMDIBuilder *dibuilder, ZigLLVMDIScope *scope,
        const char *name, ZigLLVMDIFile *file, unsigned line_number, uint64_t size_in_bits,
        uint64_t align_in_bits, unsigned flags, ZigLLVMDIType **types_array, int types_array_len,
        unsigned run_time_lang, const char *unique_id);

ZigLLVMDIType *ZigLLVMCreateDebugMemberType(ZigLLVMDIBuilder *dibuilder, ZigLLVMDIScope *scope,
        const char *name, ZigLLVMDIFile *file, unsigned line, uint64_t size_in_bits,
        uint64_t align_in_bits, uint64_t offset_in_bits, unsigned flags, ZigLLVMDIType *type);

ZigLLVMDIType *ZigLLVMCreateReplaceableCompositeType(ZigLLVMDIBuilder *dibuilder, unsigned tag,
        const char *name, ZigLLVMDIScope *scope, ZigLLVMDIFile *file, unsigned line);

ZigLLVMDIType *ZigLLVMCreateDebugForwardDeclType(ZigLLVMDIBuilder *dibuilder, unsigned tag,
        const char *name, ZigLLVMDIScope *scope, ZigLLVMDIFile *file, unsigned line);

void ZigLLVMReplaceTemporary(ZigLLVMDIBuilder *dibuilder, ZigLLVMDIType *type,
        ZigLLVMDIType *replacement);

void ZigLLVMReplaceDebugArrays(ZigLLVMDIBuilder *dibuilder, ZigLLVMDIType *type,
        ZigLLVMDIType **types_array, int types_array_len);

ZigLLVMDIType *ZigLLVMCreateSubroutineType(ZigLLVMDIBuilder *dibuilder_wrapped,
        ZigLLVMDIType **types_array, int types_array_len, unsigned flags);

unsigned ZigLLVMEncoding_DW_ATE_unsigned(void);
unsigned ZigLLVMEncoding_DW_ATE_signed(void);
unsigned ZigLLVMEncoding_DW_ATE_float(void);
unsigned ZigLLVMEncoding_DW_ATE_boolean(void);
unsigned ZigLLVMEncoding_DW_ATE_unsigned_char(void);
unsigned ZigLLVMEncoding_DW_ATE_signed_char(void);
unsigned ZigLLVMLang_DW_LANG_C99(void);
unsigned ZigLLVMTag_DW_variable(void);
unsigned ZigLLVMTag_DW_structure_type(void);

ZigLLVMDIBuilder *ZigLLVMCreateDIBuilder(LLVMModuleRef module, bool allow_unresolved);
void ZigLLVMAddModuleDebugInfoFlag(LLVMModuleRef module);
void ZigLLVMAddModuleCodeViewFlag(LLVMModuleRef module);

void ZigLLVMSetCurrentDebugLocation(LLVMBuilderRef builder, int line, int column, ZigLLVMDIScope *scope);
void ZigLLVMClearCurrentDebugLocation(LLVMBuilderRef builder);

ZigLLVMDIScope *ZigLLVMLexicalBlockToScope(ZigLLVMDILexicalBlock *lexical_block);
ZigLLVMDIScope *ZigLLVMCompileUnitToScope(ZigLLVMDICompileUnit *compile_unit);
ZigLLVMDIScope *ZigLLVMFileToScope(ZigLLVMDIFile *difile);
ZigLLVMDIScope *ZigLLVMSubprogramToScope(ZigLLVMDISubprogram *subprogram);
ZigLLVMDIScope *ZigLLVMTypeToScope(ZigLLVMDIType *type);

ZigLLVMDILocalVariable *ZigLLVMCreateAutoVariable(ZigLLVMDIBuilder *dbuilder,
        ZigLLVMDIScope *scope, const char *name, ZigLLVMDIFile *file, unsigned line_no,
        ZigLLVMDIType *type, bool always_preserve, unsigned flags);

ZigLLVMDIGlobalVariable *ZigLLVMCreateGlobalVariable(ZigLLVMDIBuilder *dbuilder,
    ZigLLVMDIScope *scope, const char *name, const char *linkage_name, ZigLLVMDIFile *file,
    unsigned line_no, ZigLLVMDIType *di_type, bool is_local_to_unit);

ZigLLVMDILocalVariable *ZigLLVMCreateParameterVariable(ZigLLVMDIBuilder *dbuilder,
        ZigLLVMDIScope *scope, const char *name, ZigLLVMDIFile *file, unsigned line_no,
        ZigLLVMDIType *type, bool always_preserve, unsigned flags, unsigned arg_no);

ZigLLVMDILexicalBlock *ZigLLVMCreateLexicalBlock(ZigLLVMDIBuilder *dbuilder, ZigLLVMDIScope *scope,
        ZigLLVMDIFile *file, unsigned line, unsigned col);

ZigLLVMDICompileUnit *ZigLLVMCreateCompileUnit(ZigLLVMDIBuilder *dibuilder,
        unsigned lang, ZigLLVMDIFile *difile, const char *producer,
        bool is_optimized, const char *flags, unsigned runtime_version, const char *split_name,
        uint64_t dwo_id, bool emit_debug_info);

ZigLLVMDIFile *ZigLLVMCreateFile(ZigLLVMDIBuilder *dibuilder, const char *filename, const char *directory);

ZigLLVMDISubprogram *ZigLLVMCreateFunction(ZigLLVMDIBuilder *dibuilder, ZigLLVMDIScope *scope,
        const char *name, const char *linkage_name, ZigLLVMDIFile *file, unsigned lineno,
        ZigLLVMDIType *fn_di_type, bool is_local_to_unit, bool is_definition, unsigned scope_line,
        unsigned flags, bool is_optimized, ZigLLVMDISubprogram *decl_subprogram);

void ZigLLVMFnSetSubprogram(LLVMValueRef fn, ZigLLVMDISubprogram *subprogram);

void ZigLLVMDIBuilderFinalize(ZigLLVMDIBuilder *dibuilder);

LLVMValueRef ZigLLVMInsertDeclareAtEnd(ZigLLVMDIBuilder *dibuilder, LLVMValueRef storage,
        ZigLLVMDILocalVariable *var_info, ZigLLVMDILocation *debug_loc, LLVMBasicBlockRef basic_block_ref);
LLVMValueRef ZigLLVMInsertDeclare(ZigLLVMDIBuilder *dibuilder, LLVMValueRef storage,
        ZigLLVMDILocalVariable *var_info, ZigLLVMDILocation *debug_loc, LLVMValueRef insert_before_instr);
ZigLLVMDILocation *ZigLLVMGetDebugLoc(unsigned line, unsigned col, ZigLLVMDIScope *scope);

void ZigLLVMSetFastMath(LLVMBuilderRef builder_wrapped, bool on_state);

void ZigLLVMAddFunctionAttr(LLVMValueRef fn, const char *attr_name, const char *attr_value);
void ZigLLVMAddFunctionAttrCold(LLVMValueRef fn);

void ZigLLVMParseCommandLineOptions(int argc, const char *const *argv);


// copied from include/llvm/ADT/Triple.h

enum ZigLLVM_ArchType {
    ZigLLVM_UnknownArch,

    ZigLLVM_arm,            // ARM (little endian): arm, armv.*, xscale
    ZigLLVM_armeb,          // ARM (big endian): armeb
    ZigLLVM_aarch64,        // AArch64 (little endian): aarch64
    ZigLLVM_aarch64_be,     // AArch64 (big endian): aarch64_be
    ZigLLVM_arc,            // ARC: Synopsys ARC
    ZigLLVM_avr,            // AVR: Atmel AVR microcontroller
    ZigLLVM_bpfel,          // eBPF or extended BPF or 64-bit BPF (little endian)
    ZigLLVM_bpfeb,          // eBPF or extended BPF or 64-bit BPF (big endian)
    ZigLLVM_hexagon,        // Hexagon: hexagon
    ZigLLVM_mips,           // MIPS: mips, mipsallegrex
    ZigLLVM_mipsel,         // MIPSEL: mipsel, mipsallegrexel
    ZigLLVM_mips64,         // MIPS64: mips64
    ZigLLVM_mips64el,       // MIPS64EL: mips64el
    ZigLLVM_msp430,         // MSP430: msp430
    ZigLLVM_nios2,          // NIOSII: nios2
    ZigLLVM_ppc,            // PPC: powerpc
    ZigLLVM_ppc64,          // PPC64: powerpc64, ppu
    ZigLLVM_ppc64le,        // PPC64LE: powerpc64le
    ZigLLVM_r600,           // R600: AMD GPUs HD2XXX - HD6XXX
    ZigLLVM_amdgcn,         // AMDGCN: AMD GCN GPUs
    ZigLLVM_riscv32,        // RISC-V (32-bit): riscv32
    ZigLLVM_riscv64,        // RISC-V (64-bit): riscv64
    ZigLLVM_sparc,          // Sparc: sparc
    ZigLLVM_sparcv9,        // Sparcv9: Sparcv9
    ZigLLVM_sparcel,        // Sparc: (endianness = little). NB: 'Sparcle' is a CPU variant
    ZigLLVM_systemz,        // SystemZ: s390x
    ZigLLVM_tce,            // TCE (http://tce.cs.tut.fi/): tce
    ZigLLVM_tcele,          // TCE little endian (http://tce.cs.tut.fi/): tcele
    ZigLLVM_thumb,          // Thumb (little endian): thumb, thumbv.*
    ZigLLVM_thumbeb,        // Thumb (big endian): thumbeb
    ZigLLVM_x86,            // X86: i[3-9]86
    ZigLLVM_x86_64,         // X86-64: amd64, x86_64
    ZigLLVM_xcore,          // XCore: xcore
    ZigLLVM_nvptx,          // NVPTX: 32-bit
    ZigLLVM_nvptx64,        // NVPTX: 64-bit
    ZigLLVM_le32,           // le32: generic little-endian 32-bit CPU (PNaCl)
    ZigLLVM_le64,           // le64: generic little-endian 64-bit CPU (PNaCl)
    ZigLLVM_amdil,          // AMDIL
    ZigLLVM_amdil64,        // AMDIL with 64-bit pointers
    ZigLLVM_hsail,          // AMD HSAIL
    ZigLLVM_hsail64,        // AMD HSAIL with 64-bit pointers
    ZigLLVM_spir,           // SPIR: standard portable IR for OpenCL 32-bit version
    ZigLLVM_spir64,         // SPIR: standard portable IR for OpenCL 64-bit version
    ZigLLVM_kalimba,        // Kalimba: generic kalimba
    ZigLLVM_shave,          // SHAVE: Movidius vector VLIW processors
    ZigLLVM_lanai,          // Lanai: Lanai 32-bit
    ZigLLVM_wasm32,         // WebAssembly with 32-bit pointers
    ZigLLVM_wasm64,         // WebAssembly with 64-bit pointers
    ZigLLVM_renderscript32, // 32-bit RenderScript
    ZigLLVM_renderscript64, // 64-bit RenderScript

    ZigLLVM_LastArchType = ZigLLVM_renderscript64
};

enum ZigLLVM_SubArchType {
    ZigLLVM_NoSubArch,

    ZigLLVM_ARMSubArch_v8_3a,
    ZigLLVM_ARMSubArch_v8_2a,
    ZigLLVM_ARMSubArch_v8_1a,
    ZigLLVM_ARMSubArch_v8,
    ZigLLVM_ARMSubArch_v8r,
    ZigLLVM_ARMSubArch_v8m_baseline,
    ZigLLVM_ARMSubArch_v8m_mainline,
    ZigLLVM_ARMSubArch_v7,
    ZigLLVM_ARMSubArch_v7em,
    ZigLLVM_ARMSubArch_v7m,
    ZigLLVM_ARMSubArch_v7s,
    ZigLLVM_ARMSubArch_v7k,
    ZigLLVM_ARMSubArch_v7ve,
    ZigLLVM_ARMSubArch_v6,
    ZigLLVM_ARMSubArch_v6m,
    ZigLLVM_ARMSubArch_v6k,
    ZigLLVM_ARMSubArch_v6t2,
    ZigLLVM_ARMSubArch_v5,
    ZigLLVM_ARMSubArch_v5te,
    ZigLLVM_ARMSubArch_v4t,

    ZigLLVM_KalimbaSubArch_v3,
    ZigLLVM_KalimbaSubArch_v4,
    ZigLLVM_KalimbaSubArch_v5,
};

enum ZigLLVM_VendorType {
    ZigLLVM_UnknownVendor,

    ZigLLVM_Apple,
    ZigLLVM_PC,
    ZigLLVM_SCEI,
    ZigLLVM_BGP,
    ZigLLVM_BGQ,
    ZigLLVM_Freescale,
    ZigLLVM_IBM,
    ZigLLVM_ImaginationTechnologies,
    ZigLLVM_MipsTechnologies,
    ZigLLVM_NVIDIA,
    ZigLLVM_CSR,
    ZigLLVM_Myriad,
    ZigLLVM_AMD,
    ZigLLVM_Mesa,
    ZigLLVM_SUSE,

    ZigLLVM_LastVendorType = ZigLLVM_SUSE
};

enum ZigLLVM_OSType {
    ZigLLVM_UnknownOS,

    ZigLLVM_Ananas,
    ZigLLVM_CloudABI,
    ZigLLVM_Darwin,
    ZigLLVM_DragonFly,
    ZigLLVM_FreeBSD,
    ZigLLVM_Fuchsia,
    ZigLLVM_IOS,
    ZigLLVM_KFreeBSD,
    ZigLLVM_Linux,
    ZigLLVM_Lv2,        // PS3
    ZigLLVM_MacOSX,
    ZigLLVM_NetBSD,
    ZigLLVM_OpenBSD,
    ZigLLVM_Solaris,
    ZigLLVM_Win32,
    ZigLLVM_Haiku,
    ZigLLVM_Minix,
    ZigLLVM_RTEMS,
    ZigLLVM_NaCl,       // Native Client
    ZigLLVM_CNK,        // BG/P Compute-Node Kernel
    ZigLLVM_Bitrig,
    ZigLLVM_AIX,
    ZigLLVM_CUDA,       // NVIDIA CUDA
    ZigLLVM_NVCL,       // NVIDIA OpenCL
    ZigLLVM_AMDHSA,     // AMD HSA Runtime
    ZigLLVM_PS4,
    ZigLLVM_ELFIAMCU,
    ZigLLVM_TvOS,       // Apple tvOS
    ZigLLVM_WatchOS,    // Apple watchOS
    ZigLLVM_Mesa3D,
    ZigLLVM_Contiki,

    ZigLLVM_LastOSType = ZigLLVM_Contiki
};

enum ZigLLVM_EnvironmentType {
    ZigLLVM_UnknownEnvironment,

    ZigLLVM_GNU,
    ZigLLVM_GNUABIN32,
    ZigLLVM_GNUABI64,
    ZigLLVM_GNUEABI,
    ZigLLVM_GNUEABIHF,
    ZigLLVM_GNUX32,
    ZigLLVM_CODE16,
    ZigLLVM_EABI,
    ZigLLVM_EABIHF,
    ZigLLVM_Android,
    ZigLLVM_Musl,
    ZigLLVM_MuslEABI,
    ZigLLVM_MuslEABIHF,

    ZigLLVM_MSVC,
    ZigLLVM_Itanium,
    ZigLLVM_Cygnus,
    ZigLLVM_AMDOpenCL,
    ZigLLVM_CoreCLR,
    ZigLLVM_OpenCL,

    ZigLLVM_LastEnvironmentType = ZigLLVM_OpenCL
};

enum ZigLLVM_ObjectFormatType {
    ZigLLVM_UnknownObjectFormat,

    ZigLLVM_COFF,
    ZigLLVM_ELF,
    ZigLLVM_MachO,
    ZigLLVM_Wasm,
};

const char *ZigLLVMGetArchTypeName(ZigLLVM_ArchType arch);
const char *ZigLLVMGetSubArchTypeName(ZigLLVM_SubArchType sub_arch);
const char *ZigLLVMGetVendorTypeName(ZigLLVM_VendorType vendor);
const char *ZigLLVMGetOSTypeName(ZigLLVM_OSType os);
const char *ZigLLVMGetEnvironmentTypeName(ZigLLVM_EnvironmentType env_type);

/*
 * This stuff is not LLVM API but it depends on the LLVM C++ API so we put it here.
 */
struct Buf;

bool ZigLLDLink(ZigLLVM_ObjectFormatType oformat, const char **args, size_t arg_count, Buf *diag);

void ZigLLVMGetNativeTarget(ZigLLVM_ArchType *arch_type, ZigLLVM_SubArchType *sub_arch_type,
        ZigLLVM_VendorType *vendor_type, ZigLLVM_OSType *os_type, ZigLLVM_EnvironmentType *environ_type,
        ZigLLVM_ObjectFormatType *oformat);

#endif
