//===--- LLVM.h - Import various common LLVM datatypes ----------*- C++ -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file forward declares and imports various common LLVM datatypes that
// lld wants to use unqualified.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_CORE_LLVM_H
#define LLD_CORE_LLVM_H

// This should be the only #include, force #includes of all the others on
// clients.
#include "llvm/ADT/Hashing.h"
#include "llvm/Support/Casting.h"
#include <utility>

namespace llvm {
  // ADT's.
  class Error;
  class StringRef;
  class Twine;
  class MemoryBuffer;
  class MemoryBufferRef;
  template<typename T> class ArrayRef;
  template<unsigned InternalLen> class SmallString;
  template<typename T, unsigned N> class SmallVector;
  template<typename T> class SmallVectorImpl;

  template<typename T>
  struct SaveAndRestore;

  template<typename T>
  class ErrorOr;

  template<typename T>
  class Expected;

  class raw_ostream;
  // TODO: DenseMap, ...
}

namespace lld {
  // Casting operators.
  using llvm::isa;
  using llvm::cast;
  using llvm::dyn_cast;
  using llvm::dyn_cast_or_null;
  using llvm::cast_or_null;

  // ADT's.
  using llvm::Error;
  using llvm::StringRef;
  using llvm::Twine;
  using llvm::MemoryBuffer;
  using llvm::MemoryBufferRef;
  using llvm::ArrayRef;
  using llvm::SmallString;
  using llvm::SmallVector;
  using llvm::SmallVectorImpl;
  using llvm::SaveAndRestore;
  using llvm::ErrorOr;
  using llvm::Expected;

  using llvm::raw_ostream;
} // end namespace lld.

namespace std {
template <> struct hash<llvm::StringRef> {
public:
  size_t operator()(const llvm::StringRef &s) const {
    return llvm::hash_value(s);
  }
};
}

#endif
