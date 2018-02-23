//===- Driver.cpp ---------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
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
#include "Filesystem.h"
#include "ICF.h"
#include "InputFiles.h"
#include "InputSection.h"
#include "LinkerScript.h"
#include "OutputSections.h"
#include "ScriptParser.h"
#include "Strings.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "Writer.h"
#include "lld/Common/Args.h"
#include "lld/Common/Driver.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "lld/Common/Threads.h"
#include "lld/Common/Version.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/ADT/StringSwitch.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Compression.h"
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

using namespace lld;
using namespace lld::elf;

Configuration *elf::Config;
LinkerDriver *elf::Driver;

static void setConfigs();

bool elf::link(ArrayRef<const char *> Args, bool CanExitEarly,
               raw_ostream &Error) {
  errorHandler().LogName = Args[0];
  errorHandler().ErrorLimitExceededMsg =
      "too many errors emitted, stopping now (use "
      "-error-limit=0 to see all errors)";
  errorHandler().ErrorOS = &Error;
  errorHandler().ColorDiagnostics = Error.has_colors();
  InputSections.clear();
  OutputSections.clear();
  Tar = nullptr;
  BinaryFiles.clear();
  BitcodeFiles.clear();
  ObjectFiles.clear();
  SharedFiles.clear();

  Config = make<Configuration>();
  Driver = make<LinkerDriver>();
  Script = make<LinkerScript>();
  Symtab = make<SymbolTable>();
  Config->Argv = {Args.begin(), Args.end()};

  Driver->main(Args, CanExitEarly);

  // Exit immediately if we don't need to return to the caller.
  // This saves time because the overhead of calling destructors
  // for all globally-allocated objects is not negligible.
  if (Config->ExitEarly)
    exitLld(errorCount() ? 1 : 0);

  freeArena();
  return !errorCount();
}

// Parses a linker -m option.
static std::tuple<ELFKind, uint16_t, uint8_t> parseEmulation(StringRef Emul) {
  uint8_t OSABI = 0;
  StringRef S = Emul;
  if (S.endswith("_fbsd")) {
    S = S.drop_back(5);
    OSABI = ELFOSABI_FREEBSD;
  }

  std::pair<ELFKind, uint16_t> Ret =
      StringSwitch<std::pair<ELFKind, uint16_t>>(S)
          .Cases("aarch64elf", "aarch64linux", {ELF64LEKind, EM_AARCH64})
          .Cases("armelf", "armelf_linux_eabi", {ELF32LEKind, EM_ARM})
          .Case("elf32_x86_64", {ELF32LEKind, EM_X86_64})
          .Cases("elf32btsmip", "elf32btsmipn32", {ELF32BEKind, EM_MIPS})
          .Cases("elf32ltsmip", "elf32ltsmipn32", {ELF32LEKind, EM_MIPS})
          .Case("elf32ppc", {ELF32BEKind, EM_PPC})
          .Case("elf64btsmip", {ELF64BEKind, EM_MIPS})
          .Case("elf64ltsmip", {ELF64LEKind, EM_MIPS})
          .Case("elf64ppc", {ELF64BEKind, EM_PPC64})
          .Cases("elf_amd64", "elf_x86_64", {ELF64LEKind, EM_X86_64})
          .Case("elf_i386", {ELF32LEKind, EM_386})
          .Case("elf_iamcu", {ELF32LEKind, EM_IAMCU})
          .Default({ELFNoneKind, EM_NONE});

  if (Ret.first == ELFNoneKind)
    error("unknown emulation: " + Emul);
  return std::make_tuple(Ret.first, Ret.second, OSABI);
}

// Returns slices of MB by parsing MB as an archive file.
// Each slice consists of a member file in the archive.
std::vector<std::pair<MemoryBufferRef, uint64_t>> static getArchiveMembers(
    MemoryBufferRef MB) {
  std::unique_ptr<Archive> File =
      CHECK(Archive::create(MB),
            MB.getBufferIdentifier() + ": failed to parse archive");

  std::vector<std::pair<MemoryBufferRef, uint64_t>> V;
  Error Err = Error::success();
  bool AddToTar = File->isThin() && Tar;
  for (const ErrorOr<Archive::Child> &COrErr : File->children(Err)) {
    Archive::Child C =
        CHECK(COrErr, MB.getBufferIdentifier() +
                          ": could not get the child of the archive");
    MemoryBufferRef MBRef =
        CHECK(C.getMemoryBufferRef(),
              MB.getBufferIdentifier() +
                  ": could not get the buffer for a child of the archive");
    if (AddToTar)
      Tar->append(relativeToRoot(check(C.getFullName())), MBRef.getBuffer());
    V.push_back(std::make_pair(MBRef, C.getChildOffset()));
  }
  if (Err)
    fatal(MB.getBufferIdentifier() + ": Archive::children failed: " +
          toString(std::move(Err)));

  // Take ownership of memory buffers created for members of thin archives.
  for (std::unique_ptr<MemoryBuffer> &MB : File->takeThinBuffers())
    make<std::unique_ptr<MemoryBuffer>>(std::move(MB));

  return V;
}

// Opens a file and create a file object. Path has to be resolved already.
void LinkerDriver::addFile(StringRef Path, bool WithLOption) {
  using namespace sys::fs;

  Optional<MemoryBufferRef> Buffer = readFile(Path);
  if (!Buffer.hasValue())
    return;
  MemoryBufferRef MBRef = *Buffer;

  if (InBinary) {
    Files.push_back(make<BinaryFile>(MBRef));
    return;
  }

  switch (identify_magic(MBRef.getBuffer())) {
  case file_magic::unknown:
    readLinkerScript(MBRef);
    return;
  case file_magic::archive: {
    // Handle -whole-archive.
    if (InWholeArchive) {
      for (const auto &P : getArchiveMembers(MBRef))
        Files.push_back(createObjectFile(P.first, Path, P.second));
      return;
    }

    std::unique_ptr<Archive> File =
        CHECK(Archive::create(MBRef), Path + ": failed to parse archive");

    // If an archive file has no symbol table, it is likely that a user
    // is attempting LTO and using a default ar command that doesn't
    // understand the LLVM bitcode file. It is a pretty common error, so
    // we'll handle it as if it had a symbol table.
    if (!File->isEmpty() && !File->hasSymbolTable()) {
      for (const auto &P : getArchiveMembers(MBRef))
        Files.push_back(make<LazyObjFile>(P.first, Path, P.second));
      return;
    }

    // Handle the regular case.
    Files.push_back(make<ArchiveFile>(std::move(File)));
    return;
  }
  case file_magic::elf_shared_object:
    if (Config->Relocatable) {
      error("attempted static link of dynamic object " + Path);
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
    Files.push_back(
        createSharedFile(MBRef, WithLOption ? path::filename(Path) : Path));
    return;
  default:
    if (InLib)
      Files.push_back(make<LazyObjFile>(MBRef, "", 0));
    else
      Files.push_back(createObjectFile(MBRef));
  }
}

// Add a given library by searching it from input search paths.
void LinkerDriver::addLibrary(StringRef Name) {
  if (Optional<std::string> Path = searchLibrary(Name))
    addFile(*Path, /*WithLOption=*/true);
  else
    error("unable to find library -l" + Name);
}

// This function is called on startup. We need this for LTO since
// LTO calls LLVM functions to compile bitcode files to native code.
// Technically this can be delayed until we read bitcode files, but
// we don't bother to do lazily because the initialization is fast.
static void initLLVM(opt::InputArgList &Args) {
  InitializeAllTargets();
  InitializeAllTargetMCs();
  InitializeAllAsmPrinters();
  InitializeAllAsmParsers();

  // Parse and evaluate -mllvm options.
  std::vector<const char *> V;
  V.push_back("lld (LLVM option parsing)");
  for (auto *Arg : Args.filtered(OPT_mllvm))
    V.push_back(Arg->getValue());
  cl::ParseCommandLineOptions(V.size(), V.data());
}

// Some command line options or some combinations of them are not allowed.
// This function checks for such errors.
static void checkOptions(opt::InputArgList &Args) {
  // The MIPS ABI as of 2016 does not support the GNU-style symbol lookup
  // table which is a relatively new feature.
  if (Config->EMachine == EM_MIPS && Config->GnuHash)
    error("the .gnu.hash section is not compatible with the MIPS target.");

  if (Config->FixCortexA53Errata843419 && Config->EMachine != EM_AARCH64)
    error("--fix-cortex-a53-843419 is only supported on AArch64 targets.");

  if (Config->Pie && Config->Shared)
    error("-shared and -pie may not be used together");

  if (!Config->Shared && !Config->FilterList.empty())
    error("-F may not be used without -shared");

  if (!Config->Shared && !Config->AuxiliaryList.empty())
    error("-f may not be used without -shared");

  if (!Config->Relocatable && !Config->DefineCommon)
    error("-no-define-common not supported in non relocatable output");

  if (Config->Relocatable) {
    if (Config->Shared)
      error("-r and -shared may not be used together");
    if (Config->GcSections)
      error("-r and --gc-sections may not be used together");
    if (Config->ICF)
      error("-r and --icf may not be used together");
    if (Config->Pie)
      error("-r and -pie may not be used together");
  }
}

static const char *getReproduceOption(opt::InputArgList &Args) {
  if (auto *Arg = Args.getLastArg(OPT_reproduce))
    return Arg->getValue();
  return getenv("LLD_REPRODUCE");
}

static bool hasZOption(opt::InputArgList &Args, StringRef Key) {
  for (auto *Arg : Args.filtered(OPT_z))
    if (Key == Arg->getValue())
      return true;
  return false;
}

void LinkerDriver::main(ArrayRef<const char *> ArgsArr, bool CanExitEarly) {
  ELFOptTable Parser;
  opt::InputArgList Args = Parser.parse(ArgsArr.slice(1));

  // Interpret this flag early because error() depends on them.
  errorHandler().ErrorLimit = args::getInteger(Args, OPT_error_limit, 20);

  // Handle -help
  if (Args.hasArg(OPT_help)) {
    printHelp(ArgsArr[0]);
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
  if (Args.hasArg(OPT_v) || Args.hasArg(OPT_version))
    message(getLLDVersion() + " (compatible with GNU linkers)");

  // The behavior of -v or --version is a bit strange, but this is
  // needed for compatibility with GNU linkers.
  if (Args.hasArg(OPT_v) && !Args.hasArg(OPT_INPUT))
    return;
  if (Args.hasArg(OPT_version))
    return;

  Config->ExitEarly = CanExitEarly && !Args.hasArg(OPT_full_shutdown);
  errorHandler().ExitEarly = Config->ExitEarly;

  if (const char *Path = getReproduceOption(Args)) {
    // Note that --reproduce is a debug option so you can ignore it
    // if you are trying to understand the whole picture of the code.
    Expected<std::unique_ptr<TarWriter>> ErrOrWriter =
        TarWriter::create(Path, path::stem(Path));
    if (ErrOrWriter) {
      Tar = ErrOrWriter->get();
      Tar->append("response.txt", createResponseFile(Args));
      Tar->append("version.txt", getLLDVersion() + "\n");
      make<std::unique_ptr<TarWriter>>(std::move(*ErrOrWriter));
    } else {
      error(Twine("--reproduce: failed to open ") + Path + ": " +
            toString(ErrOrWriter.takeError()));
    }
  }

  readConfigs(Args);
  initLLVM(Args);
  createFiles(Args);
  inferMachineType();
  setConfigs();
  checkOptions(Args);
  if (errorCount())
    return;

  switch (Config->EKind) {
  case ELF32LEKind:
    link<ELF32LE>(Args);
    return;
  case ELF32BEKind:
    link<ELF32BE>(Args);
    return;
  case ELF64LEKind:
    link<ELF64LE>(Args);
    return;
  case ELF64BEKind:
    link<ELF64BE>(Args);
    return;
  default:
    llvm_unreachable("unknown Config->EKind");
  }
}

static std::string getRpath(opt::InputArgList &Args) {
  std::vector<StringRef> V = args::getStrings(Args, OPT_rpath);
  return llvm::join(V.begin(), V.end(), ":");
}

// Determines what we should do if there are remaining unresolved
// symbols after the name resolution.
static UnresolvedPolicy getUnresolvedSymbolPolicy(opt::InputArgList &Args) {
  if (Args.hasArg(OPT_relocatable))
    return UnresolvedPolicy::IgnoreAll;

  UnresolvedPolicy ErrorOrWarn = Args.hasFlag(OPT_error_unresolved_symbols,
                                              OPT_warn_unresolved_symbols, true)
                                     ? UnresolvedPolicy::ReportError
                                     : UnresolvedPolicy::Warn;

  // Process the last of -unresolved-symbols, -no-undefined or -z defs.
  for (auto *Arg : llvm::reverse(Args)) {
    switch (Arg->getOption().getID()) {
    case OPT_unresolved_symbols: {
      StringRef S = Arg->getValue();
      if (S == "ignore-all" || S == "ignore-in-object-files")
        return UnresolvedPolicy::Ignore;
      if (S == "ignore-in-shared-libs" || S == "report-all")
        return ErrorOrWarn;
      error("unknown --unresolved-symbols value: " + S);
      continue;
    }
    case OPT_no_undefined:
      return ErrorOrWarn;
    case OPT_z:
      if (StringRef(Arg->getValue()) == "defs")
        return ErrorOrWarn;
      continue;
    }
  }

  // -shared implies -unresolved-symbols=ignore-all because missing
  // symbols are likely to be resolved at runtime using other DSOs.
  if (Config->Shared)
    return UnresolvedPolicy::Ignore;
  return ErrorOrWarn;
}

static Target2Policy getTarget2(opt::InputArgList &Args) {
  StringRef S = Args.getLastArgValue(OPT_target2, "got-rel");
  if (S == "rel")
    return Target2Policy::Rel;
  if (S == "abs")
    return Target2Policy::Abs;
  if (S == "got-rel")
    return Target2Policy::GotRel;
  error("unknown --target2 option: " + S);
  return Target2Policy::GotRel;
}

static bool isOutputFormatBinary(opt::InputArgList &Args) {
  if (auto *Arg = Args.getLastArg(OPT_oformat)) {
    StringRef S = Arg->getValue();
    if (S == "binary")
      return true;
    error("unknown --oformat value: " + S);
  }
  return false;
}

static DiscardPolicy getDiscard(opt::InputArgList &Args) {
  if (Args.hasArg(OPT_relocatable))
    return DiscardPolicy::None;

  auto *Arg =
      Args.getLastArg(OPT_discard_all, OPT_discard_locals, OPT_discard_none);
  if (!Arg)
    return DiscardPolicy::Default;
  if (Arg->getOption().getID() == OPT_discard_all)
    return DiscardPolicy::All;
  if (Arg->getOption().getID() == OPT_discard_locals)
    return DiscardPolicy::Locals;
  return DiscardPolicy::None;
}

static StringRef getDynamicLinker(opt::InputArgList &Args) {
  auto *Arg = Args.getLastArg(OPT_dynamic_linker, OPT_no_dynamic_linker);
  if (!Arg || Arg->getOption().getID() == OPT_no_dynamic_linker)
    return "";
  return Arg->getValue();
}

static StripPolicy getStrip(opt::InputArgList &Args) {
  if (Args.hasArg(OPT_relocatable))
    return StripPolicy::None;

  auto *Arg = Args.getLastArg(OPT_strip_all, OPT_strip_debug);
  if (!Arg)
    return StripPolicy::None;
  if (Arg->getOption().getID() == OPT_strip_all)
    return StripPolicy::All;
  return StripPolicy::Debug;
}

static uint64_t parseSectionAddress(StringRef S, const opt::Arg &Arg) {
  uint64_t VA = 0;
  if (S.startswith("0x"))
    S = S.drop_front(2);
  if (!to_integer(S, VA, 16))
    error("invalid argument: " + toString(Arg));
  return VA;
}

static StringMap<uint64_t> getSectionStartMap(opt::InputArgList &Args) {
  StringMap<uint64_t> Ret;
  for (auto *Arg : Args.filtered(OPT_section_start)) {
    StringRef Name;
    StringRef Addr;
    std::tie(Name, Addr) = StringRef(Arg->getValue()).split('=');
    Ret[Name] = parseSectionAddress(Addr, *Arg);
  }

  if (auto *Arg = Args.getLastArg(OPT_Ttext))
    Ret[".text"] = parseSectionAddress(Arg->getValue(), *Arg);
  if (auto *Arg = Args.getLastArg(OPT_Tdata))
    Ret[".data"] = parseSectionAddress(Arg->getValue(), *Arg);
  if (auto *Arg = Args.getLastArg(OPT_Tbss))
    Ret[".bss"] = parseSectionAddress(Arg->getValue(), *Arg);
  return Ret;
}

static SortSectionPolicy getSortSection(opt::InputArgList &Args) {
  StringRef S = Args.getLastArgValue(OPT_sort_section);
  if (S == "alignment")
    return SortSectionPolicy::Alignment;
  if (S == "name")
    return SortSectionPolicy::Name;
  if (!S.empty())
    error("unknown --sort-section rule: " + S);
  return SortSectionPolicy::Default;
}

static OrphanHandlingPolicy getOrphanHandling(opt::InputArgList &Args) {
  StringRef S = Args.getLastArgValue(OPT_orphan_handling, "place");
  if (S == "warn")
    return OrphanHandlingPolicy::Warn;
  if (S == "error")
    return OrphanHandlingPolicy::Error;
  if (S != "place")
    error("unknown --orphan-handling mode: " + S);
  return OrphanHandlingPolicy::Place;
}

// Parse --build-id or --build-id=<style>. We handle "tree" as a
// synonym for "sha1" because all our hash functions including
// -build-id=sha1 are actually tree hashes for performance reasons.
static std::pair<BuildIdKind, std::vector<uint8_t>>
getBuildId(opt::InputArgList &Args) {
  auto *Arg = Args.getLastArg(OPT_build_id, OPT_build_id_eq);
  if (!Arg)
    return {BuildIdKind::None, {}};

  if (Arg->getOption().getID() == OPT_build_id)
    return {BuildIdKind::Fast, {}};

  StringRef S = Arg->getValue();
  if (S == "md5")
    return {BuildIdKind::Md5, {}};
  if (S == "sha1" || S == "tree")
    return {BuildIdKind::Sha1, {}};
  if (S == "uuid")
    return {BuildIdKind::Uuid, {}};
  if (S.startswith("0x"))
    return {BuildIdKind::Hexstring, parseHex(S.substr(2))};

  if (S != "none")
    error("unknown --build-id style: " + S);
  return {BuildIdKind::None, {}};
}

static bool getCompressDebugSections(opt::InputArgList &Args) {
  StringRef S = Args.getLastArgValue(OPT_compress_debug_sections, "none");
  if (S == "none")
    return false;
  if (S != "zlib")
    error("unknown --compress-debug-sections value: " + S);
  if (!zlib::isAvailable())
    error("--compress-debug-sections: zlib is not available");
  return true;
}

static int parseInt(StringRef S, opt::Arg *Arg) {
  int V = 0;
  if (!to_integer(S, V, 10))
    error(Arg->getSpelling() + ": number expected, but got '" + S + "'");
  return V;
}

// Initializes Config members by the command line options.
void LinkerDriver::readConfigs(opt::InputArgList &Args) {
  Config->AllowMultipleDefinition =
      Args.hasArg(OPT_allow_multiple_definition) || hasZOption(Args, "muldefs");
  Config->AuxiliaryList = args::getStrings(Args, OPT_auxiliary);
  Config->Bsymbolic = Args.hasArg(OPT_Bsymbolic);
  Config->BsymbolicFunctions = Args.hasArg(OPT_Bsymbolic_functions);
  Config->Chroot = Args.getLastArgValue(OPT_chroot);
  Config->CompressDebugSections = getCompressDebugSections(Args);
  Config->DefineCommon = Args.hasFlag(OPT_define_common, OPT_no_define_common,
                                      !Args.hasArg(OPT_relocatable));
  Config->Demangle = Args.hasFlag(OPT_demangle, OPT_no_demangle, true);
  Config->DisableVerify = Args.hasArg(OPT_disable_verify);
  Config->Discard = getDiscard(Args);
  Config->DynamicLinker = getDynamicLinker(Args);
  Config->EhFrameHdr =
      Args.hasFlag(OPT_eh_frame_hdr, OPT_no_eh_frame_hdr, false);
  Config->EmitRelocs = Args.hasArg(OPT_emit_relocs);
  Config->EnableNewDtags = !Args.hasArg(OPT_disable_new_dtags);
  Config->Entry = Args.getLastArgValue(OPT_entry);
  Config->ExportDynamic =
      Args.hasFlag(OPT_export_dynamic, OPT_no_export_dynamic, false);
  errorHandler().FatalWarnings =
      Args.hasFlag(OPT_fatal_warnings, OPT_no_fatal_warnings, false);
  Config->FilterList = args::getStrings(Args, OPT_filter);
  Config->Fini = Args.getLastArgValue(OPT_fini, "_fini");
  Config->FixCortexA53Errata843419 = Args.hasArg(OPT_fix_cortex_a53_843419);
  Config->GcSections = Args.hasFlag(OPT_gc_sections, OPT_no_gc_sections, false);
  Config->GdbIndex = Args.hasFlag(OPT_gdb_index, OPT_no_gdb_index, false);
  Config->ICF = Args.hasFlag(OPT_icf_all, OPT_icf_none, false);
  Config->ICFData = Args.hasArg(OPT_icf_data);
  Config->Init = Args.getLastArgValue(OPT_init, "_init");
  Config->LTOAAPipeline = Args.getLastArgValue(OPT_lto_aa_pipeline);
  Config->LTONewPmPasses = Args.getLastArgValue(OPT_lto_newpm_passes);
  Config->LTOO = args::getInteger(Args, OPT_lto_O, 2);
  Config->LTOPartitions = args::getInteger(Args, OPT_lto_partitions, 1);
  Config->MapFile = Args.getLastArgValue(OPT_Map);
  Config->NoGnuUnique = Args.hasArg(OPT_no_gnu_unique);
  Config->MergeArmExidx =
      Args.hasFlag(OPT_merge_exidx_entries, OPT_no_merge_exidx_entries, true);
  Config->NoUndefinedVersion = Args.hasArg(OPT_no_undefined_version);
  Config->NoinhibitExec = Args.hasArg(OPT_noinhibit_exec);
  Config->Nostdlib = Args.hasArg(OPT_nostdlib);
  Config->OFormatBinary = isOutputFormatBinary(Args);
  Config->Omagic = Args.hasFlag(OPT_omagic, OPT_no_omagic, false);
  Config->OptRemarksFilename = Args.getLastArgValue(OPT_opt_remarks_filename);
  Config->OptRemarksWithHotness = Args.hasArg(OPT_opt_remarks_with_hotness);
  Config->Optimize = args::getInteger(Args, OPT_O, 1);
  Config->OrphanHandling = getOrphanHandling(Args);
  Config->OutputFile = Args.getLastArgValue(OPT_o);
  Config->Pie = Args.hasFlag(OPT_pie, OPT_nopie, false);
  Config->PrintGcSections =
      Args.hasFlag(OPT_print_gc_sections, OPT_no_print_gc_sections, false);
  Config->Rpath = getRpath(Args);
  Config->Relocatable = Args.hasArg(OPT_relocatable);
  Config->SaveTemps = Args.hasArg(OPT_save_temps);
  Config->SearchPaths = args::getStrings(Args, OPT_library_path);
  Config->SectionStartMap = getSectionStartMap(Args);
  Config->Shared = Args.hasArg(OPT_shared);
  Config->SingleRoRx = Args.hasArg(OPT_no_rosegment);
  Config->SoName = Args.getLastArgValue(OPT_soname);
  Config->SortSection = getSortSection(Args);
  Config->Strip = getStrip(Args);
  Config->Sysroot = Args.getLastArgValue(OPT_sysroot);
  Config->Target1Rel = Args.hasFlag(OPT_target1_rel, OPT_target1_abs, false);
  Config->Target2 = getTarget2(Args);
  Config->ThinLTOCacheDir = Args.getLastArgValue(OPT_thinlto_cache_dir);
  Config->ThinLTOCachePolicy = CHECK(
      parseCachePruningPolicy(Args.getLastArgValue(OPT_thinlto_cache_policy)),
      "--thinlto-cache-policy: invalid cache policy");
  Config->ThinLTOJobs = args::getInteger(Args, OPT_thinlto_jobs, -1u);
  ThreadsEnabled = Args.hasFlag(OPT_threads, OPT_no_threads, true);
  Config->Trace = Args.hasArg(OPT_trace);
  Config->Undefined = args::getStrings(Args, OPT_undefined);
  Config->UnresolvedSymbols = getUnresolvedSymbolPolicy(Args);
  Config->Verbose = Args.hasArg(OPT_verbose);
  errorHandler().Verbose = Config->Verbose;
  Config->WarnCommon = Args.hasArg(OPT_warn_common);
  Config->ZCombreloc = !hasZOption(Args, "nocombreloc");
  Config->ZExecstack = hasZOption(Args, "execstack");
  Config->ZNocopyreloc = hasZOption(Args, "nocopyreloc");
  Config->ZNodelete = hasZOption(Args, "nodelete");
  Config->ZNodlopen = hasZOption(Args, "nodlopen");
  Config->ZNow = hasZOption(Args, "now");
  Config->ZOrigin = hasZOption(Args, "origin");
  Config->ZRelro = !hasZOption(Args, "norelro");
  Config->ZRetpolineplt = hasZOption(Args, "retpolineplt");
  Config->ZRodynamic = hasZOption(Args, "rodynamic");
  Config->ZStackSize = args::getZOptionValue(Args, OPT_z, "stack-size", 0);
  Config->ZText = !hasZOption(Args, "notext");
  Config->ZWxneeded = hasZOption(Args, "wxneeded");

  // Parse LTO plugin-related options for compatibility with gold.
  for (auto *Arg : Args.filtered(OPT_plugin_opt, OPT_plugin_opt_eq)) {
    StringRef S = Arg->getValue();
    if (S == "disable-verify")
      Config->DisableVerify = true;
    else if (S == "save-temps")
      Config->SaveTemps = true;
    else if (S.startswith("O"))
      Config->LTOO = parseInt(S.substr(1), Arg);
    else if (S.startswith("lto-partitions="))
      Config->LTOPartitions = parseInt(S.substr(15), Arg);
    else if (S.startswith("jobs="))
      Config->ThinLTOJobs = parseInt(S.substr(5), Arg);
    else if (!S.startswith("/") && !S.startswith("-fresolution=") &&
             !S.startswith("-pass-through=") && !S.startswith("mcpu=") &&
             !S.startswith("thinlto") && S != "-function-sections" &&
             S != "-data-sections")
      error(Arg->getSpelling() + ": unknown option: " + S);
  }

  if (Config->LTOO > 3)
    error("invalid optimization level for LTO: " + Twine(Config->LTOO));
  if (Config->LTOPartitions == 0)
    error("--lto-partitions: number of threads must be > 0");
  if (Config->ThinLTOJobs == 0)
    error("--thinlto-jobs: number of threads must be > 0");

  // Parse ELF{32,64}{LE,BE} and CPU type.
  if (auto *Arg = Args.getLastArg(OPT_m)) {
    StringRef S = Arg->getValue();
    std::tie(Config->EKind, Config->EMachine, Config->OSABI) =
        parseEmulation(S);
    Config->MipsN32Abi = (S == "elf32btsmipn32" || S == "elf32ltsmipn32");
    Config->Emulation = S;
  }

  // Parse -hash-style={sysv,gnu,both}.
  if (auto *Arg = Args.getLastArg(OPT_hash_style)) {
    StringRef S = Arg->getValue();
    if (S == "sysv")
      Config->SysvHash = true;
    else if (S == "gnu")
      Config->GnuHash = true;
    else if (S == "both")
      Config->SysvHash = Config->GnuHash = true;
    else
      error("unknown -hash-style: " + S);
  }

  if (Args.hasArg(OPT_print_map))
    Config->MapFile = "-";

  // --omagic is an option to create old-fashioned executables in which
  // .text segments are writable. Today, the option is still in use to
  // create special-purpose programs such as boot loaders. It doesn't
  // make sense to create PT_GNU_RELRO for such executables.
  if (Config->Omagic)
    Config->ZRelro = false;

  std::tie(Config->BuildId, Config->BuildIdVector) = getBuildId(Args);

  if (auto *Arg = Args.getLastArg(OPT_pack_dyn_relocs_eq)) {
    StringRef S = Arg->getValue();
    if (S == "android")
      Config->AndroidPackDynRelocs = true;
    else if (S != "none")
      error("unknown -pack-dyn-relocs format: " + S);
  }

  if (auto *Arg = Args.getLastArg(OPT_symbol_ordering_file))
    if (Optional<MemoryBufferRef> Buffer = readFile(Arg->getValue()))
      Config->SymbolOrderingFile = args::getLines(*Buffer);

  // If --retain-symbol-file is used, we'll keep only the symbols listed in
  // the file and discard all others.
  if (auto *Arg = Args.getLastArg(OPT_retain_symbols_file)) {
    Config->DefaultSymbolVersion = VER_NDX_LOCAL;
    if (Optional<MemoryBufferRef> Buffer = readFile(Arg->getValue()))
      for (StringRef S : args::getLines(*Buffer))
        Config->VersionScriptGlobals.push_back(
            {S, /*IsExternCpp*/ false, /*HasWildcard*/ false});
  }

  bool HasExportDynamic =
      Args.hasFlag(OPT_export_dynamic, OPT_no_export_dynamic, false);

  // Parses -dynamic-list and -export-dynamic-symbol. They make some
  // symbols private. Note that -export-dynamic takes precedence over them
  // as it says all symbols should be exported.
  if (!HasExportDynamic) {
    for (auto *Arg : Args.filtered(OPT_dynamic_list))
      if (Optional<MemoryBufferRef> Buffer = readFile(Arg->getValue()))
        readDynamicList(*Buffer);

    for (auto *Arg : Args.filtered(OPT_export_dynamic_symbol))
      Config->DynamicList.push_back(
          {Arg->getValue(), /*IsExternCpp*/ false, /*HasWildcard*/ false});
  }

  for (auto *Arg : Args.filtered(OPT_version_script))
    if (Optional<MemoryBufferRef> Buffer = readFile(Arg->getValue()))
      readVersionScript(*Buffer);
}

// Some Config members do not directly correspond to any particular
// command line options, but computed based on other Config values.
// This function initialize such members. See Config.h for the details
// of these values.
static void setConfigs() {
  ELFKind Kind = Config->EKind;
  uint16_t Machine = Config->EMachine;

  // There is an ILP32 ABI for x86-64, although it's not very popular.
  // It is called the x32 ABI.
  bool IsX32 = (Kind == ELF32LEKind && Machine == EM_X86_64);

  Config->CopyRelocs = (Config->Relocatable || Config->EmitRelocs);
  Config->Is64 = (Kind == ELF64LEKind || Kind == ELF64BEKind);
  Config->IsLE = (Kind == ELF32LEKind || Kind == ELF64LEKind);
  Config->Endianness =
      Config->IsLE ? support::endianness::little : support::endianness::big;
  Config->IsMips64EL = (Kind == ELF64LEKind && Machine == EM_MIPS);
  Config->IsRela = Config->Is64 || IsX32 || Config->MipsN32Abi;
  Config->Pic = Config->Pie || Config->Shared;
  Config->Wordsize = Config->Is64 ? 8 : 4;
}

// Returns a value of "-format" option.
static bool getBinaryOption(StringRef S) {
  if (S == "binary")
    return true;
  if (S == "elf" || S == "default")
    return false;
  error("unknown -format value: " + S +
        " (supported formats: elf, default, binary)");
  return false;
}

void LinkerDriver::createFiles(opt::InputArgList &Args) {
  for (auto *Arg : Args) {
    switch (Arg->getOption().getUnaliasedOption().getID()) {
    case OPT_library:
      addLibrary(Arg->getValue());
      break;
    case OPT_INPUT:
      addFile(Arg->getValue(), /*WithLOption=*/false);
      break;
    case OPT_script:
      if (Optional<std::string> Path = searchLinkerScript(Arg->getValue())) {
        if (Optional<MemoryBufferRef> MB = readFile(*Path))
          readLinkerScript(*MB);
        break;
      }
      error(Twine("cannot find linker script ") + Arg->getValue());
      break;
    case OPT_as_needed:
      Config->AsNeeded = true;
      break;
    case OPT_format:
      InBinary = getBinaryOption(Arg->getValue());
      break;
    case OPT_no_as_needed:
      Config->AsNeeded = false;
      break;
    case OPT_Bstatic:
      Config->Static = true;
      break;
    case OPT_Bdynamic:
      Config->Static = false;
      break;
    case OPT_whole_archive:
      InWholeArchive = true;
      break;
    case OPT_no_whole_archive:
      InWholeArchive = false;
      break;
    case OPT_start_lib:
      InLib = true;
      break;
    case OPT_end_lib:
      InLib = false;
      break;
    }
  }

  if (Files.empty() && errorCount() == 0)
    error("no input files");
}

// If -m <machine_type> was not given, infer it from object files.
void LinkerDriver::inferMachineType() {
  if (Config->EKind != ELFNoneKind)
    return;

  for (InputFile *F : Files) {
    if (F->EKind == ELFNoneKind)
      continue;
    Config->EKind = F->EKind;
    Config->EMachine = F->EMachine;
    Config->OSABI = F->OSABI;
    Config->MipsN32Abi = Config->EMachine == EM_MIPS && isMipsN32Abi(F);
    return;
  }
  error("target emulation unknown: -m or at least one .o file required");
}

// Parse -z max-page-size=<value>. The default value is defined by
// each target.
static uint64_t getMaxPageSize(opt::InputArgList &Args) {
  uint64_t Val = args::getZOptionValue(Args, OPT_z, "max-page-size",
                                       Target->DefaultMaxPageSize);
  if (!isPowerOf2_64(Val))
    error("max-page-size: value isn't a power of 2");
  return Val;
}

// Parses -image-base option.
static Optional<uint64_t> getImageBase(opt::InputArgList &Args) {
  // Because we are using "Config->MaxPageSize" here, this function has to be
  // called after the variable is initialized.
  auto *Arg = Args.getLastArg(OPT_image_base);
  if (!Arg)
    return None;

  StringRef S = Arg->getValue();
  uint64_t V;
  if (!to_integer(S, V)) {
    error("-image-base: number expected, but got " + S);
    return 0;
  }
  if ((V % Config->MaxPageSize) != 0)
    warn("-image-base: address isn't multiple of page size: " + S);
  return V;
}

// Parses `--exclude-libs=lib,lib,...`.
// The library names may be delimited by commas or colons.
static DenseSet<StringRef> getExcludeLibs(opt::InputArgList &Args) {
  DenseSet<StringRef> Ret;
  for (auto *Arg : Args.filtered(OPT_exclude_libs)) {
    StringRef S = Arg->getValue();
    for (;;) {
      size_t Pos = S.find_first_of(",:");
      if (Pos == StringRef::npos)
        break;
      Ret.insert(S.substr(0, Pos));
      S = S.substr(Pos + 1);
    }
    Ret.insert(S);
  }
  return Ret;
}

static Optional<StringRef> getArchiveName(InputFile *File) {
  if (isa<ArchiveFile>(File))
    return File->getName();
  if (!File->ArchiveName.empty())
    return File->ArchiveName;
  return None;
}

// Handles the -exclude-libs option. If a static library file is specified
// by the -exclude-libs option, all public symbols from the archive become
// private unless otherwise specified by version scripts or something.
// A special library name "ALL" means all archive files.
//
// This is not a popular option, but some programs such as bionic libc use it.
template <class ELFT>
static void excludeLibs(opt::InputArgList &Args, ArrayRef<InputFile *> Files) {
  DenseSet<StringRef> Libs = getExcludeLibs(Args);
  bool All = Libs.count("ALL");

  for (InputFile *File : Files)
    if (Optional<StringRef> Archive = getArchiveName(File))
      if (All || Libs.count(path::filename(*Archive)))
        for (Symbol *Sym : File->getSymbols())
          if (!Sym->isLocal())
            Sym->VersionId = VER_NDX_LOCAL;
}

// Do actual linking. Note that when this function is called,
// all linker scripts have already been parsed.
template <class ELFT> void LinkerDriver::link(opt::InputArgList &Args) {
  Target = getTarget();

  Config->MaxPageSize = getMaxPageSize(Args);
  Config->ImageBase = getImageBase(Args);

  // If a -hash-style option was not given, set to a default value,
  // which varies depending on the target.
  if (!Args.hasArg(OPT_hash_style)) {
    if (Config->EMachine == EM_MIPS)
      Config->SysvHash = true;
    else
      Config->SysvHash = Config->GnuHash = true;
  }

  // Default output filename is "a.out" by the Unix tradition.
  if (Config->OutputFile.empty())
    Config->OutputFile = "a.out";

  // Fail early if the output file or map file is not writable. If a user has a
  // long link, e.g. due to a large LTO link, they do not wish to run it and
  // find that it failed because there was a mistake in their command-line.
  if (auto E = tryCreateFile(Config->OutputFile))
    error("cannot open output file " + Config->OutputFile + ": " + E.message());
  if (auto E = tryCreateFile(Config->MapFile))
    error("cannot open map file " + Config->MapFile + ": " + E.message());
  if (errorCount())
    return;

  // Use default entry point name if no name was given via the command
  // line nor linker scripts. For some reason, MIPS entry point name is
  // different from others.
  Config->WarnMissingEntry =
      (!Config->Entry.empty() || (!Config->Shared && !Config->Relocatable));
  if (Config->Entry.empty() && !Config->Relocatable)
    Config->Entry = (Config->EMachine == EM_MIPS) ? "__start" : "_start";

  // Handle --trace-symbol.
  for (auto *Arg : Args.filtered(OPT_trace_symbol))
    Symtab->trace(Arg->getValue());

  // Add all files to the symbol table. This will add almost all
  // symbols that we need to the symbol table.
  for (InputFile *F : Files)
    Symtab->addFile<ELFT>(F);

  // Process -defsym option.
  for (auto *Arg : Args.filtered(OPT_defsym)) {
    StringRef From;
    StringRef To;
    std::tie(From, To) = StringRef(Arg->getValue()).split('=');
    readDefsym(From, MemoryBufferRef(To, "-defsym"));
  }

  // Now that we have every file, we can decide if we will need a
  // dynamic symbol table.
  // We need one if we were asked to export dynamic symbols or if we are
  // producing a shared library.
  // We also need one if any shared libraries are used and for pie executables
  // (probably because the dynamic linker needs it).
  Config->HasDynSymTab =
      !SharedFiles.empty() || Config->Pic || Config->ExportDynamic;

  // Some symbols (such as __ehdr_start) are defined lazily only when there
  // are undefined symbols for them, so we add these to trigger that logic.
  for (StringRef Sym : Script->ReferencedSymbols)
    Symtab->addUndefined<ELFT>(Sym);

  // Handle the `--undefined <sym>` options.
  for (StringRef S : Config->Undefined)
    Symtab->fetchIfLazy<ELFT>(S);

  // If an entry symbol is in a static archive, pull out that file now
  // to complete the symbol table. After this, no new names except a
  // few linker-synthesized ones will be added to the symbol table.
  Symtab->fetchIfLazy<ELFT>(Config->Entry);

  // Return if there were name resolution errors.
  if (errorCount())
    return;

  // Handle undefined symbols in DSOs.
  if (!Config->Shared)
    Symtab->scanShlibUndefined<ELFT>();

  // Handle the -exclude-libs option.
  if (Args.hasArg(OPT_exclude_libs))
    excludeLibs<ELFT>(Args, Files);

  // Create ElfHeader early. We need a dummy section in
  // addReservedSymbols to mark the created symbols as not absolute.
  Out::ElfHeader = make<OutputSection>("", 0, SHF_ALLOC);
  Out::ElfHeader->Size = sizeof(typename ELFT::Ehdr);

  // We need to create some reserved symbols such as _end. Create them.
  if (!Config->Relocatable)
    addReservedSymbols();

  // Apply version scripts.
  //
  // For a relocatable output, version scripts don't make sense, and
  // parsing a symbol version string (e.g. dropping "@ver1" from a symbol
  // name "foo@ver1") rather do harm, so we don't call this if -r is given.
  if (!Config->Relocatable)
    Symtab->scanVersionScript();

  // Create wrapped symbols for -wrap option.
  for (auto *Arg : Args.filtered(OPT_wrap))
    Symtab->addSymbolWrap<ELFT>(Arg->getValue());

  Symtab->addCombinedLTOObject<ELFT>();
  if (errorCount())
    return;

  // Apply symbol renames for -wrap.
  Symtab->applySymbolWrap();

  // Now that we have a complete list of input files.
  // Beyond this point, no new files are added.
  // Aggregate all input sections into one place.
  for (InputFile *F : ObjectFiles)
    for (InputSectionBase *S : F->getSections())
      if (S && S != &InputSection::Discarded)
        InputSections.push_back(S);
  for (BinaryFile *F : BinaryFiles)
    for (InputSectionBase *S : F->getSections())
      InputSections.push_back(cast<InputSection>(S));

  // We do not want to emit debug sections if --strip-all
  // or -strip-debug are given.
  if (Config->Strip != StripPolicy::None)
    llvm::erase_if(InputSections, [](InputSectionBase *S) {
      return S->Name.startswith(".debug") || S->Name.startswith(".zdebug");
    });

  Config->EFlags = Target->calcEFlags();

  if (Config->EMachine == EM_ARM) {
    // FIXME: These warnings can be removed when lld only uses these features
    // when the input objects have been compiled with an architecture that
    // supports them.
    if (Config->ARMHasBlx == false)
      warn("lld uses blx instruction, no object with architecture supporting "
           "feature detected.");
    if (Config->ARMJ1J2BranchEncoding == false)
      warn("lld uses extended branch encoding, no object with architecture "
           "supporting feature detected.");
    if (Config->ARMHasMovtMovw == false)
      warn("lld may use movt/movw, no object with architecture supporting "
           "feature detected.");
  }

  // This adds a .comment section containing a version string. We have to add it
  // before decompressAndMergeSections because the .comment section is a
  // mergeable section.
  if (!Config->Relocatable)
    InputSections.push_back(createCommentSection());

  // Do size optimizations: garbage collection, merging of SHF_MERGE sections
  // and identical code folding.
  markLive<ELFT>();
  decompressSections();
  mergeSections();
  if (Config->ICF)
    doIcf<ELFT>();

  // Write the result to the file.
  writeResult<ELFT>();
}
