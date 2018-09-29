# REQUIRES: mips

# Check addend adjustment in case of generating a relocatable object
# if some input files have non-zero GP0 value.

# We have to use GNU as and ld.bfd 2.28 to generate relocatable object
# files with non-zero GP0 value using the following command lines:
#
# as -mips32 -o test.o \
#   && ld.bfd -m elf32btsmip -r test.o -o mips-gp0-non-zero.o
# as -mips64 -o test.o \
#   && ld.bfd -m elf64btsmip -r test.o -o mips-n64-gp0-non-zero.o

# Source code for mips-gp0-non-zero.o:
#   .text
#   .global  __start
# __start:
#   lw      $t0,%call16(__start)($gp)
# foo:
#   nop
# bar:
#   nop
#
#   .section .rodata, "a"
# v:
#   .gpword foo
#   .gpword bar

# Source code for mips-n64-gp0-non-zero.o and mips-micro-gp0-non-zero.o:
#   .text
#   .global  __start
# __start:
# foo:
#   lui     $gp,%hi(%neg(%gp_rel(foo)))

# RUN: ld.lld -r -o %t-32.r %S/Inputs/mips-gp0-non-zero.o
# RUN: llvm-readobj -mips-reginfo %t-32.r | FileCheck --check-prefix=GPVAL %s
# RUN: llvm-objdump -s %t-32.r | FileCheck --check-prefix=ADDEND32 %s

# RUN: ld.lld -r -o %t-64.r %S/Inputs/mips-n64-gp0-non-zero.o
# RUN: llvm-readobj -mips-options %t-64.r | FileCheck --check-prefix=GPVAL %s
# RUN: llvm-readobj -r %S/Inputs/mips-n64-gp0-non-zero.o %t-64.r \
# RUN:   | FileCheck --check-prefix=ADDEND64 %s

# GPVAL: GP: 0x0

# ADDEND32:      Contents of section .rodata:
# ADDEND32-NEXT:  0000 00007ff4 00007ff8
#                      ^ 4+GP0  ^ 8+GP0

# ADDEND64: File: {{.*}}{{/|\\}}mips-n64-gp0-non-zero.o
# ADDEND64: .text 0xFFFFFFFFFFFF8011
# ADDEND64: File: {{.*}}{{/|\\}}mips-non-zero-gp0.s.tmp-64.r
# ADDEND64: .text 0x0
