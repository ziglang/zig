# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
# RUN:   %p/Inputs/include.s -o %t2
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
# RUN:   %p/Inputs/notinclude.s -o %t3.notinclude

# RUN: echo "SECTIONS {} " > %t.script
# RUN: ld.lld -o %t --script %t.script %t1 %t2 %t3.notinclude
# RUN: llvm-objdump -d %t | FileCheck %s

# CHECK: Disassembly of section .text:
# CHECK-EMPTY:
# CHECK: _start:
# CHECK-NEXT: :       48 c7 c0 3c 00 00 00    movq    $60, %rax
# CHECK-NEXT: :       48 c7 c7 2a 00 00 00    movq    $42, %rdi
# CHECK-NEXT: :       cc      int3
# CHECK-NEXT: :       cc      int3
# CHECK: _potato:
# CHECK-NEXT: :       90      nop
# CHECK-NEXT: :       90      nop
# CHECK-NEXT: :       cc      int3
# CHECK-NEXT: :       cc      int3
# CHECK: tomato:
# CHECK-NEXT: :       b8 01 00 00 00  movl    $1, %eax

# RUN: echo "SECTIONS { .patatino : \
# RUN: { KEEP(*(EXCLUDE_FILE(*notinclude) .text)) } }" \
# RUN:  > %t.script
# RUN: ld.lld -o %t4 --script %t.script %t1 %t2 %t3.notinclude
# RUN: llvm-objdump -d %t4 | FileCheck %s --check-prefix=EXCLUDE

# EXCLUDE: Disassembly of section .patatino:
# EXCLUDE-EMPTY:
# EXCLUDE: _start:
# EXCLUDE-NEXT: :       48 c7 c0 3c 00 00 00    movq    $60, %rax
# EXCLUDE-NEXT: :       48 c7 c7 2a 00 00 00    movq    $42, %rdi
# EXCLUDE-NEXT: :       cc      int3
# EXCLUDE-NEXT: :       cc      int3
# EXCLUDE: _potato:
# EXCLUDE-NEXT: :       90      nop
# EXCLUDE-NEXT: :       90      nop
# EXCLUDE: Disassembly of section .text:
# EXCLUDE-EMPTY:
# EXCLUDE: tomato:
# EXCLUDE-NEXT: :       b8 01 00 00 00  movl    $1, %eax

.section .text
.globl _start
_start:
    mov $60, %rax
    mov $42, %rdi
