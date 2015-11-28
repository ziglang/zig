/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "zig_llvm.hpp"

#include <llvm/InitializePasses.h>
#include <llvm/PassRegistry.h>
#include <llvm/MC/SubtargetFeature.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Target/TargetMachine.h>
#include <llvm/IR/LegacyPassManager.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/Verifier.h>
#include <llvm/IR/Instructions.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/Analysis/TargetLibraryInfo.h>
#include <llvm/Analysis/TargetTransformInfo.h>
#include <llvm/Transforms/IPO.h>
#include <llvm/Transforms/IPO/PassManagerBuilder.h>
#include <llvm/Transforms/Scalar.h>

using namespace llvm;

void LLVMZigInitializeLoopStrengthReducePass(LLVMPassRegistryRef R) {
    initializeLoopStrengthReducePass(*unwrap(R));
}

void LLVMZigInitializeLowerIntrinsicsPass(LLVMPassRegistryRef R) {
    initializeLowerIntrinsicsPass(*unwrap(R));
}

void LLVMZigInitializeUnreachableBlockElimPass(LLVMPassRegistryRef R) {
    initializeUnreachableBlockElimPass(*unwrap(R));
}

char *LLVMZigGetHostCPUName(void) {
    std::string str = sys::getHostCPUName();
    return strdup(str.c_str());
}

char *LLVMZigGetNativeFeatures(void) {
    SubtargetFeatures features;

    StringMap<bool> host_features;
    if (sys::getHostCPUFeatures(host_features)) {
        for (auto &F : host_features)
            features.AddFeature(F.first(), F.second);
    }

    return strdup(features.getString().c_str());
}

static void addAddDiscriminatorsPass(const PassManagerBuilder &Builder, legacy::PassManagerBase &PM) {
  PM.add(createAddDiscriminatorsPass());
}


void LLVMZigOptimizeModule(LLVMTargetMachineRef targ_machine_ref, LLVMModuleRef module_ref) {
    TargetMachine* target_machine = reinterpret_cast<TargetMachine*>(targ_machine_ref);
    Module* module = unwrap(module_ref);
    TargetLibraryInfoImpl tlii(Triple(module->getTargetTriple()));

    PassManagerBuilder *PMBuilder = new PassManagerBuilder();
    PMBuilder->OptLevel = target_machine->getOptLevel();
    PMBuilder->SizeLevel = 0;
    PMBuilder->BBVectorize = true;
    PMBuilder->SLPVectorize = true;
    PMBuilder->LoopVectorize = true;

    PMBuilder->DisableUnitAtATime = false;
    PMBuilder->DisableUnrollLoops = false;
    PMBuilder->MergeFunctions = true;
    PMBuilder->PrepareForLTO = true;
    PMBuilder->RerollLoops = true;

    PMBuilder->addExtension(PassManagerBuilder::EP_EarlyAsPossible, addAddDiscriminatorsPass);

    PMBuilder->LibraryInfo = &tlii;

    PMBuilder->Inliner = createFunctionInliningPass(PMBuilder->OptLevel, PMBuilder->SizeLevel);

    // Set up the per-function pass manager.
    legacy::FunctionPassManager *FPM = new legacy::FunctionPassManager(module);
    FPM->add(createTargetTransformInfoWrapperPass(target_machine->getTargetIRAnalysis()));
#ifndef NDEBUG
    bool verify_module = true;
#else
    bool verify_module = false;
#endif
    if (verify_module) {
        FPM->add(createVerifierPass());
    }
    PMBuilder->populateFunctionPassManager(*FPM);

    // Set up the per-module pass manager.
    legacy::PassManager *MPM = new legacy::PassManager();
    MPM->add(createTargetTransformInfoWrapperPass(target_machine->getTargetIRAnalysis()));

    PMBuilder->populateModulePassManager(*MPM);


    // run per function optimization passes
    FPM->doInitialization();
    for (Function &F : *module)
      if (!F.isDeclaration())
        FPM->run(F);
    FPM->doFinalization();

    // run per module optimization passes
    MPM->run(*module);
}

static LLVMBool LLVMZigTargetMachineEmit(LLVMTargetMachineRef targ_machine_ref, LLVMModuleRef module_ref,
        raw_pwrite_stream &out_stream, LLVMCodeGenFileType codegen, char **err_msg)
{
    TargetMachine* target_machine = reinterpret_cast<TargetMachine*>(targ_machine_ref);
    Module* module = unwrap(module_ref);
    TargetLibraryInfoImpl tlii(Triple(module->getTargetTriple()));

    legacy::PassManager pass;

    pass.add(new TargetLibraryInfoWrapperPass(tlii));

    const DataLayout *td = target_machine->getDataLayout();

    if (!td) {
        *err_msg = strdup("No DataLayout in TargetMachine");
        return true;
    }
    module->setDataLayout(*td);


    TargetMachine::CodeGenFileType ft;
    switch (codegen) {
        case LLVMAssemblyFile:
            ft = TargetMachine::CGFT_AssemblyFile;
            break;
        default:
            ft = TargetMachine::CGFT_ObjectFile;
            break;
    }
    if (target_machine->addPassesToEmitFile(pass, out_stream, ft)) {
        *err_msg = strdup("TargetMachine can't emit a file of this type");
        return true;
    }

    pass.run(*module);

    out_stream.flush();
    return false;
}

LLVMBool LLVMZigTargetMachineEmitToFile(LLVMTargetMachineRef targ_machine_ref, LLVMModuleRef module_ref,
        const char* filename, LLVMCodeGenFileType codegen, char** err_msg)
{
    std::error_code error_code;
    raw_fd_ostream dest(filename, error_code, sys::fs::F_None);
    if (error_code) {
        *err_msg = strdup(error_code.message().c_str());
        return true;
    }
    return LLVMZigTargetMachineEmit(targ_machine_ref, module_ref, dest, codegen, err_msg);
}

LLVMValueRef LLVMZigBuildCall(LLVMBuilderRef B, LLVMValueRef Fn, LLVMValueRef *Args,
        unsigned NumArgs, unsigned CC, const char *Name)
{
    CallInst *call_inst = CallInst::Create(unwrap(Fn), makeArrayRef(unwrap(Args), NumArgs), Name);
    call_inst->setCallingConv(CC);
    return wrap(unwrap(B)->Insert(call_inst));
}
