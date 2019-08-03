//===- DriverUtils.cpp ----------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains utility functions for the driver. Because there
// are so many small functions, we created this separate file to make
// Driver.cpp less cluttered.
//
//===----------------------------------------------------------------------===//

#include "Config.h"
#include "Driver.h"
#include "Symbols.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "llvm/ADT/Optional.h"
#include "llvm/ADT/StringSwitch.h"
#include "llvm/BinaryFormat/COFF.h"
#include "llvm/Object/COFF.h"
#include "llvm/Object/WindowsResource.h"
#include "llvm/Option/Arg.h"
#include "llvm/Option/ArgList.h"
#include "llvm/Option/Option.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/FileUtilities.h"
#include "llvm/Support/MathExtras.h"
#include "llvm/Support/Process.h"
#include "llvm/Support/Program.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/WindowsManifest/WindowsManifestMerger.h"
#include <memory>

using namespace llvm::COFF;
using namespace llvm;
using llvm::sys::Process;

namespace lld {
namespace coff {
namespace {

const uint16_t SUBLANG_ENGLISH_US = 0x0409;
const uint16_t RT_MANIFEST = 24;

class Executor {
public:
  explicit Executor(StringRef s) : prog(saver.save(s)) {}
  void add(StringRef s) { args.push_back(saver.save(s)); }
  void add(std::string &s) { args.push_back(saver.save(s)); }
  void add(Twine s) { args.push_back(saver.save(s)); }
  void add(const char *s) { args.push_back(saver.save(s)); }

  void run() {
    ErrorOr<std::string> exeOrErr = sys::findProgramByName(prog);
    if (auto ec = exeOrErr.getError())
      fatal("unable to find " + prog + " in PATH: " + ec.message());
    StringRef exe = saver.save(*exeOrErr);
    args.insert(args.begin(), exe);

    if (sys::ExecuteAndWait(args[0], args) != 0)
      fatal("ExecuteAndWait failed: " +
            llvm::join(args.begin(), args.end(), " "));
  }

private:
  StringRef prog;
  std::vector<StringRef> args;
};

} // anonymous namespace

// Parses a string in the form of "<integer>[,<integer>]".
void parseNumbers(StringRef arg, uint64_t *addr, uint64_t *size) {
  StringRef s1, s2;
  std::tie(s1, s2) = arg.split(',');
  if (s1.getAsInteger(0, *addr))
    fatal("invalid number: " + s1);
  if (size && !s2.empty() && s2.getAsInteger(0, *size))
    fatal("invalid number: " + s2);
}

// Parses a string in the form of "<integer>[.<integer>]".
// If second number is not present, Minor is set to 0.
void parseVersion(StringRef arg, uint32_t *major, uint32_t *minor) {
  StringRef s1, s2;
  std::tie(s1, s2) = arg.split('.');
  if (s1.getAsInteger(0, *major))
    fatal("invalid number: " + s1);
  *minor = 0;
  if (!s2.empty() && s2.getAsInteger(0, *minor))
    fatal("invalid number: " + s2);
}

void parseGuard(StringRef fullArg) {
  SmallVector<StringRef, 1> splitArgs;
  fullArg.split(splitArgs, ",");
  for (StringRef arg : splitArgs) {
    if (arg.equals_lower("no"))
      config->guardCF = GuardCFLevel::Off;
    else if (arg.equals_lower("nolongjmp"))
      config->guardCF = GuardCFLevel::NoLongJmp;
    else if (arg.equals_lower("cf") || arg.equals_lower("longjmp"))
      config->guardCF = GuardCFLevel::Full;
    else
      fatal("invalid argument to /guard: " + arg);
  }
}

// Parses a string in the form of "<subsystem>[,<integer>[.<integer>]]".
void parseSubsystem(StringRef arg, WindowsSubsystem *sys, uint32_t *major,
                    uint32_t *minor) {
  StringRef sysStr, ver;
  std::tie(sysStr, ver) = arg.split(',');
  std::string sysStrLower = sysStr.lower();
  *sys = StringSwitch<WindowsSubsystem>(sysStrLower)
    .Case("boot_application", IMAGE_SUBSYSTEM_WINDOWS_BOOT_APPLICATION)
    .Case("console", IMAGE_SUBSYSTEM_WINDOWS_CUI)
    .Case("default", IMAGE_SUBSYSTEM_UNKNOWN)
    .Case("efi_application", IMAGE_SUBSYSTEM_EFI_APPLICATION)
    .Case("efi_boot_service_driver", IMAGE_SUBSYSTEM_EFI_BOOT_SERVICE_DRIVER)
    .Case("efi_rom", IMAGE_SUBSYSTEM_EFI_ROM)
    .Case("efi_runtime_driver", IMAGE_SUBSYSTEM_EFI_RUNTIME_DRIVER)
    .Case("native", IMAGE_SUBSYSTEM_NATIVE)
    .Case("posix", IMAGE_SUBSYSTEM_POSIX_CUI)
    .Case("windows", IMAGE_SUBSYSTEM_WINDOWS_GUI)
    .Default(IMAGE_SUBSYSTEM_UNKNOWN);
  if (*sys == IMAGE_SUBSYSTEM_UNKNOWN && sysStrLower != "default")
    fatal("unknown subsystem: " + sysStr);
  if (!ver.empty())
    parseVersion(ver, major, minor);
}

// Parse a string of the form of "<from>=<to>".
// Results are directly written to Config.
void parseAlternateName(StringRef s) {
  StringRef from, to;
  std::tie(from, to) = s.split('=');
  if (from.empty() || to.empty())
    fatal("/alternatename: invalid argument: " + s);
  auto it = config->alternateNames.find(from);
  if (it != config->alternateNames.end() && it->second != to)
    fatal("/alternatename: conflicts: " + s);
  config->alternateNames.insert(it, std::make_pair(from, to));
}

// Parse a string of the form of "<from>=<to>".
// Results are directly written to Config.
void parseMerge(StringRef s) {
  StringRef from, to;
  std::tie(from, to) = s.split('=');
  if (from.empty() || to.empty())
    fatal("/merge: invalid argument: " + s);
  if (from == ".rsrc" || to == ".rsrc")
    fatal("/merge: cannot merge '.rsrc' with any section");
  if (from == ".reloc" || to == ".reloc")
    fatal("/merge: cannot merge '.reloc' with any section");
  auto pair = config->merge.insert(std::make_pair(from, to));
  bool inserted = pair.second;
  if (!inserted) {
    StringRef existing = pair.first->second;
    if (existing != to)
      warn(s + ": already merged into " + existing);
  }
}

static uint32_t parseSectionAttributes(StringRef s) {
  uint32_t ret = 0;
  for (char c : s.lower()) {
    switch (c) {
    case 'd':
      ret |= IMAGE_SCN_MEM_DISCARDABLE;
      break;
    case 'e':
      ret |= IMAGE_SCN_MEM_EXECUTE;
      break;
    case 'k':
      ret |= IMAGE_SCN_MEM_NOT_CACHED;
      break;
    case 'p':
      ret |= IMAGE_SCN_MEM_NOT_PAGED;
      break;
    case 'r':
      ret |= IMAGE_SCN_MEM_READ;
      break;
    case 's':
      ret |= IMAGE_SCN_MEM_SHARED;
      break;
    case 'w':
      ret |= IMAGE_SCN_MEM_WRITE;
      break;
    default:
      fatal("/section: invalid argument: " + s);
    }
  }
  return ret;
}

// Parses /section option argument.
void parseSection(StringRef s) {
  StringRef name, attrs;
  std::tie(name, attrs) = s.split(',');
  if (name.empty() || attrs.empty())
    fatal("/section: invalid argument: " + s);
  config->section[name] = parseSectionAttributes(attrs);
}

// Parses /aligncomm option argument.
void parseAligncomm(StringRef s) {
  StringRef name, align;
  std::tie(name, align) = s.split(',');
  if (name.empty() || align.empty()) {
    error("/aligncomm: invalid argument: " + s);
    return;
  }
  int v;
  if (align.getAsInteger(0, v)) {
    error("/aligncomm: invalid argument: " + s);
    return;
  }
  config->alignComm[name] = std::max(config->alignComm[name], 1 << v);
}

// Parses /functionpadmin option argument.
void parseFunctionPadMin(llvm::opt::Arg *a, llvm::COFF::MachineTypes machine) {
  StringRef arg = a->getNumValues() ? a->getValue() : "";
  if (!arg.empty()) {
    // Optional padding in bytes is given.
    if (arg.getAsInteger(0, config->functionPadMin))
      error("/functionpadmin: invalid argument: " + arg);
    return;
  }
  // No optional argument given.
  // Set default padding based on machine, similar to link.exe.
  // There is no default padding for ARM platforms.
  if (machine == I386) {
    config->functionPadMin = 5;
  } else if (machine == AMD64) {
    config->functionPadMin = 6;
  } else {
    error("/functionpadmin: invalid argument for this machine: " + arg);
  }
}

// Parses a string in the form of "EMBED[,=<integer>]|NO".
// Results are directly written to Config.
void parseManifest(StringRef arg) {
  if (arg.equals_lower("no")) {
    config->manifest = Configuration::No;
    return;
  }
  if (!arg.startswith_lower("embed"))
    fatal("invalid option " + arg);
  config->manifest = Configuration::Embed;
  arg = arg.substr(strlen("embed"));
  if (arg.empty())
    return;
  if (!arg.startswith_lower(",id="))
    fatal("invalid option " + arg);
  arg = arg.substr(strlen(",id="));
  if (arg.getAsInteger(0, config->manifestID))
    fatal("invalid option " + arg);
}

// Parses a string in the form of "level=<string>|uiAccess=<string>|NO".
// Results are directly written to Config.
void parseManifestUAC(StringRef arg) {
  if (arg.equals_lower("no")) {
    config->manifestUAC = false;
    return;
  }
  for (;;) {
    arg = arg.ltrim();
    if (arg.empty())
      return;
    if (arg.startswith_lower("level=")) {
      arg = arg.substr(strlen("level="));
      std::tie(config->manifestLevel, arg) = arg.split(" ");
      continue;
    }
    if (arg.startswith_lower("uiaccess=")) {
      arg = arg.substr(strlen("uiaccess="));
      std::tie(config->manifestUIAccess, arg) = arg.split(" ");
      continue;
    }
    fatal("invalid option " + arg);
  }
}

// Parses a string in the form of "cd|net[,(cd|net)]*"
// Results are directly written to Config.
void parseSwaprun(StringRef arg) {
  do {
    StringRef swaprun, newArg;
    std::tie(swaprun, newArg) = arg.split(',');
    if (swaprun.equals_lower("cd"))
      config->swaprunCD = true;
    else if (swaprun.equals_lower("net"))
      config->swaprunNet = true;
    else if (swaprun.empty())
      error("/swaprun: missing argument");
    else
      error("/swaprun: invalid argument: " + swaprun);
    // To catch trailing commas, e.g. `/spawrun:cd,`
    if (newArg.empty() && arg.endswith(","))
      error("/swaprun: missing argument");
    arg = newArg;
  } while (!arg.empty());
}

// An RAII temporary file class that automatically removes a temporary file.
namespace {
class TemporaryFile {
public:
  TemporaryFile(StringRef prefix, StringRef extn, StringRef contents = "") {
    SmallString<128> s;
    if (auto ec = sys::fs::createTemporaryFile("lld-" + prefix, extn, s))
      fatal("cannot create a temporary file: " + ec.message());
    path = s.str();

    if (!contents.empty()) {
      std::error_code ec;
      raw_fd_ostream os(path, ec, sys::fs::F_None);
      if (ec)
        fatal("failed to open " + path + ": " + ec.message());
      os << contents;
    }
  }

  TemporaryFile(TemporaryFile &&obj) {
    std::swap(path, obj.path);
  }

  ~TemporaryFile() {
    if (path.empty())
      return;
    if (sys::fs::remove(path))
      fatal("failed to remove " + path);
  }

  // Returns a memory buffer of this temporary file.
  // Note that this function does not leave the file open,
  // so it is safe to remove the file immediately after this function
  // is called (you cannot remove an opened file on Windows.)
  std::unique_ptr<MemoryBuffer> getMemoryBuffer() {
    // IsVolatile=true forces MemoryBuffer to not use mmap().
    return CHECK(MemoryBuffer::getFile(path, /*FileSize=*/-1,
                                       /*RequiresNullTerminator=*/false,
                                       /*IsVolatile=*/true),
                 "could not open " + path);
  }

  std::string path;
};
}

static std::string createDefaultXml() {
  std::string ret;
  raw_string_ostream os(ret);

  // Emit the XML. Note that we do *not* verify that the XML attributes are
  // syntactically correct. This is intentional for link.exe compatibility.
  os << "<?xml version=\"1.0\" standalone=\"yes\"?>\n"
     << "<assembly xmlns=\"urn:schemas-microsoft-com:asm.v1\"\n"
     << "          manifestVersion=\"1.0\">\n";
  if (config->manifestUAC) {
    os << "  <trustInfo>\n"
       << "    <security>\n"
       << "      <requestedPrivileges>\n"
       << "         <requestedExecutionLevel level=" << config->manifestLevel
       << " uiAccess=" << config->manifestUIAccess << "/>\n"
       << "      </requestedPrivileges>\n"
       << "    </security>\n"
       << "  </trustInfo>\n";
  }
  if (!config->manifestDependency.empty()) {
    os << "  <dependency>\n"
       << "    <dependentAssembly>\n"
       << "      <assemblyIdentity " << config->manifestDependency << " />\n"
       << "    </dependentAssembly>\n"
       << "  </dependency>\n";
  }
  os << "</assembly>\n";
  return os.str();
}

static std::string createManifestXmlWithInternalMt(StringRef defaultXml) {
  std::unique_ptr<MemoryBuffer> defaultXmlCopy =
      MemoryBuffer::getMemBufferCopy(defaultXml);

  windows_manifest::WindowsManifestMerger merger;
  if (auto e = merger.merge(*defaultXmlCopy.get()))
    fatal("internal manifest tool failed on default xml: " +
          toString(std::move(e)));

  for (StringRef filename : config->manifestInput) {
    std::unique_ptr<MemoryBuffer> manifest =
        check(MemoryBuffer::getFile(filename));
    if (auto e = merger.merge(*manifest.get()))
      fatal("internal manifest tool failed on file " + filename + ": " +
            toString(std::move(e)));
  }

  return merger.getMergedManifest().get()->getBuffer();
}

static std::string createManifestXmlWithExternalMt(StringRef defaultXml) {
  // Create the default manifest file as a temporary file.
  TemporaryFile Default("defaultxml", "manifest");
  std::error_code ec;
  raw_fd_ostream os(Default.path, ec, sys::fs::F_Text);
  if (ec)
    fatal("failed to open " + Default.path + ": " + ec.message());
  os << defaultXml;
  os.close();

  // Merge user-supplied manifests if they are given.  Since libxml2 is not
  // enabled, we must shell out to Microsoft's mt.exe tool.
  TemporaryFile user("user", "manifest");

  Executor e("mt.exe");
  e.add("/manifest");
  e.add(Default.path);
  for (StringRef filename : config->manifestInput) {
    e.add("/manifest");
    e.add(filename);
  }
  e.add("/nologo");
  e.add("/out:" + StringRef(user.path));
  e.run();

  return CHECK(MemoryBuffer::getFile(user.path), "could not open " + user.path)
      .get()
      ->getBuffer();
}

static std::string createManifestXml() {
  std::string defaultXml = createDefaultXml();
  if (config->manifestInput.empty())
    return defaultXml;

  if (windows_manifest::isAvailable())
    return createManifestXmlWithInternalMt(defaultXml);

  return createManifestXmlWithExternalMt(defaultXml);
}

static std::unique_ptr<WritableMemoryBuffer>
createMemoryBufferForManifestRes(size_t manifestSize) {
  size_t resSize = alignTo(
      object::WIN_RES_MAGIC_SIZE + object::WIN_RES_NULL_ENTRY_SIZE +
          sizeof(object::WinResHeaderPrefix) + sizeof(object::WinResIDs) +
          sizeof(object::WinResHeaderSuffix) + manifestSize,
      object::WIN_RES_DATA_ALIGNMENT);
  return WritableMemoryBuffer::getNewMemBuffer(resSize, config->outputFile +
                                                            ".manifest.res");
}

static void writeResFileHeader(char *&buf) {
  memcpy(buf, COFF::WinResMagic, sizeof(COFF::WinResMagic));
  buf += sizeof(COFF::WinResMagic);
  memset(buf, 0, object::WIN_RES_NULL_ENTRY_SIZE);
  buf += object::WIN_RES_NULL_ENTRY_SIZE;
}

static void writeResEntryHeader(char *&buf, size_t manifestSize) {
  // Write the prefix.
  auto *prefix = reinterpret_cast<object::WinResHeaderPrefix *>(buf);
  prefix->DataSize = manifestSize;
  prefix->HeaderSize = sizeof(object::WinResHeaderPrefix) +
                       sizeof(object::WinResIDs) +
                       sizeof(object::WinResHeaderSuffix);
  buf += sizeof(object::WinResHeaderPrefix);

  // Write the Type/Name IDs.
  auto *iDs = reinterpret_cast<object::WinResIDs *>(buf);
  iDs->setType(RT_MANIFEST);
  iDs->setName(config->manifestID);
  buf += sizeof(object::WinResIDs);

  // Write the suffix.
  auto *suffix = reinterpret_cast<object::WinResHeaderSuffix *>(buf);
  suffix->DataVersion = 0;
  suffix->MemoryFlags = object::WIN_RES_PURE_MOVEABLE;
  suffix->Language = SUBLANG_ENGLISH_US;
  suffix->Version = 0;
  suffix->Characteristics = 0;
  buf += sizeof(object::WinResHeaderSuffix);
}

// Create a resource file containing a manifest XML.
std::unique_ptr<MemoryBuffer> createManifestRes() {
  std::string manifest = createManifestXml();

  std::unique_ptr<WritableMemoryBuffer> res =
      createMemoryBufferForManifestRes(manifest.size());

  char *buf = res->getBufferStart();
  writeResFileHeader(buf);
  writeResEntryHeader(buf, manifest.size());

  // Copy the manifest data into the .res file.
  std::copy(manifest.begin(), manifest.end(), buf);
  return std::move(res);
}

void createSideBySideManifest() {
  std::string path = config->manifestFile;
  if (path == "")
    path = config->outputFile + ".manifest";
  std::error_code ec;
  raw_fd_ostream out(path, ec, sys::fs::F_Text);
  if (ec)
    fatal("failed to create manifest: " + ec.message());
  out << createManifestXml();
}

// Parse a string in the form of
// "<name>[=<internalname>][,@ordinal[,NONAME]][,DATA][,PRIVATE]"
// or "<name>=<dllname>.<name>".
// Used for parsing /export arguments.
Export parseExport(StringRef arg) {
  Export e;
  StringRef rest;
  std::tie(e.name, rest) = arg.split(",");
  if (e.name.empty())
    goto err;

  if (e.name.contains('=')) {
    StringRef x, y;
    std::tie(x, y) = e.name.split("=");

    // If "<name>=<dllname>.<name>".
    if (y.contains(".")) {
      e.name = x;
      e.forwardTo = y;
      return e;
    }

    e.extName = x;
    e.name = y;
    if (e.name.empty())
      goto err;
  }

  // If "<name>=<internalname>[,@ordinal[,NONAME]][,DATA][,PRIVATE]"
  while (!rest.empty()) {
    StringRef tok;
    std::tie(tok, rest) = rest.split(",");
    if (tok.equals_lower("noname")) {
      if (e.ordinal == 0)
        goto err;
      e.noname = true;
      continue;
    }
    if (tok.equals_lower("data")) {
      e.data = true;
      continue;
    }
    if (tok.equals_lower("constant")) {
      e.constant = true;
      continue;
    }
    if (tok.equals_lower("private")) {
      e.isPrivate = true;
      continue;
    }
    if (tok.startswith("@")) {
      int32_t ord;
      if (tok.substr(1).getAsInteger(0, ord))
        goto err;
      if (ord <= 0 || 65535 < ord)
        goto err;
      e.ordinal = ord;
      continue;
    }
    goto err;
  }
  return e;

err:
  fatal("invalid /export: " + arg);
}

static StringRef undecorate(StringRef sym) {
  if (config->machine != I386)
    return sym;
  // In MSVC mode, a fully decorated stdcall function is exported
  // as-is with the leading underscore (with type IMPORT_NAME).
  // In MinGW mode, a decorated stdcall function gets the underscore
  // removed, just like normal cdecl functions.
  if (sym.startswith("_") && sym.contains('@') && !config->mingw)
    return sym;
  return sym.startswith("_") ? sym.substr(1) : sym;
}

// Convert stdcall/fastcall style symbols into unsuffixed symbols,
// with or without a leading underscore. (MinGW specific.)
static StringRef killAt(StringRef sym, bool prefix) {
  if (sym.empty())
    return sym;
  // Strip any trailing stdcall suffix
  sym = sym.substr(0, sym.find('@', 1));
  if (!sym.startswith("@")) {
    if (prefix && !sym.startswith("_"))
      return saver.save("_" + sym);
    return sym;
  }
  // For fastcall, remove the leading @ and replace it with an
  // underscore, if prefixes are used.
  sym = sym.substr(1);
  if (prefix)
    sym = saver.save("_" + sym);
  return sym;
}

// Performs error checking on all /export arguments.
// It also sets ordinals.
void fixupExports() {
  // Symbol ordinals must be unique.
  std::set<uint16_t> ords;
  for (Export &e : config->exports) {
    if (e.ordinal == 0)
      continue;
    if (!ords.insert(e.ordinal).second)
      fatal("duplicate export ordinal: " + e.name);
  }

  for (Export &e : config->exports) {
    if (!e.forwardTo.empty()) {
      e.exportName = undecorate(e.name);
    } else {
      e.exportName = undecorate(e.extName.empty() ? e.name : e.extName);
    }
  }

  if (config->killAt && config->machine == I386) {
    for (Export &e : config->exports) {
      e.name = killAt(e.name, true);
      e.exportName = killAt(e.exportName, false);
      e.extName = killAt(e.extName, true);
      e.symbolName = killAt(e.symbolName, true);
    }
  }

  // Uniquefy by name.
  DenseMap<StringRef, Export *> map(config->exports.size());
  std::vector<Export> v;
  for (Export &e : config->exports) {
    auto pair = map.insert(std::make_pair(e.exportName, &e));
    bool inserted = pair.second;
    if (inserted) {
      v.push_back(e);
      continue;
    }
    Export *existing = pair.first->second;
    if (e == *existing || e.name != existing->name)
      continue;
    warn("duplicate /export option: " + e.name);
  }
  config->exports = std::move(v);

  // Sort by name.
  std::sort(config->exports.begin(), config->exports.end(),
            [](const Export &a, const Export &b) {
              return a.exportName < b.exportName;
            });
}

void assignExportOrdinals() {
  // Assign unique ordinals if default (= 0).
  uint16_t max = 0;
  for (Export &e : config->exports)
    max = std::max(max, e.ordinal);
  for (Export &e : config->exports)
    if (e.ordinal == 0)
      e.ordinal = ++max;
}

// Parses a string in the form of "key=value" and check
// if value matches previous values for the same key.
void checkFailIfMismatch(StringRef arg, InputFile *source) {
  StringRef k, v;
  std::tie(k, v) = arg.split('=');
  if (k.empty() || v.empty())
    fatal("/failifmismatch: invalid argument: " + arg);
  std::pair<StringRef, InputFile *> existing = config->mustMatch[k];
  if (!existing.first.empty() && v != existing.first) {
    std::string sourceStr = source ? toString(source) : "cmd-line";
    std::string existingStr =
        existing.second ? toString(existing.second) : "cmd-line";
    fatal("/failifmismatch: mismatch detected for '" + k + "':\n>>> " +
          existingStr + " has value " + existing.first + "\n>>> " + sourceStr +
          " has value " + v);
  }
  config->mustMatch[k] = {v, source};
}

// Convert Windows resource files (.res files) to a .obj file.
// Does what cvtres.exe does, but in-process and cross-platform.
MemoryBufferRef convertResToCOFF(ArrayRef<MemoryBufferRef> mbs) {
  object::WindowsResourceParser parser;

  for (MemoryBufferRef mb : mbs) {
    std::unique_ptr<object::Binary> bin = check(object::createBinary(mb));
    object::WindowsResource *rf = dyn_cast<object::WindowsResource>(bin.get());
    if (!rf)
      fatal("cannot compile non-resource file as resource");

    std::vector<std::string> duplicates;
    if (auto ec = parser.parse(rf, duplicates))
      fatal(toString(std::move(ec)));

    for (const auto &dupeDiag : duplicates)
      if (config->forceMultipleRes)
        warn(dupeDiag);
      else
        error(dupeDiag);
  }

  Expected<std::unique_ptr<MemoryBuffer>> e =
      llvm::object::writeWindowsResourceCOFF(config->machine, parser,
                                             config->timestamp);
  if (!e)
    fatal("failed to write .res to COFF: " + toString(e.takeError()));

  MemoryBufferRef mbref = **e;
  make<std::unique_ptr<MemoryBuffer>>(std::move(*e)); // take ownership
  return mbref;
}

// Create OptTable

// Create prefix string literals used in Options.td
#define PREFIX(NAME, VALUE) const char *const NAME[] = VALUE;
#include "Options.inc"
#undef PREFIX

// Create table mapping all options defined in Options.td
static const llvm::opt::OptTable::Info infoTable[] = {
#define OPTION(X1, X2, ID, KIND, GROUP, ALIAS, X7, X8, X9, X10, X11, X12)      \
  {X1, X2, X10,         X11,         OPT_##ID, llvm::opt::Option::KIND##Class, \
   X9, X8, OPT_##GROUP, OPT_##ALIAS, X7,       X12},
#include "Options.inc"
#undef OPTION
};

COFFOptTable::COFFOptTable() : OptTable(infoTable, true) {}

// Set color diagnostics according to --color-diagnostics={auto,always,never}
// or --no-color-diagnostics flags.
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

static cl::TokenizerCallback getQuotingStyle(opt::InputArgList &args) {
  if (auto *arg = args.getLastArg(OPT_rsp_quoting)) {
    StringRef s = arg->getValue();
    if (s != "windows" && s != "posix")
      error("invalid response file quoting: " + s);
    if (s == "windows")
      return cl::TokenizeWindowsCommandLine;
    return cl::TokenizeGNUCommandLine;
  }
  // The COFF linker always defaults to Windows quoting.
  return cl::TokenizeWindowsCommandLine;
}

// Parses a given list of options.
opt::InputArgList ArgParser::parse(ArrayRef<const char *> argv) {
  // Make InputArgList from string vectors.
  unsigned missingIndex;
  unsigned missingCount;

  // We need to get the quoting style for response files before parsing all
  // options so we parse here before and ignore all the options but
  // --rsp-quoting.
  opt::InputArgList args = table.ParseArgs(argv, missingIndex, missingCount);

  // Expand response files (arguments in the form of @<filename>)
  // and then parse the argument again.
  SmallVector<const char *, 256> expandedArgv(argv.data(),
                                              argv.data() + argv.size());
  cl::ExpandResponseFiles(saver, getQuotingStyle(args), expandedArgv);
  args = table.ParseArgs(makeArrayRef(expandedArgv).drop_front(), missingIndex,
                         missingCount);

  // Print the real command line if response files are expanded.
  if (args.hasArg(OPT_verbose) && argv.size() != expandedArgv.size()) {
    std::string msg = "Command line:";
    for (const char *s : expandedArgv)
      msg += " " + std::string(s);
    message(msg);
  }

  // Save the command line after response file expansion so we can write it to
  // the PDB if necessary.
  config->argv = {expandedArgv.begin(), expandedArgv.end()};

  // Handle /WX early since it converts missing argument warnings to errors.
  errorHandler().fatalWarnings = args.hasFlag(OPT_WX, OPT_WX_no, false);

  if (missingCount)
    fatal(Twine(args.getArgString(missingIndex)) + ": missing argument");

  handleColorDiagnostics(args);

  for (auto *arg : args.filtered(OPT_UNKNOWN)) {
    std::string nearest;
    if (table.findNearest(arg->getAsString(args), nearest) > 1)
      warn("ignoring unknown argument '" + arg->getAsString(args) + "'");
    else
      warn("ignoring unknown argument '" + arg->getAsString(args) +
           "', did you mean '" + nearest + "'");
  }

  if (args.hasArg(OPT_lib))
    warn("ignoring /lib since it's not the first argument");

  return args;
}

// Tokenizes and parses a given string as command line in .drective section.
// /EXPORT options are processed in fastpath.
std::pair<opt::InputArgList, std::vector<StringRef>>
ArgParser::parseDirectives(StringRef s) {
  std::vector<StringRef> exports;
  SmallVector<const char *, 16> rest;

  for (StringRef tok : tokenize(s)) {
    if (tok.startswith_lower("/export:") || tok.startswith_lower("-export:"))
      exports.push_back(tok.substr(strlen("/export:")));
    else
      rest.push_back(tok.data());
  }

  // Make InputArgList from unparsed string vectors.
  unsigned missingIndex;
  unsigned missingCount;

  opt::InputArgList args = table.ParseArgs(rest, missingIndex, missingCount);

  if (missingCount)
    fatal(Twine(args.getArgString(missingIndex)) + ": missing argument");
  for (auto *arg : args.filtered(OPT_UNKNOWN))
    warn("ignoring unknown argument: " + arg->getAsString(args));
  return {std::move(args), std::move(exports)};
}

// link.exe has an interesting feature. If LINK or _LINK_ environment
// variables exist, their contents are handled as command line strings.
// So you can pass extra arguments using them.
opt::InputArgList ArgParser::parseLINK(std::vector<const char *> argv) {
  // Concatenate LINK env and command line arguments, and then parse them.
  if (Optional<std::string> s = Process::GetEnv("LINK")) {
    std::vector<const char *> v = tokenize(*s);
    argv.insert(std::next(argv.begin()), v.begin(), v.end());
  }
  if (Optional<std::string> s = Process::GetEnv("_LINK_")) {
    std::vector<const char *> v = tokenize(*s);
    argv.insert(std::next(argv.begin()), v.begin(), v.end());
  }
  return parse(argv);
}

std::vector<const char *> ArgParser::tokenize(StringRef s) {
  SmallVector<const char *, 16> tokens;
  cl::TokenizeWindowsCommandLine(s, saver, tokens);
  return std::vector<const char *>(tokens.begin(), tokens.end());
}

void printHelp(const char *argv0) {
  COFFOptTable().PrintHelp(outs(),
                           (std::string(argv0) + " [options] file...").c_str(),
                           "LLVM Linker", false);
}

} // namespace coff
} // namespace lld
