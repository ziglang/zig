# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/x86-64-reloc-error.s -o %tabs
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
# RUN: not ld.lld -shared %tabs %t -o /dev/null 2>&1 | FileCheck %s

# CHECK: (.debug_info+0x0): relocation R_X86_64_32 out of range: 281474976710656 is not in [0, 4294967295]; consider recompiling with -fdebug-types-section to reduce size of debug sections

.section .debug_info,"",@progbits
 .long .debug_info + 0x1000000000000
