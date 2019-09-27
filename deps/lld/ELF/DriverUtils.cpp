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

#include "Driver.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "lld/Common/Reproduce.h"
#include "lld/Common/Version.h"
#include "llvm/ADT/Optional.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/Triple.h"
#include "llvm/Option/Option.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/Process.h"

using namespace llvm;
using namespace llvm::sys;
using namespace llvm::opt;

using namespace lld;
using namespace lld::elf;

// Create OptTable

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

ELFOptTable::ELFOptTable() : OptTable(optInfo) {}

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

static cl::TokenizerCallback getQuotingStyle(opt::InputArgList &args) {
  if (auto *arg = args.getLastArg(OPT_rsp_quoting)) {
    StringRef s = arg->getValue();
    if (s != "windows" && s != "posix")
      error("invalid response file quoting: " + s);
    if (s == "windows")
      return cl::TokenizeWindowsCommandLine;
    return cl::TokenizeGNUCommandLine;
  }
  if (Triple(sys::getProcessTriple()).getOS() == Triple::Win32)
    return cl::TokenizeWindowsCommandLine;
  return cl::TokenizeGNUCommandLine;
}

// Gold LTO plugin takes a `--plugin-opt foo=bar` option as an alias for
// `--plugin-opt=foo=bar`. We want to handle `--plugin-opt=foo=` as an
// option name and `bar` as a value. Unfortunately, OptParser cannot
// handle an option with a space in it.
//
// In this function, we concatenate command line arguments so that
// `--plugin-opt <foo>` is converted to `--plugin-opt=<foo>`. This is a
// bit hacky, but looks like it is still better than handling --plugin-opt
// options by hand.
static void concatLTOPluginOptions(SmallVectorImpl<const char *> &args) {
  SmallVector<const char *, 256> v;
  for (size_t i = 0, e = args.size(); i != e; ++i) {
    StringRef s = args[i];
    if ((s == "-plugin-opt" || s == "--plugin-opt") && i + 1 != e) {
      v.push_back(saver.save(s + "=" + args[i + 1]).data());
      ++i;
    } else {
      v.push_back(args[i]);
    }
  }
  args = std::move(v);
}

// Parses a given list of options.
opt::InputArgList ELFOptTable::parse(ArrayRef<const char *> argv) {
  // Make InputArgList from string vectors.
  unsigned missingIndex;
  unsigned missingCount;
  SmallVector<const char *, 256> vec(argv.data(), argv.data() + argv.size());

  // We need to get the quoting style for response files before parsing all
  // options so we parse here before and ignore all the options but
  // --rsp-quoting.
  opt::InputArgList args = this->ParseArgs(vec, missingIndex, missingCount);

  // Expand response files (arguments in the form of @<filename>)
  // and then parse the argument again.
  cl::ExpandResponseFiles(saver, getQuotingStyle(args), vec);
  concatLTOPluginOptions(vec);
  args = this->ParseArgs(vec, missingIndex, missingCount);

  handleColorDiagnostics(args);
  if (missingCount)
    error(Twine(args.getArgString(missingIndex)) + ": missing argument");

  for (auto *arg : args.filtered(OPT_UNKNOWN)) {
    std::string nearest;
    if (findNearest(arg->getAsString(args), nearest) > 1)
      error("unknown argument '" + arg->getAsString(args) + "'");
    else
      error("unknown argument '" + arg->getAsString(args) +
            "', did you mean '" + nearest + "'");
  }
  return args;
}

void elf::printHelp() {
  ELFOptTable().PrintHelp(
      outs(), (config->progName + " [options] file...").str().c_str(), "lld",
      false /*ShowHidden*/, true /*ShowAllAliases*/);
  outs() << "\n";

  // Scripts generated by Libtool versions up to at least 2.4.6 (the most
  // recent version as of March 2017) expect /: supported targets:.* elf/
  // in a message for the -help option. If it doesn't match, the scripts
  // assume that the linker doesn't support very basic features such as
  // shared libraries. Therefore, we need to print out at least "elf".
  outs() << config->progName << ": supported targets: elf\n";
}

static std::string rewritePath(StringRef s) {
  if (fs::exists(s))
    return relativeToRoot(s);
  return s;
}

// Reconstructs command line arguments so that so that you can re-run
// the same command with the same inputs. This is for --reproduce.
std::string elf::createResponseFile(const opt::InputArgList &args) {
  SmallString<0> data;
  raw_svector_ostream os(data);
  os << "--chroot .\n";

  // Copy the command line to the output while rewriting paths.
  for (auto *arg : args) {
    switch (arg->getOption().getID()) {
    case OPT_reproduce:
      break;
    case OPT_INPUT:
      os << quote(rewritePath(arg->getValue())) << "\n";
      break;
    case OPT_o:
      // If -o path contains directories, "lld @response.txt" will likely
      // fail because the archive we are creating doesn't contain empty
      // directories for the output path (-o doesn't create directories).
      // Strip directories to prevent the issue.
      os << "-o " << quote(sys::path::filename(arg->getValue())) << "\n";
      break;
    case OPT_dynamic_list:
    case OPT_library_path:
    case OPT_rpath:
    case OPT_script:
    case OPT_symbol_ordering_file:
    case OPT_sysroot:
    case OPT_version_script:
      os << arg->getSpelling() << " " << quote(rewritePath(arg->getValue()))
         << "\n";
      break;
    default:
      os << toString(*arg) << "\n";
    }
  }
  return data.str();
}

// Find a file by concatenating given paths. If a resulting path
// starts with "=", the character is replaced with a --sysroot value.
static Optional<std::string> findFile(StringRef path1, const Twine &path2) {
  SmallString<128> s;
  if (path1.startswith("="))
    path::append(s, config->sysroot, path1.substr(1), path2);
  else
    path::append(s, path1, path2);

  if (fs::exists(s))
    return s.str().str();
  return None;
}

Optional<std::string> elf::findFromSearchPaths(StringRef path) {
  for (StringRef dir : config->searchPaths)
    if (Optional<std::string> s = findFile(dir, path))
      return s;
  return None;
}

// This is for -l<basename>. We'll look for lib<basename>.so or lib<basename>.a from
// search paths.
Optional<std::string> elf::searchLibraryBaseName(StringRef name) {
  for (StringRef dir : config->searchPaths) {
    if (!config->isStatic)
      if (Optional<std::string> s = findFile(dir, "lib" + name + ".so"))
        return s;
    if (Optional<std::string> s = findFile(dir, "lib" + name + ".a"))
      return s;
  }
  return None;
}

// This is for -l<namespec>.
Optional<std::string> elf::searchLibrary(StringRef name) {
    if (name.startswith(":"))
        return findFromSearchPaths(name.substr(1));
    return searchLibraryBaseName (name);
}

// If a linker/version script doesn't exist in the current directory, we also
// look for the script in the '-L' search paths. This matches the behaviour of
// '-T', --version-script=, and linker script INPUT() command in ld.bfd.
Optional<std::string> elf::searchScript(StringRef name) {
  if (fs::exists(name))
    return name.str();
  return findFromSearchPaths(name);
}
