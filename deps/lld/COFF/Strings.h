//===- Strings.h ------------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_COFF_STRINGS_H
#define LLD_COFF_STRINGS_H

#include "llvm/ADT/Optional.h"
#include "llvm/ADT/StringRef.h"
#include <string>

namespace lld {
namespace coff {
llvm::Optional<std::string> demangleMSVC(llvm::StringRef S);
}
}

#endif
