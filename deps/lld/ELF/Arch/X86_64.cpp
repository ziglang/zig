//===- X86_64.cpp ---------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "InputFiles.h"
#include "Symbols.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/Object/ELF.h"
#include "llvm/Support/Endian.h"

using namespace llvm;
using namespace llvm::object;
using namespace llvm::support::endian;
using namespace llvm::ELF;
using namespace lld;
using namespace lld::elf;

namespace {
class X86_64 : public TargetInfo {
public:
  X86_64();
  int getTlsGdRelaxSkip(RelType type) const override;
  RelExpr getRelExpr(RelType type, const Symbol &s,
                     const uint8_t *loc) const override;
  RelType getDynRel(RelType type) const override;
  void writeGotPltHeader(uint8_t *buf) const override;
  void writeGotPlt(uint8_t *buf, const Symbol &s) const override;
  void writePltHeader(uint8_t *buf) const override;
  void writePlt(uint8_t *buf, uint64_t gotPltEntryAddr, uint64_t pltEntryAddr,
                int32_t index, unsigned relOff) const override;
  void relocateOne(uint8_t *loc, RelType type, uint64_t val) const override;

  RelExpr adjustRelaxExpr(RelType type, const uint8_t *data,
                          RelExpr expr) const override;
  void relaxGot(uint8_t *loc, RelType type, uint64_t val) const override;
  void relaxTlsGdToIe(uint8_t *loc, RelType type, uint64_t val) const override;
  void relaxTlsGdToLe(uint8_t *loc, RelType type, uint64_t val) const override;
  void relaxTlsIeToLe(uint8_t *loc, RelType type, uint64_t val) const override;
  void relaxTlsLdToLe(uint8_t *loc, RelType type, uint64_t val) const override;
  bool adjustPrologueForCrossSplitStack(uint8_t *loc, uint8_t *end,
                                        uint8_t stOther) const override;
};
} // namespace

X86_64::X86_64() {
  copyRel = R_X86_64_COPY;
  gotRel = R_X86_64_GLOB_DAT;
  noneRel = R_X86_64_NONE;
  pltRel = R_X86_64_JUMP_SLOT;
  relativeRel = R_X86_64_RELATIVE;
  iRelativeRel = R_X86_64_IRELATIVE;
  symbolicRel = R_X86_64_64;
  tlsDescRel = R_X86_64_TLSDESC;
  tlsGotRel = R_X86_64_TPOFF64;
  tlsModuleIndexRel = R_X86_64_DTPMOD64;
  tlsOffsetRel = R_X86_64_DTPOFF64;
  pltEntrySize = 16;
  pltHeaderSize = 16;
  trapInstr = {0xcc, 0xcc, 0xcc, 0xcc}; // 0xcc = INT3

  // Align to the large page size (known as a superpage or huge page).
  // FreeBSD automatically promotes large, superpage-aligned allocations.
  defaultImageBase = 0x200000;
}

int X86_64::getTlsGdRelaxSkip(RelType type) const { return 2; }

RelExpr X86_64::getRelExpr(RelType type, const Symbol &s,
                           const uint8_t *loc) const {
  if (type == R_X86_64_GOTTPOFF)
    config->hasStaticTlsModel = true;

  switch (type) {
  case R_X86_64_8:
  case R_X86_64_16:
  case R_X86_64_32:
  case R_X86_64_32S:
  case R_X86_64_64:
    return R_ABS;
  case R_X86_64_DTPOFF32:
  case R_X86_64_DTPOFF64:
    return R_DTPREL;
  case R_X86_64_TPOFF32:
    return R_TLS;
  case R_X86_64_TLSDESC_CALL:
    return R_TLSDESC_CALL;
  case R_X86_64_TLSLD:
    return R_TLSLD_PC;
  case R_X86_64_TLSGD:
    return R_TLSGD_PC;
  case R_X86_64_SIZE32:
  case R_X86_64_SIZE64:
    return R_SIZE;
  case R_X86_64_PLT32:
    return R_PLT_PC;
  case R_X86_64_PC8:
  case R_X86_64_PC16:
  case R_X86_64_PC32:
  case R_X86_64_PC64:
    return R_PC;
  case R_X86_64_GOT32:
  case R_X86_64_GOT64:
    return R_GOTPLT;
  case R_X86_64_GOTPC32_TLSDESC:
    return R_TLSDESC_PC;
  case R_X86_64_GOTPCREL:
  case R_X86_64_GOTPCRELX:
  case R_X86_64_REX_GOTPCRELX:
  case R_X86_64_GOTTPOFF:
    return R_GOT_PC;
  case R_X86_64_GOTOFF64:
    return R_GOTPLTREL;
  case R_X86_64_GOTPC32:
  case R_X86_64_GOTPC64:
    return R_GOTPLTONLY_PC;
  case R_X86_64_NONE:
    return R_NONE;
  default:
    error(getErrorLocation(loc) + "unknown relocation (" + Twine(type) +
          ") against symbol " + toString(s));
    return R_NONE;
  }
}

void X86_64::writeGotPltHeader(uint8_t *buf) const {
  // The first entry holds the value of _DYNAMIC. It is not clear why that is
  // required, but it is documented in the psabi and the glibc dynamic linker
  // seems to use it (note that this is relevant for linking ld.so, not any
  // other program).
  write64le(buf, mainPart->dynamic->getVA());
}

void X86_64::writeGotPlt(uint8_t *buf, const Symbol &s) const {
  // See comments in X86::writeGotPlt.
  write64le(buf, s.getPltVA() + 6);
}

void X86_64::writePltHeader(uint8_t *buf) const {
  const uint8_t pltData[] = {
      0xff, 0x35, 0, 0, 0, 0, // pushq GOTPLT+8(%rip)
      0xff, 0x25, 0, 0, 0, 0, // jmp *GOTPLT+16(%rip)
      0x0f, 0x1f, 0x40, 0x00, // nop
  };
  memcpy(buf, pltData, sizeof(pltData));
  uint64_t gotPlt = in.gotPlt->getVA();
  uint64_t plt = in.plt->getVA();
  write32le(buf + 2, gotPlt - plt + 2); // GOTPLT+8
  write32le(buf + 8, gotPlt - plt + 4); // GOTPLT+16
}

void X86_64::writePlt(uint8_t *buf, uint64_t gotPltEntryAddr,
                      uint64_t pltEntryAddr, int32_t index,
                      unsigned relOff) const {
  const uint8_t inst[] = {
      0xff, 0x25, 0, 0, 0, 0, // jmpq *got(%rip)
      0x68, 0, 0, 0, 0,       // pushq <relocation index>
      0xe9, 0, 0, 0, 0,       // jmpq plt[0]
  };
  memcpy(buf, inst, sizeof(inst));

  write32le(buf + 2, gotPltEntryAddr - pltEntryAddr - 6);
  write32le(buf + 7, index);
  write32le(buf + 12, -pltHeaderSize - pltEntrySize * index - 16);
}

RelType X86_64::getDynRel(RelType type) const {
  if (type == R_X86_64_64 || type == R_X86_64_PC64 || type == R_X86_64_SIZE32 ||
      type == R_X86_64_SIZE64)
    return type;
  return R_X86_64_NONE;
}

void X86_64::relaxTlsGdToLe(uint8_t *loc, RelType type, uint64_t val) const {
  if (type == R_X86_64_TLSGD) {
    // Convert
    //   .byte 0x66
    //   leaq x@tlsgd(%rip), %rdi
    //   .word 0x6666
    //   rex64
    //   call __tls_get_addr@plt
    // to the following two instructions.
    const uint8_t inst[] = {
        0x64, 0x48, 0x8b, 0x04, 0x25, 0x00, 0x00,
        0x00, 0x00,                            // mov %fs:0x0,%rax
        0x48, 0x8d, 0x80, 0,    0,    0,    0, // lea x@tpoff,%rax
    };
    memcpy(loc - 4, inst, sizeof(inst));

    // The original code used a pc relative relocation and so we have to
    // compensate for the -4 in had in the addend.
    write32le(loc + 8, val + 4);
  } else {
    // Convert
    //   lea x@tlsgd(%rip), %rax
    //   call *(%rax)
    // to the following two instructions.
    assert(type == R_X86_64_GOTPC32_TLSDESC);
    if (memcmp(loc - 3, "\x48\x8d\x05", 3)) {
      error(getErrorLocation(loc - 3) + "R_X86_64_GOTPC32_TLSDESC must be used "
                                        "in callq *x@tlsdesc(%rip), %rax");
      return;
    }
    // movq $x@tpoff(%rip),%rax
    loc[-2] = 0xc7;
    loc[-1] = 0xc0;
    write32le(loc, val + 4);
    // xchg ax,ax
    loc[4] = 0x66;
    loc[5] = 0x90;
  }
}

void X86_64::relaxTlsGdToIe(uint8_t *loc, RelType type, uint64_t val) const {
  if (type == R_X86_64_TLSGD) {
    // Convert
    //   .byte 0x66
    //   leaq x@tlsgd(%rip), %rdi
    //   .word 0x6666
    //   rex64
    //   call __tls_get_addr@plt
    // to the following two instructions.
    const uint8_t inst[] = {
        0x64, 0x48, 0x8b, 0x04, 0x25, 0x00, 0x00,
        0x00, 0x00,                            // mov %fs:0x0,%rax
        0x48, 0x03, 0x05, 0,    0,    0,    0, // addq x@gottpoff(%rip),%rax
    };
    memcpy(loc - 4, inst, sizeof(inst));

    // Both code sequences are PC relatives, but since we are moving the
    // constant forward by 8 bytes we have to subtract the value by 8.
    write32le(loc + 8, val - 8);
  } else {
    // Convert
    //   lea x@tlsgd(%rip), %rax
    //   call *(%rax)
    // to the following two instructions.
    assert(type == R_X86_64_GOTPC32_TLSDESC);
    if (memcmp(loc - 3, "\x48\x8d\x05", 3)) {
      error(getErrorLocation(loc - 3) + "R_X86_64_GOTPC32_TLSDESC must be used "
                                        "in callq *x@tlsdesc(%rip), %rax");
      return;
    }
    // movq x@gottpoff(%rip),%rax
    loc[-2] = 0x8b;
    write32le(loc, val);
    // xchg ax,ax
    loc[4] = 0x66;
    loc[5] = 0x90;
  }
}

// In some conditions, R_X86_64_GOTTPOFF relocation can be optimized to
// R_X86_64_TPOFF32 so that it does not use GOT.
void X86_64::relaxTlsIeToLe(uint8_t *loc, RelType type, uint64_t val) const {
  uint8_t *inst = loc - 3;
  uint8_t reg = loc[-1] >> 3;
  uint8_t *regSlot = loc - 1;

  // Note that ADD with RSP or R12 is converted to ADD instead of LEA
  // because LEA with these registers needs 4 bytes to encode and thus
  // wouldn't fit the space.

  if (memcmp(inst, "\x48\x03\x25", 3) == 0) {
    // "addq foo@gottpoff(%rip),%rsp" -> "addq $foo,%rsp"
    memcpy(inst, "\x48\x81\xc4", 3);
  } else if (memcmp(inst, "\x4c\x03\x25", 3) == 0) {
    // "addq foo@gottpoff(%rip),%r12" -> "addq $foo,%r12"
    memcpy(inst, "\x49\x81\xc4", 3);
  } else if (memcmp(inst, "\x4c\x03", 2) == 0) {
    // "addq foo@gottpoff(%rip),%r[8-15]" -> "leaq foo(%r[8-15]),%r[8-15]"
    memcpy(inst, "\x4d\x8d", 2);
    *regSlot = 0x80 | (reg << 3) | reg;
  } else if (memcmp(inst, "\x48\x03", 2) == 0) {
    // "addq foo@gottpoff(%rip),%reg -> "leaq foo(%reg),%reg"
    memcpy(inst, "\x48\x8d", 2);
    *regSlot = 0x80 | (reg << 3) | reg;
  } else if (memcmp(inst, "\x4c\x8b", 2) == 0) {
    // "movq foo@gottpoff(%rip),%r[8-15]" -> "movq $foo,%r[8-15]"
    memcpy(inst, "\x49\xc7", 2);
    *regSlot = 0xc0 | reg;
  } else if (memcmp(inst, "\x48\x8b", 2) == 0) {
    // "movq foo@gottpoff(%rip),%reg" -> "movq $foo,%reg"
    memcpy(inst, "\x48\xc7", 2);
    *regSlot = 0xc0 | reg;
  } else {
    error(getErrorLocation(loc - 3) +
          "R_X86_64_GOTTPOFF must be used in MOVQ or ADDQ instructions only");
  }

  // The original code used a PC relative relocation.
  // Need to compensate for the -4 it had in the addend.
  write32le(loc, val + 4);
}

void X86_64::relaxTlsLdToLe(uint8_t *loc, RelType type, uint64_t val) const {
  if (type == R_X86_64_DTPOFF64) {
    write64le(loc, val);
    return;
  }
  if (type == R_X86_64_DTPOFF32) {
    write32le(loc, val);
    return;
  }

  const uint8_t inst[] = {
      0x66, 0x66,                                           // .word 0x6666
      0x66,                                                 // .byte 0x66
      0x64, 0x48, 0x8b, 0x04, 0x25, 0x00, 0x00, 0x00, 0x00, // mov %fs:0,%rax
  };

  if (loc[4] == 0xe8) {
    // Convert
    //   leaq bar@tlsld(%rip), %rdi           # 48 8d 3d <Loc>
    //   callq __tls_get_addr@PLT             # e8 <disp32>
    //   leaq bar@dtpoff(%rax), %rcx
    // to
    //   .word 0x6666
    //   .byte 0x66
    //   mov %fs:0,%rax
    //   leaq bar@tpoff(%rax), %rcx
    memcpy(loc - 3, inst, sizeof(inst));
    return;
  }

  if (loc[4] == 0xff && loc[5] == 0x15) {
    // Convert
    //   leaq  x@tlsld(%rip),%rdi               # 48 8d 3d <Loc>
    //   call *__tls_get_addr@GOTPCREL(%rip)    # ff 15 <disp32>
    // to
    //   .long  0x66666666
    //   movq   %fs:0,%rax
    // See "Table 11.9: LD -> LE Code Transition (LP64)" in
    // https://raw.githubusercontent.com/wiki/hjl-tools/x86-psABI/x86-64-psABI-1.0.pdf
    loc[-3] = 0x66;
    memcpy(loc - 2, inst, sizeof(inst));
    return;
  }

  error(getErrorLocation(loc - 3) +
        "expected R_X86_64_PLT32 or R_X86_64_GOTPCRELX after R_X86_64_TLSLD");
}

void X86_64::relocateOne(uint8_t *loc, RelType type, uint64_t val) const {
  switch (type) {
  case R_X86_64_8:
    checkIntUInt(loc, val, 8, type);
    *loc = val;
    break;
  case R_X86_64_PC8:
    checkInt(loc, val, 8, type);
    *loc = val;
    break;
  case R_X86_64_16:
    checkIntUInt(loc, val, 16, type);
    write16le(loc, val);
    break;
  case R_X86_64_PC16:
    checkInt(loc, val, 16, type);
    write16le(loc, val);
    break;
  case R_X86_64_32:
    checkUInt(loc, val, 32, type);
    write32le(loc, val);
    break;
  case R_X86_64_32S:
  case R_X86_64_TPOFF32:
  case R_X86_64_GOT32:
  case R_X86_64_GOTPC32:
  case R_X86_64_GOTPC32_TLSDESC:
  case R_X86_64_GOTPCREL:
  case R_X86_64_GOTPCRELX:
  case R_X86_64_REX_GOTPCRELX:
  case R_X86_64_PC32:
  case R_X86_64_GOTTPOFF:
  case R_X86_64_PLT32:
  case R_X86_64_TLSGD:
  case R_X86_64_TLSLD:
  case R_X86_64_DTPOFF32:
  case R_X86_64_SIZE32:
    checkInt(loc, val, 32, type);
    write32le(loc, val);
    break;
  case R_X86_64_64:
  case R_X86_64_DTPOFF64:
  case R_X86_64_PC64:
  case R_X86_64_SIZE64:
  case R_X86_64_GOT64:
  case R_X86_64_GOTOFF64:
  case R_X86_64_GOTPC64:
    write64le(loc, val);
    break;
  default:
    llvm_unreachable("unknown relocation");
  }
}

RelExpr X86_64::adjustRelaxExpr(RelType type, const uint8_t *data,
                                RelExpr relExpr) const {
  if (type != R_X86_64_GOTPCRELX && type != R_X86_64_REX_GOTPCRELX)
    return relExpr;
  const uint8_t op = data[-2];
  const uint8_t modRm = data[-1];

  // FIXME: When PIC is disabled and foo is defined locally in the
  // lower 32 bit address space, memory operand in mov can be converted into
  // immediate operand. Otherwise, mov must be changed to lea. We support only
  // latter relaxation at this moment.
  if (op == 0x8b)
    return R_RELAX_GOT_PC;

  // Relax call and jmp.
  if (op == 0xff && (modRm == 0x15 || modRm == 0x25))
    return R_RELAX_GOT_PC;

  // Relaxation of test, adc, add, and, cmp, or, sbb, sub, xor.
  // If PIC then no relaxation is available.
  // We also don't relax test/binop instructions without REX byte,
  // they are 32bit operations and not common to have.
  assert(type == R_X86_64_REX_GOTPCRELX);
  return config->isPic ? relExpr : R_RELAX_GOT_PC_NOPIC;
}

// A subset of relaxations can only be applied for no-PIC. This method
// handles such relaxations. Instructions encoding information was taken from:
// "Intel 64 and IA-32 Architectures Software Developer's Manual V2"
// (http://www.intel.com/content/dam/www/public/us/en/documents/manuals/
//    64-ia-32-architectures-software-developer-instruction-set-reference-manual-325383.pdf)
static void relaxGotNoPic(uint8_t *loc, uint64_t val, uint8_t op,
                          uint8_t modRm) {
  const uint8_t rex = loc[-3];
  // Convert "test %reg, foo@GOTPCREL(%rip)" to "test $foo, %reg".
  if (op == 0x85) {
    // See "TEST-Logical Compare" (4-428 Vol. 2B),
    // TEST r/m64, r64 uses "full" ModR / M byte (no opcode extension).

    // ModR/M byte has form XX YYY ZZZ, where
    // YYY is MODRM.reg(register 2), ZZZ is MODRM.rm(register 1).
    // XX has different meanings:
    // 00: The operand's memory address is in reg1.
    // 01: The operand's memory address is reg1 + a byte-sized displacement.
    // 10: The operand's memory address is reg1 + a word-sized displacement.
    // 11: The operand is reg1 itself.
    // If an instruction requires only one operand, the unused reg2 field
    // holds extra opcode bits rather than a register code
    // 0xC0 == 11 000 000 binary.
    // 0x38 == 00 111 000 binary.
    // We transfer reg2 to reg1 here as operand.
    // See "2.1.3 ModR/M and SIB Bytes" (Vol. 2A 2-3).
    loc[-1] = 0xc0 | (modRm & 0x38) >> 3; // ModR/M byte.

    // Change opcode from TEST r/m64, r64 to TEST r/m64, imm32
    // See "TEST-Logical Compare" (4-428 Vol. 2B).
    loc[-2] = 0xf7;

    // Move R bit to the B bit in REX byte.
    // REX byte is encoded as 0100WRXB, where
    // 0100 is 4bit fixed pattern.
    // REX.W When 1, a 64-bit operand size is used. Otherwise, when 0, the
    //   default operand size is used (which is 32-bit for most but not all
    //   instructions).
    // REX.R This 1-bit value is an extension to the MODRM.reg field.
    // REX.X This 1-bit value is an extension to the SIB.index field.
    // REX.B This 1-bit value is an extension to the MODRM.rm field or the
    // SIB.base field.
    // See "2.2.1.2 More on REX Prefix Fields " (2-8 Vol. 2A).
    loc[-3] = (rex & ~0x4) | (rex & 0x4) >> 2;
    write32le(loc, val);
    return;
  }

  // If we are here then we need to relax the adc, add, and, cmp, or, sbb, sub
  // or xor operations.

  // Convert "binop foo@GOTPCREL(%rip), %reg" to "binop $foo, %reg".
  // Logic is close to one for test instruction above, but we also
  // write opcode extension here, see below for details.
  loc[-1] = 0xc0 | (modRm & 0x38) >> 3 | (op & 0x3c); // ModR/M byte.

  // Primary opcode is 0x81, opcode extension is one of:
  // 000b = ADD, 001b is OR, 010b is ADC, 011b is SBB,
  // 100b is AND, 101b is SUB, 110b is XOR, 111b is CMP.
  // This value was wrote to MODRM.reg in a line above.
  // See "3.2 INSTRUCTIONS (A-M)" (Vol. 2A 3-15),
  // "INSTRUCTION SET REFERENCE, N-Z" (Vol. 2B 4-1) for
  // descriptions about each operation.
  loc[-2] = 0x81;
  loc[-3] = (rex & ~0x4) | (rex & 0x4) >> 2;
  write32le(loc, val);
}

void X86_64::relaxGot(uint8_t *loc, RelType type, uint64_t val) const {
  const uint8_t op = loc[-2];
  const uint8_t modRm = loc[-1];

  // Convert "mov foo@GOTPCREL(%rip),%reg" to "lea foo(%rip),%reg".
  if (op == 0x8b) {
    loc[-2] = 0x8d;
    write32le(loc, val);
    return;
  }

  if (op != 0xff) {
    // We are relaxing a rip relative to an absolute, so compensate
    // for the old -4 addend.
    assert(!config->isPic);
    relaxGotNoPic(loc, val + 4, op, modRm);
    return;
  }

  // Convert call/jmp instructions.
  if (modRm == 0x15) {
    // ABI says we can convert "call *foo@GOTPCREL(%rip)" to "nop; call foo".
    // Instead we convert to "addr32 call foo" where addr32 is an instruction
    // prefix. That makes result expression to be a single instruction.
    loc[-2] = 0x67; // addr32 prefix
    loc[-1] = 0xe8; // call
    write32le(loc, val);
    return;
  }

  // Convert "jmp *foo@GOTPCREL(%rip)" to "jmp foo; nop".
  // jmp doesn't return, so it is fine to use nop here, it is just a stub.
  assert(modRm == 0x25);
  loc[-2] = 0xe9; // jmp
  loc[3] = 0x90;  // nop
  write32le(loc - 1, val + 1);
}

// A split-stack prologue starts by checking the amount of stack remaining
// in one of two ways:
// A) Comparing of the stack pointer to a field in the tcb.
// B) Or a load of a stack pointer offset with an lea to r10 or r11.
bool X86_64::adjustPrologueForCrossSplitStack(uint8_t *loc, uint8_t *end,
                                              uint8_t stOther) const {
  if (!config->is64) {
    error("Target doesn't support split stacks.");
    return false;
  }

  if (loc + 8 >= end)
    return false;

  // Replace "cmp %fs:0x70,%rsp" and subsequent branch
  // with "stc, nopl 0x0(%rax,%rax,1)"
  if (memcmp(loc, "\x64\x48\x3b\x24\x25", 5) == 0) {
    memcpy(loc, "\xf9\x0f\x1f\x84\x00\x00\x00\x00", 8);
    return true;
  }

  // Adjust "lea X(%rsp),%rYY" to lea "(X - 0x4000)(%rsp),%rYY" where rYY could
  // be r10 or r11. The lea instruction feeds a subsequent compare which checks
  // if there is X available stack space. Making X larger effectively reserves
  // that much additional space. The stack grows downward so subtract the value.
  if (memcmp(loc, "\x4c\x8d\x94\x24", 4) == 0 ||
      memcmp(loc, "\x4c\x8d\x9c\x24", 4) == 0) {
    // The offset bytes are encoded four bytes after the start of the
    // instruction.
    write32le(loc + 4, read32le(loc + 4) - 0x4000);
    return true;
  }
  return false;
}

// These nonstandard PLT entries are to migtigate Spectre v2 security
// vulnerability. In order to mitigate Spectre v2, we want to avoid indirect
// branch instructions such as `jmp *GOTPLT(%rip)`. So, in the following PLT
// entries, we use a CALL followed by MOV and RET to do the same thing as an
// indirect jump. That instruction sequence is so-called "retpoline".
//
// We have two types of retpoline PLTs as a size optimization. If `-z now`
// is specified, all dynamic symbols are resolved at load-time. Thus, when
// that option is given, we can omit code for symbol lazy resolution.
namespace {
class Retpoline : public X86_64 {
public:
  Retpoline();
  void writeGotPlt(uint8_t *buf, const Symbol &s) const override;
  void writePltHeader(uint8_t *buf) const override;
  void writePlt(uint8_t *buf, uint64_t gotPltEntryAddr, uint64_t pltEntryAddr,
                int32_t index, unsigned relOff) const override;
};

class RetpolineZNow : public X86_64 {
public:
  RetpolineZNow();
  void writeGotPlt(uint8_t *buf, const Symbol &s) const override {}
  void writePltHeader(uint8_t *buf) const override;
  void writePlt(uint8_t *buf, uint64_t gotPltEntryAddr, uint64_t pltEntryAddr,
                int32_t index, unsigned relOff) const override;
};
} // namespace

Retpoline::Retpoline() {
  pltHeaderSize = 48;
  pltEntrySize = 32;
}

void Retpoline::writeGotPlt(uint8_t *buf, const Symbol &s) const {
  write64le(buf, s.getPltVA() + 17);
}

void Retpoline::writePltHeader(uint8_t *buf) const {
  const uint8_t insn[] = {
      0xff, 0x35, 0,    0,    0,    0,          // 0:    pushq GOTPLT+8(%rip)
      0x4c, 0x8b, 0x1d, 0,    0,    0,    0,    // 6:    mov GOTPLT+16(%rip), %r11
      0xe8, 0x0e, 0x00, 0x00, 0x00,             // d:    callq next
      0xf3, 0x90,                               // 12: loop: pause
      0x0f, 0xae, 0xe8,                         // 14:   lfence
      0xeb, 0xf9,                               // 17:   jmp loop
      0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, // 19:   int3; .align 16
      0x4c, 0x89, 0x1c, 0x24,                   // 20: next: mov %r11, (%rsp)
      0xc3,                                     // 24:   ret
      0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, // 25:   int3; padding
      0xcc, 0xcc, 0xcc, 0xcc,                   // 2c:   int3; padding
  };
  memcpy(buf, insn, sizeof(insn));

  uint64_t gotPlt = in.gotPlt->getVA();
  uint64_t plt = in.plt->getVA();
  write32le(buf + 2, gotPlt - plt - 6 + 8);
  write32le(buf + 9, gotPlt - plt - 13 + 16);
}

void Retpoline::writePlt(uint8_t *buf, uint64_t gotPltEntryAddr,
                         uint64_t pltEntryAddr, int32_t index,
                         unsigned relOff) const {
  const uint8_t insn[] = {
      0x4c, 0x8b, 0x1d, 0, 0, 0, 0, // 0:  mov foo@GOTPLT(%rip), %r11
      0xe8, 0,    0,    0,    0,    // 7:  callq plt+0x20
      0xe9, 0,    0,    0,    0,    // c:  jmp plt+0x12
      0x68, 0,    0,    0,    0,    // 11: pushq <relocation index>
      0xe9, 0,    0,    0,    0,    // 16: jmp plt+0
      0xcc, 0xcc, 0xcc, 0xcc, 0xcc, // 1b: int3; padding
  };
  memcpy(buf, insn, sizeof(insn));

  uint64_t off = pltHeaderSize + pltEntrySize * index;

  write32le(buf + 3, gotPltEntryAddr - pltEntryAddr - 7);
  write32le(buf + 8, -off - 12 + 32);
  write32le(buf + 13, -off - 17 + 18);
  write32le(buf + 18, index);
  write32le(buf + 23, -off - 27);
}

RetpolineZNow::RetpolineZNow() {
  pltHeaderSize = 32;
  pltEntrySize = 16;
}

void RetpolineZNow::writePltHeader(uint8_t *buf) const {
  const uint8_t insn[] = {
      0xe8, 0x0b, 0x00, 0x00, 0x00, // 0:    call next
      0xf3, 0x90,                   // 5:  loop: pause
      0x0f, 0xae, 0xe8,             // 7:    lfence
      0xeb, 0xf9,                   // a:    jmp loop
      0xcc, 0xcc, 0xcc, 0xcc,       // c:    int3; .align 16
      0x4c, 0x89, 0x1c, 0x24,       // 10: next: mov %r11, (%rsp)
      0xc3,                         // 14:   ret
      0xcc, 0xcc, 0xcc, 0xcc, 0xcc, // 15:   int3; padding
      0xcc, 0xcc, 0xcc, 0xcc, 0xcc, // 1a:   int3; padding
      0xcc,                         // 1f:   int3; padding
  };
  memcpy(buf, insn, sizeof(insn));
}

void RetpolineZNow::writePlt(uint8_t *buf, uint64_t gotPltEntryAddr,
                             uint64_t pltEntryAddr, int32_t index,
                             unsigned relOff) const {
  const uint8_t insn[] = {
      0x4c, 0x8b, 0x1d, 0,    0, 0, 0, // mov foo@GOTPLT(%rip), %r11
      0xe9, 0,    0,    0,    0,       // jmp plt+0
      0xcc, 0xcc, 0xcc, 0xcc,          // int3; padding
  };
  memcpy(buf, insn, sizeof(insn));

  write32le(buf + 3, gotPltEntryAddr - pltEntryAddr - 7);
  write32le(buf + 8, -pltHeaderSize - pltEntrySize * index - 12);
}

static TargetInfo *getTargetInfo() {
  if (config->zRetpolineplt) {
    if (config->zNow) {
      static RetpolineZNow t;
      return &t;
    }
    static Retpoline t;
    return &t;
  }

  static X86_64 t;
  return &t;
}

TargetInfo *elf::getX86_64TargetInfo() { return getTargetInfo(); }
