//===- Symbols.cpp --------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "Symbols.h"
#include "InputFiles.h"
#include "InputSection.h"
#include "OutputSections.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "Writer.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Strings.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/Support/Path.h"
#include <cstring>

using namespace llvm;
using namespace llvm::object;
using namespace llvm::ELF;

using namespace lld;
using namespace lld::elf;

Defined *ElfSym::bss;
Defined *ElfSym::etext1;
Defined *ElfSym::etext2;
Defined *ElfSym::edata1;
Defined *ElfSym::edata2;
Defined *ElfSym::end1;
Defined *ElfSym::end2;
Defined *ElfSym::globalOffsetTable;
Defined *ElfSym::mipsGp;
Defined *ElfSym::mipsGpDisp;
Defined *ElfSym::mipsLocalGp;
Defined *ElfSym::relaIpltStart;
Defined *ElfSym::relaIpltEnd;
Defined *ElfSym::riscvGlobalPointer;
Defined *ElfSym::tlsModuleBase;

// Returns a symbol for an error message.
static std::string demangle(StringRef symName) {
  if (config->demangle)
    if (Optional<std::string> s = demangleItanium(symName))
      return *s;
  return symName;
}
namespace lld {
std::string toString(const Symbol &b) { return demangle(b.getName()); }
std::string toELFString(const Archive::Symbol &b) {
  return demangle(b.getName());
}
} // namespace lld

static uint64_t getSymVA(const Symbol &sym, int64_t &addend) {
  switch (sym.kind()) {
  case Symbol::DefinedKind: {
    auto &d = cast<Defined>(sym);
    SectionBase *isec = d.section;

    // This is an absolute symbol.
    if (!isec)
      return d.value;

    assert(isec != &InputSection::discarded);
    isec = isec->repl;

    uint64_t offset = d.value;

    // An object in an SHF_MERGE section might be referenced via a
    // section symbol (as a hack for reducing the number of local
    // symbols).
    // Depending on the addend, the reference via a section symbol
    // refers to a different object in the merge section.
    // Since the objects in the merge section are not necessarily
    // contiguous in the output, the addend can thus affect the final
    // VA in a non-linear way.
    // To make this work, we incorporate the addend into the section
    // offset (and zero out the addend for later processing) so that
    // we find the right object in the section.
    if (d.isSection()) {
      offset += addend;
      addend = 0;
    }

    // In the typical case, this is actually very simple and boils
    // down to adding together 3 numbers:
    // 1. The address of the output section.
    // 2. The offset of the input section within the output section.
    // 3. The offset within the input section (this addition happens
    //    inside InputSection::getOffset).
    //
    // If you understand the data structures involved with this next
    // line (and how they get built), then you have a pretty good
    // understanding of the linker.
    uint64_t va = isec->getVA(offset);

    // MIPS relocatable files can mix regular and microMIPS code.
    // Linker needs to distinguish such code. To do so microMIPS
    // symbols has the `STO_MIPS_MICROMIPS` flag in the `st_other`
    // field. Unfortunately, the `MIPS::relocateOne()` method has
    // a symbol value only. To pass type of the symbol (regular/microMIPS)
    // to that routine as well as other places where we write
    // a symbol value as-is (.dynamic section, `Elf_Ehdr::e_entry`
    // field etc) do the same trick as compiler uses to mark microMIPS
    // for CPU - set the less-significant bit.
    if (config->emachine == EM_MIPS && isMicroMips() &&
        ((sym.stOther & STO_MIPS_MICROMIPS) || sym.needsPltAddr))
      va |= 1;

    if (d.isTls() && !config->relocatable) {
      // Use the address of the TLS segment's first section rather than the
      // segment's address, because segment addresses aren't initialized until
      // after sections are finalized. (e.g. Measuring the size of .rela.dyn
      // for Android relocation packing requires knowing TLS symbol addresses
      // during section finalization.)
      if (!Out::tlsPhdr || !Out::tlsPhdr->firstSec)
        fatal(toString(d.file) +
              " has an STT_TLS symbol but doesn't have an SHF_TLS section");
      return va - Out::tlsPhdr->firstSec->addr;
    }
    return va;
  }
  case Symbol::SharedKind:
  case Symbol::UndefinedKind:
    return 0;
  case Symbol::LazyArchiveKind:
  case Symbol::LazyObjectKind:
    assert(sym.isUsedInRegularObj && "lazy symbol reached writer");
    return 0;
  case Symbol::CommonKind:
    llvm_unreachable("common symbol reached writer");
  case Symbol::PlaceholderKind:
    llvm_unreachable("placeholder symbol reached writer");
  }
  llvm_unreachable("invalid symbol kind");
}

uint64_t Symbol::getVA(int64_t addend) const {
  uint64_t outVA = getSymVA(*this, addend);
  return outVA + addend;
}

uint64_t Symbol::getGotVA() const {
  if (gotInIgot)
    return in.igotPlt->getVA() + getGotPltOffset();
  return in.got->getVA() + getGotOffset();
}

uint64_t Symbol::getGotOffset() const { return gotIndex * config->wordsize; }

uint64_t Symbol::getGotPltVA() const {
  if (isInIplt)
    return in.igotPlt->getVA() + getGotPltOffset();
  return in.gotPlt->getVA() + getGotPltOffset();
}

uint64_t Symbol::getGotPltOffset() const {
  if (isInIplt)
    return pltIndex * config->wordsize;
  return (pltIndex + target->gotPltHeaderEntriesNum) * config->wordsize;
}

uint64_t Symbol::getPPC64LongBranchOffset() const {
  assert(ppc64BranchltIndex != 0xffff);
  return ppc64BranchltIndex * config->wordsize;
}

uint64_t Symbol::getPltVA() const {
  PltSection *plt = isInIplt ? in.iplt : in.plt;
  uint64_t outVA =
      plt->getVA() + plt->headerSize + pltIndex * target->pltEntrySize;
  // While linking microMIPS code PLT code are always microMIPS
  // code. Set the less-significant bit to track that fact.
  // See detailed comment in the `getSymVA` function.
  if (config->emachine == EM_MIPS && isMicroMips())
    outVA |= 1;
  return outVA;
}

uint64_t Symbol::getPPC64LongBranchTableVA() const {
  assert(ppc64BranchltIndex != 0xffff);
  return in.ppc64LongBranchTarget->getVA() +
         ppc64BranchltIndex * config->wordsize;
}

uint64_t Symbol::getSize() const {
  if (const auto *dr = dyn_cast<Defined>(this))
    return dr->size;
  return cast<SharedSymbol>(this)->size;
}

OutputSection *Symbol::getOutputSection() const {
  if (auto *s = dyn_cast<Defined>(this)) {
    if (auto *sec = s->section)
      return sec->repl->getOutputSection();
    return nullptr;
  }
  return nullptr;
}

// If a symbol name contains '@', the characters after that is
// a symbol version name. This function parses that.
void Symbol::parseSymbolVersion() {
  StringRef s = getName();
  size_t pos = s.find('@');
  if (pos == 0 || pos == StringRef::npos)
    return;
  StringRef verstr = s.substr(pos + 1);
  if (verstr.empty())
    return;

  // Truncate the symbol name so that it doesn't include the version string.
  nameSize = pos;

  // If this is not in this DSO, it is not a definition.
  if (!isDefined())
    return;

  // '@@' in a symbol name means the default version.
  // It is usually the most recent one.
  bool isDefault = (verstr[0] == '@');
  if (isDefault)
    verstr = verstr.substr(1);

  for (VersionDefinition &ver : config->versionDefinitions) {
    if (ver.name != verstr)
      continue;

    if (isDefault)
      versionId = ver.id;
    else
      versionId = ver.id | VERSYM_HIDDEN;
    return;
  }

  // It is an error if the specified version is not defined.
  // Usually version script is not provided when linking executable,
  // but we may still want to override a versioned symbol from DSO,
  // so we do not report error in this case. We also do not error
  // if the symbol has a local version as it won't be in the dynamic
  // symbol table.
  if (config->shared && versionId != VER_NDX_LOCAL)
    error(toString(file) + ": symbol " + s + " has undefined version " +
          verstr);
}

void Symbol::fetch() const {
  if (auto *sym = dyn_cast<LazyArchive>(this)) {
    cast<ArchiveFile>(sym->file)->fetch(sym->sym);
    return;
  }

  if (auto *sym = dyn_cast<LazyObject>(this)) {
    dyn_cast<LazyObjFile>(sym->file)->fetch();
    return;
  }

  llvm_unreachable("Symbol::fetch() is called on a non-lazy symbol");
}

MemoryBufferRef LazyArchive::getMemberBuffer() {
  Archive::Child c =
      CHECK(sym.getMember(),
            "could not get the member for symbol " + toELFString(sym));

  return CHECK(c.getMemoryBufferRef(),
               "could not get the buffer for the member defining symbol " +
                   toELFString(sym));
}

uint8_t Symbol::computeBinding() const {
  if (config->relocatable)
    return binding;
  if (visibility != STV_DEFAULT && visibility != STV_PROTECTED)
    return STB_LOCAL;
  if (versionId == VER_NDX_LOCAL && isDefined() && !isPreemptible)
    return STB_LOCAL;
  if (!config->gnuUnique && binding == STB_GNU_UNIQUE)
    return STB_GLOBAL;
  return binding;
}

bool Symbol::includeInDynsym() const {
  if (!config->hasDynSymTab)
    return false;
  if (computeBinding() == STB_LOCAL)
    return false;

  // If a PIE binary was not linked against any shared libraries, then we can
  // safely drop weak undef symbols from .dynsym.
  if (isUndefWeak() && config->pie && sharedFiles.empty())
    return false;

  return isUndefined() || isShared() || exportDynamic;
}

// Print out a log message for --trace-symbol.
void elf::printTraceSymbol(const Symbol *sym) {
  std::string s;
  if (sym->isUndefined())
    s = ": reference to ";
  else if (sym->isLazy())
    s = ": lazy definition of ";
  else if (sym->isShared())
    s = ": shared definition of ";
  else if (sym->isCommon())
    s = ": common definition of ";
  else
    s = ": definition of ";

  message(toString(sym->file) + s + sym->getName());
}

void elf::maybeWarnUnorderableSymbol(const Symbol *sym) {
  if (!config->warnSymbolOrdering)
    return;

  // If UnresolvedPolicy::Ignore is used, no "undefined symbol" error/warning
  // is emitted. It makes sense to not warn on undefined symbols.
  //
  // Note, ld.bfd --symbol-ordering-file= does not warn on undefined symbols,
  // but we don't have to be compatible here.
  if (sym->isUndefined() &&
      config->unresolvedSymbols == UnresolvedPolicy::Ignore)
    return;

  const InputFile *file = sym->file;
  auto *d = dyn_cast<Defined>(sym);

  auto report = [&](StringRef s) { warn(toString(file) + s + sym->getName()); };

  if (sym->isUndefined())
    report(": unable to order undefined symbol: ");
  else if (sym->isShared())
    report(": unable to order shared symbol: ");
  else if (d && !d->section)
    report(": unable to order absolute symbol: ");
  else if (d && isa<OutputSection>(d->section))
    report(": unable to order synthetic symbol: ");
  else if (d && !d->section->repl->isLive())
    report(": unable to order discarded symbol: ");
}

static uint8_t getMinVisibility(uint8_t va, uint8_t vb) {
  if (va == STV_DEFAULT)
    return vb;
  if (vb == STV_DEFAULT)
    return va;
  return std::min(va, vb);
}

// Merge symbol properties.
//
// When we have many symbols of the same name, we choose one of them,
// and that's the result of symbol resolution. However, symbols that
// were not chosen still affect some symbol properties.
void Symbol::mergeProperties(const Symbol &other) {
  if (other.exportDynamic)
    exportDynamic = true;
  if (other.isUsedInRegularObj)
    isUsedInRegularObj = true;

  // DSO symbols do not affect visibility in the output.
  if (!other.isShared())
    visibility = getMinVisibility(visibility, other.visibility);
}

void Symbol::resolve(const Symbol &other) {
  mergeProperties(other);

  if (isPlaceholder()) {
    replace(other);
    return;
  }

  switch (other.kind()) {
  case Symbol::UndefinedKind:
    resolveUndefined(cast<Undefined>(other));
    break;
  case Symbol::CommonKind:
    resolveCommon(cast<CommonSymbol>(other));
    break;
  case Symbol::DefinedKind:
    resolveDefined(cast<Defined>(other));
    break;
  case Symbol::LazyArchiveKind:
    resolveLazy(cast<LazyArchive>(other));
    break;
  case Symbol::LazyObjectKind:
    resolveLazy(cast<LazyObject>(other));
    break;
  case Symbol::SharedKind:
    resolveShared(cast<SharedSymbol>(other));
    break;
  case Symbol::PlaceholderKind:
    llvm_unreachable("bad symbol kind");
  }
}

void Symbol::resolveUndefined(const Undefined &other) {
  // An undefined symbol with non default visibility must be satisfied
  // in the same DSO.
  //
  // If this is a non-weak defined symbol in a discarded section, override the
  // existing undefined symbol for better error message later.
  if ((isShared() && other.visibility != STV_DEFAULT) ||
      (isUndefined() && other.binding != STB_WEAK && other.discardedSecIdx)) {
    replace(other);
    return;
  }

  if (traced)
    printTraceSymbol(&other);

  if (isLazy()) {
    // An undefined weak will not fetch archive members. See comment on Lazy in
    // Symbols.h for the details.
    if (other.binding == STB_WEAK) {
      binding = STB_WEAK;
      type = other.type;
      return;
    }

    // Do extra check for --warn-backrefs.
    //
    // --warn-backrefs is an option to prevent an undefined reference from
    // fetching an archive member written earlier in the command line. It can be
    // used to keep compatibility with GNU linkers to some degree.
    // I'll explain the feature and why you may find it useful in this comment.
    //
    // lld's symbol resolution semantics is more relaxed than traditional Unix
    // linkers. For example,
    //
    //   ld.lld foo.a bar.o
    //
    // succeeds even if bar.o contains an undefined symbol that has to be
    // resolved by some object file in foo.a. Traditional Unix linkers don't
    // allow this kind of backward reference, as they visit each file only once
    // from left to right in the command line while resolving all undefined
    // symbols at the moment of visiting.
    //
    // In the above case, since there's no undefined symbol when a linker visits
    // foo.a, no files are pulled out from foo.a, and because the linker forgets
    // about foo.a after visiting, it can't resolve undefined symbols in bar.o
    // that could have been resolved otherwise.
    //
    // That lld accepts more relaxed form means that (besides it'd make more
    // sense) you can accidentally write a command line or a build file that
    // works only with lld, even if you have a plan to distribute it to wider
    // users who may be using GNU linkers. With --warn-backrefs, you can detect
    // a library order that doesn't work with other Unix linkers.
    //
    // The option is also useful to detect cyclic dependencies between static
    // archives. Again, lld accepts
    //
    //   ld.lld foo.a bar.a
    //
    // even if foo.a and bar.a depend on each other. With --warn-backrefs, it is
    // handled as an error.
    //
    // Here is how the option works. We assign a group ID to each file. A file
    // with a smaller group ID can pull out object files from an archive file
    // with an equal or greater group ID. Otherwise, it is a reverse dependency
    // and an error.
    //
    // A file outside --{start,end}-group gets a fresh ID when instantiated. All
    // files within the same --{start,end}-group get the same group ID. E.g.
    //
    //   ld.lld A B --start-group C D --end-group E
    //
    // A forms group 0. B form group 1. C and D (including their member object
    // files) form group 2. E forms group 3. I think that you can see how this
    // group assignment rule simulates the traditional linker's semantics.
    bool backref = config->warnBackrefs && other.file &&
                   file->groupId < other.file->groupId;
    fetch();

    // We don't report backward references to weak symbols as they can be
    // overridden later.
    if (backref && !isWeak())
      warn("backward reference detected: " + other.getName() + " in " +
           toString(other.file) + " refers to " + toString(file));
    return;
  }

  // Undefined symbols in a SharedFile do not change the binding.
  if (dyn_cast_or_null<SharedFile>(other.file))
    return;

  if (isUndefined()) {
    // The binding may "upgrade" from weak to non-weak.
    if (other.binding != STB_WEAK)
      binding = other.binding;
  } else if (auto *s = dyn_cast<SharedSymbol>(this)) {
    // The binding of a SharedSymbol will be weak if there is at least one
    // reference and all are weak. The binding has one opportunity to change to
    // weak: if the first reference is weak.
    if (other.binding != STB_WEAK || !s->referenced)
      binding = other.binding;
    s->referenced = true;
  }
}

// Using .symver foo,foo@@VER unfortunately creates two symbols: foo and
// foo@@VER. We want to effectively ignore foo, so give precedence to
// foo@@VER.
// FIXME: If users can transition to using
// .symver foo,foo@@@VER
// we can delete this hack.
static int compareVersion(StringRef a, StringRef b) {
  bool x = a.contains("@@");
  bool y = b.contains("@@");
  if (!x && y)
    return 1;
  if (x && !y)
    return -1;
  return 0;
}

// Compare two symbols. Return 1 if the new symbol should win, -1 if
// the new symbol should lose, or 0 if there is a conflict.
int Symbol::compare(const Symbol *other) const {
  assert(other->isDefined() || other->isCommon());

  if (!isDefined() && !isCommon())
    return 1;

  if (int cmp = compareVersion(getName(), other->getName()))
    return cmp;

  if (other->isWeak())
    return -1;

  if (isWeak())
    return 1;

  if (isCommon() && other->isCommon()) {
    if (config->warnCommon)
      warn("multiple common of " + getName());
    return 0;
  }

  if (isCommon()) {
    if (config->warnCommon)
      warn("common " + getName() + " is overridden");
    return 1;
  }

  if (other->isCommon()) {
    if (config->warnCommon)
      warn("common " + getName() + " is overridden");
    return -1;
  }

  auto *oldSym = cast<Defined>(this);
  auto *newSym = cast<Defined>(other);

  if (other->file && isa<BitcodeFile>(other->file))
    return 0;

  if (!oldSym->section && !newSym->section && oldSym->value == newSym->value &&
      newSym->binding == STB_GLOBAL)
    return -1;

  return 0;
}

static void reportDuplicate(Symbol *sym, InputFile *newFile,
                            InputSectionBase *errSec, uint64_t errOffset) {
  if (config->allowMultipleDefinition)
    return;

  Defined *d = cast<Defined>(sym);
  if (!d->section || !errSec) {
    error("duplicate symbol: " + toString(*sym) + "\n>>> defined in " +
          toString(sym->file) + "\n>>> defined in " + toString(newFile));
    return;
  }

  // Construct and print an error message in the form of:
  //
  //   ld.lld: error: duplicate symbol: foo
  //   >>> defined at bar.c:30
  //   >>>            bar.o (/home/alice/src/bar.o)
  //   >>> defined at baz.c:563
  //   >>>            baz.o in archive libbaz.a
  auto *sec1 = cast<InputSectionBase>(d->section);
  std::string src1 = sec1->getSrcMsg(*sym, d->value);
  std::string obj1 = sec1->getObjMsg(d->value);
  std::string src2 = errSec->getSrcMsg(*sym, errOffset);
  std::string obj2 = errSec->getObjMsg(errOffset);

  std::string msg = "duplicate symbol: " + toString(*sym) + "\n>>> defined at ";
  if (!src1.empty())
    msg += src1 + "\n>>>            ";
  msg += obj1 + "\n>>> defined at ";
  if (!src2.empty())
    msg += src2 + "\n>>>            ";
  msg += obj2;
  error(msg);
}

void Symbol::resolveCommon(const CommonSymbol &other) {
  int cmp = compare(&other);
  if (cmp < 0)
    return;

  if (cmp > 0) {
    replace(other);
    return;
  }

  CommonSymbol *oldSym = cast<CommonSymbol>(this);

  oldSym->alignment = std::max(oldSym->alignment, other.alignment);
  if (oldSym->size < other.size) {
    oldSym->file = other.file;
    oldSym->size = other.size;
  }
}

void Symbol::resolveDefined(const Defined &other) {
  int cmp = compare(&other);
  if (cmp > 0)
    replace(other);
  else if (cmp == 0)
    reportDuplicate(this, other.file,
                    dyn_cast_or_null<InputSectionBase>(other.section),
                    other.value);
}

template <class LazyT> void Symbol::resolveLazy(const LazyT &other) {
  if (!isUndefined())
    return;

  // An undefined weak will not fetch archive members. See comment on Lazy in
  // Symbols.h for the details.
  if (isWeak()) {
    uint8_t ty = type;
    replace(other);
    type = ty;
    binding = STB_WEAK;
    return;
  }

  other.fetch();
}

void Symbol::resolveShared(const SharedSymbol &other) {
  if (visibility == STV_DEFAULT && (isUndefined() || isLazy())) {
    // An undefined symbol with non default visibility must be satisfied
    // in the same DSO.
    uint8_t bind = binding;
    replace(other);
    binding = bind;
    cast<SharedSymbol>(this)->referenced = true;
  }
}
