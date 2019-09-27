//===- Strings.cpp -------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "lld/Common/Strings.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/LLVM.h"
#include "llvm/Demangle/Demangle.h"
#include "llvm/Support/GlobPattern.h"
#include <algorithm>
#include <mutex>
#include <vector>

using namespace llvm;
using namespace lld;

// Returns the demangled C++ symbol name for Name.
Optional<std::string> lld::demangleItanium(StringRef name) {
  // itaniumDemangle can be used to demangle strings other than symbol
  // names which do not necessarily start with "_Z". Name can be
  // either a C or C++ symbol. Don't call itaniumDemangle if the name
  // does not look like a C++ symbol name to avoid getting unexpected
  // result for a C symbol that happens to match a mangled type name.
  if (!name.startswith("_Z"))
    return None;

  char *buf = itaniumDemangle(name.str().c_str(), nullptr, nullptr, nullptr);
  if (!buf)
    return None;
  std::string s(buf);
  free(buf);
  return s;
}

Optional<std::string> lld::demangleMSVC(StringRef name) {
  std::string prefix;
  if (name.consume_front("__imp_"))
    prefix = "__declspec(dllimport) ";

  // Demangle only C++ names.
  if (!name.startswith("?"))
    return None;

  char *buf = microsoftDemangle(name.str().c_str(), nullptr, nullptr, nullptr);
  if (!buf)
    return None;
  std::string s(buf);
  free(buf);
  return prefix + s;
}

StringMatcher::StringMatcher(ArrayRef<StringRef> pat) {
  for (StringRef s : pat) {
    Expected<GlobPattern> pat = GlobPattern::create(s);
    if (!pat)
      error(toString(pat.takeError()));
    else
      patterns.push_back(*pat);
  }
}

bool StringMatcher::match(StringRef s) const {
  for (const GlobPattern &pat : patterns)
    if (pat.match(s))
      return true;
  return false;
}

// Converts a hex string (e.g. "deadbeef") to a vector.
std::vector<uint8_t> lld::parseHex(StringRef s) {
  std::vector<uint8_t> hex;
  while (!s.empty()) {
    StringRef b = s.substr(0, 2);
    s = s.substr(2);
    uint8_t h;
    if (!to_integer(b, h, 16)) {
      error("not a hexadecimal value: " + b);
      return {};
    }
    hex.push_back(h);
  }
  return hex;
}

// Returns true if S is valid as a C language identifier.
bool lld::isValidCIdentifier(StringRef s) {
  return !s.empty() && (isAlpha(s[0]) || s[0] == '_') &&
         std::all_of(s.begin() + 1, s.end(),
                     [](char c) { return c == '_' || isAlnum(c); });
}

// Write the contents of the a buffer to a file
void lld::saveBuffer(StringRef buffer, const Twine &path) {
  std::error_code ec;
  raw_fd_ostream os(path.str(), ec, sys::fs::OpenFlags::F_None);
  if (ec)
    error("cannot create " + path + ": " + ec.message());
  os << buffer;
}
