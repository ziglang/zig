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

void LLVMZigInitializeLoopStrengthReducePass(LLVMPassRegistryRef R);
void LLVMZigInitializeLowerIntrinsicsPass(LLVMPassRegistryRef R);
void LLVMZigInitializeUnreachableBlockElimPass(LLVMPassRegistryRef R);

char *LLVMZigGetHostCPUName(void);
char *LLVMZigGetNativeFeatures(void);

LLVMBool LLVMZigTargetMachineEmitToFile(LLVMTargetMachineRef target_machine, LLVMModuleRef module,
        const char* filename, LLVMCodeGenFileType codegen, char** error_msg);

void LLVMZigOptimizeModule(LLVMTargetMachineRef targ_machine_ref, LLVMModuleRef module_ref);

LLVMValueRef LLVMZigBuildCall(LLVMBuilderRef B, LLVMValueRef Fn, LLVMValueRef *Args,
        unsigned NumArgs, unsigned CC, const char *Name);

#endif
