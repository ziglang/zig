# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t2.o
# RUN: ld.lld -shared %t2.o -o %t2.so
# RUN: ld.lld --hash-style=sysv %t1.o %t2.so -o %t.out
# RUN: llvm-readobj -s -r %t.out | FileCheck %s

# CHECK: Section {
# CHECK-NOT: Name: .plt

# CHECK:      Relocations [
# CHECK-NEXT:   Section ({{.*}}) .rela.dyn {
# CHECK-NEXT:     0x2020B0 R_X86_64_GLOB_DAT bar 0x0
# CHECK-NEXT:     0x2020B8 R_X86_64_GLOB_DAT zed 0x0
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.global _start
_start:
 movq bar@GOTPCREL(%rip), %rcx
 movq zed@GOTPCREL(%rip), %rcx
