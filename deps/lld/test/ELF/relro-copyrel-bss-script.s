// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/copy-in-shared.s -o %t2.o
// RUN: ld.lld -shared %t.o %t2.o -o %t.so

// A linker script that will map .bss.rel.ro into .bss.
// RUN: echo "SECTIONS { \
// RUN: .bss : { *(.bss) *(.bss.*) } \
// RUN: } " > %t.script

// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t3.o
// RUN: ld.lld %t3.o %t.so -z relro -o %t --script=%t.script 2>&1
// RUN: llvm-readobj --program-headers %t | FileCheck %s
        .section .text, "ax", @progbits
        .global bar
        .global foo
        .global _start
_start:
        callq bar
        // Will produce .bss.rel.ro that will match in .bss, this will lose
        // the relro property of the copy relocation.
        .quad foo

        // Non relro bss
        .bss
        // make large enough to affect PT_GNU_RELRO MemSize if this was marked
        // as relro.
        .space 0x2000

// CHECK:     Type: PT_GNU_RELRO (0x6474E552)
// CHECK-NEXT:     Offset:
// CHECK-NEXT:     VirtualAddress:
// CHECK-NEXT:     PhysicalAddress:
// CHECK-NEXT:     FileSize:
// CHECK-NEXT:     MemSize: 4096
// CHECK-NEXT:     Flags [ (0x4)
// CHECK-NEXT:       PF_R (0x4)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Alignment: 1
// CHECK-NEXT:   }
