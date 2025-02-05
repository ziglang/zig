/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_ZIG_LLVM_HPP
#define ZIG_ZIG_LLVM_HPP

#include <stdbool.h>
#include <stddef.h>
#include <llvm-c/Core.h>
#include <llvm-c/Analysis.h>
#include <llvm-c/Target.h>
#include <llvm-c/TargetMachine.h>

#ifdef __cplusplus
#define ZIG_EXTERN_C extern "C"
#else
#define ZIG_EXTERN_C
#endif

// ATTENTION: If you modify this file, be sure to update the corresponding
// extern function declarations in the self-hosted compiler.

// synchronize with llvm/include/Transforms/Instrumentation.h::SanitizerCoverageOptions::Type
// synchronize with codegen/llvm/bindings.zig::TargetMachine::EmitOptions::Coverage::Type
enum ZigLLVMCoverageType {
    ZigLLVMCoverageType_None = 0,
    ZigLLVMCoverageType_Function,
    ZigLLVMCoverageType_BB,
    ZigLLVMCoverageType_Edge
};

struct ZigLLVMCoverageOptions {
    ZigLLVMCoverageType CoverageType;
    bool IndirectCalls;
    bool TraceBB;
    bool TraceCmp;
    bool TraceDiv;
    bool TraceGep;
    bool Use8bitCounters;
    bool TracePC;
    bool TracePCGuard;
    bool Inline8bitCounters;
    bool InlineBoolFlag;
    bool PCTable;
    bool NoPrune;
    bool StackDepth;
    bool TraceLoads;
    bool TraceStores;
    bool CollectControlFlow;
};

// synchronize with llvm/include/Pass.h::ThinOrFullLTOPhase
// synchronize with codegen/llvm/bindings.zig::EmitOptions::LtoPhase
enum ZigLLVMThinOrFullLTOPhase {
    ZigLLVMThinOrFullLTOPhase_None,
    ZigLLVMThinOrFullLTOPhase_ThinPreLink,
    ZigLLVMThinOrFullLTOPhase_ThinkPostLink,
    ZigLLVMThinOrFullLTOPhase_FullPreLink,
    ZigLLVMThinOrFullLTOPhase_FullPostLink,
};

struct ZigLLVMEmitOptions {
    bool is_debug;
    bool is_small;
    bool time_report;
    bool tsan;
    bool sancov;
    ZigLLVMThinOrFullLTOPhase lto;
    bool allow_fast_isel;
    const char *asm_filename;
    const char *bin_filename;
    const char *llvm_ir_filename;
    const char *bitcode_filename;
    ZigLLVMCoverageOptions coverage;
};

// synchronize with llvm/include/Object/Archive.h::Object::Archive::Kind
// synchronize with codegen/llvm/bindings.zig::ArchiveKind
enum ZigLLVMArchiveKind {
    ZigLLVMArchiveKind_GNU,
    ZigLLVMArchiveKind_GNU64,
    ZigLLVMArchiveKind_BSD,
    ZigLLVMArchiveKind_DARWIN,
    ZigLLVMArchiveKind_DARWIN64,
    ZigLLVMArchiveKind_COFF,
    ZigLLVMArchiveKind_AIXBIG,
};

// synchronize with llvm/include/Target/TargetOptions.h::FloatABI::ABIType
// synchronize with codegen/llvm/bindings.zig::TargetMachine::FloatABI
enum ZigLLVMFloatABI {
    ZigLLVMFloatABI_Default, // Target-specific (either soft or hard depending on triple, etc).
    ZigLLVMFloatABI_Soft,    // Soft float.
    ZigLLVMFloatABI_Hard     // Hard float.
};

ZIG_EXTERN_C bool ZigLLVMTargetMachineEmitToFile(LLVMTargetMachineRef targ_machine_ref, LLVMModuleRef module_ref,
    char **error_message, const ZigLLVMEmitOptions *options);

ZIG_EXTERN_C LLVMTargetMachineRef ZigLLVMCreateTargetMachine(LLVMTargetRef T, const char *Triple,
    const char *CPU, const char *Features, LLVMCodeGenOptLevel Level, LLVMRelocMode Reloc,
    LLVMCodeModel CodeModel, bool function_sections, bool data_sections, ZigLLVMFloatABI float_abi,
    const char *abi_name);

ZIG_EXTERN_C void ZigLLVMSetOptBisectLimit(LLVMContextRef context_ref, int limit);

ZIG_EXTERN_C void ZigLLVMEnableBrokenDebugInfoCheck(LLVMContextRef context_ref);
ZIG_EXTERN_C bool ZigLLVMGetBrokenDebugInfo(LLVMContextRef context_ref);

ZIG_EXTERN_C void ZigLLVMParseCommandLineOptions(size_t argc, const char *const *argv);

ZIG_EXTERN_C bool ZigLLDLinkCOFF(int argc, const char **argv, bool can_exit_early, bool disable_output);
ZIG_EXTERN_C bool ZigLLDLinkELF(int argc, const char **argv, bool can_exit_early, bool disable_output);
ZIG_EXTERN_C bool ZigLLDLinkWasm(int argc, const char **argv, bool can_exit_early, bool disable_output);

ZIG_EXTERN_C bool ZigLLVMWriteArchive(const char *archive_name, const char **file_names, size_t file_name_count,
    ZigLLVMArchiveKind archive_kind);

ZIG_EXTERN_C bool ZigLLVMWriteImportLibrary(const char *def_path, unsigned int coff_machine,
    const char *output_lib_path, bool kill_at);

#endif
