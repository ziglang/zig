//===- DWARF.h -----------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===-------------------------------------------------------------------===//

#ifndef LLD_ELF_DWARF_H
#define LLD_ELF_DWARF_H

#include "InputFiles.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/DebugInfo/DWARF/DWARFContext.h"
#include "llvm/Object/ELF.h"

namespace lld {
namespace elf {

class InputSection;

struct LLDDWARFSection final : public llvm::DWARFSection {
  InputSectionBase *sec = nullptr;
};

template <class ELFT> class LLDDwarfObj final : public llvm::DWARFObject {
public:
  explicit LLDDwarfObj(ObjFile<ELFT> *obj);

  void forEachInfoSections(
      llvm::function_ref<void(const llvm::DWARFSection &)> f) const override {
    f(infoSection);
  }

  const llvm::DWARFSection &getRangeSection() const override {
    return rangeSection;
  }

  const llvm::DWARFSection &getRnglistsSection() const override {
    return rngListsSection;
  }

  const llvm::DWARFSection &getLineSection() const override {
    return lineSection;
  }

  const llvm::DWARFSection &getAddrSection() const override {
    return addrSection;
  }

  const llvm::DWARFSection &getGnuPubNamesSection() const override {
    return gnuPubNamesSection;
  }

  const llvm::DWARFSection &getGnuPubTypesSection() const override {
    return gnuPubTypesSection;
  }

  StringRef getFileName() const override { return ""; }
  StringRef getAbbrevSection() const override { return abbrevSection; }
  StringRef getStringSection() const override { return strSection; }
  StringRef getLineStringSection() const override { return lineStringSection; }

  bool isLittleEndian() const override {
    return ELFT::TargetEndianness == llvm::support::little;
  }

  llvm::Optional<llvm::RelocAddrEntry> find(const llvm::DWARFSection &sec,
                                            uint64_t pos) const override;

private:
  template <class RelTy>
  llvm::Optional<llvm::RelocAddrEntry> findAux(const InputSectionBase &sec,
                                               uint64_t pos,
                                               ArrayRef<RelTy> rels) const;

  LLDDWARFSection gnuPubNamesSection;
  LLDDWARFSection gnuPubTypesSection;
  LLDDWARFSection infoSection;
  LLDDWARFSection rangeSection;
  LLDDWARFSection rngListsSection;
  LLDDWARFSection lineSection;
  LLDDWARFSection addrSection;
  StringRef abbrevSection;
  StringRef strSection;
  StringRef lineStringSection;
};

} // namespace elf
} // namespace lld

#endif
