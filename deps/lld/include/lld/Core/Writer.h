//===- lld/Core/Writer.h - Abstract File Format Interface -----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_CORE_WRITER_H
#define LLD_CORE_WRITER_H

#include "lld/Common/LLVM.h"
#include "llvm/Support/Error.h"
#include <memory>
#include <vector>

namespace lld {
class File;
class LinkingContext;
class MachOLinkingContext;

/// The Writer is an abstract class for writing object files, shared
/// library files, and executable files.  Each file format (e.g. mach-o, etc)
/// has a concrete subclass of Writer.
class Writer {
public:
  virtual ~Writer();

  /// Write a file from the supplied File object
  virtual llvm::Error writeFile(const File &linkedFile, StringRef path) = 0;

  /// This method is called by Core Linking to give the Writer a chance
  /// to add file format specific "files" to set of files to be linked. This is
  /// how file format specific atoms can be added to the link.
  virtual void createImplicitFiles(std::vector<std::unique_ptr<File>> &) {}

protected:
  // only concrete subclasses can be instantiated
  Writer();
};

std::unique_ptr<Writer> createWriterMachO(const MachOLinkingContext &);
std::unique_ptr<Writer> createWriterYAML(const LinkingContext &);
} // end namespace lld

#endif
