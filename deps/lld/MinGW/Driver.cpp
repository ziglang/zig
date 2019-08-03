//===- MinGW/Driver.cpp ---------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// MinGW is a GNU development environment for Windows. It consists of GNU
// tools such as GCC and GNU ld. Unlike Cygwin, there's no POSIX-compatible
// layer, as it aims to be a native development toolchain.
//
// lld/MinGW is a drop-in replacement for GNU ld/MinGW.
//
// Being a native development tool, a MinGW linker is not very different from
// Microsoft link.exe, so a MinGW linker can be implemented as a thin wrapper
// for lld/COFF. This driver takes Unix-ish command line options, translates
// them to Windows-ish ones, and then passes them to lld/COFF.
//
// When this driver calls the lld/COFF driver, it passes a hidden option
// "-lldmingw" along with other user-supplied options, to run the lld/COFF
// linker in "MinGW mode".
//
// There are subtle differences between MS link.exe and GNU ld/MinGW, and GNU
// ld/MinGW implements a few GNU-specific features. Such features are directly
// implemented in lld/COFF and enabled only when the linker is running in MinGW
// mode.
//
//===----------------------------------------------------------------------===//

#include "lld/Common/Driver.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "lld/Common/Version.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/Optional.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/Triple.h"
#include "llvm/Option/Arg.h"
#include "llvm/Option/ArgList.h"
#include "llvm/Option/Option.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/Path.h"

#if !defined(_MSC_VER) && !defined(__MINGW32__)
#include <unistd.h>
#endif

using namespace lld;
using namespace llvm;

// Create OptTable
enum {
  OPT_INVALID = 0,
#define OPTION(_1, _2, ID, _4, _5, _6, _7, _8, _9, _10, _11, _12) OPT_##ID,
#include "Options.inc"
#undef OPTION
};

// Create prefix string literals used in Options.td
#define PREFIX(NAME, VALUE) static const char *const NAME[] = VALUE;
#include "Options.inc"
#undef PREFIX

// Create table mapping all options defined in Options.td
static const opt::OptTable::Info infoTable[] = {
#define OPTION(X1, X2, ID, KIND, GROUP, ALIAS, X7, X8, X9, X10, X11, X12)      \
  {X1, X2, X10,         X11,         OPT_##ID, opt::Option::KIND##Class,       \
   X9, X8, OPT_##GROUP, OPT_##ALIAS, X7,       X12},
#include "Options.inc"
#undef OPTION
};

namespace {
class MinGWOptTable : public opt::OptTable {
public:
  MinGWOptTable() : OptTable(infoTable, false) {}
  opt::InputArgList parse(ArrayRef<const char *> argv);
};
} // namespace

static void printHelp(const char *argv0) {
  MinGWOptTable().PrintHelp(
      outs(), (std::string(argv0) + " [options] file...").c_str(), "lld",
      false /*ShowHidden*/, true /*ShowAllAliases*/);
  outs() << "\n";
}

static cl::TokenizerCallback getQuotingStyle() {
  if (Triple(sys::getProcessTriple()).getOS() == Triple::Win32)
    return cl::TokenizeWindowsCommandLine;
  return cl::TokenizeGNUCommandLine;
}

opt::InputArgList MinGWOptTable::parse(ArrayRef<const char *> argv) {
  unsigned missingIndex;
  unsigned missingCount;

  SmallVector<const char *, 256> vec(argv.data(), argv.data() + argv.size());
  cl::ExpandResponseFiles(saver, getQuotingStyle(), vec);
  opt::InputArgList args = this->ParseArgs(vec, missingIndex, missingCount);

  if (missingCount)
    fatal(StringRef(args.getArgString(missingIndex)) + ": missing argument");
  for (auto *arg : args.filtered(OPT_UNKNOWN))
    fatal("unknown argument: " + arg->getAsString(args));
  return args;
}

// Find a file by concatenating given paths.
static Optional<std::string> findFile(StringRef path1, const Twine &path2) {
  SmallString<128> s;
  sys::path::append(s, path1, path2);
  if (sys::fs::exists(s))
    return s.str().str();
  return None;
}

// This is for -lfoo. We'll look for libfoo.dll.a or libfoo.a from search paths.
static std::string
searchLibrary(StringRef name, ArrayRef<StringRef> searchPaths, bool bStatic) {
  if (name.startswith(":")) {
    for (StringRef dir : searchPaths)
      if (Optional<std::string> s = findFile(dir, name.substr(1)))
        return *s;
    fatal("unable to find library -l" + name);
  }

  for (StringRef dir : searchPaths) {
    if (!bStatic)
      if (Optional<std::string> s = findFile(dir, "lib" + name + ".dll.a"))
        return *s;
    if (Optional<std::string> s = findFile(dir, "lib" + name + ".a"))
      return *s;
  }
  fatal("unable to find library -l" + name);
}

// Convert Unix-ish command line arguments to Windows-ish ones and
// then call coff::link.
bool mingw::link(ArrayRef<const char *> argsArr, raw_ostream &diag) {
  MinGWOptTable parser;
  opt::InputArgList args = parser.parse(argsArr.slice(1));

  if (args.hasArg(OPT_help)) {
    printHelp(argsArr[0]);
    return true;
  }

  // A note about "compatible with GNU linkers" message: this is a hack for
  // scripts generated by GNU Libtool 2.4.6 (released in February 2014 and
  // still the newest version in March 2017) or earlier to recognize LLD as
  // a GNU compatible linker. As long as an output for the -v option
  // contains "GNU" or "with BFD", they recognize us as GNU-compatible.
  if (args.hasArg(OPT_v) || args.hasArg(OPT_version))
    message(getLLDVersion() + " (compatible with GNU linkers)");

  // The behavior of -v or --version is a bit strange, but this is
  // needed for compatibility with GNU linkers.
  if (args.hasArg(OPT_v) && !args.hasArg(OPT_INPUT) && !args.hasArg(OPT_l))
    return true;
  if (args.hasArg(OPT_version))
    return true;

  if (!args.hasArg(OPT_INPUT) && !args.hasArg(OPT_l))
    fatal("no input files");

  std::vector<std::string> linkArgs;
  auto add = [&](const Twine &s) { linkArgs.push_back(s.str()); };

  add("lld-link");
  add("-lldmingw");

  if (auto *a = args.getLastArg(OPT_entry)) {
    StringRef s = a->getValue();
    if (args.getLastArgValue(OPT_m) == "i386pe" && s.startswith("_"))
      add("-entry:" + s.substr(1));
    else
      add("-entry:" + s);
  }

  if (args.hasArg(OPT_major_os_version, OPT_minor_os_version,
                  OPT_major_subsystem_version, OPT_minor_subsystem_version)) {
    auto *majOSVer = args.getLastArg(OPT_major_os_version);
    auto *minOSVer = args.getLastArg(OPT_minor_os_version);
    auto *majSubSysVer = args.getLastArg(OPT_major_subsystem_version);
    auto *minSubSysVer = args.getLastArg(OPT_minor_subsystem_version);
    if (majOSVer && majSubSysVer &&
        StringRef(majOSVer->getValue()) != StringRef(majSubSysVer->getValue()))
      warn("--major-os-version and --major-subsystem-version set to differing "
           "versions, not supported");
    if (minOSVer && minSubSysVer &&
        StringRef(minOSVer->getValue()) != StringRef(minSubSysVer->getValue()))
      warn("--minor-os-version and --minor-subsystem-version set to differing "
           "versions, not supported");
    StringRef subSys = args.getLastArgValue(OPT_subs, "default");
    StringRef major = majOSVer ? majOSVer->getValue()
                               : majSubSysVer ? majSubSysVer->getValue() : "6";
    StringRef minor = minOSVer ? minOSVer->getValue()
                               : minSubSysVer ? minSubSysVer->getValue() : "";
    StringRef sep = minor.empty() ? "" : ".";
    add("-subsystem:" + subSys + "," + major + sep + minor);
  } else if (auto *a = args.getLastArg(OPT_subs)) {
    add("-subsystem:" + StringRef(a->getValue()));
  }

  if (auto *a = args.getLastArg(OPT_out_implib))
    add("-implib:" + StringRef(a->getValue()));
  if (auto *a = args.getLastArg(OPT_stack))
    add("-stack:" + StringRef(a->getValue()));
  if (auto *a = args.getLastArg(OPT_output_def))
    add("-output-def:" + StringRef(a->getValue()));
  if (auto *a = args.getLastArg(OPT_image_base))
    add("-base:" + StringRef(a->getValue()));
  if (auto *a = args.getLastArg(OPT_map))
    add("-lldmap:" + StringRef(a->getValue()));

  if (auto *a = args.getLastArg(OPT_o))
    add("-out:" + StringRef(a->getValue()));
  else if (args.hasArg(OPT_shared))
    add("-out:a.dll");
  else
    add("-out:a.exe");

  if (auto *a = args.getLastArg(OPT_pdb)) {
    add("-debug");
    StringRef v = a->getValue();
    if (!v.empty())
      add("-pdb:" + v);
  } else if (args.hasArg(OPT_strip_debug)) {
    add("-debug:symtab");
  } else if (!args.hasArg(OPT_strip_all)) {
    add("-debug:dwarf");
  }

  if (args.hasArg(OPT_shared))
    add("-dll");
  if (args.hasArg(OPT_verbose))
    add("-verbose");
  if (args.hasArg(OPT_exclude_all_symbols))
    add("-exclude-all-symbols");
  if (args.hasArg(OPT_export_all_symbols))
    add("-export-all-symbols");
  if (args.hasArg(OPT_large_address_aware))
    add("-largeaddressaware");
  if (args.hasArg(OPT_kill_at))
    add("-kill-at");
  if (args.hasArg(OPT_appcontainer))
    add("-appcontainer");

  if (args.getLastArgValue(OPT_m) != "thumb2pe" &&
      args.getLastArgValue(OPT_m) != "arm64pe" && !args.hasArg(OPT_dynamicbase))
    add("-dynamicbase:no");

  if (args.hasFlag(OPT_no_insert_timestamp, OPT_insert_timestamp, false))
    add("-timestamp:0");

  if (args.hasFlag(OPT_gc_sections, OPT_no_gc_sections, false))
    add("-opt:ref");
  else
    add("-opt:noref");

  if (auto *a = args.getLastArg(OPT_icf)) {
    StringRef s = a->getValue();
    if (s == "all")
      add("-opt:icf");
    else if (s == "safe" || s == "none")
      add("-opt:noicf");
    else
      fatal("unknown parameter: --icf=" + s);
  } else {
    add("-opt:noicf");
  }

  if (auto *a = args.getLastArg(OPT_m)) {
    StringRef s = a->getValue();
    if (s == "i386pe")
      add("-machine:x86");
    else if (s == "i386pep")
      add("-machine:x64");
    else if (s == "thumb2pe")
      add("-machine:arm");
    else if (s == "arm64pe")
      add("-machine:arm64");
    else
      fatal("unknown parameter: -m" + s);
  }

  for (auto *a : args.filtered(OPT_mllvm))
    add("-mllvm:" + StringRef(a->getValue()));

  for (auto *a : args.filtered(OPT_Xlink))
    add(a->getValue());

  if (args.getLastArgValue(OPT_m) == "i386pe")
    add("-alternatename:__image_base__=___ImageBase");
  else
    add("-alternatename:__image_base__=__ImageBase");

  for (auto *a : args.filtered(OPT_require_defined))
    add("-include:" + StringRef(a->getValue()));
  for (auto *a : args.filtered(OPT_undefined))
    add("-includeoptional:" + StringRef(a->getValue()));

  std::vector<StringRef> searchPaths;
  for (auto *a : args.filtered(OPT_L)) {
    searchPaths.push_back(a->getValue());
    add("-libpath:" + StringRef(a->getValue()));
  }

  StringRef prefix = "";
  bool isStatic = false;
  for (auto *a : args) {
    switch (a->getOption().getID()) {
    case OPT_INPUT:
      if (StringRef(a->getValue()).endswith_lower(".def"))
        add("-def:" + StringRef(a->getValue()));
      else
        add(prefix + StringRef(a->getValue()));
      break;
    case OPT_l:
      add(prefix + searchLibrary(a->getValue(), searchPaths, isStatic));
      break;
    case OPT_whole_archive:
      prefix = "-wholearchive:";
      break;
    case OPT_no_whole_archive:
      prefix = "";
      break;
    case OPT_Bstatic:
      isStatic = true;
      break;
    case OPT_Bdynamic:
      isStatic = false;
      break;
    }
  }

  if (args.hasArg(OPT_verbose) || args.hasArg(OPT__HASH_HASH_HASH))
    outs() << llvm::join(linkArgs, " ") << "\n";

  if (args.hasArg(OPT__HASH_HASH_HASH))
    return true;

  // Repack vector of strings to vector of const char pointers for coff::link.
  std::vector<const char *> vec;
  for (const std::string &s : linkArgs)
    vec.push_back(s.c_str());
  return coff::link(vec, true);
}
