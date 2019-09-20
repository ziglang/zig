// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-readobj -S %t.so | FileCheck %s

// CHECK:      Name: .ARM.exidx
// CHECK-NEXT: Type: SHT_ARM_EXIDX
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_LINK_ORDER
// CHECK-NEXT: ]
// CHECK-NEXT: Address:
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size:
// CHECK-NEXT: Link: [[INDEX:.*]]

// CHECK:      Index: [[INDEX]]
// CHECK-NEXT: Name: .text


        f:
	.fnstart
	bx	lr
	.cantunwind
	.fnend
