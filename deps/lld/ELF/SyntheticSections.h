//===- SyntheticSection.h ---------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Synthetic sections represent chunks of linker-created data. If you
// need to create a chunk of data that to be included in some section
// in the result, you probably want to create that as a synthetic section.
//
// Synthetic sections are designed as input sections as opposed to
// output sections because we want to allow them to be manipulated
// using linker scripts just like other input sections from regular
// files.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_ELF_SYNTHETIC_SECTIONS_H
#define LLD_ELF_SYNTHETIC_SECTIONS_H

#include "DWARF.h"
#include "EhFrame.h"
#include "InputSection.h"
#include "llvm/ADT/MapVector.h"
#include "llvm/MC/StringTableBuilder.h"
#include "llvm/Support/Endian.h"
#include <functional>

namespace lld {
namespace elf {
class Defined;
struct PhdrEntry;
class SymbolTableBaseSection;
class VersionNeedBaseSection;

class SyntheticSection : public InputSection {
public:
  SyntheticSection(uint64_t flags, uint32_t type, uint32_t alignment,
                   StringRef name)
      : InputSection(nullptr, flags, type, alignment, {}, name,
                     InputSectionBase::Synthetic) {
    markLive();
  }

  virtual ~SyntheticSection() = default;
  virtual void writeTo(uint8_t *buf) = 0;
  virtual size_t getSize() const = 0;
  virtual void finalizeContents() {}
  // If the section has the SHF_ALLOC flag and the size may be changed if
  // thunks are added, update the section size.
  virtual bool updateAllocSize() { return false; }
  virtual bool isNeeded() const { return true; }

  static bool classof(const SectionBase *d) {
    return d->kind() == InputSectionBase::Synthetic;
  }
};

struct CieRecord {
  EhSectionPiece *cie = nullptr;
  std::vector<EhSectionPiece *> fdes;
};

// Section for .eh_frame.
class EhFrameSection final : public SyntheticSection {
public:
  EhFrameSection();
  void writeTo(uint8_t *buf) override;
  void finalizeContents() override;
  bool isNeeded() const override { return !sections.empty(); }
  size_t getSize() const override { return size; }

  static bool classof(const SectionBase *d) {
    return SyntheticSection::classof(d) && d->name == ".eh_frame";
  }

  template <class ELFT> void addSection(InputSectionBase *s);

  std::vector<EhInputSection *> sections;
  size_t numFdes = 0;

  struct FdeData {
    uint32_t pcRel;
    uint32_t fdeVARel;
  };

  std::vector<FdeData> getFdeData() const;
  ArrayRef<CieRecord *> getCieRecords() const { return cieRecords; }

private:
  // This is used only when parsing EhInputSection. We keep it here to avoid
  // allocating one for each EhInputSection.
  llvm::DenseMap<size_t, CieRecord *> offsetToCie;

  uint64_t size = 0;

  template <class ELFT, class RelTy>
  void addSectionAux(EhInputSection *s, llvm::ArrayRef<RelTy> rels);

  template <class ELFT, class RelTy>
  CieRecord *addCie(EhSectionPiece &piece, ArrayRef<RelTy> rels);

  template <class ELFT, class RelTy>
  bool isFdeLive(EhSectionPiece &piece, ArrayRef<RelTy> rels);

  uint64_t getFdePc(uint8_t *buf, size_t off, uint8_t enc) const;

  std::vector<CieRecord *> cieRecords;

  // CIE records are uniquified by their contents and personality functions.
  llvm::DenseMap<std::pair<ArrayRef<uint8_t>, Symbol *>, CieRecord *> cieMap;
};

class GotSection : public SyntheticSection {
public:
  GotSection();
  size_t getSize() const override { return size; }
  void finalizeContents() override;
  bool isNeeded() const override;
  void writeTo(uint8_t *buf) override;

  void addEntry(Symbol &sym);
  bool addDynTlsEntry(Symbol &sym);
  bool addTlsIndex();
  uint64_t getGlobalDynAddr(const Symbol &b) const;
  uint64_t getGlobalDynOffset(const Symbol &b) const;

  uint64_t getTlsIndexVA() { return this->getVA() + tlsIndexOff; }
  uint32_t getTlsIndexOff() const { return tlsIndexOff; }

  // Flag to force GOT to be in output if we have relocations
  // that relies on its address.
  bool hasGotOffRel = false;

protected:
  size_t numEntries = 0;
  uint32_t tlsIndexOff = -1;
  uint64_t size = 0;
};

// .note.GNU-stack section.
class GnuStackSection : public SyntheticSection {
public:
  GnuStackSection()
      : SyntheticSection(0, llvm::ELF::SHT_PROGBITS, 1, ".note.GNU-stack") {}
  void writeTo(uint8_t *buf) override {}
  size_t getSize() const override { return 0; }
};

class GnuPropertySection : public SyntheticSection {
public:
  GnuPropertySection();
  void writeTo(uint8_t *buf) override;
  size_t getSize() const override;
};

// .note.gnu.build-id section.
class BuildIdSection : public SyntheticSection {
  // First 16 bytes are a header.
  static const unsigned headerSize = 16;

public:
  const size_t hashSize;
  BuildIdSection();
  void writeTo(uint8_t *buf) override;
  size_t getSize() const override { return headerSize + hashSize; }
  void writeBuildId(llvm::ArrayRef<uint8_t> buf);

private:
  uint8_t *hashBuf;
};

// BssSection is used to reserve space for copy relocations and common symbols.
// We create three instances of this class for .bss, .bss.rel.ro and "COMMON",
// that are used for writable symbols, read-only symbols and common symbols,
// respectively.
class BssSection final : public SyntheticSection {
public:
  BssSection(StringRef name, uint64_t size, uint32_t alignment);
  void writeTo(uint8_t *) override {
    llvm_unreachable("unexpected writeTo() call for SHT_NOBITS section");
  }
  bool isNeeded() const override { return size != 0; }
  size_t getSize() const override { return size; }

  static bool classof(const SectionBase *s) { return s->bss; }
  uint64_t size;
};

class MipsGotSection final : public SyntheticSection {
public:
  MipsGotSection();
  void writeTo(uint8_t *buf) override;
  size_t getSize() const override { return size; }
  bool updateAllocSize() override;
  void finalizeContents() override;
  bool isNeeded() const override;

  // Join separate GOTs built for each input file to generate
  // primary and optional multiple secondary GOTs.
  void build();

  void addEntry(InputFile &file, Symbol &sym, int64_t addend, RelExpr expr);
  void addDynTlsEntry(InputFile &file, Symbol &sym);
  void addTlsIndex(InputFile &file);

  uint64_t getPageEntryOffset(const InputFile *f, const Symbol &s,
                              int64_t addend) const;
  uint64_t getSymEntryOffset(const InputFile *f, const Symbol &s,
                             int64_t addend) const;
  uint64_t getGlobalDynOffset(const InputFile *f, const Symbol &s) const;
  uint64_t getTlsIndexOffset(const InputFile *f) const;

  // Returns the symbol which corresponds to the first entry of the global part
  // of GOT on MIPS platform. It is required to fill up MIPS-specific dynamic
  // table properties.
  // Returns nullptr if the global part is empty.
  const Symbol *getFirstGlobalEntry() const;

  // Returns the number of entries in the local part of GOT including
  // the number of reserved entries.
  unsigned getLocalEntriesNum() const;

  // Return _gp value for primary GOT (nullptr) or particular input file.
  uint64_t getGp(const InputFile *f = nullptr) const;

private:
  // MIPS GOT consists of three parts: local, global and tls. Each part
  // contains different types of entries. Here is a layout of GOT:
  // - Header entries                |
  // - Page entries                  |   Local part
  // - Local entries (16-bit access) |
  // - Local entries (32-bit access) |
  // - Normal global entries         ||  Global part
  // - Reloc-only global entries     ||
  // - TLS entries                   ||| TLS part
  //
  // Header:
  //   Two entries hold predefined value 0x0 and 0x80000000.
  // Page entries:
  //   These entries created by R_MIPS_GOT_PAGE relocation and R_MIPS_GOT16
  //   relocation against local symbols. They are initialized by higher 16-bit
  //   of the corresponding symbol's value. So each 64kb of address space
  //   requires a single GOT entry.
  // Local entries (16-bit access):
  //   These entries created by GOT relocations against global non-preemptible
  //   symbols so dynamic linker is not necessary to resolve the symbol's
  //   values. "16-bit access" means that corresponding relocations address
  //   GOT using 16-bit index. Each unique Symbol-Addend pair has its own
  //   GOT entry.
  // Local entries (32-bit access):
  //   These entries are the same as above but created by relocations which
  //   address GOT using 32-bit index (R_MIPS_GOT_HI16/LO16 etc).
  // Normal global entries:
  //   These entries created by GOT relocations against preemptible global
  //   symbols. They need to be initialized by dynamic linker and they ordered
  //   exactly as the corresponding entries in the dynamic symbols table.
  // Reloc-only global entries:
  //   These entries created for symbols that are referenced by dynamic
  //   relocations R_MIPS_REL32. These entries are not accessed with gp-relative
  //   addressing, but MIPS ABI requires that these entries be present in GOT.
  // TLS entries:
  //   Entries created by TLS relocations.
  //
  // If the sum of local, global and tls entries is less than 64K only single
  // got is enough. Otherwise, multi-got is created. Series of primary and
  // multiple secondary GOTs have the following layout:
  // - Primary GOT
  //     Header
  //     Local entries
  //     Global entries
  //     Relocation only entries
  //     TLS entries
  //
  // - Secondary GOT
  //     Local entries
  //     Global entries
  //     TLS entries
  // ...
  //
  // All GOT entries required by relocations from a single input file entirely
  // belong to either primary or one of secondary GOTs. To reference GOT entries
  // each GOT has its own _gp value points to the "middle" of the GOT.
  // In the code this value loaded to the register which is used for GOT access.
  //
  // MIPS 32 function's prologue:
  //   lui     v0,0x0
  //   0: R_MIPS_HI16  _gp_disp
  //   addiu   v0,v0,0
  //   4: R_MIPS_LO16  _gp_disp
  //
  // MIPS 64:
  //   lui     at,0x0
  //   14: R_MIPS_GPREL16  main
  //
  // Dynamic linker does not know anything about secondary GOTs and cannot
  // use a regular MIPS mechanism for GOT entries initialization. So we have
  // to use an approach accepted by other architectures and create dynamic
  // relocations R_MIPS_REL32 to initialize global entries (and local in case
  // of PIC code) in secondary GOTs. But ironically MIPS dynamic linker
  // requires GOT entries and correspondingly ordered dynamic symbol table
  // entries to deal with dynamic relocations. To handle this problem
  // relocation-only section in the primary GOT contains entries for all
  // symbols referenced in global parts of secondary GOTs. Although the sum
  // of local and normal global entries of the primary got should be less
  // than 64K, the size of the primary got (including relocation-only entries
  // can be greater than 64K, because parts of the primary got that overflow
  // the 64K limit are used only by the dynamic linker at dynamic link-time
  // and not by 16-bit gp-relative addressing at run-time.
  //
  // For complete multi-GOT description see the following link
  // https://dmz-portal.mips.com/wiki/MIPS_Multi_GOT

  // Number of "Header" entries.
  static const unsigned headerEntriesNum = 2;

  uint64_t size = 0;

  // Symbol and addend.
  using GotEntry = std::pair<Symbol *, int64_t>;

  struct FileGot {
    InputFile *file = nullptr;
    size_t startIndex = 0;

    struct PageBlock {
      size_t firstIndex;
      size_t count;
      PageBlock() : firstIndex(0), count(0) {}
    };

    // Map output sections referenced by MIPS GOT relocations
    // to the description (index/count) "page" entries allocated
    // for this section.
    llvm::SmallMapVector<const OutputSection *, PageBlock, 16> pagesMap;
    // Maps from Symbol+Addend pair or just Symbol to the GOT entry index.
    llvm::MapVector<GotEntry, size_t> local16;
    llvm::MapVector<GotEntry, size_t> local32;
    llvm::MapVector<Symbol *, size_t> global;
    llvm::MapVector<Symbol *, size_t> relocs;
    llvm::MapVector<Symbol *, size_t> tls;
    // Set of symbols referenced by dynamic TLS relocations.
    llvm::MapVector<Symbol *, size_t> dynTlsSymbols;

    // Total number of all entries.
    size_t getEntriesNum() const;
    // Number of "page" entries.
    size_t getPageEntriesNum() const;
    // Number of entries require 16-bit index to access.
    size_t getIndexedEntriesNum() const;
  };

  // Container of GOT created for each input file.
  // After building a final series of GOTs this container
  // holds primary and secondary GOT's.
  std::vector<FileGot> gots;

  // Return (and create if necessary) `FileGot`.
  FileGot &getGot(InputFile &f);

  // Try to merge two GOTs. In case of success the `Dst` contains
  // result of merging and the function returns true. In case of
  // ovwerflow the `Dst` is unchanged and the function returns false.
  bool tryMergeGots(FileGot & dst, FileGot & src, bool isPrimary);
};

class GotPltSection final : public SyntheticSection {
public:
  GotPltSection();
  void addEntry(Symbol &sym);
  size_t getSize() const override;
  void writeTo(uint8_t *buf) override;
  bool isNeeded() const override;

  // Flag to force GotPlt to be in output if we have relocations
  // that relies on its address.
  bool hasGotPltOffRel = false;

private:
  std::vector<const Symbol *> entries;
};

// The IgotPltSection is a Got associated with the PltSection for GNU Ifunc
// Symbols that will be relocated by Target->IRelativeRel.
// On most Targets the IgotPltSection will immediately follow the GotPltSection
// on ARM the IgotPltSection will immediately follow the GotSection.
class IgotPltSection final : public SyntheticSection {
public:
  IgotPltSection();
  void addEntry(Symbol &sym);
  size_t getSize() const override;
  void writeTo(uint8_t *buf) override;
  bool isNeeded() const override { return !entries.empty(); }

private:
  std::vector<const Symbol *> entries;
};

class StringTableSection final : public SyntheticSection {
public:
  StringTableSection(StringRef name, bool dynamic);
  unsigned addString(StringRef s, bool hashIt = true);
  void writeTo(uint8_t *buf) override;
  size_t getSize() const override { return size; }
  bool isDynamic() const { return dynamic; }

private:
  const bool dynamic;

  uint64_t size = 0;

  llvm::DenseMap<StringRef, unsigned> stringMap;
  std::vector<StringRef> strings;
};

class DynamicReloc {
public:
  DynamicReloc(RelType type, const InputSectionBase *inputSec,
               uint64_t offsetInSec, bool useSymVA, Symbol *sym, int64_t addend)
      : type(type), sym(sym), inputSec(inputSec), offsetInSec(offsetInSec),
        useSymVA(useSymVA), addend(addend), outputSec(nullptr) {}
  // This constructor records dynamic relocation settings used by MIPS
  // multi-GOT implementation. It's to relocate addresses of 64kb pages
  // lie inside the output section.
  DynamicReloc(RelType type, const InputSectionBase *inputSec,
               uint64_t offsetInSec, const OutputSection *outputSec,
               int64_t addend)
      : type(type), sym(nullptr), inputSec(inputSec), offsetInSec(offsetInSec),
        useSymVA(false), addend(addend), outputSec(outputSec) {}

  uint64_t getOffset() const;
  uint32_t getSymIndex(SymbolTableBaseSection *symTab) const;

  // Computes the addend of the dynamic relocation. Note that this is not the
  // same as the addend member variable as it also includes the symbol address
  // if useSymVA is true.
  int64_t computeAddend() const;

  RelType type;

  Symbol *sym;
  const InputSectionBase *inputSec = nullptr;
  uint64_t offsetInSec;
  // If this member is true, the dynamic relocation will not be against the
  // symbol but will instead be a relative relocation that simply adds the
  // load address. This means we need to write the symbol virtual address
  // plus the original addend as the final relocation addend.
  bool useSymVA;
  int64_t addend;
  const OutputSection *outputSec;
};

template <class ELFT> class DynamicSection final : public SyntheticSection {
  using Elf_Dyn = typename ELFT::Dyn;
  using Elf_Rel = typename ELFT::Rel;
  using Elf_Rela = typename ELFT::Rela;
  using Elf_Relr = typename ELFT::Relr;
  using Elf_Shdr = typename ELFT::Shdr;
  using Elf_Sym = typename ELFT::Sym;

  // finalizeContents() fills this vector with the section contents.
  std::vector<std::pair<int32_t, std::function<uint64_t()>>> entries;

public:
  DynamicSection();
  void finalizeContents() override;
  void writeTo(uint8_t *buf) override;
  size_t getSize() const override { return size; }

private:
  void add(int32_t tag, std::function<uint64_t()> fn);
  void addInt(int32_t tag, uint64_t val);
  void addInSec(int32_t tag, InputSection *sec);
  void addInSecRelative(int32_t tag, InputSection *sec);
  void addOutSec(int32_t tag, OutputSection *sec);
  void addSize(int32_t tag, OutputSection *sec);
  void addSym(int32_t tag, Symbol *sym);

  uint64_t size = 0;
};

class RelocationBaseSection : public SyntheticSection {
public:
  RelocationBaseSection(StringRef name, uint32_t type, int32_t dynamicTag,
                        int32_t sizeDynamicTag);
  void addReloc(RelType dynType, InputSectionBase *isec, uint64_t offsetInSec,
                Symbol *sym);
  // Add a dynamic relocation that might need an addend. This takes care of
  // writing the addend to the output section if needed.
  void addReloc(RelType dynType, InputSectionBase *inputSec,
                uint64_t offsetInSec, Symbol *sym, int64_t addend, RelExpr expr,
                RelType type);
  void addReloc(const DynamicReloc &reloc);
  bool isNeeded() const override { return !relocs.empty(); }
  size_t getSize() const override { return relocs.size() * this->entsize; }
  size_t getRelativeRelocCount() const { return numRelativeRelocs; }
  void finalizeContents() override;
  int32_t dynamicTag, sizeDynamicTag;
  std::vector<DynamicReloc> relocs;

protected:
  size_t numRelativeRelocs = 0;
};

template <class ELFT>
class RelocationSection final : public RelocationBaseSection {
  using Elf_Rel = typename ELFT::Rel;
  using Elf_Rela = typename ELFT::Rela;

public:
  RelocationSection(StringRef name, bool sort);
  void writeTo(uint8_t *buf) override;

private:
  bool sort;
};

template <class ELFT>
class AndroidPackedRelocationSection final : public RelocationBaseSection {
  using Elf_Rel = typename ELFT::Rel;
  using Elf_Rela = typename ELFT::Rela;

public:
  AndroidPackedRelocationSection(StringRef name);

  bool updateAllocSize() override;
  size_t getSize() const override { return relocData.size(); }
  void writeTo(uint8_t *buf) override {
    memcpy(buf, relocData.data(), relocData.size());
  }

private:
  SmallVector<char, 0> relocData;
};

struct RelativeReloc {
  uint64_t getOffset() const { return inputSec->getVA(offsetInSec); }

  const InputSectionBase *inputSec;
  uint64_t offsetInSec;
};

class RelrBaseSection : public SyntheticSection {
public:
  RelrBaseSection();
  bool isNeeded() const override { return !relocs.empty(); }
  std::vector<RelativeReloc> relocs;
};

// RelrSection is used to encode offsets for relative relocations.
// Proposal for adding SHT_RELR sections to generic-abi is here:
//   https://groups.google.com/forum/#!topic/generic-abi/bX460iggiKg
// For more details, see the comment in RelrSection::updateAllocSize().
template <class ELFT> class RelrSection final : public RelrBaseSection {
  using Elf_Relr = typename ELFT::Relr;

public:
  RelrSection();

  bool updateAllocSize() override;
  size_t getSize() const override { return relrRelocs.size() * this->entsize; }
  void writeTo(uint8_t *buf) override {
    memcpy(buf, relrRelocs.data(), getSize());
  }

private:
  std::vector<Elf_Relr> relrRelocs;
};

struct SymbolTableEntry {
  Symbol *sym;
  size_t strTabOffset;
};

class SymbolTableBaseSection : public SyntheticSection {
public:
  SymbolTableBaseSection(StringTableSection &strTabSec);
  void finalizeContents() override;
  size_t getSize() const override { return getNumSymbols() * entsize; }
  void addSymbol(Symbol *sym);
  unsigned getNumSymbols() const { return symbols.size() + 1; }
  size_t getSymbolIndex(Symbol *sym);
  ArrayRef<SymbolTableEntry> getSymbols() const { return symbols; }

protected:
  void sortSymTabSymbols();

  // A vector of symbols and their string table offsets.
  std::vector<SymbolTableEntry> symbols;

  StringTableSection &strTabSec;

  llvm::once_flag onceFlag;
  llvm::DenseMap<Symbol *, size_t> symbolIndexMap;
  llvm::DenseMap<OutputSection *, size_t> sectionIndexMap;
};

template <class ELFT>
class SymbolTableSection final : public SymbolTableBaseSection {
  using Elf_Sym = typename ELFT::Sym;

public:
  SymbolTableSection(StringTableSection &strTabSec);
  void writeTo(uint8_t *buf) override;
};

class SymtabShndxSection final : public SyntheticSection {
public:
  SymtabShndxSection();

  void writeTo(uint8_t *buf) override;
  size_t getSize() const override;
  bool isNeeded() const override;
  void finalizeContents() override;
};

// Outputs GNU Hash section. For detailed explanation see:
// https://blogs.oracle.com/ali/entry/gnu_hash_elf_sections
class GnuHashTableSection final : public SyntheticSection {
public:
  GnuHashTableSection();
  void finalizeContents() override;
  void writeTo(uint8_t *buf) override;
  size_t getSize() const override { return size; }

  // Adds symbols to the hash table.
  // Sorts the input to satisfy GNU hash section requirements.
  void addSymbols(std::vector<SymbolTableEntry> &symbols);

private:
  // See the comment in writeBloomFilter.
  enum { Shift2 = 26 };

  void writeBloomFilter(uint8_t *buf);
  void writeHashTable(uint8_t *buf);

  struct Entry {
    Symbol *sym;
    size_t strTabOffset;
    uint32_t hash;
    uint32_t bucketIdx;
  };

  std::vector<Entry> symbols;
  size_t maskWords;
  size_t nBuckets = 0;
  size_t size = 0;
};

class HashTableSection final : public SyntheticSection {
public:
  HashTableSection();
  void finalizeContents() override;
  void writeTo(uint8_t *buf) override;
  size_t getSize() const override { return size; }

private:
  size_t size = 0;
};

// The PltSection is used for both the Plt and Iplt. The former usually has a
// header as its first entry that is used at run-time to resolve lazy binding.
// The latter is used for GNU Ifunc symbols, that will be subject to a
// Target->IRelativeRel.
class PltSection : public SyntheticSection {
public:
  PltSection(bool isIplt);
  void writeTo(uint8_t *buf) override;
  size_t getSize() const override;
  bool isNeeded() const override { return !entries.empty(); }
  void addSymbols();
  template <class ELFT> void addEntry(Symbol &sym);

  size_t headerSize;

private:
  std::vector<const Symbol *> entries;
  bool isIplt;
};

class GdbIndexSection final : public SyntheticSection {
public:
  struct AddressEntry {
    InputSection *section;
    uint64_t lowAddress;
    uint64_t highAddress;
    uint32_t cuIndex;
  };

  struct CuEntry {
    uint64_t cuOffset;
    uint64_t cuLength;
  };

  struct NameAttrEntry {
    llvm::CachedHashStringRef name;
    uint32_t cuIndexAndAttrs;
  };

  struct GdbChunk {
    InputSection *sec;
    std::vector<AddressEntry> addressAreas;
    std::vector<CuEntry> compilationUnits;
  };

  struct GdbSymbol {
    llvm::CachedHashStringRef name;
    std::vector<uint32_t> cuVector;
    uint32_t nameOff;
    uint32_t cuVectorOff;
  };

  GdbIndexSection();
  template <typename ELFT> static GdbIndexSection *create();
  void writeTo(uint8_t *buf) override;
  size_t getSize() const override { return size; }
  bool isNeeded() const override;

private:
  struct GdbIndexHeader {
    llvm::support::ulittle32_t version;
    llvm::support::ulittle32_t cuListOff;
    llvm::support::ulittle32_t cuTypesOff;
    llvm::support::ulittle32_t addressAreaOff;
    llvm::support::ulittle32_t symtabOff;
    llvm::support::ulittle32_t constantPoolOff;
  };

  void initOutputSize();
  size_t computeSymtabSize() const;

  // Each chunk contains information gathered from debug sections of a
  // single object file.
  std::vector<GdbChunk> chunks;

  // A symbol table for this .gdb_index section.
  std::vector<GdbSymbol> symbols;

  size_t size;
};

// --eh-frame-hdr option tells linker to construct a header for all the
// .eh_frame sections. This header is placed to a section named .eh_frame_hdr
// and also to a PT_GNU_EH_FRAME segment.
// At runtime the unwinder then can find all the PT_GNU_EH_FRAME segments by
// calling dl_iterate_phdr.
// This section contains a lookup table for quick binary search of FDEs.
// Detailed info about internals can be found in Ian Lance Taylor's blog:
// http://www.airs.com/blog/archives/460 (".eh_frame")
// http://www.airs.com/blog/archives/462 (".eh_frame_hdr")
class EhFrameHeader final : public SyntheticSection {
public:
  EhFrameHeader();
  void write();
  void writeTo(uint8_t *buf) override;
  size_t getSize() const override;
  bool isNeeded() const override;
};

// For more information about .gnu.version and .gnu.version_r see:
// https://www.akkadia.org/drepper/symbol-versioning

// The .gnu.version_d section which has a section type of SHT_GNU_verdef shall
// contain symbol version definitions. The number of entries in this section
// shall be contained in the DT_VERDEFNUM entry of the .dynamic section.
// The section shall contain an array of Elf_Verdef structures, optionally
// followed by an array of Elf_Verdaux structures.
class VersionDefinitionSection final : public SyntheticSection {
public:
  VersionDefinitionSection();
  void finalizeContents() override;
  size_t getSize() const override;
  void writeTo(uint8_t *buf) override;

private:
  enum { EntrySize = 28 };
  void writeOne(uint8_t *buf, uint32_t index, StringRef name, size_t nameOff);
  StringRef getFileDefName();

  unsigned fileDefNameOff;
  std::vector<unsigned> verDefNameOffs;
};

// The .gnu.version section specifies the required version of each symbol in the
// dynamic symbol table. It contains one Elf_Versym for each dynamic symbol
// table entry. An Elf_Versym is just a 16-bit integer that refers to a version
// identifier defined in the either .gnu.version_r or .gnu.version_d section.
// The values 0 and 1 are reserved. All other values are used for versions in
// the own object or in any of the dependencies.
class VersionTableSection final : public SyntheticSection {
public:
  VersionTableSection();
  void finalizeContents() override;
  size_t getSize() const override;
  void writeTo(uint8_t *buf) override;
  bool isNeeded() const override;
};

// The .gnu.version_r section defines the version identifiers used by
// .gnu.version. It contains a linked list of Elf_Verneed data structures. Each
// Elf_Verneed specifies the version requirements for a single DSO, and contains
// a reference to a linked list of Elf_Vernaux data structures which define the
// mapping from version identifiers to version names.
template <class ELFT>
class VersionNeedSection final : public SyntheticSection {
  using Elf_Verneed = typename ELFT::Verneed;
  using Elf_Vernaux = typename ELFT::Vernaux;

  struct Vernaux {
    uint64_t hash;
    uint32_t verneedIndex;
    uint64_t nameStrTab;
  };

  struct Verneed {
    uint64_t nameStrTab;
    std::vector<Vernaux> vernauxs;
  };

  std::vector<Verneed> verneeds;

public:
  VersionNeedSection();
  void finalizeContents() override;
  void writeTo(uint8_t *buf) override;
  size_t getSize() const override;
  bool isNeeded() const override;
};

// MergeSyntheticSection is a class that allows us to put mergeable sections
// with different attributes in a single output sections. To do that
// we put them into MergeSyntheticSection synthetic input sections which are
// attached to regular output sections.
class MergeSyntheticSection : public SyntheticSection {
public:
  void addSection(MergeInputSection *ms);
  std::vector<MergeInputSection *> sections;

protected:
  MergeSyntheticSection(StringRef name, uint32_t type, uint64_t flags,
                        uint32_t alignment)
      : SyntheticSection(flags, type, alignment, name) {}
};

class MergeTailSection final : public MergeSyntheticSection {
public:
  MergeTailSection(StringRef name, uint32_t type, uint64_t flags,
                   uint32_t alignment);

  size_t getSize() const override;
  void writeTo(uint8_t *buf) override;
  void finalizeContents() override;

private:
  llvm::StringTableBuilder builder;
};

class MergeNoTailSection final : public MergeSyntheticSection {
public:
  MergeNoTailSection(StringRef name, uint32_t type, uint64_t flags,
                     uint32_t alignment)
      : MergeSyntheticSection(name, type, flags, alignment) {}

  size_t getSize() const override { return size; }
  void writeTo(uint8_t *buf) override;
  void finalizeContents() override;

private:
  // We use the most significant bits of a hash as a shard ID.
  // The reason why we don't want to use the least significant bits is
  // because DenseMap also uses lower bits to determine a bucket ID.
  // If we use lower bits, it significantly increases the probability of
  // hash collisons.
  size_t getShardId(uint32_t hash) {
    assert((hash >> 31) == 0);
    return hash >> (31 - llvm::countTrailingZeros(numShards));
  }

  // Section size
  size_t size;

  // String table contents
  constexpr static size_t numShards = 32;
  std::vector<llvm::StringTableBuilder> shards;
  size_t shardOffsets[numShards];
};

// .MIPS.abiflags section.
template <class ELFT>
class MipsAbiFlagsSection final : public SyntheticSection {
  using Elf_Mips_ABIFlags = llvm::object::Elf_Mips_ABIFlags<ELFT>;

public:
  static MipsAbiFlagsSection *create();

  MipsAbiFlagsSection(Elf_Mips_ABIFlags flags);
  size_t getSize() const override { return sizeof(Elf_Mips_ABIFlags); }
  void writeTo(uint8_t *buf) override;

private:
  Elf_Mips_ABIFlags flags;
};

// .MIPS.options section.
template <class ELFT> class MipsOptionsSection final : public SyntheticSection {
  using Elf_Mips_Options = llvm::object::Elf_Mips_Options<ELFT>;
  using Elf_Mips_RegInfo = llvm::object::Elf_Mips_RegInfo<ELFT>;

public:
  static MipsOptionsSection *create();

  MipsOptionsSection(Elf_Mips_RegInfo reginfo);
  void writeTo(uint8_t *buf) override;

  size_t getSize() const override {
    return sizeof(Elf_Mips_Options) + sizeof(Elf_Mips_RegInfo);
  }

private:
  Elf_Mips_RegInfo reginfo;
};

// MIPS .reginfo section.
template <class ELFT> class MipsReginfoSection final : public SyntheticSection {
  using Elf_Mips_RegInfo = llvm::object::Elf_Mips_RegInfo<ELFT>;

public:
  static MipsReginfoSection *create();

  MipsReginfoSection(Elf_Mips_RegInfo reginfo);
  size_t getSize() const override { return sizeof(Elf_Mips_RegInfo); }
  void writeTo(uint8_t *buf) override;

private:
  Elf_Mips_RegInfo reginfo;
};

// This is a MIPS specific section to hold a space within the data segment
// of executable file which is pointed to by the DT_MIPS_RLD_MAP entry.
// See "Dynamic section" in Chapter 5 in the following document:
// ftp://www.linux-mips.org/pub/linux/mips/doc/ABI/mipsabi.pdf
class MipsRldMapSection : public SyntheticSection {
public:
  MipsRldMapSection();
  size_t getSize() const override { return config->wordsize; }
  void writeTo(uint8_t *buf) override {}
};

// Representation of the combined .ARM.Exidx input sections. We process these
// as a SyntheticSection like .eh_frame as we need to merge duplicate entries
// and add terminating sentinel entries.
//
// The .ARM.exidx input sections after SHF_LINK_ORDER processing is done form
// a table that the unwinder can derive (Addresses are encoded as offsets from
// table):
// | Address of function | Unwind instructions for function |
// where the unwind instructions are either a small number of unwind or the
// special EXIDX_CANTUNWIND entry representing no unwinding information.
// When an exception is thrown from an address A, the unwinder searches the
// table for the closest table entry with Address of function <= A. This means
// that for two consecutive table entries:
// | A1 | U1 |
// | A2 | U2 |
// The range of addresses described by U1 is [A1, A2)
//
// There are two cases where we need a linker generated table entry to fixup
// the address ranges in the table
// Case 1:
// - A sentinel entry added with an address higher than all
// executable sections. This was needed to work around libunwind bug pr31091.
// - After address assignment we need to find the highest addressed executable
// section and use the limit of that section so that the unwinder never
// matches it.
// Case 2:
// - InputSections without a .ARM.exidx section (usually from Assembly)
// need a table entry so that they terminate the range of the previously
// function. This is pr40277.
//
// Instead of storing pointers to the .ARM.exidx InputSections from
// InputObjects, we store pointers to the executable sections that need
// .ARM.exidx sections. We can then use the dependentSections of these to
// either find the .ARM.exidx section or know that we need to generate one.
class ARMExidxSyntheticSection : public SyntheticSection {
public:
  ARMExidxSyntheticSection();

  // Add an input section to the ARMExidxSyntheticSection. Returns whether the
  // section needs to be removed from the main input section list.
  bool addSection(InputSection *isec);

  size_t getSize() const override { return size; }
  void writeTo(uint8_t *buf) override;
  bool isNeeded() const override { return !empty; }
  // Sort and remove duplicate entries.
  void finalizeContents() override;
  InputSection *getLinkOrderDep() const;

  static bool classof(const SectionBase *d);

  // Links to the ARMExidxSections so we can transfer the relocations once the
  // layout is known.
  std::vector<InputSection *> exidxSections;

private:
  size_t size;

  // Empty if ExecutableSections contains no dependent .ARM.exidx sections.
  bool empty = true;

  // Instead of storing pointers to the .ARM.exidx InputSections from
  // InputObjects, we store pointers to the executable sections that need
  // .ARM.exidx sections. We can then use the dependentSections of these to
  // either find the .ARM.exidx section or know that we need to generate one.
  std::vector<InputSection *> executableSections;

  // The executable InputSection with the highest address to use for the
  // sentinel. We store separately from ExecutableSections as merging of
  // duplicate entries may mean this InputSection is removed from
  // ExecutableSections.
  InputSection *sentinel = nullptr;
};

// A container for one or more linker generated thunks. Instances of these
// thunks including ARM interworking and Mips LA25 PI to non-PI thunks.
class ThunkSection : public SyntheticSection {
public:
  // ThunkSection in OS, with desired outSecOff of Off
  ThunkSection(OutputSection *os, uint64_t off);

  // Add a newly created Thunk to this container:
  // Thunk is given offset from start of this InputSection
  // Thunk defines a symbol in this InputSection that can be used as target
  // of a relocation
  void addThunk(Thunk *t);
  size_t getSize() const override { return size; }
  void writeTo(uint8_t *buf) override;
  InputSection *getTargetInputSection() const;
  bool assignOffsets();

private:
  std::vector<Thunk *> thunks;
  size_t size = 0;
};

// Used to compute outSecOff of .got2 in each object file. This is needed to
// synthesize PLT entries for PPC32 Secure PLT ABI.
class PPC32Got2Section final : public SyntheticSection {
public:
  PPC32Got2Section();
  size_t getSize() const override { return 0; }
  bool isNeeded() const override;
  void finalizeContents() override;
  void writeTo(uint8_t *buf) override {}
};

// This section is used to store the addresses of functions that are called
// in range-extending thunks on PowerPC64. When producing position dependant
// code the addresses are link-time constants and the table is written out to
// the binary. When producing position-dependant code the table is allocated and
// filled in by the dynamic linker.
class PPC64LongBranchTargetSection final : public SyntheticSection {
public:
  PPC64LongBranchTargetSection();
  void addEntry(Symbol &sym);
  size_t getSize() const override;
  void writeTo(uint8_t *buf) override;
  bool isNeeded() const override;
  void finalizeContents() override { finalized = true; }

private:
  std::vector<const Symbol *> entries;
  bool finalized = false;
};

template <typename ELFT>
class PartitionElfHeaderSection : public SyntheticSection {
public:
  PartitionElfHeaderSection();
  size_t getSize() const override;
  void writeTo(uint8_t *buf) override;
};

template <typename ELFT>
class PartitionProgramHeadersSection : public SyntheticSection {
public:
  PartitionProgramHeadersSection();
  size_t getSize() const override;
  void writeTo(uint8_t *buf) override;
};

class PartitionIndexSection : public SyntheticSection {
public:
  PartitionIndexSection();
  size_t getSize() const override;
  void finalizeContents() override;
  void writeTo(uint8_t *buf) override;
};

// Create a dummy .sdata for __global_pointer$ if .sdata does not exist.
class RISCVSdataSection final : public SyntheticSection {
public:
  RISCVSdataSection();
  size_t getSize() const override { return 0; }
  bool isNeeded() const override;
  void writeTo(uint8_t *buf) override {}
};

InputSection *createInterpSection();
MergeInputSection *createCommentSection();
template <class ELFT> void splitSections();
void mergeSections();

template <typename ELFT> void writeEhdr(uint8_t *buf, Partition &part);
template <typename ELFT> void writePhdrs(uint8_t *buf, Partition &part);

Defined *addSyntheticLocal(StringRef name, uint8_t type, uint64_t value,
                           uint64_t size, InputSectionBase &section);

void addVerneed(Symbol *ss);

// Linker generated per-partition sections.
struct Partition {
  StringRef name;
  uint64_t nameStrTab;

  SyntheticSection *elfHeader;
  SyntheticSection *programHeaders;
  std::vector<PhdrEntry *> phdrs;

  ARMExidxSyntheticSection *armExidx;
  BuildIdSection *buildId;
  SyntheticSection *dynamic;
  StringTableSection *dynStrTab;
  SymbolTableBaseSection *dynSymTab;
  EhFrameHeader *ehFrameHdr;
  EhFrameSection *ehFrame;
  GnuHashTableSection *gnuHashTab;
  HashTableSection *hashTab;
  RelocationBaseSection *relaDyn;
  RelrBaseSection *relrDyn;
  VersionDefinitionSection *verDef;
  SyntheticSection *verNeed;
  VersionTableSection *verSym;

  unsigned getNumber() const { return this - &partitions[0] + 1; }
};

extern Partition *mainPart;

inline Partition &SectionBase::getPartition() const {
  assert(isLive());
  return partitions[partition - 1];
}

// Linker generated sections which can be used as inputs and are not specific to
// a partition.
struct InStruct {
  InputSection *armAttributes;
  BssSection *bss;
  BssSection *bssRelRo;
  GotSection *got;
  GotPltSection *gotPlt;
  IgotPltSection *igotPlt;
  PPC64LongBranchTargetSection *ppc64LongBranchTarget;
  MipsGotSection *mipsGot;
  MipsRldMapSection *mipsRldMap;
  SyntheticSection *partEnd;
  SyntheticSection *partIndex;
  PltSection *plt;
  PltSection *iplt;
  PPC32Got2Section *ppc32Got2;
  RISCVSdataSection *riscvSdata;
  RelocationBaseSection *relaPlt;
  RelocationBaseSection *relaIplt;
  StringTableSection *shStrTab;
  StringTableSection *strTab;
  SymbolTableBaseSection *symTab;
  SymtabShndxSection *symTabShndx;
};

extern InStruct in;

} // namespace elf
} // namespace lld

#endif
