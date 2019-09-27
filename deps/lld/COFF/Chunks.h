//===- Chunks.h -------------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_COFF_CHUNKS_H
#define LLD_COFF_CHUNKS_H

#include "Config.h"
#include "InputFiles.h"
#include "lld/Common/LLVM.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/PointerIntPair.h"
#include "llvm/ADT/iterator.h"
#include "llvm/ADT/iterator_range.h"
#include "llvm/MC/StringTableBuilder.h"
#include "llvm/Object/COFF.h"
#include <utility>
#include <vector>

namespace lld {
namespace coff {

using llvm::COFF::ImportDirectoryTableEntry;
using llvm::object::COFFSymbolRef;
using llvm::object::SectionRef;
using llvm::object::coff_relocation;
using llvm::object::coff_section;

class Baserel;
class Defined;
class DefinedImportData;
class DefinedRegular;
class ObjFile;
class OutputSection;
class RuntimePseudoReloc;
class Symbol;

// Mask for permissions (discardable, writable, readable, executable, etc).
const uint32_t permMask = 0xFE000000;

// Mask for section types (code, data, bss).
const uint32_t typeMask = 0x000000E0;

// The log base 2 of the largest section alignment, which is log2(8192), or 13.
enum : unsigned { Log2MaxSectionAlignment = 13 };

// A Chunk represents a chunk of data that will occupy space in the
// output (if the resolver chose that). It may or may not be backed by
// a section of an input file. It could be linker-created data, or
// doesn't even have actual data (if common or bss).
class Chunk {
public:
  enum Kind : uint8_t { SectionKind, OtherKind, ImportThunkKind };
  Kind kind() const { return chunkKind; }

  // Returns the size of this chunk (even if this is a common or BSS.)
  size_t getSize() const;

  // Returns chunk alignment in power of two form. Value values are powers of
  // two from 1 to 8192.
  uint32_t getAlignment() const { return 1U << p2Align; }

  // Update the chunk section alignment measured in bytes. Internally alignment
  // is stored in log2.
  void setAlignment(uint32_t align) {
    // Treat zero byte alignment as 1 byte alignment.
    align = align ? align : 1;
    assert(llvm::isPowerOf2_32(align) && "alignment is not a power of 2");
    p2Align = llvm::Log2_32(align);
    assert(p2Align <= Log2MaxSectionAlignment &&
           "impossible requested alignment");
  }

  // Write this chunk to a mmap'ed file, assuming Buf is pointing to
  // beginning of the file. Because this function may use RVA values
  // of other chunks for relocations, you need to set them properly
  // before calling this function.
  void writeTo(uint8_t *buf) const;

  // The writer sets and uses the addresses. In practice, PE images cannot be
  // larger than 2GB. Chunks are always laid as part of the image, so Chunk RVAs
  // can be stored with 32 bits.
  uint32_t getRVA() const { return rva; }
  void setRVA(uint64_t v) {
    rva = (uint32_t)v;
    assert(rva == v && "RVA truncated");
  }

  // Returns readable/writable/executable bits.
  uint32_t getOutputCharacteristics() const;

  // Returns the section name if this is a section chunk.
  // It is illegal to call this function on non-section chunks.
  StringRef getSectionName() const;

  // An output section has pointers to chunks in the section, and each
  // chunk has a back pointer to an output section.
  void setOutputSectionIdx(uint16_t o) { osidx = o; }
  uint16_t getOutputSectionIdx() const { return osidx; }
  OutputSection *getOutputSection() const;

  // Windows-specific.
  // Collect all locations that contain absolute addresses for base relocations.
  void getBaserels(std::vector<Baserel> *res);

  // Returns a human-readable name of this chunk. Chunks are unnamed chunks of
  // bytes, so this is used only for logging or debugging.
  StringRef getDebugName() const;

  // Return true if this file has the hotpatch flag set to true in the
  // S_COMPILE3 record in codeview debug info. Also returns true for some thunks
  // synthesized by the linker.
  bool isHotPatchable() const;

protected:
  Chunk(Kind k = OtherKind) : chunkKind(k), hasData(true), p2Align(0) {}

  const Kind chunkKind;

public:
  // Returns true if this has non-zero data. BSS chunks return
  // false. If false is returned, the space occupied by this chunk
  // will be filled with zeros. Corresponds to the
  // IMAGE_SCN_CNT_UNINITIALIZED_DATA section characteristic bit.
  uint8_t hasData : 1;

public:
  // The alignment of this chunk, stored in log2 form. The writer uses the
  // value.
  uint8_t p2Align : 7;

  // The output section index for this chunk. The first valid section number is
  // one.
  uint16_t osidx = 0;

  // The RVA of this chunk in the output. The writer sets a value.
  uint32_t rva = 0;
};

class NonSectionChunk : public Chunk {
public:
  virtual ~NonSectionChunk() = default;

  // Returns the size of this chunk (even if this is a common or BSS.)
  virtual size_t getSize() const = 0;

  virtual uint32_t getOutputCharacteristics() const { return 0; }

  // Write this chunk to a mmap'ed file, assuming Buf is pointing to
  // beginning of the file. Because this function may use RVA values
  // of other chunks for relocations, you need to set them properly
  // before calling this function.
  virtual void writeTo(uint8_t *buf) const {}

  // Returns the section name if this is a section chunk.
  // It is illegal to call this function on non-section chunks.
  virtual StringRef getSectionName() const {
    llvm_unreachable("unimplemented getSectionName");
  }

  // Windows-specific.
  // Collect all locations that contain absolute addresses for base relocations.
  virtual void getBaserels(std::vector<Baserel> *res) {}

  // Returns a human-readable name of this chunk. Chunks are unnamed chunks of
  // bytes, so this is used only for logging or debugging.
  virtual StringRef getDebugName() const { return ""; }

  static bool classof(const Chunk *c) { return c->kind() != SectionKind; }

protected:
  NonSectionChunk(Kind k = OtherKind) : Chunk(k) {}
};

// A chunk corresponding a section of an input file.
class SectionChunk final : public Chunk {
  // Identical COMDAT Folding feature accesses section internal data.
  friend class ICF;

public:
  class symbol_iterator : public llvm::iterator_adaptor_base<
                              symbol_iterator, const coff_relocation *,
                              std::random_access_iterator_tag, Symbol *> {
    friend SectionChunk;

    ObjFile *file;

    symbol_iterator(ObjFile *file, const coff_relocation *i)
        : symbol_iterator::iterator_adaptor_base(i), file(file) {}

  public:
    symbol_iterator() = default;

    Symbol *operator*() const { return file->getSymbol(I->SymbolTableIndex); }
  };

  SectionChunk(ObjFile *file, const coff_section *header);
  static bool classof(const Chunk *c) { return c->kind() == SectionKind; }
  size_t getSize() const { return header->SizeOfRawData; }
  ArrayRef<uint8_t> getContents() const;
  void writeTo(uint8_t *buf) const;

  uint32_t getOutputCharacteristics() const {
    return header->Characteristics & (permMask | typeMask);
  }
  StringRef getSectionName() const {
    return StringRef(sectionNameData, sectionNameSize);
  }
  void getBaserels(std::vector<Baserel> *res);
  bool isCOMDAT() const;
  void applyRelX64(uint8_t *off, uint16_t type, OutputSection *os, uint64_t s,
                   uint64_t p) const;
  void applyRelX86(uint8_t *off, uint16_t type, OutputSection *os, uint64_t s,
                   uint64_t p) const;
  void applyRelARM(uint8_t *off, uint16_t type, OutputSection *os, uint64_t s,
                   uint64_t p) const;
  void applyRelARM64(uint8_t *off, uint16_t type, OutputSection *os, uint64_t s,
                     uint64_t p) const;

  void getRuntimePseudoRelocs(std::vector<RuntimePseudoReloc> &res);

  // Called if the garbage collector decides to not include this chunk
  // in a final output. It's supposed to print out a log message to stdout.
  void printDiscardedMessage() const;

  // Adds COMDAT associative sections to this COMDAT section. A chunk
  // and its children are treated as a group by the garbage collector.
  void addAssociative(SectionChunk *child);

  StringRef getDebugName() const;

  // True if this is a codeview debug info chunk. These will not be laid out in
  // the image. Instead they will end up in the PDB, if one is requested.
  bool isCodeView() const {
    return getSectionName() == ".debug" || getSectionName().startswith(".debug$");
  }

  // True if this is a DWARF debug info or exception handling chunk.
  bool isDWARF() const {
    return getSectionName().startswith(".debug_") || getSectionName() == ".eh_frame";
  }

  // Allow iteration over the bodies of this chunk's relocated symbols.
  llvm::iterator_range<symbol_iterator> symbols() const {
    return llvm::make_range(symbol_iterator(file, relocsData),
                            symbol_iterator(file, relocsData + relocsSize));
  }

  ArrayRef<coff_relocation> getRelocs() const {
    return llvm::makeArrayRef(relocsData, relocsSize);
  }

  // Reloc setter used by ARM range extension thunk insertion.
  void setRelocs(ArrayRef<coff_relocation> newRelocs) {
    relocsData = newRelocs.data();
    relocsSize = newRelocs.size();
    assert(relocsSize == newRelocs.size() && "reloc size truncation");
  }

  // Single linked list iterator for associated comdat children.
  class AssociatedIterator
      : public llvm::iterator_facade_base<
            AssociatedIterator, std::forward_iterator_tag, SectionChunk> {
  public:
    AssociatedIterator() = default;
    AssociatedIterator(SectionChunk *head) : cur(head) {}
    AssociatedIterator &operator=(const AssociatedIterator &r) {
      cur = r.cur;
      return *this;
    }
    bool operator==(const AssociatedIterator &r) const { return cur == r.cur; }
    const SectionChunk &operator*() const { return *cur; }
    SectionChunk &operator*() { return *cur; }
    AssociatedIterator &operator++() {
      cur = cur->assocChildren;
      return *this;
    }

  private:
    SectionChunk *cur = nullptr;
  };

  // Allow iteration over the associated child chunks for this section.
  llvm::iterator_range<AssociatedIterator> children() const {
    return llvm::make_range(AssociatedIterator(assocChildren),
                            AssociatedIterator(nullptr));
  }

  // The section ID this chunk belongs to in its Obj.
  uint32_t getSectionNumber() const;

  ArrayRef<uint8_t> consumeDebugMagic();

  static ArrayRef<uint8_t> consumeDebugMagic(ArrayRef<uint8_t> data,
                                             StringRef sectionName);

  static SectionChunk *findByName(ArrayRef<SectionChunk *> sections,
                                  StringRef name);

  // The file that this chunk was created from.
  ObjFile *file;

  // Pointer to the COFF section header in the input file.
  const coff_section *header;

  // The COMDAT leader symbol if this is a COMDAT chunk.
  DefinedRegular *sym = nullptr;

  // The CRC of the contents as described in the COFF spec 4.5.5.
  // Auxiliary Format 5: Section Definitions. Used for ICF.
  uint32_t checksum = 0;

  // Used by the garbage collector.
  bool live;

  // Whether this section needs to be kept distinct from other sections during
  // ICF. This is set by the driver using address-significance tables.
  bool keepUnique = false;

  // The COMDAT selection if this is a COMDAT chunk.
  llvm::COFF::COMDATType selection = (llvm::COFF::COMDATType)0;

  // A pointer pointing to a replacement for this chunk.
  // Initially it points to "this" object. If this chunk is merged
  // with other chunk by ICF, it points to another chunk,
  // and this chunk is considered as dead.
  SectionChunk *repl;

private:
  SectionChunk *assocChildren = nullptr;

  // Used for ICF (Identical COMDAT Folding)
  void replace(SectionChunk *other);
  uint32_t eqClass[2] = {0, 0};

  // Relocations for this section. Size is stored below.
  const coff_relocation *relocsData;

  // Section name string. Size is stored below.
  const char *sectionNameData;

  uint32_t relocsSize = 0;
  uint32_t sectionNameSize = 0;
};

// Inline methods to implement faux-virtual dispatch for SectionChunk.

inline size_t Chunk::getSize() const {
  if (isa<SectionChunk>(this))
    return static_cast<const SectionChunk *>(this)->getSize();
  else
    return static_cast<const NonSectionChunk *>(this)->getSize();
}

inline uint32_t Chunk::getOutputCharacteristics() const {
  if (isa<SectionChunk>(this))
    return static_cast<const SectionChunk *>(this)->getOutputCharacteristics();
  else
    return static_cast<const NonSectionChunk *>(this)
        ->getOutputCharacteristics();
}

inline void Chunk::writeTo(uint8_t *buf) const {
  if (isa<SectionChunk>(this))
    static_cast<const SectionChunk *>(this)->writeTo(buf);
  else
    static_cast<const NonSectionChunk *>(this)->writeTo(buf);
}

inline StringRef Chunk::getSectionName() const {
  if (isa<SectionChunk>(this))
    return static_cast<const SectionChunk *>(this)->getSectionName();
  else
    return static_cast<const NonSectionChunk *>(this)->getSectionName();
}

inline void Chunk::getBaserels(std::vector<Baserel> *res) {
  if (isa<SectionChunk>(this))
    static_cast<SectionChunk *>(this)->getBaserels(res);
  else
    static_cast<NonSectionChunk *>(this)->getBaserels(res);
}

inline StringRef Chunk::getDebugName() const {
  if (isa<SectionChunk>(this))
    return static_cast<const SectionChunk *>(this)->getDebugName();
  else
    return static_cast<const NonSectionChunk *>(this)->getDebugName();
}

// This class is used to implement an lld-specific feature (not implemented in
// MSVC) that minimizes the output size by finding string literals sharing tail
// parts and merging them.
//
// If string tail merging is enabled and a section is identified as containing a
// string literal, it is added to a MergeChunk with an appropriate alignment.
// The MergeChunk then tail merges the strings using the StringTableBuilder
// class and assigns RVAs and section offsets to each of the member chunks based
// on the offsets assigned by the StringTableBuilder.
class MergeChunk : public NonSectionChunk {
public:
  MergeChunk(uint32_t alignment);
  static void addSection(SectionChunk *c);
  void finalizeContents();
  void assignSubsectionRVAs();

  uint32_t getOutputCharacteristics() const override;
  StringRef getSectionName() const override { return ".rdata"; }
  size_t getSize() const override;
  void writeTo(uint8_t *buf) const override;

  static MergeChunk *instances[Log2MaxSectionAlignment + 1];
  std::vector<SectionChunk *> sections;

private:
  llvm::StringTableBuilder builder;
  bool finalized = false;
};

// A chunk for common symbols. Common chunks don't have actual data.
class CommonChunk : public NonSectionChunk {
public:
  CommonChunk(const COFFSymbolRef sym);
  size_t getSize() const override { return sym.getValue(); }
  uint32_t getOutputCharacteristics() const override;
  StringRef getSectionName() const override { return ".bss"; }

private:
  const COFFSymbolRef sym;
};

// A chunk for linker-created strings.
class StringChunk : public NonSectionChunk {
public:
  explicit StringChunk(StringRef s) : str(s) {}
  size_t getSize() const override { return str.size() + 1; }
  void writeTo(uint8_t *buf) const override;

private:
  StringRef str;
};

static const uint8_t importThunkX86[] = {
    0xff, 0x25, 0x00, 0x00, 0x00, 0x00, // JMP *0x0
};

static const uint8_t importThunkARM[] = {
    0x40, 0xf2, 0x00, 0x0c, // mov.w ip, #0
    0xc0, 0xf2, 0x00, 0x0c, // mov.t ip, #0
    0xdc, 0xf8, 0x00, 0xf0, // ldr.w pc, [ip]
};

static const uint8_t importThunkARM64[] = {
    0x10, 0x00, 0x00, 0x90, // adrp x16, #0
    0x10, 0x02, 0x40, 0xf9, // ldr  x16, [x16]
    0x00, 0x02, 0x1f, 0xd6, // br   x16
};

// Windows-specific.
// A chunk for DLL import jump table entry. In a final output, its
// contents will be a JMP instruction to some __imp_ symbol.
class ImportThunkChunk : public NonSectionChunk {
public:
  ImportThunkChunk(Defined *s)
      : NonSectionChunk(ImportThunkKind), impSymbol(s) {}
  static bool classof(const Chunk *c) { return c->kind() == ImportThunkKind; }

protected:
  Defined *impSymbol;
};

class ImportThunkChunkX64 : public ImportThunkChunk {
public:
  explicit ImportThunkChunkX64(Defined *s);
  size_t getSize() const override { return sizeof(importThunkX86); }
  void writeTo(uint8_t *buf) const override;
};

class ImportThunkChunkX86 : public ImportThunkChunk {
public:
  explicit ImportThunkChunkX86(Defined *s) : ImportThunkChunk(s) {}
  size_t getSize() const override { return sizeof(importThunkX86); }
  void getBaserels(std::vector<Baserel> *res) override;
  void writeTo(uint8_t *buf) const override;
};

class ImportThunkChunkARM : public ImportThunkChunk {
public:
  explicit ImportThunkChunkARM(Defined *s) : ImportThunkChunk(s) {}
  size_t getSize() const override { return sizeof(importThunkARM); }
  void getBaserels(std::vector<Baserel> *res) override;
  void writeTo(uint8_t *buf) const override;
};

class ImportThunkChunkARM64 : public ImportThunkChunk {
public:
  explicit ImportThunkChunkARM64(Defined *s) : ImportThunkChunk(s) {}
  size_t getSize() const override { return sizeof(importThunkARM64); }
  void writeTo(uint8_t *buf) const override;
};

class RangeExtensionThunkARM : public NonSectionChunk {
public:
  explicit RangeExtensionThunkARM(Defined *t) : target(t) {}
  size_t getSize() const override;
  void writeTo(uint8_t *buf) const override;

  Defined *target;
};

class RangeExtensionThunkARM64 : public NonSectionChunk {
public:
  explicit RangeExtensionThunkARM64(Defined *t) : target(t) {}
  size_t getSize() const override;
  void writeTo(uint8_t *buf) const override;

  Defined *target;
};

// Windows-specific.
// See comments for DefinedLocalImport class.
class LocalImportChunk : public NonSectionChunk {
public:
  explicit LocalImportChunk(Defined *s) : sym(s) {
    setAlignment(config->wordsize);
  }
  size_t getSize() const override;
  void getBaserels(std::vector<Baserel> *res) override;
  void writeTo(uint8_t *buf) const override;

private:
  Defined *sym;
};

// Duplicate RVAs are not allowed in RVA tables, so unique symbols by chunk and
// offset into the chunk. Order does not matter as the RVA table will be sorted
// later.
struct ChunkAndOffset {
  Chunk *inputChunk;
  uint32_t offset;

  struct DenseMapInfo {
    static ChunkAndOffset getEmptyKey() {
      return {llvm::DenseMapInfo<Chunk *>::getEmptyKey(), 0};
    }
    static ChunkAndOffset getTombstoneKey() {
      return {llvm::DenseMapInfo<Chunk *>::getTombstoneKey(), 0};
    }
    static unsigned getHashValue(const ChunkAndOffset &co) {
      return llvm::DenseMapInfo<std::pair<Chunk *, uint32_t>>::getHashValue(
          {co.inputChunk, co.offset});
    }
    static bool isEqual(const ChunkAndOffset &lhs, const ChunkAndOffset &rhs) {
      return lhs.inputChunk == rhs.inputChunk && lhs.offset == rhs.offset;
    }
  };
};

using SymbolRVASet = llvm::DenseSet<ChunkAndOffset>;

// Table which contains symbol RVAs. Used for /safeseh and /guard:cf.
class RVATableChunk : public NonSectionChunk {
public:
  explicit RVATableChunk(SymbolRVASet s) : syms(std::move(s)) {}
  size_t getSize() const override { return syms.size() * 4; }
  void writeTo(uint8_t *buf) const override;

private:
  SymbolRVASet syms;
};

// Windows-specific.
// This class represents a block in .reloc section.
// See the PE/COFF spec 5.6 for details.
class BaserelChunk : public NonSectionChunk {
public:
  BaserelChunk(uint32_t page, Baserel *begin, Baserel *end);
  size_t getSize() const override { return data.size(); }
  void writeTo(uint8_t *buf) const override;

private:
  std::vector<uint8_t> data;
};

class Baserel {
public:
  Baserel(uint32_t v, uint8_t ty) : rva(v), type(ty) {}
  explicit Baserel(uint32_t v) : Baserel(v, getDefaultType()) {}
  uint8_t getDefaultType();

  uint32_t rva;
  uint8_t type;
};

// This is a placeholder Chunk, to allow attaching a DefinedSynthetic to a
// specific place in a section, without any data. This is used for the MinGW
// specific symbol __RUNTIME_PSEUDO_RELOC_LIST_END__, even though the concept
// of an empty chunk isn't MinGW specific.
class EmptyChunk : public NonSectionChunk {
public:
  EmptyChunk() {}
  size_t getSize() const override { return 0; }
  void writeTo(uint8_t *buf) const override {}
};

// MinGW specific, for the "automatic import of variables from DLLs" feature.
// This provides the table of runtime pseudo relocations, for variable
// references that turned out to need to be imported from a DLL even though
// the reference didn't use the dllimport attribute. The MinGW runtime will
// process this table after loading, before handling control over to user
// code.
class PseudoRelocTableChunk : public NonSectionChunk {
public:
  PseudoRelocTableChunk(std::vector<RuntimePseudoReloc> &relocs)
      : relocs(std::move(relocs)) {
    setAlignment(4);
  }
  size_t getSize() const override;
  void writeTo(uint8_t *buf) const override;

private:
  std::vector<RuntimePseudoReloc> relocs;
};

// MinGW specific; information about one individual location in the image
// that needs to be fixed up at runtime after loading. This represents
// one individual element in the PseudoRelocTableChunk table.
class RuntimePseudoReloc {
public:
  RuntimePseudoReloc(Defined *sym, SectionChunk *target, uint32_t targetOffset,
                     int flags)
      : sym(sym), target(target), targetOffset(targetOffset), flags(flags) {}

  Defined *sym;
  SectionChunk *target;
  uint32_t targetOffset;
  // The Flags field contains the size of the relocation, in bits. No other
  // flags are currently defined.
  int flags;
};

// MinGW specific. A Chunk that contains one pointer-sized absolute value.
class AbsolutePointerChunk : public NonSectionChunk {
public:
  AbsolutePointerChunk(uint64_t value) : value(value) {
    setAlignment(getSize());
  }
  size_t getSize() const override;
  void writeTo(uint8_t *buf) const override;

private:
  uint64_t value;
};

// Return true if this file has the hotpatch flag set to true in the S_COMPILE3
// record in codeview debug info. Also returns true for some thunks synthesized
// by the linker.
inline bool Chunk::isHotPatchable() const {
  if (auto *sc = dyn_cast<SectionChunk>(this))
    return sc->file->hotPatchable;
  else if (isa<ImportThunkChunk>(this))
    return true;
  return false;
}

void applyMOV32T(uint8_t *off, uint32_t v);
void applyBranch24T(uint8_t *off, int32_t v);

void applyArm64Addr(uint8_t *off, uint64_t s, uint64_t p, int shift);
void applyArm64Imm(uint8_t *off, uint64_t imm, uint32_t rangeLimit);
void applyArm64Branch26(uint8_t *off, int64_t v);

} // namespace coff
} // namespace lld

namespace llvm {
template <>
struct DenseMapInfo<lld::coff::ChunkAndOffset>
    : lld::coff::ChunkAndOffset::DenseMapInfo {};
}

#endif
