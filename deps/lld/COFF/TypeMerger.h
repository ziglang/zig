//===- TypeMerger.h ---------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_COFF_TYPEMERGER_H
#define LLD_COFF_TYPEMERGER_H

#include "Config.h"
#include "llvm/DebugInfo/CodeView/GlobalTypeTableBuilder.h"
#include "llvm/DebugInfo/CodeView/MergingTypeTableBuilder.h"
#include "llvm/Support/Allocator.h"

namespace lld {
namespace coff {

class TypeMerger {
public:
  TypeMerger(llvm::BumpPtrAllocator &alloc)
      : typeTable(alloc), iDTable(alloc), globalTypeTable(alloc),
        globalIDTable(alloc) {}

  /// Get the type table or the global type table if /DEBUG:GHASH is enabled.
  inline llvm::codeview::TypeCollection &getTypeTable() {
    if (config->debugGHashes)
      return globalTypeTable;
    return typeTable;
  }

  /// Get the ID table or the global ID table if /DEBUG:GHASH is enabled.
  inline llvm::codeview::TypeCollection &getIDTable() {
    if (config->debugGHashes)
      return globalIDTable;
    return iDTable;
  }

  /// Type records that will go into the PDB TPI stream.
  llvm::codeview::MergingTypeTableBuilder typeTable;

  /// Item records that will go into the PDB IPI stream.
  llvm::codeview::MergingTypeTableBuilder iDTable;

  /// Type records that will go into the PDB TPI stream (for /DEBUG:GHASH)
  llvm::codeview::GlobalTypeTableBuilder globalTypeTable;

  /// Item records that will go into the PDB IPI stream (for /DEBUG:GHASH)
  llvm::codeview::GlobalTypeTableBuilder globalIDTable;
};

/// Map from type index and item index in a type server PDB to the
/// corresponding index in the destination PDB.
struct CVIndexMap {
  llvm::SmallVector<llvm::codeview::TypeIndex, 0> tpiMap;
  llvm::SmallVector<llvm::codeview::TypeIndex, 0> ipiMap;
  bool isTypeServerMap = false;
  bool isPrecompiledTypeMap = false;
};

} // namespace coff
} // namespace lld

#endif