# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le %s -o %t.o
# RUN: ld.lld %t.o --defsym=foo=rel16+0x8000 -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s
# RUN: llvm-readobj -r %t.o | FileCheck --check-prefix=REL %s
# RUN: llvm-readelf -S %t | FileCheck --check-prefix=SEC %s
# RUN: llvm-readelf -x .eh_frame %t | FileCheck --check-prefix=HEX %s

.section .R_PPC64_REL14,"ax",@progbits
# FIXME This does not produce a relocation
  beq 1f
1:
# CHECK-LABEL: Disassembly of section .R_PPC64_REL14:
# CHECK: bt 2, .+4

.section .R_PPC64_REL16,"ax",@progbits
.globl rel16
rel16:
  li 3, foo-rel16-1@ha      # R_PPC64_REL16_HA
  li 3, foo-rel16@ha
  li 4, foo-rel16+0x7fff@h  # R_PPC64_REL16_HI
  li 4, foo-rel16+0x8000@h
  li 5, foo-rel16-1@l       # R_PPC64_REL16_LO
  li 5, foo-rel16@l
# CHECK-LABEL: Disassembly of section .R_PPC64_REL16:
# CHECK:      li 3, 0
# CHECK-NEXT: li 3, 1
# CHECK-NEXT: li 4, 0
# CHECK-NEXT: li 4, 1
# CHECK-NEXT: li 5, 32767
# CHECK-NEXT: li 5, -32768

.section .R_PPC64_REL24,"ax",@progbits
  b rel16
# CHECK-LABEL: Disassembly of section .R_PPC64_REL24:
# CHECK: b .+67108840

.section .REL32_AND_REL64,"ax",@progbits
  .cfi_startproc
  .cfi_personality 148, rel64
  nop
  .cfi_endproc
rel64:
  li 3, 0
# REL:      .rela.eh_frame {
# REL-NEXT:   0x12 R_PPC64_REL64 .REL32_AND_REL64 0x4
# REL-NEXT:   0x28 R_PPC64_REL32 .REL32_AND_REL64 0x0
# REL-NEXT: }

# SEC: .REL32_AND_REL64 PROGBITS 0000000010010020

## CIE Personality Address: 0x10010020-(0x10000168+2)+4 = 0xfeba
## FDE PC Begin: 0x10010020-(0x10000178+8) = 0xfea0
# HEX:      section '.eh_frame':
# HEX-NEXT: 0x10000158
# HEX-NEXT: 0x10000168 {{....}}bafe 00000000
# HEX-NEXT: 0x10000178 {{[0-9a-f]+}} {{[0-9a-f]+}} a0fe0000
