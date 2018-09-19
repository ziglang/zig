// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: not ld.lld %t.o -o /dev/null 2>&1 | FileCheck %s
// CHECK: SHF_MERGE section size must be a multiple of sh_entsize

// Test that we accept a zero sh_entsize.
// RUN: ld.lld %p/Inputs/shentsize-zero.elf -o /dev/null

.section .foo,"aM",@progbits,4
.short 42
