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
#include "InputFiles.h"
#include "LinkerScript.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/TargetOptionsCommandFlags.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/Twine.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/IR/DiagnosticPrinter.h"
#include "llvm/LTO/Caching.h"
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
using namespace llvm::ELF;

using namespace lld;
using namespace lld::elf;

// This is for use when debugging LTO.
static void saveBuffer(StringRef Buffer, const Twine &Path) {
  std::error_code EC;
  raw_fd_ostream OS(Path.str(), EC, sys::fs::OpenFlags::F_None);
  if (EC)
    error("cannot create " + Path + ": " + EC.message());
  OS << Buffer;
}

static void diagnosticHandler(const DiagnosticInfo &DI) {
  SmallString<128> ErrStorage;
  raw_svector_ostream OS(ErrStorage);
  DiagnosticPrinterRawOStream DP(OS);
  DI.print(DP);
  warn(ErrStorage);
}

static void checkError(Error E) {
  handleAllErrors(std::move(E),
                  [&](ErrorInfoBase &EIB) { error(EIB.message()); });
}

static std::unique_ptr<lto::LTO> createLTO() {
  lto::Config Conf;

  // LLD supports the new relocations.
  Conf.Options = InitTargetOptionsFromCodeGenFlags();
  Conf.Options.RelaxELFRelocations = true;

  // Always emit a section per function/datum with LTO.
  Conf.Options.FunctionSections = true;
  Conf.Options.DataSections = true;

  if (Config->Relocatable)
    Conf.RelocModel = None;
  else if (Config->Pic)
    Conf.RelocModel = Reloc::PIC_;
  else
    Conf.RelocModel = Reloc::Static;
  Conf.CodeModel = GetCodeModelFromCMModel();
  Conf.DisableVerify = Config->DisableVerify;
  Conf.DiagHandler = diagnosticHandler;
  Conf.OptLevel = Config->LTOO;

  // Set up a custom pipeline if we've been asked to.
  Conf.OptPipeline = Config->LTONewPmPasses;
  Conf.AAPipeline = Config->LTOAAPipeline;

  // Set up optimization remarks if we've been asked to.
  Conf.RemarksFilename = Config->OptRemarksFilename;
  Conf.RemarksWithHotness = Config->OptRemarksWithHotness;

  if (Config->SaveTemps)
    checkError(Conf.addSaveTemps(std::string(Config->OutputFile) + ".",
                                 /*UseInputModulePath*/ true));

  lto::ThinBackend Backend;
  if (Config->ThinLTOJobs != -1u)
    Backend = lto::createInProcessThinBackend(Config->ThinLTOJobs);
  return llvm::make_unique<lto::LTO>(std::move(Conf), Backend,
                                     Config->LTOPartitions);
}

BitcodeCompiler::BitcodeCompiler() : LTOObj(createLTO()) {
  for (Symbol *Sym : Symtab->getSymbols()) {
    StringRef Name = Sym->getName();
    for (StringRef Prefix : {"__start_", "__stop_"})
      if (Name.startswith(Prefix))
        UsedStartStop.insert(Name.substr(Prefix.size()));
  }
}

BitcodeCompiler::~BitcodeCompiler() = default;

static void undefine(Symbol *S) {
  replaceSymbol<Undefined>(S, nullptr, S->getName(), STB_GLOBAL, STV_DEFAULT,
                           S->Type);
}

void BitcodeCompiler::add(BitcodeFile &F) {
  lto::InputFile &Obj = *F.Obj;
  unsigned SymNum = 0;
  std::vector<Symbol *> Syms = F.getSymbols();
  std::vector<lto::SymbolResolution> Resols(Syms.size());

  DenseSet<StringRef> ScriptSymbols;
  for (BaseCommand *Base : Script->SectionCommands)
    if (auto *Cmd = dyn_cast<SymbolAssignment>(Base))
      ScriptSymbols.insert(Cmd->Name);

  // Provide a resolution to the LTO API for each symbol.
  for (const lto::InputFile::Symbol &ObjSym : Obj.symbols()) {
    Symbol *Sym = Syms[SymNum];
    lto::SymbolResolution &R = Resols[SymNum];
    ++SymNum;

    // Ideally we shouldn't check for SF_Undefined but currently IRObjectFile
    // reports two symbols for module ASM defined. Without this check, lld
    // flags an undefined in IR with a definition in ASM as prevailing.
    // Once IRObjectFile is fixed to report only one symbol this hack can
    // be removed.
    R.Prevailing = !ObjSym.isUndefined() && Sym->File == &F;

    // We ask LTO to preserve following global symbols:
    // 1) All symbols when doing relocatable link, so that them can be used
    //    for doing final link.
    // 2) Symbols that are used in regular objects.
    // 3) C named sections if we have corresponding __start_/__stop_ symbol.
    // 4) Symbols that are defined in bitcode files and used for dynamic linking.
    R.VisibleToRegularObj = Config->Relocatable || Sym->IsUsedInRegularObj ||
                            (R.Prevailing && Sym->includeInDynsym()) ||
                            UsedStartStop.count(ObjSym.getSectionName());
    if (R.Prevailing)
      undefine(Sym);

    // We tell LTO to not apply interprocedural optimization for following
    // symbols because otherwise LTO would inline them while their values are
    // still not final:
    // 1) Aliased (with --defsym) or wrapped (with --wrap) symbols.
    // 2) Symbols redefined in linker script.
    R.LinkerRedefined = !Sym->CanInline || ScriptSymbols.count(Sym->getName());
  }
  checkError(LTOObj->add(std::move(F.Obj), Resols));
}

// Merge all the bitcode files we have seen, codegen the result
// and return the resulting ObjectFile(s).
std::vector<InputFile *> BitcodeCompiler::compile() {
  std::vector<InputFile *> Ret;
  unsigned MaxTasks = LTOObj->getMaxTasks();
  Buff.resize(MaxTasks);
  Files.resize(MaxTasks);

  // The --thinlto-cache-dir option specifies the path to a directory in which
  // to cache native object files for ThinLTO incremental builds. If a path was
  // specified, configure LTO to use it as the cache directory.
  lto::NativeObjectCache Cache;
  if (!Config->ThinLTOCacheDir.empty())
    Cache = check(
        lto::localCache(Config->ThinLTOCacheDir,
                        [&](size_t Task, std::unique_ptr<MemoryBuffer> MB,
                            StringRef Path) { Files[Task] = std::move(MB); }));

  checkError(LTOObj->run(
      [&](size_t Task) {
        return llvm::make_unique<lto::NativeObjectStream>(
            llvm::make_unique<raw_svector_ostream>(Buff[Task]));
      },
      Cache));

  if (!Config->ThinLTOCacheDir.empty())
    pruneCache(Config->ThinLTOCacheDir, Config->ThinLTOCachePolicy);

  for (unsigned I = 0; I != MaxTasks; ++I) {
    if (Buff[I].empty())
      continue;
    if (Config->SaveTemps) {
      if (I == 0)
        saveBuffer(Buff[I], Config->OutputFile + ".lto.o");
      else
        saveBuffer(Buff[I], Config->OutputFile + Twine(I) + ".lto.o");
    }
    InputFile *Obj = createObjectFile(MemoryBufferRef(Buff[I], "lto.tmp"));
    Ret.push_back(Obj);
  }

  for (std::unique_ptr<MemoryBuffer> &File : Files)
    if (File)
      Ret.push_back(createObjectFile(*File));

  return Ret;
}
