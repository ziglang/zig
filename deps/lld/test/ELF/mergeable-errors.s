# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: not ld.lld %t.o -o %t1 2>&1 | FileCheck %s

# CHECK: error: {{.*}}.o:(.mergeable): string is not null terminated

.section .mergeable,"MS",@progbits,2
  .short 0x1122
