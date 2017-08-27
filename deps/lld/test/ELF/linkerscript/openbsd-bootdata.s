# RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %s -o %t.o
# RUN: echo "PHDRS { boot PT_OPENBSD_BOOTDATA; }" > %t.script
# RUN: ld.lld --script %t.script %t.o -o %t
# RUN: llvm-readobj --program-headers -s %t | FileCheck %s

# CHECK:      ProgramHeader {
# CHECK:        Type: PT_OPENBSD_BOOTDATA (0x65A41BE6)
