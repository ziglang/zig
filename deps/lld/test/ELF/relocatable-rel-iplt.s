# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i686-- %s -o %t1.o
# RUN: ld.lld -r %t1.o -o %t2.o
# RUN: llvm-readobj --symbols %t2.o | FileCheck %s

// CHECK:      Symbols [
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name:  (0)
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local (0x0)
// CHECK-NEXT:     Type: None (0x0)
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined (0x0)
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: .text (0)
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local (0x0)
// CHECK-NEXT:     Type: Section (0x3)
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text (0x1)
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: __rel_iplt_end (1)
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Weak (0x2)
// CHECK-NEXT:     Type: None (0x0)
// CHECK-NEXT:     Other [ (0x2)
// CHECK-NEXT:       STV_HIDDEN (0x2)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Section: Undefined (0x0)
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: __rel_iplt_start (16)
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Weak (0x2)
// CHECK-NEXT:     Type: None (0x0)
// CHECK-NEXT:     Other [ (0x2)
// CHECK-NEXT:       STV_HIDDEN (0x2)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Section: Undefined (0x0)
// CHECK-NEXT:   }
// CHECK-NEXT: ]

	movl	__rel_iplt_start, %eax
	movl	__rel_iplt_end, %eax
	ret

	.hidden	__rel_iplt_start
	.hidden	__rel_iplt_end
	.weak	__rel_iplt_start
	.weak	__rel_iplt_end
