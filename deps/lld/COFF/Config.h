//===- Config.h -------------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_COFF_CONFIG_H
#define LLD_COFF_CONFIG_H

#include "llvm/ADT/StringMap.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Object/COFF.h"
#include "llvm/Support/CachePruning.h"
#include <cstdint>
#include <map>
#include <set>
#include <string>

namespace lld {
namespace coff {

using llvm::COFF::IMAGE_FILE_MACHINE_UNKNOWN;
using llvm::COFF::WindowsSubsystem;
using llvm::StringRef;
class DefinedAbsolute;
class DefinedRelative;
class StringChunk;
class Symbol;
class InputFile;

// Short aliases.
static const auto AMD64 = llvm::COFF::IMAGE_FILE_MACHINE_AMD64;
static const auto ARM64 = llvm::COFF::IMAGE_FILE_MACHINE_ARM64;
static const auto ARMNT = llvm::COFF::IMAGE_FILE_MACHINE_ARMNT;
static const auto I386 = llvm::COFF::IMAGE_FILE_MACHINE_I386;

// Represents an /export option.
struct Export {
  StringRef name;       // N in /export:N or /export:E=N
  StringRef extName;    // E in /export:E=N
  Symbol *sym = nullptr;
  uint16_t ordinal = 0;
  bool noname = false;
  bool data = false;
  bool isPrivate = false;
  bool constant = false;

  // If an export is a form of /export:foo=dllname.bar, that means
  // that foo should be exported as an alias to bar in the DLL.
  // forwardTo is set to "dllname.bar" part. Usually empty.
  StringRef forwardTo;
  StringChunk *forwardChunk = nullptr;

  // True if this /export option was in .drectves section.
  bool directives = false;
  StringRef symbolName;
  StringRef exportName; // Name in DLL

  bool operator==(const Export &e) {
    return (name == e.name && extName == e.extName &&
            ordinal == e.ordinal && noname == e.noname &&
            data == e.data && isPrivate == e.isPrivate);
  }
};

enum class DebugType {
  None  = 0x0,
  CV    = 0x1,  /// CodeView
  PData = 0x2,  /// Procedure Data
  Fixup = 0x4,  /// Relocation Table
};

enum class GuardCFLevel {
  Off,
  NoLongJmp, // Emit gfids but no longjmp tables
  Full,      // Enable all protections.
};

// Global configuration.
struct Configuration {
  enum ManifestKind { SideBySide, Embed, No };
  bool is64() { return machine == AMD64 || machine == ARM64; }

  llvm::COFF::MachineTypes machine = IMAGE_FILE_MACHINE_UNKNOWN;
  size_t wordsize;
  bool verbose = false;
  WindowsSubsystem subsystem = llvm::COFF::IMAGE_SUBSYSTEM_UNKNOWN;
  Symbol *entry = nullptr;
  bool noEntry = false;
  std::string outputFile;
  std::string importName;
  bool demangle = true;
  bool doGC = true;
  bool doICF = true;
  bool tailMerge;
  bool relocatable = true;
  bool forceMultiple = false;
  bool forceMultipleRes = false;
  bool forceUnresolved = false;
  bool debug = false;
  bool debugDwarf = false;
  bool debugGHashes = false;
  bool debugSymtab = false;
  bool showTiming = false;
  bool showSummary = false;
  unsigned debugTypes = static_cast<unsigned>(DebugType::None);
  std::vector<std::string> natvisFiles;
  llvm::SmallString<128> pdbAltPath;
  llvm::SmallString<128> pdbPath;
  llvm::SmallString<128> pdbSourcePath;
  std::vector<llvm::StringRef> argv;

  // Symbols in this set are considered as live by the garbage collector.
  std::vector<Symbol *> gcroot;

  std::set<std::string> noDefaultLibs;
  bool noDefaultLibAll = false;

  // True if we are creating a DLL.
  bool dll = false;
  StringRef implib;
  std::vector<Export> exports;
  std::set<std::string> delayLoads;
  std::map<std::string, int> dllOrder;
  Symbol *delayLoadHelper = nullptr;

  bool saveTemps = false;

  // /guard:cf
  GuardCFLevel guardCF = GuardCFLevel::Off;

  // Used for SafeSEH.
  bool safeSEH = false;
  Symbol *sehTable = nullptr;
  Symbol *sehCount = nullptr;

  // Used for /opt:lldlto=N
  unsigned ltoo = 2;

  // Used for /opt:lldltojobs=N
  unsigned thinLTOJobs = 0;
  // Used for /opt:lldltopartitions=N
  unsigned ltoPartitions = 1;

  // Used for /opt:lldltocache=path
  StringRef ltoCache;
  // Used for /opt:lldltocachepolicy=policy
  llvm::CachePruningPolicy ltoCachePolicy;

  // Used for /merge:from=to (e.g. /merge:.rdata=.text)
  std::map<StringRef, StringRef> merge;

  // Used for /section=.name,{DEKPRSW} to set section attributes.
  std::map<StringRef, uint32_t> section;

  // Options for manifest files.
  ManifestKind manifest = No;
  int manifestID = 1;
  StringRef manifestDependency;
  bool manifestUAC = true;
  std::vector<std::string> manifestInput;
  StringRef manifestLevel = "'asInvoker'";
  StringRef manifestUIAccess = "'false'";
  StringRef manifestFile;

  // Used for /aligncomm.
  std::map<std::string, int> alignComm;

  // Used for /failifmismatch.
  std::map<StringRef, std::pair<StringRef, InputFile *>> mustMatch;

  // Used for /alternatename.
  std::map<StringRef, StringRef> alternateNames;

  // Used for /order.
  llvm::StringMap<int> order;

  // Used for /lldmap.
  std::string mapFile;

  // Used for /thinlto-index-only:
  llvm::StringRef thinLTOIndexOnlyArg;

  // Used for /thinlto-object-prefix-replace:
  std::pair<llvm::StringRef, llvm::StringRef> thinLTOPrefixReplace;

  // Used for /thinlto-object-suffix-replace:
  std::pair<llvm::StringRef, llvm::StringRef> thinLTOObjectSuffixReplace;

  uint64_t align = 4096;
  uint64_t imageBase = -1;
  uint64_t fileAlign = 512;
  uint64_t stackReserve = 1024 * 1024;
  uint64_t stackCommit = 4096;
  uint64_t heapReserve = 1024 * 1024;
  uint64_t heapCommit = 4096;
  uint32_t majorImageVersion = 0;
  uint32_t minorImageVersion = 0;
  uint32_t majorOSVersion = 6;
  uint32_t minorOSVersion = 0;
  uint32_t timestamp = 0;
  uint32_t functionPadMin = 0;
  bool dynamicBase = true;
  bool allowBind = true;
  bool nxCompat = true;
  bool allowIsolation = true;
  bool terminalServerAware = true;
  bool largeAddressAware = false;
  bool highEntropyVA = false;
  bool appContainer = false;
  bool mingw = false;
  bool warnMissingOrderSymbol = true;
  bool warnLocallyDefinedImported = true;
  bool warnDebugInfoUnusable = true;
  bool incremental = true;
  bool integrityCheck = false;
  bool killAt = false;
  bool repro = false;
  bool swaprunCD = false;
  bool swaprunNet = false;
  bool thinLTOEmitImportsFiles;
  bool thinLTOIndexOnly;
};

extern Configuration *config;

} // namespace coff
} // namespace lld

#endif
