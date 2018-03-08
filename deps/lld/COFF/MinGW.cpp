//===- MinGW.cpp ----------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
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
  if (Config->Machine == I386) {
    ExcludeSymbols = {
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
  } else {
    ExcludeSymbols = {
        "_NULL_IMPORT_DESCRIPTOR",
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
  }

  ExcludeLibs = {
      "libgcc",
      "libgcc_s",
      "libstdc++",
      "libmingw32",
      "libmingwex",
      "libg2c",
      "libsupc++",
      "libobjc",
      "libgcj",
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
  ExcludeObjects = {
      "crt0.o",
      "crt1.o",
      "crt1u.o",
      "crt2.o",
      "crt2u.o",
      "dllcrt1.o",
      "dllcrt2.o",
      "gcrt0.o",
      "gcrt1.o",
      "gcrt2.o",
      "crtbegin.o",
      "crtend.o",
  };
}

bool AutoExporter::shouldExport(Defined *Sym) const {
  if (!Sym || !Sym->isLive() || !Sym->getChunk())
    return false;

  // Only allow the symbol kinds that make sense to export; in particular,
  // disallow import symbols.
  if (!isa<DefinedRegular>(Sym) && !isa<DefinedCommon>(Sym))
    return false;
  if (ExcludeSymbols.count(Sym->getName()))
    return false;

  // Don't export anything that looks like an import symbol (which also can be
  // a manually defined data symbol with such a name).
  if (Sym->getName().startswith("__imp_"))
    return false;

  // If a corresponding __imp_ symbol exists and is defined, don't export it.
  if (Symtab->find(("__imp_" + Sym->getName()).str()))
    return false;

  // Check that file is non-null before dereferencing it, symbols not
  // originating in regular object files probably shouldn't be exported.
  if (!Sym->getFile())
    return false;

  StringRef LibName = sys::path::filename(Sym->getFile()->ParentName);

  // Drop the file extension.
  LibName = LibName.substr(0, LibName.rfind('.'));
  if (!LibName.empty())
    return !ExcludeLibs.count(LibName);

  StringRef FileName = sys::path::filename(Sym->getFile()->getName());
  return !ExcludeObjects.count(FileName);
}

void coff::writeDefFile(StringRef Name) {
  std::error_code EC;
  raw_fd_ostream OS(Name, EC, sys::fs::F_None);
  if (EC)
    fatal("cannot open " + Name + ": " + EC.message());

  OS << "EXPORTS\n";
  for (Export &E : Config->Exports) {
    OS << "    " << E.ExportName << " "
       << "@" << E.Ordinal;
    if (auto *Def = dyn_cast_or_null<Defined>(E.Sym)) {
      if (Def && Def->getChunk() &&
          !(Def->getChunk()->getPermissions() & IMAGE_SCN_MEM_EXECUTE))
        OS << " DATA";
    }
    OS << "\n";
  }
}
