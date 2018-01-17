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

#include "InputSection.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/Object/ELF.h"

namespace lld {
std::string toString(elf::RelType Type);

namespace elf {
class Defined;
class InputFile;
class Symbol;

class TargetInfo {
public:
  virtual uint32_t calcEFlags() const { return 0; }
  virtual bool isPicRel(RelType Type) const { return true; }
  virtual RelType getDynRel(RelType Type) const { return Type; }
  virtual void writeGotPltHeader(uint8_t *Buf) const {}
  virtual void writeGotPlt(uint8_t *Buf, const Symbol &S) const {};
  virtual void writeIgotPlt(uint8_t *Buf, const Symbol &S) const;
  virtual int64_t getImplicitAddend(const uint8_t *Buf, RelType Type) const;

  // If lazy binding is supported, the first entry of the PLT has code
  // to call the dynamic linker to resolve PLT entries the first time
  // they are called. This function writes that code.
  virtual void writePltHeader(uint8_t *Buf) const {}

  virtual void writePlt(uint8_t *Buf, uint64_t GotEntryAddr,
                        uint64_t PltEntryAddr, int32_t Index,
                        unsigned RelOff) const {}
  virtual void addPltHeaderSymbols(InputSection &IS) const {}
  virtual void addPltSymbols(InputSection &IS, uint64_t Off) const {}

  // Returns true if a relocation only uses the low bits of a value such that
  // all those bits are in in the same page. For example, if the relocation
  // only uses the low 12 bits in a system with 4k pages. If this is true, the
  // bits will always have the same value at runtime and we don't have to emit
  // a dynamic relocation.
  virtual bool usesOnlyLowPageBits(RelType Type) const;

  // Decide whether a Thunk is needed for the relocation from File
  // targeting S.
  virtual bool needsThunk(RelExpr Expr, RelType RelocType,
                          const InputFile *File, uint64_t BranchAddr,
                          const Symbol &S) const;
  // Return true if we can reach Dst from Src with Relocation RelocType
  virtual bool inBranchRange(RelType Type, uint64_t Src,
                             uint64_t Dst) const;
  virtual RelExpr getRelExpr(RelType Type, const Symbol &S,
                             const uint8_t *Loc) const = 0;

  virtual void relocateOne(uint8_t *Loc, RelType Type, uint64_t Val) const = 0;

  virtual ~TargetInfo();

  unsigned TlsGdRelaxSkip = 1;
  unsigned PageSize = 4096;
  unsigned DefaultMaxPageSize = 4096;

  uint64_t getImageBase();

  // Offset of _GLOBAL_OFFSET_TABLE_ from base of .got section. Use -1 for
  // end of .got
  uint64_t GotBaseSymOff = 0;

  // On systems with range extensions we place collections of Thunks at
  // regular spacings that enable the majority of branches reach the Thunks.
  uint32_t ThunkSectionSpacing = 0;

  RelType CopyRel;
  RelType GotRel;
  RelType PltRel;
  RelType RelativeRel;
  RelType IRelativeRel;
  RelType TlsDescRel;
  RelType TlsGotRel;
  RelType TlsModuleIndexRel;
  RelType TlsOffsetRel;
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

  virtual RelExpr adjustRelaxExpr(RelType Type, const uint8_t *Data,
                                  RelExpr Expr) const;
  virtual void relaxGot(uint8_t *Loc, uint64_t Val) const;
  virtual void relaxTlsGdToIe(uint8_t *Loc, RelType Type, uint64_t Val) const;
  virtual void relaxTlsGdToLe(uint8_t *Loc, RelType Type, uint64_t Val) const;
  virtual void relaxTlsIeToLe(uint8_t *Loc, RelType Type, uint64_t Val) const;
  virtual void relaxTlsLdToLe(uint8_t *Loc, RelType Type, uint64_t Val) const;

protected:
  // On FreeBSD x86_64 the first page cannot be mmaped.
  // On Linux that is controled by vm.mmap_min_addr. At least on some x86_64
  // installs that is 65536, so the first 15 pages cannot be used.
  // Given that, the smallest value that can be used in here is 0x10000.
  uint64_t DefaultImageBase = 0x10000;
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

template <class ELFT> bool isMipsPIC(const Defined *Sym);

static inline void reportRangeError(uint8_t *Loc, RelType Type, const Twine &V,
                                    int64_t Min, uint64_t Max) {
  error(getErrorLocation(Loc) + "relocation " + lld::toString(Type) +
        " out of range: " + V + " is not in [" + Twine(Min) + ", " +
        Twine(Max) + "]");
}

template <unsigned N>
static void checkInt(uint8_t *Loc, int64_t V, RelType Type) {
  if (!llvm::isInt<N>(V))
    reportRangeError(Loc, Type, Twine(V), llvm::minIntN(N), llvm::maxIntN(N));
}

template <unsigned N>
static void checkUInt(uint8_t *Loc, uint64_t V, RelType Type) {
  if (!llvm::isUInt<N>(V))
    reportRangeError(Loc, Type, Twine(V), 0, llvm::maxUIntN(N));
}

template <unsigned N>
static void checkIntUInt(uint8_t *Loc, uint64_t V, RelType Type) {
  if (!llvm::isInt<N>(V) && !llvm::isUInt<N>(V))
    // For the error message we should cast V to a signed integer so that error
    // messages show a small negative value rather than an extremely large one
    reportRangeError(Loc, Type, Twine((int64_t)V), llvm::minIntN(N),
                     llvm::maxUIntN(N));
}

template <unsigned N>
static void checkAlignment(uint8_t *Loc, uint64_t V, RelType Type) {
  if ((V & (N - 1)) != 0)
    error(getErrorLocation(Loc) + "improper alignment for relocation " +
          lld::toString(Type) + ": 0x" + llvm::utohexstr(V) +
          " is not aligned to " + Twine(N) + " bytes");
}
} // namespace elf
} // namespace lld

#endif
