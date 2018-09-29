# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/shared-ppc64.s -o %t2.o
# RUN: ld.lld -shared %t2.o -o %t2.so
# RUN: ld.lld %t.o %t2.so -o %t
# RUN: llvm-objdump -D %t | FileCheck %s
# RUN: llvm-readelf -dynamic-table %t | FileCheck --check-prefix=DT %s
# RUN: llvm-readelf -dyn-relocations %t | FileCheck --check-prefix=DYNREL %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %p/Inputs/shared-ppc64.s -o %t2.o
# RUN: ld.lld -shared %t2.o -o %t2.so
# RUN: ld.lld %t.o %t2.so -o %t
# RUN: llvm-objdump -D %t | FileCheck %s
# RUN: llvm-readelf -dynamic-table %t | FileCheck --check-prefix=DT %s
# RUN: llvm-readelf -dyn-relocations %t | FileCheck --check-prefix=DYNREL %s

# CHECK: Disassembly of section .text:

# Tocbase    + (0 << 16) + 32560
# 0x100280e0 +  0        + 32560 = 0x10030010 (.plt[2])
# CHECK: __plt_foo:
# CHECK-NEXT:     std 2, 24(1)
# CHECK-NEXT:     addis 12, 2, 0
# CHECK-NEXT:     ld 12, 32560(12)
# CHECK-NEXT:     mtctr 12
# CHECK-NEXT:     bctr

# Tocbase    + (0 << 16)  +  32568
# 0x100280e0 +  0          + 32568 = 0x1003018 (.plt[3])
# CHECK: __plt_ifunc:
# CHECK-NEXT:     std 2, 24(1)
# CHECK-NEXT:     addis 12, 2, 0
# CHECK-NEXT:     ld 12, 32568(12)
# CHECK-NEXT:     mtctr 12
# CHECK-NEXT:     bctr

# CHECK: ifunc:
# CHECK-NEXT: 10010028:  {{.*}} nop

# CHECK: _start:
# CHECK-NEXT:     addis 2, 12, 2
# CHECK-NEXT:     addi 2, 2, -32588
# CHECK-NEXT:     bl .+67108812
# CHECK-NEXT:     ld 2, 24(1)
# CHECK-NEXT:     bl .+67108824
# CHECK-NEXT:     ld 2, 24(1)

# Check tocbase
# CHECK:       Disassembly of section .got:
# CHECK-NEXT:    .got:
# CHECK-NEXT:    100200e0

# Check .plt address
# DT_PLTGOT should point to the start of the .plt section.
# DT: 0x0000000000000003 PLTGOT 0x10030000

# Check that we emit the correct dynamic relocation type for an ifunc
# DYNREL: 'PLT' relocation section at offset 0x{{[0-9a-f]+}} contains 48 bytes:
# 48 bytes --> 2 Elf64_Rela relocations
# DYNREL-NEXT: Offset        Info           Type               Symbol's Value  Symbol's Name + Addend
# DYNREL-NEXT: {{[0-9a-f]+}} {{[0-9a-f]+}}  R_PPC64_JMP_SLOT      {{0+}}            foo + 0
# DYNREL-NEXT: {{[0-9a-f]+}} {{[0-9a-f]+}}  R_PPC64_IRELATIVE     10010028


    .text
    .abiversion 2

.type ifunc STT_GNU_IFUNC
.globl ifunc
ifunc:
 nop

    .global _start
    .type   _start,@function

_start:
.Lfunc_gep0:
  addis 2, 12, .TOC.-.Lfunc_gep0@ha
  addi 2, 2, .TOC.-.Lfunc_gep0@l
.Lfunc_lep0:
  .localentry     _start, .Lfunc_lep0-.Lfunc_gep0
  bl foo
  nop
  bl ifunc
  nop
