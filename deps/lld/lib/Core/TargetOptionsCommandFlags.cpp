//===-- TargetOptionsCommandFlags.cpp ---------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file exists as a place for global variables defined in LLVM's
// CodeGen/CommandFlags.h. By putting the resulting object file in
// an archive and linking with it, the definitions will automatically be
// included when needed and skipped when already present.
//
//===----------------------------------------------------------------------===//

#include "lld/Core/TargetOptionsCommandFlags.h"

#include "llvm/CodeGen/CommandFlags.h"
#include "llvm/Target/TargetOptions.h"

// Define an externally visible version of
// InitTargetOptionsFromCodeGenFlags, so that its functionality can be
// used without having to include llvm/CodeGen/CommandFlags.h, which
// would lead to multiple definitions of the command line flags.
llvm::TargetOptions lld::InitTargetOptionsFromCodeGenFlags() {
  return ::InitTargetOptionsFromCodeGenFlags();
}

llvm::CodeModel::Model lld::GetCodeModelFromCMModel() {
  return CMModel;
}
