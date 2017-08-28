//===- LTO.cpp ------------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "LTO.h"
#include "Config.h"
#include "Error.h"
#include "InputFiles.h"
#include "Symbols.h"
#include "lld/Core/TargetOptionsCommandFlags.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/Twine.h"
#include "llvm/IR/DiagnosticPrinter.h"
#include "llvm/LTO/Config.h"
#include "llvm/LTO/LTO.h"
#include "llvm/Object/SymbolicFile.h"
#include "llvm/Support/CodeGen.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/raw_ostream.h"
#include <algorithm>
#include <cstddef>
#include <memory>
#include <string>
#include <system_error>
#include <vector>

using namespace llvm;
using namespace llvm::object;

using namespace lld;
using namespace lld::coff;

static void diagnosticHandler(const DiagnosticInfo &DI) {
  SmallString<128> ErrStorage;
  raw_svector_ostream OS(ErrStorage);
  DiagnosticPrinterRawOStream DP(OS);
  DI.print(DP);
  warn(ErrStorage);
}

static void checkError(Error E) {
  handleAllErrors(std::move(E), [&](ErrorInfoBase &EIB) -> Error {
    error(EIB.message());
    return Error::success();
  });
}

static void saveBuffer(StringRef Buffer, const Twine &Path) {
  std::error_code EC;
  raw_fd_ostream OS(Path.str(), EC, sys::fs::OpenFlags::F_None);
  if (EC)
    error("cannot create " + Path + ": " + EC.message());
  OS << Buffer;
}

static std::unique_ptr<lto::LTO> createLTO() {
  lto::Config Conf;
  Conf.Options = InitTargetOptionsFromCodeGenFlags();
  Conf.RelocModel = Reloc::PIC_;
  Conf.DisableVerify = true;
  Conf.DiagHandler = diagnosticHandler;
  Conf.OptLevel = Config->LTOOptLevel;
  if (Config->SaveTemps)
    checkError(Conf.addSaveTemps(std::string(Config->OutputFile) + ".",
                                 /*UseInputModulePath*/ true));
  lto::ThinBackend Backend;
  if (Config->LTOJobs != 0)
    Backend = lto::createInProcessThinBackend(Config->LTOJobs);
  return llvm::make_unique<lto::LTO>(std::move(Conf), Backend,
                                     Config->LTOPartitions);
}

BitcodeCompiler::BitcodeCompiler() : LTOObj(createLTO()) {}

BitcodeCompiler::~BitcodeCompiler() = default;

static void undefine(Symbol *S) {
  replaceBody<Undefined>(S, S->body()->getName());
}

void BitcodeCompiler::add(BitcodeFile &F) {
  lto::InputFile &Obj = *F.Obj;
  unsigned SymNum = 0;
  std::vector<SymbolBody *> SymBodies = F.getSymbols();
  std::vector<lto::SymbolResolution> Resols(SymBodies.size());

  // Provide a resolution to the LTO API for each symbol.
  for (const lto::InputFile::Symbol &ObjSym : Obj.symbols()) {
    SymbolBody *B = SymBodies[SymNum];
    Symbol *Sym = B->symbol();
    lto::SymbolResolution &R = Resols[SymNum];
    ++SymNum;

    // Ideally we shouldn't check for SF_Undefined but currently IRObjectFile
    // reports two symbols for module ASM defined. Without this check, lld
    // flags an undefined in IR with a definition in ASM as prevailing.
    // Once IRObjectFile is fixed to report only one symbol this hack can
    // be removed.
    R.Prevailing = !ObjSym.isUndefined() && B->getFile() == &F;
    R.VisibleToRegularObj = Sym->IsUsedInRegularObj;
    if (R.Prevailing)
      undefine(Sym);
  }
  checkError(LTOObj->add(std::move(F.Obj), Resols));
}

// Merge all the bitcode files we have seen, codegen the result
// and return the resulting objects.
std::vector<StringRef> BitcodeCompiler::compile() {
  unsigned MaxTasks = LTOObj->getMaxTasks();
  Buff.resize(MaxTasks);

  checkError(LTOObj->run([&](size_t Task) {
    return llvm::make_unique<lto::NativeObjectStream>(
        llvm::make_unique<raw_svector_ostream>(Buff[Task]));
  }));

  std::vector<StringRef> Ret;
  for (unsigned I = 0; I != MaxTasks; ++I) {
    if (Buff[I].empty())
      continue;
    if (Config->SaveTemps) {
      if (I == 0)
        saveBuffer(Buff[I], Config->OutputFile + ".lto.obj");
      else
        saveBuffer(Buff[I], Config->OutputFile + Twine(I) + ".lto.obj");
    }
    Ret.emplace_back(Buff[I].data(), Buff[I].size());
  }
  return Ret;
}
