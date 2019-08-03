//===- ICF.h --------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_COFF_ICF_H
#define LLD_COFF_ICF_H

#include "lld/Common/LLVM.h"
#include "llvm/ADT/ArrayRef.h"

namespace lld {
namespace coff {

class Chunk;

void doICF(ArrayRef<Chunk *> chunks);

} // namespace coff
} // namespace lld

#endif
