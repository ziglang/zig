# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t2.o
# RUN: ld.lld -shared %t2.o -o %t2.so -soname relro-omagic.s.tmp2.so
# RUN: ld.lld --hash-style=sysv -N %t.o -Bdynamic %t2.so -o %t
# RUN: llvm-objdump -section-headers %t | FileCheck --check-prefix=NORELRO %s
# RUN: llvm-readobj --program-headers %t | FileCheck --check-prefix=NOPHDRS %s

# NORELRO:      Sections:
# NORELRO-NEXT: Idx Name          Size     VMA              Type
# NORELRO-NEXT:   0               00000000 0000000000000000
# NORELRO-NEXT:   1 .dynsym       00000048 0000000000200120
# NORELRO-NEXT:   2 .hash         00000020 0000000000200168
# NORELRO-NEXT:   3 .dynstr       00000021 0000000000200188
# NORELRO-NEXT:   4 .rela.dyn     00000018 00000000002001b0
# NORELRO-NEXT:   5 .rela.plt     00000018 00000000002001c8
# NORELRO-NEXT:   6 .text         0000000a 00000000002001e0 TEXT
# NORELRO-NEXT:   7 .plt          00000020 00000000002001f0 TEXT
# NORELRO-NEXT:   8 .data         00000008 0000000000200210 DATA
# NORELRO-NEXT:   9 .foo          00000004 0000000000200218 DATA
# NORELRO-NEXT:  10 .dynamic      000000f0 0000000000200220
# NORELRO-NEXT:  11 .got          00000008 0000000000200310 DATA
# NORELRO-NEXT:  12 .got.plt      00000020 0000000000200318 DATA

# NOPHDRS:     ProgramHeaders [
# NOPHDRS-NOT: PT_GNU_RELRO

.long bar
jmp *bar2@GOTPCREL(%rip)

.section .data,"aw"
.quad 0

.section .foo,"aw"
.zero 4
