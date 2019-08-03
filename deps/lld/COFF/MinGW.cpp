//===- MinGW.cpp ----------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "MinGW.h"
#include "SymbolTable.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/Object/COFF.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/raw_ostream.h"

using namespace lld;
using namespace lld::coff;
using namespace llvm;
using namespace llvm::COFF;

AutoExporter::AutoExporter() {
  excludeLibs = {
      "libgcc",
      "libgcc_s",
      "libstdc++",
      "libmingw32",
      "libmingwex",
      "libg2c",
      "libsupc++",
      "libobjc",
      "libgcj",
      "libclang_rt.builtins",
      "libclang_rt.builtins-aarch64",
      "libclang_rt.builtins-arm",
      "libclang_rt.builtins-i386",
      "libclang_rt.builtins-x86_64",
      "libc++",
      "libc++abi",
      "libunwind",
      "libmsvcrt",
      "libucrtbase",
  };

  excludeObjects = {
      "crt0.o",    "crt1.o",  "crt1u.o", "crt2.o",  "crt2u.o",    "dllcrt1.o",
      "dllcrt2.o", "gcrt0.o", "gcrt1.o", "gcrt2.o", "crtbegin.o", "crtend.o",
  };

  excludeSymbolPrefixes = {
      // Import symbols
      "__imp_",
      "__IMPORT_DESCRIPTOR_",
      // Extra import symbols from GNU import libraries
      "__nm_",
      // C++ symbols
      "__rtti_",
      "__builtin_",
      // Artifical symbols such as .refptr
      ".",
  };

  excludeSymbolSuffixes = {
      "_iname",
      "_NULL_THUNK_DATA",
  };

  if (config->machine == I386) {
    excludeSymbols = {
        "__NULL_IMPORT_DESCRIPTOR",
        "__pei386_runtime_relocator",
        "_do_pseudo_reloc",
        "_impure_ptr",
        "__impure_ptr",
        "__fmode",
        "_environ",
        "___dso_handle",
        // These are the MinGW names that differ from the standard
        // ones (lacking an extra underscore).
        "_DllMain@12",
        "_DllEntryPoint@12",
        "_DllMainCRTStartup@12",
    };
    excludeSymbolPrefixes.insert("__head_");
  } else {
    excludeSymbols = {
        "__NULL_IMPORT_DESCRIPTOR",
        "_pei386_runtime_relocator",
        "do_pseudo_reloc",
        "impure_ptr",
        "_impure_ptr",
        "_fmode",
        "environ",
        "__dso_handle",
        // These are the MinGW names that differ from the standard
        // ones (lacking an extra underscore).
        "DllMain",
        "DllEntryPoint",
        "DllMainCRTStartup",
    };
    excludeSymbolPrefixes.insert("_head_");
  }
}

void AutoExporter::addWholeArchive(StringRef path) {
  StringRef libName = sys::path::filename(path);
  // Drop the file extension, to match the processing below.
  libName = libName.substr(0, libName.rfind('.'));
  excludeLibs.erase(libName);
}

bool AutoExporter::shouldExport(Defined *sym) const {
  if (!sym || !sym->isLive() || !sym->getChunk())
    return false;

  // Only allow the symbol kinds that make sense to export; in particular,
  // disallow import symbols.
  if (!isa<DefinedRegular>(sym) && !isa<DefinedCommon>(sym))
    return false;
  if (excludeSymbols.count(sym->getName()))
    return false;

  for (StringRef prefix : excludeSymbolPrefixes.keys())
    if (sym->getName().startswith(prefix))
      return false;
  for (StringRef suffix : excludeSymbolSuffixes.keys())
    if (sym->getName().endswith(suffix))
      return false;

  // If a corresponding __imp_ symbol exists and is defined, don't export it.
  if (symtab->find(("__imp_" + sym->getName()).str()))
    return false;

  // Check that file is non-null before dereferencing it, symbols not
  // originating in regular object files probably shouldn't be exported.
  if (!sym->getFile())
    return false;

  StringRef libName = sys::path::filename(sym->getFile()->parentName);

  // Drop the file extension.
  libName = libName.substr(0, libName.rfind('.'));
  if (!libName.empty())
    return !excludeLibs.count(libName);

  StringRef fileName = sys::path::filename(sym->getFile()->getName());
  return !excludeObjects.count(fileName);
}

void coff::writeDefFile(StringRef name) {
  std::error_code ec;
  raw_fd_ostream os(name, ec, sys::fs::F_None);
  if (ec)
    fatal("cannot open " + name + ": " + ec.message());

  os << "EXPORTS\n";
  for (Export &e : config->exports) {
    os << "    " << e.exportName << " "
       << "@" << e.ordinal;
    if (auto *def = dyn_cast_or_null<Defined>(e.sym)) {
      if (def && def->getChunk() &&
          !(def->getChunk()->getOutputCharacteristics() & IMAGE_SCN_MEM_EXECUTE))
        os << " DATA";
    }
    os << "\n";
  }
}
