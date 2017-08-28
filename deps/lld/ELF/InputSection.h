//===- InputSection.h -------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_ELF_INPUT_SECTION_H
#define LLD_ELF_INPUT_SECTION_H

#include "Config.h"
#include "Relocations.h"
#include "Thunks.h"
#include "lld/Core/LLVM.h"
#include "llvm/ADT/CachedHashString.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/TinyPtrVector.h"
#include "llvm/Object/ELF.h"
#include "llvm/Support/Threading.h"
#include <mutex>

namespace lld {
namespace elf {

class DefinedCommon;
class SymbolBody;
struct SectionPiece;

class DefinedRegular;
class SyntheticSection;
template <class ELFT> class EhFrameSection;
class MergeSyntheticSection;
template <class ELFT> class ObjectFile;
class OutputSection;

// This is the base class of all sections that lld handles. Some are sections in
// input files, some are sections in the produced output file and some exist
// just as a convenience for implementing special ways of combining some
// sections.
class SectionBase {
public:
  enum Kind { Regular, EHFrame, Merge, Synthetic, Output };

  Kind kind() const { return (Kind)SectionKind; }

  StringRef Name;

  unsigned SectionKind : 3;

  // The next two bit fields are only used by InputSectionBase, but we
  // put them here so the struct packs better.

  // The garbage collector sets sections' Live bits.
  // If GC is disabled, all sections are considered live by default.
  unsigned Live : 1;     // for garbage collection
  unsigned Assigned : 1; // for linker script

  uint32_t Alignment;

  // These corresponds to the fields in Elf_Shdr.
  uint64_t Flags;
  uint64_t Entsize;
  uint32_t Type;
  uint32_t Link;
  uint32_t Info;

  OutputSection *getOutputSection();
  const OutputSection *getOutputSection() const {
    return const_cast<SectionBase *>(this)->getOutputSection();
  }

  // Translate an offset in the input section to an offset in the output
  // section.
  uint64_t getOffset(uint64_t Offset) const;

  uint64_t getOffset(const DefinedRegular &Sym) const;

protected:
  SectionBase(Kind SectionKind, StringRef Name, uint64_t Flags,
              uint64_t Entsize, uint64_t Alignment, uint32_t Type,
              uint32_t Info, uint32_t Link)
      : Name(Name), SectionKind(SectionKind), Alignment(Alignment),
        Flags(Flags), Entsize(Entsize), Type(Type), Link(Link), Info(Info) {
    Live = false;
    Assigned = false;
  }
};

// This corresponds to a section of an input file.
class InputSectionBase : public SectionBase {
public:
  static bool classof(const SectionBase *S);

  // The file this section is from.
  InputFile *File;

  ArrayRef<uint8_t> Data;
  uint64_t getOffsetInFile() const;

  static InputSectionBase Discarded;

  InputSectionBase()
      : SectionBase(Regular, "", /*Flags*/ 0, /*Entsize*/ 0, /*Alignment*/ 0,
                    /*Type*/ 0,
                    /*Info*/ 0, /*Link*/ 0),
        Repl(this) {
    Live = false;
    Assigned = false;
    NumRelocations = 0;
    AreRelocsRela = false;
  }

  template <class ELFT>
  InputSectionBase(ObjectFile<ELFT> *File, const typename ELFT::Shdr *Header,
                   StringRef Name, Kind SectionKind);

  InputSectionBase(InputFile *File, uint64_t Flags, uint32_t Type,
                   uint64_t Entsize, uint32_t Link, uint32_t Info,
                   uint32_t Alignment, ArrayRef<uint8_t> Data, StringRef Name,
                   Kind SectionKind);

  // Input sections are part of an output section. Special sections
  // like .eh_frame and merge sections are first combined into a
  // synthetic section that is then added to an output section. In all
  // cases this points one level up.
  SectionBase *Parent = nullptr;

  // Relocations that refer to this section.
  const void *FirstRelocation = nullptr;
  unsigned NumRelocations : 31;
  unsigned AreRelocsRela : 1;
  template <class ELFT> ArrayRef<typename ELFT::Rel> rels() const {
    assert(!AreRelocsRela);
    return llvm::makeArrayRef(
        static_cast<const typename ELFT::Rel *>(FirstRelocation),
        NumRelocations);
  }
  template <class ELFT> ArrayRef<typename ELFT::Rela> relas() const {
    assert(AreRelocsRela);
    return llvm::makeArrayRef(
        static_cast<const typename ELFT::Rela *>(FirstRelocation),
        NumRelocations);
  }

  // This pointer points to the "real" instance of this instance.
  // Usually Repl == this. However, if ICF merges two sections,
  // Repl pointer of one section points to another section. So,
  // if you need to get a pointer to this instance, do not use
  // this but instead this->Repl.
  InputSectionBase *Repl;

  // InputSections that are dependent on us (reverse dependency for GC)
  llvm::TinyPtrVector<InputSectionBase *> DependentSections;

  // Returns the size of this section (even if this is a common or BSS.)
  size_t getSize() const;

  template <class ELFT> ObjectFile<ELFT> *getFile() const;

  template <class ELFT> llvm::object::ELFFile<ELFT> getObj() const {
    return getFile<ELFT>()->getObj();
  }

  InputSection *getLinkOrderDep() const;

  void uncompress();

  // Returns a source location string. Used to construct an error message.
  template <class ELFT> std::string getLocation(uint64_t Offset);
  template <class ELFT> std::string getSrcMsg(uint64_t Offset);
  template <class ELFT> std::string getObjMsg(uint64_t Offset);

  template <class ELFT> void relocate(uint8_t *Buf, uint8_t *BufEnd);
  void relocateAlloc(uint8_t *Buf, uint8_t *BufEnd);
  template <class ELFT> void relocateNonAlloc(uint8_t *Buf, uint8_t *BufEnd);

  std::vector<Relocation> Relocations;

  template <typename T> llvm::ArrayRef<T> getDataAs() const {
    size_t S = Data.size();
    assert(S % sizeof(T) == 0);
    return llvm::makeArrayRef<T>((const T *)Data.data(), S / sizeof(T));
  }
};

// SectionPiece represents a piece of splittable section contents.
// We allocate a lot of these and binary search on them. This means that they
// have to be as compact as possible, which is why we don't store the size (can
// be found by looking at the next one) and put the hash in a side table.
struct SectionPiece {
  SectionPiece(size_t Off, bool Live = false)
      : InputOff(Off), OutputOff(-1), Live(Live || !Config->GcSections) {}

  size_t InputOff;
  ssize_t OutputOff : 8 * sizeof(ssize_t) - 1;
  size_t Live : 1;
};
static_assert(sizeof(SectionPiece) == 2 * sizeof(size_t),
              "SectionPiece is too big");

// This corresponds to a SHF_MERGE section of an input file.
class MergeInputSection : public InputSectionBase {
public:
  template <class ELFT>
  MergeInputSection(ObjectFile<ELFT> *F, const typename ELFT::Shdr *Header,
                    StringRef Name);
  static bool classof(const SectionBase *S);
  void splitIntoPieces();

  // Mark the piece at a given offset live. Used by GC.
  void markLiveAt(uint64_t Offset) {
    assert(this->Flags & llvm::ELF::SHF_ALLOC);
    LiveOffsets.insert(Offset);
  }

  // Translate an offset in the input section to an offset
  // in the output section.
  uint64_t getOffset(uint64_t Offset) const;

  // Splittable sections are handled as a sequence of data
  // rather than a single large blob of data.
  std::vector<SectionPiece> Pieces;

  // Returns I'th piece's data. This function is very hot when
  // string merging is enabled, so we want to inline.
  LLVM_ATTRIBUTE_ALWAYS_INLINE
  llvm::CachedHashStringRef getData(size_t I) const {
    size_t Begin = Pieces[I].InputOff;
    size_t End;
    if (Pieces.size() - 1 == I)
      End = this->Data.size();
    else
      End = Pieces[I + 1].InputOff;

    StringRef S = {(const char *)(this->Data.data() + Begin), End - Begin};
    return {S, Hashes[I]};
  }

  // Returns the SectionPiece at a given input section offset.
  SectionPiece *getSectionPiece(uint64_t Offset);
  const SectionPiece *getSectionPiece(uint64_t Offset) const;

  SyntheticSection *getParent() const;

private:
  void splitStrings(ArrayRef<uint8_t> A, size_t Size);
  void splitNonStrings(ArrayRef<uint8_t> A, size_t Size);

  std::vector<uint32_t> Hashes;

  mutable llvm::DenseMap<uint64_t, uint64_t> OffsetMap;
  mutable llvm::once_flag InitOffsetMap;

  llvm::DenseSet<uint64_t> LiveOffsets;
};

struct EhSectionPiece : public SectionPiece {
  EhSectionPiece(size_t Off, InputSectionBase *ID, uint32_t Size,
                 unsigned FirstRelocation)
      : SectionPiece(Off, false), ID(ID), Size(Size),
        FirstRelocation(FirstRelocation) {}
  InputSectionBase *ID;
  uint32_t Size;
  uint32_t size() const { return Size; }

  ArrayRef<uint8_t> data() { return {ID->Data.data() + this->InputOff, Size}; }
  unsigned FirstRelocation;
};

// This corresponds to a .eh_frame section of an input file.
class EhInputSection : public InputSectionBase {
public:
  template <class ELFT>
  EhInputSection(ObjectFile<ELFT> *F, const typename ELFT::Shdr *Header,
                 StringRef Name);
  static bool classof(const SectionBase *S);
  template <class ELFT> void split();
  template <class ELFT, class RelTy> void split(ArrayRef<RelTy> Rels);

  // Splittable sections are handled as a sequence of data
  // rather than a single large blob of data.
  std::vector<EhSectionPiece> Pieces;

  SyntheticSection *getParent() const;
};

// This is a section that is added directly to an output section
// instead of needing special combination via a synthetic section. This
// includes all input sections with the exceptions of SHF_MERGE and
// .eh_frame. It also includes the synthetic sections themselves.
class InputSection : public InputSectionBase {
public:
  InputSection(uint64_t Flags, uint32_t Type, uint32_t Alignment,
               ArrayRef<uint8_t> Data, StringRef Name, Kind K = Regular);
  template <class ELFT>
  InputSection(ObjectFile<ELFT> *F, const typename ELFT::Shdr *Header,
               StringRef Name);

  // Write this section to a mmap'ed file, assuming Buf is pointing to
  // beginning of the output section.
  template <class ELFT> void writeTo(uint8_t *Buf);

  OutputSection *getParent() const;

  // The offset from beginning of the output sections this section was assigned
  // to. The writer sets a value.
  uint64_t OutSecOff = 0;

  static bool classof(const SectionBase *S);

  InputSectionBase *getRelocatedSection();

  template <class ELFT, class RelTy>
  void relocateNonAlloc(uint8_t *Buf, llvm::ArrayRef<RelTy> Rels);

  // Used by ICF.
  uint32_t Class[2] = {0, 0};

  // Called by ICF to merge two input sections.
  void replace(InputSection *Other);

private:
  template <class ELFT, class RelTy>
  void copyRelocations(uint8_t *Buf, llvm::ArrayRef<RelTy> Rels);

  template <class ELFT> void copyShtGroup(uint8_t *Buf);
};

// The list of all input sections.
extern std::vector<InputSectionBase *> InputSections;

} // namespace elf

std::string toString(const elf::InputSectionBase *);
} // namespace lld

#endif
