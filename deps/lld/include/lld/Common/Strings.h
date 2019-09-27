//===- Strings.h ------------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_STRINGS_H
#define LLD_STRINGS_H

#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/Optional.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/GlobPattern.h"
#include <string>
#include <vector>

namespace lld {
// Returns a demangled C++ symbol name. If Name is not a mangled
// name, it returns Optional::None.
llvm::Optional<std::string> demangleItanium(llvm::StringRef name);
llvm::Optional<std::string> demangleMSVC(llvm::StringRef s);

std::vector<uint8_t> parseHex(llvm::StringRef s);
bool isValidCIdentifier(llvm::StringRef s);

// Write the contents of the a buffer to a file
void saveBuffer(llvm::StringRef buffer, const llvm::Twine &path);

// This class represents multiple glob patterns.
class StringMatcher {
public:
  StringMatcher() = default;
  explicit StringMatcher(llvm::ArrayRef<llvm::StringRef> pat);

  bool match(llvm::StringRef s) const;

private:
  std::vector<llvm::GlobPattern> patterns;
};

} // namespace lld

#endif
