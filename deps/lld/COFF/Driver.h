//===- Driver.h -------------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_COFF_DRIVER_H
#define LLD_COFF_DRIVER_H

#include "Config.h"
#include "SymbolTable.h"
#include "lld/Common/LLVM.h"
#include "lld/Common/Reproduce.h"
#include "llvm/ADT/Optional.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/StringSet.h"
#include "llvm/Object/Archive.h"
#include "llvm/Object/COFF.h"
#include "llvm/Option/Arg.h"
#include "llvm/Option/ArgList.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/TarWriter.h"
#include <memory>
#include <set>
#include <vector>

namespace lld {
namespace coff {

class LinkerDriver;
extern LinkerDriver *driver;

using llvm::COFF::MachineTypes;
using llvm::COFF::WindowsSubsystem;
using llvm::Optional;

class COFFOptTable : public llvm::opt::OptTable {
public:
  COFFOptTable();
};

class ArgParser {
public:
  // Concatenate LINK environment variable and given arguments and parse them.
  llvm::opt::InputArgList parseLINK(std::vector<const char *> args);

  // Tokenizes a given string and then parses as command line options.
  llvm::opt::InputArgList parse(StringRef s) { return parse(tokenize(s)); }

  // Tokenizes a given string and then parses as command line options in
  // .drectve section. /EXPORT options are returned in second element
  // to be processed in fastpath.
  std::pair<llvm::opt::InputArgList, std::vector<StringRef>>
  parseDirectives(StringRef s);

private:
  // Parses command line options.
  llvm::opt::InputArgList parse(llvm::ArrayRef<const char *> args);

  std::vector<const char *> tokenize(StringRef s);

  COFFOptTable table;
};

class LinkerDriver {
public:
  void link(llvm::ArrayRef<const char *> args);

  // Used by the resolver to parse .drectve section contents.
  void parseDirectives(InputFile *file);

  // Used by ArchiveFile to enqueue members.
  void enqueueArchiveMember(const Archive::Child &c, const Archive::Symbol &sym,
                            StringRef parentName);

  MemoryBufferRef takeBuffer(std::unique_ptr<MemoryBuffer> mb);

  void enqueuePath(StringRef path, bool wholeArchive);

private:
  std::unique_ptr<llvm::TarWriter> tar; // for /linkrepro

  // Opens a file. Path has to be resolved already.
  MemoryBufferRef openFile(StringRef path);

  // Searches a file from search paths.
  Optional<StringRef> findFile(StringRef filename);
  Optional<StringRef> findLib(StringRef filename);
  StringRef doFindFile(StringRef filename);
  StringRef doFindLib(StringRef filename);
  StringRef doFindLibMinGW(StringRef filename);

  // Parses LIB environment which contains a list of search paths.
  void addLibSearchPaths();

  // Library search path. The first element is always "" (current directory).
  std::vector<StringRef> searchPaths;

  void maybeExportMinGWSymbols(const llvm::opt::InputArgList &args);

  // We don't want to add the same file more than once.
  // Files are uniquified by their filesystem and file number.
  std::set<llvm::sys::fs::UniqueID> visitedFiles;

  std::set<std::string> visitedLibs;

  Symbol *addUndefined(StringRef sym);

  StringRef mangleMaybe(Symbol *s);

  // Windows specific -- "main" is not the only main function in Windows.
  // You can choose one from these four -- {w,}{WinMain,main}.
  // There are four different entry point functions for them,
  // {w,}{WinMain,main}CRTStartup, respectively. The linker needs to
  // choose the right one depending on which "main" function is defined.
  // This function looks up the symbol table and resolve corresponding
  // entry point name.
  StringRef findDefaultEntry();
  WindowsSubsystem inferSubsystem();

  void addBuffer(std::unique_ptr<MemoryBuffer> mb, bool wholeArchive);
  void addArchiveBuffer(MemoryBufferRef mbref, StringRef symName,
                        StringRef parentName, uint64_t offsetInArchive);

  void enqueueTask(std::function<void()> task);
  bool run();

  std::list<std::function<void()>> taskQueue;
  std::vector<StringRef> filePaths;
  std::vector<MemoryBufferRef> resources;

  llvm::StringSet<> directivesExports;
};

// Functions below this line are defined in DriverUtils.cpp.

void printHelp(const char *argv0);

// Parses a string in the form of "<integer>[,<integer>]".
void parseNumbers(StringRef arg, uint64_t *addr, uint64_t *size = nullptr);

void parseGuard(StringRef arg);

// Parses a string in the form of "<integer>[.<integer>]".
// Minor's default value is 0.
void parseVersion(StringRef arg, uint32_t *major, uint32_t *minor);

// Parses a string in the form of "<subsystem>[,<integer>[.<integer>]]".
void parseSubsystem(StringRef arg, WindowsSubsystem *sys, uint32_t *major,
                    uint32_t *minor);

void parseAlternateName(StringRef);
void parseMerge(StringRef);
void parseSection(StringRef);
void parseAligncomm(StringRef);

// Parses a string in the form of "[:<integer>]"
void parseFunctionPadMin(llvm::opt::Arg *a, llvm::COFF::MachineTypes machine);

// Parses a string in the form of "EMBED[,=<integer>]|NO".
void parseManifest(StringRef arg);

// Parses a string in the form of "level=<string>|uiAccess=<string>"
void parseManifestUAC(StringRef arg);

// Parses a string in the form of "cd|net[,(cd|net)]*"
void parseSwaprun(StringRef arg);

// Create a resource file containing a manifest XML.
std::unique_ptr<MemoryBuffer> createManifestRes();
void createSideBySideManifest();

// Used for dllexported symbols.
Export parseExport(StringRef arg);
void fixupExports();
void assignExportOrdinals();

// Parses a string in the form of "key=value" and check
// if value matches previous values for the key.
// This feature used in the directive section to reject
// incompatible objects.
void checkFailIfMismatch(StringRef arg, InputFile *source);

// Convert Windows resource files (.res files) to a .obj file.
MemoryBufferRef convertResToCOFF(ArrayRef<MemoryBufferRef> mbs);

void runMSVCLinker(std::string rsp, ArrayRef<StringRef> objects);

// Create enum with OPT_xxx values for each option in Options.td
enum {
  OPT_INVALID = 0,
#define OPTION(_1, _2, ID, _4, _5, _6, _7, _8, _9, _10, _11, _12) OPT_##ID,
#include "Options.inc"
#undef OPTION
};

} // namespace coff
} // namespace lld

#endif
