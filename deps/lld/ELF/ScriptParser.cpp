//===- ScriptParser.cpp ---------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains a recursive-descendent parser for linker scripts.
// Parsed results are stored to Config and Script global objects.
//
//===----------------------------------------------------------------------===//

#include "ScriptParser.h"
#include "Config.h"
#include "Driver.h"
#include "InputSection.h"
#include "LinkerScript.h"
#include "OutputSections.h"
#include "ScriptLexer.h"
#include "Symbols.h"
#include "Target.h"
#include "lld/Common/Memory.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/StringSet.h"
#include "llvm/ADT/StringSwitch.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/Path.h"
#include <cassert>
#include <limits>
#include <vector>

using namespace llvm;
using namespace llvm::ELF;
using namespace llvm::support::endian;
using namespace lld;
using namespace lld::elf;

namespace {
class ScriptParser final : ScriptLexer {
public:
  ScriptParser(MemoryBufferRef mb) : ScriptLexer(mb) {
    // Initialize IsUnderSysroot
    if (config->sysroot == "")
      return;
    StringRef path = mb.getBufferIdentifier();
    for (; !path.empty(); path = sys::path::parent_path(path)) {
      if (!sys::fs::equivalent(config->sysroot, path))
        continue;
      isUnderSysroot = true;
      return;
    }
  }

  void readLinkerScript();
  void readVersionScript();
  void readDynamicList();
  void readDefsym(StringRef name);

private:
  void addFile(StringRef path);

  void readAsNeeded();
  void readEntry();
  void readExtern();
  void readGroup();
  void readInclude();
  void readInput();
  void readMemory();
  void readOutput();
  void readOutputArch();
  void readOutputFormat();
  void readPhdrs();
  void readRegionAlias();
  void readSearchDir();
  void readSections();
  void readTarget();
  void readVersion();
  void readVersionScriptCommand();

  SymbolAssignment *readSymbolAssignment(StringRef name);
  ByteCommand *readByteCommand(StringRef tok);
  std::array<uint8_t, 4> readFill();
  bool readSectionDirective(OutputSection *cmd, StringRef tok1, StringRef tok2);
  void readSectionAddressType(OutputSection *cmd);
  OutputSection *readOverlaySectionDescription();
  OutputSection *readOutputSectionDescription(StringRef outSec);
  std::vector<BaseCommand *> readOverlay();
  std::vector<StringRef> readOutputSectionPhdrs();
  InputSectionDescription *readInputSectionDescription(StringRef tok);
  StringMatcher readFilePatterns();
  std::vector<SectionPattern> readInputSectionsList();
  InputSectionDescription *readInputSectionRules(StringRef filePattern);
  unsigned readPhdrType();
  SortSectionPolicy readSortKind();
  SymbolAssignment *readProvideHidden(bool provide, bool hidden);
  SymbolAssignment *readAssignment(StringRef tok);
  void readSort();
  Expr readAssert();
  Expr readConstant();
  Expr getPageSize();

  uint64_t readMemoryAssignment(StringRef, StringRef, StringRef);
  std::pair<uint32_t, uint32_t> readMemoryAttributes();

  Expr combine(StringRef op, Expr l, Expr r);
  Expr readExpr();
  Expr readExpr1(Expr lhs, int minPrec);
  StringRef readParenLiteral();
  Expr readPrimary();
  Expr readTernary(Expr cond);
  Expr readParenExpr();

  // For parsing version script.
  std::vector<SymbolVersion> readVersionExtern();
  void readAnonymousDeclaration();
  void readVersionDeclaration(StringRef verStr);

  std::pair<std::vector<SymbolVersion>, std::vector<SymbolVersion>>
  readSymbols();

  // True if a script being read is in a subdirectory specified by -sysroot.
  bool isUnderSysroot = false;

  // A set to detect an INCLUDE() cycle.
  StringSet<> seen;
};
} // namespace

static StringRef unquote(StringRef s) {
  if (s.startswith("\""))
    return s.substr(1, s.size() - 2);
  return s;
}

// Some operations only support one non absolute value. Move the
// absolute one to the right hand side for convenience.
static void moveAbsRight(ExprValue &a, ExprValue &b) {
  if (a.sec == nullptr || (a.forceAbsolute && !b.isAbsolute()))
    std::swap(a, b);
  if (!b.isAbsolute())
    error(a.loc + ": at least one side of the expression must be absolute");
}

static ExprValue add(ExprValue a, ExprValue b) {
  moveAbsRight(a, b);
  return {a.sec, a.forceAbsolute, a.getSectionOffset() + b.getValue(), a.loc};
}

static ExprValue sub(ExprValue a, ExprValue b) {
  // The distance between two symbols in sections is absolute.
  if (!a.isAbsolute() && !b.isAbsolute())
    return a.getValue() - b.getValue();
  return {a.sec, false, a.getSectionOffset() - b.getValue(), a.loc};
}

static ExprValue bitAnd(ExprValue a, ExprValue b) {
  moveAbsRight(a, b);
  return {a.sec, a.forceAbsolute,
          (a.getValue() & b.getValue()) - a.getSecAddr(), a.loc};
}

static ExprValue bitOr(ExprValue a, ExprValue b) {
  moveAbsRight(a, b);
  return {a.sec, a.forceAbsolute,
          (a.getValue() | b.getValue()) - a.getSecAddr(), a.loc};
}

void ScriptParser::readDynamicList() {
  config->hasDynamicList = true;
  expect("{");
  std::vector<SymbolVersion> locals;
  std::vector<SymbolVersion> globals;
  std::tie(locals, globals) = readSymbols();
  expect(";");

  if (!atEOF()) {
    setError("EOF expected, but got " + next());
    return;
  }
  if (!locals.empty()) {
    setError("\"local:\" scope not supported in --dynamic-list");
    return;
  }

  for (SymbolVersion v : globals)
    config->dynamicList.push_back(v);
}

void ScriptParser::readVersionScript() {
  readVersionScriptCommand();
  if (!atEOF())
    setError("EOF expected, but got " + next());
}

void ScriptParser::readVersionScriptCommand() {
  if (consume("{")) {
    readAnonymousDeclaration();
    return;
  }

  while (!atEOF() && !errorCount() && peek() != "}") {
    StringRef verStr = next();
    if (verStr == "{") {
      setError("anonymous version definition is used in "
               "combination with other version definitions");
      return;
    }
    expect("{");
    readVersionDeclaration(verStr);
  }
}

void ScriptParser::readVersion() {
  expect("{");
  readVersionScriptCommand();
  expect("}");
}

void ScriptParser::readLinkerScript() {
  while (!atEOF()) {
    StringRef tok = next();
    if (tok == ";")
      continue;

    if (tok == "ENTRY") {
      readEntry();
    } else if (tok == "EXTERN") {
      readExtern();
    } else if (tok == "GROUP") {
      readGroup();
    } else if (tok == "INCLUDE") {
      readInclude();
    } else if (tok == "INPUT") {
      readInput();
    } else if (tok == "MEMORY") {
      readMemory();
    } else if (tok == "OUTPUT") {
      readOutput();
    } else if (tok == "OUTPUT_ARCH") {
      readOutputArch();
    } else if (tok == "OUTPUT_FORMAT") {
      readOutputFormat();
    } else if (tok == "PHDRS") {
      readPhdrs();
    } else if (tok == "REGION_ALIAS") {
      readRegionAlias();
    } else if (tok == "SEARCH_DIR") {
      readSearchDir();
    } else if (tok == "SECTIONS") {
      readSections();
    } else if (tok == "TARGET") {
      readTarget();
    } else if (tok == "VERSION") {
      readVersion();
    } else if (SymbolAssignment *cmd = readAssignment(tok)) {
      script->sectionCommands.push_back(cmd);
    } else {
      setError("unknown directive: " + tok);
    }
  }
}

void ScriptParser::readDefsym(StringRef name) {
  if (errorCount())
    return;
  Expr e = readExpr();
  if (!atEOF())
    setError("EOF expected, but got " + next());
  SymbolAssignment *cmd = make<SymbolAssignment>(name, e, getCurrentLocation());
  script->sectionCommands.push_back(cmd);
}

void ScriptParser::addFile(StringRef s) {
  if (isUnderSysroot && s.startswith("/")) {
    SmallString<128> pathData;
    StringRef path = (config->sysroot + s).toStringRef(pathData);
    if (sys::fs::exists(path)) {
      driver->addFile(saver.save(path), /*withLOption=*/false);
      return;
    }
  }

  if (s.startswith("/")) {
    driver->addFile(s, /*withLOption=*/false);
  } else if (s.startswith("=")) {
    if (config->sysroot.empty())
      driver->addFile(s.substr(1), /*withLOption=*/false);
    else
      driver->addFile(saver.save(config->sysroot + "/" + s.substr(1)),
                      /*withLOption=*/false);
  } else if (s.startswith("-l")) {
    driver->addLibrary(s.substr(2));
  } else if (sys::fs::exists(s)) {
    driver->addFile(s, /*withLOption=*/false);
  } else {
    if (Optional<std::string> path = findFromSearchPaths(s))
      driver->addFile(saver.save(*path), /*withLOption=*/true);
    else
      setError("unable to find " + s);
  }
}

void ScriptParser::readAsNeeded() {
  expect("(");
  bool orig = config->asNeeded;
  config->asNeeded = true;
  while (!errorCount() && !consume(")"))
    addFile(unquote(next()));
  config->asNeeded = orig;
}

void ScriptParser::readEntry() {
  // -e <symbol> takes predecence over ENTRY(<symbol>).
  expect("(");
  StringRef tok = next();
  if (config->entry.empty())
    config->entry = tok;
  expect(")");
}

void ScriptParser::readExtern() {
  expect("(");
  while (!errorCount() && !consume(")"))
    config->undefined.push_back(unquote(next()));
}

void ScriptParser::readGroup() {
  bool orig = InputFile::isInGroup;
  InputFile::isInGroup = true;
  readInput();
  InputFile::isInGroup = orig;
  if (!orig)
    ++InputFile::nextGroupId;
}

void ScriptParser::readInclude() {
  StringRef tok = unquote(next());

  if (!seen.insert(tok).second) {
    setError("there is a cycle in linker script INCLUDEs");
    return;
  }

  if (Optional<std::string> path = searchScript(tok)) {
    if (Optional<MemoryBufferRef> mb = readFile(*path))
      tokenize(*mb);
    return;
  }
  setError("cannot find linker script " + tok);
}

void ScriptParser::readInput() {
  expect("(");
  while (!errorCount() && !consume(")")) {
    if (consume("AS_NEEDED"))
      readAsNeeded();
    else
      addFile(unquote(next()));
  }
}

void ScriptParser::readOutput() {
  // -o <file> takes predecence over OUTPUT(<file>).
  expect("(");
  StringRef tok = next();
  if (config->outputFile.empty())
    config->outputFile = unquote(tok);
  expect(")");
}

void ScriptParser::readOutputArch() {
  // OUTPUT_ARCH is ignored for now.
  expect("(");
  while (!errorCount() && !consume(")"))
    skip();
}

static std::pair<ELFKind, uint16_t> parseBfdName(StringRef s) {
  return StringSwitch<std::pair<ELFKind, uint16_t>>(s)
      .Case("elf32-i386", {ELF32LEKind, EM_386})
      .Case("elf32-iamcu", {ELF32LEKind, EM_IAMCU})
      .Case("elf32-littlearm", {ELF32LEKind, EM_ARM})
      .Case("elf32-x86-64", {ELF32LEKind, EM_X86_64})
      .Case("elf64-aarch64", {ELF64LEKind, EM_AARCH64})
      .Case("elf64-littleaarch64", {ELF64LEKind, EM_AARCH64})
      .Case("elf32-powerpc", {ELF32BEKind, EM_PPC})
      .Case("elf64-powerpc", {ELF64BEKind, EM_PPC64})
      .Case("elf64-powerpcle", {ELF64LEKind, EM_PPC64})
      .Case("elf64-x86-64", {ELF64LEKind, EM_X86_64})
      .Cases("elf32-tradbigmips", "elf32-bigmips", {ELF32BEKind, EM_MIPS})
      .Case("elf32-ntradbigmips", {ELF32BEKind, EM_MIPS})
      .Case("elf32-tradlittlemips", {ELF32LEKind, EM_MIPS})
      .Case("elf32-ntradlittlemips", {ELF32LEKind, EM_MIPS})
      .Case("elf64-tradbigmips", {ELF64BEKind, EM_MIPS})
      .Case("elf64-tradlittlemips", {ELF64LEKind, EM_MIPS})
      .Case("elf32-littleriscv", {ELF32LEKind, EM_RISCV})
      .Case("elf64-littleriscv", {ELF64LEKind, EM_RISCV})
      .Default({ELFNoneKind, EM_NONE});
}

// Parse OUTPUT_FORMAT(bfdname) or OUTPUT_FORMAT(bfdname, big, little).
// Currently we ignore big and little parameters.
void ScriptParser::readOutputFormat() {
  expect("(");

  StringRef name = unquote(next());
  StringRef s = name;
  if (s.consume_back("-freebsd"))
    config->osabi = ELFOSABI_FREEBSD;

  std::tie(config->ekind, config->emachine) = parseBfdName(s);
  if (config->emachine == EM_NONE)
    setError("unknown output format name: " + name);
  if (s == "elf32-ntradlittlemips" || s == "elf32-ntradbigmips")
    config->mipsN32Abi = true;

  if (consume(")"))
    return;
  expect(",");
  skip();
  expect(",");
  skip();
  expect(")");
}

void ScriptParser::readPhdrs() {
  expect("{");

  while (!errorCount() && !consume("}")) {
    PhdrsCommand cmd;
    cmd.name = next();
    cmd.type = readPhdrType();

    while (!errorCount() && !consume(";")) {
      if (consume("FILEHDR"))
        cmd.hasFilehdr = true;
      else if (consume("PHDRS"))
        cmd.hasPhdrs = true;
      else if (consume("AT"))
        cmd.lmaExpr = readParenExpr();
      else if (consume("FLAGS"))
        cmd.flags = readParenExpr()().getValue();
      else
        setError("unexpected header attribute: " + next());
    }

    script->phdrsCommands.push_back(cmd);
  }
}

void ScriptParser::readRegionAlias() {
  expect("(");
  StringRef alias = unquote(next());
  expect(",");
  StringRef name = next();
  expect(")");

  if (script->memoryRegions.count(alias))
    setError("redefinition of memory region '" + alias + "'");
  if (!script->memoryRegions.count(name))
    setError("memory region '" + name + "' is not defined");
  script->memoryRegions.insert({alias, script->memoryRegions[name]});
}

void ScriptParser::readSearchDir() {
  expect("(");
  StringRef tok = next();
  if (!config->nostdlib)
    config->searchPaths.push_back(unquote(tok));
  expect(")");
}

// This reads an overlay description. Overlays are used to describe output
// sections that use the same virtual memory range and normally would trigger
// linker's sections sanity check failures.
// https://sourceware.org/binutils/docs/ld/Overlay-Description.html#Overlay-Description
std::vector<BaseCommand *> ScriptParser::readOverlay() {
  // VA and LMA expressions are optional, though for simplicity of
  // implementation we assume they are not. That is what OVERLAY was designed
  // for first of all: to allow sections with overlapping VAs at different LMAs.
  Expr addrExpr = readExpr();
  expect(":");
  expect("AT");
  Expr lmaExpr = readParenExpr();
  expect("{");

  std::vector<BaseCommand *> v;
  OutputSection *prev = nullptr;
  while (!errorCount() && !consume("}")) {
    // VA is the same for all sections. The LMAs are consecutive in memory
    // starting from the base load address specified.
    OutputSection *os = readOverlaySectionDescription();
    os->addrExpr = addrExpr;
    if (prev)
      os->lmaExpr = [=] { return prev->getLMA() + prev->size; };
    else
      os->lmaExpr = lmaExpr;
    v.push_back(os);
    prev = os;
  }

  // According to the specification, at the end of the overlay, the location
  // counter should be equal to the overlay base address plus size of the
  // largest section seen in the overlay.
  // Here we want to create the Dot assignment command to achieve that.
  Expr moveDot = [=] {
    uint64_t max = 0;
    for (BaseCommand *cmd : v)
      max = std::max(max, cast<OutputSection>(cmd)->size);
    return addrExpr().getValue() + max;
  };
  v.push_back(make<SymbolAssignment>(".", moveDot, getCurrentLocation()));
  return v;
}

void ScriptParser::readSections() {
  script->hasSectionsCommand = true;

  // -no-rosegment is used to avoid placing read only non-executable sections in
  // their own segment. We do the same if SECTIONS command is present in linker
  // script. See comment for computeFlags().
  config->singleRoRx = true;

  expect("{");
  std::vector<BaseCommand *> v;
  while (!errorCount() && !consume("}")) {
    StringRef tok = next();
    if (tok == "OVERLAY") {
      for (BaseCommand *cmd : readOverlay())
        v.push_back(cmd);
      continue;
    } else if (tok == "INCLUDE") {
      readInclude();
      continue;
    }

    if (BaseCommand *cmd = readAssignment(tok))
      v.push_back(cmd);
    else
      v.push_back(readOutputSectionDescription(tok));
  }

  if (!atEOF() && consume("INSERT")) {
    std::vector<BaseCommand *> *dest = nullptr;
    if (consume("AFTER"))
      dest = &script->insertAfterCommands[next()];
    else if (consume("BEFORE"))
      dest = &script->insertBeforeCommands[next()];
    else
      setError("expected AFTER/BEFORE, but got '" + next() + "'");
    if (dest)
      dest->insert(dest->end(), v.begin(), v.end());
    return;
  }

  script->sectionCommands.insert(script->sectionCommands.end(), v.begin(),
                                 v.end());
}

void ScriptParser::readTarget() {
  // TARGET(foo) is an alias for "--format foo". Unlike GNU linkers,
  // we accept only a limited set of BFD names (i.e. "elf" or "binary")
  // for --format. We recognize only /^elf/ and "binary" in the linker
  // script as well.
  expect("(");
  StringRef tok = next();
  expect(")");

  if (tok.startswith("elf"))
    config->formatBinary = false;
  else if (tok == "binary")
    config->formatBinary = true;
  else
    setError("unknown target: " + tok);
}

static int precedence(StringRef op) {
  return StringSwitch<int>(op)
      .Cases("*", "/", "%", 8)
      .Cases("+", "-", 7)
      .Cases("<<", ">>", 6)
      .Cases("<", "<=", ">", ">=", "==", "!=", 5)
      .Case("&", 4)
      .Case("|", 3)
      .Case("&&", 2)
      .Case("||", 1)
      .Default(-1);
}

StringMatcher ScriptParser::readFilePatterns() {
  std::vector<StringRef> v;
  while (!errorCount() && !consume(")"))
    v.push_back(next());
  return StringMatcher(v);
}

SortSectionPolicy ScriptParser::readSortKind() {
  if (consume("SORT") || consume("SORT_BY_NAME"))
    return SortSectionPolicy::Name;
  if (consume("SORT_BY_ALIGNMENT"))
    return SortSectionPolicy::Alignment;
  if (consume("SORT_BY_INIT_PRIORITY"))
    return SortSectionPolicy::Priority;
  if (consume("SORT_NONE"))
    return SortSectionPolicy::None;
  return SortSectionPolicy::Default;
}

// Reads SECTIONS command contents in the following form:
//
// <contents> ::= <elem>*
// <elem>     ::= <exclude>? <glob-pattern>
// <exclude>  ::= "EXCLUDE_FILE" "(" <glob-pattern>+ ")"
//
// For example,
//
// *(.foo EXCLUDE_FILE (a.o) .bar EXCLUDE_FILE (b.o) .baz)
//
// is parsed as ".foo", ".bar" with "a.o", and ".baz" with "b.o".
// The semantics of that is section .foo in any file, section .bar in
// any file but a.o, and section .baz in any file but b.o.
std::vector<SectionPattern> ScriptParser::readInputSectionsList() {
  std::vector<SectionPattern> ret;
  while (!errorCount() && peek() != ")") {
    StringMatcher excludeFilePat;
    if (consume("EXCLUDE_FILE")) {
      expect("(");
      excludeFilePat = readFilePatterns();
    }

    std::vector<StringRef> v;
    while (!errorCount() && peek() != ")" && peek() != "EXCLUDE_FILE")
      v.push_back(unquote(next()));

    if (!v.empty())
      ret.push_back({std::move(excludeFilePat), StringMatcher(v)});
    else
      setError("section pattern is expected");
  }
  return ret;
}

// Reads contents of "SECTIONS" directive. That directive contains a
// list of glob patterns for input sections. The grammar is as follows.
//
// <patterns> ::= <section-list>
//              | <sort> "(" <section-list> ")"
//              | <sort> "(" <sort> "(" <section-list> ")" ")"
//
// <sort>     ::= "SORT" | "SORT_BY_NAME" | "SORT_BY_ALIGNMENT"
//              | "SORT_BY_INIT_PRIORITY" | "SORT_NONE"
//
// <section-list> is parsed by readInputSectionsList().
InputSectionDescription *
ScriptParser::readInputSectionRules(StringRef filePattern) {
  auto *cmd = make<InputSectionDescription>(filePattern);
  expect("(");

  while (!errorCount() && !consume(")")) {
    SortSectionPolicy outer = readSortKind();
    SortSectionPolicy inner = SortSectionPolicy::Default;
    std::vector<SectionPattern> v;
    if (outer != SortSectionPolicy::Default) {
      expect("(");
      inner = readSortKind();
      if (inner != SortSectionPolicy::Default) {
        expect("(");
        v = readInputSectionsList();
        expect(")");
      } else {
        v = readInputSectionsList();
      }
      expect(")");
    } else {
      v = readInputSectionsList();
    }

    for (SectionPattern &pat : v) {
      pat.sortInner = inner;
      pat.sortOuter = outer;
    }

    std::move(v.begin(), v.end(), std::back_inserter(cmd->sectionPatterns));
  }
  return cmd;
}

InputSectionDescription *
ScriptParser::readInputSectionDescription(StringRef tok) {
  // Input section wildcard can be surrounded by KEEP.
  // https://sourceware.org/binutils/docs/ld/Input-Section-Keep.html#Input-Section-Keep
  if (tok == "KEEP") {
    expect("(");
    StringRef filePattern = next();
    InputSectionDescription *cmd = readInputSectionRules(filePattern);
    expect(")");
    script->keptSections.push_back(cmd);
    return cmd;
  }
  return readInputSectionRules(tok);
}

void ScriptParser::readSort() {
  expect("(");
  expect("CONSTRUCTORS");
  expect(")");
}

Expr ScriptParser::readAssert() {
  expect("(");
  Expr e = readExpr();
  expect(",");
  StringRef msg = unquote(next());
  expect(")");

  return [=] {
    if (!e().getValue())
      error(msg);
    return script->getDot();
  };
}

// Tries to read the special directive for an output section definition which
// can be one of following: "(NOLOAD)", "(COPY)", "(INFO)" or "(OVERLAY)".
// Tok1 and Tok2 are next 2 tokens peeked. See comment for readSectionAddressType below.
bool ScriptParser::readSectionDirective(OutputSection *cmd, StringRef tok1, StringRef tok2) {
  if (tok1 != "(")
    return false;
  if (tok2 != "NOLOAD" && tok2 != "COPY" && tok2 != "INFO" && tok2 != "OVERLAY")
    return false;

  expect("(");
  if (consume("NOLOAD")) {
    cmd->noload = true;
  } else {
    skip(); // This is "COPY", "INFO" or "OVERLAY".
    cmd->nonAlloc = true;
  }
  expect(")");
  return true;
}

// Reads an expression and/or the special directive for an output
// section definition. Directive is one of following: "(NOLOAD)",
// "(COPY)", "(INFO)" or "(OVERLAY)".
//
// An output section name can be followed by an address expression
// and/or directive. This grammar is not LL(1) because "(" can be
// interpreted as either the beginning of some expression or beginning
// of directive.
//
// https://sourceware.org/binutils/docs/ld/Output-Section-Address.html
// https://sourceware.org/binutils/docs/ld/Output-Section-Type.html
void ScriptParser::readSectionAddressType(OutputSection *cmd) {
  if (readSectionDirective(cmd, peek(), peek2()))
    return;

  cmd->addrExpr = readExpr();
  if (peek() == "(" && !readSectionDirective(cmd, "(", peek2()))
    setError("unknown section directive: " + peek2());
}

static Expr checkAlignment(Expr e, std::string &loc) {
  return [=] {
    uint64_t alignment = std::max((uint64_t)1, e().getValue());
    if (!isPowerOf2_64(alignment)) {
      error(loc + ": alignment must be power of 2");
      return (uint64_t)1; // Return a dummy value.
    }
    return alignment;
  };
}

OutputSection *ScriptParser::readOverlaySectionDescription() {
  OutputSection *cmd =
      script->createOutputSection(next(), getCurrentLocation());
  cmd->inOverlay = true;
  expect("{");
  while (!errorCount() && !consume("}"))
    cmd->sectionCommands.push_back(readInputSectionRules(next()));
  cmd->phdrs = readOutputSectionPhdrs();
  return cmd;
}

OutputSection *ScriptParser::readOutputSectionDescription(StringRef outSec) {
  OutputSection *cmd =
      script->createOutputSection(outSec, getCurrentLocation());

  size_t symbolsReferenced = script->referencedSymbols.size();

  if (peek() != ":")
    readSectionAddressType(cmd);
  expect(":");

  std::string location = getCurrentLocation();
  if (consume("AT"))
    cmd->lmaExpr = readParenExpr();
  if (consume("ALIGN"))
    cmd->alignExpr = checkAlignment(readParenExpr(), location);
  if (consume("SUBALIGN"))
    cmd->subalignExpr = checkAlignment(readParenExpr(), location);

  // Parse constraints.
  if (consume("ONLY_IF_RO"))
    cmd->constraint = ConstraintKind::ReadOnly;
  if (consume("ONLY_IF_RW"))
    cmd->constraint = ConstraintKind::ReadWrite;
  expect("{");

  while (!errorCount() && !consume("}")) {
    StringRef tok = next();
    if (tok == ";") {
      // Empty commands are allowed. Do nothing here.
    } else if (SymbolAssignment *assign = readAssignment(tok)) {
      cmd->sectionCommands.push_back(assign);
    } else if (ByteCommand *data = readByteCommand(tok)) {
      cmd->sectionCommands.push_back(data);
    } else if (tok == "CONSTRUCTORS") {
      // CONSTRUCTORS is a keyword to make the linker recognize C++ ctors/dtors
      // by name. This is for very old file formats such as ECOFF/XCOFF.
      // For ELF, we should ignore.
    } else if (tok == "FILL") {
      // We handle the FILL command as an alias for =fillexp section attribute,
      // which is different from what GNU linkers do.
      // https://sourceware.org/binutils/docs/ld/Output-Section-Data.html
      expect("(");
      cmd->filler = readFill();
      expect(")");
    } else if (tok == "SORT") {
      readSort();
    } else if (tok == "INCLUDE") {
      readInclude();
    } else if (peek() == "(") {
      cmd->sectionCommands.push_back(readInputSectionDescription(tok));
    } else {
      // We have a file name and no input sections description. It is not a
      // commonly used syntax, but still acceptable. In that case, all sections
      // from the file will be included.
      auto *isd = make<InputSectionDescription>(tok);
      isd->sectionPatterns.push_back({{}, StringMatcher({"*"})});
      cmd->sectionCommands.push_back(isd);
    }
  }

  if (consume(">"))
    cmd->memoryRegionName = next();

  if (consume("AT")) {
    expect(">");
    cmd->lmaRegionName = next();
  }

  if (cmd->lmaExpr && !cmd->lmaRegionName.empty())
    error("section can't have both LMA and a load region");

  cmd->phdrs = readOutputSectionPhdrs();

  if (peek() == "=" || peek().startswith("=")) {
    inExpr = true;
    consume("=");
    cmd->filler = readFill();
    inExpr = false;
  }

  // Consume optional comma following output section command.
  consume(",");

  if (script->referencedSymbols.size() > symbolsReferenced)
    cmd->expressionsUseSymbols = true;
  return cmd;
}

// Reads a `=<fillexp>` expression and returns its value as a big-endian number.
// https://sourceware.org/binutils/docs/ld/Output-Section-Fill.html
// We do not support using symbols in such expressions.
//
// When reading a hexstring, ld.bfd handles it as a blob of arbitrary
// size, while ld.gold always handles it as a 32-bit big-endian number.
// We are compatible with ld.gold because it's easier to implement.
std::array<uint8_t, 4> ScriptParser::readFill() {
  uint64_t value = readExpr()().val;
  if (value > UINT32_MAX)
    setError("filler expression result does not fit 32-bit: 0x" +
             Twine::utohexstr(value));

  std::array<uint8_t, 4> buf;
  write32be(buf.data(), (uint32_t)value);
  return buf;
}

SymbolAssignment *ScriptParser::readProvideHidden(bool provide, bool hidden) {
  expect("(");
  SymbolAssignment *cmd = readSymbolAssignment(next());
  cmd->provide = provide;
  cmd->hidden = hidden;
  expect(")");
  return cmd;
}

SymbolAssignment *ScriptParser::readAssignment(StringRef tok) {
  // Assert expression returns Dot, so this is equal to ".=."
  if (tok == "ASSERT")
    return make<SymbolAssignment>(".", readAssert(), getCurrentLocation());

  size_t oldPos = pos;
  SymbolAssignment *cmd = nullptr;
  if (peek() == "=" || peek() == "+=")
    cmd = readSymbolAssignment(tok);
  else if (tok == "PROVIDE")
    cmd = readProvideHidden(true, false);
  else if (tok == "HIDDEN")
    cmd = readProvideHidden(false, true);
  else if (tok == "PROVIDE_HIDDEN")
    cmd = readProvideHidden(true, true);

  if (cmd) {
    cmd->commandString =
        tok.str() + " " +
        llvm::join(tokens.begin() + oldPos, tokens.begin() + pos, " ");
    expect(";");
  }
  return cmd;
}

SymbolAssignment *ScriptParser::readSymbolAssignment(StringRef name) {
  StringRef op = next();
  assert(op == "=" || op == "+=");
  Expr e = readExpr();
  if (op == "+=") {
    std::string loc = getCurrentLocation();
    e = [=] { return add(script->getSymbolValue(name, loc), e()); };
  }
  return make<SymbolAssignment>(name, e, getCurrentLocation());
}

// This is an operator-precedence parser to parse a linker
// script expression.
Expr ScriptParser::readExpr() {
  // Our lexer is context-aware. Set the in-expression bit so that
  // they apply different tokenization rules.
  bool orig = inExpr;
  inExpr = true;
  Expr e = readExpr1(readPrimary(), 0);
  inExpr = orig;
  return e;
}

Expr ScriptParser::combine(StringRef op, Expr l, Expr r) {
  if (op == "+")
    return [=] { return add(l(), r()); };
  if (op == "-")
    return [=] { return sub(l(), r()); };
  if (op == "*")
    return [=] { return l().getValue() * r().getValue(); };
  if (op == "/") {
    std::string loc = getCurrentLocation();
    return [=]() -> uint64_t {
      if (uint64_t rv = r().getValue())
        return l().getValue() / rv;
      error(loc + ": division by zero");
      return 0;
    };
  }
  if (op == "%") {
    std::string loc = getCurrentLocation();
    return [=]() -> uint64_t {
      if (uint64_t rv = r().getValue())
        return l().getValue() % rv;
      error(loc + ": modulo by zero");
      return 0;
    };
  }
  if (op == "<<")
    return [=] { return l().getValue() << r().getValue(); };
  if (op == ">>")
    return [=] { return l().getValue() >> r().getValue(); };
  if (op == "<")
    return [=] { return l().getValue() < r().getValue(); };
  if (op == ">")
    return [=] { return l().getValue() > r().getValue(); };
  if (op == ">=")
    return [=] { return l().getValue() >= r().getValue(); };
  if (op == "<=")
    return [=] { return l().getValue() <= r().getValue(); };
  if (op == "==")
    return [=] { return l().getValue() == r().getValue(); };
  if (op == "!=")
    return [=] { return l().getValue() != r().getValue(); };
  if (op == "||")
    return [=] { return l().getValue() || r().getValue(); };
  if (op == "&&")
    return [=] { return l().getValue() && r().getValue(); };
  if (op == "&")
    return [=] { return bitAnd(l(), r()); };
  if (op == "|")
    return [=] { return bitOr(l(), r()); };
  llvm_unreachable("invalid operator");
}

// This is a part of the operator-precedence parser. This function
// assumes that the remaining token stream starts with an operator.
Expr ScriptParser::readExpr1(Expr lhs, int minPrec) {
  while (!atEOF() && !errorCount()) {
    // Read an operator and an expression.
    if (consume("?"))
      return readTernary(lhs);
    StringRef op1 = peek();
    if (precedence(op1) < minPrec)
      break;
    skip();
    Expr rhs = readPrimary();

    // Evaluate the remaining part of the expression first if the
    // next operator has greater precedence than the previous one.
    // For example, if we have read "+" and "3", and if the next
    // operator is "*", then we'll evaluate 3 * ... part first.
    while (!atEOF()) {
      StringRef op2 = peek();
      if (precedence(op2) <= precedence(op1))
        break;
      rhs = readExpr1(rhs, precedence(op2));
    }

    lhs = combine(op1, lhs, rhs);
  }
  return lhs;
}

Expr ScriptParser::getPageSize() {
  std::string location = getCurrentLocation();
  return [=]() -> uint64_t {
    if (target)
      return config->commonPageSize;
    error(location + ": unable to calculate page size");
    return 4096; // Return a dummy value.
  };
}

Expr ScriptParser::readConstant() {
  StringRef s = readParenLiteral();
  if (s == "COMMONPAGESIZE")
    return getPageSize();
  if (s == "MAXPAGESIZE")
    return [] { return config->maxPageSize; };
  setError("unknown constant: " + s);
  return [] { return 0; };
}

// Parses Tok as an integer. It recognizes hexadecimal (prefixed with
// "0x" or suffixed with "H") and decimal numbers. Decimal numbers may
// have "K" (Ki) or "M" (Mi) suffixes.
static Optional<uint64_t> parseInt(StringRef tok) {
  // Hexadecimal
  uint64_t val;
  if (tok.startswith_lower("0x")) {
    if (!to_integer(tok.substr(2), val, 16))
      return None;
    return val;
  }
  if (tok.endswith_lower("H")) {
    if (!to_integer(tok.drop_back(), val, 16))
      return None;
    return val;
  }

  // Decimal
  if (tok.endswith_lower("K")) {
    if (!to_integer(tok.drop_back(), val, 10))
      return None;
    return val * 1024;
  }
  if (tok.endswith_lower("M")) {
    if (!to_integer(tok.drop_back(), val, 10))
      return None;
    return val * 1024 * 1024;
  }
  if (!to_integer(tok, val, 10))
    return None;
  return val;
}

ByteCommand *ScriptParser::readByteCommand(StringRef tok) {
  int size = StringSwitch<int>(tok)
                 .Case("BYTE", 1)
                 .Case("SHORT", 2)
                 .Case("LONG", 4)
                 .Case("QUAD", 8)
                 .Default(-1);
  if (size == -1)
    return nullptr;

  size_t oldPos = pos;
  Expr e = readParenExpr();
  std::string commandString =
      tok.str() + " " +
      llvm::join(tokens.begin() + oldPos, tokens.begin() + pos, " ");
  return make<ByteCommand>(e, size, commandString);
}

StringRef ScriptParser::readParenLiteral() {
  expect("(");
  bool orig = inExpr;
  inExpr = false;
  StringRef tok = next();
  inExpr = orig;
  expect(")");
  return tok;
}

static void checkIfExists(OutputSection *cmd, StringRef location) {
  if (cmd->location.empty() && script->errorOnMissingSection)
    error(location + ": undefined section " + cmd->name);
}

Expr ScriptParser::readPrimary() {
  if (peek() == "(")
    return readParenExpr();

  if (consume("~")) {
    Expr e = readPrimary();
    return [=] { return ~e().getValue(); };
  }
  if (consume("!")) {
    Expr e = readPrimary();
    return [=] { return !e().getValue(); };
  }
  if (consume("-")) {
    Expr e = readPrimary();
    return [=] { return -e().getValue(); };
  }

  StringRef tok = next();
  std::string location = getCurrentLocation();

  // Built-in functions are parsed here.
  // https://sourceware.org/binutils/docs/ld/Builtin-Functions.html.
  if (tok == "ABSOLUTE") {
    Expr inner = readParenExpr();
    return [=] {
      ExprValue i = inner();
      i.forceAbsolute = true;
      return i;
    };
  }
  if (tok == "ADDR") {
    StringRef name = readParenLiteral();
    OutputSection *sec = script->getOrCreateOutputSection(name);
    sec->usedInExpression = true;
    return [=]() -> ExprValue {
      checkIfExists(sec, location);
      return {sec, false, 0, location};
    };
  }
  if (tok == "ALIGN") {
    expect("(");
    Expr e = readExpr();
    if (consume(")")) {
      e = checkAlignment(e, location);
      return [=] { return alignTo(script->getDot(), e().getValue()); };
    }
    expect(",");
    Expr e2 = checkAlignment(readExpr(), location);
    expect(")");
    return [=] {
      ExprValue v = e();
      v.alignment = e2().getValue();
      return v;
    };
  }
  if (tok == "ALIGNOF") {
    StringRef name = readParenLiteral();
    OutputSection *cmd = script->getOrCreateOutputSection(name);
    return [=] {
      checkIfExists(cmd, location);
      return cmd->alignment;
    };
  }
  if (tok == "ASSERT")
    return readAssert();
  if (tok == "CONSTANT")
    return readConstant();
  if (tok == "DATA_SEGMENT_ALIGN") {
    expect("(");
    Expr e = readExpr();
    expect(",");
    readExpr();
    expect(")");
    return [=] {
      return alignTo(script->getDot(), std::max((uint64_t)1, e().getValue()));
    };
  }
  if (tok == "DATA_SEGMENT_END") {
    expect("(");
    expect(".");
    expect(")");
    return [] { return script->getDot(); };
  }
  if (tok == "DATA_SEGMENT_RELRO_END") {
    // GNU linkers implements more complicated logic to handle
    // DATA_SEGMENT_RELRO_END. We instead ignore the arguments and
    // just align to the next page boundary for simplicity.
    expect("(");
    readExpr();
    expect(",");
    readExpr();
    expect(")");
    Expr e = getPageSize();
    return [=] { return alignTo(script->getDot(), e().getValue()); };
  }
  if (tok == "DEFINED") {
    StringRef name = readParenLiteral();
    return [=] { return symtab->find(name) ? 1 : 0; };
  }
  if (tok == "LENGTH") {
    StringRef name = readParenLiteral();
    if (script->memoryRegions.count(name) == 0) {
      setError("memory region not defined: " + name);
      return [] { return 0; };
    }
    return [=] { return script->memoryRegions[name]->length; };
  }
  if (tok == "LOADADDR") {
    StringRef name = readParenLiteral();
    OutputSection *cmd = script->getOrCreateOutputSection(name);
    cmd->usedInExpression = true;
    return [=] {
      checkIfExists(cmd, location);
      return cmd->getLMA();
    };
  }
  if (tok == "MAX" || tok == "MIN") {
    expect("(");
    Expr a = readExpr();
    expect(",");
    Expr b = readExpr();
    expect(")");
    if (tok == "MIN")
      return [=] { return std::min(a().getValue(), b().getValue()); };
    return [=] { return std::max(a().getValue(), b().getValue()); };
  }
  if (tok == "ORIGIN") {
    StringRef name = readParenLiteral();
    if (script->memoryRegions.count(name) == 0) {
      setError("memory region not defined: " + name);
      return [] { return 0; };
    }
    return [=] { return script->memoryRegions[name]->origin; };
  }
  if (tok == "SEGMENT_START") {
    expect("(");
    skip();
    expect(",");
    Expr e = readExpr();
    expect(")");
    return [=] { return e(); };
  }
  if (tok == "SIZEOF") {
    StringRef name = readParenLiteral();
    OutputSection *cmd = script->getOrCreateOutputSection(name);
    // Linker script does not create an output section if its content is empty.
    // We want to allow SIZEOF(.foo) where .foo is a section which happened to
    // be empty.
    return [=] { return cmd->size; };
  }
  if (tok == "SIZEOF_HEADERS")
    return [=] { return elf::getHeaderSize(); };

  // Tok is the dot.
  if (tok == ".")
    return [=] { return script->getSymbolValue(tok, location); };

  // Tok is a literal number.
  if (Optional<uint64_t> val = parseInt(tok))
    return [=] { return *val; };

  // Tok is a symbol name.
  if (!isValidCIdentifier(tok))
    setError("malformed number: " + tok);
  script->referencedSymbols.push_back(tok);
  return [=] { return script->getSymbolValue(tok, location); };
}

Expr ScriptParser::readTernary(Expr cond) {
  Expr l = readExpr();
  expect(":");
  Expr r = readExpr();
  return [=] { return cond().getValue() ? l() : r(); };
}

Expr ScriptParser::readParenExpr() {
  expect("(");
  Expr e = readExpr();
  expect(")");
  return e;
}

std::vector<StringRef> ScriptParser::readOutputSectionPhdrs() {
  std::vector<StringRef> phdrs;
  while (!errorCount() && peek().startswith(":")) {
    StringRef tok = next();
    phdrs.push_back((tok.size() == 1) ? next() : tok.substr(1));
  }
  return phdrs;
}

// Read a program header type name. The next token must be a
// name of a program header type or a constant (e.g. "0x3").
unsigned ScriptParser::readPhdrType() {
  StringRef tok = next();
  if (Optional<uint64_t> val = parseInt(tok))
    return *val;

  unsigned ret = StringSwitch<unsigned>(tok)
                     .Case("PT_NULL", PT_NULL)
                     .Case("PT_LOAD", PT_LOAD)
                     .Case("PT_DYNAMIC", PT_DYNAMIC)
                     .Case("PT_INTERP", PT_INTERP)
                     .Case("PT_NOTE", PT_NOTE)
                     .Case("PT_SHLIB", PT_SHLIB)
                     .Case("PT_PHDR", PT_PHDR)
                     .Case("PT_TLS", PT_TLS)
                     .Case("PT_GNU_EH_FRAME", PT_GNU_EH_FRAME)
                     .Case("PT_GNU_STACK", PT_GNU_STACK)
                     .Case("PT_GNU_RELRO", PT_GNU_RELRO)
                     .Case("PT_OPENBSD_RANDOMIZE", PT_OPENBSD_RANDOMIZE)
                     .Case("PT_OPENBSD_WXNEEDED", PT_OPENBSD_WXNEEDED)
                     .Case("PT_OPENBSD_BOOTDATA", PT_OPENBSD_BOOTDATA)
                     .Default(-1);

  if (ret == (unsigned)-1) {
    setError("invalid program header type: " + tok);
    return PT_NULL;
  }
  return ret;
}

// Reads an anonymous version declaration.
void ScriptParser::readAnonymousDeclaration() {
  std::vector<SymbolVersion> locals;
  std::vector<SymbolVersion> globals;
  std::tie(locals, globals) = readSymbols();

  for (SymbolVersion v : locals) {
    if (v.name == "*")
      config->defaultSymbolVersion = VER_NDX_LOCAL;
    else
      config->versionScriptLocals.push_back(v);
  }

  for (SymbolVersion v : globals)
    config->versionScriptGlobals.push_back(v);

  expect(";");
}

// Reads a non-anonymous version definition,
// e.g. "VerStr { global: foo; bar; local: *; };".
void ScriptParser::readVersionDeclaration(StringRef verStr) {
  // Read a symbol list.
  std::vector<SymbolVersion> locals;
  std::vector<SymbolVersion> globals;
  std::tie(locals, globals) = readSymbols();

  for (SymbolVersion v : locals) {
    if (v.name == "*")
      config->defaultSymbolVersion = VER_NDX_LOCAL;
    else
      config->versionScriptLocals.push_back(v);
  }

  // Create a new version definition and add that to the global symbols.
  VersionDefinition ver;
  ver.name = verStr;
  ver.globals = globals;

  // User-defined version number starts from 2 because 0 and 1 are
  // reserved for VER_NDX_LOCAL and VER_NDX_GLOBAL, respectively.
  ver.id = config->versionDefinitions.size() + 2;
  config->versionDefinitions.push_back(ver);

  // Each version may have a parent version. For example, "Ver2"
  // defined as "Ver2 { global: foo; local: *; } Ver1;" has "Ver1"
  // as a parent. This version hierarchy is, probably against your
  // instinct, purely for hint; the runtime doesn't care about it
  // at all. In LLD, we simply ignore it.
  if (peek() != ";")
    skip();
  expect(";");
}

static bool hasWildcard(StringRef s) {
  return s.find_first_of("?*[") != StringRef::npos;
}

// Reads a list of symbols, e.g. "{ global: foo; bar; local: *; };".
std::pair<std::vector<SymbolVersion>, std::vector<SymbolVersion>>
ScriptParser::readSymbols() {
  std::vector<SymbolVersion> locals;
  std::vector<SymbolVersion> globals;
  std::vector<SymbolVersion> *v = &globals;

  while (!errorCount()) {
    if (consume("}"))
      break;
    if (consumeLabel("local")) {
      v = &locals;
      continue;
    }
    if (consumeLabel("global")) {
      v = &globals;
      continue;
    }

    if (consume("extern")) {
      std::vector<SymbolVersion> ext = readVersionExtern();
      v->insert(v->end(), ext.begin(), ext.end());
    } else {
      StringRef tok = next();
      v->push_back({unquote(tok), false, hasWildcard(tok)});
    }
    expect(";");
  }
  return {locals, globals};
}

// Reads an "extern C++" directive, e.g.,
// "extern "C++" { ns::*; "f(int, double)"; };"
//
// The last semicolon is optional. E.g. this is OK:
// "extern "C++" { ns::*; "f(int, double)" };"
std::vector<SymbolVersion> ScriptParser::readVersionExtern() {
  StringRef tok = next();
  bool isCXX = tok == "\"C++\"";
  if (!isCXX && tok != "\"C\"")
    setError("Unknown language");
  expect("{");

  std::vector<SymbolVersion> ret;
  while (!errorCount() && peek() != "}") {
    StringRef tok = next();
    ret.push_back(
        {unquote(tok), isCXX, !tok.startswith("\"") && hasWildcard(tok)});
    if (consume("}"))
      return ret;
    expect(";");
  }

  expect("}");
  return ret;
}

uint64_t ScriptParser::readMemoryAssignment(StringRef s1, StringRef s2,
                                            StringRef s3) {
  if (!consume(s1) && !consume(s2) && !consume(s3)) {
    setError("expected one of: " + s1 + ", " + s2 + ", or " + s3);
    return 0;
  }
  expect("=");
  return readExpr()().getValue();
}

// Parse the MEMORY command as specified in:
// https://sourceware.org/binutils/docs/ld/MEMORY.html
//
// MEMORY { name [(attr)] : ORIGIN = origin, LENGTH = len ... }
void ScriptParser::readMemory() {
  expect("{");
  while (!errorCount() && !consume("}")) {
    StringRef tok = next();
    if (tok == "INCLUDE") {
      readInclude();
      continue;
    }

    uint32_t flags = 0;
    uint32_t negFlags = 0;
    if (consume("(")) {
      std::tie(flags, negFlags) = readMemoryAttributes();
      expect(")");
    }
    expect(":");

    uint64_t origin = readMemoryAssignment("ORIGIN", "org", "o");
    expect(",");
    uint64_t length = readMemoryAssignment("LENGTH", "len", "l");

    // Add the memory region to the region map.
    MemoryRegion *mr = make<MemoryRegion>(tok, origin, length, flags, negFlags);
    if (!script->memoryRegions.insert({tok, mr}).second)
      setError("region '" + tok + "' already defined");
  }
}

// This function parses the attributes used to match against section
// flags when placing output sections in a memory region. These flags
// are only used when an explicit memory region name is not used.
std::pair<uint32_t, uint32_t> ScriptParser::readMemoryAttributes() {
  uint32_t flags = 0;
  uint32_t negFlags = 0;
  bool invert = false;

  for (char c : next().lower()) {
    uint32_t flag = 0;
    if (c == '!')
      invert = !invert;
    else if (c == 'w')
      flag = SHF_WRITE;
    else if (c == 'x')
      flag = SHF_EXECINSTR;
    else if (c == 'a')
      flag = SHF_ALLOC;
    else if (c != 'r')
      setError("invalid memory region attribute");

    if (invert)
      negFlags |= flag;
    else
      flags |= flag;
  }
  return {flags, negFlags};
}

void elf::readLinkerScript(MemoryBufferRef mb) {
  ScriptParser(mb).readLinkerScript();
}

void elf::readVersionScript(MemoryBufferRef mb) {
  ScriptParser(mb).readVersionScript();
}

void elf::readDynamicList(MemoryBufferRef mb) {
  ScriptParser(mb).readDynamicList();
}

void elf::readDefsym(StringRef name, MemoryBufferRef mb) {
  ScriptParser(mb).readDefsym(name);
}
