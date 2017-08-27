# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# Provide new symbol. The value should be 1, like set in PROVIDE()
# RUN: echo "SECTIONS { PROVIDE(newsym = 1);}" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck --check-prefix=PROVIDE1 %s
# PROVIDE1: 0000000000000001         *ABS*    00000000 newsym

# Provide new symbol (hidden). The value should be 1
# RUN: echo "SECTIONS { PROVIDE_HIDDEN(newsym = 1);}" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck --check-prefix=HIDDEN1 %s
# HIDDEN1: 0000000000000001         *ABS*    00000000 .hidden newsym

.global _start
_start:
 nop

.globl patatino
patatino:
  movl newsym, %eax
