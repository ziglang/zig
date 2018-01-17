//===- Strings.cpp -------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "Strings.h"
#include "Config.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/Twine.h"
#include "llvm/Demangle/Demangle.h"
#include <algorithm>
#include <cstring>

using namespace llvm;
using namespace lld;
using namespace lld::elf;

StringMatcher::StringMatcher(ArrayRef<StringRef> Pat) {
  for (StringRef S : Pat) {
    Expected<GlobPattern> Pat = GlobPattern::create(S);
    if (!Pat)
      error(toString(Pat.takeError()));
    else
      Patterns.push_back(*Pat);
  }
}

bool StringMatcher::match(StringRef S) const {
  for (const GlobPattern &Pat : Patterns)
    if (Pat.match(S))
      return true;
  return false;
}

// Converts a hex string (e.g. "deadbeef") to a vector.
std::vector<uint8_t> elf::parseHex(StringRef S) {
  std::vector<uint8_t> Hex;
  while (!S.empty()) {
    StringRef B = S.substr(0, 2);
    S = S.substr(2);
    uint8_t H;
    if (!to_integer(B, H, 16)) {
      error("not a hexadecimal value: " + B);
      return {};
    }
    Hex.push_back(H);
  }
  return Hex;
}

// Returns true if S is valid as a C language identifier.
bool elf::isValidCIdentifier(StringRef S) {
  return !S.empty() && (isAlpha(S[0]) || S[0] == '_') &&
         std::all_of(S.begin() + 1, S.end(),
                     [](char C) { return C == '_' || isAlnum(C); });
}
