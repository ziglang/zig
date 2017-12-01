//===- Driver.cpp ---------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "Driver.h"
#include "Config.h"
#include "Error.h"
#include "InputFiles.h"
#include "Memory.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "Writer.h"
#include "lld/Driver/Driver.h"
#include "llvm/ADT/Optional.h"
#include "llvm/ADT/StringSwitch.h"
#include "llvm/BinaryFormat/Magic.h"
#include "llvm/Object/ArchiveWriter.h"
#include "llvm/Object/COFFImportFile.h"
#include "llvm/Object/COFFModuleDefinition.h"
#include "llvm/Option/Arg.h"
#include "llvm/Option/ArgList.h"
#include "llvm/Option/Option.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/Process.h"
#include "llvm/Support/TarWriter.h"
#include "llvm/Support/TargetSelect.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/ToolDrivers/llvm-lib/LibDriver.h"
#include <algorithm>
#include <memory>

#include <future>

using namespace llvm;
using namespace llvm::object;
using namespace llvm::COFF;
using llvm::sys::Process;

namespace lld {
namespace coff {

Configuration *Config;
LinkerDriver *Driver;

BumpPtrAllocator BAlloc;
StringSaver Saver{BAlloc};
std::vector<SpecificAllocBase *> SpecificAllocBase::Instances;

bool link(ArrayRef<const char *> Args, raw_ostream &Diag) {
  ErrorCount = 0;
  ErrorOS = &Diag;
  Config = make<Configuration>();
  Config->Argv = {Args.begin(), Args.end()};
  Config->ColorDiagnostics =
      (ErrorOS == &llvm::errs() && Process::StandardErrHasColors());
  Driver = make<LinkerDriver>();
  Driver->link(Args);
  return !ErrorCount;
}

// Drop directory components and replace extension with ".exe" or ".dll".
static std::string getOutputPath(StringRef Path) {
  auto P = Path.find_last_of("\\/");
  StringRef S = (P == StringRef::npos) ? Path : Path.substr(P + 1);
  const char* E = Config->DLL ? ".dll" : ".exe";
  return (S.substr(0, S.rfind('.')) + E).str();
}

// ErrorOr is not default constructible, so it cannot be used as the type
// parameter of a future.
// FIXME: We could open the file in createFutureForFile and avoid needing to
// return an error here, but for the moment that would cost us a file descriptor
// (a limited resource on Windows) for the duration that the future is pending.
typedef std::pair<std::unique_ptr<MemoryBuffer>, std::error_code> MBErrPair;

// Create a std::future that opens and maps a file using the best strategy for
// the host platform.
static std::future<MBErrPair> createFutureForFile(std::string Path) {
#if LLVM_ON_WIN32
  // On Windows, file I/O is relatively slow so it is best to do this
  // asynchronously.
  auto Strategy = std::launch::async;
#else
  auto Strategy = std::launch::deferred;
#endif
  return std::async(Strategy, [=]() {
    auto MBOrErr = MemoryBuffer::getFile(Path);
    if (!MBOrErr)
      return MBErrPair{nullptr, MBOrErr.getError()};
    return MBErrPair{std::move(*MBOrErr), std::error_code()};
  });
}

MemoryBufferRef LinkerDriver::takeBuffer(std::unique_ptr<MemoryBuffer> MB) {
  MemoryBufferRef MBRef = *MB;
  make<std::unique_ptr<MemoryBuffer>>(std::move(MB)); // take ownership

  if (Driver->Tar)
    Driver->Tar->append(relativeToRoot(MBRef.getBufferIdentifier()),
                        MBRef.getBuffer());
  return MBRef;
}

void LinkerDriver::addBuffer(std::unique_ptr<MemoryBuffer> MB) {
  MemoryBufferRef MBRef = takeBuffer(std::move(MB));

  // File type is detected by contents, not by file extension.
  file_magic Magic = identify_magic(MBRef.getBuffer());
  if (Magic == file_magic::windows_resource) {
    Resources.push_back(MBRef);
    return;
  }

  FilePaths.push_back(MBRef.getBufferIdentifier());
  if (Magic == file_magic::archive)
    return Symtab.addFile(make<ArchiveFile>(MBRef));
  if (Magic == file_magic::bitcode)
    return Symtab.addFile(make<BitcodeFile>(MBRef));

  if (Magic == file_magic::coff_cl_gl_object)
    error(MBRef.getBufferIdentifier() + ": is not a native COFF file. "
          "Recompile without /GL");
  else
    Symtab.addFile(make<ObjectFile>(MBRef));
}

void LinkerDriver::enqueuePath(StringRef Path) {
  auto Future =
      std::make_shared<std::future<MBErrPair>>(createFutureForFile(Path));
  std::string PathStr = Path;
  enqueueTask([=]() {
    auto MBOrErr = Future->get();
    if (MBOrErr.second)
      error("could not open " + PathStr + ": " + MBOrErr.second.message());
    else
      Driver->addBuffer(std::move(MBOrErr.first));
  });
}

void LinkerDriver::addArchiveBuffer(MemoryBufferRef MB, StringRef SymName,
                                    StringRef ParentName) {
  file_magic Magic = identify_magic(MB.getBuffer());
  if (Magic == file_magic::coff_import_library) {
    Symtab.addFile(make<ImportFile>(MB));
    return;
  }

  InputFile *Obj;
  if (Magic == file_magic::coff_object) {
    Obj = make<ObjectFile>(MB);
  } else if (Magic == file_magic::bitcode) {
    Obj = make<BitcodeFile>(MB);
  } else {
    error("unknown file type: " + MB.getBufferIdentifier());
    return;
  }

  Obj->ParentName = ParentName;
  Symtab.addFile(Obj);
  log("Loaded " + toString(Obj) + " for " + SymName);
}

void LinkerDriver::enqueueArchiveMember(const Archive::Child &C,
                                        StringRef SymName,
                                        StringRef ParentName) {
  if (!C.getParent()->isThin()) {
    MemoryBufferRef MB = check(
        C.getMemoryBufferRef(),
        "could not get the buffer for the member defining symbol " + SymName);
    enqueueTask([=]() { Driver->addArchiveBuffer(MB, SymName, ParentName); });
    return;
  }

  auto Future = std::make_shared<std::future<MBErrPair>>(createFutureForFile(
      check(C.getFullName(),
            "could not get the filename for the member defining symbol " +
                SymName)));
  enqueueTask([=]() {
    auto MBOrErr = Future->get();
    if (MBOrErr.second)
      fatal(MBOrErr.second,
            "could not get the buffer for the member defining " + SymName);
    Driver->addArchiveBuffer(takeBuffer(std::move(MBOrErr.first)), SymName,
                             ParentName);
  });
}

static bool isDecorated(StringRef Sym) {
  return Sym.startswith("_") || Sym.startswith("@") || Sym.startswith("?");
}

// Parses .drectve section contents and returns a list of files
// specified by /defaultlib.
void LinkerDriver::parseDirectives(StringRef S) {
  opt::InputArgList Args = Parser.parse(S);

  for (auto *Arg : Args) {
    switch (Arg->getOption().getID()) {
    case OPT_alternatename:
      parseAlternateName(Arg->getValue());
      break;
    case OPT_defaultlib:
      if (Optional<StringRef> Path = findLib(Arg->getValue()))
        enqueuePath(*Path);
      break;
    case OPT_export: {
      Export E = parseExport(Arg->getValue());
      E.Directives = true;
      Config->Exports.push_back(E);
      break;
    }
    case OPT_failifmismatch:
      checkFailIfMismatch(Arg->getValue());
      break;
    case OPT_incl:
      addUndefined(Arg->getValue());
      break;
    case OPT_merge:
      parseMerge(Arg->getValue());
      break;
    case OPT_nodefaultlib:
      Config->NoDefaultLibs.insert(doFindLib(Arg->getValue()));
      break;
    case OPT_section:
      parseSection(Arg->getValue());
      break;
    case OPT_editandcontinue:
    case OPT_fastfail:
    case OPT_guardsym:
    case OPT_throwingnew:
      break;
    default:
      error(Arg->getSpelling() + " is not allowed in .drectve");
    }
  }
}

// Find file from search paths. You can omit ".obj", this function takes
// care of that. Note that the returned path is not guaranteed to exist.
StringRef LinkerDriver::doFindFile(StringRef Filename) {
  bool HasPathSep = (Filename.find_first_of("/\\") != StringRef::npos);
  if (HasPathSep)
    return Filename;
  bool HasExt = (Filename.find('.') != StringRef::npos);
  for (StringRef Dir : SearchPaths) {
    SmallString<128> Path = Dir;
    sys::path::append(Path, Filename);
    if (sys::fs::exists(Path.str()))
      return Saver.save(Path.str());
    if (!HasExt) {
      Path.append(".obj");
      if (sys::fs::exists(Path.str()))
        return Saver.save(Path.str());
    }
  }
  return Filename;
}

// Resolves a file path. This never returns the same path
// (in that case, it returns None).
Optional<StringRef> LinkerDriver::findFile(StringRef Filename) {
  StringRef Path = doFindFile(Filename);
  bool Seen = !VisitedFiles.insert(Path.lower()).second;
  if (Seen)
    return None;
  return Path;
}

// Find library file from search path.
StringRef LinkerDriver::doFindLib(StringRef Filename) {
  // Add ".lib" to Filename if that has no file extension.
  bool HasExt = (Filename.find('.') != StringRef::npos);
  if (!HasExt)
    Filename = Saver.save(Filename + ".lib");
  return doFindFile(Filename);
}

// Resolves a library path. /nodefaultlib options are taken into
// consideration. This never returns the same path (in that case,
// it returns None).
Optional<StringRef> LinkerDriver::findLib(StringRef Filename) {
  if (Config->NoDefaultLibAll)
    return None;
  if (!VisitedLibs.insert(Filename.lower()).second)
    return None;
  StringRef Path = doFindLib(Filename);
  if (Config->NoDefaultLibs.count(Path))
    return None;
  if (!VisitedFiles.insert(Path.lower()).second)
    return None;
  return Path;
}

// Parses LIB environment which contains a list of search paths.
void LinkerDriver::addLibSearchPaths() {
  Optional<std::string> EnvOpt = Process::GetEnv("LIB");
  if (!EnvOpt.hasValue())
    return;
  StringRef Env = Saver.save(*EnvOpt);
  while (!Env.empty()) {
    StringRef Path;
    std::tie(Path, Env) = Env.split(';');
    SearchPaths.push_back(Path);
  }
}

SymbolBody *LinkerDriver::addUndefined(StringRef Name) {
  SymbolBody *B = Symtab.addUndefined(Name);
  Config->GCRoot.insert(B);
  return B;
}

// Symbol names are mangled by appending "_" prefix on x86.
StringRef LinkerDriver::mangle(StringRef Sym) {
  assert(Config->Machine != IMAGE_FILE_MACHINE_UNKNOWN);
  if (Config->Machine == I386)
    return Saver.save("_" + Sym);
  return Sym;
}

// Windows specific -- find default entry point name.
StringRef LinkerDriver::findDefaultEntry() {
  // User-defined main functions and their corresponding entry points.
  static const char *Entries[][2] = {
      {"main", "mainCRTStartup"},
      {"wmain", "wmainCRTStartup"},
      {"WinMain", "WinMainCRTStartup"},
      {"wWinMain", "wWinMainCRTStartup"},
  };
  for (auto E : Entries) {
    StringRef Entry = Symtab.findMangle(mangle(E[0]));
    if (!Entry.empty() && !isa<Undefined>(Symtab.find(Entry)->body()))
      return mangle(E[1]);
  }
  return "";
}

WindowsSubsystem LinkerDriver::inferSubsystem() {
  if (Config->DLL)
    return IMAGE_SUBSYSTEM_WINDOWS_GUI;
  if (Symtab.findUnderscore("main") || Symtab.findUnderscore("wmain"))
    return IMAGE_SUBSYSTEM_WINDOWS_CUI;
  if (Symtab.findUnderscore("WinMain") || Symtab.findUnderscore("wWinMain"))
    return IMAGE_SUBSYSTEM_WINDOWS_GUI;
  return IMAGE_SUBSYSTEM_UNKNOWN;
}

static uint64_t getDefaultImageBase() {
  if (Config->is64())
    return Config->DLL ? 0x180000000 : 0x140000000;
  return Config->DLL ? 0x10000000 : 0x400000;
}

static std::string createResponseFile(const opt::InputArgList &Args,
                                      ArrayRef<StringRef> FilePaths,
                                      ArrayRef<StringRef> SearchPaths) {
  SmallString<0> Data;
  raw_svector_ostream OS(Data);

  for (auto *Arg : Args) {
    switch (Arg->getOption().getID()) {
    case OPT_linkrepro:
    case OPT_INPUT:
    case OPT_defaultlib:
    case OPT_libpath:
      break;
    default:
      OS << toString(Arg) << "\n";
    }
  }

  for (StringRef Path : SearchPaths) {
    std::string RelPath = relativeToRoot(Path);
    OS << "/libpath:" << quote(RelPath) << "\n";
  }

  for (StringRef Path : FilePaths)
    OS << quote(relativeToRoot(Path)) << "\n";

  return Data.str();
}

static unsigned getDefaultDebugType(const opt::InputArgList &Args) {
  unsigned DebugTypes = static_cast<unsigned>(DebugType::CV);
  if (Args.hasArg(OPT_driver))
    DebugTypes |= static_cast<unsigned>(DebugType::PData);
  if (Args.hasArg(OPT_profile))
    DebugTypes |= static_cast<unsigned>(DebugType::Fixup);
  return DebugTypes;
}

static unsigned parseDebugType(StringRef Arg) {
  SmallVector<StringRef, 3> Types;
  Arg.split(Types, ',', /*KeepEmpty=*/false);

  unsigned DebugTypes = static_cast<unsigned>(DebugType::None);
  for (StringRef Type : Types)
    DebugTypes |= StringSwitch<unsigned>(Type.lower())
                      .Case("cv", static_cast<unsigned>(DebugType::CV))
                      .Case("pdata", static_cast<unsigned>(DebugType::PData))
                      .Case("fixup", static_cast<unsigned>(DebugType::Fixup))
                      .Default(0);
  return DebugTypes;
}

static std::string getMapFile(const opt::InputArgList &Args) {
  auto *Arg = Args.getLastArg(OPT_lldmap, OPT_lldmap_file);
  if (!Arg)
    return "";
  if (Arg->getOption().getID() == OPT_lldmap_file)
    return Arg->getValue();

  assert(Arg->getOption().getID() == OPT_lldmap);
  StringRef OutFile = Config->OutputFile;
  return (OutFile.substr(0, OutFile.rfind('.')) + ".map").str();
}

static std::string getImplibPath() {
  if (!Config->Implib.empty())
    return Config->Implib;
  SmallString<128> Out = StringRef(Config->OutputFile);
  sys::path::replace_extension(Out, ".lib");
  return Out.str();
}

//
// The import name is caculated as the following:
//
//        | LIBRARY w/ ext |   LIBRARY w/o ext   | no LIBRARY
//   -----+----------------+---------------------+------------------
//   LINK | {value}        | {value}.{.dll/.exe} | {output name}
//    LIB | {value}        | {value}.dll         | {output name}.dll
//
static std::string getImportName(bool AsLib) {
  SmallString<128> Out;

  if (Config->ImportName.empty()) {
    Out.assign(sys::path::filename(Config->OutputFile));
    if (AsLib)
      sys::path::replace_extension(Out, ".dll");
  } else {
    Out.assign(Config->ImportName);
    if (!sys::path::has_extension(Out))
      sys::path::replace_extension(Out,
                                   (Config->DLL || AsLib) ? ".dll" : ".exe");
  }

  return Out.str();
}

static void createImportLibrary(bool AsLib) {
  std::vector<COFFShortExport> Exports;
  for (Export &E1 : Config->Exports) {
    COFFShortExport E2;
    E2.Name = E1.Name;
    E2.SymbolName = E1.SymbolName;
    E2.ExtName = E1.ExtName;
    E2.Ordinal = E1.Ordinal;
    E2.Noname = E1.Noname;
    E2.Data = E1.Data;
    E2.Private = E1.Private;
    E2.Constant = E1.Constant;
    Exports.push_back(E2);
  }

  writeImportLibrary(getImportName(AsLib), getImplibPath(), Exports,
                     Config->Machine, false);
}

static void parseModuleDefs(StringRef Path) {
  std::unique_ptr<MemoryBuffer> MB = check(
    MemoryBuffer::getFile(Path, -1, false, true), "could not open " + Path);
  COFFModuleDefinition M =
      check(parseCOFFModuleDefinition(MB->getMemBufferRef(), Config->Machine));

  if (Config->OutputFile.empty())
    Config->OutputFile = Saver.save(M.OutputFile);
  Config->ImportName = Saver.save(M.ImportName);
  if (M.ImageBase)
    Config->ImageBase = M.ImageBase;
  if (M.StackReserve)
    Config->StackReserve = M.StackReserve;
  if (M.StackCommit)
    Config->StackCommit = M.StackCommit;
  if (M.HeapReserve)
    Config->HeapReserve = M.HeapReserve;
  if (M.HeapCommit)
    Config->HeapCommit = M.HeapCommit;
  if (M.MajorImageVersion)
    Config->MajorImageVersion = M.MajorImageVersion;
  if (M.MinorImageVersion)
    Config->MinorImageVersion = M.MinorImageVersion;
  if (M.MajorOSVersion)
    Config->MajorOSVersion = M.MajorOSVersion;
  if (M.MinorOSVersion)
    Config->MinorOSVersion = M.MinorOSVersion;

  for (COFFShortExport E1 : M.Exports) {
    Export E2;
    E2.Name = Saver.save(E1.Name);
    if (E1.isWeak())
      E2.ExtName = Saver.save(E1.ExtName);
    E2.Ordinal = E1.Ordinal;
    E2.Noname = E1.Noname;
    E2.Data = E1.Data;
    E2.Private = E1.Private;
    E2.Constant = E1.Constant;
    Config->Exports.push_back(E2);
  }
}

std::vector<MemoryBufferRef> getArchiveMembers(Archive *File) {
  std::vector<MemoryBufferRef> V;
  Error Err = Error::success();
  for (const ErrorOr<Archive::Child> &COrErr : File->children(Err)) {
    Archive::Child C =
        check(COrErr,
              File->getFileName() + ": could not get the child of the archive");
    MemoryBufferRef MBRef =
        check(C.getMemoryBufferRef(),
              File->getFileName() +
                  ": could not get the buffer for a child of the archive");
    V.push_back(MBRef);
  }
  if (Err)
    fatal(File->getFileName() +
          ": Archive::children failed: " + toString(std::move(Err)));
  return V;
}

// A helper function for filterBitcodeFiles.
static bool needsRebuilding(MemoryBufferRef MB) {
  // The MSVC linker doesn't support thin archives, so if it's a thin
  // archive, we always need to rebuild it.
  std::unique_ptr<Archive> File =
      check(Archive::create(MB), "Failed to read " + MB.getBufferIdentifier());
  if (File->isThin())
    return true;

  // Returns true if the archive contains at least one bitcode file.
  for (MemoryBufferRef Member : getArchiveMembers(File.get()))
    if (identify_magic(Member.getBuffer()) == file_magic::bitcode)
      return true;
  return false;
}

// Opens a given path as an archive file and removes bitcode files
// from them if exists. This function is to appease the MSVC linker as
// their linker doesn't like archive files containing non-native
// object files.
//
// If a given archive doesn't contain bitcode files, the archive path
// is returned as-is. Otherwise, a new temporary file is created and
// its path is returned.
static Optional<std::string>
filterBitcodeFiles(StringRef Path, std::vector<std::string> &TemporaryFiles) {
  std::unique_ptr<MemoryBuffer> MB = check(
      MemoryBuffer::getFile(Path, -1, false, true), "could not open " + Path);
  MemoryBufferRef MBRef = MB->getMemBufferRef();
  file_magic Magic = identify_magic(MBRef.getBuffer());

  if (Magic == file_magic::bitcode)
    return None;
  if (Magic != file_magic::archive)
    return Path.str();
  if (!needsRebuilding(MBRef))
    return Path.str();

  std::unique_ptr<Archive> File =
      check(Archive::create(MBRef),
            MBRef.getBufferIdentifier() + ": failed to parse archive");

  std::vector<NewArchiveMember> New;
  for (MemoryBufferRef Member : getArchiveMembers(File.get()))
    if (identify_magic(Member.getBuffer()) != file_magic::bitcode)
      New.emplace_back(Member);

  if (New.empty())
    return None;

  log("Creating a temporary archive for " + Path + " to remove bitcode files");

  SmallString<128> S;
  if (auto EC = sys::fs::createTemporaryFile("lld-" + sys::path::stem(Path),
                                             ".lib", S))
    fatal(EC, "cannot create a temporary file");
  std::string Temp = S.str();
  TemporaryFiles.push_back(Temp);

  std::pair<StringRef, std::error_code> Ret =
      llvm::writeArchive(Temp, New, /*WriteSymtab=*/true, Archive::Kind::K_GNU,
                         /*Deterministics=*/true,
                         /*Thin=*/false);
  if (Ret.second)
    error("failed to create a new archive " + S.str() + ": " + Ret.first);
  return Temp;
}

// Create response file contents and invoke the MSVC linker.
void LinkerDriver::invokeMSVC(opt::InputArgList &Args) {
  std::string Rsp = "/nologo\n";
  std::vector<std::string> Temps;

  // Write out archive members that we used in symbol resolution and pass these
  // to MSVC before any archives, so that MSVC uses the same objects to satisfy
  // references.
  for (const auto *O : Symtab.ObjectFiles) {
    if (O->ParentName.empty())
      continue;
    SmallString<128> S;
    int Fd;
    if (auto EC = sys::fs::createTemporaryFile(
            "lld-" + sys::path::filename(O->ParentName), ".obj", Fd, S))
      fatal(EC, "cannot create a temporary file");
    raw_fd_ostream OS(Fd, /*shouldClose*/ true);
    OS << O->MB.getBuffer();
    Temps.push_back(S.str());
    Rsp += quote(S) + "\n";
  }

  for (auto *Arg : Args) {
    switch (Arg->getOption().getID()) {
    case OPT_linkrepro:
    case OPT_lldmap:
    case OPT_lldmap_file:
    case OPT_lldsavetemps:
    case OPT_msvclto:
      // LLD-specific options are stripped.
      break;
    case OPT_opt:
      if (!StringRef(Arg->getValue()).startswith("lld"))
        Rsp += toString(Arg) + " ";
      break;
    case OPT_INPUT: {
      if (Optional<StringRef> Path = doFindFile(Arg->getValue())) {
        if (Optional<std::string> S = filterBitcodeFiles(*Path, Temps))
          Rsp += quote(*S) + "\n";
        continue;
      }
      Rsp += quote(Arg->getValue()) + "\n";
      break;
    }
    default:
      Rsp += toString(Arg) + "\n";
    }
  }

  std::vector<StringRef> ObjectFiles = Symtab.compileBitcodeFiles();
  runMSVCLinker(Rsp, ObjectFiles);

  for (StringRef Path : Temps)
    sys::fs::remove(Path);
}

void LinkerDriver::enqueueTask(std::function<void()> Task) {
  TaskQueue.push_back(std::move(Task));
}

bool LinkerDriver::run() {
  bool DidWork = !TaskQueue.empty();
  while (!TaskQueue.empty()) {
    TaskQueue.front()();
    TaskQueue.pop_front();
  }
  return DidWork;
}

void LinkerDriver::link(ArrayRef<const char *> ArgsArr) {
  // If the first command line argument is "/lib", link.exe acts like lib.exe.
  // We call our own implementation of lib.exe that understands bitcode files.
  if (ArgsArr.size() > 1 && StringRef(ArgsArr[1]).equals_lower("/lib")) {
    if (llvm::libDriverMain(ArgsArr.slice(1)) != 0)
      fatal("lib failed");
    return;
  }

  // Needed for LTO.
  InitializeAllTargetInfos();
  InitializeAllTargets();
  InitializeAllTargetMCs();
  InitializeAllAsmParsers();
  InitializeAllAsmPrinters();
  InitializeAllDisassemblers();

  // Parse command line options.
  opt::InputArgList Args = Parser.parseLINK(ArgsArr.slice(1));

  // Parse and evaluate -mllvm options.
  std::vector<const char *> V;
  V.push_back("lld-link (LLVM option parsing)");
  for (auto *Arg : Args.filtered(OPT_mllvm))
    V.push_back(Arg->getValue());
  cl::ParseCommandLineOptions(V.size(), V.data());

  // Handle /errorlimit early, because error() depends on it.
  if (auto *Arg = Args.getLastArg(OPT_errorlimit)) {
    int N = 20;
    StringRef S = Arg->getValue();
    if (S.getAsInteger(10, N))
      error(Arg->getSpelling() + " number expected, but got " + S);
    Config->ErrorLimit = N;
  }

  // Handle /help
  if (Args.hasArg(OPT_help)) {
    printHelp(ArgsArr[0]);
    return;
  }

  if (auto *Arg = Args.getLastArg(OPT_linkrepro)) {
    SmallString<64> Path = StringRef(Arg->getValue());
    sys::path::append(Path, "repro.tar");

    Expected<std::unique_ptr<TarWriter>> ErrOrWriter =
        TarWriter::create(Path, "repro");

    if (ErrOrWriter) {
      Tar = std::move(*ErrOrWriter);
    } else {
      error("/linkrepro: failed to open " + Path + ": " +
            toString(ErrOrWriter.takeError()));
    }
  }

  if (!Args.hasArgNoClaim(OPT_INPUT)) {
    if (Args.hasArgNoClaim(OPT_deffile))
      Config->NoEntry = true;
    else
      fatal("no input files");
  }

  // Construct search path list.
  SearchPaths.push_back("");
  for (auto *Arg : Args.filtered(OPT_libpath))
    SearchPaths.push_back(Arg->getValue());
  addLibSearchPaths();

  // Handle /out
  if (auto *Arg = Args.getLastArg(OPT_out))
    Config->OutputFile = Arg->getValue();

  // Handle /verbose
  if (Args.hasArg(OPT_verbose))
    Config->Verbose = true;

  // Handle /force or /force:unresolved
  if (Args.hasArg(OPT_force) || Args.hasArg(OPT_force_unresolved))
    Config->Force = true;

  // Handle /debug
  if (Args.hasArg(OPT_debug)) {
    Config->Debug = true;
    Config->DebugTypes =
        Args.hasArg(OPT_debugtype)
            ? parseDebugType(Args.getLastArg(OPT_debugtype)->getValue())
            : getDefaultDebugType(Args);
  }

  // Create a dummy PDB file to satisfy build sytem rules.
  if (auto *Arg = Args.getLastArg(OPT_pdb))
    Config->PDBPath = Arg->getValue();

  // Handle /noentry
  if (Args.hasArg(OPT_noentry)) {
    if (Args.hasArg(OPT_dll))
      Config->NoEntry = true;
    else
      error("/noentry must be specified with /dll");
  }

  // Handle /dll
  if (Args.hasArg(OPT_dll)) {
    Config->DLL = true;
    Config->ManifestID = 2;
  }

  // Handle /fixed
  if (Args.hasArg(OPT_fixed)) {
    if (Args.hasArg(OPT_dynamicbase)) {
      error("/fixed must not be specified with /dynamicbase");
    } else {
      Config->Relocatable = false;
      Config->DynamicBase = false;
    }
  }

  if (Args.hasArg(OPT_appcontainer))
    Config->AppContainer = true;

  // Handle /machine
  if (auto *Arg = Args.getLastArg(OPT_machine))
    Config->Machine = getMachineType(Arg->getValue());

  // Handle /nodefaultlib:<filename>
  for (auto *Arg : Args.filtered(OPT_nodefaultlib))
    Config->NoDefaultLibs.insert(doFindLib(Arg->getValue()));

  // Handle /nodefaultlib
  if (Args.hasArg(OPT_nodefaultlib_all))
    Config->NoDefaultLibAll = true;

  // Handle /base
  if (auto *Arg = Args.getLastArg(OPT_base))
    parseNumbers(Arg->getValue(), &Config->ImageBase);

  // Handle /stack
  if (auto *Arg = Args.getLastArg(OPT_stack))
    parseNumbers(Arg->getValue(), &Config->StackReserve, &Config->StackCommit);

  // Handle /heap
  if (auto *Arg = Args.getLastArg(OPT_heap))
    parseNumbers(Arg->getValue(), &Config->HeapReserve, &Config->HeapCommit);

  // Handle /version
  if (auto *Arg = Args.getLastArg(OPT_version))
    parseVersion(Arg->getValue(), &Config->MajorImageVersion,
                 &Config->MinorImageVersion);

  // Handle /subsystem
  if (auto *Arg = Args.getLastArg(OPT_subsystem))
    parseSubsystem(Arg->getValue(), &Config->Subsystem, &Config->MajorOSVersion,
                   &Config->MinorOSVersion);

  // Handle /alternatename
  for (auto *Arg : Args.filtered(OPT_alternatename))
    parseAlternateName(Arg->getValue());

  // Handle /include
  for (auto *Arg : Args.filtered(OPT_incl))
    addUndefined(Arg->getValue());

  // Handle /implib
  if (auto *Arg = Args.getLastArg(OPT_implib))
    Config->Implib = Arg->getValue();

  // Handle /opt
  for (auto *Arg : Args.filtered(OPT_opt)) {
    std::string Str = StringRef(Arg->getValue()).lower();
    SmallVector<StringRef, 1> Vec;
    StringRef(Str).split(Vec, ',');
    for (StringRef S : Vec) {
      if (S == "noref") {
        Config->DoGC = false;
        Config->DoICF = false;
        continue;
      }
      if (S == "icf" || StringRef(S).startswith("icf=")) {
        Config->DoICF = true;
        continue;
      }
      if (S == "noicf") {
        Config->DoICF = false;
        continue;
      }
      if (StringRef(S).startswith("lldlto=")) {
        StringRef OptLevel = StringRef(S).substr(7);
        if (OptLevel.getAsInteger(10, Config->LTOOptLevel) ||
            Config->LTOOptLevel > 3)
          error("/opt:lldlto: invalid optimization level: " + OptLevel);
        continue;
      }
      if (StringRef(S).startswith("lldltojobs=")) {
        StringRef Jobs = StringRef(S).substr(11);
        if (Jobs.getAsInteger(10, Config->LTOJobs) || Config->LTOJobs == 0)
          error("/opt:lldltojobs: invalid job count: " + Jobs);
        continue;
      }
      if (StringRef(S).startswith("lldltopartitions=")) {
        StringRef N = StringRef(S).substr(17);
        if (N.getAsInteger(10, Config->LTOPartitions) ||
            Config->LTOPartitions == 0)
          error("/opt:lldltopartitions: invalid partition count: " + N);
        continue;
      }
      if (S != "ref" && S != "lbr" && S != "nolbr")
        error("/opt: unknown option: " + S);
    }
  }

  // Handle /lldsavetemps
  if (Args.hasArg(OPT_lldsavetemps))
    Config->SaveTemps = true;

  // Handle /failifmismatch
  for (auto *Arg : Args.filtered(OPT_failifmismatch))
    checkFailIfMismatch(Arg->getValue());

  // Handle /merge
  for (auto *Arg : Args.filtered(OPT_merge))
    parseMerge(Arg->getValue());

  // Handle /section
  for (auto *Arg : Args.filtered(OPT_section))
    parseSection(Arg->getValue());

  // Handle /manifestdependency. This enables /manifest unless /manifest:no is
  // also passed.
  if (auto *Arg = Args.getLastArg(OPT_manifestdependency)) {
    Config->ManifestDependency = Arg->getValue();
    Config->Manifest = Configuration::SideBySide;
  }

  // Handle /manifest and /manifest:
  if (auto *Arg = Args.getLastArg(OPT_manifest, OPT_manifest_colon)) {
    if (Arg->getOption().getID() == OPT_manifest)
      Config->Manifest = Configuration::SideBySide;
    else
      parseManifest(Arg->getValue());
  }

  // Handle /manifestuac
  if (auto *Arg = Args.getLastArg(OPT_manifestuac))
    parseManifestUAC(Arg->getValue());

  // Handle /manifestfile
  if (auto *Arg = Args.getLastArg(OPT_manifestfile))
    Config->ManifestFile = Arg->getValue();

  // Handle /manifestinput
  for (auto *Arg : Args.filtered(OPT_manifestinput))
    Config->ManifestInput.push_back(Arg->getValue());

  if (!Config->ManifestInput.empty() &&
      Config->Manifest != Configuration::Embed) {
    fatal("/MANIFESTINPUT: requires /MANIFEST:EMBED");
  }

  // Handle miscellaneous boolean flags.
  if (Args.hasArg(OPT_allowisolation_no))
    Config->AllowIsolation = false;
  if (Args.hasArg(OPT_dynamicbase_no))
    Config->DynamicBase = false;
  if (Args.hasArg(OPT_nxcompat_no))
    Config->NxCompat = false;
  if (Args.hasArg(OPT_tsaware_no))
    Config->TerminalServerAware = false;
  if (Args.hasArg(OPT_nosymtab))
    Config->WriteSymtab = false;

  Config->MapFile = getMapFile(Args);

  if (ErrorCount)
    return;

  // Create a list of input files. Files can be given as arguments
  // for /defaultlib option.
  std::vector<MemoryBufferRef> MBs;
  for (auto *Arg : Args.filtered(OPT_INPUT))
    if (Optional<StringRef> Path = findFile(Arg->getValue()))
      enqueuePath(*Path);
  for (auto *Arg : Args.filtered(OPT_defaultlib))
    if (Optional<StringRef> Path = findLib(Arg->getValue()))
      enqueuePath(*Path);

  // Windows specific -- Create a resource file containing a manifest file.
  if (Config->Manifest == Configuration::Embed)
    addBuffer(createManifestRes());

  // Read all input files given via the command line.
  run();

  // We should have inferred a machine type by now from the input files, but if
  // not we assume x64.
  if (Config->Machine == IMAGE_FILE_MACHINE_UNKNOWN) {
    warn("/machine is not specified. x64 is assumed");
    Config->Machine = AMD64;
  }

  // Input files can be Windows resource files (.res files). We use
  // WindowsResource to convert resource files to a regular COFF file,
  // then link the resulting file normally.
  if (!Resources.empty())
    addBuffer(convertResToCOFF(Resources));

  if (Tar)
    Tar->append("response.txt",
                createResponseFile(Args, FilePaths,
                                   ArrayRef<StringRef>(SearchPaths).slice(1)));

  // Handle /largeaddressaware
  if (Config->is64() || Args.hasArg(OPT_largeaddressaware))
    Config->LargeAddressAware = true;

  // Handle /highentropyva
  if (Config->is64() && !Args.hasArg(OPT_highentropyva_no))
    Config->HighEntropyVA = true;

  // Handle /entry and /dll
  if (auto *Arg = Args.getLastArg(OPT_entry)) {
    Config->Entry = addUndefined(mangle(Arg->getValue()));
  } else if (Args.hasArg(OPT_dll) && !Config->NoEntry) {
    StringRef S = (Config->Machine == I386) ? "__DllMainCRTStartup@12"
                                            : "_DllMainCRTStartup";
    Config->Entry = addUndefined(S);
  } else if (!Config->NoEntry) {
    // Windows specific -- If entry point name is not given, we need to
    // infer that from user-defined entry name.
    StringRef S = findDefaultEntry();
    if (S.empty())
      fatal("entry point must be defined");
    Config->Entry = addUndefined(S);
    log("Entry name inferred: " + S);
  }

  // Handle /export
  for (auto *Arg : Args.filtered(OPT_export)) {
    Export E = parseExport(Arg->getValue());
    if (Config->Machine == I386) {
      if (!isDecorated(E.Name))
        E.Name = Saver.save("_" + E.Name);
      if (!E.ExtName.empty() && !isDecorated(E.ExtName))
        E.ExtName = Saver.save("_" + E.ExtName);
    }
    Config->Exports.push_back(E);
  }

  // Handle /def
  if (auto *Arg = Args.getLastArg(OPT_deffile)) {
    // parseModuleDefs mutates Config object.
    parseModuleDefs(Arg->getValue());
  }

  // Handle generation of import library from a def file.
  if (!Args.hasArgNoClaim(OPT_INPUT)) {
    fixupExports();
    createImportLibrary(/*AsLib=*/true);
    exit(0);
  }

  // Handle /delayload
  for (auto *Arg : Args.filtered(OPT_delayload)) {
    Config->DelayLoads.insert(StringRef(Arg->getValue()).lower());
    if (Config->Machine == I386) {
      Config->DelayLoadHelper = addUndefined("___delayLoadHelper2@8");
    } else {
      Config->DelayLoadHelper = addUndefined("__delayLoadHelper2");
    }
  }

  // Set default image name if neither /out or /def set it.
  if (Config->OutputFile.empty()) {
    Config->OutputFile =
        getOutputPath((*Args.filtered(OPT_INPUT).begin())->getValue());
  }

  // Put the PDB next to the image if no /pdb flag was passed.
  if (Config->Debug && Config->PDBPath.empty()) {
    Config->PDBPath = Config->OutputFile;
    sys::path::replace_extension(Config->PDBPath, ".pdb");
  }

  // Disable PDB generation if the user requested it.
  if (Args.hasArg(OPT_nopdb))
    Config->PDBPath = "";

  // Set default image base if /base is not given.
  if (Config->ImageBase == uint64_t(-1))
    Config->ImageBase = getDefaultImageBase();

  Symtab.addSynthetic(mangle("__ImageBase"), nullptr);
  if (Config->Machine == I386) {
    Symtab.addAbsolute("___safe_se_handler_table", 0);
    Symtab.addAbsolute("___safe_se_handler_count", 0);
  }

  // We do not support /guard:cf (control flow protection) yet.
  // Define CFG symbols anyway so that we can link MSVC 2015 CRT.
  Symtab.addAbsolute(mangle("__guard_fids_count"), 0);
  Symtab.addAbsolute(mangle("__guard_fids_table"), 0);
  Symtab.addAbsolute(mangle("__guard_flags"), 0x100);
  Symtab.addAbsolute(mangle("__guard_iat_count"), 0);
  Symtab.addAbsolute(mangle("__guard_iat_table"), 0);
  Symtab.addAbsolute(mangle("__guard_longjmp_count"), 0);
  Symtab.addAbsolute(mangle("__guard_longjmp_table"), 0);

  // This code may add new undefined symbols to the link, which may enqueue more
  // symbol resolution tasks, so we need to continue executing tasks until we
  // converge.
  do {
    // Windows specific -- if entry point is not found,
    // search for its mangled names.
    if (Config->Entry)
      Symtab.mangleMaybe(Config->Entry);

    // Windows specific -- Make sure we resolve all dllexported symbols.
    for (Export &E : Config->Exports) {
      if (!E.ForwardTo.empty())
        continue;
      E.Sym = addUndefined(E.Name);
      if (!E.Directives)
        Symtab.mangleMaybe(E.Sym);
    }

    // Add weak aliases. Weak aliases is a mechanism to give remaining
    // undefined symbols final chance to be resolved successfully.
    for (auto Pair : Config->AlternateNames) {
      StringRef From = Pair.first;
      StringRef To = Pair.second;
      Symbol *Sym = Symtab.find(From);
      if (!Sym)
        continue;
      if (auto *U = dyn_cast<Undefined>(Sym->body()))
        if (!U->WeakAlias)
          U->WeakAlias = Symtab.addUndefined(To);
    }

    // Windows specific -- if __load_config_used can be resolved, resolve it.
    if (Symtab.findUnderscore("_load_config_used"))
      addUndefined(mangle("_load_config_used"));
  } while (run());

  if (ErrorCount)
    return;

  // If /msvclto is given, we use the MSVC linker to link LTO output files.
  // This is useful because MSVC link.exe can generate complete PDBs.
  if (Args.hasArg(OPT_msvclto)) {
    invokeMSVC(Args);
    exit(0);
  }

  // Do LTO by compiling bitcode input files to a set of native COFF files then
  // link those files.
  Symtab.addCombinedLTOObjects();
  run();

  // Make sure we have resolved all symbols.
  Symtab.reportRemainingUndefines();

  // Windows specific -- if no /subsystem is given, we need to infer
  // that from entry point name.
  if (Config->Subsystem == IMAGE_SUBSYSTEM_UNKNOWN) {
    Config->Subsystem = inferSubsystem();
    if (Config->Subsystem == IMAGE_SUBSYSTEM_UNKNOWN)
      fatal("subsystem must be defined");
  }

  // Handle /safeseh.
  if (Args.hasArg(OPT_safeseh)) {
    for (ObjectFile *File : Symtab.ObjectFiles)
      if (!File->SEHCompat)
        error("/safeseh: " + File->getName() + " is not compatible with SEH");
    if (ErrorCount)
      return;
  }

  // Windows specific -- when we are creating a .dll file, we also
  // need to create a .lib file.
  if (!Config->Exports.empty() || Config->DLL) {
    fixupExports();
    createImportLibrary(/*AsLib=*/false);
    assignExportOrdinals();
  }

  // Windows specific -- Create a side-by-side manifest file.
  if (Config->Manifest == Configuration::SideBySide)
    createSideBySideManifest();

  // Identify unreferenced COMDAT sections.
  if (Config->DoGC)
    markLive(Symtab.getChunks());

  // Identify identical COMDAT sections to merge them.
  if (Config->DoICF)
    doICF(Symtab.getChunks());

  // Write the result.
  writeResult(&Symtab);

  // Call exit to avoid calling destructors.
  exit(0);
}

} // namespace coff
} // namespace lld
