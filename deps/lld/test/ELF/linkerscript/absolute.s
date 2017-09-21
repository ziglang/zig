# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { foo = ABSOLUTE(.) + 1; };" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readobj --symbols %t | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "PROVIDE(foo = 1 + ABSOLUTE(ADDR(.text)));" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readobj --symbols %t | FileCheck --check-prefix=CHECK-RHS %s

# CHECK:        Name: foo
# CHECK-NEXT:   Value:
# CHECK-NEXT:   Size:
# CHECK-NEXT:   Binding:
# CHECK-NEXT:   Type:
# CHECK-NEXT:   Other:
# CHECK-NEXT:   Section: Absolute
# CHECK-NEXT: }

# CHECK-RHS:        Name: foo
# CHECK-RHS-NEXT:   Value: 0x201001
# CHECK-RHS-NEXT:   Size:
# CHECK-RHS-NEXT:   Binding:
# CHECK-RHS-NEXT:   Type:
# CHECK-RHS-NEXT:   Other:
# CHECK-RHS-NEXT:   Section: Absolute
# CHECK-RHS-NEXT: }

.text
.globl _start
_start:
 nop

.global foo
