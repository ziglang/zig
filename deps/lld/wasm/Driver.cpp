//===- Driver.cpp ---------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "lld/Common/Driver.h"
#include "Config.h"
#include "InputChunks.h"
#include "InputGlobal.h"
#include "MarkLive.h"
#include "SymbolTable.h"
#include "Writer.h"
#include "lld/Common/Args.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "lld/Common/Strings.h"
#include "lld/Common/Threads.h"
#include "lld/Common/Version.h"
#include "llvm/ADT/Twine.h"
#include "llvm/Object/Wasm.h"
#include "llvm/Option/ArgList.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/Process.h"
#include "llvm/Support/TargetSelect.h"

#define DEBUG_TYPE "lld"

using namespace llvm;
using namespace llvm::object;
using namespace llvm::sys;
using namespace llvm::wasm;

using namespace lld;
using namespace lld::wasm;

Configuration *lld::wasm::Config;

namespace {

// Create enum with OPT_xxx values for each option in Options.td
enum {
  OPT_INVALID = 0,
#define OPTION(_1, _2, ID, _4, _5, _6, _7, _8, _9, _10, _11, _12) OPT_##ID,
#include "Options.inc"
#undef OPTION
};

// This function is called on startup. We need this for LTO since
// LTO calls LLVM functions to compile bitcode files to native code.
// Technically this can be delayed until we read bitcode files, but
// we don't bother to do lazily because the initialization is fast.
static void initLLVM() {
  InitializeAllTargets();
  InitializeAllTargetMCs();
  InitializeAllAsmPrinters();
  InitializeAllAsmParsers();
}

class LinkerDriver {
public:
  void link(ArrayRef<const char *> ArgsArr);

private:
  void createFiles(opt::InputArgList &Args);
  void addFile(StringRef Path);
  void addLibrary(StringRef Name);

  // True if we are in --whole-archive and --no-whole-archive.
  bool InWholeArchive = false;

  std::vector<InputFile *> Files;
};
} // anonymous namespace

bool lld::wasm::link(ArrayRef<const char *> Args, bool CanExitEarly,
                     raw_ostream &Error) {
  errorHandler().LogName = args::getFilenameWithoutExe(Args[0]);
  errorHandler().ErrorOS = &Error;
  errorHandler().ColorDiagnostics = Error.has_colors();
  errorHandler().ErrorLimitExceededMsg =
      "too many errors emitted, stopping now (use "
      "-error-limit=0 to see all errors)";

  Config = make<Configuration>();
  Symtab = make<SymbolTable>();

  initLLVM();
  LinkerDriver().link(Args);

  // Exit immediately if we don't need to return to the caller.
  // This saves time because the overhead of calling destructors
  // for all globally-allocated objects is not negligible.
  if (CanExitEarly)
    exitLld(errorCount() ? 1 : 0);

  freeArena();
  return !errorCount();
}

// Create prefix string literals used in Options.td
#define PREFIX(NAME, VALUE) const char *const NAME[] = VALUE;
#include "Options.inc"
#undef PREFIX

// Create table mapping all options defined in Options.td
static const opt::OptTable::Info OptInfo[] = {
#define OPTION(X1, X2, ID, KIND, GROUP, ALIAS, X7, X8, X9, X10, X11, X12)      \
  {X1, X2, X10,         X11,         OPT_##ID, opt::Option::KIND##Class,       \
   X9, X8, OPT_##GROUP, OPT_##ALIAS, X7,       X12},
#include "Options.inc"
#undef OPTION
};

namespace {
class WasmOptTable : public llvm::opt::OptTable {
public:
  WasmOptTable() : OptTable(OptInfo) {}
  opt::InputArgList parse(ArrayRef<const char *> Argv);
};
} // namespace

// Set color diagnostics according to -color-diagnostics={auto,always,never}
// or -no-color-diagnostics flags.
static void handleColorDiagnostics(opt::InputArgList &Args) {
  auto *Arg = Args.getLastArg(OPT_color_diagnostics, OPT_color_diagnostics_eq,
                              OPT_no_color_diagnostics);
  if (!Arg)
    return;
  if (Arg->getOption().getID() == OPT_color_diagnostics) {
    errorHandler().ColorDiagnostics = true;
  } else if (Arg->getOption().getID() == OPT_no_color_diagnostics) {
    errorHandler().ColorDiagnostics = false;
  } else {
    StringRef S = Arg->getValue();
    if (S == "always")
      errorHandler().ColorDiagnostics = true;
    else if (S == "never")
      errorHandler().ColorDiagnostics = false;
    else if (S != "auto")
      error("unknown option: --color-diagnostics=" + S);
  }
}

// Find a file by concatenating given paths.
static Optional<std::string> findFile(StringRef Path1, const Twine &Path2) {
  SmallString<128> S;
  path::append(S, Path1, Path2);
  if (fs::exists(S))
    return S.str().str();
  return None;
}

opt::InputArgList WasmOptTable::parse(ArrayRef<const char *> Argv) {
  SmallVector<const char *, 256> Vec(Argv.data(), Argv.data() + Argv.size());

  unsigned MissingIndex;
  unsigned MissingCount;

  // Expand response files (arguments in the form of @<filename>)
  cl::ExpandResponseFiles(Saver, cl::TokenizeGNUCommandLine, Vec);

  opt::InputArgList Args = this->ParseArgs(Vec, MissingIndex, MissingCount);

  handleColorDiagnostics(Args);
  for (auto *Arg : Args.filtered(OPT_UNKNOWN))
    error("unknown argument: " + Arg->getSpelling());
  return Args;
}

// Currently we allow a ".imports" to live alongside a library. This can
// be used to specify a list of symbols which can be undefined at link
// time (imported from the environment.  For example libc.a include an
// import file that lists the syscall functions it relies on at runtime.
// In the long run this information would be better stored as a symbol
// attribute/flag in the object file itself.
// See: https://github.com/WebAssembly/tool-conventions/issues/35
static void readImportFile(StringRef Filename) {
  if (Optional<MemoryBufferRef> Buf = readFile(Filename))
    for (StringRef Sym : args::getLines(*Buf))
      Config->AllowUndefinedSymbols.insert(Sym);
}

// Returns slices of MB by parsing MB as an archive file.
// Each slice consists of a member file in the archive.
std::vector<MemoryBufferRef> static getArchiveMembers(MemoryBufferRef MB) {
  std::unique_ptr<Archive> File =
      CHECK(Archive::create(MB),
            MB.getBufferIdentifier() + ": failed to parse archive");

  std::vector<MemoryBufferRef> V;
  Error Err = Error::success();
  for (const ErrorOr<Archive::Child> &COrErr : File->children(Err)) {
    Archive::Child C =
        CHECK(COrErr, MB.getBufferIdentifier() +
                          ": could not get the child of the archive");
    MemoryBufferRef MBRef =
        CHECK(C.getMemoryBufferRef(),
              MB.getBufferIdentifier() +
                  ": could not get the buffer for a child of the archive");
    V.push_back(MBRef);
  }
  if (Err)
    fatal(MB.getBufferIdentifier() +
          ": Archive::children failed: " + toString(std::move(Err)));

  // Take ownership of memory buffers created for members of thin archives.
  for (std::unique_ptr<MemoryBuffer> &MB : File->takeThinBuffers())
    make<std::unique_ptr<MemoryBuffer>>(std::move(MB));

  return V;
}

void LinkerDriver::addFile(StringRef Path) {
  Optional<MemoryBufferRef> Buffer = readFile(Path);
  if (!Buffer.hasValue())
    return;
  MemoryBufferRef MBRef = *Buffer;

  switch (identify_magic(MBRef.getBuffer())) {
  case file_magic::archive: {
    // Handle -whole-archive.
    if (InWholeArchive) {
      for (MemoryBufferRef &M : getArchiveMembers(MBRef))
        Files.push_back(createObjectFile(M));
      return;
    }

    SmallString<128> ImportFile = Path;
    path::replace_extension(ImportFile, ".imports");
    if (fs::exists(ImportFile))
      readImportFile(ImportFile.str());

    Files.push_back(make<ArchiveFile>(MBRef));
    return;
  }
  case file_magic::bitcode:
  case file_magic::wasm_object:
    Files.push_back(createObjectFile(MBRef));
    break;
  default:
    error("unknown file type: " + MBRef.getBufferIdentifier());
  }
}

// Add a given library by searching it from input search paths.
void LinkerDriver::addLibrary(StringRef Name) {
  for (StringRef Dir : Config->SearchPaths) {
    if (Optional<std::string> S = findFile(Dir, "lib" + Name + ".a")) {
      addFile(*S);
      return;
    }
  }

  error("unable to find library -l" + Name);
}

void LinkerDriver::createFiles(opt::InputArgList &Args) {
  for (auto *Arg : Args) {
    switch (Arg->getOption().getUnaliasedOption().getID()) {
    case OPT_l:
      addLibrary(Arg->getValue());
      break;
    case OPT_INPUT:
      addFile(Arg->getValue());
      break;
    case OPT_whole_archive:
      InWholeArchive = true;
      break;
    case OPT_no_whole_archive:
      InWholeArchive = false;
      break;
    }
  }
}

static StringRef getEntry(opt::InputArgList &Args, StringRef Default) {
  auto *Arg = Args.getLastArg(OPT_entry, OPT_no_entry);
  if (!Arg)
    return Default;
  if (Arg->getOption().getID() == OPT_no_entry)
    return "";
  return Arg->getValue();
}

static const uint8_t UnreachableFn[] = {
    0x03 /* ULEB length */, 0x00 /* ULEB num locals */,
    0x00 /* opcode unreachable */, 0x0b /* opcode end */
};

// For weak undefined functions, there may be "call" instructions that reference
// the symbol. In this case, we need to synthesise a dummy/stub function that
// will abort at runtime, so that relocations can still provided an operand to
// the call instruction that passes Wasm validation.
static void handleWeakUndefines() {
  for (Symbol *Sym : Symtab->getSymbols()) {
    if (!Sym->isUndefined() || !Sym->isWeak())
      continue;
    auto *FuncSym = dyn_cast<FunctionSymbol>(Sym);
    if (!FuncSym)
      continue;

    // It is possible for undefined functions not to have a signature (eg. if
    // added via "--undefined"), but weak undefined ones do have a signature.
    assert(FuncSym->Signature);
    const WasmSignature &Sig = *FuncSym->Signature;

    // Add a synthetic dummy for weak undefined functions.  These dummies will
    // be GC'd if not used as the target of any "call" instructions.
    std::string SymName = toString(*Sym);
    StringRef DebugName = Saver.save("undefined function " + SymName);
    auto *Func = make<SyntheticFunction>(Sig, Sym->getName(), DebugName);
    Func->setBody(UnreachableFn);
    // Ensure it compares equal to the null pointer, and so that table relocs
    // don't pull in the stub body (only call-operand relocs should do that).
    Func->setTableIndex(0);
    Symtab->SyntheticFunctions.emplace_back(Func);
    // Hide our dummy to prevent export.
    uint32_t Flags = WASM_SYMBOL_VISIBILITY_HIDDEN;
    replaceSymbol<DefinedFunction>(Sym, Sym->getName(), Flags, nullptr, Func);
  }
}

// Some Config members do not directly correspond to any particular
// command line options, but computed based on other Config values.
// This function initialize such members. See Config.h for the details
// of these values.
static void setConfigs(opt::InputArgList &Args) {
  Config->AllowUndefined = Args.hasArg(OPT_allow_undefined);
  Config->CompressRelocations = Args.hasArg(OPT_compress_relocations);
  Config->Demangle = Args.hasFlag(OPT_demangle, OPT_no_demangle, true);
  Config->DisableVerify = Args.hasArg(OPT_disable_verify);
  Config->Entry = getEntry(Args, Args.hasArg(OPT_relocatable) ? "" : "_start");
  Config->ExportAll = Args.hasArg(OPT_export_all);
  Config->ExportDynamic = Args.hasFlag(OPT_export_dynamic,
      OPT_no_export_dynamic, false);
  Config->ExportTable = Args.hasArg(OPT_export_table);
  errorHandler().FatalWarnings =
      Args.hasFlag(OPT_fatal_warnings, OPT_no_fatal_warnings, false);
  Config->ImportMemory = Args.hasArg(OPT_import_memory);
  Config->SharedMemory = Args.hasArg(OPT_shared_memory);
  Config->ImportTable = Args.hasArg(OPT_import_table);
  Config->LTOO = args::getInteger(Args, OPT_lto_O, 2);
  Config->LTOPartitions = args::getInteger(Args, OPT_lto_partitions, 1);
  Config->Optimize = args::getInteger(Args, OPT_O, 0);
  Config->OutputFile = Args.getLastArgValue(OPT_o);
  Config->Relocatable = Args.hasArg(OPT_relocatable);
  Config->GcSections =
      Args.hasFlag(OPT_gc_sections, OPT_no_gc_sections, !Config->Relocatable);
  Config->MergeDataSegments =
      Args.hasFlag(OPT_merge_data_segments, OPT_no_merge_data_segments,
                   !Config->Relocatable);
  Config->Pie = Args.hasFlag(OPT_pie, OPT_no_pie, false);
  Config->PrintGcSections =
      Args.hasFlag(OPT_print_gc_sections, OPT_no_print_gc_sections, false);
  Config->SaveTemps = Args.hasArg(OPT_save_temps);
  Config->SearchPaths = args::getStrings(Args, OPT_L);
  Config->Shared = Args.hasArg(OPT_shared);
  Config->StripAll = Args.hasArg(OPT_strip_all);
  Config->StripDebug = Args.hasArg(OPT_strip_debug);
  Config->StackFirst = Args.hasArg(OPT_stack_first);
  Config->ThinLTOCacheDir = Args.getLastArgValue(OPT_thinlto_cache_dir);
  Config->ThinLTOCachePolicy = CHECK(
      parseCachePruningPolicy(Args.getLastArgValue(OPT_thinlto_cache_policy)),
      "--thinlto-cache-policy: invalid cache policy");
  Config->ThinLTOJobs = args::getInteger(Args, OPT_thinlto_jobs, -1u);
  errorHandler().Verbose = Args.hasArg(OPT_verbose);
  ThreadsEnabled = Args.hasFlag(OPT_threads, OPT_no_threads, true);

  Config->InitialMemory = args::getInteger(Args, OPT_initial_memory, 0);
  Config->GlobalBase = args::getInteger(Args, OPT_global_base, 1024);
  Config->MaxMemory = args::getInteger(Args, OPT_max_memory, 0);
  Config->ZStackSize =
      args::getZOptionValue(Args, OPT_z, "stack-size", WasmPageSize);
}

// Some command line options or some combinations of them are not allowed.
// This function checks for such errors.
static void checkOptions(opt::InputArgList &Args) {
  if (!Config->StripDebug && !Config->StripAll && Config->CompressRelocations)
    error("--compress-relocations is incompatible with output debug"
          " information. Please pass --strip-debug or --strip-all");

  if (Config->LTOO > 3)
    error("invalid optimization level for LTO: " + Twine(Config->LTOO));
  if (Config->LTOPartitions == 0)
    error("--lto-partitions: number of threads must be > 0");
  if (Config->ThinLTOJobs == 0)
    error("--thinlto-jobs: number of threads must be > 0");

  if (Config->Pie && Config->Shared)
    error("-shared and -pie may not be used together");

  if (Config->OutputFile.empty())
    error("no output file specified");

  if (Config->ImportTable && Config->ExportTable)
    error("--import-table and --export-table may not be used together");

  if (Config->Relocatable) {
    if (!Config->Entry.empty())
      error("entry point specified for relocatable output file");
    if (Config->GcSections)
      error("-r and --gc-sections may not be used together");
    if (Config->CompressRelocations)
      error("-r -and --compress-relocations may not be used together");
    if (Args.hasArg(OPT_undefined))
      error("-r -and --undefined may not be used together");
    if (Config->Pie)
      error("-r and -pie may not be used together");
  }
}

// Force Sym to be entered in the output. Used for -u or equivalent.
static Symbol *handleUndefined(StringRef Name) {
  Symbol *Sym = Symtab->find(Name);
  if (!Sym)
    return nullptr;

  // Since symbol S may not be used inside the program, LTO may
  // eliminate it. Mark the symbol as "used" to prevent it.
  Sym->IsUsedInRegularObj = true;

  if (auto *LazySym = dyn_cast<LazySymbol>(Sym))
    LazySym->fetch();

  return Sym;
}

static UndefinedGlobal *
createUndefinedGlobal(StringRef Name, llvm::wasm::WasmGlobalType *Type) {
  auto *Sym =
      cast<UndefinedGlobal>(Symtab->addUndefinedGlobal(Name, Name,
                                                       DefaultModule, 0,
                                                       nullptr, Type));
  Config->AllowUndefinedSymbols.insert(Sym->getName());
  Sym->IsUsedInRegularObj = true;
  return Sym;
}

// Create ABI-defined synthetic symbols
static void createSyntheticSymbols() {
  static WasmSignature NullSignature = {{}, {}};
  static llvm::wasm::WasmGlobalType GlobalTypeI32 = {WASM_TYPE_I32, false};
  static llvm::wasm::WasmGlobalType MutableGlobalTypeI32 = {WASM_TYPE_I32,
                                                            true};

  if (!Config->Relocatable)
    WasmSym::CallCtors = Symtab->addSyntheticFunction(
        "__wasm_call_ctors", WASM_SYMBOL_VISIBILITY_HIDDEN,
        make<SyntheticFunction>(NullSignature, "__wasm_call_ctors"));

  // The __stack_pointer is imported in the shared library case, and exported
  // in the non-shared (executable) case.
  if (Config->Shared) {
    WasmSym::StackPointer =
        createUndefinedGlobal("__stack_pointer", &MutableGlobalTypeI32);
  } else {
    llvm::wasm::WasmGlobal Global;
    Global.Type = {WASM_TYPE_I32, true};
    Global.InitExpr.Value.Int32 = 0;
    Global.InitExpr.Opcode = WASM_OPCODE_I32_CONST;
    Global.SymbolName = "__stack_pointer";
    auto *StackPointer = make<InputGlobal>(Global, nullptr);
    StackPointer->Live = true;
    // For non-PIC code
    // TODO(sbc): Remove WASM_SYMBOL_VISIBILITY_HIDDEN when the mutable global
    // spec proposal is implemented in all major browsers.
    // See: https://github.com/WebAssembly/mutable-global
    WasmSym::StackPointer = Symtab->addSyntheticGlobal(
        "__stack_pointer", WASM_SYMBOL_VISIBILITY_HIDDEN, StackPointer);
    WasmSym::HeapBase = Symtab->addSyntheticDataSymbol("__heap_base", 0);
    WasmSym::DataEnd = Symtab->addSyntheticDataSymbol("__data_end", 0);

    // These two synthetic symbols exist purely for the embedder so we always
    // want to export them.
    WasmSym::HeapBase->ForceExport = true;
    WasmSym::DataEnd->ForceExport = true;
  }

  if (Config->Pic) {
    // For PIC code, we import two global variables (__memory_base and
    // __table_base) from the environment and use these as the offset at
    // which to load our static data and function table.
    // See:
    // https://github.com/WebAssembly/tool-conventions/blob/master/DynamicLinking.md
    WasmSym::MemoryBase =
        createUndefinedGlobal("__memory_base", &GlobalTypeI32);
    WasmSym::TableBase = createUndefinedGlobal("__table_base", &GlobalTypeI32);
    WasmSym::MemoryBase->markLive();
    WasmSym::TableBase->markLive();
  }

  WasmSym::DsoHandle = Symtab->addSyntheticDataSymbol(
      "__dso_handle", WASM_SYMBOL_VISIBILITY_HIDDEN);
}

void LinkerDriver::link(ArrayRef<const char *> ArgsArr) {
  WasmOptTable Parser;
  opt::InputArgList Args = Parser.parse(ArgsArr.slice(1));

  // Handle --help
  if (Args.hasArg(OPT_help)) {
    Parser.PrintHelp(outs(),
                     (std::string(ArgsArr[0]) + " [options] file...").c_str(),
                     "LLVM Linker", false);
    return;
  }

  // Handle --version
  if (Args.hasArg(OPT_version) || Args.hasArg(OPT_v)) {
    outs() << getLLDVersion() << "\n";
    return;
  }

  // Parse and evaluate -mllvm options.
  std::vector<const char *> V;
  V.push_back("wasm-ld (LLVM option parsing)");
  for (auto *Arg : Args.filtered(OPT_mllvm))
    V.push_back(Arg->getValue());
  cl::ParseCommandLineOptions(V.size(), V.data());

  errorHandler().ErrorLimit = args::getInteger(Args, OPT_error_limit, 20);

  setConfigs(Args);
  checkOptions(Args);

  if (auto *Arg = Args.getLastArg(OPT_allow_undefined_file))
    readImportFile(Arg->getValue());

  if (!Args.hasArg(OPT_INPUT)) {
    error("no input files");
    return;
  }

  Config->Pic = Config->Pie || Config->Shared;

  if (Config->Pic) {
    if (Config->ExportTable)
      error("-shared/-pie is incompatible with --export-table");
    Config->ImportTable = true;
  }

  if (Config->Shared) {
    Config->ExportDynamic = true;
    Config->AllowUndefined = true;
  }

  if (!Config->Relocatable)
    createSyntheticSymbols();

  createFiles(Args);
  if (errorCount())
    return;

  // Add all files to the symbol table. This will add almost all
  // symbols that we need to the symbol table.
  for (InputFile *F : Files)
    Symtab->addFile(F);
  if (errorCount())
    return;

  // Handle the `--undefined <sym>` options.
  for (auto *Arg : Args.filtered(OPT_undefined))
    handleUndefined(Arg->getValue());

  // Handle the `--export <sym>` options
  // This works like --undefined but also exports the symbol if its found
  for (auto *Arg : Args.filtered(OPT_export)) {
    Symbol *Sym = handleUndefined(Arg->getValue());
    if (Sym && Sym->isDefined())
      Sym->ForceExport = true;
    else if (!Config->AllowUndefined)
      error(Twine("symbol exported via --export not found: ") +
            Arg->getValue());
  }

  Symbol *EntrySym = nullptr;
  if (!Config->Relocatable) {
    // Add synthetic dummies for weak undefined functions.
    handleWeakUndefines();

    if (!Config->Shared && !Config->Entry.empty()) {
      EntrySym = handleUndefined(Config->Entry);
      if (EntrySym && EntrySym->isDefined())
        EntrySym->ForceExport = true;
      else
        error("entry symbol not defined (pass --no-entry to supress): " +
              Config->Entry);
    }

    // Make sure we have resolved all symbols.
    if (!Config->AllowUndefined)
      Symtab->reportRemainingUndefines();
  }

  if (errorCount())
    return;

  // Do link-time optimization if given files are LLVM bitcode files.
  // This compiles bitcode files into real object files.
  Symtab->addCombinedLTOObject();
  if (errorCount())
    return;

  if (EntrySym)
    EntrySym->setHidden(false);

  if (errorCount())
    return;

  // Do size optimizations: garbage collection
  markLive();

  // Write the result to the file.
  writeResult();
}
