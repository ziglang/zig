# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { }" > %t.script
# RUN: not ld.lld %t.o -script %t.script -o /dev/null 2>&1 | FileCheck %s
# CHECK: error: undefined symbol: _edata
# CHECK: >>> referenced by {{.*}}:(.text+0x0)
# CHECK: error: undefined symbol: _etext
# CHECK: >>> referenced by {{.*}}:(.text+0x8)
# CHECK: error: undefined symbol: _end
# CHECK: >>> referenced by {{.*}}:(.text+0x10)

.global _start,_end,_etext,_edata
.text
_start:
 .quad _edata + 0x1
 .quad _etext + 0x1
 .quad _end + 0x1

.data
  .word 1
.bss
  .align 4
  .space 6
