# REQUIRES: x86
# RUN: rm -f %t.a
# RUN: llvm-ar rc %t.a
# RUN: ld.lld -m elf_x86_64 %t.a -o %t -r
# RUN: llvm-readobj --file-headers %t | FileCheck %s

# CHECK: Format: ELF64-x86-64
# CHECK: Arch: x86_64
# CHECK: AddressSize: 64bit
# CHECK: Type: Relocatable
