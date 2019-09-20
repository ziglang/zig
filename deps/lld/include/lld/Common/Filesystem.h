//===- Filesystem.h ---------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_FILESYSTEM_H
#define LLD_FILESYSTEM_H

#include "lld/Common/LLVM.h"
#include <system_error>

namespace lld {
void unlinkAsync(StringRef path);
std::error_code tryCreateFile(StringRef path);
} // namespace lld

#endif
