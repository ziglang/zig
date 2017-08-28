// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=armv7a-linux-gnueabi
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-readobj -s -dyn-relocations %t.so | FileCheck --check-prefix=SEC %s
// RUN: llvm-objdump -d -triple=armv7a-linux-gnueabi %t.so | FileCheck %s
// REQUIRES: arm

// Test the handling of the global-dynamic TLS model. Dynamic Loader finds
// module index R_ARM_TLS_DTPMOD32 and the offset within the module
// R_ARM_TLS_DTPOFF32. One of the variables is hidden which permits relaxation
// to local dynamic

 .text
 .syntax unified
 .globl  func
 .p2align        2
 .type   func,%function
func:
.L0:
 nop
.L1:
 nop
.L2:
 nop

 .p2align        2
// Generate R_ARM_TLS_GD32 relocations
// Allocates a pair of GOT entries dynamically relocated by R_ARM_TLS_DTPMOD32
// and R_ARM_TLS_DTPOFF32 respectively. The literal contains the offset of the
// first GOT entry from the place
.Lt0: .word   x(TLSGD) + (. - .L0 - 8)
.Lt1: .word   y(TLSGD) + (. - .L1 - 8)
.Lt2: .word   z(TLSGD) + (. - .L2 - 8)

// __thread int x = 10
// __thread int y;
// __thread int z __attribute((visibility("hidden")))

 .hidden z
 .globl  z
 .globl  y
 .globl  x

 .section       .tbss,"awT",%nobits
 .p2align  2
.TLSSTART:
 .type  z, %object
z:
 .space 4
 .type  y, %object
y:
 .space 4
 .section       .tdata,"awT",%progbits
 .p2align 2
 .type  x, %object
x:
 .word  10

// SEC:      Name: .tdata
// SEC-NEXT: Type: SHT_PROGBITS
// SEC-NEXT: Flags [
// SEC-NEXT:   SHF_ALLOC
// SEC-NEXT:   SHF_TLS
// SEC-NEXT:   SHF_WRITE
// SEC-NEXT:  ]
// SEC-NEXT: Address: 0x2000
// SEC:      Size: 4
// SEC:      Name: .tbss
// SEC-NEXT: Type: SHT_NOBITS
// SEC-NEXT: Flags [
// SEC-NEXT:   SHF_ALLOC
// SEC-NEXT:   SHF_TLS
// SEC-NEXT:   SHF_WRITE
// SEC-NEXT: ]
// SEC-NEXT: Address: 0x2004
// SEC:      Size: 8

// SEC:      Name: .got
// SEC-NEXT: Type: SHT_PROGBITS
// SEC-NEXT: Flags [
// SEC-NEXT:   SHF_ALLOC
// SEC-NEXT:   SHF_WRITE
// SEC-NEXT: ]
// SEC-NEXT: Address: 0x204C
// SEC:      Size: 24

// SEC: Dynamic Relocations {
// SEC-NEXT: 0x205C R_ARM_TLS_DTPMOD32 -
// SEC-NEXT: 0x204C R_ARM_TLS_DTPMOD32 x
// SEC-NEXT: 0x2050 R_ARM_TLS_DTPOFF32 x
// SEC-NEXT: 0x2054 R_ARM_TLS_DTPMOD32 y
// SEC-NEXT: 0x2058 R_ARM_TLS_DTPOFF32 y


// CHECK: Disassembly
// CHECK-NEXT: func:
// CHECK-NEXT:    1000:      00 f0 20 e3     nop
// CHECK-NEXT:    1004:      00 f0 20 e3     nop
// CHECK-NEXT:    1008:      00 f0 20 e3     nop

// (0x204c - 0x100c) + (0x100c - 0x1000 - 8) = 0x1044
// CHECK:    100c:	44 10 00 00
// (0x2054 - 0x1010) + (0x1010 - 0x1004 - 8) = 0x1048
// CHECK-NEXT:    1010:	48 10 00 00
// (0x205c - 0x1014) + (0x1014 - 0x1008 - 8) = 0x104c
// CHECK-NEXT:    1014:	4c 10 00 00

