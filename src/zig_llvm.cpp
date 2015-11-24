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
