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

struct LLVMZigDIType;
struct LLVMZigDIBuilder;
struct LLVMZigDICompileUnit;
struct LLVMZigDIScope;
struct LLVMZigDIFile;
struct LLVMZigDILexicalBlock;
struct LLVMZigDISubprogram;
struct LLVMZigDISubroutineType;
struct LLVMZigDILocalVariable;
struct LLVMZigDILocation;
struct LLVMZigDIEnumerator;
struct LLVMZigInsertionPoint;

void LLVMZigInitializeLoopStrengthReducePass(LLVMPassRegistryRef R);
void LLVMZigInitializeLowerIntrinsicsPass(LLVMPassRegistryRef R);
void LLVMZigInitializeUnreachableBlockElimPass(LLVMPassRegistryRef R);

char *LLVMZigGetHostCPUName(void);
char *LLVMZigGetNativeFeatures(void);

void LLVMZigOptimizeModule(LLVMTargetMachineRef targ_machine_ref, LLVMModuleRef module_ref);

LLVMValueRef LLVMZigBuildCall(LLVMBuilderRef B, LLVMValueRef Fn, LLVMValueRef *Args,
        unsigned NumArgs, unsigned CC, const char *Name);

// 0 is return value, 1 is first arg
void LLVMZigAddNonNullAttr(LLVMValueRef fn, unsigned i);

LLVMZigDIType *LLVMZigCreateDebugPointerType(LLVMZigDIBuilder *dibuilder, LLVMZigDIType *pointee_type,
        uint64_t size_in_bits, uint64_t align_in_bits, const char *name);

LLVMZigDIType *LLVMZigCreateDebugBasicType(LLVMZigDIBuilder *dibuilder, const char *name,
        uint64_t size_in_bits, uint64_t align_in_bits, unsigned encoding);

LLVMZigDIType *LLVMZigCreateDebugArrayType(LLVMZigDIBuilder *dibuilder,
        uint64_t size_in_bits, uint64_t align_in_bits, LLVMZigDIType *elem_type,
        int elem_count);

LLVMZigDIEnumerator *LLVMZigCreateDebugEnumerator(LLVMZigDIBuilder *dibuilder, const char *name, int64_t val);

LLVMZigDIType *LLVMZigCreateDebugEnumerationType(LLVMZigDIBuilder *dibuilder, LLVMZigDIScope *scope,
        const char *name, LLVMZigDIFile *file, unsigned line_number, uint64_t size_in_bits,
        uint64_t align_in_bits, LLVMZigDIEnumerator **enumerator_array, int enumerator_array_len,
        LLVMZigDIType *underlying_type, const char *unique_id);

LLVMZigDIType *LLVMZigCreateDebugStructType(LLVMZigDIBuilder *dibuilder, LLVMZigDIScope *scope,
        const char *name, LLVMZigDIFile *file, unsigned line_number, uint64_t size_in_bits,
        uint64_t align_in_bits, unsigned flags, LLVMZigDIType *derived_from, 
        LLVMZigDIType **types_array, int types_array_len, unsigned run_time_lang, LLVMZigDIType *vtable_holder,
        const char *unique_id);

LLVMZigDIType *LLVMZigCreateDebugUnionType(LLVMZigDIBuilder *dibuilder, LLVMZigDIScope *scope,
        const char *name, LLVMZigDIFile *file, unsigned line_number, uint64_t size_in_bits,
        uint64_t align_in_bits, unsigned flags, LLVMZigDIType **types_array, int types_array_len,
        unsigned run_time_lang, const char *unique_id);

LLVMZigDIType *LLVMZigCreateDebugMemberType(LLVMZigDIBuilder *dibuilder, LLVMZigDIScope *scope,
        const char *name, LLVMZigDIFile *file, unsigned line, uint64_t size_in_bits,
        uint64_t align_in_bits, uint64_t offset_in_bits, unsigned flags, LLVMZigDIType *type);

LLVMZigDIType *LLVMZigCreateReplaceableCompositeType(LLVMZigDIBuilder *dibuilder, unsigned tag,
        const char *name, LLVMZigDIScope *scope, LLVMZigDIFile *file, unsigned line);

LLVMZigDIType *LLVMZigCreateDebugForwardDeclType(LLVMZigDIBuilder *dibuilder, unsigned tag,
        const char *name, LLVMZigDIScope *scope, LLVMZigDIFile *file, unsigned line);

void LLVMZigReplaceTemporary(LLVMZigDIBuilder *dibuilder, LLVMZigDIType *type,
        LLVMZigDIType *replacement);

void LLVMZigReplaceDebugArrays(LLVMZigDIBuilder *dibuilder, LLVMZigDIType *type,
        LLVMZigDIType **types_array, int types_array_len);

LLVMZigDIType *LLVMZigCreateSubroutineType(LLVMZigDIBuilder *dibuilder_wrapped,
        LLVMZigDIType **types_array, int types_array_len, unsigned flags);

unsigned LLVMZigEncoding_DW_ATE_unsigned(void);
unsigned LLVMZigEncoding_DW_ATE_signed(void);
unsigned LLVMZigEncoding_DW_ATE_float(void);
unsigned LLVMZigEncoding_DW_ATE_boolean(void);
unsigned LLVMZigEncoding_DW_ATE_unsigned_char(void);
unsigned LLVMZigEncoding_DW_ATE_signed_char(void);
unsigned LLVMZigLang_DW_LANG_C99(void);
unsigned LLVMZigTag_DW_variable(void);
unsigned LLVMZigTag_DW_structure_type(void);

LLVMZigDIBuilder *LLVMZigCreateDIBuilder(LLVMModuleRef module, bool allow_unresolved);

void LLVMZigSetCurrentDebugLocation(LLVMBuilderRef builder, int line, int column, LLVMZigDIScope *scope);

LLVMZigDIScope *LLVMZigLexicalBlockToScope(LLVMZigDILexicalBlock *lexical_block);
LLVMZigDIScope *LLVMZigCompileUnitToScope(LLVMZigDICompileUnit *compile_unit);
LLVMZigDIScope *LLVMZigFileToScope(LLVMZigDIFile *difile);
LLVMZigDIScope *LLVMZigSubprogramToScope(LLVMZigDISubprogram *subprogram);
LLVMZigDIScope *LLVMZigTypeToScope(LLVMZigDIType *type);

LLVMZigDILocalVariable *LLVMZigCreateAutoVariable(LLVMZigDIBuilder *dbuilder,
        LLVMZigDIScope *scope, const char *name, LLVMZigDIFile *file, unsigned line_no,
        LLVMZigDIType *type, bool always_preserve, unsigned flags);

LLVMZigDILocalVariable *LLVMZigCreateParameterVariable(LLVMZigDIBuilder *dbuilder,
        LLVMZigDIScope *scope, const char *name, LLVMZigDIFile *file, unsigned line_no,
        LLVMZigDIType *type, bool always_preserve, unsigned flags, unsigned arg_no);

LLVMZigDILexicalBlock *LLVMZigCreateLexicalBlock(LLVMZigDIBuilder *dbuilder, LLVMZigDIScope *scope,
        LLVMZigDIFile *file, unsigned line, unsigned col);

LLVMZigDICompileUnit *LLVMZigCreateCompileUnit(LLVMZigDIBuilder *dibuilder,
        unsigned lang, const char *file, const char *dir, const char *producer,
        bool is_optimized, const char *flags, unsigned runtime_version, const char *split_name,
        uint64_t dwo_id, bool emit_debug_info);

LLVMZigDIFile *LLVMZigCreateFile(LLVMZigDIBuilder *dibuilder, const char *filename, const char *directory);

LLVMZigDISubprogram *LLVMZigCreateFunction(LLVMZigDIBuilder *dibuilder, LLVMZigDIScope *scope,
        const char *name, const char *linkage_name, LLVMZigDIFile *file, unsigned lineno,
        LLVMZigDIType *fn_di_type, bool is_local_to_unit, bool is_definition, unsigned scope_line,
        unsigned flags, bool is_optimized, LLVMZigDISubprogram *decl_subprogram);

void LLVMZigDIBuilderFinalize(LLVMZigDIBuilder *dibuilder);

LLVMZigInsertionPoint *LLVMZigSaveInsertPoint(LLVMBuilderRef builder);
void LLVMZigRestoreInsertPoint(LLVMBuilderRef builder, LLVMZigInsertionPoint *point);

LLVMValueRef LLVMZigInsertDeclareAtEnd(LLVMZigDIBuilder *dibuilder, LLVMValueRef storage,
        LLVMZigDILocalVariable *var_info, LLVMZigDILocation *debug_loc, LLVMBasicBlockRef basic_block_ref);
LLVMValueRef LLVMZigInsertDeclare(LLVMZigDIBuilder *dibuilder, LLVMValueRef storage,
        LLVMZigDILocalVariable *var_info, LLVMZigDILocation *debug_loc, LLVMValueRef insert_before_instr);
LLVMZigDILocation *LLVMZigGetDebugLoc(unsigned line, unsigned col, LLVMZigDIScope *scope);

void LLVMZigSetFastMath(LLVMBuilderRef builder_wrapped, bool on_state);


// copied from include/llvm/ADT/Triple.h

enum ZigLLVM_ArchType {
  ZigLLVM_UnknownArch,

  ZigLLVM_arm,        // ARM (little endian): arm, armv.*, xscale
  ZigLLVM_armeb,      // ARM (big endian): armeb
  ZigLLVM_aarch64,    // AArch64 (little endian): aarch64
  ZigLLVM_aarch64_be, // AArch64 (big endian): aarch64_be
  ZigLLVM_avr,        // AVR: Atmel AVR microcontroller
  ZigLLVM_bpfel,      // eBPF or extended BPF or 64-bit BPF (little endian)
  ZigLLVM_bpfeb,      // eBPF or extended BPF or 64-bit BPF (big endian)
  ZigLLVM_hexagon,    // Hexagon: hexagon
  ZigLLVM_mips,       // MIPS: mips, mipsallegrex
  ZigLLVM_mipsel,     // MIPSEL: mipsel, mipsallegrexel
  ZigLLVM_mips64,     // MIPS64: mips64
  ZigLLVM_mips64el,   // MIPS64EL: mips64el
  ZigLLVM_msp430,     // MSP430: msp430
  ZigLLVM_ppc,        // PPC: powerpc
  ZigLLVM_ppc64,      // PPC64: powerpc64, ppu
  ZigLLVM_ppc64le,    // PPC64LE: powerpc64le
  ZigLLVM_r600,       // R600: AMD GPUs HD2XXX - HD6XXX
  ZigLLVM_amdgcn,     // AMDGCN: AMD GCN GPUs
  ZigLLVM_sparc,      // Sparc: sparc
  ZigLLVM_sparcv9,    // Sparcv9: Sparcv9
  ZigLLVM_sparcel,    // Sparc: (endianness = little). NB: 'Sparcle' is a CPU variant
  ZigLLVM_systemz,    // SystemZ: s390x
  ZigLLVM_tce,        // TCE (http://tce.cs.tut.fi/): tce
  ZigLLVM_thumb,      // Thumb (little endian): thumb, thumbv.*
  ZigLLVM_thumbeb,    // Thumb (big endian): thumbeb
  ZigLLVM_x86,        // X86: i[3-9]86
  ZigLLVM_x86_64,     // X86-64: amd64, x86_64
  ZigLLVM_xcore,      // XCore: xcore
  ZigLLVM_nvptx,      // NVPTX: 32-bit
  ZigLLVM_nvptx64,    // NVPTX: 64-bit
  ZigLLVM_le32,       // le32: generic little-endian 32-bit CPU (PNaCl)
  ZigLLVM_le64,       // le64: generic little-endian 64-bit CPU (PNaCl)
  ZigLLVM_amdil,      // AMDIL
  ZigLLVM_amdil64,    // AMDIL with 64-bit pointers
  ZigLLVM_hsail,      // AMD HSAIL
  ZigLLVM_hsail64,    // AMD HSAIL with 64-bit pointers
  ZigLLVM_spir,       // SPIR: standard portable IR for OpenCL 32-bit version
  ZigLLVM_spir64,     // SPIR: standard portable IR for OpenCL 64-bit version
  ZigLLVM_kalimba,    // Kalimba: generic kalimba
  ZigLLVM_shave,      // SHAVE: Movidius vector VLIW processors
  ZigLLVM_wasm32,     // WebAssembly with 32-bit pointers
  ZigLLVM_wasm64,     // WebAssembly with 64-bit pointers

  ZigLLVM_LastArchType = ZigLLVM_wasm64
};

enum ZigLLVM_SubArchType {
  ZigLLVM_NoSubArch,

  ZigLLVM_ARMSubArch_v8_2a,
  ZigLLVM_ARMSubArch_v8_1a,
  ZigLLVM_ARMSubArch_v8,
  ZigLLVM_ARMSubArch_v7,
  ZigLLVM_ARMSubArch_v7em,
  ZigLLVM_ARMSubArch_v7m,
  ZigLLVM_ARMSubArch_v7s,
  ZigLLVM_ARMSubArch_v7k,
  ZigLLVM_ARMSubArch_v6,
  ZigLLVM_ARMSubArch_v6m,
  ZigLLVM_ARMSubArch_v6k,
  ZigLLVM_ARMSubArch_v6t2,
  ZigLLVM_ARMSubArch_v5,
  ZigLLVM_ARMSubArch_v5te,
  ZigLLVM_ARMSubArch_v4t,

  ZigLLVM_KalimbaSubArch_v3,
  ZigLLVM_KalimbaSubArch_v4,
  ZigLLVM_KalimbaSubArch_v5
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

  ZigLLVM_LastVendorType = ZigLLVM_Myriad
};
enum ZigLLVM_OSType {
  ZigLLVM_UnknownOS,

  ZigLLVM_CloudABI,
  ZigLLVM_Darwin,
  ZigLLVM_DragonFly,
  ZigLLVM_FreeBSD,
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

  ZigLLVM_LastOSType = ZigLLVM_WatchOS
};
enum ZigLLVM_EnvironmentType {
  ZigLLVM_UnknownEnvironment,

  ZigLLVM_GNU,
  ZigLLVM_GNUEABI,
  ZigLLVM_GNUEABIHF,
  ZigLLVM_GNUX32,
  ZigLLVM_CODE16,
  ZigLLVM_EABI,
  ZigLLVM_EABIHF,
  ZigLLVM_Android,

  ZigLLVM_MSVC,
  ZigLLVM_Itanium,
  ZigLLVM_Cygnus,
  ZigLLVM_AMDOpenCL,
  ZigLLVM_CoreCLR,
  ZigLLVM_LastEnvironmentType = ZigLLVM_CoreCLR
};
enum ZigLLVM_ObjectFormatType {
    ZigLLVM_UnknownObjectFormat,

    ZigLLVM_COFF,
    ZigLLVM_ELF,
    ZigLLVM_MachO,
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
void ZigLLVMGetNativeTarget(ZigLLVM_ArchType *arch_type, ZigLLVM_SubArchType *sub_arch_type,
        ZigLLVM_VendorType *vendor_type, ZigLLVM_OSType *os_type, ZigLLVM_EnvironmentType *environ_type,
        ZigLLVM_ObjectFormatType *oformat);
void ZigLLVMGetTargetTriple(Buf *out_buf, ZigLLVM_ArchType arch_type, ZigLLVM_SubArchType sub_arch_type,
        ZigLLVM_VendorType vendor_type, ZigLLVM_OSType os_type, ZigLLVM_EnvironmentType environ_type,
        ZigLLVM_ObjectFormatType oformat);


Buf *get_dynamic_linker(LLVMTargetMachineRef target_machine);

#endif
