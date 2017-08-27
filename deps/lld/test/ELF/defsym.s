# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld -o %t %t.o --defsym=foo2=foo1
# RUN: llvm-readobj -t -s %t | FileCheck %s
# RUN: llvm-objdump -d -print-imm-hex %t | FileCheck %s --check-prefix=USE

## Check that we accept --defsym foo2=foo1 form.
# RUN: ld.lld -o %t2 %t.o --defsym foo2=foo1
# RUN: llvm-readobj -t -s %t2 | FileCheck %s
# RUN: llvm-objdump -d -print-imm-hex %t2 | FileCheck %s --check-prefix=USE

# CHECK:      Symbol {
# CHECK:        Name: foo1
# CHECK-NEXT:   Value: 0x123
# CHECK-NEXT:   Size:
# CHECK-NEXT:   Binding: Global
# CHECK-NEXT:   Type:
# CHECK-NEXT:   Other:
# CHECK-NEXT:   Section: Absolute
# CHECK-NEXT: }
# CHECK-NEXT: Symbol {
# CHECK-NEXT:   Name: foo1
# CHECK-NEXT:   Value: 0x123
# CHECK-NEXT:   Size:
# CHECK-NEXT:   Binding: Global
# CHECK-NEXT:   Type:
# CHECK-NEXT:   Other:
# CHECK-NEXT:   Section: Absolute
# CHECK-NEXT: }

## Check we can use foo2 and it that it is an alias for foo1.
# USE:       Disassembly of section .text:
# USE-NEXT:  _start:
# USE-NEXT:    movl $0x123, %edx

# RUN: not ld.lld -o %t %t.o --defsym=foo2=1 2>&1 | FileCheck %s -check-prefix=ERR1
# ERR1: error: --defsym: symbol name expected, but got 1

# RUN: not ld.lld -o %t %t.o --defsym=foo2=und 2>&1 | FileCheck %s -check-prefix=ERR2
# ERR2: error: -defsym: undefined symbol: und

.globl foo1
 foo1 = 0x123

.global _start
_start:
  movl $foo2, %edx
