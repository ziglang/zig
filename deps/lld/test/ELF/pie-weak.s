# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/dummy-shared.s -o %t1.o
# RUN: ld.lld %t1.o -shared -o %t1.so
# RUN: llvm-mc -filetype=obj -relax-relocations=false -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld --hash-style=sysv -pie %t.o %t1.so -o %t
# RUN: llvm-readobj -r %t | FileCheck --check-prefix=RELOCS %s
# RUN: llvm-objdump -d %t | FileCheck --check-prefix=DISASM %s

# RELOCS:      Relocations [
# RELOCS-NEXT:   Section ({{.*}}) .rela.dyn {
# RELOCS-NEXT:     R_X86_64_GLOB_DAT foo 0x0
# RELOCS-NEXT:   }
# RELOCS-NEXT: ]

.weak foo

.globl _start
_start:
# DISASM: _start:
# DISASM-NEXT: 1000: 48 8b 05 a9 10 00 00 movq 4265(%rip), %rax
#                                              ^ .got - (.text + 7)
mov foo@gotpcrel(%rip), %rax
