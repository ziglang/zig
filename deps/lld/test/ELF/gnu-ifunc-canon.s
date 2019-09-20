// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/gnu-ifunc-canon-ro-pcrel.s -o %t-ro-pcrel.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/gnu-ifunc-canon-ro-abs.s -o %t-ro-abs.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/gnu-ifunc-canon-rw-addend.s -o %t-rw-addend.o
// RUN: ld.lld %t.o -o %t1
// RUN: llvm-readobj -r %t1 | FileCheck --check-prefix=IREL2 %s
// RUN: ld.lld %t.o %t-ro-pcrel.o -o %t2
// RUN: llvm-readobj -r %t2 | FileCheck --check-prefix=IREL1 %s
// RUN: ld.lld %t.o %t-ro-abs.o -o %t3
// RUN: llvm-readobj -r %t3 | FileCheck --check-prefix=IREL1 %s
// RUN: ld.lld %t.o %t-rw-addend.o -o %t4
// RUN: llvm-readobj -r %t4 | FileCheck --check-prefix=IREL1 %s
// RUN: llvm-objdump -s %t4 | FileCheck --check-prefix=DUMP %s
// RUN: ld.lld %t.o %t-rw-addend.o -o %t4a -z retpolineplt
// RUN: llvm-readobj -r %t4a | FileCheck --check-prefix=IREL1 %s
// RUN: llvm-objdump -s %t4a | FileCheck --check-prefix=DUMP2 %s
// RUN: ld.lld %t-ro-pcrel.o %t.o -o %t5
// RUN: llvm-readobj -r %t5 | FileCheck --check-prefix=IREL1 %s
// RUN: ld.lld %t-ro-abs.o %t.o -o %t6
// RUN: llvm-readobj -r %t6 | FileCheck --check-prefix=IREL1 %s
// RUN: ld.lld %t-rw-addend.o %t.o -o %t7
// RUN: llvm-readobj -r %t7 | FileCheck --check-prefix=IREL1 %s
// RUN: ld.lld %t.o -o %t8 -pie
// RUN: llvm-readobj -r %t8 | FileCheck --check-prefix=IREL2 %s
// RUN: ld.lld %t.o %t-ro-pcrel.o -o %t9 -pie
// RUN: llvm-readobj -r %t9 | FileCheck --check-prefix=IREL1-REL2 %s
// RUN: ld.lld %t.o %t-rw-addend.o -o %t10 -pie
// RUN: llvm-readobj -r %t10 | FileCheck --check-prefix=IREL1-REL3 %s
// RUN: ld.lld %t-ro-pcrel.o %t.o -o %t11 -pie
// RUN: llvm-readobj -r %t11 | FileCheck --check-prefix=IREL1-REL2 %s
// RUN: ld.lld %t-rw-addend.o %t.o -o %t12 -pie
// RUN: llvm-readobj -r %t12 | FileCheck --check-prefix=IREL1-REL3 %s

// Two relocs, one for the GOT and the other for .data.
// IREL2-NOT: R_X86_64_
// IREL2: .rela.plt
// IREL2-NEXT: R_X86_64_IRELATIVE
// IREL2-NEXT: R_X86_64_IRELATIVE
// IREL2-NOT: R_X86_64_

// One reloc for the canonical PLT.
// IREL1-NOT: R_X86_64_
// IREL1: .rela.plt
// IREL1-NEXT: R_X86_64_IRELATIVE
// IREL1-NOT: R_X86_64_

// One reloc for the canonical PLT and two RELATIVE relocations pointing to it,
// one in the GOT and one in .data.
// IREL1-REL2-NOT: R_X86_64_
// IREL1-REL2: .rela.dyn
// IREL1-REL2-NEXT: R_X86_64_RELATIVE
// IREL1-REL2-NEXT: R_X86_64_RELATIVE
// IREL1-REL2: .rela.plt
// IREL1-REL2-NEXT: R_X86_64_IRELATIVE
// IREL1-REL2-NOT: R_X86_64_

// One reloc for the canonical PLT and three RELATIVE relocations pointing to it,
// one in the GOT and two in .data.
// IREL1-REL3-NOT: R_X86_64_
// IREL1-REL3: .rela.dyn
// IREL1-REL3-NEXT: R_X86_64_RELATIVE
// IREL1-REL3-NEXT: R_X86_64_RELATIVE
// IREL1-REL3-NEXT: R_X86_64_RELATIVE
// IREL1-REL3: .rela.plt
// IREL1-REL3-NEXT: R_X86_64_IRELATIVE
// IREL1-REL3-NOT: R_X86_64_

// Make sure the static relocations look right, both with and without headers.
// DUMP: Contents of section .plt:
// DUMP-NEXT: 201010
// DUMP: Contents of section .got:
// DUMP-NEXT: 202000 10102000 00000000
// DUMP: Contents of section .data:
// DUMP-NEXT: 203000 10102000 00000000 11102000 00000000

// DUMP2: Contents of section .plt:
// DUMP2-NEXT: 201010
// DUMP2: Contents of section .got:
// DUMP2-NEXT: 202000 40102000 00000000
// DUMP2: Contents of section .data:
// DUMP2-NEXT: 203000 40102000 00000000 41102000 00000000

lea ifunc@gotpcrel(%rip), %rbx

.type ifunc STT_GNU_IFUNC
.globl ifunc
ifunc:
ret

.data
.8byte ifunc
