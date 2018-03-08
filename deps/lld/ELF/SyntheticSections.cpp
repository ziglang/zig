//===- SyntheticSections.cpp ----------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file contains linker-synthesized sections. Currently,
// synthetic sections are created either output sections or input sections,
// but we are rewriting code so that all synthetic sections are created as
// input sections.
//
//===----------------------------------------------------------------------===//

#include "SyntheticSections.h"
#include "Bits.h"
#include "Config.h"
#include "InputFiles.h"
#include "LinkerScript.h"
#include "OutputSections.h"
#include "Strings.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "Target.h"
#include "Writer.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "lld/Common/Threads.h"
#include "lld/Common/Version.h"
#include "llvm/BinaryFormat/Dwarf.h"
#include "llvm/DebugInfo/DWARF/DWARFDebugPubTable.h"
#include "llvm/Object/Decompressor.h"
#include "llvm/Object/ELFObjectFile.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/LEB128.h"
#include "llvm/Support/MD5.h"
#include "llvm/Support/RandomNumberGenerator.h"
#include "llvm/Support/SHA1.h"
#include "llvm/Support/xxhash.h"
#include <cstdlib>
#include <thread>

using namespace llvm;
using namespace llvm::dwarf;
using namespace llvm::ELF;
using namespace llvm::object;
using namespace llvm::support;
using namespace llvm::support::endian;

using namespace lld;
using namespace lld::elf;

constexpr size_t MergeNoTailSection::NumShards;

static void write32(void *Buf, uint32_t Val) {
  endian::write32(Buf, Val, Config->Endianness);
}

uint64_t SyntheticSection::getVA() const {
  if (OutputSection *Sec = getParent())
    return Sec->Addr + OutSecOff;
  return 0;
}

// Returns an LLD version string.
static ArrayRef<uint8_t> getVersion() {
  // Check LLD_VERSION first for ease of testing.
  // You can get consitent output by using the environment variable.
  // This is only for testing.
  StringRef S = getenv("LLD_VERSION");
  if (S.empty())
    S = Saver.save(Twine("Linker: ") + getLLDVersion());

  // +1 to include the terminating '\0'.
  return {(const uint8_t *)S.data(), S.size() + 1};
}

// Creates a .comment section containing LLD version info.
// With this feature, you can identify LLD-generated binaries easily
// by "readelf --string-dump .comment <file>".
// The returned object is a mergeable string section.
MergeInputSection *elf::createCommentSection() {
  return make<MergeInputSection>(SHF_MERGE | SHF_STRINGS, SHT_PROGBITS, 1,
                                 getVersion(), ".comment");
}

// .MIPS.abiflags section.
template <class ELFT>
MipsAbiFlagsSection<ELFT>::MipsAbiFlagsSection(Elf_Mips_ABIFlags Flags)
    : SyntheticSection(SHF_ALLOC, SHT_MIPS_ABIFLAGS, 8, ".MIPS.abiflags"),
      Flags(Flags) {
  this->Entsize = sizeof(Elf_Mips_ABIFlags);
}

template <class ELFT> void MipsAbiFlagsSection<ELFT>::writeTo(uint8_t *Buf) {
  memcpy(Buf, &Flags, sizeof(Flags));
}

template <class ELFT>
MipsAbiFlagsSection<ELFT> *MipsAbiFlagsSection<ELFT>::create() {
  Elf_Mips_ABIFlags Flags = {};
  bool Create = false;

  for (InputSectionBase *Sec : InputSections) {
    if (Sec->Type != SHT_MIPS_ABIFLAGS)
      continue;
    Sec->Live = false;
    Create = true;

    std::string Filename = toString(Sec->File);
    const size_t Size = Sec->Data.size();
    // Older version of BFD (such as the default FreeBSD linker) concatenate
    // .MIPS.abiflags instead of merging. To allow for this case (or potential
    // zero padding) we ignore everything after the first Elf_Mips_ABIFlags
    if (Size < sizeof(Elf_Mips_ABIFlags)) {
      error(Filename + ": invalid size of .MIPS.abiflags section: got " +
            Twine(Size) + " instead of " + Twine(sizeof(Elf_Mips_ABIFlags)));
      return nullptr;
    }
    auto *S = reinterpret_cast<const Elf_Mips_ABIFlags *>(Sec->Data.data());
    if (S->version != 0) {
      error(Filename + ": unexpected .MIPS.abiflags version " +
            Twine(S->version));
      return nullptr;
    }

    // LLD checks ISA compatibility in calcMipsEFlags(). Here we just
    // select the highest number of ISA/Rev/Ext.
    Flags.isa_level = std::max(Flags.isa_level, S->isa_level);
    Flags.isa_rev = std::max(Flags.isa_rev, S->isa_rev);
    Flags.isa_ext = std::max(Flags.isa_ext, S->isa_ext);
    Flags.gpr_size = std::max(Flags.gpr_size, S->gpr_size);
    Flags.cpr1_size = std::max(Flags.cpr1_size, S->cpr1_size);
    Flags.cpr2_size = std::max(Flags.cpr2_size, S->cpr2_size);
    Flags.ases |= S->ases;
    Flags.flags1 |= S->flags1;
    Flags.flags2 |= S->flags2;
    Flags.fp_abi = elf::getMipsFpAbiFlag(Flags.fp_abi, S->fp_abi, Filename);
  };

  if (Create)
    return make<MipsAbiFlagsSection<ELFT>>(Flags);
  return nullptr;
}

// .MIPS.options section.
template <class ELFT>
MipsOptionsSection<ELFT>::MipsOptionsSection(Elf_Mips_RegInfo Reginfo)
    : SyntheticSection(SHF_ALLOC, SHT_MIPS_OPTIONS, 8, ".MIPS.options"),
      Reginfo(Reginfo) {
  this->Entsize = sizeof(Elf_Mips_Options) + sizeof(Elf_Mips_RegInfo);
}

template <class ELFT> void MipsOptionsSection<ELFT>::writeTo(uint8_t *Buf) {
  auto *Options = reinterpret_cast<Elf_Mips_Options *>(Buf);
  Options->kind = ODK_REGINFO;
  Options->size = getSize();

  if (!Config->Relocatable)
    Reginfo.ri_gp_value = InX::MipsGot->getGp();
  memcpy(Buf + sizeof(Elf_Mips_Options), &Reginfo, sizeof(Reginfo));
}

template <class ELFT>
MipsOptionsSection<ELFT> *MipsOptionsSection<ELFT>::create() {
  // N64 ABI only.
  if (!ELFT::Is64Bits)
    return nullptr;

  std::vector<InputSectionBase *> Sections;
  for (InputSectionBase *Sec : InputSections)
    if (Sec->Type == SHT_MIPS_OPTIONS)
      Sections.push_back(Sec);

  if (Sections.empty())
    return nullptr;

  Elf_Mips_RegInfo Reginfo = {};
  for (InputSectionBase *Sec : Sections) {
    Sec->Live = false;

    std::string Filename = toString(Sec->File);
    ArrayRef<uint8_t> D = Sec->Data;

    while (!D.empty()) {
      if (D.size() < sizeof(Elf_Mips_Options)) {
        error(Filename + ": invalid size of .MIPS.options section");
        break;
      }

      auto *Opt = reinterpret_cast<const Elf_Mips_Options *>(D.data());
      if (Opt->kind == ODK_REGINFO) {
        if (Config->Relocatable && Opt->getRegInfo().ri_gp_value)
          error(Filename + ": unsupported non-zero ri_gp_value");
        Reginfo.ri_gprmask |= Opt->getRegInfo().ri_gprmask;
        Sec->getFile<ELFT>()->MipsGp0 = Opt->getRegInfo().ri_gp_value;
        break;
      }

      if (!Opt->size)
        fatal(Filename + ": zero option descriptor size");
      D = D.slice(Opt->size);
    }
  };

  return make<MipsOptionsSection<ELFT>>(Reginfo);
}

// MIPS .reginfo section.
template <class ELFT>
MipsReginfoSection<ELFT>::MipsReginfoSection(Elf_Mips_RegInfo Reginfo)
    : SyntheticSection(SHF_ALLOC, SHT_MIPS_REGINFO, 4, ".reginfo"),
      Reginfo(Reginfo) {
  this->Entsize = sizeof(Elf_Mips_RegInfo);
}

template <class ELFT> void MipsReginfoSection<ELFT>::writeTo(uint8_t *Buf) {
  if (!Config->Relocatable)
    Reginfo.ri_gp_value = InX::MipsGot->getGp();
  memcpy(Buf, &Reginfo, sizeof(Reginfo));
}

template <class ELFT>
MipsReginfoSection<ELFT> *MipsReginfoSection<ELFT>::create() {
  // Section should be alive for O32 and N32 ABIs only.
  if (ELFT::Is64Bits)
    return nullptr;

  std::vector<InputSectionBase *> Sections;
  for (InputSectionBase *Sec : InputSections)
    if (Sec->Type == SHT_MIPS_REGINFO)
      Sections.push_back(Sec);

  if (Sections.empty())
    return nullptr;

  Elf_Mips_RegInfo Reginfo = {};
  for (InputSectionBase *Sec : Sections) {
    Sec->Live = false;

    if (Sec->Data.size() != sizeof(Elf_Mips_RegInfo)) {
      error(toString(Sec->File) + ": invalid size of .reginfo section");
      return nullptr;
    }
    auto *R = reinterpret_cast<const Elf_Mips_RegInfo *>(Sec->Data.data());
    if (Config->Relocatable && R->ri_gp_value)
      error(toString(Sec->File) + ": unsupported non-zero ri_gp_value");

    Reginfo.ri_gprmask |= R->ri_gprmask;
    Sec->getFile<ELFT>()->MipsGp0 = R->ri_gp_value;
  };

  return make<MipsReginfoSection<ELFT>>(Reginfo);
}

InputSection *elf::createInterpSection() {
  // StringSaver guarantees that the returned string ends with '\0'.
  StringRef S = Saver.save(Config->DynamicLinker);
  ArrayRef<uint8_t> Contents = {(const uint8_t *)S.data(), S.size() + 1};

  auto *Sec = make<InputSection>(nullptr, SHF_ALLOC, SHT_PROGBITS, 1, Contents,
                                 ".interp");
  Sec->Live = true;
  return Sec;
}

Symbol *elf::addSyntheticLocal(StringRef Name, uint8_t Type, uint64_t Value,
                               uint64_t Size, InputSectionBase &Section) {
  auto *S = make<Defined>(Section.File, Name, STB_LOCAL, STV_DEFAULT, Type,
                          Value, Size, &Section);
  if (InX::SymTab)
    InX::SymTab->addSymbol(S);
  return S;
}

static size_t getHashSize() {
  switch (Config->BuildId) {
  case BuildIdKind::Fast:
    return 8;
  case BuildIdKind::Md5:
  case BuildIdKind::Uuid:
    return 16;
  case BuildIdKind::Sha1:
    return 20;
  case BuildIdKind::Hexstring:
    return Config->BuildIdVector.size();
  default:
    llvm_unreachable("unknown BuildIdKind");
  }
}

BuildIdSection::BuildIdSection()
    : SyntheticSection(SHF_ALLOC, SHT_NOTE, 4, ".note.gnu.build-id"),
      HashSize(getHashSize()) {}

void BuildIdSection::writeTo(uint8_t *Buf) {
  write32(Buf, 4);                      // Name size
  write32(Buf + 4, HashSize);           // Content size
  write32(Buf + 8, NT_GNU_BUILD_ID);    // Type
  memcpy(Buf + 12, "GNU", 4);           // Name string
  HashBuf = Buf + 16;
}

// Split one uint8 array into small pieces of uint8 arrays.
static std::vector<ArrayRef<uint8_t>> split(ArrayRef<uint8_t> Arr,
                                            size_t ChunkSize) {
  std::vector<ArrayRef<uint8_t>> Ret;
  while (Arr.size() > ChunkSize) {
    Ret.push_back(Arr.take_front(ChunkSize));
    Arr = Arr.drop_front(ChunkSize);
  }
  if (!Arr.empty())
    Ret.push_back(Arr);
  return Ret;
}

// Computes a hash value of Data using a given hash function.
// In order to utilize multiple cores, we first split data into 1MB
// chunks, compute a hash for each chunk, and then compute a hash value
// of the hash values.
void BuildIdSection::computeHash(
    llvm::ArrayRef<uint8_t> Data,
    std::function<void(uint8_t *Dest, ArrayRef<uint8_t> Arr)> HashFn) {
  std::vector<ArrayRef<uint8_t>> Chunks = split(Data, 1024 * 1024);
  std::vector<uint8_t> Hashes(Chunks.size() * HashSize);

  // Compute hash values.
  parallelForEachN(0, Chunks.size(), [&](size_t I) {
    HashFn(Hashes.data() + I * HashSize, Chunks[I]);
  });

  // Write to the final output buffer.
  HashFn(HashBuf, Hashes);
}

BssSection::BssSection(StringRef Name, uint64_t Size, uint32_t Alignment)
    : SyntheticSection(SHF_ALLOC | SHF_WRITE, SHT_NOBITS, Alignment, Name) {
  this->Bss = true;
  if (OutputSection *Sec = getParent())
    Sec->Alignment = std::max(Sec->Alignment, Alignment);
  this->Size = Size;
}

void BuildIdSection::writeBuildId(ArrayRef<uint8_t> Buf) {
  switch (Config->BuildId) {
  case BuildIdKind::Fast:
    computeHash(Buf, [](uint8_t *Dest, ArrayRef<uint8_t> Arr) {
      write64le(Dest, xxHash64(toStringRef(Arr)));
    });
    break;
  case BuildIdKind::Md5:
    computeHash(Buf, [](uint8_t *Dest, ArrayRef<uint8_t> Arr) {
      memcpy(Dest, MD5::hash(Arr).data(), 16);
    });
    break;
  case BuildIdKind::Sha1:
    computeHash(Buf, [](uint8_t *Dest, ArrayRef<uint8_t> Arr) {
      memcpy(Dest, SHA1::hash(Arr).data(), 20);
    });
    break;
  case BuildIdKind::Uuid:
    if (auto EC = getRandomBytes(HashBuf, HashSize))
      error("entropy source failure: " + EC.message());
    break;
  case BuildIdKind::Hexstring:
    memcpy(HashBuf, Config->BuildIdVector.data(), Config->BuildIdVector.size());
    break;
  default:
    llvm_unreachable("unknown BuildIdKind");
  }
}

EhFrameSection::EhFrameSection()
    : SyntheticSection(SHF_ALLOC, SHT_PROGBITS, 1, ".eh_frame") {}

// Search for an existing CIE record or create a new one.
// CIE records from input object files are uniquified by their contents
// and where their relocations point to.
template <class ELFT, class RelTy>
CieRecord *EhFrameSection::addCie(EhSectionPiece &Cie, ArrayRef<RelTy> Rels) {
  auto *Sec = cast<EhInputSection>(Cie.Sec);
  if (read32(Cie.data().data() + 4, Config->Endianness) != 0)
    fatal(toString(Sec) + ": CIE expected at beginning of .eh_frame");

  Symbol *Personality = nullptr;
  unsigned FirstRelI = Cie.FirstRelocation;
  if (FirstRelI != (unsigned)-1)
    Personality =
        &Sec->template getFile<ELFT>()->getRelocTargetSym(Rels[FirstRelI]);

  // Search for an existing CIE by CIE contents/relocation target pair.
  CieRecord *&Rec = CieMap[{Cie.data(), Personality}];

  // If not found, create a new one.
  if (!Rec) {
    Rec = make<CieRecord>();
    Rec->Cie = &Cie;
    CieRecords.push_back(Rec);
  }
  return Rec;
}

// There is one FDE per function. Returns true if a given FDE
// points to a live function.
template <class ELFT, class RelTy>
bool EhFrameSection::isFdeLive(EhSectionPiece &Fde, ArrayRef<RelTy> Rels) {
  auto *Sec = cast<EhInputSection>(Fde.Sec);
  unsigned FirstRelI = Fde.FirstRelocation;

  // An FDE should point to some function because FDEs are to describe
  // functions. That's however not always the case due to an issue of
  // ld.gold with -r. ld.gold may discard only functions and leave their
  // corresponding FDEs, which results in creating bad .eh_frame sections.
  // To deal with that, we ignore such FDEs.
  if (FirstRelI == (unsigned)-1)
    return false;

  const RelTy &Rel = Rels[FirstRelI];
  Symbol &B = Sec->template getFile<ELFT>()->getRelocTargetSym(Rel);

  // FDEs for garbage-collected or merged-by-ICF sections are dead.
  if (auto *D = dyn_cast<Defined>(&B))
    if (SectionBase *Sec = D->Section)
      return Sec->Live;
  return false;
}

// .eh_frame is a sequence of CIE or FDE records. In general, there
// is one CIE record per input object file which is followed by
// a list of FDEs. This function searches an existing CIE or create a new
// one and associates FDEs to the CIE.
template <class ELFT, class RelTy>
void EhFrameSection::addSectionAux(EhInputSection *Sec, ArrayRef<RelTy> Rels) {
  DenseMap<size_t, CieRecord *> OffsetToCie;
  for (EhSectionPiece &Piece : Sec->Pieces) {
    // The empty record is the end marker.
    if (Piece.Size == 4)
      return;

    size_t Offset = Piece.InputOff;
    uint32_t ID = read32(Piece.data().data() + 4, Config->Endianness);
    if (ID == 0) {
      OffsetToCie[Offset] = addCie<ELFT>(Piece, Rels);
      continue;
    }

    uint32_t CieOffset = Offset + 4 - ID;
    CieRecord *Rec = OffsetToCie[CieOffset];
    if (!Rec)
      fatal(toString(Sec) + ": invalid CIE reference");

    if (!isFdeLive<ELFT>(Piece, Rels))
      continue;
    Rec->Fdes.push_back(&Piece);
    NumFdes++;
  }
}

template <class ELFT> void EhFrameSection::addSection(InputSectionBase *C) {
  auto *Sec = cast<EhInputSection>(C);
  Sec->Parent = this;

  Alignment = std::max(Alignment, Sec->Alignment);
  Sections.push_back(Sec);

  for (auto *DS : Sec->DependentSections)
    DependentSections.push_back(DS);

  // .eh_frame is a sequence of CIE or FDE records. This function
  // splits it into pieces so that we can call
  // SplitInputSection::getSectionPiece on the section.
  Sec->split<ELFT>();
  if (Sec->Pieces.empty())
    return;

  if (Sec->AreRelocsRela)
    addSectionAux<ELFT>(Sec, Sec->template relas<ELFT>());
  else
    addSectionAux<ELFT>(Sec, Sec->template rels<ELFT>());
}

static void writeCieFde(uint8_t *Buf, ArrayRef<uint8_t> D) {
  memcpy(Buf, D.data(), D.size());

  size_t Aligned = alignTo(D.size(), Config->Wordsize);

  // Zero-clear trailing padding if it exists.
  memset(Buf + D.size(), 0, Aligned - D.size());

  // Fix the size field. -4 since size does not include the size field itself.
  write32(Buf, Aligned - 4);
}

void EhFrameSection::finalizeContents() {
  if (this->Size)
    return; // Already finalized.

  size_t Off = 0;
  for (CieRecord *Rec : CieRecords) {
    Rec->Cie->OutputOff = Off;
    Off += alignTo(Rec->Cie->Size, Config->Wordsize);

    for (EhSectionPiece *Fde : Rec->Fdes) {
      Fde->OutputOff = Off;
      Off += alignTo(Fde->Size, Config->Wordsize);
    }
  }

  // The LSB standard does not allow a .eh_frame section with zero
  // Call Frame Information records. Therefore add a CIE record length
  // 0 as a terminator if this .eh_frame section is empty.
  if (Off == 0)
    Off = 4;

  this->Size = Off;
}

// Returns data for .eh_frame_hdr. .eh_frame_hdr is a binary search table
// to get an FDE from an address to which FDE is applied. This function
// returns a list of such pairs.
std::vector<EhFrameSection::FdeData> EhFrameSection::getFdeData() const {
  uint8_t *Buf = getParent()->Loc + OutSecOff;
  std::vector<FdeData> Ret;

  for (CieRecord *Rec : CieRecords) {
    uint8_t Enc = getFdeEncoding(Rec->Cie);
    for (EhSectionPiece *Fde : Rec->Fdes) {
      uint32_t Pc = getFdePc(Buf, Fde->OutputOff, Enc);
      uint32_t FdeVA = getParent()->Addr + Fde->OutputOff;
      Ret.push_back({Pc, FdeVA});
    }
  }
  return Ret;
}

static uint64_t readFdeAddr(uint8_t *Buf, int Size) {
  switch (Size) {
  case DW_EH_PE_udata2:
    return read16(Buf, Config->Endianness);
  case DW_EH_PE_udata4:
    return read32(Buf, Config->Endianness);
  case DW_EH_PE_udata8:
    return read64(Buf, Config->Endianness);
  case DW_EH_PE_absptr:
    return readUint(Buf);
  }
  fatal("unknown FDE size encoding");
}

// Returns the VA to which a given FDE (on a mmap'ed buffer) is applied to.
// We need it to create .eh_frame_hdr section.
uint64_t EhFrameSection::getFdePc(uint8_t *Buf, size_t FdeOff,
                                  uint8_t Enc) const {
  // The starting address to which this FDE applies is
  // stored at FDE + 8 byte.
  size_t Off = FdeOff + 8;
  uint64_t Addr = readFdeAddr(Buf + Off, Enc & 0x7);
  if ((Enc & 0x70) == DW_EH_PE_absptr)
    return Addr;
  if ((Enc & 0x70) == DW_EH_PE_pcrel)
    return Addr + getParent()->Addr + Off;
  fatal("unknown FDE size relative encoding");
}

void EhFrameSection::writeTo(uint8_t *Buf) {
  // Write CIE and FDE records.
  for (CieRecord *Rec : CieRecords) {
    size_t CieOffset = Rec->Cie->OutputOff;
    writeCieFde(Buf + CieOffset, Rec->Cie->data());

    for (EhSectionPiece *Fde : Rec->Fdes) {
      size_t Off = Fde->OutputOff;
      writeCieFde(Buf + Off, Fde->data());

      // FDE's second word should have the offset to an associated CIE.
      // Write it.
      write32(Buf + Off + 4, Off + 4 - CieOffset);
    }
  }

  // Apply relocations. .eh_frame section contents are not contiguous
  // in the output buffer, but relocateAlloc() still works because
  // getOffset() takes care of discontiguous section pieces.
  for (EhInputSection *S : Sections)
    S->relocateAlloc(Buf, nullptr);
}

GotSection::GotSection()
    : SyntheticSection(SHF_ALLOC | SHF_WRITE, SHT_PROGBITS,
                       Target->GotEntrySize, ".got") {}

void GotSection::addEntry(Symbol &Sym) {
  Sym.GotIndex = NumEntries;
  ++NumEntries;
}

bool GotSection::addDynTlsEntry(Symbol &Sym) {
  if (Sym.GlobalDynIndex != -1U)
    return false;
  Sym.GlobalDynIndex = NumEntries;
  // Global Dynamic TLS entries take two GOT slots.
  NumEntries += 2;
  return true;
}

// Reserves TLS entries for a TLS module ID and a TLS block offset.
// In total it takes two GOT slots.
bool GotSection::addTlsIndex() {
  if (TlsIndexOff != uint32_t(-1))
    return false;
  TlsIndexOff = NumEntries * Config->Wordsize;
  NumEntries += 2;
  return true;
}

uint64_t GotSection::getGlobalDynAddr(const Symbol &B) const {
  return this->getVA() + B.GlobalDynIndex * Config->Wordsize;
}

uint64_t GotSection::getGlobalDynOffset(const Symbol &B) const {
  return B.GlobalDynIndex * Config->Wordsize;
}

void GotSection::finalizeContents() { Size = NumEntries * Config->Wordsize; }

bool GotSection::empty() const {
  // We need to emit a GOT even if it's empty if there's a relocation that is
  // relative to GOT(such as GOTOFFREL) or there's a symbol that points to a GOT
  // (i.e. _GLOBAL_OFFSET_TABLE_).
  return NumEntries == 0 && !HasGotOffRel && !ElfSym::GlobalOffsetTable;
}

void GotSection::writeTo(uint8_t *Buf) {
  // Buf points to the start of this section's buffer,
  // whereas InputSectionBase::relocateAlloc() expects its argument
  // to point to the start of the output section.
  relocateAlloc(Buf - OutSecOff, Buf - OutSecOff + Size);
}

MipsGotSection::MipsGotSection()
    : SyntheticSection(SHF_ALLOC | SHF_WRITE | SHF_MIPS_GPREL, SHT_PROGBITS, 16,
                       ".got") {}

void MipsGotSection::addEntry(Symbol &Sym, int64_t Addend, RelExpr Expr) {
  // For "true" local symbols which can be referenced from the same module
  // only compiler creates two instructions for address loading:
  //
  // lw   $8, 0($gp) # R_MIPS_GOT16
  // addi $8, $8, 0  # R_MIPS_LO16
  //
  // The first instruction loads high 16 bits of the symbol address while
  // the second adds an offset. That allows to reduce number of required
  // GOT entries because only one global offset table entry is necessary
  // for every 64 KBytes of local data. So for local symbols we need to
  // allocate number of GOT entries to hold all required "page" addresses.
  //
  // All global symbols (hidden and regular) considered by compiler uniformly.
  // It always generates a single `lw` instruction and R_MIPS_GOT16 relocation
  // to load address of the symbol. So for each such symbol we need to
  // allocate dedicated GOT entry to store its address.
  //
  // If a symbol is preemptible we need help of dynamic linker to get its
  // final address. The corresponding GOT entries are allocated in the
  // "global" part of GOT. Entries for non preemptible global symbol allocated
  // in the "local" part of GOT.
  //
  // See "Global Offset Table" in Chapter 5:
  // ftp://www.linux-mips.org/pub/linux/mips/doc/ABI/mipsabi.pdf
  if (Expr == R_MIPS_GOT_LOCAL_PAGE) {
    // At this point we do not know final symbol value so to reduce number
    // of allocated GOT entries do the following trick. Save all output
    // sections referenced by GOT relocations. Then later in the `finalize`
    // method calculate number of "pages" required to cover all saved output
    // section and allocate appropriate number of GOT entries.
    PageIndexMap.insert({Sym.getOutputSection(), 0});
    return;
  }
  if (Sym.isTls()) {
    // GOT entries created for MIPS TLS relocations behave like
    // almost GOT entries from other ABIs. They go to the end
    // of the global offset table.
    Sym.GotIndex = TlsEntries.size();
    TlsEntries.push_back(&Sym);
    return;
  }
  auto AddEntry = [&](Symbol &S, uint64_t A, GotEntries &Items) {
    if (S.isInGot() && !A)
      return;
    size_t NewIndex = Items.size();
    if (!EntryIndexMap.insert({{&S, A}, NewIndex}).second)
      return;
    Items.emplace_back(&S, A);
    if (!A)
      S.GotIndex = NewIndex;
  };
  if (Sym.IsPreemptible) {
    // Ignore addends for preemptible symbols. They got single GOT entry anyway.
    AddEntry(Sym, 0, GlobalEntries);
    Sym.IsInGlobalMipsGot = true;
  } else if (Expr == R_MIPS_GOT_OFF32) {
    AddEntry(Sym, Addend, LocalEntries32);
    Sym.Is32BitMipsGot = true;
  } else {
    // Hold local GOT entries accessed via a 16-bit index separately.
    // That allows to write them in the beginning of the GOT and keep
    // their indexes as less as possible to escape relocation's overflow.
    AddEntry(Sym, Addend, LocalEntries);
  }
}

bool MipsGotSection::addDynTlsEntry(Symbol &Sym) {
  if (Sym.GlobalDynIndex != -1U)
    return false;
  Sym.GlobalDynIndex = TlsEntries.size();
  // Global Dynamic TLS entries take two GOT slots.
  TlsEntries.push_back(nullptr);
  TlsEntries.push_back(&Sym);
  return true;
}

// Reserves TLS entries for a TLS module ID and a TLS block offset.
// In total it takes two GOT slots.
bool MipsGotSection::addTlsIndex() {
  if (TlsIndexOff != uint32_t(-1))
    return false;
  TlsIndexOff = TlsEntries.size() * Config->Wordsize;
  TlsEntries.push_back(nullptr);
  TlsEntries.push_back(nullptr);
  return true;
}

static uint64_t getMipsPageAddr(uint64_t Addr) {
  return (Addr + 0x8000) & ~0xffff;
}

static uint64_t getMipsPageCount(uint64_t Size) {
  return (Size + 0xfffe) / 0xffff + 1;
}

uint64_t MipsGotSection::getPageEntryOffset(const Symbol &B,
                                            int64_t Addend) const {
  const OutputSection *OutSec = B.getOutputSection();
  uint64_t SecAddr = getMipsPageAddr(OutSec->Addr);
  uint64_t SymAddr = getMipsPageAddr(B.getVA(Addend));
  uint64_t Index = PageIndexMap.lookup(OutSec) + (SymAddr - SecAddr) / 0xffff;
  assert(Index < PageEntriesNum);
  return (HeaderEntriesNum + Index) * Config->Wordsize;
}

uint64_t MipsGotSection::getSymEntryOffset(const Symbol &B,
                                           int64_t Addend) const {
  // Calculate offset of the GOT entries block: TLS, global, local.
  uint64_t Index = HeaderEntriesNum + PageEntriesNum;
  if (B.isTls())
    Index += LocalEntries.size() + LocalEntries32.size() + GlobalEntries.size();
  else if (B.IsInGlobalMipsGot)
    Index += LocalEntries.size() + LocalEntries32.size();
  else if (B.Is32BitMipsGot)
    Index += LocalEntries.size();
  // Calculate offset of the GOT entry in the block.
  if (B.isInGot())
    Index += B.GotIndex;
  else {
    auto It = EntryIndexMap.find({&B, Addend});
    assert(It != EntryIndexMap.end());
    Index += It->second;
  }
  return Index * Config->Wordsize;
}

uint64_t MipsGotSection::getTlsOffset() const {
  return (getLocalEntriesNum() + GlobalEntries.size()) * Config->Wordsize;
}

uint64_t MipsGotSection::getGlobalDynOffset(const Symbol &B) const {
  return B.GlobalDynIndex * Config->Wordsize;
}

const Symbol *MipsGotSection::getFirstGlobalEntry() const {
  return GlobalEntries.empty() ? nullptr : GlobalEntries.front().first;
}

unsigned MipsGotSection::getLocalEntriesNum() const {
  return HeaderEntriesNum + PageEntriesNum + LocalEntries.size() +
         LocalEntries32.size();
}

void MipsGotSection::finalizeContents() { updateAllocSize(); }

bool MipsGotSection::updateAllocSize() {
  PageEntriesNum = 0;
  for (std::pair<const OutputSection *, size_t> &P : PageIndexMap) {
    // For each output section referenced by GOT page relocations calculate
    // and save into PageIndexMap an upper bound of MIPS GOT entries required
    // to store page addresses of local symbols. We assume the worst case -
    // each 64kb page of the output section has at least one GOT relocation
    // against it. And take in account the case when the section intersects
    // page boundaries.
    P.second = PageEntriesNum;
    PageEntriesNum += getMipsPageCount(P.first->Size);
  }
  Size = (getLocalEntriesNum() + GlobalEntries.size() + TlsEntries.size()) *
         Config->Wordsize;
  return false;
}

bool MipsGotSection::empty() const {
  // We add the .got section to the result for dynamic MIPS target because
  // its address and properties are mentioned in the .dynamic section.
  return Config->Relocatable;
}

uint64_t MipsGotSection::getGp() const { return ElfSym::MipsGp->getVA(0); }

void MipsGotSection::writeTo(uint8_t *Buf) {
  // Set the MSB of the second GOT slot. This is not required by any
  // MIPS ABI documentation, though.
  //
  // There is a comment in glibc saying that "The MSB of got[1] of a
  // gnu object is set to identify gnu objects," and in GNU gold it
  // says "the second entry will be used by some runtime loaders".
  // But how this field is being used is unclear.
  //
  // We are not really willing to mimic other linkers behaviors
  // without understanding why they do that, but because all files
  // generated by GNU tools have this special GOT value, and because
  // we've been doing this for years, it is probably a safe bet to
  // keep doing this for now. We really need to revisit this to see
  // if we had to do this.
  writeUint(Buf + Config->Wordsize, (uint64_t)1 << (Config->Wordsize * 8 - 1));
  Buf += HeaderEntriesNum * Config->Wordsize;
  // Write 'page address' entries to the local part of the GOT.
  for (std::pair<const OutputSection *, size_t> &L : PageIndexMap) {
    size_t PageCount = getMipsPageCount(L.first->Size);
    uint64_t FirstPageAddr = getMipsPageAddr(L.first->Addr);
    for (size_t PI = 0; PI < PageCount; ++PI) {
      uint8_t *Entry = Buf + (L.second + PI) * Config->Wordsize;
      writeUint(Entry, FirstPageAddr + PI * 0x10000);
    }
  }
  Buf += PageEntriesNum * Config->Wordsize;
  auto AddEntry = [&](const GotEntry &SA) {
    uint8_t *Entry = Buf;
    Buf += Config->Wordsize;
    const Symbol *Sym = SA.first;
    uint64_t VA = Sym->getVA(SA.second);
    if (Sym->StOther & STO_MIPS_MICROMIPS)
      VA |= 1;
    writeUint(Entry, VA);
  };
  std::for_each(std::begin(LocalEntries), std::end(LocalEntries), AddEntry);
  std::for_each(std::begin(LocalEntries32), std::end(LocalEntries32), AddEntry);
  std::for_each(std::begin(GlobalEntries), std::end(GlobalEntries), AddEntry);
  // Initialize TLS-related GOT entries. If the entry has a corresponding
  // dynamic relocations, leave it initialized by zero. Write down adjusted
  // TLS symbol's values otherwise. To calculate the adjustments use offsets
  // for thread-local storage.
  // https://www.linux-mips.org/wiki/NPTL
  if (TlsIndexOff != -1U && !Config->Pic)
    writeUint(Buf + TlsIndexOff, 1);
  for (const Symbol *B : TlsEntries) {
    if (!B || B->IsPreemptible)
      continue;
    uint64_t VA = B->getVA();
    if (B->GotIndex != -1U) {
      uint8_t *Entry = Buf + B->GotIndex * Config->Wordsize;
      writeUint(Entry, VA - 0x7000);
    }
    if (B->GlobalDynIndex != -1U) {
      uint8_t *Entry = Buf + B->GlobalDynIndex * Config->Wordsize;
      writeUint(Entry, 1);
      Entry += Config->Wordsize;
      writeUint(Entry, VA - 0x8000);
    }
  }
}

GotPltSection::GotPltSection()
    : SyntheticSection(SHF_ALLOC | SHF_WRITE, SHT_PROGBITS,
                       Target->GotPltEntrySize, ".got.plt") {}

void GotPltSection::addEntry(Symbol &Sym) {
  Sym.GotPltIndex = Target->GotPltHeaderEntriesNum + Entries.size();
  Entries.push_back(&Sym);
}

size_t GotPltSection::getSize() const {
  return (Target->GotPltHeaderEntriesNum + Entries.size()) *
         Target->GotPltEntrySize;
}

void GotPltSection::writeTo(uint8_t *Buf) {
  Target->writeGotPltHeader(Buf);
  Buf += Target->GotPltHeaderEntriesNum * Target->GotPltEntrySize;
  for (const Symbol *B : Entries) {
    Target->writeGotPlt(Buf, *B);
    Buf += Config->Wordsize;
  }
}

// On ARM the IgotPltSection is part of the GotSection, on other Targets it is
// part of the .got.plt
IgotPltSection::IgotPltSection()
    : SyntheticSection(SHF_ALLOC | SHF_WRITE, SHT_PROGBITS,
                       Target->GotPltEntrySize,
                       Config->EMachine == EM_ARM ? ".got" : ".got.plt") {}

void IgotPltSection::addEntry(Symbol &Sym) {
  Sym.IsInIgot = true;
  Sym.GotPltIndex = Entries.size();
  Entries.push_back(&Sym);
}

size_t IgotPltSection::getSize() const {
  return Entries.size() * Target->GotPltEntrySize;
}

void IgotPltSection::writeTo(uint8_t *Buf) {
  for (const Symbol *B : Entries) {
    Target->writeIgotPlt(Buf, *B);
    Buf += Config->Wordsize;
  }
}

StringTableSection::StringTableSection(StringRef Name, bool Dynamic)
    : SyntheticSection(Dynamic ? (uint64_t)SHF_ALLOC : 0, SHT_STRTAB, 1, Name),
      Dynamic(Dynamic) {
  // ELF string tables start with a NUL byte.
  addString("");
}

// Adds a string to the string table. If HashIt is true we hash and check for
// duplicates. It is optional because the name of global symbols are already
// uniqued and hashing them again has a big cost for a small value: uniquing
// them with some other string that happens to be the same.
unsigned StringTableSection::addString(StringRef S, bool HashIt) {
  if (HashIt) {
    auto R = StringMap.insert(std::make_pair(S, this->Size));
    if (!R.second)
      return R.first->second;
  }
  unsigned Ret = this->Size;
  this->Size = this->Size + S.size() + 1;
  Strings.push_back(S);
  return Ret;
}

void StringTableSection::writeTo(uint8_t *Buf) {
  for (StringRef S : Strings) {
    memcpy(Buf, S.data(), S.size());
    Buf[S.size()] = '\0';
    Buf += S.size() + 1;
  }
}

// Returns the number of version definition entries. Because the first entry
// is for the version definition itself, it is the number of versioned symbols
// plus one. Note that we don't support multiple versions yet.
static unsigned getVerDefNum() { return Config->VersionDefinitions.size() + 1; }

template <class ELFT>
DynamicSection<ELFT>::DynamicSection()
    : SyntheticSection(SHF_ALLOC | SHF_WRITE, SHT_DYNAMIC, Config->Wordsize,
                       ".dynamic") {
  this->Entsize = ELFT::Is64Bits ? 16 : 8;

  // .dynamic section is not writable on MIPS and on Fuchsia OS
  // which passes -z rodynamic.
  // See "Special Section" in Chapter 4 in the following document:
  // ftp://www.linux-mips.org/pub/linux/mips/doc/ABI/mipsabi.pdf
  if (Config->EMachine == EM_MIPS || Config->ZRodynamic)
    this->Flags = SHF_ALLOC;

  // Add strings to .dynstr early so that .dynstr's size will be
  // fixed early.
  for (StringRef S : Config->FilterList)
    addInt(DT_FILTER, InX::DynStrTab->addString(S));
  for (StringRef S : Config->AuxiliaryList)
    addInt(DT_AUXILIARY, InX::DynStrTab->addString(S));

  if (!Config->Rpath.empty())
    addInt(Config->EnableNewDtags ? DT_RUNPATH : DT_RPATH,
           InX::DynStrTab->addString(Config->Rpath));

  for (InputFile *File : SharedFiles) {
    SharedFile<ELFT> *F = cast<SharedFile<ELFT>>(File);
    if (F->IsNeeded)
      addInt(DT_NEEDED, InX::DynStrTab->addString(F->SoName));
  }
  if (!Config->SoName.empty())
    addInt(DT_SONAME, InX::DynStrTab->addString(Config->SoName));
}

template <class ELFT>
void DynamicSection<ELFT>::add(int32_t Tag, std::function<uint64_t()> Fn) {
  Entries.push_back({Tag, Fn});
}

template <class ELFT>
void DynamicSection<ELFT>::addInt(int32_t Tag, uint64_t Val) {
  Entries.push_back({Tag, [=] { return Val; }});
}

template <class ELFT>
void DynamicSection<ELFT>::addInSec(int32_t Tag, InputSection *Sec) {
  Entries.push_back(
      {Tag, [=] { return Sec->getParent()->Addr + Sec->OutSecOff; }});
}

template <class ELFT>
void DynamicSection<ELFT>::addOutSec(int32_t Tag, OutputSection *Sec) {
  Entries.push_back({Tag, [=] { return Sec->Addr; }});
}

template <class ELFT>
void DynamicSection<ELFT>::addSize(int32_t Tag, OutputSection *Sec) {
  Entries.push_back({Tag, [=] { return Sec->Size; }});
}

template <class ELFT>
void DynamicSection<ELFT>::addSym(int32_t Tag, Symbol *Sym) {
  Entries.push_back({Tag, [=] { return Sym->getVA(); }});
}

// Add remaining entries to complete .dynamic contents.
template <class ELFT> void DynamicSection<ELFT>::finalizeContents() {
  if (this->Size)
    return; // Already finalized.

  // Set DT_FLAGS and DT_FLAGS_1.
  uint32_t DtFlags = 0;
  uint32_t DtFlags1 = 0;
  if (Config->Bsymbolic)
    DtFlags |= DF_SYMBOLIC;
  if (Config->ZNodelete)
    DtFlags1 |= DF_1_NODELETE;
  if (Config->ZNodlopen)
    DtFlags1 |= DF_1_NOOPEN;
  if (Config->ZNow) {
    DtFlags |= DF_BIND_NOW;
    DtFlags1 |= DF_1_NOW;
  }
  if (Config->ZOrigin) {
    DtFlags |= DF_ORIGIN;
    DtFlags1 |= DF_1_ORIGIN;
  }

  if (DtFlags)
    addInt(DT_FLAGS, DtFlags);
  if (DtFlags1)
    addInt(DT_FLAGS_1, DtFlags1);

  // DT_DEBUG is a pointer to debug informaion used by debuggers at runtime. We
  // need it for each process, so we don't write it for DSOs. The loader writes
  // the pointer into this entry.
  //
  // DT_DEBUG is the only .dynamic entry that needs to be written to. Some
  // systems (currently only Fuchsia OS) provide other means to give the
  // debugger this information. Such systems may choose make .dynamic read-only.
  // If the target is such a system (used -z rodynamic) don't write DT_DEBUG.
  if (!Config->Shared && !Config->Relocatable && !Config->ZRodynamic)
    addInt(DT_DEBUG, 0);

  this->Link = InX::DynStrTab->getParent()->SectionIndex;
  if (!InX::RelaDyn->empty()) {
    addInSec(InX::RelaDyn->DynamicTag, InX::RelaDyn);
    addSize(InX::RelaDyn->SizeDynamicTag, InX::RelaDyn->getParent());

    bool IsRela = Config->IsRela;
    addInt(IsRela ? DT_RELAENT : DT_RELENT,
           IsRela ? sizeof(Elf_Rela) : sizeof(Elf_Rel));

    // MIPS dynamic loader does not support RELCOUNT tag.
    // The problem is in the tight relation between dynamic
    // relocations and GOT. So do not emit this tag on MIPS.
    if (Config->EMachine != EM_MIPS) {
      size_t NumRelativeRels = InX::RelaDyn->getRelativeRelocCount();
      if (Config->ZCombreloc && NumRelativeRels)
        addInt(IsRela ? DT_RELACOUNT : DT_RELCOUNT, NumRelativeRels);
    }
  }
  // .rel[a].plt section usually consists of two parts, containing plt and
  // iplt relocations. It is possible to have only iplt relocations in the
  // output. In that case RelaPlt is empty and have zero offset, the same offset
  // as RelaIplt have. And we still want to emit proper dynamic tags for that
  // case, so here we always use RelaPlt as marker for the begining of
  // .rel[a].plt section.
  if (InX::RelaPlt->getParent()->Live) {
    addInSec(DT_JMPREL, InX::RelaPlt);
    addSize(DT_PLTRELSZ, InX::RelaPlt->getParent());
    switch (Config->EMachine) {
    case EM_MIPS:
      addInSec(DT_MIPS_PLTGOT, InX::GotPlt);
      break;
    case EM_SPARCV9:
      addInSec(DT_PLTGOT, InX::Plt);
      break;
    default:
      addInSec(DT_PLTGOT, InX::GotPlt);
      break;
    }
    addInt(DT_PLTREL, Config->IsRela ? DT_RELA : DT_REL);
  }

  addInSec(DT_SYMTAB, InX::DynSymTab);
  addInt(DT_SYMENT, sizeof(Elf_Sym));
  addInSec(DT_STRTAB, InX::DynStrTab);
  addInt(DT_STRSZ, InX::DynStrTab->getSize());
  if (!Config->ZText)
    addInt(DT_TEXTREL, 0);
  if (InX::GnuHashTab)
    addInSec(DT_GNU_HASH, InX::GnuHashTab);
  if (InX::HashTab)
    addInSec(DT_HASH, InX::HashTab);

  if (Out::PreinitArray) {
    addOutSec(DT_PREINIT_ARRAY, Out::PreinitArray);
    addSize(DT_PREINIT_ARRAYSZ, Out::PreinitArray);
  }
  if (Out::InitArray) {
    addOutSec(DT_INIT_ARRAY, Out::InitArray);
    addSize(DT_INIT_ARRAYSZ, Out::InitArray);
  }
  if (Out::FiniArray) {
    addOutSec(DT_FINI_ARRAY, Out::FiniArray);
    addSize(DT_FINI_ARRAYSZ, Out::FiniArray);
  }

  if (Symbol *B = Symtab->find(Config->Init))
    if (B->isDefined())
      addSym(DT_INIT, B);
  if (Symbol *B = Symtab->find(Config->Fini))
    if (B->isDefined())
      addSym(DT_FINI, B);

  bool HasVerNeed = In<ELFT>::VerNeed->getNeedNum() != 0;
  if (HasVerNeed || In<ELFT>::VerDef)
    addInSec(DT_VERSYM, In<ELFT>::VerSym);
  if (In<ELFT>::VerDef) {
    addInSec(DT_VERDEF, In<ELFT>::VerDef);
    addInt(DT_VERDEFNUM, getVerDefNum());
  }
  if (HasVerNeed) {
    addInSec(DT_VERNEED, In<ELFT>::VerNeed);
    addInt(DT_VERNEEDNUM, In<ELFT>::VerNeed->getNeedNum());
  }

  if (Config->EMachine == EM_MIPS) {
    addInt(DT_MIPS_RLD_VERSION, 1);
    addInt(DT_MIPS_FLAGS, RHF_NOTPOT);
    addInt(DT_MIPS_BASE_ADDRESS, Target->getImageBase());
    addInt(DT_MIPS_SYMTABNO, InX::DynSymTab->getNumSymbols());

    add(DT_MIPS_LOCAL_GOTNO, [] { return InX::MipsGot->getLocalEntriesNum(); });

    if (const Symbol *B = InX::MipsGot->getFirstGlobalEntry())
      addInt(DT_MIPS_GOTSYM, B->DynsymIndex);
    else
      addInt(DT_MIPS_GOTSYM, InX::DynSymTab->getNumSymbols());
    addInSec(DT_PLTGOT, InX::MipsGot);
    if (InX::MipsRldMap)
      addInSec(DT_MIPS_RLD_MAP, InX::MipsRldMap);
  }

  addInt(DT_NULL, 0);

  getParent()->Link = this->Link;
  this->Size = Entries.size() * this->Entsize;
}

template <class ELFT> void DynamicSection<ELFT>::writeTo(uint8_t *Buf) {
  auto *P = reinterpret_cast<Elf_Dyn *>(Buf);

  for (std::pair<int32_t, std::function<uint64_t()>> &KV : Entries) {
    P->d_tag = KV.first;
    P->d_un.d_val = KV.second();
    ++P;
  }
}

uint64_t DynamicReloc::getOffset() const {
  return InputSec->getOutputSection()->Addr + InputSec->getOffset(OffsetInSec);
}

int64_t DynamicReloc::getAddend() const {
  if (UseSymVA)
    return Sym->getVA(Addend);
  return Addend;
}

uint32_t DynamicReloc::getSymIndex() const {
  if (Sym && !UseSymVA)
    return Sym->DynsymIndex;
  return 0;
}

RelocationBaseSection::RelocationBaseSection(StringRef Name, uint32_t Type,
                                             int32_t DynamicTag,
                                             int32_t SizeDynamicTag)
    : SyntheticSection(SHF_ALLOC, Type, Config->Wordsize, Name),
      DynamicTag(DynamicTag), SizeDynamicTag(SizeDynamicTag) {}

void RelocationBaseSection::addReloc(const DynamicReloc &Reloc) {
  if (Reloc.Type == Target->RelativeRel)
    ++NumRelativeRelocs;
  Relocs.push_back(Reloc);
}

void RelocationBaseSection::finalizeContents() {
  // If all relocations are R_*_RELATIVE they don't refer to any
  // dynamic symbol and we don't need a dynamic symbol table. If that
  // is the case, just use 0 as the link.
  Link = InX::DynSymTab ? InX::DynSymTab->getParent()->SectionIndex : 0;

  // Set required output section properties.
  getParent()->Link = Link;
}

template <class ELFT>
static void encodeDynamicReloc(typename ELFT::Rela *P,
                               const DynamicReloc &Rel) {
  if (Config->IsRela)
    P->r_addend = Rel.getAddend();
  P->r_offset = Rel.getOffset();
  if (Config->EMachine == EM_MIPS && Rel.getInputSec() == InX::MipsGot)
    // The MIPS GOT section contains dynamic relocations that correspond to TLS
    // entries. These entries are placed after the global and local sections of
    // the GOT. At the point when we create these relocations, the size of the
    // global and local sections is unknown, so the offset that we store in the
    // TLS entry's DynamicReloc is relative to the start of the TLS section of
    // the GOT, rather than being relative to the start of the GOT. This line of
    // code adds the size of the global and local sections to the virtual
    // address computed by getOffset() in order to adjust it into the TLS
    // section.
    P->r_offset += InX::MipsGot->getTlsOffset();
  P->setSymbolAndType(Rel.getSymIndex(), Rel.Type, Config->IsMips64EL);
}

template <class ELFT>
RelocationSection<ELFT>::RelocationSection(StringRef Name, bool Sort)
    : RelocationBaseSection(Name, Config->IsRela ? SHT_RELA : SHT_REL,
                            Config->IsRela ? DT_RELA : DT_REL,
                            Config->IsRela ? DT_RELASZ : DT_RELSZ),
      Sort(Sort) {
  this->Entsize = Config->IsRela ? sizeof(Elf_Rela) : sizeof(Elf_Rel);
}

template <class ELFT, class RelTy>
static bool compRelocations(const RelTy &A, const RelTy &B) {
  bool AIsRel = A.getType(Config->IsMips64EL) == Target->RelativeRel;
  bool BIsRel = B.getType(Config->IsMips64EL) == Target->RelativeRel;
  if (AIsRel != BIsRel)
    return AIsRel;

  return A.getSymbol(Config->IsMips64EL) < B.getSymbol(Config->IsMips64EL);
}

template <class ELFT> void RelocationSection<ELFT>::writeTo(uint8_t *Buf) {
  uint8_t *BufBegin = Buf;
  for (const DynamicReloc &Rel : Relocs) {
    encodeDynamicReloc<ELFT>(reinterpret_cast<Elf_Rela *>(Buf), Rel);
    Buf += Config->IsRela ? sizeof(Elf_Rela) : sizeof(Elf_Rel);
  }

  if (Sort) {
    if (Config->IsRela)
      std::stable_sort((Elf_Rela *)BufBegin,
                       (Elf_Rela *)BufBegin + Relocs.size(),
                       compRelocations<ELFT, Elf_Rela>);
    else
      std::stable_sort((Elf_Rel *)BufBegin, (Elf_Rel *)BufBegin + Relocs.size(),
                       compRelocations<ELFT, Elf_Rel>);
  }
}

template <class ELFT> unsigned RelocationSection<ELFT>::getRelocOffset() {
  return this->Entsize * Relocs.size();
}

template <class ELFT>
AndroidPackedRelocationSection<ELFT>::AndroidPackedRelocationSection(
    StringRef Name)
    : RelocationBaseSection(
          Name, Config->IsRela ? SHT_ANDROID_RELA : SHT_ANDROID_REL,
          Config->IsRela ? DT_ANDROID_RELA : DT_ANDROID_REL,
          Config->IsRela ? DT_ANDROID_RELASZ : DT_ANDROID_RELSZ) {
  this->Entsize = 1;
}

template <class ELFT>
bool AndroidPackedRelocationSection<ELFT>::updateAllocSize() {
  // This function computes the contents of an Android-format packed relocation
  // section.
  //
  // This format compresses relocations by using relocation groups to factor out
  // fields that are common between relocations and storing deltas from previous
  // relocations in SLEB128 format (which has a short representation for small
  // numbers). A good example of a relocation type with common fields is
  // R_*_RELATIVE, which is normally used to represent function pointers in
  // vtables. In the REL format, each relative relocation has the same r_info
  // field, and is only different from other relative relocations in terms of
  // the r_offset field. By sorting relocations by offset, grouping them by
  // r_info and representing each relocation with only the delta from the
  // previous offset, each 8-byte relocation can be compressed to as little as 1
  // byte (or less with run-length encoding). This relocation packer was able to
  // reduce the size of the relocation section in an Android Chromium DSO from
  // 2,911,184 bytes to 174,693 bytes, or 6% of the original size.
  //
  // A relocation section consists of a header containing the literal bytes
  // 'APS2' followed by a sequence of SLEB128-encoded integers. The first two
  // elements are the total number of relocations in the section and an initial
  // r_offset value. The remaining elements define a sequence of relocation
  // groups. Each relocation group starts with a header consisting of the
  // following elements:
  //
  // - the number of relocations in the relocation group
  // - flags for the relocation group
  // - (if RELOCATION_GROUPED_BY_OFFSET_DELTA_FLAG is set) the r_offset delta
  //   for each relocation in the group.
  // - (if RELOCATION_GROUPED_BY_INFO_FLAG is set) the value of the r_info
  //   field for each relocation in the group.
  // - (if RELOCATION_GROUP_HAS_ADDEND_FLAG and
  //   RELOCATION_GROUPED_BY_ADDEND_FLAG are set) the r_addend delta for
  //   each relocation in the group.
  //
  // Following the relocation group header are descriptions of each of the
  // relocations in the group. They consist of the following elements:
  //
  // - (if RELOCATION_GROUPED_BY_OFFSET_DELTA_FLAG is not set) the r_offset
  //   delta for this relocation.
  // - (if RELOCATION_GROUPED_BY_INFO_FLAG is not set) the value of the r_info
  //   field for this relocation.
  // - (if RELOCATION_GROUP_HAS_ADDEND_FLAG is set and
  //   RELOCATION_GROUPED_BY_ADDEND_FLAG is not set) the r_addend delta for
  //   this relocation.

  size_t OldSize = RelocData.size();

  RelocData = {'A', 'P', 'S', '2'};
  raw_svector_ostream OS(RelocData);
  auto Add = [&](int64_t V) { encodeSLEB128(V, OS); };

  // The format header includes the number of relocations and the initial
  // offset (we set this to zero because the first relocation group will
  // perform the initial adjustment).
  Add(Relocs.size());
  Add(0);

  std::vector<Elf_Rela> Relatives, NonRelatives;

  for (const DynamicReloc &Rel : Relocs) {
    Elf_Rela R;
    encodeDynamicReloc<ELFT>(&R, Rel);

    if (R.getType(Config->IsMips64EL) == Target->RelativeRel)
      Relatives.push_back(R);
    else
      NonRelatives.push_back(R);
  }

  std::sort(Relatives.begin(), Relatives.end(),
            [](const Elf_Rel &A, const Elf_Rel &B) {
              return A.r_offset < B.r_offset;
            });

  // Try to find groups of relative relocations which are spaced one word
  // apart from one another. These generally correspond to vtable entries. The
  // format allows these groups to be encoded using a sort of run-length
  // encoding, but each group will cost 7 bytes in addition to the offset from
  // the previous group, so it is only profitable to do this for groups of
  // size 8 or larger.
  std::vector<Elf_Rela> UngroupedRelatives;
  std::vector<std::vector<Elf_Rela>> RelativeGroups;
  for (auto I = Relatives.begin(), E = Relatives.end(); I != E;) {
    std::vector<Elf_Rela> Group;
    do {
      Group.push_back(*I++);
    } while (I != E && (I - 1)->r_offset + Config->Wordsize == I->r_offset);

    if (Group.size() < 8)
      UngroupedRelatives.insert(UngroupedRelatives.end(), Group.begin(),
                                Group.end());
    else
      RelativeGroups.emplace_back(std::move(Group));
  }

  unsigned HasAddendIfRela =
      Config->IsRela ? RELOCATION_GROUP_HAS_ADDEND_FLAG : 0;

  uint64_t Offset = 0;
  uint64_t Addend = 0;

  // Emit the run-length encoding for the groups of adjacent relative
  // relocations. Each group is represented using two groups in the packed
  // format. The first is used to set the current offset to the start of the
  // group (and also encodes the first relocation), and the second encodes the
  // remaining relocations.
  for (std::vector<Elf_Rela> &G : RelativeGroups) {
    // The first relocation in the group.
    Add(1);
    Add(RELOCATION_GROUPED_BY_OFFSET_DELTA_FLAG |
        RELOCATION_GROUPED_BY_INFO_FLAG | HasAddendIfRela);
    Add(G[0].r_offset - Offset);
    Add(Target->RelativeRel);
    if (Config->IsRela) {
      Add(G[0].r_addend - Addend);
      Addend = G[0].r_addend;
    }

    // The remaining relocations.
    Add(G.size() - 1);
    Add(RELOCATION_GROUPED_BY_OFFSET_DELTA_FLAG |
        RELOCATION_GROUPED_BY_INFO_FLAG | HasAddendIfRela);
    Add(Config->Wordsize);
    Add(Target->RelativeRel);
    if (Config->IsRela) {
      for (auto I = G.begin() + 1, E = G.end(); I != E; ++I) {
        Add(I->r_addend - Addend);
        Addend = I->r_addend;
      }
    }

    Offset = G.back().r_offset;
  }

  // Now the ungrouped relatives.
  if (!UngroupedRelatives.empty()) {
    Add(UngroupedRelatives.size());
    Add(RELOCATION_GROUPED_BY_INFO_FLAG | HasAddendIfRela);
    Add(Target->RelativeRel);
    for (Elf_Rela &R : UngroupedRelatives) {
      Add(R.r_offset - Offset);
      Offset = R.r_offset;
      if (Config->IsRela) {
        Add(R.r_addend - Addend);
        Addend = R.r_addend;
      }
    }
  }

  // Finally the non-relative relocations.
  std::sort(NonRelatives.begin(), NonRelatives.end(),
            [](const Elf_Rela &A, const Elf_Rela &B) {
              return A.r_offset < B.r_offset;
            });
  if (!NonRelatives.empty()) {
    Add(NonRelatives.size());
    Add(HasAddendIfRela);
    for (Elf_Rela &R : NonRelatives) {
      Add(R.r_offset - Offset);
      Offset = R.r_offset;
      Add(R.r_info);
      if (Config->IsRela) {
        Add(R.r_addend - Addend);
        Addend = R.r_addend;
      }
    }
  }

  // Returns whether the section size changed. We need to keep recomputing both
  // section layout and the contents of this section until the size converges
  // because changing this section's size can affect section layout, which in
  // turn can affect the sizes of the LEB-encoded integers stored in this
  // section.
  return RelocData.size() != OldSize;
}

SymbolTableBaseSection::SymbolTableBaseSection(StringTableSection &StrTabSec)
    : SyntheticSection(StrTabSec.isDynamic() ? (uint64_t)SHF_ALLOC : 0,
                       StrTabSec.isDynamic() ? SHT_DYNSYM : SHT_SYMTAB,
                       Config->Wordsize,
                       StrTabSec.isDynamic() ? ".dynsym" : ".symtab"),
      StrTabSec(StrTabSec) {}

// Orders symbols according to their positions in the GOT,
// in compliance with MIPS ABI rules.
// See "Global Offset Table" in Chapter 5 in the following document
// for detailed description:
// ftp://www.linux-mips.org/pub/linux/mips/doc/ABI/mipsabi.pdf
static bool sortMipsSymbols(const SymbolTableEntry &L,
                            const SymbolTableEntry &R) {
  // Sort entries related to non-local preemptible symbols by GOT indexes.
  // All other entries go to the first part of GOT in arbitrary order.
  bool LIsInLocalGot = !L.Sym->IsInGlobalMipsGot;
  bool RIsInLocalGot = !R.Sym->IsInGlobalMipsGot;
  if (LIsInLocalGot || RIsInLocalGot)
    return !RIsInLocalGot;
  return L.Sym->GotIndex < R.Sym->GotIndex;
}

void SymbolTableBaseSection::finalizeContents() {
  getParent()->Link = StrTabSec.getParent()->SectionIndex;

  // If it is a .dynsym, there should be no local symbols, but we need
  // to do a few things for the dynamic linker.
  if (this->Type == SHT_DYNSYM) {
    // Section's Info field has the index of the first non-local symbol.
    // Because the first symbol entry is a null entry, 1 is the first.
    getParent()->Info = 1;

    if (InX::GnuHashTab) {
      // NB: It also sorts Symbols to meet the GNU hash table requirements.
      InX::GnuHashTab->addSymbols(Symbols);
    } else if (Config->EMachine == EM_MIPS) {
      std::stable_sort(Symbols.begin(), Symbols.end(), sortMipsSymbols);
    }

    size_t I = 0;
    for (const SymbolTableEntry &S : Symbols) S.Sym->DynsymIndex = ++I;
    return;
  }
}

// The ELF spec requires that all local symbols precede global symbols, so we
// sort symbol entries in this function. (For .dynsym, we don't do that because
// symbols for dynamic linking are inherently all globals.)
void SymbolTableBaseSection::postThunkContents() {
  if (this->Type == SHT_DYNSYM)
    return;
  // move all local symbols before global symbols.
  auto It = std::stable_partition(
      Symbols.begin(), Symbols.end(), [](const SymbolTableEntry &S) {
        return S.Sym->isLocal() || S.Sym->computeBinding() == STB_LOCAL;
      });
  size_t NumLocals = It - Symbols.begin();
  getParent()->Info = NumLocals + 1;
}

void SymbolTableBaseSection::addSymbol(Symbol *B) {
  // Adding a local symbol to a .dynsym is a bug.
  assert(this->Type != SHT_DYNSYM || !B->isLocal());

  bool HashIt = B->isLocal();
  Symbols.push_back({B, StrTabSec.addString(B->getName(), HashIt)});
}

size_t SymbolTableBaseSection::getSymbolIndex(Symbol *Sym) {
  // Initializes symbol lookup tables lazily. This is used only
  // for -r or -emit-relocs.
  llvm::call_once(OnceFlag, [&] {
    SymbolIndexMap.reserve(Symbols.size());
    size_t I = 0;
    for (const SymbolTableEntry &E : Symbols) {
      if (E.Sym->Type == STT_SECTION)
        SectionIndexMap[E.Sym->getOutputSection()] = ++I;
      else
        SymbolIndexMap[E.Sym] = ++I;
    }
  });

  // Section symbols are mapped based on their output sections
  // to maintain their semantics.
  if (Sym->Type == STT_SECTION)
    return SectionIndexMap.lookup(Sym->getOutputSection());
  return SymbolIndexMap.lookup(Sym);
}

template <class ELFT>
SymbolTableSection<ELFT>::SymbolTableSection(StringTableSection &StrTabSec)
    : SymbolTableBaseSection(StrTabSec) {
  this->Entsize = sizeof(Elf_Sym);
}

// Write the internal symbol table contents to the output symbol table.
template <class ELFT> void SymbolTableSection<ELFT>::writeTo(uint8_t *Buf) {
  // The first entry is a null entry as per the ELF spec.
  memset(Buf, 0, sizeof(Elf_Sym));
  Buf += sizeof(Elf_Sym);

  auto *ESym = reinterpret_cast<Elf_Sym *>(Buf);

  for (SymbolTableEntry &Ent : Symbols) {
    Symbol *Sym = Ent.Sym;

    // Set st_info and st_other.
    ESym->st_other = 0;
    if (Sym->isLocal()) {
      ESym->setBindingAndType(STB_LOCAL, Sym->Type);
    } else {
      ESym->setBindingAndType(Sym->computeBinding(), Sym->Type);
      ESym->setVisibility(Sym->Visibility);
    }

    ESym->st_name = Ent.StrTabOffset;

    // Set a section index.
    BssSection *CommonSec = nullptr;
    if (!Config->DefineCommon)
      if (auto *D = dyn_cast<Defined>(Sym))
        CommonSec = dyn_cast_or_null<BssSection>(D->Section);
    if (CommonSec)
      ESym->st_shndx = SHN_COMMON;
    else if (const OutputSection *OutSec = Sym->getOutputSection())
      ESym->st_shndx = OutSec->SectionIndex;
    else if (isa<Defined>(Sym))
      ESym->st_shndx = SHN_ABS;
    else
      ESym->st_shndx = SHN_UNDEF;

    // Copy symbol size if it is a defined symbol. st_size is not significant
    // for undefined symbols, so whether copying it or not is up to us if that's
    // the case. We'll leave it as zero because by not setting a value, we can
    // get the exact same outputs for two sets of input files that differ only
    // in undefined symbol size in DSOs.
    if (ESym->st_shndx == SHN_UNDEF)
      ESym->st_size = 0;
    else
      ESym->st_size = Sym->getSize();

    // st_value is usually an address of a symbol, but that has a
    // special meaining for uninstantiated common symbols (this can
    // occur if -r is given).
    if (CommonSec)
      ESym->st_value = CommonSec->Alignment;
    else
      ESym->st_value = Sym->getVA();

    ++ESym;
  }

  // On MIPS we need to mark symbol which has a PLT entry and requires
  // pointer equality by STO_MIPS_PLT flag. That is necessary to help
  // dynamic linker distinguish such symbols and MIPS lazy-binding stubs.
  // https://sourceware.org/ml/binutils/2008-07/txt00000.txt
  if (Config->EMachine == EM_MIPS) {
    auto *ESym = reinterpret_cast<Elf_Sym *>(Buf);

    for (SymbolTableEntry &Ent : Symbols) {
      Symbol *Sym = Ent.Sym;
      if (Sym->isInPlt() && Sym->NeedsPltAddr)
        ESym->st_other |= STO_MIPS_PLT;
      if (isMicroMips()) {
        // Set STO_MIPS_MICROMIPS flag and less-significant bit for
        // defined microMIPS symbols and shared symbols with PLT record.
        if ((Sym->isDefined() && (Sym->StOther & STO_MIPS_MICROMIPS)) ||
            (Sym->isShared() && Sym->NeedsPltAddr)) {
          if (StrTabSec.isDynamic())
            ESym->st_value |= 1;
          ESym->st_other |= STO_MIPS_MICROMIPS;
        }
      }
      if (Config->Relocatable)
        if (auto *D = dyn_cast<Defined>(Sym))
          if (isMipsPIC<ELFT>(D))
            ESym->st_other |= STO_MIPS_PIC;
      ++ESym;
    }
  }
}

// .hash and .gnu.hash sections contain on-disk hash tables that map
// symbol names to their dynamic symbol table indices. Their purpose
// is to help the dynamic linker resolve symbols quickly. If ELF files
// don't have them, the dynamic linker has to do linear search on all
// dynamic symbols, which makes programs slower. Therefore, a .hash
// section is added to a DSO by default. A .gnu.hash is added if you
// give the -hash-style=gnu or -hash-style=both option.
//
// The Unix semantics of resolving dynamic symbols is somewhat expensive.
// Each ELF file has a list of DSOs that the ELF file depends on and a
// list of dynamic symbols that need to be resolved from any of the
// DSOs. That means resolving all dynamic symbols takes O(m)*O(n)
// where m is the number of DSOs and n is the number of dynamic
// symbols. For modern large programs, both m and n are large.  So
// making each step faster by using hash tables substiantially
// improves time to load programs.
//
// (Note that this is not the only way to design the shared library.
// For instance, the Windows DLL takes a different approach. On
// Windows, each dynamic symbol has a name of DLL from which the symbol
// has to be resolved. That makes the cost of symbol resolution O(n).
// This disables some hacky techniques you can use on Unix such as
// LD_PRELOAD, but this is arguably better semantics than the Unix ones.)
//
// Due to historical reasons, we have two different hash tables, .hash
// and .gnu.hash. They are for the same purpose, and .gnu.hash is a new
// and better version of .hash. .hash is just an on-disk hash table, but
// .gnu.hash has a bloom filter in addition to a hash table to skip
// DSOs very quickly. If you are sure that your dynamic linker knows
// about .gnu.hash, you want to specify -hash-style=gnu. Otherwise, a
// safe bet is to specify -hash-style=both for backward compatibilty.
GnuHashTableSection::GnuHashTableSection()
    : SyntheticSection(SHF_ALLOC, SHT_GNU_HASH, Config->Wordsize, ".gnu.hash") {
}

void GnuHashTableSection::finalizeContents() {
  getParent()->Link = InX::DynSymTab->getParent()->SectionIndex;

  // Computes bloom filter size in word size. We want to allocate 8
  // bits for each symbol. It must be a power of two.
  if (Symbols.empty())
    MaskWords = 1;
  else
    MaskWords = NextPowerOf2((Symbols.size() - 1) / Config->Wordsize);

  Size = 16;                            // Header
  Size += Config->Wordsize * MaskWords; // Bloom filter
  Size += NBuckets * 4;                 // Hash buckets
  Size += Symbols.size() * 4;           // Hash values
}

void GnuHashTableSection::writeTo(uint8_t *Buf) {
  // The output buffer is not guaranteed to be zero-cleared because we pre-
  // fill executable sections with trap instructions. This is a precaution
  // for that case, which happens only when -no-rosegment is given.
  memset(Buf, 0, Size);

  // Write a header.
  write32(Buf, NBuckets);
  write32(Buf + 4, InX::DynSymTab->getNumSymbols() - Symbols.size());
  write32(Buf + 8, MaskWords);
  write32(Buf + 12, getShift2());
  Buf += 16;

  // Write a bloom filter and a hash table.
  writeBloomFilter(Buf);
  Buf += Config->Wordsize * MaskWords;
  writeHashTable(Buf);
}

// This function writes a 2-bit bloom filter. This bloom filter alone
// usually filters out 80% or more of all symbol lookups [1].
// The dynamic linker uses the hash table only when a symbol is not
// filtered out by a bloom filter.
//
// [1] Ulrich Drepper (2011), "How To Write Shared Libraries" (Ver. 4.1.2),
//     p.9, https://www.akkadia.org/drepper/dsohowto.pdf
void GnuHashTableSection::writeBloomFilter(uint8_t *Buf) {
  const unsigned C = Config->Wordsize * 8;
  for (const Entry &Sym : Symbols) {
    size_t I = (Sym.Hash / C) & (MaskWords - 1);
    uint64_t Val = readUint(Buf + I * Config->Wordsize);
    Val |= uint64_t(1) << (Sym.Hash % C);
    Val |= uint64_t(1) << ((Sym.Hash >> getShift2()) % C);
    writeUint(Buf + I * Config->Wordsize, Val);
  }
}

void GnuHashTableSection::writeHashTable(uint8_t *Buf) {
  uint32_t *Buckets = reinterpret_cast<uint32_t *>(Buf);
  uint32_t OldBucket = -1;
  uint32_t *Values = Buckets + NBuckets;
  for (auto I = Symbols.begin(), E = Symbols.end(); I != E; ++I) {
    // Write a hash value. It represents a sequence of chains that share the
    // same hash modulo value. The last element of each chain is terminated by
    // LSB 1.
    uint32_t Hash = I->Hash;
    bool IsLastInChain = (I + 1) == E || I->BucketIdx != (I + 1)->BucketIdx;
    Hash = IsLastInChain ? Hash | 1 : Hash & ~1;
    write32(Values++, Hash);

    if (I->BucketIdx == OldBucket)
      continue;
    // Write a hash bucket. Hash buckets contain indices in the following hash
    // value table.
    write32(Buckets + I->BucketIdx, I->Sym->DynsymIndex);
    OldBucket = I->BucketIdx;
  }
}

static uint32_t hashGnu(StringRef Name) {
  uint32_t H = 5381;
  for (uint8_t C : Name)
    H = (H << 5) + H + C;
  return H;
}

// Add symbols to this symbol hash table. Note that this function
// destructively sort a given vector -- which is needed because
// GNU-style hash table places some sorting requirements.
void GnuHashTableSection::addSymbols(std::vector<SymbolTableEntry> &V) {
  // We cannot use 'auto' for Mid because GCC 6.1 cannot deduce
  // its type correctly.
  std::vector<SymbolTableEntry>::iterator Mid =
      std::stable_partition(V.begin(), V.end(), [](const SymbolTableEntry &S) {
        // Shared symbols that this executable preempts are special. The dynamic
        // linker has to look them up, so they have to be in the hash table.
        if (auto *SS = dyn_cast<SharedSymbol>(S.Sym))
          return SS->CopyRelSec == nullptr && !SS->NeedsPltAddr;
        return !S.Sym->isDefined();
      });
  if (Mid == V.end())
    return;

  // We chose load factor 4 for the on-disk hash table. For each hash
  // collision, the dynamic linker will compare a uint32_t hash value.
  // Since the integer comparison is quite fast, we believe we can make
  // the load factor even larger. 4 is just a conservative choice.
  NBuckets = std::max<size_t>((V.end() - Mid) / 4, 1);

  for (SymbolTableEntry &Ent : llvm::make_range(Mid, V.end())) {
    Symbol *B = Ent.Sym;
    uint32_t Hash = hashGnu(B->getName());
    uint32_t BucketIdx = Hash % NBuckets;
    Symbols.push_back({B, Ent.StrTabOffset, Hash, BucketIdx});
  }

  std::stable_sort(
      Symbols.begin(), Symbols.end(),
      [](const Entry &L, const Entry &R) { return L.BucketIdx < R.BucketIdx; });

  V.erase(Mid, V.end());
  for (const Entry &Ent : Symbols)
    V.push_back({Ent.Sym, Ent.StrTabOffset});
}

HashTableSection::HashTableSection()
    : SyntheticSection(SHF_ALLOC, SHT_HASH, 4, ".hash") {
  this->Entsize = 4;
}

void HashTableSection::finalizeContents() {
  getParent()->Link = InX::DynSymTab->getParent()->SectionIndex;

  unsigned NumEntries = 2;                       // nbucket and nchain.
  NumEntries += InX::DynSymTab->getNumSymbols(); // The chain entries.

  // Create as many buckets as there are symbols.
  NumEntries += InX::DynSymTab->getNumSymbols();
  this->Size = NumEntries * 4;
}

void HashTableSection::writeTo(uint8_t *Buf) {
  // See comment in GnuHashTableSection::writeTo.
  memset(Buf, 0, Size);

  unsigned NumSymbols = InX::DynSymTab->getNumSymbols();

  uint32_t *P = reinterpret_cast<uint32_t *>(Buf);
  write32(P++, NumSymbols); // nbucket
  write32(P++, NumSymbols); // nchain

  uint32_t *Buckets = P;
  uint32_t *Chains = P + NumSymbols;

  for (const SymbolTableEntry &S : InX::DynSymTab->getSymbols()) {
    Symbol *Sym = S.Sym;
    StringRef Name = Sym->getName();
    unsigned I = Sym->DynsymIndex;
    uint32_t Hash = hashSysV(Name) % NumSymbols;
    Chains[I] = Buckets[Hash];
    write32(Buckets + Hash, I);
  }
}

PltSection::PltSection(size_t S)
    : SyntheticSection(SHF_ALLOC | SHF_EXECINSTR, SHT_PROGBITS, 16, ".plt"),
      HeaderSize(S) {
  // The PLT needs to be writable on SPARC as the dynamic linker will
  // modify the instructions in the PLT entries.
  if (Config->EMachine == EM_SPARCV9)
    this->Flags |= SHF_WRITE;
}

void PltSection::writeTo(uint8_t *Buf) {
  // At beginning of PLT but not the IPLT, we have code to call the dynamic
  // linker to resolve dynsyms at runtime. Write such code.
  if (HeaderSize != 0)
    Target->writePltHeader(Buf);
  size_t Off = HeaderSize;
  // The IPlt is immediately after the Plt, account for this in RelOff
  unsigned PltOff = getPltRelocOff();

  for (auto &I : Entries) {
    const Symbol *B = I.first;
    unsigned RelOff = I.second + PltOff;
    uint64_t Got = B->getGotPltVA();
    uint64_t Plt = this->getVA() + Off;
    Target->writePlt(Buf + Off, Got, Plt, B->PltIndex, RelOff);
    Off += Target->PltEntrySize;
  }
}

template <class ELFT> void PltSection::addEntry(Symbol &Sym) {
  Sym.PltIndex = Entries.size();
  RelocationBaseSection *PltRelocSection = InX::RelaPlt;
  if (HeaderSize == 0) {
    PltRelocSection = InX::RelaIplt;
    Sym.IsInIplt = true;
  }
  unsigned RelOff =
      static_cast<RelocationSection<ELFT> *>(PltRelocSection)->getRelocOffset();
  Entries.push_back(std::make_pair(&Sym, RelOff));
}

size_t PltSection::getSize() const {
  return HeaderSize + Entries.size() * Target->PltEntrySize;
}

// Some architectures such as additional symbols in the PLT section. For
// example ARM uses mapping symbols to aid disassembly
void PltSection::addSymbols() {
  // The PLT may have symbols defined for the Header, the IPLT has no header
  if (HeaderSize != 0)
    Target->addPltHeaderSymbols(*this);
  size_t Off = HeaderSize;
  for (size_t I = 0; I < Entries.size(); ++I) {
    Target->addPltSymbols(*this, Off);
    Off += Target->PltEntrySize;
  }
}

unsigned PltSection::getPltRelocOff() const {
  return (HeaderSize == 0) ? InX::Plt->getSize() : 0;
}

// The string hash function for .gdb_index.
static uint32_t computeGdbHash(StringRef S) {
  uint32_t H = 0;
  for (uint8_t C : S)
    H = H * 67 + tolower(C) - 113;
  return H;
}

static std::vector<GdbIndexChunk::CuEntry> readCuList(DWARFContext &Dwarf) {
  std::vector<GdbIndexChunk::CuEntry> Ret;
  for (std::unique_ptr<DWARFCompileUnit> &Cu : Dwarf.compile_units())
    Ret.push_back({Cu->getOffset(), Cu->getLength() + 4});
  return Ret;
}

static std::vector<GdbIndexChunk::AddressEntry>
readAddressAreas(DWARFContext &Dwarf, InputSection *Sec) {
  std::vector<GdbIndexChunk::AddressEntry> Ret;

  uint32_t CuIdx = 0;
  for (std::unique_ptr<DWARFCompileUnit> &Cu : Dwarf.compile_units()) {
    DWARFAddressRangesVector Ranges;
    Cu->collectAddressRanges(Ranges);

    ArrayRef<InputSectionBase *> Sections = Sec->File->getSections();
    for (DWARFAddressRange &R : Ranges) {
      InputSectionBase *S = Sections[R.SectionIndex];
      if (!S || S == &InputSection::Discarded || !S->Live)
        continue;
      // Range list with zero size has no effect.
      if (R.LowPC == R.HighPC)
        continue;
      auto *IS = cast<InputSection>(S);
      uint64_t Offset = IS->getOffsetInFile();
      Ret.push_back({IS, R.LowPC - Offset, R.HighPC - Offset, CuIdx});
    }
    ++CuIdx;
  }
  return Ret;
}

static std::vector<GdbIndexChunk::NameTypeEntry>
readPubNamesAndTypes(DWARFContext &Dwarf) {
  StringRef Sec1 = Dwarf.getDWARFObj().getGnuPubNamesSection();
  StringRef Sec2 = Dwarf.getDWARFObj().getGnuPubTypesSection();

  std::vector<GdbIndexChunk::NameTypeEntry> Ret;
  for (StringRef Sec : {Sec1, Sec2}) {
    DWARFDebugPubTable Table(Sec, Config->IsLE, true);
    for (const DWARFDebugPubTable::Set &Set : Table.getData()) {
      for (const DWARFDebugPubTable::Entry &Ent : Set.Entries) {
        CachedHashStringRef S(Ent.Name, computeGdbHash(Ent.Name));
        Ret.push_back({S, Ent.Descriptor.toBits()});
      }
    }
  }
  return Ret;
}

static std::vector<InputSection *> getDebugInfoSections() {
  std::vector<InputSection *> Ret;
  for (InputSectionBase *S : InputSections)
    if (InputSection *IS = dyn_cast<InputSection>(S))
      if (IS->Name == ".debug_info")
        Ret.push_back(IS);
  return Ret;
}

void GdbIndexSection::fixCuIndex() {
  uint32_t Idx = 0;
  for (GdbIndexChunk &Chunk : Chunks) {
    for (GdbIndexChunk::AddressEntry &Ent : Chunk.AddressAreas)
      Ent.CuIndex += Idx;
    Idx += Chunk.CompilationUnits.size();
  }
}

std::vector<std::vector<uint32_t>> GdbIndexSection::createCuVectors() {
  std::vector<std::vector<uint32_t>> Ret;
  uint32_t Idx = 0;
  uint32_t Off = 0;

  for (GdbIndexChunk &Chunk : Chunks) {
    for (GdbIndexChunk::NameTypeEntry &Ent : Chunk.NamesAndTypes) {
      GdbSymbol *&Sym = Symbols[Ent.Name];
      if (!Sym) {
        Sym = make<GdbSymbol>(GdbSymbol{Ent.Name.hash(), Off, Ret.size()});
        Off += Ent.Name.size() + 1;
        Ret.push_back({});
      }

      // gcc 5.4.1 produces a buggy .debug_gnu_pubnames that contains
      // duplicate entries, so we want to dedup them.
      std::vector<uint32_t> &Vec = Ret[Sym->CuVectorIndex];
      uint32_t Val = (Ent.Type << 24) | Idx;
      if (Vec.empty() || Vec.back() != Val)
        Vec.push_back(Val);
    }
    Idx += Chunk.CompilationUnits.size();
  }

  StringPoolSize = Off;
  return Ret;
}

template <class ELFT> GdbIndexSection *elf::createGdbIndex() {
  // Gather debug info to create a .gdb_index section.
  std::vector<InputSection *> Sections = getDebugInfoSections();
  std::vector<GdbIndexChunk> Chunks(Sections.size());

  parallelForEachN(0, Chunks.size(), [&](size_t I) {
    ObjFile<ELFT> *File = Sections[I]->getFile<ELFT>();
    DWARFContext Dwarf(make_unique<LLDDwarfObj<ELFT>>(File));

    Chunks[I].DebugInfoSec = Sections[I];
    Chunks[I].CompilationUnits = readCuList(Dwarf);
    Chunks[I].AddressAreas = readAddressAreas(Dwarf, Sections[I]);
    Chunks[I].NamesAndTypes = readPubNamesAndTypes(Dwarf);
  });

  // .debug_gnu_pub{names,types} are useless in executables.
  // They are present in input object files solely for creating
  // a .gdb_index. So we can remove it from the output.
  for (InputSectionBase *S : InputSections)
    if (S->Name == ".debug_gnu_pubnames" || S->Name == ".debug_gnu_pubtypes")
      S->Live = false;

  // Create a .gdb_index and returns it.
  return make<GdbIndexSection>(std::move(Chunks));
}

static size_t getCuSize(ArrayRef<GdbIndexChunk> Arr) {
  size_t Ret = 0;
  for (const GdbIndexChunk &D : Arr)
    Ret += D.CompilationUnits.size();
  return Ret;
}

static size_t getAddressAreaSize(ArrayRef<GdbIndexChunk> Arr) {
  size_t Ret = 0;
  for (const GdbIndexChunk &D : Arr)
    Ret += D.AddressAreas.size();
  return Ret;
}

std::vector<GdbSymbol *> GdbIndexSection::createGdbSymtab() {
  uint32_t Size = NextPowerOf2(Symbols.size() * 4 / 3);
  if (Size < 1024)
    Size = 1024;

  uint32_t Mask = Size - 1;
  std::vector<GdbSymbol *> Ret(Size);

  for (auto &KV : Symbols) {
    GdbSymbol *Sym = KV.second;
    uint32_t I = Sym->NameHash & Mask;
    uint32_t Step = ((Sym->NameHash * 17) & Mask) | 1;

    while (Ret[I])
      I = (I + Step) & Mask;
    Ret[I] = Sym;
  }
  return Ret;
}

GdbIndexSection::GdbIndexSection(std::vector<GdbIndexChunk> &&C)
    : SyntheticSection(0, SHT_PROGBITS, 1, ".gdb_index"), Chunks(std::move(C)) {
  fixCuIndex();
  CuVectors = createCuVectors();
  GdbSymtab = createGdbSymtab();

  // Compute offsets early to know the section size.
  // Each chunk size needs to be in sync with what we write in writeTo.
  CuTypesOffset = CuListOffset + getCuSize(Chunks) * 16;
  SymtabOffset = CuTypesOffset + getAddressAreaSize(Chunks) * 20;
  ConstantPoolOffset = SymtabOffset + GdbSymtab.size() * 8;

  size_t Off = 0;
  for (ArrayRef<uint32_t> Vec : CuVectors) {
    CuVectorOffsets.push_back(Off);
    Off += (Vec.size() + 1) * 4;
  }
  StringPoolOffset = ConstantPoolOffset + Off;
}

size_t GdbIndexSection::getSize() const {
  return StringPoolOffset + StringPoolSize;
}

void GdbIndexSection::writeTo(uint8_t *Buf) {
  // Write the section header.
  write32le(Buf, 7);
  write32le(Buf + 4, CuListOffset);
  write32le(Buf + 8, CuTypesOffset);
  write32le(Buf + 12, CuTypesOffset);
  write32le(Buf + 16, SymtabOffset);
  write32le(Buf + 20, ConstantPoolOffset);
  Buf += 24;

  // Write the CU list.
  for (GdbIndexChunk &D : Chunks) {
    for (GdbIndexChunk::CuEntry &Cu : D.CompilationUnits) {
      write64le(Buf, D.DebugInfoSec->OutSecOff + Cu.CuOffset);
      write64le(Buf + 8, Cu.CuLength);
      Buf += 16;
    }
  }

  // Write the address area.
  for (GdbIndexChunk &D : Chunks) {
    for (GdbIndexChunk::AddressEntry &E : D.AddressAreas) {
      uint64_t BaseAddr =
          E.Section->getParent()->Addr + E.Section->getOffset(0);
      write64le(Buf, BaseAddr + E.LowAddress);
      write64le(Buf + 8, BaseAddr + E.HighAddress);
      write32le(Buf + 16, E.CuIndex);
      Buf += 20;
    }
  }

  // Write the symbol table.
  for (GdbSymbol *Sym : GdbSymtab) {
    if (Sym) {
      write32le(Buf, Sym->NameOffset + StringPoolOffset - ConstantPoolOffset);
      write32le(Buf + 4, CuVectorOffsets[Sym->CuVectorIndex]);
    }
    Buf += 8;
  }

  // Write the CU vectors.
  for (ArrayRef<uint32_t> Vec : CuVectors) {
    write32le(Buf, Vec.size());
    Buf += 4;
    for (uint32_t Val : Vec) {
      write32le(Buf, Val);
      Buf += 4;
    }
  }

  // Write the string pool.
  for (auto &KV : Symbols) {
    CachedHashStringRef S = KV.first;
    GdbSymbol *Sym = KV.second;
    size_t Off = Sym->NameOffset;
    memcpy(Buf + Off, S.val().data(), S.size());
    Buf[Off + S.size()] = '\0';
  }
}

bool GdbIndexSection::empty() const { return !Out::DebugInfo; }

EhFrameHeader::EhFrameHeader()
    : SyntheticSection(SHF_ALLOC, SHT_PROGBITS, 1, ".eh_frame_hdr") {}

// .eh_frame_hdr contains a binary search table of pointers to FDEs.
// Each entry of the search table consists of two values,
// the starting PC from where FDEs covers, and the FDE's address.
// It is sorted by PC.
void EhFrameHeader::writeTo(uint8_t *Buf) {
  typedef EhFrameSection::FdeData FdeData;

  std::vector<FdeData> Fdes = InX::EhFrame->getFdeData();

  // Sort the FDE list by their PC and uniqueify. Usually there is only
  // one FDE for a PC (i.e. function), but if ICF merges two functions
  // into one, there can be more than one FDEs pointing to the address.
  auto Less = [](const FdeData &A, const FdeData &B) { return A.Pc < B.Pc; };
  std::stable_sort(Fdes.begin(), Fdes.end(), Less);
  auto Eq = [](const FdeData &A, const FdeData &B) { return A.Pc == B.Pc; };
  Fdes.erase(std::unique(Fdes.begin(), Fdes.end(), Eq), Fdes.end());

  Buf[0] = 1;
  Buf[1] = DW_EH_PE_pcrel | DW_EH_PE_sdata4;
  Buf[2] = DW_EH_PE_udata4;
  Buf[3] = DW_EH_PE_datarel | DW_EH_PE_sdata4;
  write32(Buf + 4, InX::EhFrame->getParent()->Addr - this->getVA() - 4);
  write32(Buf + 8, Fdes.size());
  Buf += 12;

  uint64_t VA = this->getVA();
  for (FdeData &Fde : Fdes) {
    write32(Buf, Fde.Pc - VA);
    write32(Buf + 4, Fde.FdeVA - VA);
    Buf += 8;
  }
}

size_t EhFrameHeader::getSize() const {
  // .eh_frame_hdr has a 12 bytes header followed by an array of FDEs.
  return 12 + InX::EhFrame->NumFdes * 8;
}

bool EhFrameHeader::empty() const { return InX::EhFrame->empty(); }

template <class ELFT>
VersionDefinitionSection<ELFT>::VersionDefinitionSection()
    : SyntheticSection(SHF_ALLOC, SHT_GNU_verdef, sizeof(uint32_t),
                       ".gnu.version_d") {}

static StringRef getFileDefName() {
  if (!Config->SoName.empty())
    return Config->SoName;
  return Config->OutputFile;
}

template <class ELFT> void VersionDefinitionSection<ELFT>::finalizeContents() {
  FileDefNameOff = InX::DynStrTab->addString(getFileDefName());
  for (VersionDefinition &V : Config->VersionDefinitions)
    V.NameOff = InX::DynStrTab->addString(V.Name);

  getParent()->Link = InX::DynStrTab->getParent()->SectionIndex;

  // sh_info should be set to the number of definitions. This fact is missed in
  // documentation, but confirmed by binutils community:
  // https://sourceware.org/ml/binutils/2014-11/msg00355.html
  getParent()->Info = getVerDefNum();
}

template <class ELFT>
void VersionDefinitionSection<ELFT>::writeOne(uint8_t *Buf, uint32_t Index,
                                              StringRef Name, size_t NameOff) {
  auto *Verdef = reinterpret_cast<Elf_Verdef *>(Buf);
  Verdef->vd_version = 1;
  Verdef->vd_cnt = 1;
  Verdef->vd_aux = sizeof(Elf_Verdef);
  Verdef->vd_next = sizeof(Elf_Verdef) + sizeof(Elf_Verdaux);
  Verdef->vd_flags = (Index == 1 ? VER_FLG_BASE : 0);
  Verdef->vd_ndx = Index;
  Verdef->vd_hash = hashSysV(Name);

  auto *Verdaux = reinterpret_cast<Elf_Verdaux *>(Buf + sizeof(Elf_Verdef));
  Verdaux->vda_name = NameOff;
  Verdaux->vda_next = 0;
}

template <class ELFT>
void VersionDefinitionSection<ELFT>::writeTo(uint8_t *Buf) {
  writeOne(Buf, 1, getFileDefName(), FileDefNameOff);

  for (VersionDefinition &V : Config->VersionDefinitions) {
    Buf += sizeof(Elf_Verdef) + sizeof(Elf_Verdaux);
    writeOne(Buf, V.Id, V.Name, V.NameOff);
  }

  // Need to terminate the last version definition.
  Elf_Verdef *Verdef = reinterpret_cast<Elf_Verdef *>(Buf);
  Verdef->vd_next = 0;
}

template <class ELFT> size_t VersionDefinitionSection<ELFT>::getSize() const {
  return (sizeof(Elf_Verdef) + sizeof(Elf_Verdaux)) * getVerDefNum();
}

template <class ELFT>
VersionTableSection<ELFT>::VersionTableSection()
    : SyntheticSection(SHF_ALLOC, SHT_GNU_versym, sizeof(uint16_t),
                       ".gnu.version") {
  this->Entsize = sizeof(Elf_Versym);
}

template <class ELFT> void VersionTableSection<ELFT>::finalizeContents() {
  // At the moment of june 2016 GNU docs does not mention that sh_link field
  // should be set, but Sun docs do. Also readelf relies on this field.
  getParent()->Link = InX::DynSymTab->getParent()->SectionIndex;
}

template <class ELFT> size_t VersionTableSection<ELFT>::getSize() const {
  return sizeof(Elf_Versym) * (InX::DynSymTab->getSymbols().size() + 1);
}

template <class ELFT> void VersionTableSection<ELFT>::writeTo(uint8_t *Buf) {
  auto *OutVersym = reinterpret_cast<Elf_Versym *>(Buf) + 1;
  for (const SymbolTableEntry &S : InX::DynSymTab->getSymbols()) {
    OutVersym->vs_index = S.Sym->VersionId;
    ++OutVersym;
  }
}

template <class ELFT> bool VersionTableSection<ELFT>::empty() const {
  return !In<ELFT>::VerDef && In<ELFT>::VerNeed->empty();
}

template <class ELFT>
VersionNeedSection<ELFT>::VersionNeedSection()
    : SyntheticSection(SHF_ALLOC, SHT_GNU_verneed, sizeof(uint32_t),
                       ".gnu.version_r") {
  // Identifiers in verneed section start at 2 because 0 and 1 are reserved
  // for VER_NDX_LOCAL and VER_NDX_GLOBAL.
  // First identifiers are reserved by verdef section if it exist.
  NextIndex = getVerDefNum() + 1;
}

template <class ELFT>
void VersionNeedSection<ELFT>::addSymbol(SharedSymbol *SS) {
  SharedFile<ELFT> &File = SS->getFile<ELFT>();
  const typename ELFT::Verdef *Ver = File.Verdefs[SS->VerdefIndex];
  if (!Ver) {
    SS->VersionId = VER_NDX_GLOBAL;
    return;
  }

  // If we don't already know that we need an Elf_Verneed for this DSO, prepare
  // to create one by adding it to our needed list and creating a dynstr entry
  // for the soname.
  if (File.VerdefMap.empty())
    Needed.push_back({&File, InX::DynStrTab->addString(File.SoName)});
  typename SharedFile<ELFT>::NeededVer &NV = File.VerdefMap[Ver];
  // If we don't already know that we need an Elf_Vernaux for this Elf_Verdef,
  // prepare to create one by allocating a version identifier and creating a
  // dynstr entry for the version name.
  if (NV.Index == 0) {
    NV.StrTab = InX::DynStrTab->addString(File.getStringTable().data() +
                                          Ver->getAux()->vda_name);
    NV.Index = NextIndex++;
  }
  SS->VersionId = NV.Index;
}

template <class ELFT> void VersionNeedSection<ELFT>::writeTo(uint8_t *Buf) {
  // The Elf_Verneeds need to appear first, followed by the Elf_Vernauxs.
  auto *Verneed = reinterpret_cast<Elf_Verneed *>(Buf);
  auto *Vernaux = reinterpret_cast<Elf_Vernaux *>(Verneed + Needed.size());

  for (std::pair<SharedFile<ELFT> *, size_t> &P : Needed) {
    // Create an Elf_Verneed for this DSO.
    Verneed->vn_version = 1;
    Verneed->vn_cnt = P.first->VerdefMap.size();
    Verneed->vn_file = P.second;
    Verneed->vn_aux =
        reinterpret_cast<char *>(Vernaux) - reinterpret_cast<char *>(Verneed);
    Verneed->vn_next = sizeof(Elf_Verneed);
    ++Verneed;

    // Create the Elf_Vernauxs for this Elf_Verneed. The loop iterates over
    // VerdefMap, which will only contain references to needed version
    // definitions. Each Elf_Vernaux is based on the information contained in
    // the Elf_Verdef in the source DSO. This loop iterates over a std::map of
    // pointers, but is deterministic because the pointers refer to Elf_Verdef
    // data structures within a single input file.
    for (auto &NV : P.first->VerdefMap) {
      Vernaux->vna_hash = NV.first->vd_hash;
      Vernaux->vna_flags = 0;
      Vernaux->vna_other = NV.second.Index;
      Vernaux->vna_name = NV.second.StrTab;
      Vernaux->vna_next = sizeof(Elf_Vernaux);
      ++Vernaux;
    }

    Vernaux[-1].vna_next = 0;
  }
  Verneed[-1].vn_next = 0;
}

template <class ELFT> void VersionNeedSection<ELFT>::finalizeContents() {
  getParent()->Link = InX::DynStrTab->getParent()->SectionIndex;
  getParent()->Info = Needed.size();
}

template <class ELFT> size_t VersionNeedSection<ELFT>::getSize() const {
  unsigned Size = Needed.size() * sizeof(Elf_Verneed);
  for (const std::pair<SharedFile<ELFT> *, size_t> &P : Needed)
    Size += P.first->VerdefMap.size() * sizeof(Elf_Vernaux);
  return Size;
}

template <class ELFT> bool VersionNeedSection<ELFT>::empty() const {
  return getNeedNum() == 0;
}

void MergeSyntheticSection::addSection(MergeInputSection *MS) {
  MS->Parent = this;
  Sections.push_back(MS);
}

MergeTailSection::MergeTailSection(StringRef Name, uint32_t Type,
                                   uint64_t Flags, uint32_t Alignment)
    : MergeSyntheticSection(Name, Type, Flags, Alignment),
      Builder(StringTableBuilder::RAW, Alignment) {}

size_t MergeTailSection::getSize() const { return Builder.getSize(); }

void MergeTailSection::writeTo(uint8_t *Buf) { Builder.write(Buf); }

void MergeTailSection::finalizeContents() {
  // Add all string pieces to the string table builder to create section
  // contents.
  for (MergeInputSection *Sec : Sections)
    for (size_t I = 0, E = Sec->Pieces.size(); I != E; ++I)
      if (Sec->Pieces[I].Live)
        Builder.add(Sec->getData(I));

  // Fix the string table content. After this, the contents will never change.
  Builder.finalize();

  // finalize() fixed tail-optimized strings, so we can now get
  // offsets of strings. Get an offset for each string and save it
  // to a corresponding StringPiece for easy access.
  for (MergeInputSection *Sec : Sections)
    for (size_t I = 0, E = Sec->Pieces.size(); I != E; ++I)
      if (Sec->Pieces[I].Live)
        Sec->Pieces[I].OutputOff = Builder.getOffset(Sec->getData(I));
}

void MergeNoTailSection::writeTo(uint8_t *Buf) {
  for (size_t I = 0; I < NumShards; ++I)
    Shards[I].write(Buf + ShardOffsets[I]);
}

// This function is very hot (i.e. it can take several seconds to finish)
// because sometimes the number of inputs is in an order of magnitude of
// millions. So, we use multi-threading.
//
// For any strings S and T, we know S is not mergeable with T if S's hash
// value is different from T's. If that's the case, we can safely put S and
// T into different string builders without worrying about merge misses.
// We do it in parallel.
void MergeNoTailSection::finalizeContents() {
  // Initializes string table builders.
  for (size_t I = 0; I < NumShards; ++I)
    Shards.emplace_back(StringTableBuilder::RAW, Alignment);

  // Concurrency level. Must be a power of 2 to avoid expensive modulo
  // operations in the following tight loop.
  size_t Concurrency = 1;
  if (ThreadsEnabled)
    Concurrency =
        std::min<size_t>(PowerOf2Floor(hardware_concurrency()), NumShards);

  // Add section pieces to the builders.
  parallelForEachN(0, Concurrency, [&](size_t ThreadId) {
    for (MergeInputSection *Sec : Sections) {
      for (size_t I = 0, E = Sec->Pieces.size(); I != E; ++I) {
        size_t ShardId = getShardId(Sec->Pieces[I].Hash);
        if ((ShardId & (Concurrency - 1)) == ThreadId && Sec->Pieces[I].Live)
          Sec->Pieces[I].OutputOff = Shards[ShardId].add(Sec->getData(I));
      }
    }
  });

  // Compute an in-section offset for each shard.
  size_t Off = 0;
  for (size_t I = 0; I < NumShards; ++I) {
    Shards[I].finalizeInOrder();
    if (Shards[I].getSize() > 0)
      Off = alignTo(Off, Alignment);
    ShardOffsets[I] = Off;
    Off += Shards[I].getSize();
  }
  Size = Off;

  // So far, section pieces have offsets from beginning of shards, but
  // we want offsets from beginning of the whole section. Fix them.
  parallelForEach(Sections, [&](MergeInputSection *Sec) {
    for (size_t I = 0, E = Sec->Pieces.size(); I != E; ++I)
      if (Sec->Pieces[I].Live)
        Sec->Pieces[I].OutputOff +=
            ShardOffsets[getShardId(Sec->Pieces[I].Hash)];
  });
}

static MergeSyntheticSection *createMergeSynthetic(StringRef Name,
                                                   uint32_t Type,
                                                   uint64_t Flags,
                                                   uint32_t Alignment) {
  bool ShouldTailMerge = (Flags & SHF_STRINGS) && Config->Optimize >= 2;
  if (ShouldTailMerge)
    return make<MergeTailSection>(Name, Type, Flags, Alignment);
  return make<MergeNoTailSection>(Name, Type, Flags, Alignment);
}

// Debug sections may be compressed by zlib. Uncompress if exists.
void elf::decompressSections() {
  parallelForEach(InputSections, [](InputSectionBase *Sec) {
    if (Sec->Live)
      Sec->maybeUncompress();
  });
}

// This function scans over the inputsections to create mergeable
// synthetic sections.
//
// It removes MergeInputSections from the input section array and adds
// new synthetic sections at the location of the first input section
// that it replaces. It then finalizes each synthetic section in order
// to compute an output offset for each piece of each input section.
void elf::mergeSections() {
  // splitIntoPieces needs to be called on each MergeInputSection
  // before calling finalizeContents(). Do that first.
  parallelForEach(InputSections, [](InputSectionBase *Sec) {
    if (Sec->Live)
      if (auto *S = dyn_cast<MergeInputSection>(Sec))
        S->splitIntoPieces();
  });

  std::vector<MergeSyntheticSection *> MergeSections;
  for (InputSectionBase *&S : InputSections) {
    MergeInputSection *MS = dyn_cast<MergeInputSection>(S);
    if (!MS)
      continue;

    // We do not want to handle sections that are not alive, so just remove
    // them instead of trying to merge.
    if (!MS->Live)
      continue;

    StringRef OutsecName = getOutputSectionName(MS);
    uint32_t Alignment = std::max<uint32_t>(MS->Alignment, MS->Entsize);

    auto I = llvm::find_if(MergeSections, [=](MergeSyntheticSection *Sec) {
      // While we could create a single synthetic section for two different
      // values of Entsize, it is better to take Entsize into consideration.
      //
      // With a single synthetic section no two pieces with different Entsize
      // could be equal, so we may as well have two sections.
      //
      // Using Entsize in here also allows us to propagate it to the synthetic
      // section.
      return Sec->Name == OutsecName && Sec->Flags == MS->Flags &&
             Sec->Entsize == MS->Entsize && Sec->Alignment == Alignment;
    });
    if (I == MergeSections.end()) {
      MergeSyntheticSection *Syn =
          createMergeSynthetic(OutsecName, MS->Type, MS->Flags, Alignment);
      MergeSections.push_back(Syn);
      I = std::prev(MergeSections.end());
      S = Syn;
      Syn->Entsize = MS->Entsize;
    } else {
      S = nullptr;
    }
    (*I)->addSection(MS);
  }
  for (auto *MS : MergeSections)
    MS->finalizeContents();

  std::vector<InputSectionBase *> &V = InputSections;
  V.erase(std::remove(V.begin(), V.end(), nullptr), V.end());
}

MipsRldMapSection::MipsRldMapSection()
    : SyntheticSection(SHF_ALLOC | SHF_WRITE, SHT_PROGBITS, Config->Wordsize,
                       ".rld_map") {}

ARMExidxSentinelSection::ARMExidxSentinelSection()
    : SyntheticSection(SHF_ALLOC | SHF_LINK_ORDER, SHT_ARM_EXIDX,
                       Config->Wordsize, ".ARM.exidx") {}

// Write a terminating sentinel entry to the end of the .ARM.exidx table.
// This section will have been sorted last in the .ARM.exidx table.
// This table entry will have the form:
// | PREL31 upper bound of code that has exception tables | EXIDX_CANTUNWIND |
// The sentinel must have the PREL31 value of an address higher than any
// address described by any other table entry.
void ARMExidxSentinelSection::writeTo(uint8_t *Buf) {
  assert(Highest);
  uint64_t S =
      Highest->getParent()->Addr + Highest->getOffset(Highest->getSize());
  uint64_t P = getVA();
  Target->relocateOne(Buf, R_ARM_PREL31, S - P);
  write32le(Buf + 4, 1);
}

// The sentinel has to be removed if there are no other .ARM.exidx entries.
bool ARMExidxSentinelSection::empty() const {
  OutputSection *OS = getParent();
  for (auto *B : OS->SectionCommands)
    if (auto *ISD = dyn_cast<InputSectionDescription>(B))
      for (auto *S : ISD->Sections)
        if (!isa<ARMExidxSentinelSection>(S))
          return false;
  return true;
}

ThunkSection::ThunkSection(OutputSection *OS, uint64_t Off)
    : SyntheticSection(SHF_ALLOC | SHF_EXECINSTR, SHT_PROGBITS,
                       Config->Wordsize, ".text.thunk") {
  this->Parent = OS;
  this->OutSecOff = Off;
}

void ThunkSection::addThunk(Thunk *T) {
  uint64_t Off = alignTo(Size, T->Alignment);
  T->Offset = Off;
  Thunks.push_back(T);
  T->addSymbols(*this);
  Size = Off + T->size();
}

void ThunkSection::writeTo(uint8_t *Buf) {
  for (const Thunk *T : Thunks)
    T->writeTo(Buf + T->Offset, *this);
}

InputSection *ThunkSection::getTargetInputSection() const {
  if (Thunks.empty())
    return nullptr;
  const Thunk *T = Thunks.front();
  return T->getTargetInputSection();
}

InputSection *InX::ARMAttributes;
BssSection *InX::Bss;
BssSection *InX::BssRelRo;
BuildIdSection *InX::BuildId;
EhFrameHeader *InX::EhFrameHdr;
EhFrameSection *InX::EhFrame;
SyntheticSection *InX::Dynamic;
StringTableSection *InX::DynStrTab;
SymbolTableBaseSection *InX::DynSymTab;
InputSection *InX::Interp;
GdbIndexSection *InX::GdbIndex;
GotSection *InX::Got;
GotPltSection *InX::GotPlt;
GnuHashTableSection *InX::GnuHashTab;
HashTableSection *InX::HashTab;
IgotPltSection *InX::IgotPlt;
MipsGotSection *InX::MipsGot;
MipsRldMapSection *InX::MipsRldMap;
PltSection *InX::Plt;
PltSection *InX::Iplt;
RelocationBaseSection *InX::RelaDyn;
RelocationBaseSection *InX::RelaPlt;
RelocationBaseSection *InX::RelaIplt;
StringTableSection *InX::ShStrTab;
StringTableSection *InX::StrTab;
SymbolTableBaseSection *InX::SymTab;

template GdbIndexSection *elf::createGdbIndex<ELF32LE>();
template GdbIndexSection *elf::createGdbIndex<ELF32BE>();
template GdbIndexSection *elf::createGdbIndex<ELF64LE>();
template GdbIndexSection *elf::createGdbIndex<ELF64BE>();

template void EhFrameSection::addSection<ELF32LE>(InputSectionBase *);
template void EhFrameSection::addSection<ELF32BE>(InputSectionBase *);
template void EhFrameSection::addSection<ELF64LE>(InputSectionBase *);
template void EhFrameSection::addSection<ELF64BE>(InputSectionBase *);

template void PltSection::addEntry<ELF32LE>(Symbol &Sym);
template void PltSection::addEntry<ELF32BE>(Symbol &Sym);
template void PltSection::addEntry<ELF64LE>(Symbol &Sym);
template void PltSection::addEntry<ELF64BE>(Symbol &Sym);

template class elf::MipsAbiFlagsSection<ELF32LE>;
template class elf::MipsAbiFlagsSection<ELF32BE>;
template class elf::MipsAbiFlagsSection<ELF64LE>;
template class elf::MipsAbiFlagsSection<ELF64BE>;

template class elf::MipsOptionsSection<ELF32LE>;
template class elf::MipsOptionsSection<ELF32BE>;
template class elf::MipsOptionsSection<ELF64LE>;
template class elf::MipsOptionsSection<ELF64BE>;

template class elf::MipsReginfoSection<ELF32LE>;
template class elf::MipsReginfoSection<ELF32BE>;
template class elf::MipsReginfoSection<ELF64LE>;
template class elf::MipsReginfoSection<ELF64BE>;

template class elf::DynamicSection<ELF32LE>;
template class elf::DynamicSection<ELF32BE>;
template class elf::DynamicSection<ELF64LE>;
template class elf::DynamicSection<ELF64BE>;

template class elf::RelocationSection<ELF32LE>;
template class elf::RelocationSection<ELF32BE>;
template class elf::RelocationSection<ELF64LE>;
template class elf::RelocationSection<ELF64BE>;

template class elf::AndroidPackedRelocationSection<ELF32LE>;
template class elf::AndroidPackedRelocationSection<ELF32BE>;
template class elf::AndroidPackedRelocationSection<ELF64LE>;
template class elf::AndroidPackedRelocationSection<ELF64BE>;

template class elf::SymbolTableSection<ELF32LE>;
template class elf::SymbolTableSection<ELF32BE>;
template class elf::SymbolTableSection<ELF64LE>;
template class elf::SymbolTableSection<ELF64BE>;

template class elf::VersionTableSection<ELF32LE>;
template class elf::VersionTableSection<ELF32BE>;
template class elf::VersionTableSection<ELF64LE>;
template class elf::VersionTableSection<ELF64BE>;

template class elf::VersionNeedSection<ELF32LE>;
template class elf::VersionNeedSection<ELF32BE>;
template class elf::VersionNeedSection<ELF64LE>;
template class elf::VersionNeedSection<ELF64BE>;

template class elf::VersionDefinitionSection<ELF32LE>;
template class elf::VersionDefinitionSection<ELF32BE>;
template class elf::VersionDefinitionSection<ELF64LE>;
template class elf::VersionDefinitionSection<ELF64BE>;
