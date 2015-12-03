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
struct LLVMZigInsertionPoint;

void LLVMZigInitializeLoopStrengthReducePass(LLVMPassRegistryRef R);
void LLVMZigInitializeLowerIntrinsicsPass(LLVMPassRegistryRef R);
void LLVMZigInitializeUnreachableBlockElimPass(LLVMPassRegistryRef R);

char *LLVMZigGetHostCPUName(void);
char *LLVMZigGetNativeFeatures(void);

void LLVMZigOptimizeModule(LLVMTargetMachineRef targ_machine_ref, LLVMModuleRef module_ref);

LLVMValueRef LLVMZigBuildCall(LLVMBuilderRef B, LLVMValueRef Fn, LLVMValueRef *Args,
        unsigned NumArgs, unsigned CC, const char *Name);


LLVMZigDIType *LLVMZigCreateDebugPointerType(LLVMZigDIBuilder *dibuilder, LLVMZigDIType *pointee_type,
        uint64_t size_in_bits, uint64_t align_in_bits, const char *name);

LLVMZigDIType *LLVMZigCreateDebugBasicType(LLVMZigDIBuilder *dibuilder, const char *name,
        uint64_t size_in_bits, uint64_t align_in_bits, unsigned encoding);

LLVMZigDISubroutineType *LLVMZigCreateSubroutineType(LLVMZigDIBuilder *dibuilder_wrapped,
        LLVMZigDIFile *file, LLVMZigDIType **types_array, int types_array_len, unsigned flags);

unsigned LLVMZigEncoding_DW_ATE_unsigned(void);
unsigned LLVMZigEncoding_DW_ATE_signed(void);
unsigned LLVMZigLang_DW_LANG_C99(void);

LLVMZigDIBuilder *LLVMZigCreateDIBuilder(LLVMModuleRef module, bool allow_unresolved);

void LLVMZigSetCurrentDebugLocation(LLVMBuilderRef builder, int line, int column, LLVMZigDIScope *scope);

LLVMZigDIScope *LLVMZigLexicalBlockToScope(LLVMZigDILexicalBlock *lexical_block);
LLVMZigDIScope *LLVMZigCompileUnitToScope(LLVMZigDICompileUnit *compile_unit);
LLVMZigDIScope *LLVMZigFileToScope(LLVMZigDIFile *difile);
LLVMZigDIScope *LLVMZigSubprogramToScope(LLVMZigDISubprogram *subprogram);

LLVMZigDILexicalBlock *LLVMZigCreateLexicalBlock(LLVMZigDIBuilder *dbuilder, LLVMZigDIScope *scope,
        LLVMZigDIFile *file, unsigned line, unsigned col);

LLVMZigDICompileUnit *LLVMZigCreateCompileUnit(LLVMZigDIBuilder *dibuilder,
        unsigned lang, const char *file, const char *dir, const char *producer,
        bool is_optimized, const char *flags, unsigned runtime_version, const char *split_name,
        uint64_t dwo_id, bool emit_debug_info);

LLVMZigDIFile *LLVMZigCreateFile(LLVMZigDIBuilder *dibuilder, const char *filename, const char *directory);

LLVMZigDISubprogram *LLVMZigCreateFunction(LLVMZigDIBuilder *dibuilder, LLVMZigDIScope *scope,
        const char *name, const char *linkage_name, LLVMZigDIFile *file, unsigned lineno,
        LLVMZigDISubroutineType *ty, bool is_local_to_unit, bool is_definition, unsigned scope_line,
        unsigned flags, bool is_optimized, LLVMValueRef function);

void LLVMZigDIBuilderFinalize(LLVMZigDIBuilder *dibuilder);

LLVMZigInsertionPoint *LLVMZigSaveInsertPoint(LLVMBuilderRef builder);
void LLVMZigRestoreInsertPoint(LLVMBuilderRef builder, LLVMZigInsertionPoint *point);


/*
 * This stuff is not LLVM API but it depends on the LLVM C++ API so we put it here.
 */
#include "buffer.hpp"

Buf *get_dynamic_linker(LLVMTargetMachineRef target_machine);

#endif
