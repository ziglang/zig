//===- PPC64.cpp ----------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "Symbols.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/Support/Endian.h"

using namespace llvm;
using namespace llvm::object;
using namespace llvm::support::endian;
using namespace llvm::ELF;
using namespace lld;
using namespace lld::elf;

static uint64_t PPC64TocOffset = 0x8000;
static uint64_t DynamicThreadPointerOffset = 0x8000;

uint64_t elf::getPPC64TocBase() {
  // The TOC consists of sections .got, .toc, .tocbss, .plt in that order. The
  // TOC starts where the first of these sections starts. We always create a
  // .got when we see a relocation that uses it, so for us the start is always
  // the .got.
  uint64_t TocVA = InX::Got->getVA();

  // Per the ppc64-elf-linux ABI, The TOC base is TOC value plus 0x8000
  // thus permitting a full 64 Kbytes segment. Note that the glibc startup
  // code (crt1.o) assumes that you can get from the TOC base to the
  // start of the .toc section with only a single (signed) 16-bit relocation.
  return TocVA + PPC64TocOffset;
}

namespace {
class PPC64 final : public TargetInfo {
public:
  PPC64();
  uint32_t calcEFlags() const override;
  RelExpr getRelExpr(RelType Type, const Symbol &S,
                     const uint8_t *Loc) const override;
  void writePltHeader(uint8_t *Buf) const override;
  void writePlt(uint8_t *Buf, uint64_t GotPltEntryAddr, uint64_t PltEntryAddr,
                int32_t Index, unsigned RelOff) const override;
  void relocateOne(uint8_t *Loc, RelType Type, uint64_t Val) const override;
  void writeGotHeader(uint8_t *Buf) const override;
  bool needsThunk(RelExpr Expr, RelType Type, const InputFile *File,
                  uint64_t BranchAddr, const Symbol &S) const override;
  RelExpr adjustRelaxExpr(RelType Type, const uint8_t *Data,
                          RelExpr Expr) const override;
  void relaxTlsGdToIe(uint8_t *Loc, RelType Type, uint64_t Val) const override;
  void relaxTlsGdToLe(uint8_t *Loc, RelType Type, uint64_t Val) const override;
  void relaxTlsLdToLe(uint8_t *Loc, RelType Type, uint64_t Val) const override;
};
} // namespace

// Relocation masks following the #lo(value), #hi(value), #ha(value),
// #higher(value), #highera(value), #highest(value), and #highesta(value)
// macros defined in section 4.5.1. Relocation Types of the PPC-elf64abi
// document.
static uint16_t lo(uint64_t V) { return V; }
static uint16_t hi(uint64_t V) { return V >> 16; }
static uint16_t ha(uint64_t V) { return (V + 0x8000) >> 16; }
static uint16_t higher(uint64_t V) { return V >> 32; }
static uint16_t highera(uint64_t V) { return (V + 0x8000) >> 32; }
static uint16_t highest(uint64_t V) { return V >> 48; }
static uint16_t highesta(uint64_t V) { return (V + 0x8000) >> 48; }

PPC64::PPC64() {
  GotRel = R_PPC64_GLOB_DAT;
  PltRel = R_PPC64_JMP_SLOT;
  RelativeRel = R_PPC64_RELATIVE;
  IRelativeRel = R_PPC64_IRELATIVE;
  GotEntrySize = 8;
  PltEntrySize = 4;
  GotPltEntrySize = 8;
  GotBaseSymInGotPlt = false;
  GotBaseSymOff = 0x8000;
  GotHeaderEntriesNum = 1;
  GotPltHeaderEntriesNum = 2;
  PltHeaderSize = 60;
  NeedsThunks = true;
  TcbSize = 8;
  TlsTpOffset = 0x7000;

  TlsModuleIndexRel = R_PPC64_DTPMOD64;
  TlsOffsetRel = R_PPC64_DTPREL64;

  TlsGotRel = R_PPC64_TPREL64;

  // We need 64K pages (at least under glibc/Linux, the loader won't
  // set different permissions on a finer granularity than that).
  DefaultMaxPageSize = 65536;

  // The PPC64 ELF ABI v1 spec, says:
  //
  //   It is normally desirable to put segments with different characteristics
  //   in separate 256 Mbyte portions of the address space, to give the
  //   operating system full paging flexibility in the 64-bit address space.
  //
  // And because the lowest non-zero 256M boundary is 0x10000000, PPC64 linkers
  // use 0x10000000 as the starting address.
  DefaultImageBase = 0x10000000;

  TrapInstr =
      (Config->IsLE == sys::IsLittleEndianHost) ? 0x7fe00008 : 0x0800e07f;
}

static uint32_t getEFlags(InputFile *File) {
  if (Config->EKind == ELF64BEKind)
    return cast<ObjFile<ELF64BE>>(File)->getObj().getHeader()->e_flags;
  return cast<ObjFile<ELF64LE>>(File)->getObj().getHeader()->e_flags;
}

// This file implements v2 ABI. This function makes sure that all
// object files have v2 or an unspecified version as an ABI version.
uint32_t PPC64::calcEFlags() const {
  for (InputFile *F : ObjectFiles) {
    uint32_t Flag = getEFlags(F);
    if (Flag == 1)
      error(toString(F) + ": ABI version 1 is not supported");
    else if (Flag > 2)
      error(toString(F) + ": unrecognized e_flags: " + Twine(Flag));
  }
  return 2;
}

void PPC64::relaxTlsGdToLe(uint8_t *Loc, RelType Type, uint64_t Val) const {
  // Reference: 3.7.4.2 of the 64-bit ELF V2 abi supplement.
  // The general dynamic code sequence for a global `x` will look like:
  // Instruction                    Relocation                Symbol
  // addis r3, r2, x@got@tlsgd@ha   R_PPC64_GOT_TLSGD16_HA      x
  // addi  r3, r3, x@got@tlsgd@l    R_PPC64_GOT_TLSGD16_LO      x
  // bl __tls_get_addr(x@tlsgd)     R_PPC64_TLSGD               x
  //                                R_PPC64_REL24               __tls_get_addr
  // nop                            None                       None

  // Relaxing to local exec entails converting:
  // addis r3, r2, x@got@tlsgd@ha    into      nop
  // addi  r3, r3, x@got@tlsgd@l     into      addis r3, r13, x@tprel@ha
  // bl __tls_get_addr(x@tlsgd)      into      nop
  // nop                             into      addi r3, r3, x@tprel@l

  uint32_t EndianOffset = Config->EKind == ELF64BEKind ? 2U : 0U;

  switch (Type) {
  case R_PPC64_GOT_TLSGD16_HA:
    write32(Loc - EndianOffset, 0x60000000); // nop
    break;
  case R_PPC64_GOT_TLSGD16_LO:
    write32(Loc - EndianOffset, 0x3c6d0000); // addis r3, r13
    relocateOne(Loc, R_PPC64_TPREL16_HA, Val);
    break;
  case R_PPC64_TLSGD:
    write32(Loc, 0x60000000);     // nop
    write32(Loc + 4, 0x38630000); // addi r3, r3
    relocateOne(Loc + 4 + EndianOffset, R_PPC64_TPREL16_LO, Val);
    break;
  default:
    llvm_unreachable("unsupported relocation for TLS GD to LE relaxation");
  }
}


void PPC64::relaxTlsLdToLe(uint8_t *Loc, RelType Type, uint64_t Val) const {
  // Reference: 3.7.4.3 of the 64-bit ELF V2 abi supplement.
  // The local dynamic code sequence for a global `x` will look like:
  // Instruction                    Relocation                Symbol
  // addis r3, r2, x@got@tlsld@ha   R_PPC64_GOT_TLSLD16_HA      x
  // addi  r3, r3, x@got@tlsld@l    R_PPC64_GOT_TLSLD16_LO      x
  // bl __tls_get_addr(x@tlsgd)     R_PPC64_TLSLD               x
  //                                R_PPC64_REL24               __tls_get_addr
  // nop                            None                       None

  // Relaxing to local exec entails converting:
  // addis r3, r2, x@got@tlsld@ha   into      nop
  // addi  r3, r3, x@got@tlsld@l    into      addis r3, r13, 0
  // bl __tls_get_addr(x@tlsgd)     into      nop
  // nop                            into      addi r3, r3, 4096

  uint32_t EndianOffset = Config->EKind == ELF64BEKind ? 2U : 0U;
  switch (Type) {
  case R_PPC64_GOT_TLSLD16_HA:
    write32(Loc - EndianOffset, 0x60000000); // nop
    break;
  case R_PPC64_GOT_TLSLD16_LO:
    write32(Loc - EndianOffset, 0x3c6d0000); // addis r3, r13, 0
    break;
  case R_PPC64_TLSLD:
    write32(Loc, 0x60000000);     // nop
    write32(Loc + 4, 0x38631000); // addi r3, r3, 4096
    break;
  case R_PPC64_DTPREL16:
  case R_PPC64_DTPREL16_HA:
  case R_PPC64_DTPREL16_HI:
  case R_PPC64_DTPREL16_DS:
  case R_PPC64_DTPREL16_LO:
  case R_PPC64_DTPREL16_LO_DS:
  case R_PPC64_GOT_DTPREL16_HA:
  case R_PPC64_GOT_DTPREL16_LO_DS:
  case R_PPC64_GOT_DTPREL16_DS:
  case R_PPC64_GOT_DTPREL16_HI:
    relocateOne(Loc, Type, Val);
    break;
  default:
    llvm_unreachable("unsupported relocation for TLS LD to LE relaxation");
  }
}

RelExpr PPC64::getRelExpr(RelType Type, const Symbol &S,
                          const uint8_t *Loc) const {
  switch (Type) {
  case R_PPC64_TOC16:
  case R_PPC64_TOC16_DS:
  case R_PPC64_TOC16_HA:
  case R_PPC64_TOC16_HI:
  case R_PPC64_TOC16_LO:
  case R_PPC64_TOC16_LO_DS:
    return R_GOTREL;
  case R_PPC64_TOC:
    return R_PPC_TOC;
  case R_PPC64_REL24:
    return R_PPC_CALL_PLT;
  case R_PPC64_REL16_LO:
  case R_PPC64_REL16_HA:
  case R_PPC64_REL32:
  case R_PPC64_REL64:
    return R_PC;
  case R_PPC64_GOT_TLSGD16:
  case R_PPC64_GOT_TLSGD16_HA:
  case R_PPC64_GOT_TLSGD16_HI:
  case R_PPC64_GOT_TLSGD16_LO:
    return R_TLSGD_GOT;
  case R_PPC64_GOT_TLSLD16:
  case R_PPC64_GOT_TLSLD16_HA:
  case R_PPC64_GOT_TLSLD16_HI:
  case R_PPC64_GOT_TLSLD16_LO:
    return R_TLSLD_GOT;
  case R_PPC64_GOT_TPREL16_HA:
  case R_PPC64_GOT_TPREL16_LO_DS:
  case R_PPC64_GOT_TPREL16_DS:
  case R_PPC64_GOT_TPREL16_HI:
    return R_GOT_OFF;
  case R_PPC64_GOT_DTPREL16_HA:
  case R_PPC64_GOT_DTPREL16_LO_DS:
  case R_PPC64_GOT_DTPREL16_DS:
  case R_PPC64_GOT_DTPREL16_HI:
    return R_TLSLD_GOT_OFF;
  case R_PPC64_TPREL16:
  case R_PPC64_TPREL16_HA:
  case R_PPC64_TPREL16_LO:
  case R_PPC64_TPREL16_HI:
  case R_PPC64_TPREL16_DS:
  case R_PPC64_TPREL16_LO_DS:
  case R_PPC64_TPREL16_HIGHER:
  case R_PPC64_TPREL16_HIGHERA:
  case R_PPC64_TPREL16_HIGHEST:
  case R_PPC64_TPREL16_HIGHESTA:
    return R_TLS;
  case R_PPC64_DTPREL16:
  case R_PPC64_DTPREL16_DS:
  case R_PPC64_DTPREL16_HA:
  case R_PPC64_DTPREL16_HI:
  case R_PPC64_DTPREL16_HIGHER:
  case R_PPC64_DTPREL16_HIGHERA:
  case R_PPC64_DTPREL16_HIGHEST:
  case R_PPC64_DTPREL16_HIGHESTA:
  case R_PPC64_DTPREL16_LO:
  case R_PPC64_DTPREL16_LO_DS:
  case R_PPC64_DTPREL64:
    return R_ABS;
  case R_PPC64_TLSGD:
    return R_TLSDESC_CALL;
  case R_PPC64_TLSLD:
    return R_TLSLD_HINT;
  case R_PPC64_TLS:
    return R_HINT;
  default:
    return R_ABS;
  }
}

void PPC64::writeGotHeader(uint8_t *Buf) const {
  write64(Buf, getPPC64TocBase());
}

void PPC64::writePltHeader(uint8_t *Buf) const {
  // The generic resolver stub goes first.
  write32(Buf +  0, 0x7c0802a6); // mflr r0
  write32(Buf +  4, 0x429f0005); // bcl  20,4*cr7+so,8 <_glink+0x8>
  write32(Buf +  8, 0x7d6802a6); // mflr r11
  write32(Buf + 12, 0x7c0803a6); // mtlr r0
  write32(Buf + 16, 0x7d8b6050); // subf r12, r11, r12
  write32(Buf + 20, 0x380cffcc); // subi r0,r12,52
  write32(Buf + 24, 0x7800f082); // srdi r0,r0,62,2
  write32(Buf + 28, 0xe98b002c); // ld   r12,44(r11)
  write32(Buf + 32, 0x7d6c5a14); // add  r11,r12,r11
  write32(Buf + 36, 0xe98b0000); // ld   r12,0(r11)
  write32(Buf + 40, 0xe96b0008); // ld   r11,8(r11)
  write32(Buf + 44, 0x7d8903a6); // mtctr   r12
  write32(Buf + 48, 0x4e800420); // bctr

  // The 'bcl' instruction will set the link register to the address of the
  // following instruction ('mflr r11'). Here we store the offset from that
  // instruction  to the first entry in the GotPlt section.
  int64_t GotPltOffset = InX::GotPlt->getVA() - (InX::Plt->getVA() + 8);
  write64(Buf + 52, GotPltOffset);
}

void PPC64::writePlt(uint8_t *Buf, uint64_t GotPltEntryAddr,
                     uint64_t PltEntryAddr, int32_t Index,
                     unsigned RelOff) const {
 int32_t Offset = PltHeaderSize + Index * PltEntrySize;
 // bl __glink_PLTresolve
 write32(Buf, 0x48000000 | ((-Offset) & 0x03FFFFFc));
}

static std::pair<RelType, uint64_t> toAddr16Rel(RelType Type, uint64_t Val) {
  // Relocations relative to the toc-base need to be adjusted by the Toc offset.
  uint64_t TocBiasedVal = Val - PPC64TocOffset;
  // Relocations relative to dtv[dtpmod] need to be adjusted by the DTP offset.
  uint64_t DTPBiasedVal = Val - DynamicThreadPointerOffset;

  switch (Type) {
  // TOC biased relocation.
  case R_PPC64_GOT_TLSGD16:
  case R_PPC64_GOT_TLSLD16:
  case R_PPC64_TOC16:
    return {R_PPC64_ADDR16, TocBiasedVal};
  case R_PPC64_TOC16_DS:
  case R_PPC64_GOT_TPREL16_DS:
  case R_PPC64_GOT_DTPREL16_DS:
    return {R_PPC64_ADDR16_DS, TocBiasedVal};
  case R_PPC64_GOT_TLSGD16_HA:
  case R_PPC64_GOT_TLSLD16_HA:
  case R_PPC64_GOT_TPREL16_HA:
  case R_PPC64_GOT_DTPREL16_HA:
  case R_PPC64_TOC16_HA:
    return {R_PPC64_ADDR16_HA, TocBiasedVal};
  case R_PPC64_GOT_TLSGD16_HI:
  case R_PPC64_GOT_TLSLD16_HI:
  case R_PPC64_GOT_TPREL16_HI:
  case R_PPC64_GOT_DTPREL16_HI:
  case R_PPC64_TOC16_HI:
    return {R_PPC64_ADDR16_HI, TocBiasedVal};
  case R_PPC64_GOT_TLSGD16_LO:
  case R_PPC64_GOT_TLSLD16_LO:
  case R_PPC64_TOC16_LO:
    return {R_PPC64_ADDR16_LO, TocBiasedVal};
  case R_PPC64_TOC16_LO_DS:
  case R_PPC64_GOT_TPREL16_LO_DS:
  case R_PPC64_GOT_DTPREL16_LO_DS:
    return {R_PPC64_ADDR16_LO_DS, TocBiasedVal};

  // Dynamic Thread pointer biased relocation types.
  case R_PPC64_DTPREL16:
    return {R_PPC64_ADDR16, DTPBiasedVal};
  case R_PPC64_DTPREL16_DS:
    return {R_PPC64_ADDR16_DS, DTPBiasedVal};
  case R_PPC64_DTPREL16_HA:
    return {R_PPC64_ADDR16_HA, DTPBiasedVal};
  case R_PPC64_DTPREL16_HI:
    return {R_PPC64_ADDR16_HI, DTPBiasedVal};
  case R_PPC64_DTPREL16_HIGHER:
    return {R_PPC64_ADDR16_HIGHER, DTPBiasedVal};
  case R_PPC64_DTPREL16_HIGHERA:
    return {R_PPC64_ADDR16_HIGHERA, DTPBiasedVal};
  case R_PPC64_DTPREL16_HIGHEST:
    return {R_PPC64_ADDR16_HIGHEST, DTPBiasedVal};
  case R_PPC64_DTPREL16_HIGHESTA:
    return {R_PPC64_ADDR16_HIGHESTA, DTPBiasedVal};
  case R_PPC64_DTPREL16_LO:
    return {R_PPC64_ADDR16_LO, DTPBiasedVal};
  case R_PPC64_DTPREL16_LO_DS:
    return {R_PPC64_ADDR16_LO_DS, DTPBiasedVal};
  case R_PPC64_DTPREL64:
    return {R_PPC64_ADDR64, DTPBiasedVal};

  default:
    return {Type, Val};
  }
}

void PPC64::relocateOne(uint8_t *Loc, RelType Type, uint64_t Val) const {
  // For a TOC-relative relocation, proceed in terms of the corresponding
  // ADDR16 relocation type.
  std::tie(Type, Val) = toAddr16Rel(Type, Val);

  switch (Type) {
  case R_PPC64_ADDR14: {
    checkAlignment(Loc, Val, 4, Type);
    // Preserve the AA/LK bits in the branch instruction
    uint8_t AALK = Loc[3];
    write16(Loc + 2, (AALK & 3) | (Val & 0xfffc));
    break;
  }
  case R_PPC64_ADDR16:
  case R_PPC64_TPREL16:
    checkInt(Loc, Val, 16, Type);
    write16(Loc, Val);
    break;
  case R_PPC64_ADDR16_DS:
  case R_PPC64_TPREL16_DS:
    checkInt(Loc, Val, 16, Type);
    write16(Loc, (read16(Loc) & 3) | (Val & ~3));
    break;
  case R_PPC64_ADDR16_HA:
  case R_PPC64_REL16_HA:
  case R_PPC64_TPREL16_HA:
    write16(Loc, ha(Val));
    break;
  case R_PPC64_ADDR16_HI:
  case R_PPC64_REL16_HI:
  case R_PPC64_TPREL16_HI:
    write16(Loc, hi(Val));
    break;
  case R_PPC64_ADDR16_HIGHER:
  case R_PPC64_TPREL16_HIGHER:
    write16(Loc, higher(Val));
    break;
  case R_PPC64_ADDR16_HIGHERA:
  case R_PPC64_TPREL16_HIGHERA:
    write16(Loc, highera(Val));
    break;
  case R_PPC64_ADDR16_HIGHEST:
  case R_PPC64_TPREL16_HIGHEST:
    write16(Loc, highest(Val));
    break;
  case R_PPC64_ADDR16_HIGHESTA:
  case R_PPC64_TPREL16_HIGHESTA:
    write16(Loc, highesta(Val));
    break;
  case R_PPC64_ADDR16_LO:
  case R_PPC64_REL16_LO:
  case R_PPC64_TPREL16_LO:
    write16(Loc, lo(Val));
    break;
  case R_PPC64_ADDR16_LO_DS:
  case R_PPC64_TPREL16_LO_DS:
    write16(Loc, (read16(Loc) & 3) | (lo(Val) & ~3));
    break;
  case R_PPC64_ADDR32:
  case R_PPC64_REL32:
    checkInt(Loc, Val, 32, Type);
    write32(Loc, Val);
    break;
  case R_PPC64_ADDR64:
  case R_PPC64_REL64:
  case R_PPC64_TOC:
    write64(Loc, Val);
    break;
  case R_PPC64_REL24: {
    uint32_t Mask = 0x03FFFFFC;
    checkInt(Loc, Val, 24, Type);
    write32(Loc, (read32(Loc) & ~Mask) | (Val & Mask));
    break;
  }
  case R_PPC64_DTPREL64:
    write64(Loc, Val - DynamicThreadPointerOffset);
    break;
  default:
    error(getErrorLocation(Loc) + "unrecognized reloc " + Twine(Type));
  }
}

bool PPC64::needsThunk(RelExpr Expr, RelType Type, const InputFile *File,
                       uint64_t BranchAddr, const Symbol &S) const {
  // If a function is in the plt it needs to be called through
  // a call stub.
  return Type == R_PPC64_REL24 && S.isInPlt();
}

RelExpr PPC64::adjustRelaxExpr(RelType Type, const uint8_t *Data,
                               RelExpr Expr) const {
  if (Expr == R_RELAX_TLS_GD_TO_IE)
    return R_RELAX_TLS_GD_TO_IE_GOT_OFF;
  if (Expr == R_RELAX_TLS_LD_TO_LE)
    return R_RELAX_TLS_LD_TO_LE_ABS;
  return Expr;
}

// Reference: 3.7.4.1 of the 64-bit ELF V2 abi supplement.
// The general dynamic code sequence for a global `x` uses 4 instructions.
// Instruction                    Relocation                Symbol
// addis r3, r2, x@got@tlsgd@ha   R_PPC64_GOT_TLSGD16_HA      x
// addi  r3, r3, x@got@tlsgd@l    R_PPC64_GOT_TLSGD16_LO      x
// bl __tls_get_addr(x@tlsgd)     R_PPC64_TLSGD               x
//                                R_PPC64_REL24               __tls_get_addr
// nop                            None                       None
//
// Relaxing to initial-exec entails:
// 1) Convert the addis/addi pair that builds the address of the tls_index
//    struct for 'x' to an addis/ld pair that loads an offset from a got-entry.
// 2) Convert the call to __tls_get_addr to a nop.
// 3) Convert the nop following the call to an add of the loaded offset to the
//    thread pointer.
// Since the nop must directly follow the call, the R_PPC64_TLSGD relocation is
// used as the relaxation hint for both steps 2 and 3.
void PPC64::relaxTlsGdToIe(uint8_t *Loc, RelType Type, uint64_t Val) const {
  switch (Type) {
  case R_PPC64_GOT_TLSGD16_HA:
    // This is relaxed from addis rT, r2, sym@got@tlsgd@ha to
    //                      addis rT, r2, sym@got@tprel@ha.
    relocateOne(Loc, R_PPC64_GOT_TPREL16_HA, Val);
    return;
  case R_PPC64_GOT_TLSGD16_LO: {
    // Relax from addi  r3, rA, sym@got@tlsgd@l to
    //            ld r3, sym@got@tprel@l(rA)
    uint32_t EndianOffset = Config->EKind == ELF64BEKind ? 2U : 0U;
    uint32_t InputRegister = (read32(Loc - EndianOffset) & (0x1f << 16));
    write32(Loc - EndianOffset, 0xE8600000 | InputRegister);
    relocateOne(Loc, R_PPC64_GOT_TPREL16_LO_DS, Val);
    return;
  }
  case R_PPC64_TLSGD:
    write32(Loc, 0x60000000);     // bl __tls_get_addr(sym@tlsgd) --> nop
    write32(Loc + 4, 0x7c636A14); // nop --> add r3, r3, r13
    return;
  default:
    llvm_unreachable("unsupported relocation for TLS GD to IE relaxation");
  }
}

TargetInfo *elf::getPPC64TargetInfo() {
  static PPC64 Target;
  return &Target;
}
