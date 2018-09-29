// REQUIRES: arm
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=armv7a-linux-gnueabi
// RUN: ld.lld --hash-style=sysv %t.o -o %t.so -shared
// RUN: llvm-readobj -s -dyn-relocations %t.so | FileCheck --check-prefix=SEC %s
// RUN: llvm-objdump -d -triple=armv7a-linux-gnueabi %t.so | FileCheck %s

// Test the handling of the local-dynamic TLS model. Dynamic loader finds
// module index R_ARM_TLS_DTPMOD32. The offset in the next GOT slot is 0
// The R_ARM_TLS_LDO is the offset of the variable within the TLS block.
 .global __tls_get_addr
 .text
 .p2align  2
 .global _start
 .syntax unified
 .arm
 .type   _start, %function
_start:
.L0:
 nop

 .word   x(tlsldm) + (. - .L0 - 8)
 .word   x(tlsldo)
 .word   y(tlsldo)

 .section        .tbss,"awT",%nobits
 .p2align  2
 .type   y, %object
y:
 .space  4
 .section        .tdata,"awT",%progbits
 .p2align  2
 .type   x, %object
x:
 .word   10

// SEC:      Name: .tdata
// SEC-NEXT: Type: SHT_PROGBITS
// SEC-NEXT: Flags [
// SEC-NEXT:   SHF_ALLOC
// SEC-NEXT:   SHF_TLS
// SEC-NEXT:   SHF_WRITE
// SEC-NEXT: ]
// SEC-NEXT: Address: 0x2000
// SEC:    Size: 4
// SEC:    Name: .tbss
// SEC-NEXT: Type: SHT_NOBITS (0x8)
// SEC-NEXT: Flags [
// SEC-NEXT:   SHF_ALLOC
// SEC-NEXT:   SHF_TLS
// SEC-NEXT:   SHF_WRITE
// SEC-NEXT: ]
// SEC-NEXT: Address: 0x2004
// SEC:      Size: 4

// SEC: Dynamic Relocations {
// SEC-NEXT:  0x204C R_ARM_TLS_DTPMOD32 - 0x0

// CHECK: Disassembly of section .text:
// CHECK-NEXT: _start:
// CHECK-NEXT: 1000:       00 f0 20 e3     nop

// (0x204c - 0x1004) + (0x1004 - 0x1000 - 8) = 0x1044
// CHECK:      1004:       44 10 00 00
// CHECK-NEXT: 1008:       00 00 00 00
// CHECK-NEXT: 100c:       04 00 00 00

// CHECK-EXE: Disassembly of section .text:
// CHECK-NEXT-EXE: _start:
// CHECK-NEXT-EXE:   11000:       00 f0 20 e3     nop

// CHECK-EXE:   11004:       fc 0f 00 00
// CHECK-EXE:   11008:       00 00 00 00
// CHECK-EXE:   1100c:       04 00 00 00
