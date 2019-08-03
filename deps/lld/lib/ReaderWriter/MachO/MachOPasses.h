//===- lib/ReaderWriter/MachO/MachOPasses.h -------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_READER_WRITER_MACHO_PASSES_H
#define LLD_READER_WRITER_MACHO_PASSES_H

#include "lld/Core/PassManager.h"
#include "lld/ReaderWriter/MachOLinkingContext.h"

namespace lld {
namespace mach_o {

void addLayoutPass(PassManager &pm, const MachOLinkingContext &ctx);
void addStubsPass(PassManager &pm, const MachOLinkingContext &ctx);
void addGOTPass(PassManager &pm, const MachOLinkingContext &ctx);
void addTLVPass(PassManager &pm, const MachOLinkingContext &ctx);
void addCompactUnwindPass(PassManager &pm, const MachOLinkingContext &ctx);
void addObjCPass(PassManager &pm, const MachOLinkingContext &ctx);
void addShimPass(PassManager &pm, const MachOLinkingContext &ctx);

} // namespace mach_o
} // namespace lld

#endif // LLD_READER_WRITER_MACHO_PASSES_H
