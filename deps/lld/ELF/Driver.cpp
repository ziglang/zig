//===- Driver.cpp ---------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// The driver drives the entire linking process. It is responsible for
// parsing command line options and doing whatever it is instructed to do.
//
// One notable thing in the LLD's driver when compared to other linkers is
// that the LLD's driver is agnostic on the host operating system.
// Other linkers usually have implicit default values (such as a dynamic
// linker path or library paths) for each host OS.
//
// I don't think implicit default values are useful because they are
// usually explicitly specified by the compiler driver. They can even
// be harmful when you are doing cross-linking. Therefore, in LLD, we
// simply trust the compiler driver to pass all required options and
// don't try to make effort on our side.
//
//===----------------------------------------------------------------------===//

#include "Driver.h"
#include "Config.h"
#include "ICF.h"
#include "InputFiles.h"
#include "InputSection.h"
#include "LinkerScript.h"
#include "MarkLive.h"
#include "OutputSections.h"
#include "ScriptParser.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "Writer.h"
#include "lld/Common/Args.h"
#include "lld/Common/Driver.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Filesystem.h"
#include "lld/Common/Memory.h"
#include "lld/Common/Strings.h"
#include "lld/Common/TargetOptionsCommandFlags.h"
#include "lld/Common/Threads.h"
#include "lld/Common/Version.h"
#include "llvm/ADT/SetVector.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/ADT/StringSwitch.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Compression.h"
#include "llvm/Support/GlobPattern.h"
#include "llvm/Support/LEB128.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/TarWriter.h"
#include "llvm/Support/TargetSelect.h"
#include "llvm/Support/raw_ostream.h"
#include <cstdlib>
#include <utility>

using namespace llvm;
using namespace llvm::ELF;
using namespace llvm::object;
using namespace llvm::sys;
using namespace llvm::support;

using namespace lld;
using namespace lld::elf;

Configuration *elf::config;
LinkerDriver *elf::driver;

static void setConfigs(opt::InputArgList &args);
static void readConfigs(opt::InputArgList &args);

bool elf::link(ArrayRef<const char *> args, bool canExitEarly,
               raw_ostream &error) {
  errorHandler().logName = args::getFilenameWithoutExe(args[0]);
  errorHandler().errorLimitExceededMsg =
      "too many errors emitted, stopping now (use "
      "-error-limit=0 to see all errors)";
  errorHandler().errorOS = &error;
  errorHandler().exitEarly = canExitEarly;
  errorHandler().colorDiagnostics = error.has_colors();

  inputSections.clear();
  outputSections.clear();
  binaryFiles.clear();
  bitcodeFiles.clear();
  objectFiles.clear();
  sharedFiles.clear();

  config = make<Configuration>();
  driver = make<LinkerDriver>();
  script = make<LinkerScript>();
  symtab = make<SymbolTable>();

  tar = nullptr;
  memset(&in, 0, sizeof(in));

  partitions = {Partition()};

  SharedFile::vernauxNum = 0;

  config->progName = args[0];

  driver->main(args);

  // Exit immediately if we don't need to return to the caller.
  // This saves time because the overhead of calling destructors
  // for all globally-allocated objects is not negligible.
  if (canExitEarly)
    exitLld(errorCount() ? 1 : 0);

  freeArena();
  return !errorCount();
}

// Parses a linker -m option.
static std::tuple<ELFKind, uint16_t, uint8_t> parseEmulation(StringRef emul) {
  uint8_t osabi = 0;
  StringRef s = emul;
  if (s.endswith("_fbsd")) {
    s = s.drop_back(5);
    osabi = ELFOSABI_FREEBSD;
  }

  std::pair<ELFKind, uint16_t> ret =
      StringSwitch<std::pair<ELFKind, uint16_t>>(s)
          .Cases("aarch64elf", "aarch64linux", "aarch64_elf64_le_vec",
                 {ELF64LEKind, EM_AARCH64})
          .Cases("armelf", "armelf_linux_eabi", {ELF32LEKind, EM_ARM})
          .Case("elf32_x86_64", {ELF32LEKind, EM_X86_64})
          .Cases("elf32btsmip", "elf32btsmipn32", {ELF32BEKind, EM_MIPS})
          .Cases("elf32ltsmip", "elf32ltsmipn32", {ELF32LEKind, EM_MIPS})
          .Case("elf32lriscv", {ELF32LEKind, EM_RISCV})
          .Cases("elf32ppc", "elf32ppclinux", {ELF32BEKind, EM_PPC})
          .Case("elf64btsmip", {ELF64BEKind, EM_MIPS})
          .Case("elf64ltsmip", {ELF64LEKind, EM_MIPS})
          .Case("elf64lriscv", {ELF64LEKind, EM_RISCV})
          .Case("elf64ppc", {ELF64BEKind, EM_PPC64})
          .Case("elf64lppc", {ELF64LEKind, EM_PPC64})
          .Cases("elf_amd64", "elf_x86_64", {ELF64LEKind, EM_X86_64})
          .Case("elf_i386", {ELF32LEKind, EM_386})
          .Case("elf_iamcu", {ELF32LEKind, EM_IAMCU})
          .Default({ELFNoneKind, EM_NONE});

  if (ret.first == ELFNoneKind)
    error("unknown emulation: " + emul);
  return std::make_tuple(ret.first, ret.second, osabi);
}

// Returns slices of MB by parsing MB as an archive file.
// Each slice consists of a member file in the archive.
std::vector<std::pair<MemoryBufferRef, uint64_t>> static getArchiveMembers(
    MemoryBufferRef mb) {
  std::unique_ptr<Archive> file =
      CHECK(Archive::create(mb),
            mb.getBufferIdentifier() + ": failed to parse archive");

  std::vector<std::pair<MemoryBufferRef, uint64_t>> v;
  Error err = Error::success();
  bool addToTar = file->isThin() && tar;
  for (const ErrorOr<Archive::Child> &cOrErr : file->children(err)) {
    Archive::Child c =
        CHECK(cOrErr, mb.getBufferIdentifier() +
                          ": could not get the child of the archive");
    MemoryBufferRef mbref =
        CHECK(c.getMemoryBufferRef(),
              mb.getBufferIdentifier() +
                  ": could not get the buffer for a child of the archive");
    if (addToTar)
      tar->append(relativeToRoot(check(c.getFullName())), mbref.getBuffer());
    v.push_back(std::make_pair(mbref, c.getChildOffset()));
  }
  if (err)
    fatal(mb.getBufferIdentifier() + ": Archive::children failed: " +
          toString(std::move(err)));

  // Take ownership of memory buffers created for members of thin archives.
  for (std::unique_ptr<MemoryBuffer> &mb : file->takeThinBuffers())
    make<std::unique_ptr<MemoryBuffer>>(std::move(mb));

  return v;
}

// Opens a file and create a file object. Path has to be resolved already.
void LinkerDriver::addFile(StringRef path, bool withLOption) {
  using namespace sys::fs;

  Optional<MemoryBufferRef> buffer = readFile(path);
  if (!buffer.hasValue())
    return;
  MemoryBufferRef mbref = *buffer;

  if (config->formatBinary) {
    files.push_back(make<BinaryFile>(mbref));
    return;
  }

  switch (identify_magic(mbref.getBuffer())) {
  case file_magic::unknown:
    readLinkerScript(mbref);
    return;
  case file_magic::archive: {
    // Handle -whole-archive.
    if (inWholeArchive) {
      for (const auto &p : getArchiveMembers(mbref))
        files.push_back(createObjectFile(p.first, path, p.second));
      return;
    }

    std::unique_ptr<Archive> file =
        CHECK(Archive::create(mbref), path + ": failed to parse archive");

    // If an archive file has no symbol table, it is likely that a user
    // is attempting LTO and using a default ar command that doesn't
    // understand the LLVM bitcode file. It is a pretty common error, so
    // we'll handle it as if it had a symbol table.
    if (!file->isEmpty() && !file->hasSymbolTable()) {
      // Check if all members are bitcode files. If not, ignore, which is the
      // default action without the LTO hack described above.
      for (const std::pair<MemoryBufferRef, uint64_t> &p :
           getArchiveMembers(mbref))
        if (identify_magic(p.first.getBuffer()) != file_magic::bitcode) {
          error(path + ": archive has no index; run ranlib to add one");
          return;
        }

      for (const std::pair<MemoryBufferRef, uint64_t> &p :
           getArchiveMembers(mbref))
        files.push_back(make<LazyObjFile>(p.first, path, p.second));
      return;
    }

    // Handle the regular case.
    files.push_back(make<ArchiveFile>(std::move(file)));
    return;
  }
  case file_magic::elf_shared_object:
    if (config->isStatic || config->relocatable) {
      error("attempted static link of dynamic object " + path);
      return;
    }

    // DSOs usually have DT_SONAME tags in their ELF headers, and the
    // sonames are used to identify DSOs. But if they are missing,
    // they are identified by filenames. We don't know whether the new
    // file has a DT_SONAME or not because we haven't parsed it yet.
    // Here, we set the default soname for the file because we might
    // need it later.
    //
    // If a file was specified by -lfoo, the directory part is not
    // significant, as a user did not specify it. This behavior is
    // compatible with GNU.
    files.push_back(
        make<SharedFile>(mbref, withLOption ? path::filename(path) : path));
    return;
  case file_magic::bitcode:
  case file_magic::elf_relocatable:
    if (inLib)
      files.push_back(make<LazyObjFile>(mbref, "", 0));
    else
      files.push_back(createObjectFile(mbref));
    break;
  default:
    error(path + ": unknown file type");
  }
}

// Add a given library by searching it from input search paths.
void LinkerDriver::addLibrary(StringRef name) {
  if (Optional<std::string> path = searchLibrary(name))
    addFile(*path, /*withLOption=*/true);
  else
    error("unable to find library -l" + name);
}

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

// Some command line options or some combinations of them are not allowed.
// This function checks for such errors.
static void checkOptions() {
  // The MIPS ABI as of 2016 does not support the GNU-style symbol lookup
  // table which is a relatively new feature.
  if (config->emachine == EM_MIPS && config->gnuHash)
    error("the .gnu.hash section is not compatible with the MIPS target");

  if (config->fixCortexA53Errata843419 && config->emachine != EM_AARCH64)
    error("--fix-cortex-a53-843419 is only supported on AArch64 targets");

  if (config->tocOptimize && config->emachine != EM_PPC64)
    error("--toc-optimize is only supported on the PowerPC64 target");

  if (config->pie && config->shared)
    error("-shared and -pie may not be used together");

  if (!config->shared && !config->filterList.empty())
    error("-F may not be used without -shared");

  if (!config->shared && !config->auxiliaryList.empty())
    error("-f may not be used without -shared");

  if (!config->relocatable && !config->defineCommon)
    error("-no-define-common not supported in non relocatable output");

  if (config->zText && config->zIfuncNoplt)
    error("-z text and -z ifunc-noplt may not be used together");

  if (config->relocatable) {
    if (config->shared)
      error("-r and -shared may not be used together");
    if (config->gcSections)
      error("-r and --gc-sections may not be used together");
    if (config->gdbIndex)
      error("-r and --gdb-index may not be used together");
    if (config->icf != ICFLevel::None)
      error("-r and --icf may not be used together");
    if (config->pie)
      error("-r and -pie may not be used together");
  }

  if (config->executeOnly) {
    if (config->emachine != EM_AARCH64)
      error("-execute-only is only supported on AArch64 targets");

    if (config->singleRoRx && !script->hasSectionsCommand)
      error("-execute-only and -no-rosegment cannot be used together");
  }

  if (config->zRetpolineplt && config->requireCET)
    error("--require-cet may not be used with -z retpolineplt");

  if (config->emachine != EM_AARCH64) {
    if (config->pacPlt)
      error("--pac-plt only supported on AArch64");
    if (config->forceBTI)
      error("--force-bti only supported on AArch64");
  }
}

static const char *getReproduceOption(opt::InputArgList &args) {
  if (auto *arg = args.getLastArg(OPT_reproduce))
    return arg->getValue();
  return getenv("LLD_REPRODUCE");
}

static bool hasZOption(opt::InputArgList &args, StringRef key) {
  for (auto *arg : args.filtered(OPT_z))
    if (key == arg->getValue())
      return true;
  return false;
}

static bool getZFlag(opt::InputArgList &args, StringRef k1, StringRef k2,
                     bool Default) {
  for (auto *arg : args.filtered_reverse(OPT_z)) {
    if (k1 == arg->getValue())
      return true;
    if (k2 == arg->getValue())
      return false;
  }
  return Default;
}

static bool isKnownZFlag(StringRef s) {
  return s == "combreloc" || s == "copyreloc" || s == "defs" ||
         s == "execstack" || s == "global" || s == "hazardplt" ||
         s == "ifunc-noplt" || s == "initfirst" || s == "interpose" ||
         s == "keep-text-section-prefix" || s == "lazy" || s == "muldefs" ||
         s == "nocombreloc" || s == "nocopyreloc" || s == "nodefaultlib" ||
         s == "nodelete" || s == "nodlopen" || s == "noexecstack" ||
         s == "nokeep-text-section-prefix" || s == "norelro" || s == "notext" ||
         s == "now" || s == "origin" || s == "relro" || s == "retpolineplt" ||
         s == "rodynamic" || s == "text" || s == "wxneeded" ||
         s.startswith("common-page-size") || s.startswith("max-page-size=") ||
         s.startswith("stack-size=");
}

// Report an error for an unknown -z option.
static void checkZOptions(opt::InputArgList &args) {
  for (auto *arg : args.filtered(OPT_z))
    if (!isKnownZFlag(arg->getValue()))
      error("unknown -z value: " + StringRef(arg->getValue()));
}

void LinkerDriver::main(ArrayRef<const char *> argsArr) {
  ELFOptTable parser;
  opt::InputArgList args = parser.parse(argsArr.slice(1));

  // Interpret this flag early because error() depends on them.
  errorHandler().errorLimit = args::getInteger(args, OPT_error_limit, 20);
  checkZOptions(args);

  // Handle -help
  if (args.hasArg(OPT_help)) {
    printHelp();
    return;
  }

  // Handle -v or -version.
  //
  // A note about "compatible with GNU linkers" message: this is a hack for
  // scripts generated by GNU Libtool 2.4.6 (released in February 2014 and
  // still the newest version in March 2017) or earlier to recognize LLD as
  // a GNU compatible linker. As long as an output for the -v option
  // contains "GNU" or "with BFD", they recognize us as GNU-compatible.
  //
  // This is somewhat ugly hack, but in reality, we had no choice other
  // than doing this. Considering the very long release cycle of Libtool,
  // it is not easy to improve it to recognize LLD as a GNU compatible
  // linker in a timely manner. Even if we can make it, there are still a
  // lot of "configure" scripts out there that are generated by old version
  // of Libtool. We cannot convince every software developer to migrate to
  // the latest version and re-generate scripts. So we have this hack.
  if (args.hasArg(OPT_v) || args.hasArg(OPT_version))
    message(getLLDVersion() + " (compatible with GNU linkers)");

  if (const char *path = getReproduceOption(args)) {
    // Note that --reproduce is a debug option so you can ignore it
    // if you are trying to understand the whole picture of the code.
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

  readConfigs(args);

  // The behavior of -v or --version is a bit strange, but this is
  // needed for compatibility with GNU linkers.
  if (args.hasArg(OPT_v) && !args.hasArg(OPT_INPUT))
    return;
  if (args.hasArg(OPT_version))
    return;

  initLLVM();
  createFiles(args);
  if (errorCount())
    return;

  inferMachineType();
  setConfigs(args);
  checkOptions();
  if (errorCount())
    return;

  // The Target instance handles target-specific stuff, such as applying
  // relocations or writing a PLT section. It also contains target-dependent
  // values such as a default image base address.
  target = getTarget();

  switch (config->ekind) {
  case ELF32LEKind:
    link<ELF32LE>(args);
    return;
  case ELF32BEKind:
    link<ELF32BE>(args);
    return;
  case ELF64LEKind:
    link<ELF64LE>(args);
    return;
  case ELF64BEKind:
    link<ELF64BE>(args);
    return;
  default:
    llvm_unreachable("unknown Config->EKind");
  }
}

static std::string getRpath(opt::InputArgList &args) {
  std::vector<StringRef> v = args::getStrings(args, OPT_rpath);
  return llvm::join(v.begin(), v.end(), ":");
}

// Determines what we should do if there are remaining unresolved
// symbols after the name resolution.
static UnresolvedPolicy getUnresolvedSymbolPolicy(opt::InputArgList &args) {
  UnresolvedPolicy errorOrWarn = args.hasFlag(OPT_error_unresolved_symbols,
                                              OPT_warn_unresolved_symbols, true)
                                     ? UnresolvedPolicy::ReportError
                                     : UnresolvedPolicy::Warn;

  // Process the last of -unresolved-symbols, -no-undefined or -z defs.
  for (auto *arg : llvm::reverse(args)) {
    switch (arg->getOption().getID()) {
    case OPT_unresolved_symbols: {
      StringRef s = arg->getValue();
      if (s == "ignore-all" || s == "ignore-in-object-files")
        return UnresolvedPolicy::Ignore;
      if (s == "ignore-in-shared-libs" || s == "report-all")
        return errorOrWarn;
      error("unknown --unresolved-symbols value: " + s);
      continue;
    }
    case OPT_no_undefined:
      return errorOrWarn;
    case OPT_z:
      if (StringRef(arg->getValue()) == "defs")
        return errorOrWarn;
      continue;
    }
  }

  // -shared implies -unresolved-symbols=ignore-all because missing
  // symbols are likely to be resolved at runtime using other DSOs.
  if (config->shared)
    return UnresolvedPolicy::Ignore;
  return errorOrWarn;
}

static Target2Policy getTarget2(opt::InputArgList &args) {
  StringRef s = args.getLastArgValue(OPT_target2, "got-rel");
  if (s == "rel")
    return Target2Policy::Rel;
  if (s == "abs")
    return Target2Policy::Abs;
  if (s == "got-rel")
    return Target2Policy::GotRel;
  error("unknown --target2 option: " + s);
  return Target2Policy::GotRel;
}

static bool isOutputFormatBinary(opt::InputArgList &args) {
  StringRef s = args.getLastArgValue(OPT_oformat, "elf");
  if (s == "binary")
    return true;
  if (!s.startswith("elf"))
    error("unknown --oformat value: " + s);
  return false;
}

static DiscardPolicy getDiscard(opt::InputArgList &args) {
  if (args.hasArg(OPT_relocatable))
    return DiscardPolicy::None;

  auto *arg =
      args.getLastArg(OPT_discard_all, OPT_discard_locals, OPT_discard_none);
  if (!arg)
    return DiscardPolicy::Default;
  if (arg->getOption().getID() == OPT_discard_all)
    return DiscardPolicy::All;
  if (arg->getOption().getID() == OPT_discard_locals)
    return DiscardPolicy::Locals;
  return DiscardPolicy::None;
}

static StringRef getDynamicLinker(opt::InputArgList &args) {
  auto *arg = args.getLastArg(OPT_dynamic_linker, OPT_no_dynamic_linker);
  if (!arg || arg->getOption().getID() == OPT_no_dynamic_linker)
    return "";
  return arg->getValue();
}

static ICFLevel getICF(opt::InputArgList &args) {
  auto *arg = args.getLastArg(OPT_icf_none, OPT_icf_safe, OPT_icf_all);
  if (!arg || arg->getOption().getID() == OPT_icf_none)
    return ICFLevel::None;
  if (arg->getOption().getID() == OPT_icf_safe)
    return ICFLevel::Safe;
  return ICFLevel::All;
}

static StripPolicy getStrip(opt::InputArgList &args) {
  if (args.hasArg(OPT_relocatable))
    return StripPolicy::None;

  auto *arg = args.getLastArg(OPT_strip_all, OPT_strip_debug);
  if (!arg)
    return StripPolicy::None;
  if (arg->getOption().getID() == OPT_strip_all)
    return StripPolicy::All;
  return StripPolicy::Debug;
}

static uint64_t parseSectionAddress(StringRef s, opt::InputArgList &args,
                                    const opt::Arg &arg) {
  uint64_t va = 0;
  if (s.startswith("0x"))
    s = s.drop_front(2);
  if (!to_integer(s, va, 16))
    error("invalid argument: " + arg.getAsString(args));
  return va;
}

static StringMap<uint64_t> getSectionStartMap(opt::InputArgList &args) {
  StringMap<uint64_t> ret;
  for (auto *arg : args.filtered(OPT_section_start)) {
    StringRef name;
    StringRef addr;
    std::tie(name, addr) = StringRef(arg->getValue()).split('=');
    ret[name] = parseSectionAddress(addr, args, *arg);
  }

  if (auto *arg = args.getLastArg(OPT_Ttext))
    ret[".text"] = parseSectionAddress(arg->getValue(), args, *arg);
  if (auto *arg = args.getLastArg(OPT_Tdata))
    ret[".data"] = parseSectionAddress(arg->getValue(), args, *arg);
  if (auto *arg = args.getLastArg(OPT_Tbss))
    ret[".bss"] = parseSectionAddress(arg->getValue(), args, *arg);
  return ret;
}

static SortSectionPolicy getSortSection(opt::InputArgList &args) {
  StringRef s = args.getLastArgValue(OPT_sort_section);
  if (s == "alignment")
    return SortSectionPolicy::Alignment;
  if (s == "name")
    return SortSectionPolicy::Name;
  if (!s.empty())
    error("unknown --sort-section rule: " + s);
  return SortSectionPolicy::Default;
}

static OrphanHandlingPolicy getOrphanHandling(opt::InputArgList &args) {
  StringRef s = args.getLastArgValue(OPT_orphan_handling, "place");
  if (s == "warn")
    return OrphanHandlingPolicy::Warn;
  if (s == "error")
    return OrphanHandlingPolicy::Error;
  if (s != "place")
    error("unknown --orphan-handling mode: " + s);
  return OrphanHandlingPolicy::Place;
}

// Parse --build-id or --build-id=<style>. We handle "tree" as a
// synonym for "sha1" because all our hash functions including
// -build-id=sha1 are actually tree hashes for performance reasons.
static std::pair<BuildIdKind, std::vector<uint8_t>>
getBuildId(opt::InputArgList &args) {
  auto *arg = args.getLastArg(OPT_build_id, OPT_build_id_eq);
  if (!arg)
    return {BuildIdKind::None, {}};

  if (arg->getOption().getID() == OPT_build_id)
    return {BuildIdKind::Fast, {}};

  StringRef s = arg->getValue();
  if (s == "fast")
    return {BuildIdKind::Fast, {}};
  if (s == "md5")
    return {BuildIdKind::Md5, {}};
  if (s == "sha1" || s == "tree")
    return {BuildIdKind::Sha1, {}};
  if (s == "uuid")
    return {BuildIdKind::Uuid, {}};
  if (s.startswith("0x"))
    return {BuildIdKind::Hexstring, parseHex(s.substr(2))};

  if (s != "none")
    error("unknown --build-id style: " + s);
  return {BuildIdKind::None, {}};
}

static std::pair<bool, bool> getPackDynRelocs(opt::InputArgList &args) {
  StringRef s = args.getLastArgValue(OPT_pack_dyn_relocs, "none");
  if (s == "android")
    return {true, false};
  if (s == "relr")
    return {false, true};
  if (s == "android+relr")
    return {true, true};

  if (s != "none")
    error("unknown -pack-dyn-relocs format: " + s);
  return {false, false};
}

static void readCallGraph(MemoryBufferRef mb) {
  // Build a map from symbol name to section
  DenseMap<StringRef, Symbol *> map;
  for (InputFile *file : objectFiles)
    for (Symbol *sym : file->getSymbols())
      map[sym->getName()] = sym;

  auto findSection = [&](StringRef name) -> InputSectionBase * {
    Symbol *sym = map.lookup(name);
    if (!sym) {
      if (config->warnSymbolOrdering)
        warn(mb.getBufferIdentifier() + ": no such symbol: " + name);
      return nullptr;
    }
    maybeWarnUnorderableSymbol(sym);

    if (Defined *dr = dyn_cast_or_null<Defined>(sym))
      return dyn_cast_or_null<InputSectionBase>(dr->section);
    return nullptr;
  };

  for (StringRef line : args::getLines(mb)) {
    SmallVector<StringRef, 3> fields;
    line.split(fields, ' ');
    uint64_t count;

    if (fields.size() != 3 || !to_integer(fields[2], count)) {
      error(mb.getBufferIdentifier() + ": parse error");
      return;
    }

    if (InputSectionBase *from = findSection(fields[0]))
      if (InputSectionBase *to = findSection(fields[1]))
        config->callGraphProfile[std::make_pair(from, to)] += count;
  }
}

template <class ELFT> static void readCallGraphsFromObjectFiles() {
  for (auto file : objectFiles) {
    auto *obj = cast<ObjFile<ELFT>>(file);

    for (const Elf_CGProfile_Impl<ELFT> &cgpe : obj->cgProfile) {
      auto *fromSym = dyn_cast<Defined>(&obj->getSymbol(cgpe.cgp_from));
      auto *toSym = dyn_cast<Defined>(&obj->getSymbol(cgpe.cgp_to));
      if (!fromSym || !toSym)
        continue;

      auto *from = dyn_cast_or_null<InputSectionBase>(fromSym->section);
      auto *to = dyn_cast_or_null<InputSectionBase>(toSym->section);
      if (from && to)
        config->callGraphProfile[{from, to}] += cgpe.cgp_weight;
    }
  }
}

static bool getCompressDebugSections(opt::InputArgList &args) {
  StringRef s = args.getLastArgValue(OPT_compress_debug_sections, "none");
  if (s == "none")
    return false;
  if (s != "zlib")
    error("unknown --compress-debug-sections value: " + s);
  if (!zlib::isAvailable())
    error("--compress-debug-sections: zlib is not available");
  return true;
}

static std::pair<StringRef, StringRef> getOldNewOptions(opt::InputArgList &args,
                                                        unsigned id) {
  auto *arg = args.getLastArg(id);
  if (!arg)
    return {"", ""};

  StringRef s = arg->getValue();
  std::pair<StringRef, StringRef> ret = s.split(';');
  if (ret.second.empty())
    error(arg->getSpelling() + " expects 'old;new' format, but got " + s);
  return ret;
}

// Parse the symbol ordering file and warn for any duplicate entries.
static std::vector<StringRef> getSymbolOrderingFile(MemoryBufferRef mb) {
  SetVector<StringRef> names;
  for (StringRef s : args::getLines(mb))
    if (!names.insert(s) && config->warnSymbolOrdering)
      warn(mb.getBufferIdentifier() + ": duplicate ordered symbol: " + s);

  return names.takeVector();
}

static void parseClangOption(StringRef opt, const Twine &msg) {
  std::string err;
  raw_string_ostream os(err);

  const char *argv[] = {config->progName.data(), opt.data()};
  if (cl::ParseCommandLineOptions(2, argv, "", &os))
    return;
  os.flush();
  error(msg + ": " + StringRef(err).trim());
}

// Initializes Config members by the command line options.
static void readConfigs(opt::InputArgList &args) {
  errorHandler().verbose = args.hasArg(OPT_verbose);
  errorHandler().fatalWarnings =
      args.hasFlag(OPT_fatal_warnings, OPT_no_fatal_warnings, false);
  errorHandler().vsDiagnostics =
      args.hasArg(OPT_visual_studio_diagnostics_format, false);
  threadsEnabled = args.hasFlag(OPT_threads, OPT_no_threads, true);

  config->allowMultipleDefinition =
      args.hasFlag(OPT_allow_multiple_definition,
                   OPT_no_allow_multiple_definition, false) ||
      hasZOption(args, "muldefs");
  config->allowShlibUndefined =
      args.hasFlag(OPT_allow_shlib_undefined, OPT_no_allow_shlib_undefined,
                   args.hasArg(OPT_shared));
  config->auxiliaryList = args::getStrings(args, OPT_auxiliary);
  config->bsymbolic = args.hasArg(OPT_Bsymbolic);
  config->bsymbolicFunctions = args.hasArg(OPT_Bsymbolic_functions);
  config->checkSections =
      args.hasFlag(OPT_check_sections, OPT_no_check_sections, true);
  config->chroot = args.getLastArgValue(OPT_chroot);
  config->compressDebugSections = getCompressDebugSections(args);
  config->cref = args.hasFlag(OPT_cref, OPT_no_cref, false);
  config->defineCommon = args.hasFlag(OPT_define_common, OPT_no_define_common,
                                      !args.hasArg(OPT_relocatable));
  config->demangle = args.hasFlag(OPT_demangle, OPT_no_demangle, true);
  config->dependentLibraries = args.hasFlag(OPT_dependent_libraries, OPT_no_dependent_libraries, true);
  config->disableVerify = args.hasArg(OPT_disable_verify);
  config->discard = getDiscard(args);
  config->dwoDir = args.getLastArgValue(OPT_plugin_opt_dwo_dir_eq);
  config->dynamicLinker = getDynamicLinker(args);
  config->ehFrameHdr =
      args.hasFlag(OPT_eh_frame_hdr, OPT_no_eh_frame_hdr, false);
  config->emitLLVM = args.hasArg(OPT_plugin_opt_emit_llvm, false);
  config->emitRelocs = args.hasArg(OPT_emit_relocs);
  config->callGraphProfileSort = args.hasFlag(
      OPT_call_graph_profile_sort, OPT_no_call_graph_profile_sort, true);
  config->enableNewDtags =
      args.hasFlag(OPT_enable_new_dtags, OPT_disable_new_dtags, true);
  config->entry = args.getLastArgValue(OPT_entry);
  config->executeOnly =
      args.hasFlag(OPT_execute_only, OPT_no_execute_only, false);
  config->exportDynamic =
      args.hasFlag(OPT_export_dynamic, OPT_no_export_dynamic, false);
  config->filterList = args::getStrings(args, OPT_filter);
  config->fini = args.getLastArgValue(OPT_fini, "_fini");
  config->fixCortexA53Errata843419 = args.hasArg(OPT_fix_cortex_a53_843419);
  config->forceBTI = args.hasArg(OPT_force_bti);
  config->requireCET = args.hasArg(OPT_require_cet);
  config->gcSections = args.hasFlag(OPT_gc_sections, OPT_no_gc_sections, false);
  config->gnuUnique = args.hasFlag(OPT_gnu_unique, OPT_no_gnu_unique, true);
  config->gdbIndex = args.hasFlag(OPT_gdb_index, OPT_no_gdb_index, false);
  config->icf = getICF(args);
  config->ignoreDataAddressEquality =
      args.hasArg(OPT_ignore_data_address_equality);
  config->ignoreFunctionAddressEquality =
      args.hasArg(OPT_ignore_function_address_equality);
  config->init = args.getLastArgValue(OPT_init, "_init");
  config->ltoAAPipeline = args.getLastArgValue(OPT_lto_aa_pipeline);
  config->ltoCSProfileGenerate = args.hasArg(OPT_lto_cs_profile_generate);
  config->ltoCSProfileFile = args.getLastArgValue(OPT_lto_cs_profile_file);
  config->ltoDebugPassManager = args.hasArg(OPT_lto_debug_pass_manager);
  config->ltoNewPassManager = args.hasArg(OPT_lto_new_pass_manager);
  config->ltoNewPmPasses = args.getLastArgValue(OPT_lto_newpm_passes);
  config->ltoo = args::getInteger(args, OPT_lto_O, 2);
  config->ltoObjPath = args.getLastArgValue(OPT_plugin_opt_obj_path_eq);
  config->ltoPartitions = args::getInteger(args, OPT_lto_partitions, 1);
  config->ltoSampleProfile = args.getLastArgValue(OPT_lto_sample_profile);
  config->mapFile = args.getLastArgValue(OPT_Map);
  config->mipsGotSize = args::getInteger(args, OPT_mips_got_size, 0xfff0);
  config->mergeArmExidx =
      args.hasFlag(OPT_merge_exidx_entries, OPT_no_merge_exidx_entries, true);
  config->nmagic = args.hasFlag(OPT_nmagic, OPT_no_nmagic, false);
  config->noinhibitExec = args.hasArg(OPT_noinhibit_exec);
  config->nostdlib = args.hasArg(OPT_nostdlib);
  config->oFormatBinary = isOutputFormatBinary(args);
  config->omagic = args.hasFlag(OPT_omagic, OPT_no_omagic, false);
  config->optRemarksFilename = args.getLastArgValue(OPT_opt_remarks_filename);
  config->optRemarksPasses = args.getLastArgValue(OPT_opt_remarks_passes);
  config->optRemarksWithHotness = args.hasArg(OPT_opt_remarks_with_hotness);
  config->optRemarksFormat = args.getLastArgValue(OPT_opt_remarks_format);
  config->optimize = args::getInteger(args, OPT_O, 1);
  config->orphanHandling = getOrphanHandling(args);
  config->outputFile = args.getLastArgValue(OPT_o);
  config->pacPlt = args.hasArg(OPT_pac_plt);
  config->pie = args.hasFlag(OPT_pie, OPT_no_pie, false);
  config->printIcfSections =
      args.hasFlag(OPT_print_icf_sections, OPT_no_print_icf_sections, false);
  config->printGcSections =
      args.hasFlag(OPT_print_gc_sections, OPT_no_print_gc_sections, false);
  config->printSymbolOrder =
      args.getLastArgValue(OPT_print_symbol_order);
  config->rpath = getRpath(args);
  config->relocatable = args.hasArg(OPT_relocatable);
  config->saveTemps = args.hasArg(OPT_save_temps);
  config->searchPaths = args::getStrings(args, OPT_library_path);
  config->sectionStartMap = getSectionStartMap(args);
  config->shared = args.hasArg(OPT_shared);
  config->singleRoRx = args.hasArg(OPT_no_rosegment);
  config->soName = args.getLastArgValue(OPT_soname);
  config->sortSection = getSortSection(args);
  config->splitStackAdjustSize = args::getInteger(args, OPT_split_stack_adjust_size, 16384);
  config->strip = getStrip(args);
  config->sysroot = args.getLastArgValue(OPT_sysroot);
  config->target1Rel = args.hasFlag(OPT_target1_rel, OPT_target1_abs, false);
  config->target2 = getTarget2(args);
  config->thinLTOCacheDir = args.getLastArgValue(OPT_thinlto_cache_dir);
  config->thinLTOCachePolicy = CHECK(
      parseCachePruningPolicy(args.getLastArgValue(OPT_thinlto_cache_policy)),
      "--thinlto-cache-policy: invalid cache policy");
  config->thinLTOEmitImportsFiles =
      args.hasArg(OPT_plugin_opt_thinlto_emit_imports_files);
  config->thinLTOIndexOnly = args.hasArg(OPT_plugin_opt_thinlto_index_only) ||
                             args.hasArg(OPT_plugin_opt_thinlto_index_only_eq);
  config->thinLTOIndexOnlyArg =
      args.getLastArgValue(OPT_plugin_opt_thinlto_index_only_eq);
  config->thinLTOJobs = args::getInteger(args, OPT_thinlto_jobs, -1u);
  config->thinLTOObjectSuffixReplace =
      getOldNewOptions(args, OPT_plugin_opt_thinlto_object_suffix_replace_eq);
  config->thinLTOPrefixReplace =
      getOldNewOptions(args, OPT_plugin_opt_thinlto_prefix_replace_eq);
  config->trace = args.hasArg(OPT_trace);
  config->undefined = args::getStrings(args, OPT_undefined);
  config->undefinedVersion =
      args.hasFlag(OPT_undefined_version, OPT_no_undefined_version, true);
  config->useAndroidRelrTags = args.hasFlag(
      OPT_use_android_relr_tags, OPT_no_use_android_relr_tags, false);
  config->unresolvedSymbols = getUnresolvedSymbolPolicy(args);
  config->warnBackrefs =
      args.hasFlag(OPT_warn_backrefs, OPT_no_warn_backrefs, false);
  config->warnCommon = args.hasFlag(OPT_warn_common, OPT_no_warn_common, false);
  config->warnIfuncTextrel =
      args.hasFlag(OPT_warn_ifunc_textrel, OPT_no_warn_ifunc_textrel, false);
  config->warnSymbolOrdering =
      args.hasFlag(OPT_warn_symbol_ordering, OPT_no_warn_symbol_ordering, true);
  config->zCombreloc = getZFlag(args, "combreloc", "nocombreloc", true);
  config->zCopyreloc = getZFlag(args, "copyreloc", "nocopyreloc", true);
  config->zExecstack = getZFlag(args, "execstack", "noexecstack", false);
  config->zGlobal = hasZOption(args, "global");
  config->zHazardplt = hasZOption(args, "hazardplt");
  config->zIfuncNoplt = hasZOption(args, "ifunc-noplt");
  config->zInitfirst = hasZOption(args, "initfirst");
  config->zInterpose = hasZOption(args, "interpose");
  config->zKeepTextSectionPrefix = getZFlag(
      args, "keep-text-section-prefix", "nokeep-text-section-prefix", false);
  config->zNodefaultlib = hasZOption(args, "nodefaultlib");
  config->zNodelete = hasZOption(args, "nodelete");
  config->zNodlopen = hasZOption(args, "nodlopen");
  config->zNow = getZFlag(args, "now", "lazy", false);
  config->zOrigin = hasZOption(args, "origin");
  config->zRelro = getZFlag(args, "relro", "norelro", true);
  config->zRetpolineplt = hasZOption(args, "retpolineplt");
  config->zRodynamic = hasZOption(args, "rodynamic");
  config->zStackSize = args::getZOptionValue(args, OPT_z, "stack-size", 0);
  config->zText = getZFlag(args, "text", "notext", true);
  config->zWxneeded = hasZOption(args, "wxneeded");

  // Parse LTO options.
  if (auto *arg = args.getLastArg(OPT_plugin_opt_mcpu_eq))
    parseClangOption(saver.save("-mcpu=" + StringRef(arg->getValue())),
                     arg->getSpelling());

  for (auto *arg : args.filtered(OPT_plugin_opt))
    parseClangOption(arg->getValue(), arg->getSpelling());

  // Parse -mllvm options.
  for (auto *arg : args.filtered(OPT_mllvm))
    parseClangOption(arg->getValue(), arg->getSpelling());

  if (config->ltoo > 3)
    error("invalid optimization level for LTO: " + Twine(config->ltoo));
  if (config->ltoPartitions == 0)
    error("--lto-partitions: number of threads must be > 0");
  if (config->thinLTOJobs == 0)
    error("--thinlto-jobs: number of threads must be > 0");

  if (config->splitStackAdjustSize < 0)
    error("--split-stack-adjust-size: size must be >= 0");

  // Parse ELF{32,64}{LE,BE} and CPU type.
  if (auto *arg = args.getLastArg(OPT_m)) {
    StringRef s = arg->getValue();
    std::tie(config->ekind, config->emachine, config->osabi) =
        parseEmulation(s);
    config->mipsN32Abi = (s == "elf32btsmipn32" || s == "elf32ltsmipn32");
    config->emulation = s;
  }

  // Parse -hash-style={sysv,gnu,both}.
  if (auto *arg = args.getLastArg(OPT_hash_style)) {
    StringRef s = arg->getValue();
    if (s == "sysv")
      config->sysvHash = true;
    else if (s == "gnu")
      config->gnuHash = true;
    else if (s == "both")
      config->sysvHash = config->gnuHash = true;
    else
      error("unknown -hash-style: " + s);
  }

  if (args.hasArg(OPT_print_map))
    config->mapFile = "-";

  // Page alignment can be disabled by the -n (--nmagic) and -N (--omagic).
  // As PT_GNU_RELRO relies on Paging, do not create it when we have disabled
  // it.
  if (config->nmagic || config->omagic)
    config->zRelro = false;

  std::tie(config->buildId, config->buildIdVector) = getBuildId(args);

  std::tie(config->androidPackDynRelocs, config->relrPackDynRelocs) =
      getPackDynRelocs(args);

  if (auto *arg = args.getLastArg(OPT_symbol_ordering_file)){
    if (args.hasArg(OPT_call_graph_ordering_file))
      error("--symbol-ordering-file and --call-graph-order-file "
            "may not be used together");
    if (Optional<MemoryBufferRef> buffer = readFile(arg->getValue())){
      config->symbolOrderingFile = getSymbolOrderingFile(*buffer);
      // Also need to disable CallGraphProfileSort to prevent
      // LLD order symbols with CGProfile
      config->callGraphProfileSort = false;
    }
  }

  // If --retain-symbol-file is used, we'll keep only the symbols listed in
  // the file and discard all others.
  if (auto *arg = args.getLastArg(OPT_retain_symbols_file)) {
    config->defaultSymbolVersion = VER_NDX_LOCAL;
    if (Optional<MemoryBufferRef> buffer = readFile(arg->getValue()))
      for (StringRef s : args::getLines(*buffer))
        config->versionScriptGlobals.push_back(
            {s, /*IsExternCpp*/ false, /*HasWildcard*/ false});
  }

  bool hasExportDynamic =
      args.hasFlag(OPT_export_dynamic, OPT_no_export_dynamic, false);

  // Parses -dynamic-list and -export-dynamic-symbol. They make some
  // symbols private. Note that -export-dynamic takes precedence over them
  // as it says all symbols should be exported.
  if (!hasExportDynamic) {
    for (auto *arg : args.filtered(OPT_dynamic_list))
      if (Optional<MemoryBufferRef> buffer = readFile(arg->getValue()))
        readDynamicList(*buffer);

    for (auto *arg : args.filtered(OPT_export_dynamic_symbol))
      config->dynamicList.push_back(
          {arg->getValue(), /*IsExternCpp*/ false, /*HasWildcard*/ false});
  }

  // If --export-dynamic-symbol=foo is given and symbol foo is defined in
  // an object file in an archive file, that object file should be pulled
  // out and linked. (It doesn't have to behave like that from technical
  // point of view, but this is needed for compatibility with GNU.)
  for (auto *arg : args.filtered(OPT_export_dynamic_symbol))
    config->undefined.push_back(arg->getValue());

  for (auto *arg : args.filtered(OPT_version_script))
    if (Optional<std::string> path = searchScript(arg->getValue())) {
      if (Optional<MemoryBufferRef> buffer = readFile(*path))
        readVersionScript(*buffer);
    } else {
      error(Twine("cannot find version script ") + arg->getValue());
    }
}

// Some Config members do not directly correspond to any particular
// command line options, but computed based on other Config values.
// This function initialize such members. See Config.h for the details
// of these values.
static void setConfigs(opt::InputArgList &args) {
  ELFKind k = config->ekind;
  uint16_t m = config->emachine;

  config->copyRelocs = (config->relocatable || config->emitRelocs);
  config->is64 = (k == ELF64LEKind || k == ELF64BEKind);
  config->isLE = (k == ELF32LEKind || k == ELF64LEKind);
  config->endianness = config->isLE ? endianness::little : endianness::big;
  config->isMips64EL = (k == ELF64LEKind && m == EM_MIPS);
  config->isPic = config->pie || config->shared;
  config->picThunk = args.hasArg(OPT_pic_veneer, config->isPic);
  config->wordsize = config->is64 ? 8 : 4;

  // ELF defines two different ways to store relocation addends as shown below:
  //
  //  Rel:  Addends are stored to the location where relocations are applied.
  //  Rela: Addends are stored as part of relocation entry.
  //
  // In other words, Rela makes it easy to read addends at the price of extra
  // 4 or 8 byte for each relocation entry. We don't know why ELF defined two
  // different mechanisms in the first place, but this is how the spec is
  // defined.
  //
  // You cannot choose which one, Rel or Rela, you want to use. Instead each
  // ABI defines which one you need to use. The following expression expresses
  // that.
  config->isRela = m == EM_AARCH64 || m == EM_AMDGPU || m == EM_HEXAGON ||
                   m == EM_PPC || m == EM_PPC64 || m == EM_RISCV ||
                   m == EM_X86_64;

  // If the output uses REL relocations we must store the dynamic relocation
  // addends to the output sections. We also store addends for RELA relocations
  // if --apply-dynamic-relocs is used.
  // We default to not writing the addends when using RELA relocations since
  // any standard conforming tool can find it in r_addend.
  config->writeAddends = args.hasFlag(OPT_apply_dynamic_relocs,
                                      OPT_no_apply_dynamic_relocs, false) ||
                         !config->isRela;

  config->tocOptimize =
      args.hasFlag(OPT_toc_optimize, OPT_no_toc_optimize, m == EM_PPC64);
}

// Returns a value of "-format" option.
static bool isFormatBinary(StringRef s) {
  if (s == "binary")
    return true;
  if (s == "elf" || s == "default")
    return false;
  error("unknown -format value: " + s +
        " (supported formats: elf, default, binary)");
  return false;
}

void LinkerDriver::createFiles(opt::InputArgList &args) {
  // For --{push,pop}-state.
  std::vector<std::tuple<bool, bool, bool>> stack;

  // Iterate over argv to process input files and positional arguments.
  for (auto *arg : args) {
    switch (arg->getOption().getID()) {
    case OPT_library:
      addLibrary(arg->getValue());
      break;
    case OPT_INPUT:
      addFile(arg->getValue(), /*withLOption=*/false);
      break;
    case OPT_defsym: {
      StringRef from;
      StringRef to;
      std::tie(from, to) = StringRef(arg->getValue()).split('=');
      if (from.empty() || to.empty())
        error("-defsym: syntax error: " + StringRef(arg->getValue()));
      else
        readDefsym(from, MemoryBufferRef(to, "-defsym"));
      break;
    }
    case OPT_script:
      if (Optional<std::string> path = searchScript(arg->getValue())) {
        if (Optional<MemoryBufferRef> mb = readFile(*path))
          readLinkerScript(*mb);
        break;
      }
      error(Twine("cannot find linker script ") + arg->getValue());
      break;
    case OPT_as_needed:
      config->asNeeded = true;
      break;
    case OPT_format:
      config->formatBinary = isFormatBinary(arg->getValue());
      break;
    case OPT_no_as_needed:
      config->asNeeded = false;
      break;
    case OPT_Bstatic:
    case OPT_omagic:
    case OPT_nmagic:
      config->isStatic = true;
      break;
    case OPT_Bdynamic:
      config->isStatic = false;
      break;
    case OPT_whole_archive:
      inWholeArchive = true;
      break;
    case OPT_no_whole_archive:
      inWholeArchive = false;
      break;
    case OPT_just_symbols:
      if (Optional<MemoryBufferRef> mb = readFile(arg->getValue())) {
        files.push_back(createObjectFile(*mb));
        files.back()->justSymbols = true;
      }
      break;
    case OPT_start_group:
      if (InputFile::isInGroup)
        error("nested --start-group");
      InputFile::isInGroup = true;
      break;
    case OPT_end_group:
      if (!InputFile::isInGroup)
        error("stray --end-group");
      InputFile::isInGroup = false;
      ++InputFile::nextGroupId;
      break;
    case OPT_start_lib:
      if (inLib)
        error("nested --start-lib");
      if (InputFile::isInGroup)
        error("may not nest --start-lib in --start-group");
      inLib = true;
      InputFile::isInGroup = true;
      break;
    case OPT_end_lib:
      if (!inLib)
        error("stray --end-lib");
      inLib = false;
      InputFile::isInGroup = false;
      ++InputFile::nextGroupId;
      break;
    case OPT_push_state:
      stack.emplace_back(config->asNeeded, config->isStatic, inWholeArchive);
      break;
    case OPT_pop_state:
      if (stack.empty()) {
        error("unbalanced --push-state/--pop-state");
        break;
      }
      std::tie(config->asNeeded, config->isStatic, inWholeArchive) = stack.back();
      stack.pop_back();
      break;
    }
  }

  if (files.empty() && errorCount() == 0)
    error("no input files");
}

// If -m <machine_type> was not given, infer it from object files.
void LinkerDriver::inferMachineType() {
  if (config->ekind != ELFNoneKind)
    return;

  for (InputFile *f : files) {
    if (f->ekind == ELFNoneKind)
      continue;
    config->ekind = f->ekind;
    config->emachine = f->emachine;
    config->osabi = f->osabi;
    config->mipsN32Abi = config->emachine == EM_MIPS && isMipsN32Abi(f);
    return;
  }
  error("target emulation unknown: -m or at least one .o file required");
}

// Parse -z max-page-size=<value>. The default value is defined by
// each target.
static uint64_t getMaxPageSize(opt::InputArgList &args) {
  uint64_t val = args::getZOptionValue(args, OPT_z, "max-page-size",
                                       target->defaultMaxPageSize);
  if (!isPowerOf2_64(val))
    error("max-page-size: value isn't a power of 2");
  if (config->nmagic || config->omagic) {
    if (val != target->defaultMaxPageSize)
      warn("-z max-page-size set, but paging disabled by omagic or nmagic");
    return 1;
  }
  return val;
}

// Parse -z common-page-size=<value>. The default value is defined by
// each target.
static uint64_t getCommonPageSize(opt::InputArgList &args) {
  uint64_t val = args::getZOptionValue(args, OPT_z, "common-page-size",
                                       target->defaultCommonPageSize);
  if (!isPowerOf2_64(val))
    error("common-page-size: value isn't a power of 2");
  if (config->nmagic || config->omagic) {
    if (val != target->defaultCommonPageSize)
      warn("-z common-page-size set, but paging disabled by omagic or nmagic");
    return 1;
  }
  // commonPageSize can't be larger than maxPageSize.
  if (val > config->maxPageSize)
    val = config->maxPageSize;
  return val;
}

// Parses -image-base option.
static Optional<uint64_t> getImageBase(opt::InputArgList &args) {
  // Because we are using "Config->maxPageSize" here, this function has to be
  // called after the variable is initialized.
  auto *arg = args.getLastArg(OPT_image_base);
  if (!arg)
    return None;

  StringRef s = arg->getValue();
  uint64_t v;
  if (!to_integer(s, v)) {
    error("-image-base: number expected, but got " + s);
    return 0;
  }
  if ((v % config->maxPageSize) != 0)
    warn("-image-base: address isn't multiple of page size: " + s);
  return v;
}

// Parses `--exclude-libs=lib,lib,...`.
// The library names may be delimited by commas or colons.
static DenseSet<StringRef> getExcludeLibs(opt::InputArgList &args) {
  DenseSet<StringRef> ret;
  for (auto *arg : args.filtered(OPT_exclude_libs)) {
    StringRef s = arg->getValue();
    for (;;) {
      size_t pos = s.find_first_of(",:");
      if (pos == StringRef::npos)
        break;
      ret.insert(s.substr(0, pos));
      s = s.substr(pos + 1);
    }
    ret.insert(s);
  }
  return ret;
}

// Handles the -exclude-libs option. If a static library file is specified
// by the -exclude-libs option, all public symbols from the archive become
// private unless otherwise specified by version scripts or something.
// A special library name "ALL" means all archive files.
//
// This is not a popular option, but some programs such as bionic libc use it.
static void excludeLibs(opt::InputArgList &args) {
  DenseSet<StringRef> libs = getExcludeLibs(args);
  bool all = libs.count("ALL");

  auto visit = [&](InputFile *file) {
    if (!file->archiveName.empty())
      if (all || libs.count(path::filename(file->archiveName)))
        for (Symbol *sym : file->getSymbols())
          if (!sym->isLocal() && sym->file == file)
            sym->versionId = VER_NDX_LOCAL;
  };

  for (InputFile *file : objectFiles)
    visit(file);

  for (BitcodeFile *file : bitcodeFiles)
    visit(file);
}

// Force Sym to be entered in the output. Used for -u or equivalent.
static void handleUndefined(Symbol *sym) {
  // Since a symbol may not be used inside the program, LTO may
  // eliminate it. Mark the symbol as "used" to prevent it.
  sym->isUsedInRegularObj = true;

  if (sym->isLazy())
    sym->fetch();
}

// As an extention to GNU linkers, lld supports a variant of `-u`
// which accepts wildcard patterns. All symbols that match a given
// pattern are handled as if they were given by `-u`.
static void handleUndefinedGlob(StringRef arg) {
  Expected<GlobPattern> pat = GlobPattern::create(arg);
  if (!pat) {
    error("--undefined-glob: " + toString(pat.takeError()));
    return;
  }

  std::vector<Symbol *> syms;
  symtab->forEachSymbol([&](Symbol *sym) {
    // Calling Sym->fetch() from here is not safe because it may
    // add new symbols to the symbol table, invalidating the
    // current iterator. So we just keep a note.
    if (pat->match(sym->getName()))
      syms.push_back(sym);
  });

  for (Symbol *sym : syms)
    handleUndefined(sym);
}

static void handleLibcall(StringRef name) {
  Symbol *sym = symtab->find(name);
  if (!sym || !sym->isLazy())
    return;

  MemoryBufferRef mb;
  if (auto *lo = dyn_cast<LazyObject>(sym))
    mb = lo->file->mb;
  else
    mb = cast<LazyArchive>(sym)->getMemberBuffer();

  if (isBitcode(mb))
    sym->fetch();
}

// Replaces common symbols with defined symbols reside in .bss sections.
// This function is called after all symbol names are resolved. As a
// result, the passes after the symbol resolution won't see any
// symbols of type CommonSymbol.
static void replaceCommonSymbols() {
  symtab->forEachSymbol([](Symbol *sym) {
    auto *s = dyn_cast<CommonSymbol>(sym);
    if (!s)
      return;

    auto *bss = make<BssSection>("COMMON", s->size, s->alignment);
    bss->file = s->file;
    bss->markDead();
    inputSections.push_back(bss);
    s->replace(Defined{s->file, s->getName(), s->binding, s->stOther, s->type,
                       /*value=*/0, s->size, bss});
  });
}

// If all references to a DSO happen to be weak, the DSO is not added
// to DT_NEEDED. If that happens, we need to eliminate shared symbols
// created from the DSO. Otherwise, they become dangling references
// that point to a non-existent DSO.
static void demoteSharedSymbols() {
  symtab->forEachSymbol([](Symbol *sym) {
    auto *s = dyn_cast<SharedSymbol>(sym);
    if (!s || s->getFile().isNeeded)
      return;

    bool used = s->used;
    s->replace(Undefined{nullptr, s->getName(), STB_WEAK, s->stOther, s->type});
    s->used = used;
  });
}

// The section referred to by `s` is considered address-significant. Set the
// keepUnique flag on the section if appropriate.
static void markAddrsig(Symbol *s) {
  if (auto *d = dyn_cast_or_null<Defined>(s))
    if (d->section)
      // We don't need to keep text sections unique under --icf=all even if they
      // are address-significant.
      if (config->icf == ICFLevel::Safe || !(d->section->flags & SHF_EXECINSTR))
        d->section->keepUnique = true;
}

// Record sections that define symbols mentioned in --keep-unique <symbol>
// and symbols referred to by address-significance tables. These sections are
// ineligible for ICF.
template <class ELFT>
static void findKeepUniqueSections(opt::InputArgList &args) {
  for (auto *arg : args.filtered(OPT_keep_unique)) {
    StringRef name = arg->getValue();
    auto *d = dyn_cast_or_null<Defined>(symtab->find(name));
    if (!d || !d->section) {
      warn("could not find symbol " + name + " to keep unique");
      continue;
    }
    d->section->keepUnique = true;
  }

  // --icf=all --ignore-data-address-equality means that we can ignore
  // the dynsym and address-significance tables entirely.
  if (config->icf == ICFLevel::All && config->ignoreDataAddressEquality)
    return;

  // Symbols in the dynsym could be address-significant in other executables
  // or DSOs, so we conservatively mark them as address-significant.
  symtab->forEachSymbol([&](Symbol *sym) {
    if (sym->includeInDynsym())
      markAddrsig(sym);
  });

  // Visit the address-significance table in each object file and mark each
  // referenced symbol as address-significant.
  for (InputFile *f : objectFiles) {
    auto *obj = cast<ObjFile<ELFT>>(f);
    ArrayRef<Symbol *> syms = obj->getSymbols();
    if (obj->addrsigSec) {
      ArrayRef<uint8_t> contents =
          check(obj->getObj().getSectionContents(obj->addrsigSec));
      const uint8_t *cur = contents.begin();
      while (cur != contents.end()) {
        unsigned size;
        const char *err;
        uint64_t symIndex = decodeULEB128(cur, &size, contents.end(), &err);
        if (err)
          fatal(toString(f) + ": could not decode addrsig section: " + err);
        markAddrsig(syms[symIndex]);
        cur += size;
      }
    } else {
      // If an object file does not have an address-significance table,
      // conservatively mark all of its symbols as address-significant.
      for (Symbol *s : syms)
        markAddrsig(s);
    }
  }
}

// This function reads a symbol partition specification section. These sections
// are used to control which partition a symbol is allocated to. See
// https://lld.llvm.org/Partitions.html for more details on partitions.
template <typename ELFT>
static void readSymbolPartitionSection(InputSectionBase *s) {
  // Read the relocation that refers to the partition's entry point symbol.
  Symbol *sym;
  if (s->areRelocsRela)
    sym = &s->getFile<ELFT>()->getRelocTargetSym(s->template relas<ELFT>()[0]);
  else
    sym = &s->getFile<ELFT>()->getRelocTargetSym(s->template rels<ELFT>()[0]);
  if (!isa<Defined>(sym) || !sym->includeInDynsym())
    return;

  StringRef partName = reinterpret_cast<const char *>(s->data().data());
  for (Partition &part : partitions) {
    if (part.name == partName) {
      sym->partition = part.getNumber();
      return;
    }
  }

  // Forbid partitions from being used on incompatible targets, and forbid them
  // from being used together with various linker features that assume a single
  // set of output sections.
  if (script->hasSectionsCommand)
    error(toString(s->file) +
          ": partitions cannot be used with the SECTIONS command");
  if (script->hasPhdrsCommands())
    error(toString(s->file) +
          ": partitions cannot be used with the PHDRS command");
  if (!config->sectionStartMap.empty())
    error(toString(s->file) + ": partitions cannot be used with "
                              "--section-start, -Ttext, -Tdata or -Tbss");
  if (config->emachine == EM_MIPS)
    error(toString(s->file) + ": partitions cannot be used on this target");

  // Impose a limit of no more than 254 partitions. This limit comes from the
  // sizes of the Partition fields in InputSectionBase and Symbol, as well as
  // the amount of space devoted to the partition number in RankFlags.
  if (partitions.size() == 254)
    fatal("may not have more than 254 partitions");

  partitions.emplace_back();
  Partition &newPart = partitions.back();
  newPart.name = partName;
  sym->partition = newPart.getNumber();
}

static Symbol *addUndefined(StringRef name) {
  return symtab->addSymbol(
      Undefined{nullptr, name, STB_GLOBAL, STV_DEFAULT, 0});
}

// This function is where all the optimizations of link-time
// optimization takes place. When LTO is in use, some input files are
// not in native object file format but in the LLVM bitcode format.
// This function compiles bitcode files into a few big native files
// using LLVM functions and replaces bitcode symbols with the results.
// Because all bitcode files that the program consists of are passed to
// the compiler at once, it can do a whole-program optimization.
template <class ELFT> void LinkerDriver::compileBitcodeFiles() {
  // Compile bitcode files and replace bitcode symbols.
  lto.reset(new BitcodeCompiler);
  for (BitcodeFile *file : bitcodeFiles)
    lto->add(*file);

  for (InputFile *file : lto->compile()) {
    auto *obj = cast<ObjFile<ELFT>>(file);
    obj->parse(/*ignoreComdats=*/true);
    for (Symbol *sym : obj->getGlobalSymbols())
      sym->parseSymbolVersion();
    objectFiles.push_back(file);
  }
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
  parallelForEach(objectFiles, [&](InputFile *file) {
    MutableArrayRef<Symbol *> syms = file->getMutableSymbols();
    for (size_t i = 0, e = syms.size(); i != e; ++i)
      if (Symbol *s = map.lookup(syms[i]))
        syms[i] = s;
  });

  // Update pointers in the symbol table.
  for (const WrappedSymbol &w : wrapped)
    symtab->wrap(w.sym, w.real, w.wrap);
}

// To enable CET (x86's hardware-assited control flow enforcement), each
// source file must be compiled with -fcf-protection. Object files compiled
// with the flag contain feature flags indicating that they are compatible
// with CET. We enable the feature only when all object files are compatible
// with CET.
//
// This function returns the merged feature flags. If 0, we cannot enable CET.
// This is also the case with AARCH64's BTI and PAC which use the similar
// GNU_PROPERTY_AARCH64_FEATURE_1_AND mechanism.
//
// Note that the CET-aware PLT is not implemented yet. We do error
// check only.
template <class ELFT> static uint32_t getAndFeatures() {
  if (config->emachine != EM_386 && config->emachine != EM_X86_64 &&
      config->emachine != EM_AARCH64)
    return 0;

  uint32_t ret = -1;
  for (InputFile *f : objectFiles) {
    uint32_t features = cast<ObjFile<ELFT>>(f)->andFeatures;
    if (config->forceBTI && !(features & GNU_PROPERTY_AARCH64_FEATURE_1_BTI)) {
      warn(toString(f) + ": --force-bti: file does not have BTI property");
      features |= GNU_PROPERTY_AARCH64_FEATURE_1_BTI;
    } else if (!features && config->requireCET)
      error(toString(f) + ": --require-cet: file is not compatible with CET");
    ret &= features;
  }

  // Force enable pointer authentication Plt, we don't warn in this case as
  // this does not require support in the object for correctness.
  if (config->pacPlt)
    ret |= GNU_PROPERTY_AARCH64_FEATURE_1_PAC;

  return ret;
}

static const char *libcallRoutineNames[] = {
#define HANDLE_LIBCALL(code, name) name,
#include "llvm/IR/RuntimeLibcalls.def"
#undef HANDLE_LIBCALL
};

// Do actual linking. Note that when this function is called,
// all linker scripts have already been parsed.
template <class ELFT> void LinkerDriver::link(opt::InputArgList &args) {
  // If a -hash-style option was not given, set to a default value,
  // which varies depending on the target.
  if (!args.hasArg(OPT_hash_style)) {
    if (config->emachine == EM_MIPS)
      config->sysvHash = true;
    else
      config->sysvHash = config->gnuHash = true;
  }

  // Default output filename is "a.out" by the Unix tradition.
  if (config->outputFile.empty())
    config->outputFile = "a.out";

  // Fail early if the output file or map file is not writable. If a user has a
  // long link, e.g. due to a large LTO link, they do not wish to run it and
  // find that it failed because there was a mistake in their command-line.
  if (auto e = tryCreateFile(config->outputFile))
    error("cannot open output file " + config->outputFile + ": " + e.message());
  if (auto e = tryCreateFile(config->mapFile))
    error("cannot open map file " + config->mapFile + ": " + e.message());
  if (errorCount())
    return;

  // Use default entry point name if no name was given via the command
  // line nor linker scripts. For some reason, MIPS entry point name is
  // different from others.
  config->warnMissingEntry =
      (!config->entry.empty() || (!config->shared && !config->relocatable));
  if (config->entry.empty() && !config->relocatable)
    config->entry = (config->emachine == EM_MIPS) ? "__start" : "_start";

  // Handle --trace-symbol.
  for (auto *arg : args.filtered(OPT_trace_symbol))
    symtab->insert(arg->getValue())->traced = true;

  // Add all files to the symbol table. This will add almost all
  // symbols that we need to the symbol table. This process might
  // add files to the link, via autolinking, these files are always
  // appended to the Files vector.
  for (size_t i = 0; i < files.size(); ++i)
    parseFile(files[i]);

  // Now that we have every file, we can decide if we will need a
  // dynamic symbol table.
  // We need one if we were asked to export dynamic symbols or if we are
  // producing a shared library.
  // We also need one if any shared libraries are used and for pie executables
  // (probably because the dynamic linker needs it).
  config->hasDynSymTab =
      !sharedFiles.empty() || config->isPic || config->exportDynamic;

  // Some symbols (such as __ehdr_start) are defined lazily only when there
  // are undefined symbols for them, so we add these to trigger that logic.
  for (StringRef name : script->referencedSymbols)
    addUndefined(name);

  // Handle the `--undefined <sym>` options.
  for (StringRef arg : config->undefined)
    if (Symbol *sym = symtab->find(arg))
      handleUndefined(sym);

  // If an entry symbol is in a static archive, pull out that file now.
  if (Symbol *sym = symtab->find(config->entry))
    handleUndefined(sym);

  // Handle the `--undefined-glob <pattern>` options.
  for (StringRef pat : args::getStrings(args, OPT_undefined_glob))
    handleUndefinedGlob(pat);

  // If any of our inputs are bitcode files, the LTO code generator may create
  // references to certain library functions that might not be explicit in the
  // bitcode file's symbol table. If any of those library functions are defined
  // in a bitcode file in an archive member, we need to arrange to use LTO to
  // compile those archive members by adding them to the link beforehand.
  //
  // However, adding all libcall symbols to the link can have undesired
  // consequences. For example, the libgcc implementation of
  // __sync_val_compare_and_swap_8 on 32-bit ARM pulls in an .init_array entry
  // that aborts the program if the Linux kernel does not support 64-bit
  // atomics, which would prevent the program from running even if it does not
  // use 64-bit atomics.
  //
  // Therefore, we only add libcall symbols to the link before LTO if we have
  // to, i.e. if the symbol's definition is in bitcode. Any other required
  // libcall symbols will be added to the link after LTO when we add the LTO
  // object file to the link.
  if (!bitcodeFiles.empty())
    for (const char *s : libcallRoutineNames)
      handleLibcall(s);

  // Return if there were name resolution errors.
  if (errorCount())
    return;

  // Now when we read all script files, we want to finalize order of linker
  // script commands, which can be not yet final because of INSERT commands.
  script->processInsertCommands();

  // We want to declare linker script's symbols early,
  // so that we can version them.
  // They also might be exported if referenced by DSOs.
  script->declareSymbols();

  // Handle the -exclude-libs option.
  if (args.hasArg(OPT_exclude_libs))
    excludeLibs(args);

  // Create elfHeader early. We need a dummy section in
  // addReservedSymbols to mark the created symbols as not absolute.
  Out::elfHeader = make<OutputSection>("", 0, SHF_ALLOC);
  Out::elfHeader->size = sizeof(typename ELFT::Ehdr);

  // Create wrapped symbols for -wrap option.
  std::vector<WrappedSymbol> wrapped = addWrappedSymbols(args);

  // We need to create some reserved symbols such as _end. Create them.
  if (!config->relocatable)
    addReservedSymbols();

  // Apply version scripts.
  //
  // For a relocatable output, version scripts don't make sense, and
  // parsing a symbol version string (e.g. dropping "@ver1" from a symbol
  // name "foo@ver1") rather do harm, so we don't call this if -r is given.
  if (!config->relocatable)
    symtab->scanVersionScript();

  // Do link-time optimization if given files are LLVM bitcode files.
  // This compiles bitcode files into real object files.
  //
  // With this the symbol table should be complete. After this, no new names
  // except a few linker-synthesized ones will be added to the symbol table.
  compileBitcodeFiles<ELFT>();
  if (errorCount())
    return;

  // If -thinlto-index-only is given, we should create only "index
  // files" and not object files. Index file creation is already done
  // in addCombinedLTOObject, so we are done if that's the case.
  if (config->thinLTOIndexOnly)
    return;

  // Likewise, --plugin-opt=emit-llvm is an option to make LTO create
  // an output file in bitcode and exit, so that you can just get a
  // combined bitcode file.
  if (config->emitLLVM)
    return;

  // Apply symbol renames for -wrap.
  if (!wrapped.empty())
    wrapSymbols(wrapped);

  // Now that we have a complete list of input files.
  // Beyond this point, no new files are added.
  // Aggregate all input sections into one place.
  for (InputFile *f : objectFiles)
    for (InputSectionBase *s : f->getSections())
      if (s && s != &InputSection::discarded)
        inputSections.push_back(s);
  for (BinaryFile *f : binaryFiles)
    for (InputSectionBase *s : f->getSections())
      inputSections.push_back(cast<InputSection>(s));

  llvm::erase_if(inputSections, [](InputSectionBase *s) {
    if (s->type == SHT_LLVM_SYMPART) {
      readSymbolPartitionSection<ELFT>(s);
      return true;
    }

    // We do not want to emit debug sections if --strip-all
    // or -strip-debug are given.
    return config->strip != StripPolicy::None &&
           (s->name.startswith(".debug") || s->name.startswith(".zdebug"));
  });

  // Now that the number of partitions is fixed, save a pointer to the main
  // partition.
  mainPart = &partitions[0];

  // Read .note.gnu.property sections from input object files which
  // contain a hint to tweak linker's and loader's behaviors.
  config->andFeatures = getAndFeatures<ELFT>();

  // The Target instance handles target-specific stuff, such as applying
  // relocations or writing a PLT section. It also contains target-dependent
  // values such as a default image base address.
  target = getTarget();

  config->eflags = target->calcEFlags();
  // maxPageSize (sometimes called abi page size) is the maximum page size that
  // the output can be run on. For example if the OS can use 4k or 64k page
  // sizes then maxPageSize must be 64k for the output to be useable on both.
  // All important alignment decisions must use this value.
  config->maxPageSize = getMaxPageSize(args);
  // commonPageSize is the most common page size that the output will be run on.
  // For example if an OS can use 4k or 64k page sizes and 4k is more common
  // than 64k then commonPageSize is set to 4k. commonPageSize can be used for
  // optimizations such as DATA_SEGMENT_ALIGN in linker scripts. LLD's use of it
  // is limited to writing trap instructions on the last executable segment.
  config->commonPageSize = getCommonPageSize(args);

  config->imageBase = getImageBase(args);

  if (config->emachine == EM_ARM) {
    // FIXME: These warnings can be removed when lld only uses these features
    // when the input objects have been compiled with an architecture that
    // supports them.
    if (config->armHasBlx == false)
      warn("lld uses blx instruction, no object with architecture supporting "
           "feature detected");
  }

  // This adds a .comment section containing a version string. We have to add it
  // before mergeSections because the .comment section is a mergeable section.
  if (!config->relocatable)
    inputSections.push_back(createCommentSection());

  // Replace common symbols with regular symbols.
  replaceCommonSymbols();

  // Do size optimizations: garbage collection, merging of SHF_MERGE sections
  // and identical code folding.
  splitSections<ELFT>();
  markLive<ELFT>();
  demoteSharedSymbols();
  mergeSections();
  if (config->icf != ICFLevel::None) {
    findKeepUniqueSections<ELFT>(args);
    doIcf<ELFT>();
  }

  // Read the callgraph now that we know what was gced or icfed
  if (config->callGraphProfileSort) {
    if (auto *arg = args.getLastArg(OPT_call_graph_ordering_file))
      if (Optional<MemoryBufferRef> buffer = readFile(arg->getValue()))
        readCallGraph(*buffer);
    readCallGraphsFromObjectFiles<ELFT>();
  }

  // Write the result to the file.
  writeResult<ELFT>();
}
