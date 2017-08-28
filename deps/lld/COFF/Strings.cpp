//===- Strings.cpp -------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "Strings.h"
#include <mutex>

#if defined(_MSC_VER)
#include <Windows.h>
#include <DbgHelp.h>
#pragma comment(lib, "dbghelp.lib")
#endif

using namespace lld;
using namespace lld::coff;
using namespace llvm;

Optional<std::string> coff::demangle(StringRef S) {
#if defined(_MSC_VER)
  // UnDecorateSymbolName is not thread-safe, so we need a mutex.
  static std::mutex Mu;
  std::lock_guard<std::mutex> Lock(Mu);

  char Buf[4096];
  if (S.startswith("?"))
    if (size_t Len = UnDecorateSymbolName(S.str().c_str(), Buf, sizeof(Buf), 0))
      return std::string(Buf, Len);
#endif
  return None;
}
