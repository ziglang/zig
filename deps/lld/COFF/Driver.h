//===- Driver.h -------------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_COFF_DRIVER_H
#define LLD_COFF_DRIVER_H

#include "Config.h"
#include "SymbolTable.h"
#include "lld/Core/LLVM.h"
#include "lld/Core/Reproduce.h"
#include "llvm/ADT/Optional.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Object/Archive.h"
#include "llvm/Object/COFF.h"
#include "llvm/Option/Arg.h"
#include "llvm/Option/ArgList.h"
#include "llvm/Support/TarWriter.h"
#include <memory>
#include <set>
#include <vector>

namespace lld {
namespace coff {

class LinkerDriver;
extern LinkerDriver *Driver;

using llvm::COFF::MachineTypes;
using llvm::COFF::WindowsSubsystem;
using llvm::Optional;

// Implemented in MarkLive.cpp.
void markLive(const std::vector<Chunk *> &Chunks);

// Implemented in ICF.cpp.
void doICF(const std::vector<Chunk *> &Chunks);

class ArgParser {
public:
  // Parses command line options.
  llvm::opt::InputArgList parse(llvm::ArrayRef<const char *> Args);

  // Concatenate LINK environment varirable and given arguments and parse them.
  llvm::opt::InputArgList parseLINK(std::vector<const char *> Args);

  // Tokenizes a given string and then parses as command line options.
  llvm::opt::InputArgList parse(StringRef S) { return parse(tokenize(S)); }

private:
  std::vector<const char *> tokenize(StringRef S);

  std::vector<const char *> replaceResponseFiles(std::vector<const char *>);
};

class LinkerDriver {
public:
  LinkerDriver() { coff::Symtab = &Symtab; }
  void link(llvm::ArrayRef<const char *> Args);

  // Used by the resolver to parse .drectve section contents.
  void parseDirectives(StringRef S);

  // Used by ArchiveFile to enqueue members.
  void enqueueArchiveMember(const Archive::Child &C, StringRef SymName,
                            StringRef ParentName);

private:
  ArgParser Parser;
  SymbolTable Symtab;

  std::unique_ptr<llvm::TarWriter> Tar; // for /linkrepro

  // Opens a file. Path has to be resolved already.
  MemoryBufferRef openFile(StringRef Path);

  // Searches a file from search paths.
  Optional<StringRef> findFile(StringRef Filename);
  Optional<StringRef> findLib(StringRef Filename);
  StringRef doFindFile(StringRef Filename);
  StringRef doFindLib(StringRef Filename);

  // Parses LIB environment which contains a list of search paths.
  void addLibSearchPaths();

  // Library search path. The first element is always "" (current directory).
  std::vector<StringRef> SearchPaths;
  std::set<std::string> VisitedFiles;
  std::set<std::string> VisitedLibs;

  SymbolBody *addUndefined(StringRef Sym);
  StringRef mangle(StringRef Sym);

  // Windows specific -- "main" is not the only main function in Windows.
  // You can choose one from these four -- {w,}{WinMain,main}.
  // There are four different entry point functions for them,
  // {w,}{WinMain,main}CRTStartup, respectively. The linker needs to
  // choose the right one depending on which "main" function is defined.
  // This function looks up the symbol table and resolve corresponding
  // entry point name.
  StringRef findDefaultEntry();
  WindowsSubsystem inferSubsystem();

  void invokeMSVC(llvm::opt::InputArgList &Args);

  MemoryBufferRef takeBuffer(std::unique_ptr<MemoryBuffer> MB);
  void addBuffer(std::unique_ptr<MemoryBuffer> MB);
  void addArchiveBuffer(MemoryBufferRef MBRef, StringRef SymName,
                        StringRef ParentName);

  void enqueuePath(StringRef Path);

  void enqueueTask(std::function<void()> Task);
  bool run();

  std::list<std::function<void()>> TaskQueue;
  std::vector<StringRef> FilePaths;
  std::vector<MemoryBufferRef> Resources;
};

// Functions below this line are defined in DriverUtils.cpp.

void printHelp(const char *Argv0);

// For /machine option.
MachineTypes getMachineType(StringRef Arg);
StringRef machineToStr(MachineTypes MT);

// Parses a string in the form of "<integer>[,<integer>]".
void parseNumbers(StringRef Arg, uint64_t *Addr, uint64_t *Size = nullptr);

// Parses a string in the form of "<integer>[.<integer>]".
// Minor's default value is 0.
void parseVersion(StringRef Arg, uint32_t *Major, uint32_t *Minor);

// Parses a string in the form of "<subsystem>[,<integer>[.<integer>]]".
void parseSubsystem(StringRef Arg, WindowsSubsystem *Sys, uint32_t *Major,
                    uint32_t *Minor);

void parseAlternateName(StringRef);
void parseMerge(StringRef);
void parseSection(StringRef);

// Parses a string in the form of "EMBED[,=<integer>]|NO".
void parseManifest(StringRef Arg);

// Parses a string in the form of "level=<string>|uiAccess=<string>"
void parseManifestUAC(StringRef Arg);

// Create a resource file containing a manifest XML.
std::unique_ptr<MemoryBuffer> createManifestRes();
void createSideBySideManifest();

// Used for dllexported symbols.
Export parseExport(StringRef Arg);
void fixupExports();
void assignExportOrdinals();

// Parses a string in the form of "key=value" and check
// if value matches previous values for the key.
// This feature used in the directive section to reject
// incompatible objects.
void checkFailIfMismatch(StringRef Arg);

// Convert Windows resource files (.res files) to a .obj file
// using cvtres.exe.
std::unique_ptr<MemoryBuffer>
convertResToCOFF(const std::vector<MemoryBufferRef> &MBs);

void runMSVCLinker(std::string Rsp, ArrayRef<StringRef> Objects);

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
