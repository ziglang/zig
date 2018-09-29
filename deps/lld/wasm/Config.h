//===- Config.h -------------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_WASM_CONFIG_H
#define LLD_WASM_CONFIG_H

#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/StringSet.h"
#include "llvm/BinaryFormat/Wasm.h"
#include "llvm/Support/CachePruning.h"

namespace lld {
namespace wasm {

struct Configuration {
  bool AllowUndefined;
  bool CompressRelocTargets;
  bool Demangle;
  bool DisableVerify;
  bool ExportAll;
  bool ExportTable;
  bool GcSections;
  bool ImportMemory;
  bool ImportTable;
  bool MergeDataSegments;
  bool PrintGcSections;
  bool Relocatable;
  bool SaveTemps;
  bool StripAll;
  bool StripDebug;
  bool StackFirst;
  uint32_t GlobalBase;
  uint32_t InitialMemory;
  uint32_t MaxMemory;
  uint32_t ZStackSize;
  unsigned LTOPartitions;
  unsigned LTOO;
  unsigned Optimize;
  unsigned ThinLTOJobs;
  llvm::StringRef Entry;
  llvm::StringRef OutputFile;
  llvm::StringRef ThinLTOCacheDir;

  llvm::StringSet<> AllowUndefinedSymbols;
  std::vector<llvm::StringRef> SearchPaths;
  llvm::CachePruningPolicy ThinLTOCachePolicy;
};

// The only instance of Configuration struct.
extern Configuration *Config;

} // namespace wasm
} // namespace lld

#endif
