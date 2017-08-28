# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %tfirst.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
# RUN:   %p/Inputs/filename-spec.s -o %tsecond.o

# RUN: echo "SECTIONS { .foo : { \
# RUN:   KEEP(*first.o(.foo)) \
# RUN:   KEEP(*second.o(.foo)) } }" > %t1.script
# RUN: ld.lld -o %t1 --script %t1.script %tfirst.o %tsecond.o
# RUN: llvm-objdump -s %t1 | FileCheck --check-prefix=FIRSTSECOND %s
# FIRSTSECOND:      Contents of section .foo:
# FIRSTSECOND-NEXT:   01000000 00000000 11000000 00000000

# RUN: echo "SECTIONS { .foo : { \
# RUN:   KEEP(*second.o(.foo)) \
# RUN:   KEEP(*first.o(.foo)) } }" > %t2.script
# RUN: ld.lld -o %t2 --script %t2.script %tfirst.o %tsecond.o
# RUN: llvm-objdump -s %t2 | FileCheck --check-prefix=SECONDFIRST %s
# SECONDFIRST:      Contents of section .foo:
# SECONDFIRST-NEXT:   11000000 00000000 01000000 00000000

## Now the same tests but without KEEP. Checking that file name inside
## KEEP is parsed fine.
# RUN: echo "SECTIONS { .foo : { \
# RUN:   *first.o(.foo) \
# RUN:   *second.o(.foo) } }" > %t3.script
# RUN: ld.lld -o %t3 --script %t3.script %tfirst.o %tsecond.o
# RUN: llvm-objdump -s %t3 | FileCheck --check-prefix=FIRSTSECOND %s

# RUN: echo "SECTIONS { .foo : { \
# RUN:   *second.o(.foo) \
# RUN:   *first.o(.foo) } }" > %t4.script
# RUN: ld.lld -o %t4 --script %t4.script %tfirst.o %tsecond.o
# RUN: llvm-objdump -s %t4 | FileCheck --check-prefix=SECONDFIRST %s

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %T/filename-spec1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
# RUN:   %p/Inputs/filename-spec.s -o %T/filename-spec2.o

# RUN: echo "SECTIONS { .foo : { \
# RUN:   filename-spec2.o(.foo) \
# RUN:   filename-spec1.o(.foo) } }" > %t5.script
# RUN: ld.lld -o %t5 --script %t5.script \
# RUN:   %T/filename-spec1.o %T/filename-spec2.o
# RUN: llvm-objdump -s %t5 | FileCheck --check-prefix=SECONDFIRST %s

# RUN: echo "SECTIONS { .foo : { \
# RUN:   filename-spec1.o(.foo) \
# RUN:   filename-spec2.o(.foo) } }" > %t6.script
# RUN: ld.lld -o %t6 --script %t6.script \
# RUN:   %T/filename-spec1.o %T/filename-spec2.o
# RUN: llvm-objdump -s %t6 | FileCheck --check-prefix=FIRSTSECOND %s

.global _start
_start:
 nop

.section .foo,"a"
 .quad 1
