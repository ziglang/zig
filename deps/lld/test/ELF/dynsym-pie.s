# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
# RUN: ld.lld -pie %t -o %t.out
# RUN: llvm-readobj -t -dyn-symbols %t.out | FileCheck %s

# CHECK:      DynamicSymbols [
# CHECK-NEXT:  Symbol {
# CHECK-NEXT:    Name: @
# CHECK-NEXT:    Value: 0x0
# CHECK-NEXT:    Size: 0
# CHECK-NEXT:    Binding: Local
# CHECK-NEXT:    Type: None
# CHECK-NEXT:    Other: 0
# CHECK-NEXT:    Section: Undefined
# CHECK-NEXT:  }
# CHECK-NEXT: ]

.text
.globl _start
_start:

.global default
default:

.global protected
protected:

.global hidden
hidden:

.global internal
internal:

.global protected_with_hidden
.protected
protected_with_hidden:
