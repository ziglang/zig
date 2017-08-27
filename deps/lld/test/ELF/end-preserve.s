// Should preserve the value of the "end" symbol if it is defined.
// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t
// RUN: llvm-nm %t | FileCheck %s

// CHECK: 0000000000000005 A end

.global _start,end
end = 5
.text
_start:
    nop
.bss
    .space 6
