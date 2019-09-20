//===- Target.h -------------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_ELF_TARGET_H
#define LLD_ELF_TARGET_H

#include "InputSection.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/Object/ELF.h"
#include "llvm/Support/MathExtras.h"
#include <array>

namespace lld {
std::string toString(elf::RelType type);

namespace elf {
class Defined;
class InputFile;
class Symbol;

class TargetInfo {
public:
  virtual uint32_t calcEFlags() const { return 0; }
  virtual RelExpr getRelExpr(RelType type, const Symbol &s,
                             const uint8_t *loc) const = 0;
  virtual RelType getDynRel(RelType type) const { return 0; }
  virtual void writeGotPltHeader(uint8_t *buf) const {}
  virtual void writeGotHeader(uint8_t *buf) const {}
  virtual void writeGotPlt(uint8_t *buf, const Symbol &s) const {};
  virtual void writeIgotPlt(uint8_t *buf, const Symbol &s) const;
  virtual int64_t getImplicitAddend(const uint8_t *buf, RelType type) const;
  virtual int getTlsGdRelaxSkip(RelType type) const { return 1; }

  // If lazy binding is supported, the first entry of the PLT has code
  // to call the dynamic linker to resolve PLT entries the first time
  // they are called. This function writes that code.
  virtual void writePltHeader(uint8_t *buf) const {}

  virtual void writePlt(uint8_t *buf, uint64_t gotEntryAddr,
                        uint64_t pltEntryAddr, int32_t index,
                        unsigned relOff) const {}
  virtual void addPltHeaderSymbols(InputSection &isec) const {}
  virtual void addPltSymbols(InputSection &isec, uint64_t off) const {}

  // Returns true if a relocation only uses the low bits of a value such that
  // all those bits are in the same page. For example, if the relocation
  // only uses the low 12 bits in a system with 4k pages. If this is true, the
  // bits will always have the same value at runtime and we don't have to emit
  // a dynamic relocation.
  virtual bool usesOnlyLowPageBits(RelType type) const;

  // Decide whether a Thunk is needed for the relocation from File
  // targeting S.
  virtual bool needsThunk(RelExpr expr, RelType relocType,
                          const InputFile *file, uint64_t branchAddr,
                          const Symbol &s) const;

  // On systems with range extensions we place collections of Thunks at
  // regular spacings that enable the majority of branches reach the Thunks.
  // a value of 0 means range extension thunks are not supported.
  virtual uint32_t getThunkSectionSpacing() const { return 0; }

  // The function with a prologue starting at Loc was compiled with
  // -fsplit-stack and it calls a function compiled without. Adjust the prologue
  // to do the right thing. See https://gcc.gnu.org/wiki/SplitStacks.
  // The symbols st_other flags are needed on PowerPC64 for determining the
  // offset to the split-stack prologue.
  virtual bool adjustPrologueForCrossSplitStack(uint8_t *loc, uint8_t *end,
                                                uint8_t stOther) const;

  // Return true if we can reach dst from src with RelType type.
  virtual bool inBranchRange(RelType type, uint64_t src,
                             uint64_t dst) const;

  virtual void relocateOne(uint8_t *loc, RelType type, uint64_t val) const = 0;

  virtual ~TargetInfo();

  unsigned defaultCommonPageSize = 4096;
  unsigned defaultMaxPageSize = 4096;

  uint64_t getImageBase() const;

  // True if _GLOBAL_OFFSET_TABLE_ is relative to .got.plt, false if .got.
  bool gotBaseSymInGotPlt = true;

  RelType copyRel;
  RelType gotRel;
  RelType noneRel;
  RelType pltRel;
  RelType relativeRel;
  RelType iRelativeRel;
  RelType symbolicRel;
  RelType tlsDescRel;
  RelType tlsGotRel;
  RelType tlsModuleIndexRel;
  RelType tlsOffsetRel;
  unsigned pltEntrySize;
  unsigned pltHeaderSize;

  // At least on x86_64 positions 1 and 2 are used by the first plt entry
  // to support lazy loading.
  unsigned gotPltHeaderEntriesNum = 3;

  // On PPC ELF V2 abi, the first entry in the .got is the .TOC.
  unsigned gotHeaderEntriesNum = 0;

  bool needsThunks = false;

  // A 4-byte field corresponding to one or more trap instructions, used to pad
  // executable OutputSections.
  std::array<uint8_t, 4> trapInstr;

  // If a target needs to rewrite calls to __morestack to instead call
  // __morestack_non_split when a split-stack enabled caller calls a
  // non-split-stack callee this will return true. Otherwise returns false.
  bool needsMoreStackNonSplit = true;

  virtual RelExpr adjustRelaxExpr(RelType type, const uint8_t *data,
                                  RelExpr expr) const;
  virtual void relaxGot(uint8_t *loc, RelType type, uint64_t val) const;
  virtual void relaxTlsGdToIe(uint8_t *loc, RelType type, uint64_t val) const;
  virtual void relaxTlsGdToLe(uint8_t *loc, RelType type, uint64_t val) const;
  virtual void relaxTlsIeToLe(uint8_t *loc, RelType type, uint64_t val) const;
  virtual void relaxTlsLdToLe(uint8_t *loc, RelType type, uint64_t val) const;

protected:
  // On FreeBSD x86_64 the first page cannot be mmaped.
  // On Linux that is controled by vm.mmap_min_addr. At least on some x86_64
  // installs that is 65536, so the first 15 pages cannot be used.
  // Given that, the smallest value that can be used in here is 0x10000.
  uint64_t defaultImageBase = 0x10000;
};

TargetInfo *getAArch64TargetInfo();
TargetInfo *getAMDGPUTargetInfo();
TargetInfo *getARMTargetInfo();
TargetInfo *getAVRTargetInfo();
TargetInfo *getHexagonTargetInfo();
TargetInfo *getMSP430TargetInfo();
TargetInfo *getPPC64TargetInfo();
TargetInfo *getPPCTargetInfo();
TargetInfo *getRISCVTargetInfo();
TargetInfo *getSPARCV9TargetInfo();
TargetInfo *getX86TargetInfo();
TargetInfo *getX86_64TargetInfo();
template <class ELFT> TargetInfo *getMipsTargetInfo();

struct ErrorPlace {
  InputSectionBase *isec;
  std::string loc;
};

// Returns input section and corresponding source string for the given location.
ErrorPlace getErrorPlace(const uint8_t *loc);

static inline std::string getErrorLocation(const uint8_t *loc) {
  return getErrorPlace(loc).loc;
}

void writePPC32GlinkSection(uint8_t *buf, size_t numEntries);

bool tryRelaxPPC64TocIndirection(RelType type, const Relocation &rel,
                                 uint8_t *bufLoc);
unsigned getPPCDFormOp(unsigned secondaryOp);

// In the PowerPC64 Elf V2 abi a function can have 2 entry points.  The first
// is a global entry point (GEP) which typically is used to initialize the TOC
// pointer in general purpose register 2.  The second is a local entry
// point (LEP) which bypasses the TOC pointer initialization code. The
// offset between GEP and LEP is encoded in a function's st_other flags.
// This function will return the offset (in bytes) from the global entry-point
// to the local entry-point.
unsigned getPPC64GlobalEntryToLocalEntryOffset(uint8_t stOther);

// Returns true if a relocation is a small code model relocation that accesses
// the .toc section.
bool isPPC64SmallCodeModelTocReloc(RelType type);

uint64_t getPPC64TocBase();
uint64_t getAArch64Page(uint64_t expr);

extern const TargetInfo *target;
TargetInfo *getTarget();

template <class ELFT> bool isMipsPIC(const Defined *sym);

static inline void reportRangeError(uint8_t *loc, RelType type, const Twine &v,
                                    int64_t min, uint64_t max) {
  ErrorPlace errPlace = getErrorPlace(loc);
  StringRef hint;
  if (errPlace.isec && errPlace.isec->name.startswith(".debug"))
    hint = "; consider recompiling with -fdebug-types-section to reduce size "
           "of debug sections";

  errorOrWarn(errPlace.loc + "relocation " + lld::toString(type) +
              " out of range: " + v.str() + " is not in [" + Twine(min).str() +
              ", " + Twine(max).str() + "]" + hint);
}

// Make sure that V can be represented as an N bit signed integer.
inline void checkInt(uint8_t *loc, int64_t v, int n, RelType type) {
  if (v != llvm::SignExtend64(v, n))
    reportRangeError(loc, type, Twine(v), llvm::minIntN(n), llvm::maxIntN(n));
}

// Make sure that V can be represented as an N bit unsigned integer.
inline void checkUInt(uint8_t *loc, uint64_t v, int n, RelType type) {
  if ((v >> n) != 0)
    reportRangeError(loc, type, Twine(v), 0, llvm::maxUIntN(n));
}

// Make sure that V can be represented as an N bit signed or unsigned integer.
inline void checkIntUInt(uint8_t *loc, uint64_t v, int n, RelType type) {
  // For the error message we should cast V to a signed integer so that error
  // messages show a small negative value rather than an extremely large one
  if (v != (uint64_t)llvm::SignExtend64(v, n) && (v >> n) != 0)
    reportRangeError(loc, type, Twine((int64_t)v), llvm::minIntN(n),
                     llvm::maxUIntN(n));
}

inline void checkAlignment(uint8_t *loc, uint64_t v, int n, RelType type) {
  if ((v & (n - 1)) != 0)
    error(getErrorLocation(loc) + "improper alignment for relocation " +
          lld::toString(type) + ": 0x" + llvm::utohexstr(v) +
          " is not aligned to " + Twine(n) + " bytes");
}

// Endianness-aware read/write.
inline uint16_t read16(const void *p) {
  return llvm::support::endian::read16(p, config->endianness);
}

inline uint32_t read32(const void *p) {
  return llvm::support::endian::read32(p, config->endianness);
}

inline uint64_t read64(const void *p) {
  return llvm::support::endian::read64(p, config->endianness);
}

inline void write16(void *p, uint16_t v) {
  llvm::support::endian::write16(p, v, config->endianness);
}

inline void write32(void *p, uint32_t v) {
  llvm::support::endian::write32(p, v, config->endianness);
}

inline void write64(void *p, uint64_t v) {
  llvm::support::endian::write64(p, v, config->endianness);
}
} // namespace elf
} // namespace lld

#endif
