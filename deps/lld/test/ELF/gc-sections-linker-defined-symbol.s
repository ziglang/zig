# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t.so --gc-sections -shared
# RUN: llvm-readobj --dyn-symbols %t.so | FileCheck %s

# CHECK:      Name: _end
# CHECK-NEXT: Value:
# CHECK-NEXT: Size:
# CHECK-NEXT: Binding: Global
# CHECK-NEXT: Type: None
# CHECK-NEXT: Other:
# CHECK-NEXT: Section: .data

        .data
        .globl g
        g:
        .quad _end
