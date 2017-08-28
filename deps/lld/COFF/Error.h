//===- Error.h --------------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_COFF_ERROR_H
#define LLD_COFF_ERROR_H

#include "lld/Core/LLVM.h"
#include "llvm/Support/Error.h"

namespace lld {
namespace coff {

extern uint64_t ErrorCount;
extern llvm::raw_ostream *ErrorOS;

void log(const Twine &Msg);
void message(const Twine &Msg);
void warn(const Twine &Msg);
void error(const Twine &Msg);
LLVM_ATTRIBUTE_NORETURN void fatal(const Twine &Msg);
LLVM_ATTRIBUTE_NORETURN void fatal(std::error_code EC, const Twine &Prefix);
LLVM_ATTRIBUTE_NORETURN void fatal(llvm::Error &Err, const Twine &Prefix);

template <class T> T check(ErrorOr<T> V, const Twine &Prefix) {
  if (auto EC = V.getError())
    fatal(EC, Prefix);
  return std::move(*V);
}

template <class T> T check(Expected<T> E, const Twine &Prefix) {
  if (llvm::Error Err = E.takeError())
    fatal(Err, Prefix);
  return std::move(*E);
}

template <class T> T check(ErrorOr<T> EO) {
  if (!EO)
    fatal(EO.getError().message());
  return std::move(*EO);
}

template <class T> T check(Expected<T> E) {
  if (!E) {
    std::string Buf;
    llvm::raw_string_ostream OS(Buf);
    logAllUnhandledErrors(E.takeError(), OS, "");
    OS.flush();
    fatal(Buf);
  }
  return std::move(*E);
}

} // namespace coff
} // namespace lld

#endif
