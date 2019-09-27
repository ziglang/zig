# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-nm %t | FileCheck --check-prefix=NM %s
# RUN: llvm-readelf -S %t | FileCheck --check-prefix=SECTIONS %s
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s
# RUN: llvm-readelf -r %t | FileCheck --check-prefix=DYNREL %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-nm %t | FileCheck --check-prefix=NM %s
# RUN: llvm-readelf -S %t | FileCheck --check-prefix=SECTIONS %s
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s
# RUN: llvm-readelf -r %t | FileCheck --check-prefix=DYNREL %s

# NM-DAG: 0000000010028000 d .TOC.
# NM-DAG: 0000000010010000 T ifunc
# NM-DAG: 0000000010010004 T ifunc2

# SECTIONS: .plt NOBITS 0000000010030000

# __plt_ifunc - . = 0x10010020 - 0x10010010 = 16
# __plt_ifunc2 - . = 0x10010044 - 0x10010018 = 28
# CHECK: _start:
# CHECK-NEXT:                 addis 2, 12, 1
# CHECK-NEXT:                 addi 2, 2, 32760
# CHECK-NEXT: 10010010:       bl .+16
# CHECK-NEXT:                 ld 2, 24(1)
# CHECK-NEXT: 10010018:       bl .+28
# CHECK-NEXT:                 ld 2, 24(1)

# .plt[0] - .TOC. = 0x10030000 - 0x10028000 = (1<<16) - 32768
# CHECK: __plt_ifunc:
# CHECK-NEXT:     std 2, 24(1)
# CHECK-NEXT:     addis 12, 2, 1
# CHECK-NEXT:     ld 12, -32768(12)
# CHECK-NEXT:     mtctr 12
# CHECK-NEXT:     bctr

# .plt[1] - .TOC. = 0x10030000+8 - 0x10028000 = (1<<16) - 32760
# CHECK: __plt_ifunc2:
# CHECK-NEXT:     std 2, 24(1)
# CHECK-NEXT:     addis 12, 2, 1
# CHECK-NEXT:     ld 12, -32760(12)
# CHECK-NEXT:     mtctr 12
# CHECK-NEXT:     bctr

# Check that we emit 2 R_PPC64_IRELATIVE.
# DYNREL: R_PPC64_IRELATIVE       10010000
# DYNREL: R_PPC64_IRELATIVE       10010004

.type ifunc STT_GNU_IFUNC
.globl ifunc
ifunc:
  nop

.type ifunc2 STT_GNU_IFUNC
.globl ifunc2
ifunc2:
  nop

.global _start
.type   _start,@function

_start:
.Lfunc_gep0:
  addis 2, 12, .TOC.-.Lfunc_gep0@ha
  addi 2, 2, .TOC.-.Lfunc_gep0@l
.Lfunc_lep0:
  .localentry     _start, .Lfunc_lep0-.Lfunc_gep0
  bl ifunc
  nop
  bl ifunc2
  nop
