// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: ld.lld %t -o %t2 -shared
// RUN: llvm-readobj -t %t2 | FileCheck %s
// REQUIRES: x86

	leaq	.L.str(%rip), %rdi

	.section	.rodata.str1.1,"aMS",@progbits,1
.L.str:
	.asciz	"foobar"

// Test that the .L symbol is omitted

// CHECK:      Symbols [
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name:  (0)
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: _DYNAMIC
// CHECK-NEXT:     Value: 0x2000
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other [ (0x2)
// CHECK-NEXT:       STV_HIDDEN
// CHECK-NEXT:     ]
// CHECK-NEXT:     Section: .dynamic
// CHECK-NEXT:   }
// CHECK-NEXT: ]
