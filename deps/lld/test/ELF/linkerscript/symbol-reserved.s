# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "PROVIDE_HIDDEN(newsym = __ehdr_start + 5);" > %t.script
# RUN: ld.lld -o %t1 %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck %s

# CHECK: 0000000000200005 .text 00000000 .hidden newsym

# RUN: ld.lld -o %t1.so %t.script %t -shared
# RUN: llvm-objdump -t %t1.so | FileCheck --check-prefix=SHARED %s

# SHARED: 0000000000000005 .dynsym 00000000 .hidden newsym

# RUN: echo "PROVIDE_HIDDEN(newsym = ALIGN(__ehdr_start, CONSTANT(MAXPAGESIZE)) + 5);" > %t.script
# RUN: ld.lld -o %t1 %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck --check-prefix=ALIGNED %s

# ALIGNED: 0000000000200005 .text 00000000 .hidden newsym

.global _start
_start:
  lea newsym(%rip),%rax
