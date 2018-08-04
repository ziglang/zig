# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/comdat-discarded-reloc.s -o %t2.o
# RUN: ld.lld -gc-sections %t.o %t2.o -o %t

## ELF spec doesn't allow a relocation to point to a deduplicated
## COMDAT section. Unfortunately this happens in practice (e.g. .eh_frame)
## Test case checks we do not crash.

.global bar, _start

.section .text.foo,"aG",@progbits,group,comdat

.section .text
_start:
 .quad .text.foo
 .quad bar
