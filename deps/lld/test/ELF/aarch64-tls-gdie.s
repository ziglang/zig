// REQUIRES: aarch64
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=aarch64-pc-linux
// RUN: llvm-mc %p/Inputs/aarch64-tls-gdie.s -o %t2.o -filetype=obj -triple=aarch64-pc-linux
// RUN: ld.lld %t2.o -o %t2.so -shared
// RUN: ld.lld --hash-style=sysv %t.o %t2.so -o %t
// RUN: llvm-readobj -s %t | FileCheck --check-prefix=SEC %s
// RUN: llvm-objdump -d %t | FileCheck %s

        .globl  _start
_start:
        nop
        adrp    x0, :tlsdesc:a
        ldr     x1, [x0, :tlsdesc_lo12:a]
        add     x0, x0, :tlsdesc_lo12:a
        .tlsdesccall a
        blr     x1

// SEC:      Name: .got
// SEC-NEXT: Type: SHT_PROGBITS
// SEC-NEXT: Flags [
// SEC-NEXT:   SHF_ALLOC
// SEC-NEXT:   SHF_WRITE
// SEC-NEXT: ]
// SEC-NEXT: Address: 0x300B0

// page(0x300B0) - page(0x20004) = 65536
// 0x0B0 = 176

// CHECK:      _start:
// CHECK-NEXT: 20000: {{.*}} nop
// CHECK-NEXT: 20004: {{.*}} adrp       x0, #65536
// CHECK-NEXT: 20008: {{.*}} ldr        x0, [x0, #176]
// CHECK-NEXT: 2000c: {{.*}} nop
// CHECK-NEXT: 20010: {{.*}} nop
