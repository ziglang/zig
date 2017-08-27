# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -relax-relocations=false -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld -pie %t.o -o %t
# RUN: llvm-readobj -r %t | FileCheck --check-prefix=RELOCS %s
# RUN: llvm-objdump -d %t | FileCheck --check-prefix=DISASM %s

# RELOCS:      Relocations [
# RELOCS-NEXT: ]

.weak foo

.globl _start
_start:
# DISASM: _start:
# DISASM-NEXT: 1000: 48 8b 05 69 10 00 00 movq 4201(%rip), %rax
#                                              ^ .got - (.text + 7)
mov foo@gotpcrel(%rip), %rax
