//===- LinkerScript.h -------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_ELF_LINKER_SCRIPT_H
#define LLD_ELF_LINKER_SCRIPT_H

#include "Config.h"
#include "Strings.h"
#include "Writer.h"
#include "lld/Core/LLVM.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/MemoryBuffer.h"
#include <cstddef>
#include <cstdint>
#include <functional>
#include <memory>
#include <vector>

namespace lld {
namespace elf {

class DefinedCommon;
class SymbolBody;
class InputSectionBase;
class InputSection;
class OutputSection;
class OutputSectionFactory;
class InputSectionBase;
class SectionBase;

struct ExprValue {
  SectionBase *Sec;
  uint64_t Val;
  bool ForceAbsolute;
  uint64_t Alignment = 1;
  std::string Loc;

  ExprValue(SectionBase *Sec, bool ForceAbsolute, uint64_t Val,
            const Twine &Loc)
      : Sec(Sec), Val(Val), ForceAbsolute(ForceAbsolute), Loc(Loc.str()) {}
  ExprValue(SectionBase *Sec, uint64_t Val, const Twine &Loc)
      : ExprValue(Sec, false, Val, Loc) {}
  ExprValue(uint64_t Val) : ExprValue(nullptr, Val, "") {}
  bool isAbsolute() const { return ForceAbsolute || Sec == nullptr; }
  uint64_t getValue() const;
  uint64_t getSecAddr() const;
};

// This represents an expression in the linker script.
// ScriptParser::readExpr reads an expression and returns an Expr.
// Later, we evaluate the expression by calling the function.
typedef std::function<ExprValue()> Expr;

// This enum is used to implement linker script SECTIONS command.
// https://sourceware.org/binutils/docs/ld/SECTIONS.html#SECTIONS
enum SectionsCommandKind {
  AssignmentKind, // . = expr or <sym> = expr
  OutputSectionKind,
  InputSectionKind,
  AssertKind,   // ASSERT(expr)
  BytesDataKind // BYTE(expr), SHORT(expr), LONG(expr) or QUAD(expr)
};

struct BaseCommand {
  BaseCommand(int K) : Kind(K) {}
  int Kind;
};

// This represents ". = <expr>" or "<symbol> = <expr>".
struct SymbolAssignment : BaseCommand {
  SymbolAssignment(StringRef Name, Expr E, std::string Loc)
      : BaseCommand(AssignmentKind), Name(Name), Expression(E), Location(Loc) {}

  static bool classof(const BaseCommand *C);

  // The LHS of an expression. Name is either a symbol name or ".".
  StringRef Name;
  SymbolBody *Sym = nullptr;

  // The RHS of an expression.
  Expr Expression;

  // Command attributes for PROVIDE, HIDDEN and PROVIDE_HIDDEN.
  bool Provide = false;
  bool Hidden = false;

  // Holds file name and line number for error reporting.
  std::string Location;
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
  std::string Name;
  uint64_t Origin;
  uint64_t Length;
  uint32_t Flags;
  uint32_t NegFlags;
};

struct OutputSectionCommand : BaseCommand {
  OutputSectionCommand(StringRef Name)
      : BaseCommand(OutputSectionKind), Name(Name) {}

  static bool classof(const BaseCommand *C);

  OutputSection *Sec = nullptr;
  MemoryRegion *MemRegion = nullptr;
  StringRef Name;
  Expr AddrExpr;
  Expr AlignExpr;
  Expr LMAExpr;
  Expr SubalignExpr;
  std::vector<BaseCommand *> Commands;
  std::vector<StringRef> Phdrs;
  llvm::Optional<uint32_t> Filler;
  ConstraintKind Constraint = ConstraintKind::NoConstraint;
  std::string Location;
  std::string MemoryRegionName;
  bool Noload = false;

  template <class ELFT> void finalize();
  template <class ELFT> void writeTo(uint8_t *Buf);
  template <class ELFT> void maybeCompress();
  uint32_t getFiller();

  void sort(std::function<int(InputSectionBase *S)> Order);
  void sortInitFini();
  void sortCtorsDtors();
};

// This struct represents one section match pattern in SECTIONS() command.
// It can optionally have negative match pattern for EXCLUDED_FILE command.
// Also it may be surrounded with SORT() command, so contains sorting rules.
struct SectionPattern {
  SectionPattern(StringMatcher &&Pat1, StringMatcher &&Pat2)
      : ExcludedFilePat(Pat1), SectionPat(Pat2) {}

  StringMatcher ExcludedFilePat;
  StringMatcher SectionPat;
  SortSectionPolicy SortOuter;
  SortSectionPolicy SortInner;
};

struct InputSectionDescription : BaseCommand {
  InputSectionDescription(StringRef FilePattern)
      : BaseCommand(InputSectionKind), FilePat(FilePattern) {}

  static bool classof(const BaseCommand *C);

  StringMatcher FilePat;

  // Input sections that matches at least one of SectionPatterns
  // will be associated with this InputSectionDescription.
  std::vector<SectionPattern> SectionPatterns;

  std::vector<InputSection *> Sections;
};

// Represents an ASSERT().
struct AssertCommand : BaseCommand {
  AssertCommand(Expr E) : BaseCommand(AssertKind), Expression(E) {}

  static bool classof(const BaseCommand *C);

  Expr Expression;
};

// Represents BYTE(), SHORT(), LONG(), or QUAD().
struct BytesDataCommand : BaseCommand {
  BytesDataCommand(Expr E, unsigned Size)
      : BaseCommand(BytesDataKind), Expression(E), Size(Size) {}

  static bool classof(const BaseCommand *C);

  Expr Expression;
  unsigned Offset;
  unsigned Size;
};

struct PhdrsCommand {
  StringRef Name;
  unsigned Type;
  bool HasFilehdr;
  bool HasPhdrs;
  unsigned Flags;
  Expr LMAExpr;
};

// ScriptConfiguration holds linker script parse results.
struct ScriptConfiguration {
  // Used to assign addresses to sections.
  std::vector<BaseCommand *> Commands;

  // Used to assign sections to headers.
  std::vector<PhdrsCommand> PhdrsCommands;

  bool HasSections = false;

  // List of section patterns specified with KEEP commands. They will
  // be kept even if they are unused and --gc-sections is specified.
  std::vector<InputSectionDescription *> KeptSections;

  // A map from memory region name to a memory region descriptor.
  llvm::DenseMap<llvm::StringRef, MemoryRegion> MemoryRegions;

  // A list of symbols referenced by the script.
  std::vector<llvm::StringRef> ReferencedSymbols;
};

class LinkerScript final {
  // Temporary state used in processCommands() and assignAddresses()
  // that must be reinitialized for each call to the above functions, and must
  // not be used outside of the scope of a call to the above functions.
  struct AddressState {
    uint64_t ThreadBssOffset = 0;
    OutputSection *OutSec = nullptr;
    MemoryRegion *MemRegion = nullptr;
    llvm::DenseMap<const MemoryRegion *, uint64_t> MemRegionOffset;
    std::function<uint64_t()> LMAOffset;
    AddressState(const ScriptConfiguration &Opt);
  };
  llvm::DenseMap<OutputSection *, OutputSectionCommand *> SecToCommand;
  llvm::DenseMap<StringRef, OutputSectionCommand *> NameToOutputSectionCommand;

  void assignSymbol(SymbolAssignment *Cmd, bool InSec);
  void setDot(Expr E, const Twine &Loc, bool InSec);

  std::vector<InputSection *>
  computeInputSections(const InputSectionDescription *);

  std::vector<InputSectionBase *>
  createInputSectionList(OutputSectionCommand &Cmd);

  std::vector<size_t> getPhdrIndices(OutputSectionCommand *Cmd);
  size_t getPhdrIndex(const Twine &Loc, StringRef PhdrName);

  MemoryRegion *findMemoryRegion(OutputSectionCommand *Cmd);

  void switchTo(OutputSection *Sec);
  uint64_t advance(uint64_t Size, unsigned Align);
  void output(InputSection *Sec);
  void process(BaseCommand &Base);

  AddressState *CurAddressState = nullptr;
  OutputSection *Aether;

  uint64_t Dot;

public:
  bool ErrorOnMissingSection = false;
  OutputSectionCommand *createOutputSectionCommand(StringRef Name,
                                                   StringRef Location);
  OutputSectionCommand *getOrCreateOutputSectionCommand(StringRef Name);

  OutputSectionCommand *getCmd(OutputSection *Sec) const;
  bool hasPhdrsCommands() { return !Opt.PhdrsCommands.empty(); }
  uint64_t getDot() { return Dot; }
  void discard(ArrayRef<InputSectionBase *> V);

  ExprValue getSymbolValue(const Twine &Loc, StringRef S);
  bool isDefined(StringRef S);

  void fabricateDefaultCommands();
  void addOrphanSections(OutputSectionFactory &Factory);
  void removeEmptyCommands();
  void adjustSectionsBeforeSorting();
  void adjustSectionsAfterSorting();

  std::vector<PhdrEntry> createPhdrs();
  bool ignoreInterpSection();

  bool shouldKeep(InputSectionBase *S);
  void assignOffsets(OutputSectionCommand *Cmd);
  void processNonSectionCommands();
  void assignAddresses();
  void allocateHeaders(std::vector<PhdrEntry> &Phdrs);
  void addSymbol(SymbolAssignment *Cmd);
  void processCommands(OutputSectionFactory &Factory);

  // Parsed linker script configurations are set to this struct.
  ScriptConfiguration Opt;
};

extern LinkerScript *Script;

} // end namespace elf
} // end namespace lld

#endif // LLD_ELF_LINKER_SCRIPT_H
