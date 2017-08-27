//===- OutputSections.cpp -------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "OutputSections.h"
#include "Config.h"
#include "LinkerScript.h"
#include "Memory.h"
#include "Strings.h"
#include "SymbolTable.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "Threads.h"
#include "llvm/BinaryFormat/Dwarf.h"
#include "llvm/Support/MD5.h"
#include "llvm/Support/MathExtras.h"
#include "llvm/Support/SHA1.h"

using namespace llvm;
using namespace llvm::dwarf;
using namespace llvm::object;
using namespace llvm::support::endian;
using namespace llvm::ELF;

using namespace lld;
using namespace lld::elf;

uint8_t Out::First;
OutputSection *Out::Opd;
uint8_t *Out::OpdBuf;
PhdrEntry *Out::TlsPhdr;
OutputSection *Out::DebugInfo;
OutputSection *Out::ElfHeader;
OutputSection *Out::ProgramHeaders;
OutputSection *Out::PreinitArray;
OutputSection *Out::InitArray;
OutputSection *Out::FiniArray;

std::vector<OutputSection *> elf::OutputSections;
std::vector<OutputSectionCommand *> elf::OutputSectionCommands;

uint32_t OutputSection::getPhdrFlags() const {
  uint32_t Ret = PF_R;
  if (Flags & SHF_WRITE)
    Ret |= PF_W;
  if (Flags & SHF_EXECINSTR)
    Ret |= PF_X;
  return Ret;
}

template <class ELFT>
void OutputSection::writeHeaderTo(typename ELFT::Shdr *Shdr) {
  Shdr->sh_entsize = Entsize;
  Shdr->sh_addralign = Alignment;
  Shdr->sh_type = Type;
  Shdr->sh_offset = Offset;
  Shdr->sh_flags = Flags;
  Shdr->sh_info = Info;
  Shdr->sh_link = Link;
  Shdr->sh_addr = Addr;
  Shdr->sh_size = Size;
  Shdr->sh_name = ShName;
}

OutputSection::OutputSection(StringRef Name, uint32_t Type, uint64_t Flags)
    : SectionBase(Output, Name, Flags, /*Entsize*/ 0, /*Alignment*/ 1, Type,
                  /*Info*/ 0,
                  /*Link*/ 0),
      SectionIndex(INT_MAX) {}

static uint64_t updateOffset(uint64_t Off, InputSection *S) {
  Off = alignTo(Off, S->Alignment);
  S->OutSecOff = Off;
  return Off + S->getSize();
}

void OutputSection::addSection(InputSection *S) {
  assert(S->Live);
  Sections.push_back(S);
  S->Parent = this;
  this->updateAlignment(S->Alignment);

  // The actual offsets will be computed by assignAddresses. For now, use
  // crude approximation so that it is at least easy for other code to know the
  // section order. It is also used to calculate the output section size early
  // for compressed debug sections.
  this->Size = updateOffset(Size, S);

  // If this section contains a table of fixed-size entries, sh_entsize
  // holds the element size. Consequently, if this contains two or more
  // input sections, all of them must have the same sh_entsize. However,
  // you can put different types of input sections into one output
  // sectin by using linker scripts. I don't know what to do here.
  // Probably we sholuld handle that as an error. But for now we just
  // pick the largest sh_entsize.
  this->Entsize = std::max(this->Entsize, S->Entsize);
}

static SectionKey createKey(InputSectionBase *C, StringRef OutsecName) {
  //  The ELF spec just says
  // ----------------------------------------------------------------
  // In the first phase, input sections that match in name, type and
  // attribute flags should be concatenated into single sections.
  // ----------------------------------------------------------------
  //
  // However, it is clear that at least some flags have to be ignored for
  // section merging. At the very least SHF_GROUP and SHF_COMPRESSED have to be
  // ignored. We should not have two output .text sections just because one was
  // in a group and another was not for example.
  //
  // It also seems that that wording was a late addition and didn't get the
  // necessary scrutiny.
  //
  // Merging sections with different flags is expected by some users. One
  // reason is that if one file has
  //
  // int *const bar __attribute__((section(".foo"))) = (int *)0;
  //
  // gcc with -fPIC will produce a read only .foo section. But if another
  // file has
  //
  // int zed;
  // int *const bar __attribute__((section(".foo"))) = (int *)&zed;
  //
  // gcc with -fPIC will produce a read write section.
  //
  // Last but not least, when using linker script the merge rules are forced by
  // the script. Unfortunately, linker scripts are name based. This means that
  // expressions like *(.foo*) can refer to multiple input sections with
  // different flags. We cannot put them in different output sections or we
  // would produce wrong results for
  //
  // start = .; *(.foo.*) end = .; *(.bar)
  //
  // and a mapping of .foo1 and .bar1 to one section and .foo2 and .bar2 to
  // another. The problem is that there is no way to layout those output
  // sections such that the .foo sections are the only thing between the start
  // and end symbols.
  //
  // Given the above issues, we instead merge sections by name and error on
  // incompatible types and flags.

  uint32_t Alignment = 0;
  uint64_t Flags = 0;
  if (Config->Relocatable && (C->Flags & SHF_MERGE)) {
    Alignment = std::max<uint64_t>(C->Alignment, C->Entsize);
    Flags = C->Flags & (SHF_MERGE | SHF_STRINGS);
  }

  return SectionKey{OutsecName, Flags, Alignment};
}

OutputSectionFactory::OutputSectionFactory() {}

static uint64_t getIncompatibleFlags(uint64_t Flags) {
  return Flags & (SHF_ALLOC | SHF_TLS);
}

// We allow sections of types listed below to merged into a
// single progbits section. This is typically done by linker
// scripts. Merging nobits and progbits will force disk space
// to be allocated for nobits sections. Other ones don't require
// any special treatment on top of progbits, so there doesn't
// seem to be a harm in merging them.
static bool canMergeToProgbits(unsigned Type) {
  return Type == SHT_NOBITS || Type == SHT_PROGBITS || Type == SHT_INIT_ARRAY ||
         Type == SHT_PREINIT_ARRAY || Type == SHT_FINI_ARRAY ||
         Type == SHT_NOTE;
}

void elf::reportDiscarded(InputSectionBase *IS) {
  if (!Config->PrintGcSections)
    return;
  message("removing unused section from '" + IS->Name + "' in file '" +
          IS->File->getName() + "'");
}

void OutputSectionFactory::addInputSec(InputSectionBase *IS,
                                       StringRef OutsecName) {
  // Sections with the SHT_GROUP attribute reach here only when the - r option
  // is given. Such sections define "section groups", and InputFiles.cpp has
  // dedup'ed section groups by their signatures. For the -r, we want to pass
  // through all SHT_GROUP sections without merging them because merging them
  // creates broken section contents.
  if (IS->Type == SHT_GROUP) {
    OutputSection *Out = nullptr;
    addInputSec(IS, OutsecName, Out);
    return;
  }

  // Imagine .zed : { *(.foo) *(.bar) } script. Both foo and bar may have
  // relocation sections .rela.foo and .rela.bar for example. Most tools do
  // not allow multiple REL[A] sections for output section. Hence we
  // should combine these relocation sections into single output.
  // We skip synthetic sections because it can be .rela.dyn/.rela.plt or any
  // other REL[A] sections created by linker itself.
  if (!isa<SyntheticSection>(IS) &&
      (IS->Type == SHT_REL || IS->Type == SHT_RELA)) {
    auto *Sec = cast<InputSection>(IS);
    OutputSection *Out = Sec->getRelocatedSection()->getOutputSection();
    addInputSec(IS, OutsecName, Out->RelocationSection);
    return;
  }

  SectionKey Key = createKey(IS, OutsecName);
  OutputSection *&Sec = Map[Key];
  addInputSec(IS, OutsecName, Sec);
}

void OutputSectionFactory::addInputSec(InputSectionBase *IS,
                                       StringRef OutsecName,
                                       OutputSection *&Sec) {
  if (!IS->Live) {
    reportDiscarded(IS);
    return;
  }

  if (Sec) {
    if (getIncompatibleFlags(Sec->Flags) != getIncompatibleFlags(IS->Flags))
      error("incompatible section flags for " + Sec->Name + "\n>>> " +
            toString(IS) + ": 0x" + utohexstr(IS->Flags) +
            "\n>>> output section " + Sec->Name + ": 0x" +
            utohexstr(Sec->Flags));
    if (Sec->Type != IS->Type) {
      if (canMergeToProgbits(Sec->Type) && canMergeToProgbits(IS->Type))
        Sec->Type = SHT_PROGBITS;
      else
        error("section type mismatch for " + IS->Name + "\n>>> " +
              toString(IS) + ": " +
              getELFSectionTypeName(Config->EMachine, IS->Type) +
              "\n>>> output section " + Sec->Name + ": " +
              getELFSectionTypeName(Config->EMachine, Sec->Type));
    }
    Sec->Flags |= IS->Flags;
  } else {
    Sec = make<OutputSection>(OutsecName, IS->Type, IS->Flags);
    OutputSections.push_back(Sec);
  }

  Sec->addSection(cast<InputSection>(IS));
}

OutputSectionFactory::~OutputSectionFactory() {}

SectionKey DenseMapInfo<SectionKey>::getEmptyKey() {
  return SectionKey{DenseMapInfo<StringRef>::getEmptyKey(), 0, 0};
}

SectionKey DenseMapInfo<SectionKey>::getTombstoneKey() {
  return SectionKey{DenseMapInfo<StringRef>::getTombstoneKey(), 0, 0};
}

unsigned DenseMapInfo<SectionKey>::getHashValue(const SectionKey &Val) {
  return hash_combine(Val.Name, Val.Flags, Val.Alignment);
}

bool DenseMapInfo<SectionKey>::isEqual(const SectionKey &LHS,
                                       const SectionKey &RHS) {
  return DenseMapInfo<StringRef>::isEqual(LHS.Name, RHS.Name) &&
         LHS.Flags == RHS.Flags && LHS.Alignment == RHS.Alignment;
}

uint64_t elf::getHeaderSize() {
  if (Config->OFormatBinary)
    return 0;
  return Out::ElfHeader->Size + Out::ProgramHeaders->Size;
}

template void OutputSection::writeHeaderTo<ELF32LE>(ELF32LE::Shdr *Shdr);
template void OutputSection::writeHeaderTo<ELF32BE>(ELF32BE::Shdr *Shdr);
template void OutputSection::writeHeaderTo<ELF64LE>(ELF64LE::Shdr *Shdr);
template void OutputSection::writeHeaderTo<ELF64BE>(ELF64BE::Shdr *Shdr);
