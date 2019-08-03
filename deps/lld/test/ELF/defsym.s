# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld -o %t %t.o --defsym=foo2=foo1
# RUN: llvm-readobj --symbols -S %t | FileCheck %s
# RUN: llvm-objdump -d -print-imm-hex %t | FileCheck %s --check-prefix=USE

## Check that we accept --defsym foo2=foo1 form.
# RUN: ld.lld -o %t2 %t.o --defsym foo2=foo1
# RUN: llvm-readobj --symbols -S %t2 | FileCheck %s
# RUN: llvm-objdump -d -print-imm-hex %t2 | FileCheck %s --check-prefix=USE

## Check we are reporting the error correctly and don't crash
## when handling the second --defsym.
# RUN: not ld.lld -o %t2 %t.o --defsym ERR+ \
#        --defsym foo2=foo1 2>&1 | FileCheck %s --check-prefix=ERR
# ERR: error: -defsym: syntax error: ERR+

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
# CHECK-NEXT:   Name: foo2
# CHECK-NEXT:   Value: 0x123
# CHECK-NEXT:   Size:
# CHECK-NEXT:   Binding: Global
# CHECK-NEXT:   Type:
# CHECK-NEXT:   Other:
# CHECK-NEXT:   Section: Absolute
# CHECK-NEXT: }

## Check we can use foo2 and it that it is an alias for foo1.
# USE:       Disassembly of section .text:
# USE-EMPTY:
# USE-NEXT:  _start:
# USE-NEXT:    movl $0x123, %edx

# RUN: ld.lld -o %t %t.o --defsym=foo2=1
# RUN: llvm-readobj --symbols -S %t | FileCheck %s --check-prefix=ABS

# ABS:      Symbol {
# ABS:        Name: foo2
# ABS-NEXT:   Value: 0x1
# ABS-NEXT:   Size:
# ABS-NEXT:   Binding: Global
# ABS-NEXT:   Type:
# ABS-NEXT:   Other:
# ABS-NEXT:   Section: Absolute
# ABS-NEXT: }

# RUN: ld.lld -o %t %t.o --defsym=foo2=foo1+5
# RUN: llvm-readobj --symbols -S %t | FileCheck %s --check-prefix=EXPR

# EXPR:      Symbol {
# EXPR:        Name: foo1
# EXPR-NEXT:   Value: 0x123
# EXPR-NEXT:   Size:
# EXPR-NEXT:   Binding: Global
# EXPR-NEXT:   Type:
# EXPR-NEXT:   Other:
# EXPR-NEXT:   Section: Absolute
# EXPR-NEXT: }
# EXPR-NEXT: Symbol {
# EXPR-NEXT:   Name: foo2
# EXPR-NEXT:   Value: 0x128
# EXPR-NEXT:   Size:
# EXPR-NEXT:   Binding: Global
# EXPR-NEXT:   Type:
# EXPR-NEXT:   Other:
# EXPR-NEXT:   Section: Absolute
# EXPR-NEXT: }

# RUN: not ld.lld -o %t %t.o --defsym=foo2=und 2>&1 | FileCheck %s -check-prefix=ERR1
# ERR1: error: -defsym:1: symbol not found: und

# RUN: not ld.lld -o %t %t.o --defsym=xxx=yyy,zzz 2>&1 | FileCheck %s -check-prefix=ERR2
# ERR2: -defsym:1: EOF expected, but got ,

# RUN: not ld.lld -o %t %t.o --defsym=foo 2>&1 | FileCheck %s -check-prefix=ERR3
# ERR3: error: -defsym: syntax error: foo

# RUN: not ld.lld -o %t %t.o --defsym= 2>&1 | FileCheck %s -check-prefix=ERR4
# ERR4: error: -defsym: syntax error:

.globl foo1
 foo1 = 0x123

.global _start
_start:
  movl $foo2, %edx
