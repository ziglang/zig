// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %s -o %t.o
// RUN: ld.lld %t.o -o %t
// RUN: llvm-readelf -r %t | FileCheck --check-prefix=RELOC %s
// RUN: llvm-readelf -x .got %t | FileCheck %s

// RELOC: no relocations

// CHECK: 0x00220000 00000000 00000000

        .globl  _start
_start:
        adrp    x8, :got:foo
        ldr     x8, [x8, :got_lo12:foo]
        ldr     w0, [x8]
        ret

        .weak   foo
