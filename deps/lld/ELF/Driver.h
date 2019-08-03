//===- Driver.h -------------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_ELF_DRIVER_H
#define LLD_ELF_DRIVER_H

#include "LTO.h"
#include "SymbolTable.h"
#include "lld/Common/LLVM.h"
#include "lld/Common/Reproduce.h"
#include "llvm/ADT/Optional.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/StringSet.h"
#include "llvm/Option/ArgList.h"
#include "llvm/Support/raw_ostream.h"

namespace lld {
namespace elf {

extern class LinkerDriver *driver;

class LinkerDriver {
public:
  void main(ArrayRef<const char *> args);
  void addFile(StringRef path, bool withLOption);
  void addLibrary(StringRef name);

private:
  void createFiles(llvm::opt::InputArgList &args);
  void inferMachineType();
  template <class ELFT> void link(llvm::opt::InputArgList &args);
  template <class ELFT> void compileBitcodeFiles();

  // True if we are in --whole-archive and --no-whole-archive.
  bool inWholeArchive = false;

  // True if we are in --start-lib and --end-lib.
  bool inLib = false;

  // For LTO.
  std::unique_ptr<BitcodeCompiler> lto;

  std::vector<InputFile *> files;
};

// Parses command line options.
class ELFOptTable : public llvm::opt::OptTable {
public:
  ELFOptTable();
  llvm::opt::InputArgList parse(ArrayRef<const char *> argv);
};

// Create enum with OPT_xxx values for each option in Options.td
enum {
  OPT_INVALID = 0,
#define OPTION(_1, _2, ID, _4, _5, _6, _7, _8, _9, _10, _11, _12) OPT_##ID,
#include "Options.inc"
#undef OPTION
};

void printHelp();
std::string createResponseFile(const llvm::opt::InputArgList &args);

llvm::Optional<std::string> findFromSearchPaths(StringRef path);
llvm::Optional<std::string> searchScript(StringRef path);
llvm::Optional<std::string> searchLibraryBaseName(StringRef path);
llvm::Optional<std::string> searchLibrary(StringRef path);

} // namespace elf
} // namespace lld

#endif
