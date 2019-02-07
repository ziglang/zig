# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
# RUN: ld.lld -pie %t -o %t.out
# RUN: llvm-readobj -t -dyn-symbols %t.out | FileCheck %s

# CHECK:       Symbols [
# CHECK:        Symbol {
# CHECK:          Name: hidden
# CHECK-NEXT:     Value: 0x1000
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Local
# CHECK-NEXT:     Type: None
# CHECK-NEXT:     Other [
# CHECK-NEXT:       STV_HIDDEN
# CHECK-NEXT:     ]
# CHECK-NEXT:     Section: .text
# CHECK-NEXT:   }
# CHECK:        Symbol {
# CHECK:          Name: internal
# CHECK-NEXT:     Value: 0x1000
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Local
# CHECK-NEXT:     Type: None
# CHECK-NEXT:     Other [
# CHECK-NEXT:       STV_INTERNAL
# CHECK-NEXT:     ]
# CHECK-NEXT:     Section: .text
# CHECK-NEXT:   }
# CHECK:        Symbol {
# CHECK:          Name: default
# CHECK-NEXT:     Value: 0x1000
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Global
# CHECK-NEXT:     Type: None
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: .text
# CHECK-NEXT:   }
# CHECK:        Symbol {
# CHECK:          Name: protected
# CHECK-NEXT:     Value: 0x1000
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Global
# CHECK-NEXT:     Type: None
# CHECK-NEXT:     Other [
# CHECK-NEXT:       STV_PROTECTED
# CHECK-NEXT:     ]
# CHECK-NEXT:     Section: .text
# CHECK-NEXT:   }
# CHECK-NEXT: ]

# CHECK:      DynamicSymbols [
# CHECK-NEXT:  Symbol {
# CHECK-NEXT:    Name:
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
.protected protected
protected:

.global hidden
.hidden hidden
hidden:

.global internal
.internal internal
internal:
