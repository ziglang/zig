//===- Error.cpp ----------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "Error.h"
#include "Config.h"

#include "llvm/ADT/Twine.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/ManagedStatic.h"
#include "llvm/Support/Process.h"
#include "llvm/Support/raw_ostream.h"
#include <mutex>

#if !defined(_MSC_VER) && !defined(__MINGW32__)
#include <unistd.h>
#endif

using namespace llvm;

namespace lld {
// The functions defined in this file can be called from multiple threads,
// but outs() or errs() are not thread-safe. We protect them using a mutex.
static std::mutex Mu;

namespace coff {
uint64_t ErrorCount;
raw_ostream *ErrorOS;

LLVM_ATTRIBUTE_NORETURN void exitLld(int Val) {
  // Dealloc/destroy ManagedStatic variables before calling
  // _exit(). In a non-LTO build, this is a nop. In an LTO
  // build allows us to get the output of -time-passes.
  llvm_shutdown();

  outs().flush();
  errs().flush();
  _exit(Val);
}

static void print(StringRef S, raw_ostream::Colors C) {
  *ErrorOS << Config->Argv[0] << ": ";
  if (Config->ColorDiagnostics) {
    ErrorOS->changeColor(C, true);
    *ErrorOS << S;
    ErrorOS->resetColor();
  } else {
    *ErrorOS << S;
  }
}

void log(const Twine &Msg) {
  if (Config->Verbose) {
    std::lock_guard<std::mutex> Lock(Mu);
    outs() << Config->Argv[0] << ": " << Msg << "\n";
    outs().flush();
  }
}

void message(const Twine &Msg) {
  std::lock_guard<std::mutex> Lock(Mu);
  outs() << Msg << "\n";
  outs().flush();
}

void error(const Twine &Msg) {
  std::lock_guard<std::mutex> Lock(Mu);

  if (Config->ErrorLimit == 0 || ErrorCount < Config->ErrorLimit) {
    print("error: ", raw_ostream::RED);
    *ErrorOS << Msg << "\n";
  } else if (ErrorCount == Config->ErrorLimit) {
    print("error: ", raw_ostream::RED);
    *ErrorOS << "too many errors emitted, stopping now"
             << " (use /ERRORLIMIT:0 to see all errors)\n";
    if (Config->CanExitEarly)
      exitLld(1);
  }

  ++ErrorCount;
}

void fatal(const Twine &Msg) {
  if (Config->ColorDiagnostics) {
    errs().changeColor(raw_ostream::RED, /*bold=*/true);
    errs() << "error: ";
    errs().resetColor();
  } else {
    errs() << "error: ";
  }
  errs() << Msg << "\n";
  exitLld(1);
}

void fatal(std::error_code EC, const Twine &Msg) {
  fatal(Msg + ": " + EC.message());
}

void fatal(llvm::Error &Err, const Twine &Msg) {
  fatal(errorToErrorCode(std::move(Err)), Msg);
}

void warn(const Twine &Msg) {
  std::lock_guard<std::mutex> Lock(Mu);
  print("warning: ", raw_ostream::MAGENTA);
  *ErrorOS << Msg << "\n";
}

} // namespace coff
} // namespace lld
