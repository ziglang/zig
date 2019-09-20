//===- lib/Core/LinkingContext.cpp - Linker Context Object Interface ------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "lld/Core/LinkingContext.h"
#include "lld/Core/File.h"
#include "lld/Core/Node.h"
#include "lld/Core/Simple.h"
#include "lld/Core/Writer.h"
#include <algorithm>

namespace lld {

LinkingContext::LinkingContext() = default;

LinkingContext::~LinkingContext() = default;

bool LinkingContext::validate() {
  return validateImpl();
}

llvm::Error LinkingContext::writeFile(const File &linkedFile) const {
  return this->writer().writeFile(linkedFile, _outputPath);
}

std::unique_ptr<File> LinkingContext::createEntrySymbolFile() const {
  return createEntrySymbolFile("<command line option -e>");
}

std::unique_ptr<File>
LinkingContext::createEntrySymbolFile(StringRef filename) const {
  if (entrySymbolName().empty())
    return nullptr;
  std::unique_ptr<SimpleFile> entryFile(new SimpleFile(filename,
                                                       File::kindEntryObject));
  entryFile->addAtom(
      *(new (_allocator) SimpleUndefinedAtom(*entryFile, entrySymbolName())));
  return std::move(entryFile);
}

std::unique_ptr<File> LinkingContext::createUndefinedSymbolFile() const {
  return createUndefinedSymbolFile("<command line option -u or --defsym>");
}

std::unique_ptr<File>
LinkingContext::createUndefinedSymbolFile(StringRef filename) const {
  if (_initialUndefinedSymbols.empty())
    return nullptr;
  std::unique_ptr<SimpleFile> undefinedSymFile(
    new SimpleFile(filename, File::kindUndefinedSymsObject));
  for (StringRef undefSym : _initialUndefinedSymbols)
    undefinedSymFile->addAtom(*(new (_allocator) SimpleUndefinedAtom(
                                   *undefinedSymFile, undefSym)));
  return std::move(undefinedSymFile);
}

void LinkingContext::createInternalFiles(
    std::vector<std::unique_ptr<File>> &result) const {
  if (std::unique_ptr<File> file = createEntrySymbolFile())
    result.push_back(std::move(file));
  if (std::unique_ptr<File> file = createUndefinedSymbolFile())
    result.push_back(std::move(file));
}

} // end namespace lld
