# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/shared.s -o %t2.o
# RUN: ld.lld -shared %t2.o -o %t2.so
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld -o %t %t.o --as-needed %t2.so
# RUN: llvm-readobj --dynamic-table --dyn-symbols %t | FileCheck %s


# There must be a NEEDED entry for each undefined

# CHECK:      Name: bar
# CHECK-NEXT: Value: 0x0
# CHECK-NEXT: Size: 0
# CHECK-NEXT: Binding: Global
# CHECK-NEXT: Type: Function
# CHECK-NEXT: Other: 0
# CHECK-NEXT: Section: Undefined

# CHECK: NEEDED Shared library: [{{.*}}as-needed-no-reloc{{.*}}2.so]

        .globl _start
_start:
        .global bar
