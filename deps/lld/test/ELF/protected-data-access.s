# REQUIRES: x86
# RUN: llvm-mc -triple x86_64-pc-linux -filetype=obj %p/Inputs/protected-data-access.s -o %t2.o
# RUN: ld.lld %t2.o -o %t2.so -shared
# RUN: llvm-mc -triple x86_64-pc-linux -filetype=obj %s -o %t.o

# RUN: not ld.lld %t.o %t2.so -o %t 2>&1 | FileCheck --check-prefix=ERR %s
# ERR: error: cannot preempt symbol: foo

# RUN: ld.lld --ignore-data-address-equality %t.o %t2.so -o %t
# RUN: llvm-readobj --dyn-symbols --relocations %t | FileCheck %s

# Check that we have a copy relocation.

# CHECK: R_X86_64_COPY foo 0x0

# CHECK:      Name: foo
# CHECK-NEXT: Value:
# CHECK-NEXT: Size: 8
# CHECK-NEXT: Binding: Global
# CHECK-NEXT: Type: Object
# CHECK-NEXT: Other:
# CHECK-NEXT: Section: .bss.rel.ro

.global _start
_start:
  .quad foo

