//===- ErrorHandler.h -------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// In LLD, we have three levels of errors: fatal, error or warn.
//
// Fatal makes the program exit immediately with an error message.
// You shouldn't use it except for reporting a corrupted input file.
//
// Error prints out an error message and increment a global variable
// ErrorCount to record the fact that we met an error condition. It does
// not exit, so it is safe for a lld-as-a-library use case. It is generally
// useful because it can report more than one error in a single run.
//
// Warn doesn't do anything but printing out a given message.
//
// It is not recommended to use llvm::outs() or llvm::errs() directly
// in LLD because they are not thread-safe. The functions declared in
// this file are mutually excluded, so you want to use them instead.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_COMMON_ERRORHANDLER_H
#define LLD_COMMON_ERRORHANDLER_H

#include "lld/Common/LLVM.h"

#include "llvm/ADT/STLExtras.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/FileOutputBuffer.h"

namespace lld {

class ErrorHandler {
public:
  uint64_t ErrorCount = 0;
  uint64_t ErrorLimit = 20;
  StringRef ErrorLimitExceededMsg = "too many errors emitted, stopping now";
  StringRef LogName = "lld";
  llvm::raw_ostream *ErrorOS = &llvm::errs();
  bool ColorDiagnostics = llvm::errs().has_colors();
  bool ExitEarly = true;
  bool FatalWarnings = false;
  bool Verbose = false;

  void error(const Twine &Msg);
  LLVM_ATTRIBUTE_NORETURN void fatal(const Twine &Msg);
  void log(const Twine &Msg);
  void message(const Twine &Msg);
  void warn(const Twine &Msg);

  std::unique_ptr<llvm::FileOutputBuffer> OutputBuffer;

private:
  void print(StringRef S, raw_ostream::Colors C);
};

/// Returns the default error handler.
ErrorHandler &errorHandler();

inline void error(const Twine &Msg) { errorHandler().error(Msg); }
inline LLVM_ATTRIBUTE_NORETURN void fatal(const Twine &Msg) {
  errorHandler().fatal(Msg);
}
inline void log(const Twine &Msg) { errorHandler().log(Msg); }
inline void message(const Twine &Msg) { errorHandler().message(Msg); }
inline void warn(const Twine &Msg) { errorHandler().warn(Msg); }
inline uint64_t errorCount() { return errorHandler().ErrorCount; }

LLVM_ATTRIBUTE_NORETURN void exitLld(int Val);

// check functions are convenient functions to strip errors
// from error-or-value objects.
template <class T> T check(ErrorOr<T> E) {
  if (auto EC = E.getError())
    fatal(EC.message());
  return std::move(*E);
}

template <class T> T check(Expected<T> E) {
  if (!E)
    fatal(llvm::toString(E.takeError()));
  return std::move(*E);
}

template <class T>
T check2(ErrorOr<T> E, llvm::function_ref<std::string()> Prefix) {
  if (auto EC = E.getError())
    fatal(Prefix() + ": " + EC.message());
  return std::move(*E);
}

template <class T>
T check2(Expected<T> E, llvm::function_ref<std::string()> Prefix) {
  if (!E)
    fatal(Prefix() + ": " + toString(E.takeError()));
  return std::move(*E);
}

inline std::string toString(const Twine &S) { return S.str(); }

// To evaluate the second argument lazily, we use C macro.
#define CHECK(E, S) check2(E, [&] { return toString(S); })

} // namespace lld

#endif
