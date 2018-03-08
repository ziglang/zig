//===- Strings.h ------------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_ELF_STRINGS_H
#define LLD_ELF_STRINGS_H

#include "lld/Common/LLVM.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/BitVector.h"
#include "llvm/ADT/Optional.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/GlobPattern.h"
#include <vector>

namespace lld {
namespace elf {

std::vector<uint8_t> parseHex(StringRef S);
bool isValidCIdentifier(StringRef S);

// This is a lazy version of StringRef. String size is computed lazily
// when it is needed. It is more efficient than StringRef to instantiate
// if you have a string whose size is unknown.
//
// ELF string tables contain a lot of null-terminated strings.
// Most of them are not necessary for the linker because they are names
// of local symbols and the linker doesn't use local symbol names for
// name resolution. So, we use this class to represents strings read
// from string tables.
class StringRefZ {
public:
  StringRefZ() : Start(nullptr), Size(0) {}
  StringRefZ(const char *S, size_t Size) : Start(S), Size(Size) {}

  /*implicit*/ StringRefZ(const char *S) : Start(S), Size(-1) {}

  /*implicit*/ StringRefZ(llvm::StringRef S)
      : Start(S.data()), Size(S.size()) {}

  operator llvm::StringRef() const {
    if (Size == (size_t)-1)
      Size = strlen(Start);
    return {Start, Size};
  }

private:
  const char *Start;
  mutable size_t Size;
};

// This class represents multiple glob patterns.
class StringMatcher {
public:
  StringMatcher() = default;
  explicit StringMatcher(ArrayRef<StringRef> Pat);

  bool match(StringRef S) const;

private:
  std::vector<llvm::GlobPattern> Patterns;
};

inline ArrayRef<uint8_t> toArrayRef(StringRef S) {
  return {(const uint8_t *)S.data(), S.size()};
}
} // namespace elf
} // namespace lld

#endif
