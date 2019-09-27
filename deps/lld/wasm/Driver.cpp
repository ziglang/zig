//===- Driver.cpp ---------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
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
#include "lld/Common/Reproduce.h"
#include "lld/Common/Strings.h"
#include "lld/Common/Threads.h"
#include "lld/Common/Version.h"
#include "llvm/ADT/Twine.h"
#include "llvm/Object/Wasm.h"
#include "llvm/Option/Arg.h"
#include "llvm/Option/ArgList.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/Process.h"
#include "llvm/Support/TarWriter.h"
#include "llvm/Support/TargetSelect.h"

#define DEBUG_TYPE "lld"

using namespace llvm;
using namespace llvm::object;
using namespace llvm::sys;
using namespace llvm::wasm;

using namespace lld;
using namespace lld::wasm;

Configuration *lld::wasm::config;

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
  void link(ArrayRef<const char *> argsArr);

private:
  void createFiles(opt::InputArgList &args);
  void addFile(StringRef path);
  void addLibrary(StringRef name);

  // True if we are in --whole-archive and --no-whole-archive.
  bool inWholeArchive = false;

  std::vector<InputFile *> files;
};
} // anonymous namespace

bool lld::wasm::link(ArrayRef<const char *> args, bool canExitEarly,
                     raw_ostream &error) {
  errorHandler().logName = args::getFilenameWithoutExe(args[0]);
  errorHandler().errorOS = &error;
  errorHandler().colorDiagnostics = error.has_colors();
  errorHandler().errorLimitExceededMsg =
      "too many errors emitted, stopping now (use "
      "-error-limit=0 to see all errors)";

  config = make<Configuration>();
  symtab = make<SymbolTable>();

  initLLVM();
  LinkerDriver().link(args);

  // Exit immediately if we don't need to return to the caller.
  // This saves time because the overhead of calling destructors
  // for all globally-allocated objects is not negligible.
  if (canExitEarly)
    exitLld(errorCount() ? 1 : 0);

  freeArena();
  return !errorCount();
}

// Create prefix string literals used in Options.td
#define PREFIX(NAME, VALUE) const char *const NAME[] = VALUE;
#include "Options.inc"
#undef PREFIX

// Create table mapping all options defined in Options.td
static const opt::OptTable::Info optInfo[] = {
#define OPTION(X1, X2, ID, KIND, GROUP, ALIAS, X7, X8, X9, X10, X11, X12)      \
  {X1, X2, X10,         X11,         OPT_##ID, opt::Option::KIND##Class,       \
   X9, X8, OPT_##GROUP, OPT_##ALIAS, X7,       X12},
#include "Options.inc"
#undef OPTION
};

namespace {
class WasmOptTable : public llvm::opt::OptTable {
public:
  WasmOptTable() : OptTable(optInfo) {}
  opt::InputArgList parse(ArrayRef<const char *> argv);
};
} // namespace

// Set color diagnostics according to -color-diagnostics={auto,always,never}
// or -no-color-diagnostics flags.
static void handleColorDiagnostics(opt::InputArgList &args) {
  auto *arg = args.getLastArg(OPT_color_diagnostics, OPT_color_diagnostics_eq,
                              OPT_no_color_diagnostics);
  if (!arg)
    return;
  if (arg->getOption().getID() == OPT_color_diagnostics) {
    errorHandler().colorDiagnostics = true;
  } else if (arg->getOption().getID() == OPT_no_color_diagnostics) {
    errorHandler().colorDiagnostics = false;
  } else {
    StringRef s = arg->getValue();
    if (s == "always")
      errorHandler().colorDiagnostics = true;
    else if (s == "never")
      errorHandler().colorDiagnostics = false;
    else if (s != "auto")
      error("unknown option: --color-diagnostics=" + s);
  }
}

// Find a file by concatenating given paths.
static Optional<std::string> findFile(StringRef path1, const Twine &path2) {
  SmallString<128> s;
  path::append(s, path1, path2);
  if (fs::exists(s))
    return s.str().str();
  return None;
}

opt::InputArgList WasmOptTable::parse(ArrayRef<const char *> argv) {
  SmallVector<const char *, 256> vec(argv.data(), argv.data() + argv.size());

  unsigned missingIndex;
  unsigned missingCount;

  // Expand response files (arguments in the form of @<filename>)
  cl::ExpandResponseFiles(saver, cl::TokenizeGNUCommandLine, vec);

  opt::InputArgList args = this->ParseArgs(vec, missingIndex, missingCount);

  handleColorDiagnostics(args);
  for (auto *arg : args.filtered(OPT_UNKNOWN))
    error("unknown argument: " + arg->getAsString(args));
  return args;
}

// Currently we allow a ".imports" to live alongside a library. This can
// be used to specify a list of symbols which can be undefined at link
// time (imported from the environment.  For example libc.a include an
// import file that lists the syscall functions it relies on at runtime.
// In the long run this information would be better stored as a symbol
// attribute/flag in the object file itself.
// See: https://github.com/WebAssembly/tool-conventions/issues/35
static void readImportFile(StringRef filename) {
  if (Optional<MemoryBufferRef> buf = readFile(filename))
    for (StringRef sym : args::getLines(*buf))
      config->allowUndefinedSymbols.insert(sym);
}

// Returns slices of MB by parsing MB as an archive file.
// Each slice consists of a member file in the archive.
std::vector<MemoryBufferRef> static getArchiveMembers(MemoryBufferRef mb) {
  std::unique_ptr<Archive> file =
      CHECK(Archive::create(mb),
            mb.getBufferIdentifier() + ": failed to parse archive");

  std::vector<MemoryBufferRef> v;
  Error err = Error::success();
  for (const ErrorOr<Archive::Child> &cOrErr : file->children(err)) {
    Archive::Child c =
        CHECK(cOrErr, mb.getBufferIdentifier() +
                          ": could not get the child of the archive");
    MemoryBufferRef mbref =
        CHECK(c.getMemoryBufferRef(),
              mb.getBufferIdentifier() +
                  ": could not get the buffer for a child of the archive");
    v.push_back(mbref);
  }
  if (err)
    fatal(mb.getBufferIdentifier() +
          ": Archive::children failed: " + toString(std::move(err)));

  // Take ownership of memory buffers created for members of thin archives.
  for (std::unique_ptr<MemoryBuffer> &mb : file->takeThinBuffers())
    make<std::unique_ptr<MemoryBuffer>>(std::move(mb));

  return v;
}

void LinkerDriver::addFile(StringRef path) {
  Optional<MemoryBufferRef> buffer = readFile(path);
  if (!buffer.hasValue())
    return;
  MemoryBufferRef mbref = *buffer;

  switch (identify_magic(mbref.getBuffer())) {
  case file_magic::archive: {
    SmallString<128> importFile = path;
    path::replace_extension(importFile, ".imports");
    if (fs::exists(importFile))
      readImportFile(importFile.str());

    // Handle -whole-archive.
    if (inWholeArchive) {
      for (MemoryBufferRef &m : getArchiveMembers(mbref))
        files.push_back(createObjectFile(m, path));
      return;
    }

    std::unique_ptr<Archive> file =
        CHECK(Archive::create(mbref), path + ": failed to parse archive");

    if (!file->isEmpty() && !file->hasSymbolTable()) {
      error(mbref.getBufferIdentifier() +
            ": archive has no index; run ranlib to add one");
    }

    files.push_back(make<ArchiveFile>(mbref));
    return;
  }
  case file_magic::bitcode:
  case file_magic::wasm_object:
    files.push_back(createObjectFile(mbref));
    break;
  default:
    error("unknown file type: " + mbref.getBufferIdentifier());
  }
}

// Add a given library by searching it from input search paths.
void LinkerDriver::addLibrary(StringRef name) {
  for (StringRef dir : config->searchPaths) {
    if (Optional<std::string> s = findFile(dir, "lib" + name + ".a")) {
      addFile(*s);
      return;
    }
  }

  error("unable to find library -l" + name);
}

void LinkerDriver::createFiles(opt::InputArgList &args) {
  for (auto *arg : args) {
    switch (arg->getOption().getID()) {
    case OPT_l:
      addLibrary(arg->getValue());
      break;
    case OPT_INPUT:
      addFile(arg->getValue());
      break;
    case OPT_whole_archive:
      inWholeArchive = true;
      break;
    case OPT_no_whole_archive:
      inWholeArchive = false;
      break;
    }
  }
}

static StringRef getEntry(opt::InputArgList &args) {
  auto *arg = args.getLastArg(OPT_entry, OPT_no_entry);
  if (!arg) {
    if (args.hasArg(OPT_relocatable))
      return "";
    if (args.hasArg(OPT_shared))
      return "__wasm_call_ctors";
    return "_start";
  }
  if (arg->getOption().getID() == OPT_no_entry)
    return "";
  return arg->getValue();
}

// Initializes Config members by the command line options.
static void readConfigs(opt::InputArgList &args) {
  config->allowUndefined = args.hasArg(OPT_allow_undefined);
  config->checkFeatures =
      args.hasFlag(OPT_check_features, OPT_no_check_features, true);
  config->compressRelocations = args.hasArg(OPT_compress_relocations);
  config->demangle = args.hasFlag(OPT_demangle, OPT_no_demangle, true);
  config->disableVerify = args.hasArg(OPT_disable_verify);
  config->emitRelocs = args.hasArg(OPT_emit_relocs);
  config->entry = getEntry(args);
  config->exportAll = args.hasArg(OPT_export_all);
  config->exportDynamic = args.hasFlag(OPT_export_dynamic,
      OPT_no_export_dynamic, false);
  config->exportTable = args.hasArg(OPT_export_table);
  errorHandler().fatalWarnings =
      args.hasFlag(OPT_fatal_warnings, OPT_no_fatal_warnings, false);
  config->importMemory = args.hasArg(OPT_import_memory);
  config->sharedMemory = args.hasArg(OPT_shared_memory);
  config->passiveSegments = args.hasFlag(
      OPT_passive_segments, OPT_active_segments, config->sharedMemory);
  config->importTable = args.hasArg(OPT_import_table);
  config->ltoo = args::getInteger(args, OPT_lto_O, 2);
  config->ltoPartitions = args::getInteger(args, OPT_lto_partitions, 1);
  config->optimize = args::getInteger(args, OPT_O, 0);
  config->outputFile = args.getLastArgValue(OPT_o);
  config->relocatable = args.hasArg(OPT_relocatable);
  config->gcSections =
      args.hasFlag(OPT_gc_sections, OPT_no_gc_sections, !config->relocatable);
  config->mergeDataSegments =
      args.hasFlag(OPT_merge_data_segments, OPT_no_merge_data_segments,
                   !config->relocatable);
  config->pie = args.hasFlag(OPT_pie, OPT_no_pie, false);
  config->printGcSections =
      args.hasFlag(OPT_print_gc_sections, OPT_no_print_gc_sections, false);
  config->saveTemps = args.hasArg(OPT_save_temps);
  config->searchPaths = args::getStrings(args, OPT_L);
  config->shared = args.hasArg(OPT_shared);
  config->stripAll = args.hasArg(OPT_strip_all);
  config->stripDebug = args.hasArg(OPT_strip_debug);
  config->stackFirst = args.hasArg(OPT_stack_first);
  config->trace = args.hasArg(OPT_trace);
  config->thinLTOCacheDir = args.getLastArgValue(OPT_thinlto_cache_dir);
  config->thinLTOCachePolicy = CHECK(
      parseCachePruningPolicy(args.getLastArgValue(OPT_thinlto_cache_policy)),
      "--thinlto-cache-policy: invalid cache policy");
  config->thinLTOJobs = args::getInteger(args, OPT_thinlto_jobs, -1u);
  errorHandler().verbose = args.hasArg(OPT_verbose);
  LLVM_DEBUG(errorHandler().verbose = true);
  threadsEnabled = args.hasFlag(OPT_threads, OPT_no_threads, true);

  config->initialMemory = args::getInteger(args, OPT_initial_memory, 0);
  config->globalBase = args::getInteger(args, OPT_global_base, 1024);
  config->maxMemory = args::getInteger(args, OPT_max_memory, 0);
  config->zStackSize =
      args::getZOptionValue(args, OPT_z, "stack-size", WasmPageSize);

  if (auto *arg = args.getLastArg(OPT_features)) {
    config->features =
        llvm::Optional<std::vector<std::string>>(std::vector<std::string>());
    for (StringRef s : arg->getValues())
      config->features->push_back(s);
  }
}

// Some Config members do not directly correspond to any particular
// command line options, but computed based on other Config values.
// This function initialize such members. See Config.h for the details
// of these values.
static void setConfigs() {
  config->isPic = config->pie || config->shared;

  if (config->isPic) {
    if (config->exportTable)
      error("-shared/-pie is incompatible with --export-table");
    config->importTable = true;
  }

  if (config->shared) {
    config->importMemory = true;
    config->exportDynamic = true;
    config->allowUndefined = true;
  }
}

// Some command line options or some combinations of them are not allowed.
// This function checks for such errors.
static void checkOptions(opt::InputArgList &args) {
  if (!config->stripDebug && !config->stripAll && config->compressRelocations)
    error("--compress-relocations is incompatible with output debug"
          " information. Please pass --strip-debug or --strip-all");

  if (config->ltoo > 3)
    error("invalid optimization level for LTO: " + Twine(config->ltoo));
  if (config->ltoPartitions == 0)
    error("--lto-partitions: number of threads must be > 0");
  if (config->thinLTOJobs == 0)
    error("--thinlto-jobs: number of threads must be > 0");

  if (config->pie && config->shared)
    error("-shared and -pie may not be used together");

  if (config->outputFile.empty())
    error("no output file specified");

  if (config->importTable && config->exportTable)
    error("--import-table and --export-table may not be used together");

  if (config->relocatable) {
    if (!config->entry.empty())
      error("entry point specified for relocatable output file");
    if (config->gcSections)
      error("-r and --gc-sections may not be used together");
    if (config->compressRelocations)
      error("-r -and --compress-relocations may not be used together");
    if (args.hasArg(OPT_undefined))
      error("-r -and --undefined may not be used together");
    if (config->pie)
      error("-r and -pie may not be used together");
  }
}

// Force Sym to be entered in the output. Used for -u or equivalent.
static Symbol *handleUndefined(StringRef name) {
  Symbol *sym = symtab->find(name);
  if (!sym)
    return nullptr;

  // Since symbol S may not be used inside the program, LTO may
  // eliminate it. Mark the symbol as "used" to prevent it.
  sym->isUsedInRegularObj = true;

  if (auto *lazySym = dyn_cast<LazySymbol>(sym))
    lazySym->fetch();

  return sym;
}

static UndefinedGlobal *
createUndefinedGlobal(StringRef name, llvm::wasm::WasmGlobalType *type) {
  auto *sym =
      cast<UndefinedGlobal>(symtab->addUndefinedGlobal(name, name,
                                                       defaultModule, 0,
                                                       nullptr, type));
  config->allowUndefinedSymbols.insert(sym->getName());
  sym->isUsedInRegularObj = true;
  return sym;
}

// Create ABI-defined synthetic symbols
static void createSyntheticSymbols() {
  static WasmSignature nullSignature = {{}, {}};
  static WasmSignature i32ArgSignature = {{}, {ValType::I32}};
  static llvm::wasm::WasmGlobalType globalTypeI32 = {WASM_TYPE_I32, false};
  static llvm::wasm::WasmGlobalType mutableGlobalTypeI32 = {WASM_TYPE_I32,
                                                            true};

  if (!config->relocatable) {
    WasmSym::callCtors = symtab->addSyntheticFunction(
        "__wasm_call_ctors", WASM_SYMBOL_VISIBILITY_HIDDEN,
        make<SyntheticFunction>(nullSignature, "__wasm_call_ctors"));

    if (config->passiveSegments) {
      // Passive segments are used to avoid memory being reinitialized on each
      // thread's instantiation. These passive segments are initialized and
      // dropped in __wasm_init_memory, which is the first function called from
      // __wasm_call_ctors.
      WasmSym::initMemory = symtab->addSyntheticFunction(
          "__wasm_init_memory", WASM_SYMBOL_VISIBILITY_HIDDEN,
          make<SyntheticFunction>(nullSignature, "__wasm_init_memory"));
    }

    if (config->isPic) {
      // For PIC code we create a synthetic function __wasm_apply_relocs which
      // is called from __wasm_call_ctors before the user-level constructors.
      WasmSym::applyRelocs = symtab->addSyntheticFunction(
          "__wasm_apply_relocs", WASM_SYMBOL_VISIBILITY_HIDDEN,
          make<SyntheticFunction>(nullSignature, "__wasm_apply_relocs"));
    }
  }

  if (!config->shared)
    WasmSym::dataEnd = symtab->addOptionalDataSymbol("__data_end");

  if (config->isPic) {
    WasmSym::stackPointer =
        createUndefinedGlobal("__stack_pointer", &mutableGlobalTypeI32);
    // For PIC code, we import two global variables (__memory_base and
    // __table_base) from the environment and use these as the offset at
    // which to load our static data and function table.
    // See:
    // https://github.com/WebAssembly/tool-conventions/blob/master/DynamicLinking.md
    WasmSym::memoryBase =
        createUndefinedGlobal("__memory_base", &globalTypeI32);
    WasmSym::tableBase = createUndefinedGlobal("__table_base", &globalTypeI32);
    WasmSym::memoryBase->markLive();
    WasmSym::tableBase->markLive();
  } else {
    llvm::wasm::WasmGlobal global;
    global.Type = {WASM_TYPE_I32, true};
    global.InitExpr.Value.Int32 = 0;
    global.InitExpr.Opcode = WASM_OPCODE_I32_CONST;
    global.SymbolName = "__stack_pointer";
    auto *stackPointer = make<InputGlobal>(global, nullptr);
    stackPointer->live = true;
    // For non-PIC code
    // TODO(sbc): Remove WASM_SYMBOL_VISIBILITY_HIDDEN when the mutable global
    // spec proposal is implemented in all major browsers.
    // See: https://github.com/WebAssembly/mutable-global
    WasmSym::stackPointer = symtab->addSyntheticGlobal(
        "__stack_pointer", WASM_SYMBOL_VISIBILITY_HIDDEN, stackPointer);
    WasmSym::globalBase = symtab->addOptionalDataSymbol("__global_base");
    WasmSym::heapBase = symtab->addOptionalDataSymbol("__heap_base");
  }

  if (config->sharedMemory && !config->shared) {
    llvm::wasm::WasmGlobal tlsBaseGlobal;
    tlsBaseGlobal.Type = {WASM_TYPE_I32, true};
    tlsBaseGlobal.InitExpr.Value.Int32 = 0;
    tlsBaseGlobal.InitExpr.Opcode = WASM_OPCODE_I32_CONST;
    tlsBaseGlobal.SymbolName = "__tls_base";
    WasmSym::tlsBase =
        symtab->addSyntheticGlobal("__tls_base", WASM_SYMBOL_VISIBILITY_HIDDEN,
                                   make<InputGlobal>(tlsBaseGlobal, nullptr));

    llvm::wasm::WasmGlobal tlsSizeGlobal;
    tlsSizeGlobal.Type = {WASM_TYPE_I32, false};
    tlsSizeGlobal.InitExpr.Value.Int32 = 0;
    tlsSizeGlobal.InitExpr.Opcode = WASM_OPCODE_I32_CONST;
    tlsSizeGlobal.SymbolName = "__tls_size";
    WasmSym::tlsSize =
        symtab->addSyntheticGlobal("__tls_size", WASM_SYMBOL_VISIBILITY_HIDDEN,
                                   make<InputGlobal>(tlsSizeGlobal, nullptr));

    WasmSym::initTLS = symtab->addSyntheticFunction(
        "__wasm_init_tls", WASM_SYMBOL_VISIBILITY_HIDDEN,
        make<SyntheticFunction>(i32ArgSignature, "__wasm_init_tls"));
  }

  WasmSym::dsoHandle = symtab->addSyntheticDataSymbol(
      "__dso_handle", WASM_SYMBOL_VISIBILITY_HIDDEN);
}

// Reconstructs command line arguments so that so that you can re-run
// the same command with the same inputs. This is for --reproduce.
static std::string createResponseFile(const opt::InputArgList &args) {
  SmallString<0> data;
  raw_svector_ostream os(data);

  // Copy the command line to the output while rewriting paths.
  for (auto *arg : args) {
    switch (arg->getOption().getID()) {
    case OPT_reproduce:
      break;
    case OPT_INPUT:
      os << quote(relativeToRoot(arg->getValue())) << "\n";
      break;
    case OPT_o:
      // If -o path contains directories, "lld @response.txt" will likely
      // fail because the archive we are creating doesn't contain empty
      // directories for the output path (-o doesn't create directories).
      // Strip directories to prevent the issue.
      os << "-o " << quote(sys::path::filename(arg->getValue())) << "\n";
      break;
    default:
      os << toString(*arg) << "\n";
    }
  }
  return data.str();
}

// The --wrap option is a feature to rename symbols so that you can write
// wrappers for existing functions. If you pass `-wrap=foo`, all
// occurrences of symbol `foo` are resolved to `wrap_foo` (so, you are
// expected to write `wrap_foo` function as a wrapper). The original
// symbol becomes accessible as `real_foo`, so you can call that from your
// wrapper.
//
// This data structure is instantiated for each -wrap option.
struct WrappedSymbol {
  Symbol *sym;
  Symbol *real;
  Symbol *wrap;
};

static Symbol *addUndefined(StringRef name) {
  return symtab->addUndefinedFunction(name, "", "", 0, nullptr, nullptr, false);
}

// Handles -wrap option.
//
// This function instantiates wrapper symbols. At this point, they seem
// like they are not being used at all, so we explicitly set some flags so
// that LTO won't eliminate them.
static std::vector<WrappedSymbol> addWrappedSymbols(opt::InputArgList &args) {
  std::vector<WrappedSymbol> v;
  DenseSet<StringRef> seen;

  for (auto *arg : args.filtered(OPT_wrap)) {
    StringRef name = arg->getValue();
    if (!seen.insert(name).second)
      continue;

    Symbol *sym = symtab->find(name);
    if (!sym)
      continue;

    Symbol *real = addUndefined(saver.save("__real_" + name));
    Symbol *wrap = addUndefined(saver.save("__wrap_" + name));
    v.push_back({sym, real, wrap});

    // We want to tell LTO not to inline symbols to be overwritten
    // because LTO doesn't know the final symbol contents after renaming.
    real->canInline = false;
    sym->canInline = false;

    // Tell LTO not to eliminate these symbols.
    sym->isUsedInRegularObj = true;
    wrap->isUsedInRegularObj = true;
    real->isUsedInRegularObj = false;
  }
  return v;
}

// Do renaming for -wrap by updating pointers to symbols.
//
// When this function is executed, only InputFiles and symbol table
// contain pointers to symbol objects. We visit them to replace pointers,
// so that wrapped symbols are swapped as instructed by the command line.
static void wrapSymbols(ArrayRef<WrappedSymbol> wrapped) {
  DenseMap<Symbol *, Symbol *> map;
  for (const WrappedSymbol &w : wrapped) {
    map[w.sym] = w.wrap;
    map[w.real] = w.sym;
  }

  // Update pointers in input files.
  parallelForEach(symtab->objectFiles, [&](InputFile *file) {
    MutableArrayRef<Symbol *> syms = file->getMutableSymbols();
    for (size_t i = 0, e = syms.size(); i != e; ++i)
      if (Symbol *s = map.lookup(syms[i]))
        syms[i] = s;
  });

  // Update pointers in the symbol table.
  for (const WrappedSymbol &w : wrapped)
    symtab->wrap(w.sym, w.real, w.wrap);
}

void LinkerDriver::link(ArrayRef<const char *> argsArr) {
  WasmOptTable parser;
  opt::InputArgList args = parser.parse(argsArr.slice(1));

  // Handle --help
  if (args.hasArg(OPT_help)) {
    parser.PrintHelp(outs(),
                     (std::string(argsArr[0]) + " [options] file...").c_str(),
                     "LLVM Linker", false);
    return;
  }

  // Handle --version
  if (args.hasArg(OPT_version) || args.hasArg(OPT_v)) {
    outs() << getLLDVersion() << "\n";
    return;
  }

  // Handle --reproduce
  if (auto *arg = args.getLastArg(OPT_reproduce)) {
    StringRef path = arg->getValue();
    Expected<std::unique_ptr<TarWriter>> errOrWriter =
        TarWriter::create(path, path::stem(path));
    if (errOrWriter) {
      tar = std::move(*errOrWriter);
      tar->append("response.txt", createResponseFile(args));
      tar->append("version.txt", getLLDVersion() + "\n");
    } else {
      error("--reproduce: " + toString(errOrWriter.takeError()));
    }
  }

  // Parse and evaluate -mllvm options.
  std::vector<const char *> v;
  v.push_back("wasm-ld (LLVM option parsing)");
  for (auto *arg : args.filtered(OPT_mllvm))
    v.push_back(arg->getValue());
  cl::ParseCommandLineOptions(v.size(), v.data());

  errorHandler().errorLimit = args::getInteger(args, OPT_error_limit, 20);

  readConfigs(args);
  setConfigs();
  checkOptions(args);

  if (auto *arg = args.getLastArg(OPT_allow_undefined_file))
    readImportFile(arg->getValue());

  if (!args.hasArg(OPT_INPUT)) {
    error("no input files");
    return;
  }

  // Handle --trace-symbol.
  for (auto *arg : args.filtered(OPT_trace_symbol))
    symtab->trace(arg->getValue());

  for (auto *arg : args.filtered(OPT_export))
    config->exportedSymbols.insert(arg->getValue());

  if (!config->relocatable)
    createSyntheticSymbols();

  createFiles(args);
  if (errorCount())
    return;

  // Add all files to the symbol table. This will add almost all
  // symbols that we need to the symbol table.
  for (InputFile *f : files)
    symtab->addFile(f);
  if (errorCount())
    return;

  // Handle the `--undefined <sym>` options.
  for (auto *arg : args.filtered(OPT_undefined))
    handleUndefined(arg->getValue());

  // Handle the `--export <sym>` options
  // This works like --undefined but also exports the symbol if its found
  for (auto *arg : args.filtered(OPT_export))
    handleUndefined(arg->getValue());

  Symbol *entrySym = nullptr;
  if (!config->relocatable && !config->entry.empty()) {
    entrySym = handleUndefined(config->entry);
    if (entrySym && entrySym->isDefined())
      entrySym->forceExport = true;
    else
      error("entry symbol not defined (pass --no-entry to supress): " +
            config->entry);
  }

  if (errorCount())
    return;

  // Create wrapped symbols for -wrap option.
  std::vector<WrappedSymbol> wrapped = addWrappedSymbols(args);

  // Do link-time optimization if given files are LLVM bitcode files.
  // This compiles bitcode files into real object files.
  symtab->addCombinedLTOObject();
  if (errorCount())
    return;

  // Resolve any variant symbols that were created due to signature
  // mismatchs.
  symtab->handleSymbolVariants();
  if (errorCount())
    return;

  // Apply symbol renames for -wrap.
  if (!wrapped.empty())
    wrapSymbols(wrapped);

  for (auto *arg : args.filtered(OPT_export)) {
    Symbol *sym = symtab->find(arg->getValue());
    if (sym && sym->isDefined())
      sym->forceExport = true;
    else if (!config->allowUndefined)
      error(Twine("symbol exported via --export not found: ") +
            arg->getValue());
  }

  if (!config->relocatable) {
    // Add synthetic dummies for weak undefined functions.  Must happen
    // after LTO otherwise functions may not yet have signatures.
    symtab->handleWeakUndefines();
  }

  if (entrySym)
    entrySym->setHidden(false);

  if (errorCount())
    return;

  // Do size optimizations: garbage collection
  markLive();

  // Write the result to the file.
  writeResult();
}
