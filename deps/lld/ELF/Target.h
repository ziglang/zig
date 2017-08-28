//===- Target.h -------------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_ELF_TARGET_H
#define LLD_ELF_TARGET_H

#include "Error.h"
#include "InputSection.h"
#include "llvm/Object/ELF.h"

namespace lld {
std::string toString(uint32_t RelType);

namespace elf {
class InputFile;
class SymbolBody;

class TargetInfo {
public:
  virtual bool isPicRel(uint32_t Type) const { return true; }
  virtual uint32_t getDynRel(uint32_t Type) const { return Type; }
  virtual void writeGotPltHeader(uint8_t *Buf) const {}
  virtual void writeGotPlt(uint8_t *Buf, const SymbolBody &S) const {};
  virtual void writeIgotPlt(uint8_t *Buf, const SymbolBody &S) const;
  virtual int64_t getImplicitAddend(const uint8_t *Buf, uint32_t Type) const;

  // If lazy binding is supported, the first entry of the PLT has code
  // to call the dynamic linker to resolve PLT entries the first time
  // they are called. This function writes that code.
  virtual void writePltHeader(uint8_t *Buf) const {}

  virtual void writePlt(uint8_t *Buf, uint64_t GotEntryAddr,
                        uint64_t PltEntryAddr, int32_t Index,
                        unsigned RelOff) const {}
  virtual void addPltHeaderSymbols(InputSectionBase *IS) const {}
  virtual void addPltSymbols(InputSectionBase *IS, uint64_t Off) const {}
  // Returns true if a relocation only uses the low bits of a value such that
  // all those bits are in in the same page. For example, if the relocation
  // only uses the low 12 bits in a system with 4k pages. If this is true, the
  // bits will always have the same value at runtime and we don't have to emit
  // a dynamic relocation.
  virtual bool usesOnlyLowPageBits(uint32_t Type) const;

  // Decide whether a Thunk is needed for the relocation from File
  // targeting S.
  virtual bool needsThunk(RelExpr Expr, uint32_t RelocType,
                          const InputFile *File, const SymbolBody &S) const;
  // Return true if we can reach Dst from Src with Relocation RelocType
  virtual bool inBranchRange(uint32_t RelocType, uint64_t Src,
                             uint64_t Dst) const;
  virtual RelExpr getRelExpr(uint32_t Type, const SymbolBody &S,
                             const uint8_t *Loc) const = 0;
  virtual void relocateOne(uint8_t *Loc, uint32_t Type, uint64_t Val) const = 0;
  virtual ~TargetInfo();

  unsigned TlsGdRelaxSkip = 1;
  unsigned PageSize = 4096;
  unsigned DefaultMaxPageSize = 4096;

  // On FreeBSD x86_64 the first page cannot be mmaped.
  // On Linux that is controled by vm.mmap_min_addr. At least on some x86_64
  // installs that is 65536, so the first 15 pages cannot be used.
  // Given that, the smallest value that can be used in here is 0x10000.
  uint64_t DefaultImageBase = 0x10000;

  // Offset of _GLOBAL_OFFSET_TABLE_ from base of .got section. Use -1 for
  // end of .got
  uint64_t GotBaseSymOff = 0;

  uint32_t CopyRel;
  uint32_t GotRel;
  uint32_t PltRel;
  uint32_t RelativeRel;
  uint32_t IRelativeRel;
  uint32_t TlsDescRel;
  uint32_t TlsGotRel;
  uint32_t TlsModuleIndexRel;
  uint32_t TlsOffsetRel;
  unsigned GotEntrySize = 0;
  unsigned GotPltEntrySize = 0;
  unsigned PltEntrySize;
  unsigned PltHeaderSize;

  // At least on x86_64 positions 1 and 2 are used by the first plt entry
  // to support lazy loading.
  unsigned GotPltHeaderEntriesNum = 3;

  // Set to 0 for variant 2
  unsigned TcbSize = 0;

  bool NeedsThunks = false;

  // A 4-byte field corresponding to one or more trap instructions, used to pad
  // executable OutputSections.
  uint32_t TrapInstr = 0;

  virtual RelExpr adjustRelaxExpr(uint32_t Type, const uint8_t *Data,
                                  RelExpr Expr) const;
  virtual void relaxGot(uint8_t *Loc, uint64_t Val) const;
  virtual void relaxTlsGdToIe(uint8_t *Loc, uint32_t Type, uint64_t Val) const;
  virtual void relaxTlsGdToLe(uint8_t *Loc, uint32_t Type, uint64_t Val) const;
  virtual void relaxTlsIeToLe(uint8_t *Loc, uint32_t Type, uint64_t Val) const;
  virtual void relaxTlsLdToLe(uint8_t *Loc, uint32_t Type, uint64_t Val) const;
};

TargetInfo *getAArch64TargetInfo();
TargetInfo *getAMDGPUTargetInfo();
TargetInfo *getARMTargetInfo();
TargetInfo *getAVRTargetInfo();
TargetInfo *getPPC64TargetInfo();
TargetInfo *getPPCTargetInfo();
TargetInfo *getSPARCV9TargetInfo();
TargetInfo *getX32TargetInfo();
TargetInfo *getX86TargetInfo();
TargetInfo *getX86_64TargetInfo();
template <class ELFT> TargetInfo *getMipsTargetInfo();

std::string getErrorLocation(const uint8_t *Loc);

uint64_t getPPC64TocBase();
uint64_t getAArch64Page(uint64_t Expr);

extern TargetInfo *Target;
TargetInfo *getTarget();

template <unsigned N>
static void checkInt(uint8_t *Loc, int64_t V, uint32_t Type) {
  if (!llvm::isInt<N>(V))
    error(getErrorLocation(Loc) + "relocation " + lld::toString(Type) +
          " out of range");
}

template <unsigned N>
static void checkUInt(uint8_t *Loc, uint64_t V, uint32_t Type) {
  if (!llvm::isUInt<N>(V))
    error(getErrorLocation(Loc) + "relocation " + lld::toString(Type) +
          " out of range");
}

template <unsigned N>
static void checkIntUInt(uint8_t *Loc, uint64_t V, uint32_t Type) {
  if (!llvm::isInt<N>(V) && !llvm::isUInt<N>(V))
    error(getErrorLocation(Loc) + "relocation " + lld::toString(Type) +
          " out of range");
}

template <unsigned N>
static void checkAlignment(uint8_t *Loc, uint64_t V, uint32_t Type) {
  if ((V & (N - 1)) != 0)
    error(getErrorLocation(Loc) + "improper alignment for relocation " +
          lld::toString(Type));
}
} // namespace elf
} // namespace lld

#endif
