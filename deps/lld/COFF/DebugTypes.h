//===- DebugTypes.h ---------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_COFF_DEBUGTYPES_H
#define LLD_COFF_DEBUGTYPES_H

#include "llvm/Support/Error.h"
#include "llvm/Support/MemoryBuffer.h"

namespace llvm {
namespace codeview {
class PrecompRecord;
class TypeServer2Record;
} // namespace codeview
namespace pdb {
class NativeSession;
}
} // namespace llvm

namespace lld {
namespace coff {

class ObjFile;

class TpiSource {
public:
  enum TpiKind { Regular, PCH, UsingPCH, PDB, UsingPDB };

  TpiSource(TpiKind k, const ObjFile *f);
  virtual ~TpiSource() {}

  const TpiKind kind;
  const ObjFile *file;
};

TpiSource *makeTpiSource(const ObjFile *f);
TpiSource *makeUseTypeServerSource(const ObjFile *f,
                                   const llvm::codeview::TypeServer2Record *ts);
TpiSource *makePrecompSource(const ObjFile *f);
TpiSource *makeUsePrecompSource(const ObjFile *f,
                                const llvm::codeview::PrecompRecord *precomp);

void loadTypeServerSource(llvm::MemoryBufferRef m);

// Temporary interface to get the dependency
template <typename T> const T &retrieveDependencyInfo(const TpiSource *source);

// Temporary interface until we move PDBLinker::maybeMergeTypeServerPDB here
llvm::Expected<llvm::pdb::NativeSession *>
findTypeServerSource(const ObjFile *f);

} // namespace coff
} // namespace lld

#endif