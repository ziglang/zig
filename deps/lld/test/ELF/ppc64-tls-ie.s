# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le %s -o %t.o
# RUN: llvm-readobj -r %t.o | FileCheck --check-prefix=INPUT-REL %s
## IE
# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-readobj -r %t.so | FileCheck --check-prefix=IE-REL %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.so | FileCheck --check-prefix=IE %s
## IE -> LE
# RUN: ld.lld %t.o -o %t
# RUN: llvm-readelf -r %t | FileCheck --check-prefix=NOREL %s
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefix=LE %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64 %s -o %t.o
# RUN: llvm-readobj -r %t.o | FileCheck --check-prefix=INPUT-REL %s
## IE
# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-readobj -r %t.so | FileCheck --check-prefix=IE-REL %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.so | FileCheck --check-prefix=IE %s
## IE -> LE
# RUN: ld.lld %t.o -o %t
# RUN: llvm-readelf -r %t | FileCheck --check-prefix=NOREL %s
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefix=LE %s

# IE-REL:      .rela.dyn {
# IE-REL-NEXT:   0x200B0 R_PPC64_TPREL64 c 0x0
# IE-REL-NEXT:   0x200C0 R_PPC64_TPREL64 i 0x0
# IE-REL-NEXT:   0x200C8 R_PPC64_TPREL64 l 0x0
# IE-REL-NEXT:   0x200B8 R_PPC64_TPREL64 s 0x0
# IE-REL-NEXT: }

# INPUT-REL: R_PPC64_GOT_TPREL16_HA c 0x0
# INPUT-REL: R_PPC64_GOT_TPREL16_LO_DS c 0x0
# INPUT-REL: R_PPC64_TLS c 0x0
## &.got[0] - .TOC. = -32768
# IE-LABEL: test1:
# IE-NEXT:  addis 3, 2, 0
# IE-NEXT:  ld 3, -32768(3)
# IE-NEXT:  lbzx 3, 3, 13
# LE-LABEL: test1:
# LE-NEXT:   nop
# LE-NEXT:   addis 3, 13, 0
# LE-NEXT:   lbz 3, -28672(3)
test1:
  addis 3, 2, c@got@tprel@ha
  ld 3, c@got@tprel@l(3)
  lbzx 3, 3, c@tls

# INPUT-REL: R_PPC64_GOT_TPREL16_HA s 0x0
# INPUT-REL: R_PPC64_GOT_TPREL16_LO_DS s 0x0
# INPUT-REL: R_PPC64_TLS s 0x0
## &.got[1] - .TOC. = -32760
# IE-LABEL: test2:
# IE-NEXT:  addis 3, 2, 0
# IE-NEXT:  ld 3, -32760(3)
# IE-NEXT:  lhzx 3, 3, 13
# LE-LABEL: test2:
# LE-NEXT:  nop
# LE-NEXT:  addis 3, 13, 0
# LE-NEXT:  lhz 3, -28670(3)
test2:
  addis 3, 2, s@got@tprel@ha
  ld 3, s@got@tprel@l(3)
  lhzx 3, 3, s@tls

# INPUT-REL: R_PPC64_GOT_TPREL16_HA i 0x0
# INPUT-REL: R_PPC64_GOT_TPREL16_LO_DS i 0x0
# INPUT-REL: R_PPC64_TLS i 0x0
## &.got[2] - .TOC. = -32752
# IE-LABEL: test3:
# IE-NEXT:  addis 3, 2, 0
# IE-NEXT:  ld 3, -32752(3)
# IE-NEXT:  lwzx 3, 3, 13
# LE-LABEL: test3:
# LE-NEXT:  nop
# LE-NEXT:  addis 3, 13, 0
# LE-NEXT:  lwz 3, -28668(3)
test3:
  addis 3, 2, i@got@tprel@ha
  ld 3, i@got@tprel@l(3)
  lwzx 3, 3, i@tls

# INPUT-REL: R_PPC64_GOT_TPREL16_HA l 0x0
# INPUT-REL: R_PPC64_GOT_TPREL16_LO_DS l 0x0
# INPUT-REL: R_PPC64_TLS l 0x0
## &.got[3] - .TOC. = -32744
# IE-LABEL: test4:
# IE-NEXT:  addis 3, 2, 0
# IE-NEXT:  ld 3, -32744(3)
# IE-NEXT:  ldx 3, 3, 13
# LE-LABEL: test4:
# LE-NEXT:  nop
# LE-NEXT:  addis 3, 13, 0
# LE-NEXT:  ld 3, -28664(3)
test4:
  addis 3, 2, l@got@tprel@ha
  ld 3, l@got@tprel@l(3)
  ldx 3, 3, l@tls

# LE-LABEL: test5:
# LE-NEXT:  nop
# LE-NEXT:  addis 4, 13, 0
# LE-NEXT: stb 3, -28672(4)
test5:
  addis 4, 2, c@got@tprel@ha
  ld 4, c@got@tprel@l(4)
  stbx 3, 4, c@tls


# LE-LABEL: test6:
# LE-NEXT:  nop
# LE-NEXT:  addis 4, 13, 0
# LE-NEXT: sth 3, -28670(4)
test6:
  addis 4, 2, s@got@tprel@ha
  ld 4, s@got@tprel@l(4)
  sthx 3, 4, s@tls


# LE-LABEL: test7:
# LE-NEXT:  nop
# LE-NEXT:  addis 4, 13, 0
# LE-NEXT: stw 3, -28668(4)
test7:
  addis 4, 2, i@got@tprel@ha
  ld 4, i@got@tprel@l(4)
  stwx 3, 4, i@tls

# LE-LABEL: test8:
# LE-NEXT:  nop
# LE-NEXT:  addis 4, 13, 0
# LE-NEXT: std 3, -28664(4)
test8:
  addis 4, 2, l@got@tprel@ha
  ld 4, l@got@tprel@l(4)
  stdx 3, 4, l@tls

# LE-LABEL: test9:
# LE-NEXT:  nop
# LE-NEXT:  addis 3, 13, 0
# LE-NEXT:  addi 3, 3, -28668
test9:
  addis 3, 2, i@got@tprel@ha
  ld 3, i@got@tprel@l(3)
  add 3, 3, i@tls

# LE-LABEL: test_ds:
# LE-NEXT:  addis 4, 13, 0
# LE-NEXT: std 3, -28664(4)
test_ds:
  ld 4, l@got@tprel(2)
  stdx 3, 4, l@tls

# NOREL: There are no relocations in this file.

.section .tdata,"awT",@progbits
.globl c, s, i, l
c:
.byte 97

.p2align 1
s:
.short 55

.p2align 2
i:
.long 55

.p2align 3
l:
.quad 55
