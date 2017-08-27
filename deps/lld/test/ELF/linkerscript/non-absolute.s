# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: echo "SECTIONS { A = . - 0x10; B = A + 0x1; }" > %t.script
# RUN: ld.lld -shared %t1.o --script %t.script -o %t
# RUN: llvm-objdump -d %t | FileCheck %s --check-prefix=DUMP
# RUN: llvm-readobj -t %t | FileCheck %s --check-prefix=SYMBOL

# DUMP:       Disassembly of section .text:
# DUMP-NEXT:  foo:
# DUMP-NEXT:   0: {{.*}} -21(%rip), %eax

# SYMBOL:     Symbol {
# SYMBOL:        Name: B
# SYMBOL-NEXT:   Value: 0xFFFFFFFFFFFFFFF1
# SYMBOL-NEXT:   Size: 0
# SYMBOL-NEXT:   Binding: Local
# SYMBOL-NEXT:   Type: None
# SYMBOL-NEXT:   Other [
# SYMBOL-NEXT:     STV_HIDDEN
# SYMBOL-NEXT:   ]
# SYMBOL-NEXT:   Section: .text
# SYMBOL-NEXT: }

.text
.globl foo
.type foo, @function
foo:
 movl B(%rip), %eax

.hidden B
