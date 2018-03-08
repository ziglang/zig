// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-pc-linux %s -o %t.o
// RUN: ld.lld --hash-style=sysv -shared %t.o -o %t.so
// RUN: llvm-objdump -d %t.so | FileCheck %s
// RUN: llvm-readobj -r %t.so | FileCheck --check-prefix=REL %s

	.text
        adrp    x0, :tlsdesc:a
        ldr     x1, [x0, :tlsdesc_lo12:a]
        add     x0, x0, :tlsdesc_lo12:a
        .tlsdesccall a
        blr     x1

// Create relocation against local TLS symbols where linker should
// create target specific dynamic TLSDESC relocation where addend is
// the symbol VMA in tls block.

// CHECK:      10000: {{.*}}  adrp    x0, #65536
// CHECK-NEXT: 10004: {{.*}}  ldr     x1, [x0, #144]
// CHECK-NEXT: 10008: {{.*}}  add     x0, x0, #144
// CHECK-NEXT: 1000c: {{.*}}  blr     x1

	adrp	x0, :tlsdesc:local1
	ldr	x1, [x0, :tlsdesc_lo12:local1]
	add	x0, x0, :tlsdesc_lo12:local1
        .tlsdesccall a
        blr     x1

// CHECK:      10010: {{.*}}  adrp    x0, #65536
// CHECK-NEXT: 10014: {{.*}}  ldr     x1, [x0, #160]
// CHECK-NEXT: 10018: {{.*}}  add     x0, x0, #160
// CHECK-NEXT: 1001c: {{.*}}  blr     x1

	adrp	x0, :tlsdesc:local2
	ldr	x1, [x0, :tlsdesc_lo12:local2]
	add	x0, x0, :tlsdesc_lo12:local2
        .tlsdesccall a
        blr     x1

// CHECK:      10020: {{.*}}  adrp    x0, #65536
// CHECK-NEXT: 10024: {{.*}}  ldr     x1, [x0, #176]
// CHECK-NEXT: 10028: {{.*}}  add     x0, x0, #176
// CHECK-NEXT: 1002c: {{.*}}  blr     x1

        .section .tbss,"awT",@nobits
        .type   local1,@object
        .p2align 2
local1:
        .word   0
        .size   local1, 4

        .type   local2,@object
        .p2align 3
local2:
        .xword  0
        .size   local2, 8


// 0x1000 + 4096 + 160 = 0x20A0
// 0x1000 + 4096 + 176 = 0x20B0
// 0x1000 + 4096 + 144 = 0x2090

// R_AARCH64_TLSDESC - 0x0 -> start of tls block
// R_AARCH64_TLSDESC - 0x8 -> align (sizeof (local1), 8)

// REL:      Relocations [
// REL-NEXT:   Section (4) .rela.dyn {
// REL-NEXT:     0x200A0 R_AARCH64_TLSDESC - 0x0
// REL-NEXT:     0x200B0 R_AARCH64_TLSDESC - 0x8
// REL-NEXT:     0x20090 R_AARCH64_TLSDESC a 0x0
// REL-NEXT:   }
// REL-NEXT: ]
