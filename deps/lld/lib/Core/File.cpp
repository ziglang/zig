//===- Core/File.cpp - A Container of Atoms -------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "lld/Core/File.h"
#include <mutex>

namespace lld {

File::~File() = default;

File::AtomVector<DefinedAtom> File::_noDefinedAtoms;
File::AtomVector<UndefinedAtom> File::_noUndefinedAtoms;
File::AtomVector<SharedLibraryAtom> File::_noSharedLibraryAtoms;
File::AtomVector<AbsoluteAtom> File::_noAbsoluteAtoms;

std::error_code File::parse() {
  std::lock_guard<std::mutex> lock(_parseMutex);
  if (!_lastError.hasValue())
    _lastError = doParse();
  return _lastError.getValue();
}

} // end namespace lld
