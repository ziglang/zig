//===- Driver.cpp ---------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "Driver.h"
#include "Config.h"
#include "DebugTypes.h"
#include "ICF.h"
#include "InputFiles.h"
#include "MarkLive.h"
#include "MinGW.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "Writer.h"
#include "lld/Common/Args.h"
#include "lld/Common/Driver.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Filesystem.h"
#include "lld/Common/Memory.h"
#include "lld/Common/Threads.h"
#include "lld/Common/Timer.h"
#include "lld/Common/Version.h"
#include "llvm/ADT/Optional.h"
#include "llvm/ADT/StringSwitch.h"
#include "llvm/BinaryFormat/Magic.h"
#include "llvm/Object/ArchiveWriter.h"
#include "llvm/Object/COFFImportFile.h"
#include "llvm/Object/COFFModuleDefinition.h"
#include "llvm/Object/WindowsMachineFlag.h"
#include "llvm/Option/Arg.h"
#include "llvm/Option/ArgList.h"
#include "llvm/Option/Option.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/LEB128.h"
#include "llvm/Support/MathExtras.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/Process.h"
#include "llvm/Support/TarWriter.h"
#include "llvm/Support/TargetSelect.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/ToolDrivers/llvm-lib/LibDriver.h"
#include <algorithm>
#include <future>
#include <memory>

using namespace llvm;
using namespace llvm::object;
using namespace llvm::COFF;
using llvm::sys::Process;

namespace lld {
namespace coff {

static Timer inputFileTimer("Input File Reading", Timer::root());

Configuration *config;
LinkerDriver *driver;

bool link(ArrayRef<const char *> args, bool canExitEarly, raw_ostream &diag) {
  errorHandler().logName = args::getFilenameWithoutExe(args[0]);
  errorHandler().errorOS = &diag;
  errorHandler().colorDiagnostics = diag.has_colors();
  errorHandler().errorLimitExceededMsg =
      "too many errors emitted, stopping now"
      " (use /errorlimit:0 to see all errors)";
  errorHandler().exitEarly = canExitEarly;
  config = make<Configuration>();

  symtab = make<SymbolTable>();

  driver = make<LinkerDriver>();
  driver->link(args);

  // Call exit() if we can to avoid calling destructors.
  if (canExitEarly)
    exitLld(errorCount() ? 1 : 0);

  freeArena();
  ObjFile::instances.clear();
  ImportFile::instances.clear();
  BitcodeFile::instances.clear();
  memset(MergeChunk::instances, 0, sizeof(MergeChunk::instances));
  return !errorCount();
}

// Parse options of the form "old;new".
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

// Drop directory components and replace extension with ".exe" or ".dll".
static std::string getOutputPath(StringRef path) {
  auto p = path.find_last_of("\\/");
  StringRef s = (p == StringRef::npos) ? path : path.substr(p + 1);
  const char* e = config->dll ? ".dll" : ".exe";
  return (s.substr(0, s.rfind('.')) + e).str();
}

// Returns true if S matches /crtend.?\.o$/.
static bool isCrtend(StringRef s) {
  if (!s.endswith(".o"))
    return false;
  s = s.drop_back(2);
  if (s.endswith("crtend"))
    return true;
  return !s.empty() && s.drop_back().endswith("crtend");
}

// ErrorOr is not default constructible, so it cannot be used as the type
// parameter of a future.
// FIXME: We could open the file in createFutureForFile and avoid needing to
// return an error here, but for the moment that would cost us a file descriptor
// (a limited resource on Windows) for the duration that the future is pending.
using MBErrPair = std::pair<std::unique_ptr<MemoryBuffer>, std::error_code>;

// Create a std::future that opens and maps a file using the best strategy for
// the host platform.
static std::future<MBErrPair> createFutureForFile(std::string path) {
#if _WIN32
  // On Windows, file I/O is relatively slow so it is best to do this
  // asynchronously.
  auto strategy = std::launch::async;
#else
  auto strategy = std::launch::deferred;
#endif
  return std::async(strategy, [=]() {
    auto mbOrErr = MemoryBuffer::getFile(path,
                                         /*FileSize*/ -1,
                                         /*RequiresNullTerminator*/ false);
    if (!mbOrErr)
      return MBErrPair{nullptr, mbOrErr.getError()};
    return MBErrPair{std::move(*mbOrErr), std::error_code()};
  });
}

// Symbol names are mangled by prepending "_" on x86.
static StringRef mangle(StringRef sym) {
  assert(config->machine != IMAGE_FILE_MACHINE_UNKNOWN);
  if (config->machine == I386)
    return saver.save("_" + sym);
  return sym;
}

static bool findUnderscoreMangle(StringRef sym) {
  Symbol *s = symtab->findMangle(mangle(sym));
  return s && !isa<Undefined>(s);
}

MemoryBufferRef LinkerDriver::takeBuffer(std::unique_ptr<MemoryBuffer> mb) {
  MemoryBufferRef mbref = *mb;
  make<std::unique_ptr<MemoryBuffer>>(std::move(mb)); // take ownership

  if (driver->tar)
    driver->tar->append(relativeToRoot(mbref.getBufferIdentifier()),
                        mbref.getBuffer());
  return mbref;
}

void LinkerDriver::addBuffer(std::unique_ptr<MemoryBuffer> mb,
                             bool wholeArchive) {
  StringRef filename = mb->getBufferIdentifier();

  MemoryBufferRef mbref = takeBuffer(std::move(mb));
  filePaths.push_back(filename);

  // File type is detected by contents, not by file extension.
  switch (identify_magic(mbref.getBuffer())) {
  case file_magic::windows_resource:
    resources.push_back(mbref);
    break;
  case file_magic::archive:
    if (wholeArchive) {
      std::unique_ptr<Archive> file =
          CHECK(Archive::create(mbref), filename + ": failed to parse archive");
      Archive *archive = file.get();
      make<std::unique_ptr<Archive>>(std::move(file)); // take ownership

      for (MemoryBufferRef m : getArchiveMembers(archive))
        addArchiveBuffer(m, "<whole-archive>", filename, 0);
      return;
    }
    symtab->addFile(make<ArchiveFile>(mbref));
    break;
  case file_magic::bitcode:
    symtab->addFile(make<BitcodeFile>(mbref, "", 0));
    break;
  case file_magic::coff_object:
  case file_magic::coff_import_library:
    symtab->addFile(make<ObjFile>(mbref));
    break;
  case file_magic::pdb:
    loadTypeServerSource(mbref);
    break;
  case file_magic::coff_cl_gl_object:
    error(filename + ": is not a native COFF file. Recompile without /GL");
    break;
  case file_magic::pecoff_executable:
    if (filename.endswith_lower(".dll")) {
      error(filename + ": bad file type. Did you specify a DLL instead of an "
                       "import library?");
      break;
    }
    LLVM_FALLTHROUGH;
  default:
    error(mbref.getBufferIdentifier() + ": unknown file type");
    break;
  }
}

void LinkerDriver::enqueuePath(StringRef path, bool wholeArchive) {
  auto future =
      std::make_shared<std::future<MBErrPair>>(createFutureForFile(path));
  std::string pathStr = path;
  enqueueTask([=]() {
    auto mbOrErr = future->get();
    if (mbOrErr.second) {
      std::string msg =
          "could not open '" + pathStr + "': " + mbOrErr.second.message();
      // Check if the filename is a typo for an option flag. OptTable thinks
      // that all args that are not known options and that start with / are
      // filenames, but e.g. `/nodefaultlibs` is more likely a typo for
      // the option `/nodefaultlib` than a reference to a file in the root
      // directory.
      std::string nearest;
      if (COFFOptTable().findNearest(pathStr, nearest) > 1)
        error(msg);
      else
        error(msg + "; did you mean '" + nearest + "'");
    } else
      driver->addBuffer(std::move(mbOrErr.first), wholeArchive);
  });
}

void LinkerDriver::addArchiveBuffer(MemoryBufferRef mb, StringRef symName,
                                    StringRef parentName,
                                    uint64_t offsetInArchive) {
  file_magic magic = identify_magic(mb.getBuffer());
  if (magic == file_magic::coff_import_library) {
    InputFile *imp = make<ImportFile>(mb);
    imp->parentName = parentName;
    symtab->addFile(imp);
    return;
  }

  InputFile *obj;
  if (magic == file_magic::coff_object) {
    obj = make<ObjFile>(mb);
  } else if (magic == file_magic::bitcode) {
    obj = make<BitcodeFile>(mb, parentName, offsetInArchive);
  } else {
    error("unknown file type: " + mb.getBufferIdentifier());
    return;
  }

  obj->parentName = parentName;
  symtab->addFile(obj);
  log("Loaded " + toString(obj) + " for " + symName);
}

void LinkerDriver::enqueueArchiveMember(const Archive::Child &c,
                                        const Archive::Symbol &sym,
                                        StringRef parentName) {

  auto reportBufferError = [=](Error &&e, StringRef childName) {
    fatal("could not get the buffer for the member defining symbol " +
          toCOFFString(sym) + ": " + parentName + "(" + childName + "): " +
          toString(std::move(e)));
  };

  if (!c.getParent()->isThin()) {
    uint64_t offsetInArchive = c.getChildOffset();
    Expected<MemoryBufferRef> mbOrErr = c.getMemoryBufferRef();
    if (!mbOrErr)
      reportBufferError(mbOrErr.takeError(), check(c.getFullName()));
    MemoryBufferRef mb = mbOrErr.get();
    enqueueTask([=]() {
      driver->addArchiveBuffer(mb, toCOFFString(sym), parentName,
                               offsetInArchive);
    });
    return;
  }

  std::string childName = CHECK(
      c.getFullName(),
      "could not get the filename for the member defining symbol " +
      toCOFFString(sym));
  auto future = std::make_shared<std::future<MBErrPair>>(
      createFutureForFile(childName));
  enqueueTask([=]() {
    auto mbOrErr = future->get();
    if (mbOrErr.second)
      reportBufferError(errorCodeToError(mbOrErr.second), childName);
    driver->addArchiveBuffer(takeBuffer(std::move(mbOrErr.first)),
                             toCOFFString(sym), parentName,
                             /*OffsetInArchive=*/0);
  });
}

static bool isDecorated(StringRef sym) {
  return sym.startswith("@") || sym.contains("@@") || sym.startswith("?") ||
         (!config->mingw && sym.contains('@'));
}

// Parses .drectve section contents and returns a list of files
// specified by /defaultlib.
void LinkerDriver::parseDirectives(InputFile *file) {
  StringRef s = file->getDirectives();
  if (s.empty())
    return;

  log("Directives: " + toString(file) + ": " + s);

  ArgParser parser;
  // .drectve is always tokenized using Windows shell rules.
  // /EXPORT: option can appear too many times, processing in fastpath.
  opt::InputArgList args;
  std::vector<StringRef> exports;
  std::tie(args, exports) = parser.parseDirectives(s);

  for (StringRef e : exports) {
    // If a common header file contains dllexported function
    // declarations, many object files may end up with having the
    // same /EXPORT options. In order to save cost of parsing them,
    // we dedup them first.
    if (!directivesExports.insert(e).second)
      continue;

    Export exp = parseExport(e);
    if (config->machine == I386 && config->mingw) {
      if (!isDecorated(exp.name))
        exp.name = saver.save("_" + exp.name);
      if (!exp.extName.empty() && !isDecorated(exp.extName))
        exp.extName = saver.save("_" + exp.extName);
    }
    exp.directives = true;
    config->exports.push_back(exp);
  }

  for (auto *arg : args) {
    switch (arg->getOption().getID()) {
    case OPT_aligncomm:
      parseAligncomm(arg->getValue());
      break;
    case OPT_alternatename:
      parseAlternateName(arg->getValue());
      break;
    case OPT_defaultlib:
      if (Optional<StringRef> path = findLib(arg->getValue()))
        enqueuePath(*path, false);
      break;
    case OPT_entry:
      config->entry = addUndefined(mangle(arg->getValue()));
      break;
    case OPT_failifmismatch:
      checkFailIfMismatch(arg->getValue(), file);
      break;
    case OPT_incl:
      addUndefined(arg->getValue());
      break;
    case OPT_merge:
      parseMerge(arg->getValue());
      break;
    case OPT_nodefaultlib:
      config->noDefaultLibs.insert(doFindLib(arg->getValue()).lower());
      break;
    case OPT_section:
      parseSection(arg->getValue());
      break;
    case OPT_subsystem:
      parseSubsystem(arg->getValue(), &config->subsystem,
                     &config->majorOSVersion, &config->minorOSVersion);
      break;
    // Only add flags here that link.exe accepts in
    // `#pragma comment(linker, "/flag")`-generated sections.
    case OPT_editandcontinue:
    case OPT_guardsym:
    case OPT_throwingnew:
      break;
    default:
      error(arg->getSpelling() + " is not allowed in .drectve");
    }
  }
}

// Find file from search paths. You can omit ".obj", this function takes
// care of that. Note that the returned path is not guaranteed to exist.
StringRef LinkerDriver::doFindFile(StringRef filename) {
  bool hasPathSep = (filename.find_first_of("/\\") != StringRef::npos);
  if (hasPathSep)
    return filename;
  bool hasExt = filename.contains('.');
  for (StringRef dir : searchPaths) {
    SmallString<128> path = dir;
    sys::path::append(path, filename);
    if (sys::fs::exists(path.str()))
      return saver.save(path.str());
    if (!hasExt) {
      path.append(".obj");
      if (sys::fs::exists(path.str()))
        return saver.save(path.str());
    }
  }
  return filename;
}

static Optional<sys::fs::UniqueID> getUniqueID(StringRef path) {
  sys::fs::UniqueID ret;
  if (sys::fs::getUniqueID(path, ret))
    return None;
  return ret;
}

// Resolves a file path. This never returns the same path
// (in that case, it returns None).
Optional<StringRef> LinkerDriver::findFile(StringRef filename) {
  StringRef path = doFindFile(filename);

  if (Optional<sys::fs::UniqueID> id = getUniqueID(path)) {
    bool seen = !visitedFiles.insert(*id).second;
    if (seen)
      return None;
  }

  if (path.endswith_lower(".lib"))
    visitedLibs.insert(sys::path::filename(path));
  return path;
}

// MinGW specific. If an embedded directive specified to link to
// foo.lib, but it isn't found, try libfoo.a instead.
StringRef LinkerDriver::doFindLibMinGW(StringRef filename) {
  if (filename.contains('/') || filename.contains('\\'))
    return filename;

  SmallString<128> s = filename;
  sys::path::replace_extension(s, ".a");
  StringRef libName = saver.save("lib" + s.str());
  return doFindFile(libName);
}

// Find library file from search path.
StringRef LinkerDriver::doFindLib(StringRef filename) {
  // Add ".lib" to Filename if that has no file extension.
  bool hasExt = filename.contains('.');
  if (!hasExt)
    filename = saver.save(filename + ".lib");
  StringRef ret = doFindFile(filename);
  // For MinGW, if the find above didn't turn up anything, try
  // looking for a MinGW formatted library name.
  if (config->mingw && ret == filename)
    return doFindLibMinGW(filename);
  return ret;
}

// Resolves a library path. /nodefaultlib options are taken into
// consideration. This never returns the same path (in that case,
// it returns None).
Optional<StringRef> LinkerDriver::findLib(StringRef filename) {
  if (config->noDefaultLibAll)
    return None;
  if (!visitedLibs.insert(filename.lower()).second)
    return None;

  StringRef path = doFindLib(filename);
  if (config->noDefaultLibs.count(path.lower()))
    return None;

  if (Optional<sys::fs::UniqueID> id = getUniqueID(path))
    if (!visitedFiles.insert(*id).second)
      return None;
  return path;
}

// Parses LIB environment which contains a list of search paths.
void LinkerDriver::addLibSearchPaths() {
  Optional<std::string> envOpt = Process::GetEnv("LIB");
  if (!envOpt.hasValue())
    return;
  StringRef env = saver.save(*envOpt);
  while (!env.empty()) {
    StringRef path;
    std::tie(path, env) = env.split(';');
    searchPaths.push_back(path);
  }
}

Symbol *LinkerDriver::addUndefined(StringRef name) {
  Symbol *b = symtab->addUndefined(name);
  if (!b->isGCRoot) {
    b->isGCRoot = true;
    config->gcroot.push_back(b);
  }
  return b;
}

StringRef LinkerDriver::mangleMaybe(Symbol *s) {
  // If the plain symbol name has already been resolved, do nothing.
  Undefined *unmangled = dyn_cast<Undefined>(s);
  if (!unmangled)
    return "";

  // Otherwise, see if a similar, mangled symbol exists in the symbol table.
  Symbol *mangled = symtab->findMangle(unmangled->getName());
  if (!mangled)
    return "";

  // If we find a similar mangled symbol, make this an alias to it and return
  // its name.
  log(unmangled->getName() + " aliased to " + mangled->getName());
  unmangled->weakAlias = symtab->addUndefined(mangled->getName());
  return mangled->getName();
}

// Windows specific -- find default entry point name.
//
// There are four different entry point functions for Windows executables,
// each of which corresponds to a user-defined "main" function. This function
// infers an entry point from a user-defined "main" function.
StringRef LinkerDriver::findDefaultEntry() {
  assert(config->subsystem != IMAGE_SUBSYSTEM_UNKNOWN &&
         "must handle /subsystem before calling this");

  if (config->mingw)
    return mangle(config->subsystem == IMAGE_SUBSYSTEM_WINDOWS_GUI
                      ? "WinMainCRTStartup"
                      : "mainCRTStartup");

  if (config->subsystem == IMAGE_SUBSYSTEM_WINDOWS_GUI) {
    if (findUnderscoreMangle("wWinMain")) {
      if (!findUnderscoreMangle("WinMain"))
        return mangle("wWinMainCRTStartup");
      warn("found both wWinMain and WinMain; using latter");
    }
    return mangle("WinMainCRTStartup");
  }
  if (findUnderscoreMangle("wmain")) {
    if (!findUnderscoreMangle("main"))
      return mangle("wmainCRTStartup");
    warn("found both wmain and main; using latter");
  }
  return mangle("mainCRTStartup");
}

WindowsSubsystem LinkerDriver::inferSubsystem() {
  if (config->dll)
    return IMAGE_SUBSYSTEM_WINDOWS_GUI;
  if (config->mingw)
    return IMAGE_SUBSYSTEM_WINDOWS_CUI;
  // Note that link.exe infers the subsystem from the presence of these
  // functions even if /entry: or /nodefaultlib are passed which causes them
  // to not be called.
  bool haveMain = findUnderscoreMangle("main");
  bool haveWMain = findUnderscoreMangle("wmain");
  bool haveWinMain = findUnderscoreMangle("WinMain");
  bool haveWWinMain = findUnderscoreMangle("wWinMain");
  if (haveMain || haveWMain) {
    if (haveWinMain || haveWWinMain) {
      warn(std::string("found ") + (haveMain ? "main" : "wmain") + " and " +
           (haveWinMain ? "WinMain" : "wWinMain") +
           "; defaulting to /subsystem:console");
    }
    return IMAGE_SUBSYSTEM_WINDOWS_CUI;
  }
  if (haveWinMain || haveWWinMain)
    return IMAGE_SUBSYSTEM_WINDOWS_GUI;
  return IMAGE_SUBSYSTEM_UNKNOWN;
}

static uint64_t getDefaultImageBase() {
  if (config->is64())
    return config->dll ? 0x180000000 : 0x140000000;
  return config->dll ? 0x10000000 : 0x400000;
}

static std::string createResponseFile(const opt::InputArgList &args,
                                      ArrayRef<StringRef> filePaths,
                                      ArrayRef<StringRef> searchPaths) {
  SmallString<0> data;
  raw_svector_ostream os(data);

  for (auto *arg : args) {
    switch (arg->getOption().getID()) {
    case OPT_linkrepro:
    case OPT_INPUT:
    case OPT_defaultlib:
    case OPT_libpath:
    case OPT_manifest:
    case OPT_manifest_colon:
    case OPT_manifestdependency:
    case OPT_manifestfile:
    case OPT_manifestinput:
    case OPT_manifestuac:
      break;
    case OPT_implib:
    case OPT_pdb:
    case OPT_out:
      os << arg->getSpelling() << sys::path::filename(arg->getValue()) << "\n";
      break;
    default:
      os << toString(*arg) << "\n";
    }
  }

  for (StringRef path : searchPaths) {
    std::string relPath = relativeToRoot(path);
    os << "/libpath:" << quote(relPath) << "\n";
  }

  for (StringRef path : filePaths)
    os << quote(relativeToRoot(path)) << "\n";

  return data.str();
}

enum class DebugKind { Unknown, None, Full, FastLink, GHash, Dwarf, Symtab };

static DebugKind parseDebugKind(const opt::InputArgList &args) {
  auto *a = args.getLastArg(OPT_debug, OPT_debug_opt);
  if (!a)
    return DebugKind::None;
  if (a->getNumValues() == 0)
    return DebugKind::Full;

  DebugKind debug = StringSwitch<DebugKind>(a->getValue())
                     .CaseLower("none", DebugKind::None)
                     .CaseLower("full", DebugKind::Full)
                     .CaseLower("fastlink", DebugKind::FastLink)
                     // LLD extensions
                     .CaseLower("ghash", DebugKind::GHash)
                     .CaseLower("dwarf", DebugKind::Dwarf)
                     .CaseLower("symtab", DebugKind::Symtab)
                     .Default(DebugKind::Unknown);

  if (debug == DebugKind::FastLink) {
    warn("/debug:fastlink unsupported; using /debug:full");
    return DebugKind::Full;
  }
  if (debug == DebugKind::Unknown) {
    error("/debug: unknown option: " + Twine(a->getValue()));
    return DebugKind::None;
  }
  return debug;
}

static unsigned parseDebugTypes(const opt::InputArgList &args) {
  unsigned debugTypes = static_cast<unsigned>(DebugType::None);

  if (auto *a = args.getLastArg(OPT_debugtype)) {
    SmallVector<StringRef, 3> types;
    StringRef(a->getValue())
        .split(types, ',', /*MaxSplit=*/-1, /*KeepEmpty=*/false);

    for (StringRef type : types) {
      unsigned v = StringSwitch<unsigned>(type.lower())
                       .Case("cv", static_cast<unsigned>(DebugType::CV))
                       .Case("pdata", static_cast<unsigned>(DebugType::PData))
                       .Case("fixup", static_cast<unsigned>(DebugType::Fixup))
                       .Default(0);
      if (v == 0) {
        warn("/debugtype: unknown option '" + type + "'");
        continue;
      }
      debugTypes |= v;
    }
    return debugTypes;
  }

  // Default debug types
  debugTypes = static_cast<unsigned>(DebugType::CV);
  if (args.hasArg(OPT_driver))
    debugTypes |= static_cast<unsigned>(DebugType::PData);
  if (args.hasArg(OPT_profile))
    debugTypes |= static_cast<unsigned>(DebugType::Fixup);

  return debugTypes;
}

static std::string getMapFile(const opt::InputArgList &args) {
  auto *arg = args.getLastArg(OPT_lldmap, OPT_lldmap_file);
  if (!arg)
    return "";
  if (arg->getOption().getID() == OPT_lldmap_file)
    return arg->getValue();

  assert(arg->getOption().getID() == OPT_lldmap);
  StringRef outFile = config->outputFile;
  return (outFile.substr(0, outFile.rfind('.')) + ".map").str();
}

static std::string getImplibPath() {
  if (!config->implib.empty())
    return config->implib;
  SmallString<128> out = StringRef(config->outputFile);
  sys::path::replace_extension(out, ".lib");
  return out.str();
}

//
// The import name is caculated as the following:
//
//        | LIBRARY w/ ext |   LIBRARY w/o ext   | no LIBRARY
//   -----+----------------+---------------------+------------------
//   LINK | {value}        | {value}.{.dll/.exe} | {output name}
//    LIB | {value}        | {value}.dll         | {output name}.dll
//
static std::string getImportName(bool asLib) {
  SmallString<128> out;

  if (config->importName.empty()) {
    out.assign(sys::path::filename(config->outputFile));
    if (asLib)
      sys::path::replace_extension(out, ".dll");
  } else {
    out.assign(config->importName);
    if (!sys::path::has_extension(out))
      sys::path::replace_extension(out,
                                   (config->dll || asLib) ? ".dll" : ".exe");
  }

  return out.str();
}

static void createImportLibrary(bool asLib) {
  std::vector<COFFShortExport> exports;
  for (Export &e1 : config->exports) {
    COFFShortExport e2;
    e2.Name = e1.name;
    e2.SymbolName = e1.symbolName;
    e2.ExtName = e1.extName;
    e2.Ordinal = e1.ordinal;
    e2.Noname = e1.noname;
    e2.Data = e1.data;
    e2.Private = e1.isPrivate;
    e2.Constant = e1.constant;
    exports.push_back(e2);
  }

  auto handleError = [](Error &&e) {
    handleAllErrors(std::move(e),
                    [](ErrorInfoBase &eib) { error(eib.message()); });
  };
  std::string libName = getImportName(asLib);
  std::string path = getImplibPath();

  if (!config->incremental) {
    handleError(writeImportLibrary(libName, path, exports, config->machine,
                                   config->mingw));
    return;
  }

  // If the import library already exists, replace it only if the contents
  // have changed.
  ErrorOr<std::unique_ptr<MemoryBuffer>> oldBuf = MemoryBuffer::getFile(
      path, /*FileSize*/ -1, /*RequiresNullTerminator*/ false);
  if (!oldBuf) {
    handleError(writeImportLibrary(libName, path, exports, config->machine,
                                   config->mingw));
    return;
  }

  SmallString<128> tmpName;
  if (std::error_code ec =
          sys::fs::createUniqueFile(path + ".tmp-%%%%%%%%.lib", tmpName))
    fatal("cannot create temporary file for import library " + path + ": " +
          ec.message());

  if (Error e = writeImportLibrary(libName, tmpName, exports, config->machine,
                                   config->mingw)) {
    handleError(std::move(e));
    return;
  }

  std::unique_ptr<MemoryBuffer> newBuf = check(MemoryBuffer::getFile(
      tmpName, /*FileSize*/ -1, /*RequiresNullTerminator*/ false));
  if ((*oldBuf)->getBuffer() != newBuf->getBuffer()) {
    oldBuf->reset();
    handleError(errorCodeToError(sys::fs::rename(tmpName, path)));
  } else {
    sys::fs::remove(tmpName);
  }
}

static void parseModuleDefs(StringRef path) {
  std::unique_ptr<MemoryBuffer> mb = CHECK(
      MemoryBuffer::getFile(path, -1, false, true), "could not open " + path);
  COFFModuleDefinition m = check(parseCOFFModuleDefinition(
      mb->getMemBufferRef(), config->machine, config->mingw));

  if (config->outputFile.empty())
    config->outputFile = saver.save(m.OutputFile);
  config->importName = saver.save(m.ImportName);
  if (m.ImageBase)
    config->imageBase = m.ImageBase;
  if (m.StackReserve)
    config->stackReserve = m.StackReserve;
  if (m.StackCommit)
    config->stackCommit = m.StackCommit;
  if (m.HeapReserve)
    config->heapReserve = m.HeapReserve;
  if (m.HeapCommit)
    config->heapCommit = m.HeapCommit;
  if (m.MajorImageVersion)
    config->majorImageVersion = m.MajorImageVersion;
  if (m.MinorImageVersion)
    config->minorImageVersion = m.MinorImageVersion;
  if (m.MajorOSVersion)
    config->majorOSVersion = m.MajorOSVersion;
  if (m.MinorOSVersion)
    config->minorOSVersion = m.MinorOSVersion;

  for (COFFShortExport e1 : m.Exports) {
    Export e2;
    // In simple cases, only Name is set. Renamed exports are parsed
    // and set as "ExtName = Name". If Name has the form "OtherDll.Func",
    // it shouldn't be a normal exported function but a forward to another
    // DLL instead. This is supported by both MS and GNU linkers.
    if (e1.ExtName != e1.Name && StringRef(e1.Name).contains('.')) {
      e2.name = saver.save(e1.ExtName);
      e2.forwardTo = saver.save(e1.Name);
      config->exports.push_back(e2);
      continue;
    }
    e2.name = saver.save(e1.Name);
    e2.extName = saver.save(e1.ExtName);
    e2.ordinal = e1.Ordinal;
    e2.noname = e1.Noname;
    e2.data = e1.Data;
    e2.isPrivate = e1.Private;
    e2.constant = e1.Constant;
    config->exports.push_back(e2);
  }
}

void LinkerDriver::enqueueTask(std::function<void()> task) {
  taskQueue.push_back(std::move(task));
}

bool LinkerDriver::run() {
  ScopedTimer t(inputFileTimer);

  bool didWork = !taskQueue.empty();
  while (!taskQueue.empty()) {
    taskQueue.front()();
    taskQueue.pop_front();
  }
  return didWork;
}

// Parse an /order file. If an option is given, the linker places
// COMDAT sections in the same order as their names appear in the
// given file.
static void parseOrderFile(StringRef arg) {
  // For some reason, the MSVC linker requires a filename to be
  // preceded by "@".
  if (!arg.startswith("@")) {
    error("malformed /order option: '@' missing");
    return;
  }

  // Get a list of all comdat sections for error checking.
  DenseSet<StringRef> set;
  for (Chunk *c : symtab->getChunks())
    if (auto *sec = dyn_cast<SectionChunk>(c))
      if (sec->sym)
        set.insert(sec->sym->getName());

  // Open a file.
  StringRef path = arg.substr(1);
  std::unique_ptr<MemoryBuffer> mb = CHECK(
      MemoryBuffer::getFile(path, -1, false, true), "could not open " + path);

  // Parse a file. An order file contains one symbol per line.
  // All symbols that were not present in a given order file are
  // considered to have the lowest priority 0 and are placed at
  // end of an output section.
  for (std::string s : args::getLines(mb->getMemBufferRef())) {
    if (config->machine == I386 && !isDecorated(s))
      s = "_" + s;

    if (set.count(s) == 0) {
      if (config->warnMissingOrderSymbol)
        warn("/order:" + arg + ": missing symbol: " + s + " [LNK4037]");
    }
    else
      config->order[s] = INT_MIN + config->order.size();
  }
}

static void markAddrsig(Symbol *s) {
  if (auto *d = dyn_cast_or_null<Defined>(s))
    if (SectionChunk *c = dyn_cast_or_null<SectionChunk>(d->getChunk()))
      c->keepUnique = true;
}

static void findKeepUniqueSections() {
  // Exported symbols could be address-significant in other executables or DSOs,
  // so we conservatively mark them as address-significant.
  for (Export &r : config->exports)
    markAddrsig(r.sym);

  // Visit the address-significance table in each object file and mark each
  // referenced symbol as address-significant.
  for (ObjFile *obj : ObjFile::instances) {
    ArrayRef<Symbol *> syms = obj->getSymbols();
    if (obj->addrsigSec) {
      ArrayRef<uint8_t> contents;
      cantFail(
          obj->getCOFFObj()->getSectionContents(obj->addrsigSec, contents));
      const uint8_t *cur = contents.begin();
      while (cur != contents.end()) {
        unsigned size;
        const char *err;
        uint64_t symIndex = decodeULEB128(cur, &size, contents.end(), &err);
        if (err)
          fatal(toString(obj) + ": could not decode addrsig section: " + err);
        if (symIndex >= syms.size())
          fatal(toString(obj) + ": invalid symbol index in addrsig section");
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

// link.exe replaces each %foo% in altPath with the contents of environment
// variable foo, and adds the two magic env vars _PDB (expands to the basename
// of pdb's output path) and _EXT (expands to the extension of the output
// binary).
// lld only supports %_PDB% and %_EXT% and warns on references to all other env
// vars.
static void parsePDBAltPath(StringRef altPath) {
  SmallString<128> buf;
  StringRef pdbBasename =
      sys::path::filename(config->pdbPath, sys::path::Style::windows);
  StringRef binaryExtension =
      sys::path::extension(config->outputFile, sys::path::Style::windows);
  if (!binaryExtension.empty())
    binaryExtension = binaryExtension.substr(1); // %_EXT% does not include '.'.

  // Invariant:
  //   +--------- cursor ('a...' might be the empty string).
  //   |   +----- firstMark
  //   |   |   +- secondMark
  //   v   v   v
  //   a...%...%...
  size_t cursor = 0;
  while (cursor < altPath.size()) {
    size_t firstMark, secondMark;
    if ((firstMark = altPath.find('%', cursor)) == StringRef::npos ||
        (secondMark = altPath.find('%', firstMark + 1)) == StringRef::npos) {
      // Didn't find another full fragment, treat rest of string as literal.
      buf.append(altPath.substr(cursor));
      break;
    }

    // Found a full fragment. Append text in front of first %, and interpret
    // text between first and second % as variable name.
    buf.append(altPath.substr(cursor, firstMark - cursor));
    StringRef var = altPath.substr(firstMark, secondMark - firstMark + 1);
    if (var.equals_lower("%_pdb%"))
      buf.append(pdbBasename);
    else if (var.equals_lower("%_ext%"))
      buf.append(binaryExtension);
    else {
      warn("only %_PDB% and %_EXT% supported in /pdbaltpath:, keeping " +
           var + " as literal");
      buf.append(var);
    }

    cursor = secondMark + 1;
  }

  config->pdbAltPath = buf;
}

/// Check that at most one resource obj file was used.
/// Call after ObjFile::Instances is complete.
static void diagnoseMultipleResourceObjFiles() {
  // The .rsrc$01 section in a resource obj file contains a tree description
  // of resources.  Merging multiple resource obj files would require merging
  // the trees instead of using usual linker section merging semantics.
  // Since link.exe disallows linking more than one resource obj file with
  // LNK4078, mirror that.  The normal use of resource files is to give the
  // linker many .res files, which are then converted to a single resource obj
  // file internally, so this is not a big restriction in practice.
  ObjFile *resourceObjFile = nullptr;
  for (ObjFile *f : ObjFile::instances) {
    if (!f->isResourceObjFile)
      continue;

    if (!resourceObjFile) {
      resourceObjFile = f;
      continue;
    }

    error(toString(f) +
          ": more than one resource obj file not allowed, already got " +
          toString(resourceObjFile));
  }
}

// In MinGW, if no symbols are chosen to be exported, then all symbols are
// automatically exported by default. This behavior can be forced by the
// -export-all-symbols option, so that it happens even when exports are
// explicitly specified. The automatic behavior can be disabled using the
// -exclude-all-symbols option, so that lld-link behaves like link.exe rather
// than MinGW in the case that nothing is explicitly exported.
void LinkerDriver::maybeExportMinGWSymbols(const opt::InputArgList &args) {
  if (!config->dll)
    return;

  if (!args.hasArg(OPT_export_all_symbols)) {
    if (!config->exports.empty())
      return;
    if (args.hasArg(OPT_exclude_all_symbols))
      return;
  }

  AutoExporter exporter;

  for (auto *arg : args.filtered(OPT_wholearchive_file))
    if (Optional<StringRef> path = doFindFile(arg->getValue()))
      exporter.addWholeArchive(*path);

  symtab->forEachSymbol([&](Symbol *s) {
    auto *def = dyn_cast<Defined>(s);
    if (!exporter.shouldExport(def))
      return;

    Export e;
    e.name = def->getName();
    e.sym = def;
    if (Chunk *c = def->getChunk())
      if (!(c->getOutputCharacteristics() & IMAGE_SCN_MEM_EXECUTE))
        e.data = true;
    config->exports.push_back(e);
  });
}

static const char *libcallRoutineNames[] = {
#define HANDLE_LIBCALL(code, name) name,
#include "llvm/IR/RuntimeLibcalls.def"
#undef HANDLE_LIBCALL
};

void LinkerDriver::link(ArrayRef<const char *> argsArr) {
  // Needed for LTO.
  InitializeAllTargetInfos();
  InitializeAllTargets();
  InitializeAllTargetMCs();
  InitializeAllAsmParsers();
  InitializeAllAsmPrinters();

  // If the first command line argument is "/lib", link.exe acts like lib.exe.
  // We call our own implementation of lib.exe that understands bitcode files.
  if (argsArr.size() > 1 && StringRef(argsArr[1]).equals_lower("/lib")) {
    if (llvm::libDriverMain(argsArr.slice(1)) != 0)
      fatal("lib failed");
    return;
  }

  // Parse command line options.
  ArgParser parser;
  opt::InputArgList args = parser.parseLINK(argsArr);

  // Parse and evaluate -mllvm options.
  std::vector<const char *> v;
  v.push_back("lld-link (LLVM option parsing)");
  for (auto *arg : args.filtered(OPT_mllvm))
    v.push_back(arg->getValue());
  cl::ParseCommandLineOptions(v.size(), v.data());

  // Handle /errorlimit early, because error() depends on it.
  if (auto *arg = args.getLastArg(OPT_errorlimit)) {
    int n = 20;
    StringRef s = arg->getValue();
    if (s.getAsInteger(10, n))
      error(arg->getSpelling() + " number expected, but got " + s);
    errorHandler().errorLimit = n;
  }

  // Handle /help
  if (args.hasArg(OPT_help)) {
    printHelp(argsArr[0]);
    return;
  }

  lld::threadsEnabled = args.hasFlag(OPT_threads, OPT_threads_no, true);

  if (args.hasArg(OPT_show_timing))
    config->showTiming = true;

  config->showSummary = args.hasArg(OPT_summary);

  ScopedTimer t(Timer::root());
  // Handle --version, which is an lld extension. This option is a bit odd
  // because it doesn't start with "/", but we deliberately chose "--" to
  // avoid conflict with /version and for compatibility with clang-cl.
  if (args.hasArg(OPT_dash_dash_version)) {
    outs() << getLLDVersion() << "\n";
    return;
  }

  // Handle /lldmingw early, since it can potentially affect how other
  // options are handled.
  config->mingw = args.hasArg(OPT_lldmingw);

  if (auto *arg = args.getLastArg(OPT_linkrepro)) {
    SmallString<64> path = StringRef(arg->getValue());
    sys::path::append(path, "repro.tar");

    Expected<std::unique_ptr<TarWriter>> errOrWriter =
        TarWriter::create(path, "repro");

    if (errOrWriter) {
      tar = std::move(*errOrWriter);
    } else {
      error("/linkrepro: failed to open " + path + ": " +
            toString(errOrWriter.takeError()));
    }
  }

  if (!args.hasArg(OPT_INPUT)) {
    if (args.hasArg(OPT_deffile))
      config->noEntry = true;
    else
      fatal("no input files");
  }

  // Construct search path list.
  searchPaths.push_back("");
  for (auto *arg : args.filtered(OPT_libpath))
    searchPaths.push_back(arg->getValue());
  addLibSearchPaths();

  // Handle /ignore
  for (auto *arg : args.filtered(OPT_ignore)) {
    SmallVector<StringRef, 8> vec;
    StringRef(arg->getValue()).split(vec, ',');
    for (StringRef s : vec) {
      if (s == "4037")
        config->warnMissingOrderSymbol = false;
      else if (s == "4099")
        config->warnDebugInfoUnusable = false;
      else if (s == "4217")
        config->warnLocallyDefinedImported = false;
      // Other warning numbers are ignored.
    }
  }

  // Handle /out
  if (auto *arg = args.getLastArg(OPT_out))
    config->outputFile = arg->getValue();

  // Handle /verbose
  if (args.hasArg(OPT_verbose))
    config->verbose = true;
  errorHandler().verbose = config->verbose;

  // Handle /force or /force:unresolved
  if (args.hasArg(OPT_force, OPT_force_unresolved))
    config->forceUnresolved = true;

  // Handle /force or /force:multiple
  if (args.hasArg(OPT_force, OPT_force_multiple))
    config->forceMultiple = true;

  // Handle /force or /force:multipleres
  if (args.hasArg(OPT_force, OPT_force_multipleres))
    config->forceMultipleRes = true;

  // Handle /debug
  DebugKind debug = parseDebugKind(args);
  if (debug == DebugKind::Full || debug == DebugKind::Dwarf ||
      debug == DebugKind::GHash) {
    config->debug = true;
    config->incremental = true;
  }

  // Handle /demangle
  config->demangle = args.hasFlag(OPT_demangle, OPT_demangle_no);

  // Handle /debugtype
  config->debugTypes = parseDebugTypes(args);

  // Handle /pdb
  bool shouldCreatePDB =
      (debug == DebugKind::Full || debug == DebugKind::GHash);
  if (shouldCreatePDB) {
    if (auto *arg = args.getLastArg(OPT_pdb))
      config->pdbPath = arg->getValue();
    if (auto *arg = args.getLastArg(OPT_pdbaltpath))
      config->pdbAltPath = arg->getValue();
    if (args.hasArg(OPT_natvis))
      config->natvisFiles = args.getAllArgValues(OPT_natvis);

    if (auto *arg = args.getLastArg(OPT_pdb_source_path))
      config->pdbSourcePath = arg->getValue();
  }

  // Handle /noentry
  if (args.hasArg(OPT_noentry)) {
    if (args.hasArg(OPT_dll))
      config->noEntry = true;
    else
      error("/noentry must be specified with /dll");
  }

  // Handle /dll
  if (args.hasArg(OPT_dll)) {
    config->dll = true;
    config->manifestID = 2;
  }

  // Handle /dynamicbase and /fixed. We can't use hasFlag for /dynamicbase
  // because we need to explicitly check whether that option or its inverse was
  // present in the argument list in order to handle /fixed.
  auto *dynamicBaseArg = args.getLastArg(OPT_dynamicbase, OPT_dynamicbase_no);
  if (dynamicBaseArg &&
      dynamicBaseArg->getOption().getID() == OPT_dynamicbase_no)
    config->dynamicBase = false;

  // MSDN claims "/FIXED:NO is the default setting for a DLL, and /FIXED is the
  // default setting for any other project type.", but link.exe defaults to
  // /FIXED:NO for exe outputs as well. Match behavior, not docs.
  bool fixed = args.hasFlag(OPT_fixed, OPT_fixed_no, false);
  if (fixed) {
    if (dynamicBaseArg &&
        dynamicBaseArg->getOption().getID() == OPT_dynamicbase) {
      error("/fixed must not be specified with /dynamicbase");
    } else {
      config->relocatable = false;
      config->dynamicBase = false;
    }
  }

  // Handle /appcontainer
  config->appContainer =
      args.hasFlag(OPT_appcontainer, OPT_appcontainer_no, false);

  // Handle /machine
  if (auto *arg = args.getLastArg(OPT_machine)) {
    config->machine = getMachineType(arg->getValue());
    if (config->machine == IMAGE_FILE_MACHINE_UNKNOWN)
      fatal(Twine("unknown /machine argument: ") + arg->getValue());
  }

  // Handle /nodefaultlib:<filename>
  for (auto *arg : args.filtered(OPT_nodefaultlib))
    config->noDefaultLibs.insert(doFindLib(arg->getValue()).lower());

  // Handle /nodefaultlib
  if (args.hasArg(OPT_nodefaultlib_all))
    config->noDefaultLibAll = true;

  // Handle /base
  if (auto *arg = args.getLastArg(OPT_base))
    parseNumbers(arg->getValue(), &config->imageBase);

  // Handle /filealign
  if (auto *arg = args.getLastArg(OPT_filealign)) {
    parseNumbers(arg->getValue(), &config->fileAlign);
    if (!isPowerOf2_64(config->fileAlign))
      error("/filealign: not a power of two: " + Twine(config->fileAlign));
  }

  // Handle /stack
  if (auto *arg = args.getLastArg(OPT_stack))
    parseNumbers(arg->getValue(), &config->stackReserve, &config->stackCommit);

  // Handle /guard:cf
  if (auto *arg = args.getLastArg(OPT_guard))
    parseGuard(arg->getValue());

  // Handle /heap
  if (auto *arg = args.getLastArg(OPT_heap))
    parseNumbers(arg->getValue(), &config->heapReserve, &config->heapCommit);

  // Handle /version
  if (auto *arg = args.getLastArg(OPT_version))
    parseVersion(arg->getValue(), &config->majorImageVersion,
                 &config->minorImageVersion);

  // Handle /subsystem
  if (auto *arg = args.getLastArg(OPT_subsystem))
    parseSubsystem(arg->getValue(), &config->subsystem, &config->majorOSVersion,
                   &config->minorOSVersion);

  // Handle /timestamp
  if (llvm::opt::Arg *arg = args.getLastArg(OPT_timestamp, OPT_repro)) {
    if (arg->getOption().getID() == OPT_repro) {
      config->timestamp = 0;
      config->repro = true;
    } else {
      config->repro = false;
      StringRef value(arg->getValue());
      if (value.getAsInteger(0, config->timestamp))
        fatal(Twine("invalid timestamp: ") + value +
              ".  Expected 32-bit integer");
    }
  } else {
    config->repro = false;
    config->timestamp = time(nullptr);
  }

  // Handle /alternatename
  for (auto *arg : args.filtered(OPT_alternatename))
    parseAlternateName(arg->getValue());

  // Handle /include
  for (auto *arg : args.filtered(OPT_incl))
    addUndefined(arg->getValue());

  // Handle /implib
  if (auto *arg = args.getLastArg(OPT_implib))
    config->implib = arg->getValue();

  // Handle /opt.
  bool doGC = debug == DebugKind::None || args.hasArg(OPT_profile);
  unsigned icfLevel =
      args.hasArg(OPT_profile) ? 0 : 1; // 0: off, 1: limited, 2: on
  unsigned tailMerge = 1;
  for (auto *arg : args.filtered(OPT_opt)) {
    std::string str = StringRef(arg->getValue()).lower();
    SmallVector<StringRef, 1> vec;
    StringRef(str).split(vec, ',');
    for (StringRef s : vec) {
      if (s == "ref") {
        doGC = true;
      } else if (s == "noref") {
        doGC = false;
      } else if (s == "icf" || s.startswith("icf=")) {
        icfLevel = 2;
      } else if (s == "noicf") {
        icfLevel = 0;
      } else if (s == "lldtailmerge") {
        tailMerge = 2;
      } else if (s == "nolldtailmerge") {
        tailMerge = 0;
      } else if (s.startswith("lldlto=")) {
        StringRef optLevel = s.substr(7);
        if (optLevel.getAsInteger(10, config->ltoo) || config->ltoo > 3)
          error("/opt:lldlto: invalid optimization level: " + optLevel);
      } else if (s.startswith("lldltojobs=")) {
        StringRef jobs = s.substr(11);
        if (jobs.getAsInteger(10, config->thinLTOJobs) ||
            config->thinLTOJobs == 0)
          error("/opt:lldltojobs: invalid job count: " + jobs);
      } else if (s.startswith("lldltopartitions=")) {
        StringRef n = s.substr(17);
        if (n.getAsInteger(10, config->ltoPartitions) ||
            config->ltoPartitions == 0)
          error("/opt:lldltopartitions: invalid partition count: " + n);
      } else if (s != "lbr" && s != "nolbr")
        error("/opt: unknown option: " + s);
    }
  }

  // Limited ICF is enabled if GC is enabled and ICF was never mentioned
  // explicitly.
  // FIXME: LLD only implements "limited" ICF, i.e. it only merges identical
  // code. If the user passes /OPT:ICF explicitly, LLD should merge identical
  // comdat readonly data.
  if (icfLevel == 1 && !doGC)
    icfLevel = 0;
  config->doGC = doGC;
  config->doICF = icfLevel > 0;
  config->tailMerge = (tailMerge == 1 && config->doICF) || tailMerge == 2;

  // Handle /lldsavetemps
  if (args.hasArg(OPT_lldsavetemps))
    config->saveTemps = true;

  // Handle /kill-at
  if (args.hasArg(OPT_kill_at))
    config->killAt = true;

  // Handle /lldltocache
  if (auto *arg = args.getLastArg(OPT_lldltocache))
    config->ltoCache = arg->getValue();

  // Handle /lldsavecachepolicy
  if (auto *arg = args.getLastArg(OPT_lldltocachepolicy))
    config->ltoCachePolicy = CHECK(
        parseCachePruningPolicy(arg->getValue()),
        Twine("/lldltocachepolicy: invalid cache policy: ") + arg->getValue());

  // Handle /failifmismatch
  for (auto *arg : args.filtered(OPT_failifmismatch))
    checkFailIfMismatch(arg->getValue(), nullptr);

  // Handle /merge
  for (auto *arg : args.filtered(OPT_merge))
    parseMerge(arg->getValue());

  // Add default section merging rules after user rules. User rules take
  // precedence, but we will emit a warning if there is a conflict.
  parseMerge(".idata=.rdata");
  parseMerge(".didat=.rdata");
  parseMerge(".edata=.rdata");
  parseMerge(".xdata=.rdata");
  parseMerge(".bss=.data");

  if (config->mingw) {
    parseMerge(".ctors=.rdata");
    parseMerge(".dtors=.rdata");
    parseMerge(".CRT=.rdata");
  }

  // Handle /section
  for (auto *arg : args.filtered(OPT_section))
    parseSection(arg->getValue());

  // Handle /align
  if (auto *arg = args.getLastArg(OPT_align)) {
    parseNumbers(arg->getValue(), &config->align);
    if (!isPowerOf2_64(config->align))
      error("/align: not a power of two: " + StringRef(arg->getValue()));
  }

  // Handle /aligncomm
  for (auto *arg : args.filtered(OPT_aligncomm))
    parseAligncomm(arg->getValue());

  // Handle /manifestdependency. This enables /manifest unless /manifest:no is
  // also passed.
  if (auto *arg = args.getLastArg(OPT_manifestdependency)) {
    config->manifestDependency = arg->getValue();
    config->manifest = Configuration::SideBySide;
  }

  // Handle /manifest and /manifest:
  if (auto *arg = args.getLastArg(OPT_manifest, OPT_manifest_colon)) {
    if (arg->getOption().getID() == OPT_manifest)
      config->manifest = Configuration::SideBySide;
    else
      parseManifest(arg->getValue());
  }

  // Handle /manifestuac
  if (auto *arg = args.getLastArg(OPT_manifestuac))
    parseManifestUAC(arg->getValue());

  // Handle /manifestfile
  if (auto *arg = args.getLastArg(OPT_manifestfile))
    config->manifestFile = arg->getValue();

  // Handle /manifestinput
  for (auto *arg : args.filtered(OPT_manifestinput))
    config->manifestInput.push_back(arg->getValue());

  if (!config->manifestInput.empty() &&
      config->manifest != Configuration::Embed) {
    fatal("/manifestinput: requires /manifest:embed");
  }

  config->thinLTOEmitImportsFiles = args.hasArg(OPT_thinlto_emit_imports_files);
  config->thinLTOIndexOnly = args.hasArg(OPT_thinlto_index_only) ||
                             args.hasArg(OPT_thinlto_index_only_arg);
  config->thinLTOIndexOnlyArg =
      args.getLastArgValue(OPT_thinlto_index_only_arg);
  config->thinLTOPrefixReplace =
      getOldNewOptions(args, OPT_thinlto_prefix_replace);
  config->thinLTOObjectSuffixReplace =
      getOldNewOptions(args, OPT_thinlto_object_suffix_replace);
  // Handle miscellaneous boolean flags.
  config->allowBind = args.hasFlag(OPT_allowbind, OPT_allowbind_no, true);
  config->allowIsolation =
      args.hasFlag(OPT_allowisolation, OPT_allowisolation_no, true);
  config->incremental =
      args.hasFlag(OPT_incremental, OPT_incremental_no,
                   !config->doGC && !config->doICF && !args.hasArg(OPT_order) &&
                       !args.hasArg(OPT_profile));
  config->integrityCheck =
      args.hasFlag(OPT_integritycheck, OPT_integritycheck_no, false);
  config->nxCompat = args.hasFlag(OPT_nxcompat, OPT_nxcompat_no, true);
  for (auto *arg : args.filtered(OPT_swaprun))
    parseSwaprun(arg->getValue());
  config->terminalServerAware =
      !config->dll && args.hasFlag(OPT_tsaware, OPT_tsaware_no, true);
  config->debugDwarf = debug == DebugKind::Dwarf;
  config->debugGHashes = debug == DebugKind::GHash;
  config->debugSymtab = debug == DebugKind::Symtab;

  config->mapFile = getMapFile(args);

  if (config->incremental && args.hasArg(OPT_profile)) {
    warn("ignoring '/incremental' due to '/profile' specification");
    config->incremental = false;
  }

  if (config->incremental && args.hasArg(OPT_order)) {
    warn("ignoring '/incremental' due to '/order' specification");
    config->incremental = false;
  }

  if (config->incremental && config->doGC) {
    warn("ignoring '/incremental' because REF is enabled; use '/opt:noref' to "
         "disable");
    config->incremental = false;
  }

  if (config->incremental && config->doICF) {
    warn("ignoring '/incremental' because ICF is enabled; use '/opt:noicf' to "
         "disable");
    config->incremental = false;
  }

  if (errorCount())
    return;

  std::set<sys::fs::UniqueID> wholeArchives;
  for (auto *arg : args.filtered(OPT_wholearchive_file))
    if (Optional<StringRef> path = doFindFile(arg->getValue()))
      if (Optional<sys::fs::UniqueID> id = getUniqueID(*path))
        wholeArchives.insert(*id);

  // A predicate returning true if a given path is an argument for
  // /wholearchive:, or /wholearchive is enabled globally.
  // This function is a bit tricky because "foo.obj /wholearchive:././foo.obj"
  // needs to be handled as "/wholearchive:foo.obj foo.obj".
  auto isWholeArchive = [&](StringRef path) -> bool {
    if (args.hasArg(OPT_wholearchive_flag))
      return true;
    if (Optional<sys::fs::UniqueID> id = getUniqueID(path))
      return wholeArchives.count(*id);
    return false;
  };

  // Create a list of input files. Files can be given as arguments
  // for /defaultlib option.
  for (auto *arg : args.filtered(OPT_INPUT, OPT_wholearchive_file))
    if (Optional<StringRef> path = findFile(arg->getValue()))
      enqueuePath(*path, isWholeArchive(*path));

  for (auto *arg : args.filtered(OPT_defaultlib))
    if (Optional<StringRef> path = findLib(arg->getValue()))
      enqueuePath(*path, false);

  // Windows specific -- Create a resource file containing a manifest file.
  if (config->manifest == Configuration::Embed)
    addBuffer(createManifestRes(), false);

  // Read all input files given via the command line.
  run();

  if (errorCount())
    return;

  // We should have inferred a machine type by now from the input files, but if
  // not we assume x64.
  if (config->machine == IMAGE_FILE_MACHINE_UNKNOWN) {
    warn("/machine is not specified. x64 is assumed");
    config->machine = AMD64;
  }
  config->wordsize = config->is64() ? 8 : 4;

  // Handle /safeseh, x86 only, on by default, except for mingw.
  if (config->machine == I386 &&
      args.hasFlag(OPT_safeseh, OPT_safeseh_no, !config->mingw))
    config->safeSEH = true;

  // Handle /functionpadmin
  for (auto *arg : args.filtered(OPT_functionpadmin, OPT_functionpadmin_opt))
    parseFunctionPadMin(arg, config->machine);

  // Input files can be Windows resource files (.res files). We use
  // WindowsResource to convert resource files to a regular COFF file,
  // then link the resulting file normally.
  if (!resources.empty())
    symtab->addFile(make<ObjFile>(convertResToCOFF(resources)));

  if (tar)
    tar->append("response.txt",
                createResponseFile(args, filePaths,
                                   ArrayRef<StringRef>(searchPaths).slice(1)));

  // Handle /largeaddressaware
  config->largeAddressAware = args.hasFlag(
      OPT_largeaddressaware, OPT_largeaddressaware_no, config->is64());

  // Handle /highentropyva
  config->highEntropyVA =
      config->is64() &&
      args.hasFlag(OPT_highentropyva, OPT_highentropyva_no, true);

  if (!config->dynamicBase &&
      (config->machine == ARMNT || config->machine == ARM64))
    error("/dynamicbase:no is not compatible with " +
          machineToStr(config->machine));

  // Handle /export
  for (auto *arg : args.filtered(OPT_export)) {
    Export e = parseExport(arg->getValue());
    if (config->machine == I386) {
      if (!isDecorated(e.name))
        e.name = saver.save("_" + e.name);
      if (!e.extName.empty() && !isDecorated(e.extName))
        e.extName = saver.save("_" + e.extName);
    }
    config->exports.push_back(e);
  }

  // Handle /def
  if (auto *arg = args.getLastArg(OPT_deffile)) {
    // parseModuleDefs mutates Config object.
    parseModuleDefs(arg->getValue());
  }

  // Handle generation of import library from a def file.
  if (!args.hasArg(OPT_INPUT)) {
    fixupExports();
    createImportLibrary(/*asLib=*/true);
    return;
  }

  // Windows specific -- if no /subsystem is given, we need to infer
  // that from entry point name.  Must happen before /entry handling,
  // and after the early return when just writing an import library.
  if (config->subsystem == IMAGE_SUBSYSTEM_UNKNOWN) {
    config->subsystem = inferSubsystem();
    if (config->subsystem == IMAGE_SUBSYSTEM_UNKNOWN)
      fatal("subsystem must be defined");
  }

  // Handle /entry and /dll
  if (auto *arg = args.getLastArg(OPT_entry)) {
    config->entry = addUndefined(mangle(arg->getValue()));
  } else if (!config->entry && !config->noEntry) {
    if (args.hasArg(OPT_dll)) {
      StringRef s = (config->machine == I386) ? "__DllMainCRTStartup@12"
                                              : "_DllMainCRTStartup";
      config->entry = addUndefined(s);
    } else {
      // Windows specific -- If entry point name is not given, we need to
      // infer that from user-defined entry name.
      StringRef s = findDefaultEntry();
      if (s.empty())
        fatal("entry point must be defined");
      config->entry = addUndefined(s);
      log("Entry name inferred: " + s);
    }
  }

  // Handle /delayload
  for (auto *arg : args.filtered(OPT_delayload)) {
    config->delayLoads.insert(StringRef(arg->getValue()).lower());
    if (config->machine == I386) {
      config->delayLoadHelper = addUndefined("___delayLoadHelper2@8");
    } else {
      config->delayLoadHelper = addUndefined("__delayLoadHelper2");
    }
  }

  // Set default image name if neither /out or /def set it.
  if (config->outputFile.empty()) {
    config->outputFile =
        getOutputPath((*args.filtered(OPT_INPUT).begin())->getValue());
  }

  // Fail early if an output file is not writable.
  if (auto e = tryCreateFile(config->outputFile)) {
    error("cannot open output file " + config->outputFile + ": " + e.message());
    return;
  }

  if (shouldCreatePDB) {
    // Put the PDB next to the image if no /pdb flag was passed.
    if (config->pdbPath.empty()) {
      config->pdbPath = config->outputFile;
      sys::path::replace_extension(config->pdbPath, ".pdb");
    }

    // The embedded PDB path should be the absolute path to the PDB if no
    // /pdbaltpath flag was passed.
    if (config->pdbAltPath.empty()) {
      config->pdbAltPath = config->pdbPath;

      // It's important to make the path absolute and remove dots.  This path
      // will eventually be written into the PE header, and certain Microsoft
      // tools won't work correctly if these assumptions are not held.
      sys::fs::make_absolute(config->pdbAltPath);
      sys::path::remove_dots(config->pdbAltPath);
    } else {
      // Don't do this earlier, so that Config->OutputFile is ready.
      parsePDBAltPath(config->pdbAltPath);
    }
  }

  // Set default image base if /base is not given.
  if (config->imageBase == uint64_t(-1))
    config->imageBase = getDefaultImageBase();

  symtab->addSynthetic(mangle("__ImageBase"), nullptr);
  if (config->machine == I386) {
    symtab->addAbsolute("___safe_se_handler_table", 0);
    symtab->addAbsolute("___safe_se_handler_count", 0);
  }

  symtab->addAbsolute(mangle("__guard_fids_count"), 0);
  symtab->addAbsolute(mangle("__guard_fids_table"), 0);
  symtab->addAbsolute(mangle("__guard_flags"), 0);
  symtab->addAbsolute(mangle("__guard_iat_count"), 0);
  symtab->addAbsolute(mangle("__guard_iat_table"), 0);
  symtab->addAbsolute(mangle("__guard_longjmp_count"), 0);
  symtab->addAbsolute(mangle("__guard_longjmp_table"), 0);
  // Needed for MSVC 2017 15.5 CRT.
  symtab->addAbsolute(mangle("__enclave_config"), 0);

  if (config->mingw) {
    symtab->addAbsolute(mangle("__RUNTIME_PSEUDO_RELOC_LIST__"), 0);
    symtab->addAbsolute(mangle("__RUNTIME_PSEUDO_RELOC_LIST_END__"), 0);
    symtab->addAbsolute(mangle("__CTOR_LIST__"), 0);
    symtab->addAbsolute(mangle("__DTOR_LIST__"), 0);
  }

  // This code may add new undefined symbols to the link, which may enqueue more
  // symbol resolution tasks, so we need to continue executing tasks until we
  // converge.
  do {
    // Windows specific -- if entry point is not found,
    // search for its mangled names.
    if (config->entry)
      mangleMaybe(config->entry);

    // Windows specific -- Make sure we resolve all dllexported symbols.
    for (Export &e : config->exports) {
      if (!e.forwardTo.empty())
        continue;
      e.sym = addUndefined(e.name);
      if (!e.directives)
        e.symbolName = mangleMaybe(e.sym);
    }

    // Add weak aliases. Weak aliases is a mechanism to give remaining
    // undefined symbols final chance to be resolved successfully.
    for (auto pair : config->alternateNames) {
      StringRef from = pair.first;
      StringRef to = pair.second;
      Symbol *sym = symtab->find(from);
      if (!sym)
        continue;
      if (auto *u = dyn_cast<Undefined>(sym))
        if (!u->weakAlias)
          u->weakAlias = symtab->addUndefined(to);
    }

    // If any inputs are bitcode files, the LTO code generator may create
    // references to library functions that are not explicit in the bitcode
    // file's symbol table. If any of those library functions are defined in a
    // bitcode file in an archive member, we need to arrange to use LTO to
    // compile those archive members by adding them to the link beforehand.
    if (!BitcodeFile::instances.empty())
      for (const char *s : libcallRoutineNames)
        symtab->addLibcall(s);

    // Windows specific -- if __load_config_used can be resolved, resolve it.
    if (symtab->findUnderscore("_load_config_used"))
      addUndefined(mangle("_load_config_used"));
  } while (run());

  if (errorCount())
    return;

  // Do LTO by compiling bitcode input files to a set of native COFF files then
  // link those files (unless -thinlto-index-only was given, in which case we
  // resolve symbols and write indices, but don't generate native code or link).
  symtab->addCombinedLTOObjects();

  // If -thinlto-index-only is given, we should create only "index
  // files" and not object files. Index file creation is already done
  // in addCombinedLTOObject, so we are done if that's the case.
  if (config->thinLTOIndexOnly)
    return;

  // If we generated native object files from bitcode files, this resolves
  // references to the symbols we use from them.
  run();

  if (args.hasArg(OPT_include_optional)) {
    // Handle /includeoptional
    for (auto *arg : args.filtered(OPT_include_optional))
      if (dyn_cast_or_null<Lazy>(symtab->find(arg->getValue())))
        addUndefined(arg->getValue());
    while (run());
  }

  if (config->mingw) {
    // Load any further object files that might be needed for doing automatic
    // imports.
    //
    // For cases with no automatically imported symbols, this iterates once
    // over the symbol table and doesn't do anything.
    //
    // For the normal case with a few automatically imported symbols, this
    // should only need to be run once, since each new object file imported
    // is an import library and wouldn't add any new undefined references,
    // but there's nothing stopping the __imp_ symbols from coming from a
    // normal object file as well (although that won't be used for the
    // actual autoimport later on). If this pass adds new undefined references,
    // we won't iterate further to resolve them.
    symtab->loadMinGWAutomaticImports();
    run();
  }

  // Make sure we have resolved all symbols.
  symtab->reportRemainingUndefines();
  if (errorCount())
    return;

  if (config->mingw) {
    // In MinGW, all symbols are automatically exported if no symbols
    // are chosen to be exported.
    maybeExportMinGWSymbols(args);

    // Make sure the crtend.o object is the last object file. This object
    // file can contain terminating section chunks that need to be placed
    // last. GNU ld processes files and static libraries explicitly in the
    // order provided on the command line, while lld will pull in needed
    // files from static libraries only after the last object file on the
    // command line.
    for (auto i = ObjFile::instances.begin(), e = ObjFile::instances.end();
         i != e; i++) {
      ObjFile *file = *i;
      if (isCrtend(file->getName())) {
        ObjFile::instances.erase(i);
        ObjFile::instances.push_back(file);
        break;
      }
    }
  }

  // Windows specific -- when we are creating a .dll file, we also
  // need to create a .lib file.
  if (!config->exports.empty() || config->dll) {
    fixupExports();
    createImportLibrary(/*asLib=*/false);
    assignExportOrdinals();
  }

  // Handle /output-def (MinGW specific).
  if (auto *arg = args.getLastArg(OPT_output_def))
    writeDefFile(arg->getValue());

  // Set extra alignment for .comm symbols
  for (auto pair : config->alignComm) {
    StringRef name = pair.first;
    uint32_t alignment = pair.second;

    Symbol *sym = symtab->find(name);
    if (!sym) {
      warn("/aligncomm symbol " + name + " not found");
      continue;
    }

    // If the symbol isn't common, it must have been replaced with a regular
    // symbol, which will carry its own alignment.
    auto *dc = dyn_cast<DefinedCommon>(sym);
    if (!dc)
      continue;

    CommonChunk *c = dc->getChunk();
    c->setAlignment(std::max(c->getAlignment(), alignment));
  }

  // Windows specific -- Create a side-by-side manifest file.
  if (config->manifest == Configuration::SideBySide)
    createSideBySideManifest();

  // Handle /order. We want to do this at this moment because we
  // need a complete list of comdat sections to warn on nonexistent
  // functions.
  if (auto *arg = args.getLastArg(OPT_order))
    parseOrderFile(arg->getValue());

  // Identify unreferenced COMDAT sections.
  if (config->doGC)
    markLive(symtab->getChunks());

  // Needs to happen after the last call to addFile().
  diagnoseMultipleResourceObjFiles();

  // Identify identical COMDAT sections to merge them.
  if (config->doICF) {
    findKeepUniqueSections();
    doICF(symtab->getChunks());
  }

  // Write the result.
  writeResult();

  // Stop early so we can print the results.
  Timer::root().stop();
  if (config->showTiming)
    Timer::root().print();
}

} // namespace coff
} // namespace lld
