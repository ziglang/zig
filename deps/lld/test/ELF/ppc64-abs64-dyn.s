# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-readobj -r %t.so | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-readobj -r %t.so | FileCheck %s

## Test that we create R_PPC64_RELATIVE for R_PPC64_ADDR64 to non-preemptable
## symbols and R_PPC64_TOC in writable sections.

## FIXME the addend for offset 0x20000 should be TOC base+0x8000+1, not 0x80001.
# CHECK:      .rela.dyn {
# CHECK-NEXT:   0x20000 R_PPC64_RELATIVE - 0x8001
# CHECK-NEXT:   0x20008 R_PPC64_RELATIVE - 0x20001
# CHECK-NEXT:   0x20010 R_PPC64_ADDR64 external 0x1
# CHECK-NEXT:   0x20018 R_PPC64_ADDR64 global 0x1
# CHECK-NEXT: }

.data
.globl global
global:
local:

.quad .TOC.@tocbase + 1
.quad local + 1
.quad external + 1
.quad global + 1
