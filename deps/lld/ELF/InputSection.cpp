//===- InputSection.cpp ---------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "InputSection.h"
#include "Config.h"
#include "EhFrame.h"
#include "InputFiles.h"
#include "LinkerScript.h"
#include "OutputSections.h"
#include "Relocations.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "Thunks.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "llvm/Support/Compiler.h"
#include "llvm/Support/Compression.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/Threading.h"
#include "llvm/Support/xxhash.h"
#include <algorithm>
#include <mutex>
#include <set>
#include <vector>

using namespace llvm;
using namespace llvm::ELF;
using namespace llvm::object;
using namespace llvm::support;
using namespace llvm::support::endian;
using namespace llvm::sys;

using namespace lld;
using namespace lld::elf;

std::vector<InputSectionBase *> elf::inputSections;

// Returns a string to construct an error message.
std::string lld::toString(const InputSectionBase *sec) {
  return (toString(sec->file) + ":(" + sec->name + ")").str();
}

template <class ELFT>
static ArrayRef<uint8_t> getSectionContents(ObjFile<ELFT> &file,
                                            const typename ELFT::Shdr &hdr) {
  if (hdr.sh_type == SHT_NOBITS)
    return makeArrayRef<uint8_t>(nullptr, hdr.sh_size);
  return check(file.getObj().getSectionContents(&hdr));
}

InputSectionBase::InputSectionBase(InputFile *file, uint64_t flags,
                                   uint32_t type, uint64_t entsize,
                                   uint32_t link, uint32_t info,
                                   uint32_t alignment, ArrayRef<uint8_t> data,
                                   StringRef name, Kind sectionKind)
    : SectionBase(sectionKind, name, flags, entsize, alignment, type, info,
                  link),
      file(file), rawData(data) {
  // In order to reduce memory allocation, we assume that mergeable
  // sections are smaller than 4 GiB, which is not an unreasonable
  // assumption as of 2017.
  if (sectionKind == SectionBase::Merge && rawData.size() > UINT32_MAX)
    error(toString(this) + ": section too large");

  numRelocations = 0;
  areRelocsRela = false;

  // The ELF spec states that a value of 0 means the section has
  // no alignment constraits.
  uint32_t v = std::max<uint32_t>(alignment, 1);
  if (!isPowerOf2_64(v))
    fatal(toString(this) + ": sh_addralign is not a power of 2");
  this->alignment = v;

  // In ELF, each section can be compressed by zlib, and if compressed,
  // section name may be mangled by appending "z" (e.g. ".zdebug_info").
  // If that's the case, demangle section name so that we can handle a
  // section as if it weren't compressed.
  if ((flags & SHF_COMPRESSED) || name.startswith(".zdebug")) {
    if (!zlib::isAvailable())
      error(toString(file) + ": contains a compressed section, " +
            "but zlib is not available");
    parseCompressedHeader();
  }
}

// Drop SHF_GROUP bit unless we are producing a re-linkable object file.
// SHF_GROUP is a marker that a section belongs to some comdat group.
// That flag doesn't make sense in an executable.
static uint64_t getFlags(uint64_t flags) {
  flags &= ~(uint64_t)SHF_INFO_LINK;
  if (!config->relocatable)
    flags &= ~(uint64_t)SHF_GROUP;
  return flags;
}

// GNU assembler 2.24 and LLVM 4.0.0's MC (the newest release as of
// March 2017) fail to infer section types for sections starting with
// ".init_array." or ".fini_array.". They set SHT_PROGBITS instead of
// SHF_INIT_ARRAY. As a result, the following assembler directive
// creates ".init_array.100" with SHT_PROGBITS, for example.
//
//   .section .init_array.100, "aw"
//
// This function forces SHT_{INIT,FINI}_ARRAY so that we can handle
// incorrect inputs as if they were correct from the beginning.
static uint64_t getType(uint64_t type, StringRef name) {
  if (type == SHT_PROGBITS && name.startswith(".init_array."))
    return SHT_INIT_ARRAY;
  if (type == SHT_PROGBITS && name.startswith(".fini_array."))
    return SHT_FINI_ARRAY;
  return type;
}

template <class ELFT>
InputSectionBase::InputSectionBase(ObjFile<ELFT> &file,
                                   const typename ELFT::Shdr &hdr,
                                   StringRef name, Kind sectionKind)
    : InputSectionBase(&file, getFlags(hdr.sh_flags),
                       getType(hdr.sh_type, name), hdr.sh_entsize, hdr.sh_link,
                       hdr.sh_info, hdr.sh_addralign,
                       getSectionContents(file, hdr), name, sectionKind) {
  // We reject object files having insanely large alignments even though
  // they are allowed by the spec. I think 4GB is a reasonable limitation.
  // We might want to relax this in the future.
  if (hdr.sh_addralign > UINT32_MAX)
    fatal(toString(&file) + ": section sh_addralign is too large");
}

size_t InputSectionBase::getSize() const {
  if (auto *s = dyn_cast<SyntheticSection>(this))
    return s->getSize();
  if (uncompressedSize >= 0)
    return uncompressedSize;
  return rawData.size();
}

void InputSectionBase::uncompress() const {
  size_t size = uncompressedSize;
  char *uncompressedBuf;
  {
    static std::mutex mu;
    std::lock_guard<std::mutex> lock(mu);
    uncompressedBuf = bAlloc.Allocate<char>(size);
  }

  if (Error e = zlib::uncompress(toStringRef(rawData), uncompressedBuf, size))
    fatal(toString(this) +
          ": uncompress failed: " + llvm::toString(std::move(e)));
  rawData = makeArrayRef((uint8_t *)uncompressedBuf, size);
  uncompressedSize = -1;
}

uint64_t InputSectionBase::getOffsetInFile() const {
  const uint8_t *fileStart = (const uint8_t *)file->mb.getBufferStart();
  const uint8_t *secStart = data().begin();
  return secStart - fileStart;
}

uint64_t SectionBase::getOffset(uint64_t offset) const {
  switch (kind()) {
  case Output: {
    auto *os = cast<OutputSection>(this);
    // For output sections we treat offset -1 as the end of the section.
    return offset == uint64_t(-1) ? os->size : offset;
  }
  case Regular:
  case Synthetic:
    return cast<InputSection>(this)->getOffset(offset);
  case EHFrame:
    // The file crtbeginT.o has relocations pointing to the start of an empty
    // .eh_frame that is known to be the first in the link. It does that to
    // identify the start of the output .eh_frame.
    return offset;
  case Merge:
    const MergeInputSection *ms = cast<MergeInputSection>(this);
    if (InputSection *isec = ms->getParent())
      return isec->getOffset(ms->getParentOffset(offset));
    return ms->getParentOffset(offset);
  }
  llvm_unreachable("invalid section kind");
}

uint64_t SectionBase::getVA(uint64_t offset) const {
  const OutputSection *out = getOutputSection();
  return (out ? out->addr : 0) + getOffset(offset);
}

OutputSection *SectionBase::getOutputSection() {
  InputSection *sec;
  if (auto *isec = dyn_cast<InputSection>(this))
    sec = isec;
  else if (auto *ms = dyn_cast<MergeInputSection>(this))
    sec = ms->getParent();
  else if (auto *eh = dyn_cast<EhInputSection>(this))
    sec = eh->getParent();
  else
    return cast<OutputSection>(this);
  return sec ? sec->getParent() : nullptr;
}

// When a section is compressed, `rawData` consists with a header followed
// by zlib-compressed data. This function parses a header to initialize
// `uncompressedSize` member and remove the header from `rawData`.
void InputSectionBase::parseCompressedHeader() {
  using Chdr64 = typename ELF64LE::Chdr;
  using Chdr32 = typename ELF32LE::Chdr;

  // Old-style header
  if (name.startswith(".zdebug")) {
    if (!toStringRef(rawData).startswith("ZLIB")) {
      error(toString(this) + ": corrupted compressed section header");
      return;
    }
    rawData = rawData.slice(4);

    if (rawData.size() < 8) {
      error(toString(this) + ": corrupted compressed section header");
      return;
    }

    uncompressedSize = read64be(rawData.data());
    rawData = rawData.slice(8);

    // Restore the original section name.
    // (e.g. ".zdebug_info" -> ".debug_info")
    name = saver.save("." + name.substr(2));
    return;
  }

  assert(flags & SHF_COMPRESSED);
  flags &= ~(uint64_t)SHF_COMPRESSED;

  // New-style 64-bit header
  if (config->is64) {
    if (rawData.size() < sizeof(Chdr64)) {
      error(toString(this) + ": corrupted compressed section");
      return;
    }

    auto *hdr = reinterpret_cast<const Chdr64 *>(rawData.data());
    if (hdr->ch_type != ELFCOMPRESS_ZLIB) {
      error(toString(this) + ": unsupported compression type");
      return;
    }

    uncompressedSize = hdr->ch_size;
    alignment = std::max<uint32_t>(hdr->ch_addralign, 1);
    rawData = rawData.slice(sizeof(*hdr));
    return;
  }

  // New-style 32-bit header
  if (rawData.size() < sizeof(Chdr32)) {
    error(toString(this) + ": corrupted compressed section");
    return;
  }

  auto *hdr = reinterpret_cast<const Chdr32 *>(rawData.data());
  if (hdr->ch_type != ELFCOMPRESS_ZLIB) {
    error(toString(this) + ": unsupported compression type");
    return;
  }

  uncompressedSize = hdr->ch_size;
  alignment = std::max<uint32_t>(hdr->ch_addralign, 1);
  rawData = rawData.slice(sizeof(*hdr));
}

InputSection *InputSectionBase::getLinkOrderDep() const {
  assert(link);
  assert(flags & SHF_LINK_ORDER);
  return cast<InputSection>(file->getSections()[link]);
}

// Find a function symbol that encloses a given location.
template <class ELFT>
Defined *InputSectionBase::getEnclosingFunction(uint64_t offset) {
  for (Symbol *b : file->getSymbols())
    if (Defined *d = dyn_cast<Defined>(b))
      if (d->section == this && d->type == STT_FUNC && d->value <= offset &&
          offset < d->value + d->size)
        return d;
  return nullptr;
}

// Returns a source location string. Used to construct an error message.
template <class ELFT>
std::string InputSectionBase::getLocation(uint64_t offset) {
  std::string secAndOffset = (name + "+0x" + utohexstr(offset)).str();

  // We don't have file for synthetic sections.
  if (getFile<ELFT>() == nullptr)
    return (config->outputFile + ":(" + secAndOffset + ")")
        .str();

  // First check if we can get desired values from debugging information.
  if (Optional<DILineInfo> info = getFile<ELFT>()->getDILineInfo(this, offset))
    return info->FileName + ":" + std::to_string(info->Line) + ":(" +
           secAndOffset + ")";

  // File->sourceFile contains STT_FILE symbol that contains a
  // source file name. If it's missing, we use an object file name.
  std::string srcFile = getFile<ELFT>()->sourceFile;
  if (srcFile.empty())
    srcFile = toString(file);

  if (Defined *d = getEnclosingFunction<ELFT>(offset))
    return srcFile + ":(function " + toString(*d) + ": " + secAndOffset + ")";

  // If there's no symbol, print out the offset in the section.
  return (srcFile + ":(" + secAndOffset + ")");
}

// This function is intended to be used for constructing an error message.
// The returned message looks like this:
//
//   foo.c:42 (/home/alice/possibly/very/long/path/foo.c:42)
//
//  Returns an empty string if there's no way to get line info.
std::string InputSectionBase::getSrcMsg(const Symbol &sym, uint64_t offset) {
  return file->getSrcMsg(sym, *this, offset);
}

// Returns a filename string along with an optional section name. This
// function is intended to be used for constructing an error
// message. The returned message looks like this:
//
//   path/to/foo.o:(function bar)
//
// or
//
//   path/to/foo.o:(function bar) in archive path/to/bar.a
std::string InputSectionBase::getObjMsg(uint64_t off) {
  std::string filename = file->getName();

  std::string archive;
  if (!file->archiveName.empty())
    archive = " in archive " + file->archiveName;

  // Find a symbol that encloses a given location.
  for (Symbol *b : file->getSymbols())
    if (auto *d = dyn_cast<Defined>(b))
      if (d->section == this && d->value <= off && off < d->value + d->size)
        return filename + ":(" + toString(*d) + ")" + archive;

  // If there's no symbol, print out the offset in the section.
  return (filename + ":(" + name + "+0x" + utohexstr(off) + ")" + archive)
      .str();
}

InputSection InputSection::discarded(nullptr, 0, 0, 0, ArrayRef<uint8_t>(), "");

InputSection::InputSection(InputFile *f, uint64_t flags, uint32_t type,
                           uint32_t alignment, ArrayRef<uint8_t> data,
                           StringRef name, Kind k)
    : InputSectionBase(f, flags, type,
                       /*Entsize*/ 0, /*Link*/ 0, /*Info*/ 0, alignment, data,
                       name, k) {}

template <class ELFT>
InputSection::InputSection(ObjFile<ELFT> &f, const typename ELFT::Shdr &header,
                           StringRef name)
    : InputSectionBase(f, header, name, InputSectionBase::Regular) {}

bool InputSection::classof(const SectionBase *s) {
  return s->kind() == SectionBase::Regular ||
         s->kind() == SectionBase::Synthetic;
}

OutputSection *InputSection::getParent() const {
  return cast_or_null<OutputSection>(parent);
}

// Copy SHT_GROUP section contents. Used only for the -r option.
template <class ELFT> void InputSection::copyShtGroup(uint8_t *buf) {
  // ELFT::Word is the 32-bit integral type in the target endianness.
  using u32 = typename ELFT::Word;
  ArrayRef<u32> from = getDataAs<u32>();
  auto *to = reinterpret_cast<u32 *>(buf);

  // The first entry is not a section number but a flag.
  *to++ = from[0];

  // Adjust section numbers because section numbers in an input object
  // files are different in the output.
  ArrayRef<InputSectionBase *> sections = file->getSections();
  for (uint32_t idx : from.slice(1))
    *to++ = sections[idx]->getOutputSection()->sectionIndex;
}

InputSectionBase *InputSection::getRelocatedSection() const {
  if (!file || (type != SHT_RELA && type != SHT_REL))
    return nullptr;
  ArrayRef<InputSectionBase *> sections = file->getSections();
  return sections[info];
}

// This is used for -r and --emit-relocs. We can't use memcpy to copy
// relocations because we need to update symbol table offset and section index
// for each relocation. So we copy relocations one by one.
template <class ELFT, class RelTy>
void InputSection::copyRelocations(uint8_t *buf, ArrayRef<RelTy> rels) {
  InputSectionBase *sec = getRelocatedSection();

  for (const RelTy &rel : rels) {
    RelType type = rel.getType(config->isMips64EL);
    const ObjFile<ELFT> *file = getFile<ELFT>();
    Symbol &sym = file->getRelocTargetSym(rel);

    auto *p = reinterpret_cast<typename ELFT::Rela *>(buf);
    buf += sizeof(RelTy);

    if (RelTy::IsRela)
      p->r_addend = getAddend<ELFT>(rel);

    // Output section VA is zero for -r, so r_offset is an offset within the
    // section, but for --emit-relocs it is an virtual address.
    p->r_offset = sec->getVA(rel.r_offset);
    p->setSymbolAndType(in.symTab->getSymbolIndex(&sym), type,
                        config->isMips64EL);

    if (sym.type == STT_SECTION) {
      // We combine multiple section symbols into only one per
      // section. This means we have to update the addend. That is
      // trivial for Elf_Rela, but for Elf_Rel we have to write to the
      // section data. We do that by adding to the Relocation vector.

      // .eh_frame is horribly special and can reference discarded sections. To
      // avoid having to parse and recreate .eh_frame, we just replace any
      // relocation in it pointing to discarded sections with R_*_NONE, which
      // hopefully creates a frame that is ignored at runtime. Also, don't warn
      // on .gcc_except_table and debug sections.
      //
      // See the comment in maybeReportUndefined for PPC64 .toc .
      auto *d = dyn_cast<Defined>(&sym);
      if (!d) {
        if (!sec->name.startswith(".debug") &&
            !sec->name.startswith(".zdebug") && sec->name != ".eh_frame" &&
            sec->name != ".gcc_except_table" && sec->name != ".toc") {
          uint32_t secIdx = cast<Undefined>(sym).discardedSecIdx;
          Elf_Shdr_Impl<ELFT> sec =
              CHECK(file->getObj().sections(), file)[secIdx];
          warn("relocation refers to a discarded section: " +
               CHECK(file->getObj().getSectionName(&sec), file) +
               "\n>>> referenced by " + getObjMsg(p->r_offset));
        }
        p->setSymbolAndType(0, 0, false);
        continue;
      }
      SectionBase *section = d->section->repl;
      if (!section->isLive()) {
        p->setSymbolAndType(0, 0, false);
        continue;
      }

      int64_t addend = getAddend<ELFT>(rel);
      const uint8_t *bufLoc = sec->data().begin() + rel.r_offset;
      if (!RelTy::IsRela)
        addend = target->getImplicitAddend(bufLoc, type);

      if (config->emachine == EM_MIPS && config->relocatable &&
          target->getRelExpr(type, sym, bufLoc) == R_MIPS_GOTREL) {
        // Some MIPS relocations depend on "gp" value. By default,
        // this value has 0x7ff0 offset from a .got section. But
        // relocatable files produced by a complier or a linker
        // might redefine this default value and we must use it
        // for a calculation of the relocation result. When we
        // generate EXE or DSO it's trivial. Generating a relocatable
        // output is more difficult case because the linker does
        // not calculate relocations in this mode and loses
        // individual "gp" values used by each input object file.
        // As a workaround we add the "gp" value to the relocation
        // addend and save it back to the file.
        addend += sec->getFile<ELFT>()->mipsGp0;
      }

      if (RelTy::IsRela)
        p->r_addend = sym.getVA(addend) - section->getOutputSection()->addr;
      else if (config->relocatable && type != target->noneRel)
        sec->relocations.push_back({R_ABS, type, rel.r_offset, addend, &sym});
    }
  }
}

// The ARM and AArch64 ABI handle pc-relative relocations to undefined weak
// references specially. The general rule is that the value of the symbol in
// this context is the address of the place P. A further special case is that
// branch relocations to an undefined weak reference resolve to the next
// instruction.
static uint32_t getARMUndefinedRelativeWeakVA(RelType type, uint32_t a,
                                              uint32_t p) {
  switch (type) {
  // Unresolved branch relocations to weak references resolve to next
  // instruction, this will be either 2 or 4 bytes on from P.
  case R_ARM_THM_JUMP11:
    return p + 2 + a;
  case R_ARM_CALL:
  case R_ARM_JUMP24:
  case R_ARM_PC24:
  case R_ARM_PLT32:
  case R_ARM_PREL31:
  case R_ARM_THM_JUMP19:
  case R_ARM_THM_JUMP24:
    return p + 4 + a;
  case R_ARM_THM_CALL:
    // We don't want an interworking BLX to ARM
    return p + 5 + a;
  // Unresolved non branch pc-relative relocations
  // R_ARM_TARGET2 which can be resolved relatively is not present as it never
  // targets a weak-reference.
  case R_ARM_MOVW_PREL_NC:
  case R_ARM_MOVT_PREL:
  case R_ARM_REL32:
  case R_ARM_THM_MOVW_PREL_NC:
  case R_ARM_THM_MOVT_PREL:
    return p + a;
  }
  llvm_unreachable("ARM pc-relative relocation expected\n");
}

// The comment above getARMUndefinedRelativeWeakVA applies to this function.
static uint64_t getAArch64UndefinedRelativeWeakVA(uint64_t type, uint64_t a,
                                                  uint64_t p) {
  switch (type) {
  // Unresolved branch relocations to weak references resolve to next
  // instruction, this is 4 bytes on from P.
  case R_AARCH64_CALL26:
  case R_AARCH64_CONDBR19:
  case R_AARCH64_JUMP26:
  case R_AARCH64_TSTBR14:
    return p + 4 + a;
  // Unresolved non branch pc-relative relocations
  case R_AARCH64_PREL16:
  case R_AARCH64_PREL32:
  case R_AARCH64_PREL64:
  case R_AARCH64_ADR_PREL_LO21:
  case R_AARCH64_LD_PREL_LO19:
    return p + a;
  }
  llvm_unreachable("AArch64 pc-relative relocation expected\n");
}

// ARM SBREL relocations are of the form S + A - B where B is the static base
// The ARM ABI defines base to be "addressing origin of the output segment
// defining the symbol S". We defined the "addressing origin"/static base to be
// the base of the PT_LOAD segment containing the Sym.
// The procedure call standard only defines a Read Write Position Independent
// RWPI variant so in practice we should expect the static base to be the base
// of the RW segment.
static uint64_t getARMStaticBase(const Symbol &sym) {
  OutputSection *os = sym.getOutputSection();
  if (!os || !os->ptLoad || !os->ptLoad->firstSec)
    fatal("SBREL relocation to " + sym.getName() + " without static base");
  return os->ptLoad->firstSec->addr;
}

// For R_RISCV_PC_INDIRECT (R_RISCV_PCREL_LO12_{I,S}), the symbol actually
// points the corresponding R_RISCV_PCREL_HI20 relocation, and the target VA
// is calculated using PCREL_HI20's symbol.
//
// This function returns the R_RISCV_PCREL_HI20 relocation from
// R_RISCV_PCREL_LO12's symbol and addend.
static Relocation *getRISCVPCRelHi20(const Symbol *sym, uint64_t addend) {
  const Defined *d = cast<Defined>(sym);
  if (!d->section) {
    error("R_RISCV_PCREL_LO12 relocation points to an absolute symbol: " +
          sym->getName());
    return nullptr;
  }
  InputSection *isec = cast<InputSection>(d->section);

  if (addend != 0)
    warn("Non-zero addend in R_RISCV_PCREL_LO12 relocation to " +
         isec->getObjMsg(d->value) + " is ignored");

  // Relocations are sorted by offset, so we can use std::equal_range to do
  // binary search.
  Relocation r;
  r.offset = d->value;
  auto range =
      std::equal_range(isec->relocations.begin(), isec->relocations.end(), r,
                       [](const Relocation &lhs, const Relocation &rhs) {
                         return lhs.offset < rhs.offset;
                       });

  for (auto it = range.first; it != range.second; ++it)
    if (it->type == R_RISCV_PCREL_HI20 || it->type == R_RISCV_GOT_HI20 ||
        it->type == R_RISCV_TLS_GD_HI20 || it->type == R_RISCV_TLS_GOT_HI20)
      return &*it;

  error("R_RISCV_PCREL_LO12 relocation points to " + isec->getObjMsg(d->value) +
        " without an associated R_RISCV_PCREL_HI20 relocation");
  return nullptr;
}

// A TLS symbol's virtual address is relative to the TLS segment. Add a
// target-specific adjustment to produce a thread-pointer-relative offset.
static int64_t getTlsTpOffset(const Symbol &s) {
  // On targets that support TLSDESC, _TLS_MODULE_BASE_@tpoff = 0.
  if (&s == ElfSym::tlsModuleBase)
    return 0;

  switch (config->emachine) {
  case EM_ARM:
  case EM_AARCH64:
    // Variant 1. The thread pointer points to a TCB with a fixed 2-word size,
    // followed by a variable amount of alignment padding, followed by the TLS
    // segment.
    return s.getVA(0) + alignTo(config->wordsize * 2, Out::tlsPhdr->p_align);
  case EM_386:
  case EM_X86_64:
    // Variant 2. The TLS segment is located just before the thread pointer.
    return s.getVA(0) - alignTo(Out::tlsPhdr->p_memsz, Out::tlsPhdr->p_align);
  case EM_PPC:
  case EM_PPC64:
    // The thread pointer points to a fixed offset from the start of the
    // executable's TLS segment. An offset of 0x7000 allows a signed 16-bit
    // offset to reach 0x1000 of TCB/thread-library data and 0xf000 of the
    // program's TLS segment.
    return s.getVA(0) - 0x7000;
  case EM_RISCV:
    return s.getVA(0);
  default:
    llvm_unreachable("unhandled Config->EMachine");
  }
}

static uint64_t getRelocTargetVA(const InputFile *file, RelType type, int64_t a,
                                 uint64_t p, const Symbol &sym, RelExpr expr) {
  switch (expr) {
  case R_ABS:
  case R_DTPREL:
  case R_RELAX_TLS_LD_TO_LE_ABS:
  case R_RELAX_GOT_PC_NOPIC:
  case R_RISCV_ADD:
    return sym.getVA(a);
  case R_ADDEND:
    return a;
  case R_ARM_SBREL:
    return sym.getVA(a) - getARMStaticBase(sym);
  case R_GOT:
  case R_RELAX_TLS_GD_TO_IE_ABS:
    return sym.getGotVA() + a;
  case R_GOTONLY_PC:
    return in.got->getVA() + a - p;
  case R_GOTPLTONLY_PC:
    return in.gotPlt->getVA() + a - p;
  case R_GOTREL:
  case R_PPC64_RELAX_TOC:
    return sym.getVA(a) - in.got->getVA();
  case R_GOTPLTREL:
    return sym.getVA(a) - in.gotPlt->getVA();
  case R_GOTPLT:
  case R_RELAX_TLS_GD_TO_IE_GOTPLT:
    return sym.getGotVA() + a - in.gotPlt->getVA();
  case R_TLSLD_GOT_OFF:
  case R_GOT_OFF:
  case R_RELAX_TLS_GD_TO_IE_GOT_OFF:
    return sym.getGotOffset() + a;
  case R_AARCH64_GOT_PAGE_PC:
  case R_AARCH64_RELAX_TLS_GD_TO_IE_PAGE_PC:
    return getAArch64Page(sym.getGotVA() + a) - getAArch64Page(p);
  case R_GOT_PC:
  case R_RELAX_TLS_GD_TO_IE:
    return sym.getGotVA() + a - p;
  case R_HEXAGON_GOT:
    return sym.getGotVA() - in.gotPlt->getVA();
  case R_MIPS_GOTREL:
    return sym.getVA(a) - in.mipsGot->getGp(file);
  case R_MIPS_GOT_GP:
    return in.mipsGot->getGp(file) + a;
  case R_MIPS_GOT_GP_PC: {
    // R_MIPS_LO16 expression has R_MIPS_GOT_GP_PC type iif the target
    // is _gp_disp symbol. In that case we should use the following
    // formula for calculation "AHL + GP - P + 4". For details see p. 4-19 at
    // ftp://www.linux-mips.org/pub/linux/mips/doc/ABI/mipsabi.pdf
    // microMIPS variants of these relocations use slightly different
    // expressions: AHL + GP - P + 3 for %lo() and AHL + GP - P - 1 for %hi()
    // to correctly handle less-sugnificant bit of the microMIPS symbol.
    uint64_t v = in.mipsGot->getGp(file) + a - p;
    if (type == R_MIPS_LO16 || type == R_MICROMIPS_LO16)
      v += 4;
    if (type == R_MICROMIPS_LO16 || type == R_MICROMIPS_HI16)
      v -= 1;
    return v;
  }
  case R_MIPS_GOT_LOCAL_PAGE:
    // If relocation against MIPS local symbol requires GOT entry, this entry
    // should be initialized by 'page address'. This address is high 16-bits
    // of sum the symbol's value and the addend.
    return in.mipsGot->getVA() + in.mipsGot->getPageEntryOffset(file, sym, a) -
           in.mipsGot->getGp(file);
  case R_MIPS_GOT_OFF:
  case R_MIPS_GOT_OFF32:
    // In case of MIPS if a GOT relocation has non-zero addend this addend
    // should be applied to the GOT entry content not to the GOT entry offset.
    // That is why we use separate expression type.
    return in.mipsGot->getVA() + in.mipsGot->getSymEntryOffset(file, sym, a) -
           in.mipsGot->getGp(file);
  case R_MIPS_TLSGD:
    return in.mipsGot->getVA() + in.mipsGot->getGlobalDynOffset(file, sym) -
           in.mipsGot->getGp(file);
  case R_MIPS_TLSLD:
    return in.mipsGot->getVA() + in.mipsGot->getTlsIndexOffset(file) -
           in.mipsGot->getGp(file);
  case R_AARCH64_PAGE_PC: {
    uint64_t val = sym.isUndefWeak() ? p + a : sym.getVA(a);
    return getAArch64Page(val) - getAArch64Page(p);
  }
  case R_RISCV_PC_INDIRECT: {
    if (const Relocation *hiRel = getRISCVPCRelHi20(&sym, a))
      return getRelocTargetVA(file, hiRel->type, hiRel->addend, sym.getVA(),
                              *hiRel->sym, hiRel->expr);
    return 0;
  }
  case R_PC: {
    uint64_t dest;
    if (sym.isUndefWeak()) {
      // On ARM and AArch64 a branch to an undefined weak resolves to the
      // next instruction, otherwise the place.
      if (config->emachine == EM_ARM)
        dest = getARMUndefinedRelativeWeakVA(type, a, p);
      else if (config->emachine == EM_AARCH64)
        dest = getAArch64UndefinedRelativeWeakVA(type, a, p);
      else if (config->emachine == EM_PPC)
        dest = p;
      else
        dest = sym.getVA(a);
    } else {
      dest = sym.getVA(a);
    }
    return dest - p;
  }
  case R_PLT:
    return sym.getPltVA() + a;
  case R_PLT_PC:
  case R_PPC64_CALL_PLT:
    return sym.getPltVA() + a - p;
  case R_PPC32_PLTREL:
    // R_PPC_PLTREL24 uses the addend (usually 0 or 0x8000) to indicate r30
    // stores _GLOBAL_OFFSET_TABLE_ or .got2+0x8000. The addend is ignored for
    // target VA compuation.
    return sym.getPltVA() - p;
  case R_PPC64_CALL: {
    uint64_t symVA = sym.getVA(a);
    // If we have an undefined weak symbol, we might get here with a symbol
    // address of zero. That could overflow, but the code must be unreachable,
    // so don't bother doing anything at all.
    if (!symVA)
      return 0;

    // PPC64 V2 ABI describes two entry points to a function. The global entry
    // point is used for calls where the caller and callee (may) have different
    // TOC base pointers and r2 needs to be modified to hold the TOC base for
    // the callee. For local calls the caller and callee share the same
    // TOC base and so the TOC pointer initialization code should be skipped by
    // branching to the local entry point.
    return symVA - p + getPPC64GlobalEntryToLocalEntryOffset(sym.stOther);
  }
  case R_PPC64_TOCBASE:
    return getPPC64TocBase() + a;
  case R_RELAX_GOT_PC:
    return sym.getVA(a) - p;
  case R_RELAX_TLS_GD_TO_LE:
  case R_RELAX_TLS_IE_TO_LE:
  case R_RELAX_TLS_LD_TO_LE:
  case R_TLS:
    // It is not very clear what to return if the symbol is undefined. With
    // --noinhibit-exec, even a non-weak undefined reference may reach here.
    // Just return A, which matches R_ABS, and the behavior of some dynamic
    // loaders.
    if (sym.isUndefined())
      return a;
    return getTlsTpOffset(sym) + a;
  case R_RELAX_TLS_GD_TO_LE_NEG:
  case R_NEG_TLS:
    if (sym.isUndefined())
      return a;
    return -getTlsTpOffset(sym) + a;
  case R_SIZE:
    return sym.getSize() + a;
  case R_TLSDESC:
    return in.got->getGlobalDynAddr(sym) + a;
  case R_TLSDESC_PC:
    return in.got->getGlobalDynAddr(sym) + a - p;
  case R_AARCH64_TLSDESC_PAGE:
    return getAArch64Page(in.got->getGlobalDynAddr(sym) + a) -
           getAArch64Page(p);
  case R_TLSGD_GOT:
    return in.got->getGlobalDynOffset(sym) + a;
  case R_TLSGD_GOTPLT:
    return in.got->getVA() + in.got->getGlobalDynOffset(sym) + a - in.gotPlt->getVA();
  case R_TLSGD_PC:
    return in.got->getGlobalDynAddr(sym) + a - p;
  case R_TLSLD_GOTPLT:
    return in.got->getVA() + in.got->getTlsIndexOff() + a - in.gotPlt->getVA();
  case R_TLSLD_GOT:
    return in.got->getTlsIndexOff() + a;
  case R_TLSLD_PC:
    return in.got->getTlsIndexVA() + a - p;
  default:
    llvm_unreachable("invalid expression");
  }
}

// This function applies relocations to sections without SHF_ALLOC bit.
// Such sections are never mapped to memory at runtime. Debug sections are
// an example. Relocations in non-alloc sections are much easier to
// handle than in allocated sections because it will never need complex
// treatement such as GOT or PLT (because at runtime no one refers them).
// So, we handle relocations for non-alloc sections directly in this
// function as a performance optimization.
template <class ELFT, class RelTy>
void InputSection::relocateNonAlloc(uint8_t *buf, ArrayRef<RelTy> rels) {
  const unsigned bits = sizeof(typename ELFT::uint) * 8;

  for (const RelTy &rel : rels) {
    RelType type = rel.getType(config->isMips64EL);

    // GCC 8.0 or earlier have a bug that they emit R_386_GOTPC relocations
    // against _GLOBAL_OFFSET_TABLE_ for .debug_info. The bug has been fixed
    // in 2017 (https://gcc.gnu.org/bugzilla/show_bug.cgi?id=82630), but we
    // need to keep this bug-compatible code for a while.
    if (config->emachine == EM_386 && type == R_386_GOTPC)
      continue;

    uint64_t offset = getOffset(rel.r_offset);
    uint8_t *bufLoc = buf + offset;
    int64_t addend = getAddend<ELFT>(rel);
    if (!RelTy::IsRela)
      addend += target->getImplicitAddend(bufLoc, type);

    Symbol &sym = getFile<ELFT>()->getRelocTargetSym(rel);
    RelExpr expr = target->getRelExpr(type, sym, bufLoc);
    if (expr == R_NONE)
      continue;

    if (expr != R_ABS && expr != R_DTPREL && expr != R_RISCV_ADD) {
      std::string msg = getLocation<ELFT>(offset) +
                        ": has non-ABS relocation " + toString(type) +
                        " against symbol '" + toString(sym) + "'";
      if (expr != R_PC) {
        error(msg);
        return;
      }

      // If the control reaches here, we found a PC-relative relocation in a
      // non-ALLOC section. Since non-ALLOC section is not loaded into memory
      // at runtime, the notion of PC-relative doesn't make sense here. So,
      // this is a usage error. However, GNU linkers historically accept such
      // relocations without any errors and relocate them as if they were at
      // address 0. For bug-compatibilty, we accept them with warnings. We
      // know Steel Bank Common Lisp as of 2018 have this bug.
      warn(msg);
      target->relocateOne(bufLoc, type,
                          SignExtend64<bits>(sym.getVA(addend - offset)));
      continue;
    }

    if (sym.isTls() && !Out::tlsPhdr)
      target->relocateOne(bufLoc, type, 0);
    else
      target->relocateOne(bufLoc, type, SignExtend64<bits>(sym.getVA(addend)));
  }
}

// This is used when '-r' is given.
// For REL targets, InputSection::copyRelocations() may store artificial
// relocations aimed to update addends. They are handled in relocateAlloc()
// for allocatable sections, and this function does the same for
// non-allocatable sections, such as sections with debug information.
static void relocateNonAllocForRelocatable(InputSection *sec, uint8_t *buf) {
  const unsigned bits = config->is64 ? 64 : 32;

  for (const Relocation &rel : sec->relocations) {
    // InputSection::copyRelocations() adds only R_ABS relocations.
    assert(rel.expr == R_ABS);
    uint8_t *bufLoc = buf + rel.offset + sec->outSecOff;
    uint64_t targetVA = SignExtend64(rel.sym->getVA(rel.addend), bits);
    target->relocateOne(bufLoc, rel.type, targetVA);
  }
}

template <class ELFT>
void InputSectionBase::relocate(uint8_t *buf, uint8_t *bufEnd) {
  if (flags & SHF_EXECINSTR)
    adjustSplitStackFunctionPrologues<ELFT>(buf, bufEnd);

  if (flags & SHF_ALLOC) {
    relocateAlloc(buf, bufEnd);
    return;
  }

  auto *sec = cast<InputSection>(this);
  if (config->relocatable)
    relocateNonAllocForRelocatable(sec, buf);
  else if (sec->areRelocsRela)
    sec->relocateNonAlloc<ELFT>(buf, sec->template relas<ELFT>());
  else
    sec->relocateNonAlloc<ELFT>(buf, sec->template rels<ELFT>());
}

void InputSectionBase::relocateAlloc(uint8_t *buf, uint8_t *bufEnd) {
  assert(flags & SHF_ALLOC);
  const unsigned bits = config->wordsize * 8;

  for (const Relocation &rel : relocations) {
    uint64_t offset = rel.offset;
    if (auto *sec = dyn_cast<InputSection>(this))
      offset += sec->outSecOff;
    uint8_t *bufLoc = buf + offset;
    RelType type = rel.type;

    uint64_t addrLoc = getOutputSection()->addr + offset;
    RelExpr expr = rel.expr;
    uint64_t targetVA = SignExtend64(
        getRelocTargetVA(file, type, rel.addend, addrLoc, *rel.sym, expr),
        bits);

    switch (expr) {
    case R_RELAX_GOT_PC:
    case R_RELAX_GOT_PC_NOPIC:
      target->relaxGot(bufLoc, type, targetVA);
      break;
    case R_PPC64_RELAX_TOC:
      if (!tryRelaxPPC64TocIndirection(type, rel, bufLoc))
        target->relocateOne(bufLoc, type, targetVA);
      break;
    case R_RELAX_TLS_IE_TO_LE:
      target->relaxTlsIeToLe(bufLoc, type, targetVA);
      break;
    case R_RELAX_TLS_LD_TO_LE:
    case R_RELAX_TLS_LD_TO_LE_ABS:
      target->relaxTlsLdToLe(bufLoc, type, targetVA);
      break;
    case R_RELAX_TLS_GD_TO_LE:
    case R_RELAX_TLS_GD_TO_LE_NEG:
      target->relaxTlsGdToLe(bufLoc, type, targetVA);
      break;
    case R_AARCH64_RELAX_TLS_GD_TO_IE_PAGE_PC:
    case R_RELAX_TLS_GD_TO_IE:
    case R_RELAX_TLS_GD_TO_IE_ABS:
    case R_RELAX_TLS_GD_TO_IE_GOT_OFF:
    case R_RELAX_TLS_GD_TO_IE_GOTPLT:
      target->relaxTlsGdToIe(bufLoc, type, targetVA);
      break;
    case R_PPC64_CALL:
      // If this is a call to __tls_get_addr, it may be part of a TLS
      // sequence that has been relaxed and turned into a nop. In this
      // case, we don't want to handle it as a call.
      if (read32(bufLoc) == 0x60000000) // nop
        break;

      // Patch a nop (0x60000000) to a ld.
      if (rel.sym->needsTocRestore) {
        if (bufLoc + 8 > bufEnd || read32(bufLoc + 4) != 0x60000000) {
          error(getErrorLocation(bufLoc) + "call lacks nop, can't restore toc");
          break;
        }
        write32(bufLoc + 4, 0xe8410018); // ld %r2, 24(%r1)
      }
      target->relocateOne(bufLoc, type, targetVA);
      break;
    default:
      target->relocateOne(bufLoc, type, targetVA);
      break;
    }
  }
}

// For each function-defining prologue, find any calls to __morestack,
// and replace them with calls to __morestack_non_split.
static void switchMorestackCallsToMorestackNonSplit(
    DenseSet<Defined *> &prologues, std::vector<Relocation *> &morestackCalls) {

  // If the target adjusted a function's prologue, all calls to
  // __morestack inside that function should be switched to
  // __morestack_non_split.
  Symbol *moreStackNonSplit = symtab->find("__morestack_non_split");
  if (!moreStackNonSplit) {
    error("Mixing split-stack objects requires a definition of "
          "__morestack_non_split");
    return;
  }

  // Sort both collections to compare addresses efficiently.
  llvm::sort(morestackCalls, [](const Relocation *l, const Relocation *r) {
    return l->offset < r->offset;
  });
  std::vector<Defined *> functions(prologues.begin(), prologues.end());
  llvm::sort(functions, [](const Defined *l, const Defined *r) {
    return l->value < r->value;
  });

  auto it = morestackCalls.begin();
  for (Defined *f : functions) {
    // Find the first call to __morestack within the function.
    while (it != morestackCalls.end() && (*it)->offset < f->value)
      ++it;
    // Adjust all calls inside the function.
    while (it != morestackCalls.end() && (*it)->offset < f->value + f->size) {
      (*it)->sym = moreStackNonSplit;
      ++it;
    }
  }
}

static bool enclosingPrologueAttempted(uint64_t offset,
                                       const DenseSet<Defined *> &prologues) {
  for (Defined *f : prologues)
    if (f->value <= offset && offset < f->value + f->size)
      return true;
  return false;
}

// If a function compiled for split stack calls a function not
// compiled for split stack, then the caller needs its prologue
// adjusted to ensure that the called function will have enough stack
// available. Find those functions, and adjust their prologues.
template <class ELFT>
void InputSectionBase::adjustSplitStackFunctionPrologues(uint8_t *buf,
                                                         uint8_t *end) {
  if (!getFile<ELFT>()->splitStack)
    return;
  DenseSet<Defined *> prologues;
  std::vector<Relocation *> morestackCalls;

  for (Relocation &rel : relocations) {
    // Local symbols can't possibly be cross-calls, and should have been
    // resolved long before this line.
    if (rel.sym->isLocal())
      continue;

    // Ignore calls into the split-stack api.
    if (rel.sym->getName().startswith("__morestack")) {
      if (rel.sym->getName().equals("__morestack"))
        morestackCalls.push_back(&rel);
      continue;
    }

    // A relocation to non-function isn't relevant. Sometimes
    // __morestack is not marked as a function, so this check comes
    // after the name check.
    if (rel.sym->type != STT_FUNC)
      continue;

    // If the callee's-file was compiled with split stack, nothing to do.  In
    // this context, a "Defined" symbol is one "defined by the binary currently
    // being produced". So an "undefined" symbol might be provided by a shared
    // library. It is not possible to tell how such symbols were compiled, so be
    // conservative.
    if (Defined *d = dyn_cast<Defined>(rel.sym))
      if (InputSection *isec = cast_or_null<InputSection>(d->section))
        if (!isec || !isec->getFile<ELFT>() || isec->getFile<ELFT>()->splitStack)
          continue;

    if (enclosingPrologueAttempted(rel.offset, prologues))
      continue;

    if (Defined *f = getEnclosingFunction<ELFT>(rel.offset)) {
      prologues.insert(f);
      if (target->adjustPrologueForCrossSplitStack(buf + getOffset(f->value),
                                                   end, f->stOther))
        continue;
      if (!getFile<ELFT>()->someNoSplitStack)
        error(lld::toString(this) + ": " + f->getName() +
              " (with -fsplit-stack) calls " + rel.sym->getName() +
              " (without -fsplit-stack), but couldn't adjust its prologue");
    }
  }

  if (target->needsMoreStackNonSplit)
    switchMorestackCallsToMorestackNonSplit(prologues, morestackCalls);
}

template <class ELFT> void InputSection::writeTo(uint8_t *buf) {
  if (type == SHT_NOBITS)
    return;

  if (auto *s = dyn_cast<SyntheticSection>(this)) {
    s->writeTo(buf + outSecOff);
    return;
  }

  // If -r or --emit-relocs is given, then an InputSection
  // may be a relocation section.
  if (type == SHT_RELA) {
    copyRelocations<ELFT>(buf + outSecOff, getDataAs<typename ELFT::Rela>());
    return;
  }
  if (type == SHT_REL) {
    copyRelocations<ELFT>(buf + outSecOff, getDataAs<typename ELFT::Rel>());
    return;
  }

  // If -r is given, we may have a SHT_GROUP section.
  if (type == SHT_GROUP) {
    copyShtGroup<ELFT>(buf + outSecOff);
    return;
  }

  // If this is a compressed section, uncompress section contents directly
  // to the buffer.
  if (uncompressedSize >= 0) {
    size_t size = uncompressedSize;
    if (Error e = zlib::uncompress(toStringRef(rawData),
                                   (char *)(buf + outSecOff), size))
      fatal(toString(this) +
            ": uncompress failed: " + llvm::toString(std::move(e)));
    uint8_t *bufEnd = buf + outSecOff + size;
    relocate<ELFT>(buf, bufEnd);
    return;
  }

  // Copy section contents from source object file to output file
  // and then apply relocations.
  memcpy(buf + outSecOff, data().data(), data().size());
  uint8_t *bufEnd = buf + outSecOff + data().size();
  relocate<ELFT>(buf, bufEnd);
}

void InputSection::replace(InputSection *other) {
  alignment = std::max(alignment, other->alignment);

  // When a section is replaced with another section that was allocated to
  // another partition, the replacement section (and its associated sections)
  // need to be placed in the main partition so that both partitions will be
  // able to access it.
  if (partition != other->partition) {
    partition = 1;
    for (InputSection *isec : dependentSections)
      isec->partition = 1;
  }

  other->repl = repl;
  other->markDead();
}

template <class ELFT>
EhInputSection::EhInputSection(ObjFile<ELFT> &f,
                               const typename ELFT::Shdr &header,
                               StringRef name)
    : InputSectionBase(f, header, name, InputSectionBase::EHFrame) {}

SyntheticSection *EhInputSection::getParent() const {
  return cast_or_null<SyntheticSection>(parent);
}

// Returns the index of the first relocation that points to a region between
// Begin and Begin+Size.
template <class IntTy, class RelTy>
static unsigned getReloc(IntTy begin, IntTy size, const ArrayRef<RelTy> &rels,
                         unsigned &relocI) {
  // Start search from RelocI for fast access. That works because the
  // relocations are sorted in .eh_frame.
  for (unsigned n = rels.size(); relocI < n; ++relocI) {
    const RelTy &rel = rels[relocI];
    if (rel.r_offset < begin)
      continue;

    if (rel.r_offset < begin + size)
      return relocI;
    return -1;
  }
  return -1;
}

// .eh_frame is a sequence of CIE or FDE records.
// This function splits an input section into records and returns them.
template <class ELFT> void EhInputSection::split() {
  if (areRelocsRela)
    split<ELFT>(relas<ELFT>());
  else
    split<ELFT>(rels<ELFT>());
}

template <class ELFT, class RelTy>
void EhInputSection::split(ArrayRef<RelTy> rels) {
  unsigned relI = 0;
  for (size_t off = 0, end = data().size(); off != end;) {
    size_t size = readEhRecordSize(this, off);
    pieces.emplace_back(off, this, size, getReloc(off, size, rels, relI));
    // The empty record is the end marker.
    if (size == 4)
      break;
    off += size;
  }
}

static size_t findNull(StringRef s, size_t entSize) {
  // Optimize the common case.
  if (entSize == 1)
    return s.find(0);

  for (unsigned i = 0, n = s.size(); i != n; i += entSize) {
    const char *b = s.begin() + i;
    if (std::all_of(b, b + entSize, [](char c) { return c == 0; }))
      return i;
  }
  return StringRef::npos;
}

SyntheticSection *MergeInputSection::getParent() const {
  return cast_or_null<SyntheticSection>(parent);
}

// Split SHF_STRINGS section. Such section is a sequence of
// null-terminated strings.
void MergeInputSection::splitStrings(ArrayRef<uint8_t> data, size_t entSize) {
  size_t off = 0;
  bool isAlloc = flags & SHF_ALLOC;
  StringRef s = toStringRef(data);

  while (!s.empty()) {
    size_t end = findNull(s, entSize);
    if (end == StringRef::npos)
      fatal(toString(this) + ": string is not null terminated");
    size_t size = end + entSize;

    pieces.emplace_back(off, xxHash64(s.substr(0, size)), !isAlloc);
    s = s.substr(size);
    off += size;
  }
}

// Split non-SHF_STRINGS section. Such section is a sequence of
// fixed size records.
void MergeInputSection::splitNonStrings(ArrayRef<uint8_t> data,
                                        size_t entSize) {
  size_t size = data.size();
  assert((size % entSize) == 0);
  bool isAlloc = flags & SHF_ALLOC;

  for (size_t i = 0; i != size; i += entSize)
    pieces.emplace_back(i, xxHash64(data.slice(i, entSize)), !isAlloc);
}

template <class ELFT>
MergeInputSection::MergeInputSection(ObjFile<ELFT> &f,
                                     const typename ELFT::Shdr &header,
                                     StringRef name)
    : InputSectionBase(f, header, name, InputSectionBase::Merge) {}

MergeInputSection::MergeInputSection(uint64_t flags, uint32_t type,
                                     uint64_t entsize, ArrayRef<uint8_t> data,
                                     StringRef name)
    : InputSectionBase(nullptr, flags, type, entsize, /*Link*/ 0, /*Info*/ 0,
                       /*Alignment*/ entsize, data, name, SectionBase::Merge) {}

// This function is called after we obtain a complete list of input sections
// that need to be linked. This is responsible to split section contents
// into small chunks for further processing.
//
// Note that this function is called from parallelForEach. This must be
// thread-safe (i.e. no memory allocation from the pools).
void MergeInputSection::splitIntoPieces() {
  assert(pieces.empty());

  if (flags & SHF_STRINGS)
    splitStrings(data(), entsize);
  else
    splitNonStrings(data(), entsize);
}

SectionPiece *MergeInputSection::getSectionPiece(uint64_t offset) {
  if (this->data().size() <= offset)
    fatal(toString(this) + ": offset is outside the section");

  // If Offset is not at beginning of a section piece, it is not in the map.
  // In that case we need to  do a binary search of the original section piece vector.
  auto it = partition_point(
      pieces, [=](SectionPiece p) { return p.inputOff <= offset; });
  return &it[-1];
}

// Returns the offset in an output section for a given input offset.
// Because contents of a mergeable section is not contiguous in output,
// it is not just an addition to a base output offset.
uint64_t MergeInputSection::getParentOffset(uint64_t offset) const {
  // If Offset is not at beginning of a section piece, it is not in the map.
  // In that case we need to search from the original section piece vector.
  const SectionPiece &piece =
      *(const_cast<MergeInputSection *>(this)->getSectionPiece (offset));
  uint64_t addend = offset - piece.inputOff;
  return piece.outputOff + addend;
}

template InputSection::InputSection(ObjFile<ELF32LE> &, const ELF32LE::Shdr &,
                                    StringRef);
template InputSection::InputSection(ObjFile<ELF32BE> &, const ELF32BE::Shdr &,
                                    StringRef);
template InputSection::InputSection(ObjFile<ELF64LE> &, const ELF64LE::Shdr &,
                                    StringRef);
template InputSection::InputSection(ObjFile<ELF64BE> &, const ELF64BE::Shdr &,
                                    StringRef);

template std::string InputSectionBase::getLocation<ELF32LE>(uint64_t);
template std::string InputSectionBase::getLocation<ELF32BE>(uint64_t);
template std::string InputSectionBase::getLocation<ELF64LE>(uint64_t);
template std::string InputSectionBase::getLocation<ELF64BE>(uint64_t);

template void InputSection::writeTo<ELF32LE>(uint8_t *);
template void InputSection::writeTo<ELF32BE>(uint8_t *);
template void InputSection::writeTo<ELF64LE>(uint8_t *);
template void InputSection::writeTo<ELF64BE>(uint8_t *);

template MergeInputSection::MergeInputSection(ObjFile<ELF32LE> &,
                                              const ELF32LE::Shdr &, StringRef);
template MergeInputSection::MergeInputSection(ObjFile<ELF32BE> &,
                                              const ELF32BE::Shdr &, StringRef);
template MergeInputSection::MergeInputSection(ObjFile<ELF64LE> &,
                                              const ELF64LE::Shdr &, StringRef);
template MergeInputSection::MergeInputSection(ObjFile<ELF64BE> &,
                                              const ELF64BE::Shdr &, StringRef);

template EhInputSection::EhInputSection(ObjFile<ELF32LE> &,
                                        const ELF32LE::Shdr &, StringRef);
template EhInputSection::EhInputSection(ObjFile<ELF32BE> &,
                                        const ELF32BE::Shdr &, StringRef);
template EhInputSection::EhInputSection(ObjFile<ELF64LE> &,
                                        const ELF64LE::Shdr &, StringRef);
template EhInputSection::EhInputSection(ObjFile<ELF64BE> &,
                                        const ELF64BE::Shdr &, StringRef);

template void EhInputSection::split<ELF32LE>();
template void EhInputSection::split<ELF32BE>();
template void EhInputSection::split<ELF64LE>();
template void EhInputSection::split<ELF64BE>();
