// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/x86-64-reloc-error.s -o %tabs
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: not ld.lld -shared %tabs %t -o %t2 2>&1 | FileCheck %s
// REQUIRES: x86

  movl $big, %edx
  movq $foo - 0x1000000000000, %rdx

# CHECK: {{.*}}:(.text+0x1): relocation R_X86_64_32 out of range: 68719476736 is not in [0, 4294967295]
# CHECK: {{.*}}:(.text+0x8): relocation R_X86_64_32S out of range: -281474976710656 is not in [-2147483648, 2147483647]
