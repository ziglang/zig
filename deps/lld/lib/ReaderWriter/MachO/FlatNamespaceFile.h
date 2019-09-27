//===- lib/ReaderWriter/MachO/FlatNamespaceFile.h -------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_READER_WRITER_MACHO_FLAT_NAMESPACE_FILE_H
#define LLD_READER_WRITER_MACHO_FLAT_NAMESPACE_FILE_H

#include "Atoms.h"
#include "lld/Core/SharedLibraryFile.h"
#include "lld/ReaderWriter/MachOLinkingContext.h"
#include "llvm/Support/Debug.h"

namespace lld {
namespace mach_o {

//
// A FlateNamespaceFile instance may be added as a resolution source of last
// resort, depending on how -flat_namespace and -undefined are set.
//
class FlatNamespaceFile : public SharedLibraryFile {
public:
  FlatNamespaceFile(const MachOLinkingContext &context)
    : SharedLibraryFile("flat namespace") { }

  OwningAtomPtr<SharedLibraryAtom> exports(StringRef name) const override {
    return new (allocator()) MachOSharedLibraryAtom(*this, name, getDSOName(),
                                                    false);
  }

  StringRef getDSOName() const override { return "flat-namespace"; }

  const AtomRange<DefinedAtom> defined() const override {
    return _noDefinedAtoms;
  }
  const AtomRange<UndefinedAtom> undefined() const override {
    return _noUndefinedAtoms;
  }

  const AtomRange<SharedLibraryAtom> sharedLibrary() const override {
    return _noSharedLibraryAtoms;
  }

  const AtomRange<AbsoluteAtom> absolute() const override {
    return _noAbsoluteAtoms;
  }

  void clearAtoms() override {
    _noDefinedAtoms.clear();
    _noUndefinedAtoms.clear();
    _noSharedLibraryAtoms.clear();
    _noAbsoluteAtoms.clear();
  }
};

} // namespace mach_o
} // namespace lld

#endif // LLD_READER_WRITER_MACHO_FLAT_NAMESPACE_FILE_H
