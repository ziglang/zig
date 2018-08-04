// REQUIRES: arm
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=armv7a-linux-gnueabi
// RUN: ld.lld %t.o -o %t
// RUN: llvm-readobj -s -dyn-relocations %t | FileCheck --check-prefix=SEC %s
// RUN: llvm-objdump -d -triple=armv7a-linux-gnueabi %t | FileCheck %s

// Test the handling of the local exec TLS model. TLS can be resolved
// statically for an application. The code sequences assume a thread pointer
// in r9

 .text
 .syntax unified
 .globl  _start
 .p2align        2
 .type   _start,%function
_start:
 .p2align        2
// Generate R_ARM_TLS_LE32 relocations. These resolve statically to the offset
// of the variable from the thread pointer
.Lt0: .word   x(TPOFF)
.Lt1: .word   y(TPOFF)
.Lt2: .word   z(TPOFF)

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
// SEC-NEXT: Address: 0x12000
// SEC:      Size: 4
// SEC:      Name: .tbss
// SEC-NEXT: Type: SHT_NOBITS
// SEC-NEXT: Flags [
// SEC-NEXT:   SHF_ALLOC
// SEC-NEXT:   SHF_TLS
// SEC-NEXT:   SHF_WRITE
// SEC-NEXT: ]
// SEC-NEXT: Address: 0x12004
// SEC:      Size: 8

// SEC: Dynamic Relocations {
// SEC-NEXT: }

// CHECK: Disassembly of section .text:
// CHECK-NEXT: _start:
// offset of x from Thread pointer = (TcbSize + 0x0 = 0x8)
// CHECK-NEXT:   11000:         08 00 00 00
// offset of z from Thread pointer = (TcbSize + 0x8 = 0x10)
// CHECK-NEXT:   11004:         10 00 00 00
// offset of y from Thread pointer = (TcbSize + 0x4 = 0xc)
// CHECK-NEXT:   11008:         0c 00 00 00
