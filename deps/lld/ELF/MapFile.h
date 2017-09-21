//===- MapFile.h ------------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_ELF_MAPFILE_H
#define LLD_ELF_MAPFILE_H

#include <llvm/ADT/ArrayRef.h>

namespace lld {
namespace elf {
struct OutputSectionCommand;
template <class ELFT>
void writeMapFile(llvm::ArrayRef<OutputSectionCommand *> Script);
} // namespace elf
} // namespace lld

#endif
