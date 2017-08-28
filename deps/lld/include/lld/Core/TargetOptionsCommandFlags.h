//===-- TargetOptionsCommandFlags.h ----------------------------*- C++ -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// Helper to create TargetOptions from command line flags.
//
//===----------------------------------------------------------------------===//

#include "llvm/Support/CodeGen.h"
#include "llvm/Target/TargetOptions.h"

namespace lld {
llvm::TargetOptions InitTargetOptionsFromCodeGenFlags();
llvm::CodeModel::Model GetCodeModelFromCMModel();
}
