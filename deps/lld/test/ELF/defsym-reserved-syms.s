# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld -o %t %t.o --defsym=foo2=etext
# RUN: llvm-readobj --symbols -S %t | FileCheck %s

## Check 'foo2' value is equal to value of 'etext'.
# CHECK:     Symbol {
# CHECK:      Name: foo2
# CHECK-NEXT:  Value: 0x[[VAL:.*]]
# CHECK:     Symbol {
# CHECK:      Name: etext
# CHECK-NEXT:  Value: 0x[[VAL]]

## Check 'foo2' value set correctly when using
## reserved symbol 'etext' in expression.
# RUN: ld.lld -o %t %t.o --defsym=foo2=etext+2
# RUN: llvm-readobj --symbols -S %t | FileCheck %s --check-prefix=EXPR
# EXPR:     Symbol {
# EXPR:      Name: foo2
# EXPR-NEXT:  Value: 0x201007
# EXPR:     Symbol {
# EXPR:      Name: etext
# EXPR-NEXT:  Value: 0x201005

.globl foo1
 foo1 = 0x123

.global _start
_start:
  movl $foo2, %edx
