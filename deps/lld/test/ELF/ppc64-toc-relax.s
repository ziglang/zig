# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/ppc64-toc-relax-shared.s -o %t.o
# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/ppc64-toc-relax.s -o %t2.o
# RUN: llvm-readobj -r %t1.o | FileCheck --check-prefixes=RELOCS-LE,RELOCS %s
# RUN: ld.lld %t1.o %t2.o %t.so -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefixes=COMMON,EXE %s

# RUN: ld.lld -shared %t1.o %t2.o %t.so -o %t2.so
# RUN: llvm-objdump -d --no-show-raw-insn %t2.so | FileCheck --check-prefixes=COMMON,SHARED %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %p/Inputs/ppc64-toc-relax-shared.s -o %t.o
# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %p/Inputs/ppc64-toc-relax.s -o %t2.o
# RUN: llvm-readobj -r %t1.o | FileCheck --check-prefixes=RELOCS-BE,RELOCS %s
# RUN: ld.lld %t1.o %t2.o %t.so -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefixes=COMMON,EXE %s

# RUN: ld.lld -shared %t1.o %t2.o %t.so -o %t2.so
# RUN: llvm-objdump -d --no-show-raw-insn %t2.so | FileCheck --check-prefixes=COMMON,SHARED %s

# RELOCS-LE:      .rela.text {
# RELOCS-LE-NEXT:   0x0 R_PPC64_TOC16_HA .toc 0x0
# RELOCS-LE-NEXT:   0x4 R_PPC64_TOC16_LO_DS .toc 0x0
# RELOCS-LE-NEXT:   0xC R_PPC64_TOC16_HA .toc 0x8
# RELOCS-LE-NEXT:   0x10 R_PPC64_TOC16_LO_DS .toc 0x8
# RELOCS-LE-NEXT:   0x18 R_PPC64_TOC16_HA .toc 0x10
# RELOCS-LE-NEXT:   0x1C R_PPC64_TOC16_LO_DS .toc 0x10
# RELOCS-LE-NEXT:   0x24 R_PPC64_TOC16_HA .toc 0x18
# RELOCS-LE-NEXT:   0x28 R_PPC64_TOC16_LO_DS .toc 0x18
# RELOCS-LE-NEXT: }

# RELOCS-BE:      .rela.text {
# RELOCS-BE-NEXT:   0x2 R_PPC64_TOC16_HA .toc 0x0
# RELOCS-BE-NEXT:   0x6 R_PPC64_TOC16_LO_DS .toc 0x0
# RELOCS-BE-NEXT:   0xE R_PPC64_TOC16_HA .toc 0x8
# RELOCS-BE-NEXT:   0x12 R_PPC64_TOC16_LO_DS .toc 0x8
# RELOCS-BE-NEXT:   0x1A R_PPC64_TOC16_HA .toc 0x10
# RELOCS-BE-NEXT:   0x1E R_PPC64_TOC16_LO_DS .toc 0x10
# RELOCS-BE-NEXT:   0x26 R_PPC64_TOC16_HA .toc 0x18
# RELOCS-BE-NEXT:   0x2A R_PPC64_TOC16_LO_DS .toc 0x18
# RELOCS-BE-NEXT: }

# RELOCS:         .rela.toc {
# RELOCS-NEXT:      0x0 R_PPC64_ADDR64 hidden 0x0
# RELOCS-NEXT:      0x8 R_PPC64_ADDR64 hidden2 0x0
# RELOCS-NEXT:      0x10 R_PPC64_ADDR64 shared 0x0
# RELOCS-NEXT:      0x18 R_PPC64_ADDR64 default 0x0
# RELOCS-NEXT:    }

# NM-DAG: 0000000010030000 D default
# NM-DAG: 0000000010030000 d hidden
# NM-DAG: 0000000010040000 d hidden2

# 'hidden' is non-preemptable. It is relaxed.
# address(hidden) - (.got+0x8000) = 0x10030000 - (0x100200c0+0x8000) = 32576
# COMMON: nop
# COMMON: addi 3, 2, 32576
# COMMON: lwa 3, 0(3)
  addis 3, 2, .Lhidden@toc@ha
  ld    3, .Lhidden@toc@l(3)
  lwa   3, 0(3)

# address(hidden2) - (.got+0x8000) = 0x10040000 - (0x100200c0+0x8000) = (1<<16)+32576
# COMMON: addis 3, 2, 1
# COMMON: addi 3, 3, 32576
# COMMON: lwa 3, 0(3)
  addis 3, 2, .Lhidden2@toc@ha
  ld    3, .Lhidden2@toc@l(3)
  lwa   3, 0(3)

# 'shared' is not defined in an object file. Its definition is determined at
# runtime by the dynamic linker, so the extra indirection cannot be relaxed.
# The first addis can still be relaxed to nop, though.
# COMMON: nop
# COMMON: ld 4, -32752(2)
# COMMON: lwa 4, 0(4)
  addis 4, 2, .Lshared@toc@ha
  ld    4, .Lshared@toc@l(4)
  lwa   4, 0(4)

# 'default' has default visibility. It is non-preemptable when producing an executable.
# address(default) - (.got+0x8000) = 0x10030000 - (0x100200c0+0x8000) = 32576
# EXE: nop
# EXE: addi 5, 2, 32576
# EXE: lwa 5, 0(5)

# SHARED: nop
# SHARED: ld 5, -32744(2)
# SHARED: lwa 5, 0(5)
  addis 5, 2, .Ldefault@toc@ha
  ld    5, .Ldefault@toc@l(5)
  lwa   5, 0(5)

.section .toc,"aw",@progbits
.Lhidden:
  .tc hidden[TC], hidden
.Lhidden2:
  .tc hidden2[TC], hidden2
.Lshared:
  .tc shared[TC], shared
.Ldefault:
  .tc default[TC], default
