# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: echo "SECTIONS { A = . - 0x10; B = A + 0x1; }" > %t.script
# RUN: ld.lld -shared %t1.o --script %t.script -o %t
# RUN: llvm-objdump -d %t | FileCheck %s --check-prefix=DUMP
# RUN: llvm-readobj --symbols %t | FileCheck %s --check-prefix=SYMBOL

# B = A + 0x1 = -0x10 + 0x1 = -0xf -> 0xFFFFFFFFFFFFFFF1
# B - (0x94+6) = -0xf - (0x94+6) = -169
# DUMP:       Disassembly of section .text:
# DUMP-EMPTY:
# DUMP-NEXT:  foo:
# DUMP-NEXT:   94: {{.*}} -169(%rip), %eax

# SYMBOL:     Symbol {
# SYMBOL:        Name: B
# SYMBOL-NEXT:   Value: 0xFFFFFFFFFFFFFFF1
# SYMBOL-NEXT:   Size: 0
# SYMBOL-NEXT:   Binding: Local
# SYMBOL-NEXT:   Type: None
# SYMBOL-NEXT:   Other [
# SYMBOL-NEXT:     STV_HIDDEN
# SYMBOL-NEXT:   ]
# SYMBOL-NEXT:   Section: .dynsym
# SYMBOL-NEXT: }

.text
.globl foo
.type foo, @function
foo:
 movl B(%rip), %eax

.hidden B
