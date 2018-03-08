// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/wrap-no-real.s -o %t2.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/wrap-no-real2.s -o %t3.o
// RUN: ld.lld -o %t3.so -shared %t3.o

// RUN: ld.lld -o %t %t1.o %t2.o -wrap foo
// RUN: llvm-objdump -d -print-imm-hex %t | FileCheck %s

// RUN: ld.lld -o %t %t1.o %t2.o %t3.so -wrap foo
// RUN: llvm-objdump -d -print-imm-hex %t | FileCheck %s

// CHECK: _start:
// CHECK-NEXT: movl $0x11010, %edx
// CHECK-NEXT: movl $0x11010, %edx
// CHECK-NEXT: movl $0x11000, %edx

// RUN: llvm-readobj -t %t | FileCheck -check-prefix=SYM %s

// Test the full symbol table. It is verbose, but lld at times
// produced duplicated symbols which are hard to test otherwise.

// SYM:       Symbols [
// SYM-NEXT:    Symbol {
// SYM-NEXT:     Name:  (0)
// SYM-NEXT:     Value:
// SYM-NEXT:     Size:
// SYM-NEXT:     Binding:
// SYM-NEXT:     Type
// SYM-NEXT:     Other:
// SYM-NEXT:     Section:
// SYM-NEXT:   }
// SYM-NEXT:   Symbol {
// SYM-NEXT:     Name: _DYNAMIC
// SYM-NEXT:     Value:
// SYM-NEXT:     Size:
// SYM-NEXT:     Binding:
// SYM-NEXT:     Type:
// SYM-NEXT:     Other [
// SYM-NEXT:       STV_HIDDEN
// SYM-NEXT:     ]
// SYM-NEXT:     Section: .dynamic
// SYM-NEXT:   }
// SYM-NEXT:   Symbol {
// SYM-NEXT:     Name: foo
// SYM-NEXT:     Value: 0x11000
// SYM-NEXT:     Size:
// SYM-NEXT:     Binding:
// SYM-NEXT:     Type:
// SYM-NEXT:     Other:
// SYM-NEXT:     Section:
// SYM-NEXT:   }
// SYM-NEXT:   Symbol {
// SYM-NEXT:     Name: _start
// SYM-NEXT:     Value:
// SYM-NEXT:     Size:
// SYM-NEXT:     Binding:
// SYM-NEXT:     Type
// SYM-NEXT:     Other:
// SYM-NEXT:     Section:
// SYM-NEXT:   }
// SYM-NEXT:   Symbol {
// SYM-NEXT:     Name: __wrap_foo
// SYM-NEXT:     Value: 0x11010
// SYM-NEXT:     Size:
// SYM-NEXT:     Binding:
// SYM-NEXT:     Type:
// SYM-NEXT:     Other:
// SYM-NEXT:     Section:
// SYM-NEXT:   }
// SYM-NEXT: ]

.global _start
_start:
  movl $foo, %edx
  movl $__wrap_foo, %edx
  movl $__real_foo, %edx
