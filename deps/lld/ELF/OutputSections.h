//===- OutputSections.h -----------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_ELF_OUTPUT_SECTIONS_H
#define LLD_ELF_OUTPUT_SECTIONS_H

#include "Config.h"
#include "InputSection.h"
#include "LinkerScript.h"
#include "Relocations.h"
#include "lld/Common/LLVM.h"
#include "llvm/MC/StringTableBuilder.h"
#include "llvm/Object/ELF.h"
#include <array>

namespace lld {
namespace elf {

struct PhdrEntry;
class InputSection;
class InputSectionBase;

// This represents a section in an output file.
// It is composed of multiple InputSections.
// The writer creates multiple OutputSections and assign them unique,
// non-overlapping file offsets and VAs.
class OutputSection final : public BaseCommand, public SectionBase {
public:
  OutputSection(StringRef name, uint32_t type, uint64_t flags);

  static bool classof(const SectionBase *s) {
    return s->kind() == SectionBase::Output;
  }

  static bool classof(const BaseCommand *c);

  uint64_t getLMA() const { return ptLoad ? addr + ptLoad->lmaOffset : addr; }
  template <typename ELFT> void writeHeaderTo(typename ELFT::Shdr *sHdr);

  uint32_t sectionIndex = UINT32_MAX;
  unsigned sortRank;

  uint32_t getPhdrFlags() const;

  // Pointer to the PT_LOAD segment, which this section resides in. This field
  // is used to correctly compute file offset of a section. When two sections
  // share the same load segment, difference between their file offsets should
  // be equal to difference between their virtual addresses. To compute some
  // section offset we use the following formula: Off = Off_first + VA -
  // VA_first, where Off_first and VA_first is file offset and VA of first
  // section in PT_LOAD.
  PhdrEntry *ptLoad = nullptr;

  // Pointer to a relocation section for this section. Usually nullptr because
  // we consume relocations, but if --emit-relocs is specified (which is rare),
  // it may have a non-null value.
  OutputSection *relocationSection = nullptr;

  // Initially this field is the number of InputSections that have been added to
  // the OutputSection so far. Later on, after a call to assignAddresses, it
  // corresponds to the Elf_Shdr member.
  uint64_t size = 0;

  // The following fields correspond to Elf_Shdr members.
  uint64_t offset = 0;
  uint64_t addr = 0;
  uint32_t shName = 0;

  void addSection(InputSection *isec);

  // The following members are normally only used in linker scripts.
  MemoryRegion *memRegion = nullptr;
  MemoryRegion *lmaRegion = nullptr;
  Expr addrExpr;
  Expr alignExpr;
  Expr lmaExpr;
  Expr subalignExpr;
  std::vector<BaseCommand *> sectionCommands;
  std::vector<StringRef> phdrs;
  llvm::Optional<std::array<uint8_t, 4>> filler;
  ConstraintKind constraint = ConstraintKind::NoConstraint;
  std::string location;
  std::string memoryRegionName;
  std::string lmaRegionName;
  bool nonAlloc = false;
  bool noload = false;
  bool expressionsUseSymbols = false;
  bool usedInExpression = false;
  bool inOverlay = false;

  // Tracks whether the section has ever had an input section added to it, even
  // if the section was later removed (e.g. because it is a synthetic section
  // that wasn't needed). This is needed for orphan placement.
  bool hasInputSections = false;

  void finalize();
  template <class ELFT> void writeTo(uint8_t *buf);
  template <class ELFT> void maybeCompress();

  void sort(llvm::function_ref<int(InputSectionBase *s)> order);
  void sortInitFini();
  void sortCtorsDtors();

private:
  // Used for implementation of --compress-debug-sections option.
  std::vector<uint8_t> zDebugHeader;
  llvm::SmallVector<char, 1> compressedData;

  std::array<uint8_t, 4> getFiller();
};

int getPriority(StringRef s);

std::vector<InputSection *> getInputSections(OutputSection* os);

// All output sections that are handled by the linker specially are
// globally accessible. Writer initializes them, so don't use them
// until Writer is initialized.
struct Out {
  static uint8_t *bufferStart;
  static uint8_t first;
  static PhdrEntry *tlsPhdr;
  static OutputSection *elfHeader;
  static OutputSection *programHeaders;
  static OutputSection *preinitArray;
  static OutputSection *initArray;
  static OutputSection *finiArray;
};

} // namespace elf
} // namespace lld

namespace lld {
namespace elf {

uint64_t getHeaderSize();

extern std::vector<OutputSection *> outputSections;
} // namespace elf
} // namespace lld

#endif
