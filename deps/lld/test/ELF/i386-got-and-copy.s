# REQUIRES: x86

# If there are two relocations such that the first one requires
# dynamic COPY relocation, the second one requires GOT entry
# creation, linker should create both - dynamic relocation
# and GOT entry.

# RUN: llvm-mc -filetype=obj -triple=i386-pc-linux \
# RUN:         %S/Inputs/copy-in-shared.s -o %t.so.o
# RUN: llvm-mc -filetype=obj -triple=i386-pc-linux %s -o %t.o
# RUN: ld.lld %t.so.o -shared -o %t.so
# RUN: ld.lld --hash-style=sysv %t.o %t.so -o %t.exe
# RUN: llvm-readobj -r %t.exe | FileCheck %s

# CHECK:      Relocations [
# CHECK-NEXT:   Section (4) .rel.dyn {
# CHECK-NEXT:     0x{{[0-9A-F]+}} R_386_COPY foo
# CHECK-NEXT:   }
# CHECK-NEXT: ]

  .text
  .global _start
_start:
  movl $foo, (%esp)     # R_386_32 - requires R_386_COPY relocation
  movl foo@GOT, %eax    # R_386_GOT32 - requires GOT entry
