// REQUIRES: aarch64
// RUN: llvm-mc %s -o %t.o -triple aarch64-pc-linux -filetype=obj
// RUN: ld.lld --hash-style=sysv %t.o -o %t.so -shared
// RUN: llvm-readobj -s %t.so | FileCheck --check-prefix=SEC %s
// RUN: llvm-objdump -d %t.so | FileCheck %s

foo:
        adrp    x0, :tlsdesc:bar
        ldr     x1, [x0, :tlsdesc_lo12:bar]
        add     x0, x0, :tlsdesc_lo12:bar
        .tlsdesccall bar
        blr     x1


        .section        .tdata,"awT",@progbits
bar:
        .word   42


// SEC:      Name: .got
// SEC-NEXT: Type: SHT_PROGBITS
// SEC-NEXT: Flags [
// SEC-NEXT:   SHF_ALLOC
// SEC-NEXT:   SHF_WRITE
// SEC-NEXT: ]
// SEC-NEXT: Address: 0x20098
// SEC-NEXT: Offset: 0x20098
// SEC-NEXT: Size: 16

// page(0x20098) - page(0x10000) = 65536
// 0x98 = 152

// CHECK:      foo:
// CHECK-NEXT: 10000: {{.*}} adrp x0, #65536
// CHECK-NEXT: 10004: {{.*}} ldr  x1, [x0, #152]
// CHECK-NEXT: 10008: {{.*}} add  x0, x0, #152
// CHECK-NEXT: 1000c: {{.*}} blr  x1
