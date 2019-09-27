//===- Config.h -------------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
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

// This struct contains the global configuration for the linker.
// Most fields are direct mapping from the command line options
// and such fields have the same name as the corresponding options.
// Most fields are initialized by the driver.
struct Configuration {
  bool allowUndefined;
  bool checkFeatures;
  bool compressRelocations;
  bool demangle;
  bool disableVerify;
  bool emitRelocs;
  bool exportAll;
  bool exportDynamic;
  bool exportTable;
  bool gcSections;
  bool importMemory;
  bool sharedMemory;
  bool passiveSegments;
  bool importTable;
  bool mergeDataSegments;
  bool pie;
  bool printGcSections;
  bool relocatable;
  bool saveTemps;
  bool shared;
  bool stripAll;
  bool stripDebug;
  bool stackFirst;
  bool trace;
  uint32_t globalBase;
  uint32_t initialMemory;
  uint32_t maxMemory;
  uint32_t zStackSize;
  unsigned ltoPartitions;
  unsigned ltoo;
  unsigned optimize;
  unsigned thinLTOJobs;

  llvm::StringRef entry;
  llvm::StringRef outputFile;
  llvm::StringRef thinLTOCacheDir;

  llvm::StringSet<> allowUndefinedSymbols;
  llvm::StringSet<> exportedSymbols;
  std::vector<llvm::StringRef> searchPaths;
  llvm::CachePruningPolicy thinLTOCachePolicy;
  llvm::Optional<std::vector<std::string>> features;

  // The following config options do not directly correspond to any
  // particualr command line options.

  // True if we are creating position-independent code.
  bool isPic;
};

// The only instance of Configuration struct.
extern Configuration *config;

} // namespace wasm
} // namespace lld

#endif
