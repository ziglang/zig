//===- LinkerScript.h -------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_ELF_LINKER_SCRIPT_H
#define LLD_ELF_LINKER_SCRIPT_H

#include "Config.h"
#include "Writer.h"
#include "lld/Common/LLVM.h"
#include "lld/Common/Strings.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/MapVector.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/MemoryBuffer.h"
#include <cstddef>
#include <cstdint>
#include <functional>
#include <memory>
#include <vector>

namespace lld {
namespace elf {

class Defined;
class InputSection;
class InputSectionBase;
class OutputSection;
class SectionBase;
class Symbol;
class ThunkSection;

// This represents an r-value in the linker script.
struct ExprValue {
  ExprValue(SectionBase *sec, bool forceAbsolute, uint64_t val,
            const Twine &loc)
      : sec(sec), forceAbsolute(forceAbsolute), val(val), loc(loc.str()) {}

  ExprValue(uint64_t val) : ExprValue(nullptr, false, val, "") {}

  bool isAbsolute() const { return forceAbsolute || sec == nullptr; }
  uint64_t getValue() const;
  uint64_t getSecAddr() const;
  uint64_t getSectionOffset() const;

  // If a value is relative to a section, it has a non-null Sec.
  SectionBase *sec;

  // True if this expression is enclosed in ABSOLUTE().
  // This flag affects the return value of getValue().
  bool forceAbsolute;

  uint64_t val;
  uint64_t alignment = 1;

  // Original source location. Used for error messages.
  std::string loc;
};

// This represents an expression in the linker script.
// ScriptParser::readExpr reads an expression and returns an Expr.
// Later, we evaluate the expression by calling the function.
using Expr = std::function<ExprValue()>;

// This enum is used to implement linker script SECTIONS command.
// https://sourceware.org/binutils/docs/ld/SECTIONS.html#SECTIONS
enum SectionsCommandKind {
  AssignmentKind, // . = expr or <sym> = expr
  OutputSectionKind,
  InputSectionKind,
  ByteKind    // BYTE(expr), SHORT(expr), LONG(expr) or QUAD(expr)
};

struct BaseCommand {
  BaseCommand(int k) : kind(k) {}
  int kind;
};

// This represents ". = <expr>" or "<symbol> = <expr>".
struct SymbolAssignment : BaseCommand {
  SymbolAssignment(StringRef name, Expr e, std::string loc)
      : BaseCommand(AssignmentKind), name(name), expression(e), location(loc) {}

  static bool classof(const BaseCommand *c) {
    return c->kind == AssignmentKind;
  }

  // The LHS of an expression. Name is either a symbol name or ".".
  StringRef name;
  Defined *sym = nullptr;

  // The RHS of an expression.
  Expr expression;

  // Command attributes for PROVIDE, HIDDEN and PROVIDE_HIDDEN.
  bool provide = false;
  bool hidden = false;

  // Holds file name and line number for error reporting.
  std::string location;

  // A string representation of this command. We use this for -Map.
  std::string commandString;

  // Address of this assignment command.
  unsigned addr;

  // Size of this assignment command. This is usually 0, but if
  // you move '.' this may be greater than 0.
  unsigned size;
};

// Linker scripts allow additional constraints to be put on ouput sections.
// If an output section is marked as ONLY_IF_RO, the section is created
// only if its input sections are read-only. Likewise, an output section
// with ONLY_IF_RW is created if all input sections are RW.
enum class ConstraintKind { NoConstraint, ReadOnly, ReadWrite };

// This struct is used to represent the location and size of regions of
// target memory. Instances of the struct are created by parsing the
// MEMORY command.
struct MemoryRegion {
  MemoryRegion(StringRef name, uint64_t origin, uint64_t length, uint32_t flags,
               uint32_t negFlags)
      : name(name), origin(origin), length(length), flags(flags),
        negFlags(negFlags) {}

  std::string name;
  uint64_t origin;
  uint64_t length;
  uint32_t flags;
  uint32_t negFlags;
  uint64_t curPos = 0;
};

// This struct represents one section match pattern in SECTIONS() command.
// It can optionally have negative match pattern for EXCLUDED_FILE command.
// Also it may be surrounded with SORT() command, so contains sorting rules.
struct SectionPattern {
  SectionPattern(StringMatcher &&pat1, StringMatcher &&pat2)
      : excludedFilePat(pat1), sectionPat(pat2),
        sortOuter(SortSectionPolicy::Default),
        sortInner(SortSectionPolicy::Default) {}

  StringMatcher excludedFilePat;
  StringMatcher sectionPat;
  SortSectionPolicy sortOuter;
  SortSectionPolicy sortInner;
};

struct InputSectionDescription : BaseCommand {
  InputSectionDescription(StringRef filePattern)
      : BaseCommand(InputSectionKind), filePat(filePattern) {}

  static bool classof(const BaseCommand *c) {
    return c->kind == InputSectionKind;
  }

  StringMatcher filePat;

  // Input sections that matches at least one of SectionPatterns
  // will be associated with this InputSectionDescription.
  std::vector<SectionPattern> sectionPatterns;

  std::vector<InputSection *> sections;

  // Temporary record of synthetic ThunkSection instances and the pass that
  // they were created in. This is used to insert newly created ThunkSections
  // into Sections at the end of a createThunks() pass.
  std::vector<std::pair<ThunkSection *, uint32_t>> thunkSections;
};

// Represents BYTE(), SHORT(), LONG(), or QUAD().
struct ByteCommand : BaseCommand {
  ByteCommand(Expr e, unsigned size, std::string commandString)
      : BaseCommand(ByteKind), commandString(commandString), expression(e),
        size(size) {}

  static bool classof(const BaseCommand *c) { return c->kind == ByteKind; }

  // Keeps string representing the command. Used for -Map" is perhaps better.
  std::string commandString;

  Expr expression;

  // This is just an offset of this assignment command in the output section.
  unsigned offset;

  // Size of this data command.
  unsigned size;
};

struct PhdrsCommand {
  StringRef name;
  unsigned type = llvm::ELF::PT_NULL;
  bool hasFilehdr = false;
  bool hasPhdrs = false;
  llvm::Optional<unsigned> flags;
  Expr lmaExpr = nullptr;
};

class LinkerScript final {
  // Temporary state used in processSectionCommands() and assignAddresses()
  // that must be reinitialized for each call to the above functions, and must
  // not be used outside of the scope of a call to the above functions.
  struct AddressState {
    AddressState();
    uint64_t threadBssOffset = 0;
    OutputSection *outSec = nullptr;
    MemoryRegion *memRegion = nullptr;
    MemoryRegion *lmaRegion = nullptr;
    uint64_t lmaOffset = 0;
  };

  llvm::DenseMap<StringRef, OutputSection *> nameToOutputSection;

  void addSymbol(SymbolAssignment *cmd);
  void assignSymbol(SymbolAssignment *cmd, bool inSec);
  void setDot(Expr e, const Twine &loc, bool inSec);
  void expandOutputSection(uint64_t size);
  void expandMemoryRegions(uint64_t size);

  std::vector<InputSection *>
  computeInputSections(const InputSectionDescription *);

  std::vector<InputSection *> createInputSectionList(OutputSection &cmd);

  std::vector<size_t> getPhdrIndices(OutputSection *sec);

  MemoryRegion *findMemoryRegion(OutputSection *sec);

  void switchTo(OutputSection *sec);
  uint64_t advance(uint64_t size, unsigned align);
  void output(InputSection *sec);

  void assignOffsets(OutputSection *sec);

  // Ctx captures the local AddressState and makes it accessible
  // deliberately. This is needed as there are some cases where we cannot just
  // thread the current state through to a lambda function created by the
  // script parser.
  // This should remain a plain pointer as its lifetime is smaller than
  // LinkerScript.
  AddressState *ctx = nullptr;

  OutputSection *aether;

  uint64_t dot;

public:
  OutputSection *createOutputSection(StringRef name, StringRef location);
  OutputSection *getOrCreateOutputSection(StringRef name);

  bool hasPhdrsCommands() { return !phdrsCommands.empty(); }
  uint64_t getDot() { return dot; }
  void discard(ArrayRef<InputSection *> v);

  ExprValue getSymbolValue(StringRef name, const Twine &loc);

  void addOrphanSections();
  void adjustSectionsBeforeSorting();
  void adjustSectionsAfterSorting();

  std::vector<PhdrEntry *> createPhdrs();
  bool needsInterpSection();

  bool shouldKeep(InputSectionBase *s);
  void assignAddresses();
  void allocateHeaders(std::vector<PhdrEntry *> &phdrs);
  void processSectionCommands();
  void declareSymbols();

  // Used to handle INSERT AFTER statements.
  void processInsertCommands();

  // SECTIONS command list.
  std::vector<BaseCommand *> sectionCommands;

  // PHDRS command list.
  std::vector<PhdrsCommand> phdrsCommands;

  bool hasSectionsCommand = false;
  bool errorOnMissingSection = false;

  // List of section patterns specified with KEEP commands. They will
  // be kept even if they are unused and --gc-sections is specified.
  std::vector<InputSectionDescription *> keptSections;

  // A map from memory region name to a memory region descriptor.
  llvm::MapVector<llvm::StringRef, MemoryRegion *> memoryRegions;

  // A list of symbols referenced by the script.
  std::vector<llvm::StringRef> referencedSymbols;

  // Used to implement INSERT [AFTER|BEFORE]. Contains commands that need
  // to be inserted into SECTIONS commands list.
  llvm::DenseMap<StringRef, std::vector<BaseCommand *>> insertAfterCommands;
  llvm::DenseMap<StringRef, std::vector<BaseCommand *>> insertBeforeCommands;
};

extern LinkerScript *script;

} // end namespace elf
} // end namespace lld

#endif // LLD_ELF_LINKER_SCRIPT_H
