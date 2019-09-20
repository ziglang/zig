//===- DWARF.cpp ----------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// The -gdb-index option instructs the linker to emit a .gdb_index section.
// The section contains information to make gdb startup faster.
// The format of the section is described at
// https://sourceware.org/gdb/onlinedocs/gdb/Index-Section-Format.html.
//
//===----------------------------------------------------------------------===//

#include "DWARF.h"
#include "Symbols.h"
#include "Target.h"
#include "lld/Common/Memory.h"
#include "llvm/DebugInfo/DWARF/DWARFDebugPubTable.h"
#include "llvm/Object/ELFObjectFile.h"

using namespace llvm;
using namespace llvm::object;
using namespace lld;
using namespace lld::elf;

template <class ELFT> LLDDwarfObj<ELFT>::LLDDwarfObj(ObjFile<ELFT> *obj) {
  for (InputSectionBase *sec : obj->getSections()) {
    if (!sec)
      continue;

    if (LLDDWARFSection *m =
            StringSwitch<LLDDWARFSection *>(sec->name)
                .Case(".debug_addr", &addrSection)
                .Case(".debug_gnu_pubnames", &gnuPubNamesSection)
                .Case(".debug_gnu_pubtypes", &gnuPubTypesSection)
                .Case(".debug_info", &infoSection)
                .Case(".debug_ranges", &rangeSection)
                .Case(".debug_rnglists", &rngListsSection)
                .Case(".debug_line", &lineSection)
                .Default(nullptr)) {
      m->Data = toStringRef(sec->data());
      m->sec = sec;
      continue;
    }

    if (sec->name == ".debug_abbrev")
      abbrevSection = toStringRef(sec->data());
    else if (sec->name == ".debug_str")
      strSection = toStringRef(sec->data());
    else if (sec->name == ".debug_line_str")
      lineStringSection = toStringRef(sec->data());
  }
}

namespace {
template <class RelTy> struct LLDRelocationResolver {
  // In the ELF ABIs, S sepresents the value of the symbol in the relocation
  // entry. For Rela, the addend is stored as part of the relocation entry.
  static uint64_t resolve(object::RelocationRef ref, uint64_t s,
                          uint64_t /* A */) {
    return s + ref.getRawDataRefImpl().p;
  }
};

template <class ELFT> struct LLDRelocationResolver<Elf_Rel_Impl<ELFT, false>> {
  // For Rel, the addend A is supplied by the caller.
  static uint64_t resolve(object::RelocationRef /*Ref*/, uint64_t s,
                          uint64_t a) {
    return s + a;
  }
};
} // namespace

// Find if there is a relocation at Pos in Sec.  The code is a bit
// more complicated than usual because we need to pass a section index
// to llvm since it has no idea about InputSection.
template <class ELFT>
template <class RelTy>
Optional<RelocAddrEntry>
LLDDwarfObj<ELFT>::findAux(const InputSectionBase &sec, uint64_t pos,
                           ArrayRef<RelTy> rels) const {
  auto it =
      partition_point(rels, [=](const RelTy &a) { return a.r_offset < pos; });
  if (it == rels.end() || it->r_offset != pos)
    return None;
  const RelTy &rel = *it;

  const ObjFile<ELFT> *file = sec.getFile<ELFT>();
  uint32_t symIndex = rel.getSymbol(config->isMips64EL);
  const typename ELFT::Sym &sym = file->template getELFSyms<ELFT>()[symIndex];
  uint32_t secIndex = file->getSectionIndex(sym);

  // An undefined symbol may be a symbol defined in a discarded section. We
  // shall still resolve it. This is important for --gdb-index: the end address
  // offset of an entry in .debug_ranges is relocated. If it is not resolved,
  // its zero value will terminate the decoding of .debug_ranges prematurely.
  Symbol &s = file->getRelocTargetSym(rel);
  uint64_t val = 0;
  if (auto *dr = dyn_cast<Defined>(&s)) {
    val = dr->value;

    // FIXME: We should be consistent about always adding the file
    // offset or not.
    if (dr->section->flags & ELF::SHF_ALLOC)
      val += cast<InputSection>(dr->section)->getOffsetInFile();
  }

  DataRefImpl d;
  d.p = getAddend<ELFT>(rel);
  return RelocAddrEntry{secIndex, RelocationRef(d, nullptr),
                        val,      Optional<object::RelocationRef>(),
                        0,        LLDRelocationResolver<RelTy>::resolve};
}

template <class ELFT>
Optional<RelocAddrEntry> LLDDwarfObj<ELFT>::find(const llvm::DWARFSection &s,
                                                 uint64_t pos) const {
  auto &sec = static_cast<const LLDDWARFSection &>(s);
  if (sec.sec->areRelocsRela)
    return findAux(*sec.sec, pos, sec.sec->template relas<ELFT>());
  return findAux(*sec.sec, pos, sec.sec->template rels<ELFT>());
}

template class elf::LLDDwarfObj<ELF32LE>;
template class elf::LLDDwarfObj<ELF32BE>;
template class elf::LLDDwarfObj<ELF64LE>;
template class elf::LLDDwarfObj<ELF64BE>;
