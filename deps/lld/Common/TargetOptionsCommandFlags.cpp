//===-- TargetOptionsCommandFlags.cpp ---------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file exists as a place for global variables defined in LLVM's
// CodeGen/CommandFlags.inc. By putting the resulting object file in
// an archive and linking with it, the definitions will automatically be
// included when needed and skipped when already present.
//
//===----------------------------------------------------------------------===//

#include "lld/Common/TargetOptionsCommandFlags.h"

#include "llvm/CodeGen/CommandFlags.inc"
#include "llvm/Target/TargetOptions.h"

// Define an externally visible version of
// initTargetOptionsFromCodeGenFlags, so that its functionality can be
// used without having to include llvm/CodeGen/CommandFlags.inc, which
// would lead to multiple definitions of the command line flags.
llvm::TargetOptions lld::initTargetOptionsFromCodeGenFlags() {
  return ::InitTargetOptionsFromCodeGenFlags();
}

llvm::Optional<llvm::CodeModel::Model> lld::getCodeModelFromCMModel() {
  return getCodeModel();
}

std::string lld::getCPUStr() { return ::getCPUStr(); }

std::vector<std::string> lld::getMAttrs() { return ::MAttrs; }
