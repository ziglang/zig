# REQUIRES: mips
# Check R_MIPS_GOT16 relocation calculation.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t-be.o
# RUN: ld.lld %t-be.o -o %t-be.exe
# RUN: llvm-readobj --sections -r --symbols --mips-plt-got %t-be.exe \
# RUN:   | FileCheck -check-prefixes=ELF,EXE %s
# RUN: llvm-objdump -d %t-be.exe | FileCheck -check-prefix=DIS %s

# RUN: llvm-mc -filetype=obj -triple=mipsel-unknown-linux %s -o %t-el.o
# RUN: ld.lld %t-el.o -o %t-el.exe
# RUN: llvm-readobj --sections -r --symbols --mips-plt-got %t-el.exe \
# RUN:   | FileCheck -check-prefixes=ELF,EXE %s
# RUN: llvm-objdump -d %t-el.exe | FileCheck -check-prefix=DIS %s

# RUN: ld.lld -shared %t-be.o -o %t-be.so
# RUN: llvm-readobj --sections -r --symbols --mips-plt-got %t-be.so \
# RUN:   | FileCheck -check-prefixes=ELF,DSO %s
# RUN: llvm-objdump -d %t-be.so | FileCheck -check-prefix=DIS %s

# RUN: ld.lld -shared %t-el.o -o %t-el.so
# RUN: llvm-readobj --sections -r --symbols --mips-plt-got %t-el.so \
# RUN:   | FileCheck -check-prefixes=ELF,DSO %s
# RUN: llvm-objdump -d %t-el.so | FileCheck -check-prefix=DIS %s

  .text
  .globl  __start
__start:
  lui $2, %got(v1)

  .data
  .globl v1
  .type  v1,@object
  .size  v1,4
v1:
  .word 0

# ELF:      Section {
# ELF:        Name: .got
# ELF:        Flags [
# ELF-NEXT:     SHF_ALLOC
# ELF-NEXT:     SHF_MIPS_GPREL
# ELF-NEXT:     SHF_WRITE
# ELF-NEXT:   ]
#
# ELF:      Relocations [
# ELF-NEXT: ]
#
# ELF:      Symbol {
# ELF:        Name: v1
# ELF-NEXT:   Value: 0x[[V1:[0-9A-F]+]]
#
# ELF:      {{.*}} GOT {
# EXE-NEXT:   Canonical gp value: 0x38000
# DSO-NEXT:   Canonical gp value: 0x28000
#
# ELF:        Entry {
# EXE:          Address: 0x30018
# DSO:          Address: 0x20018
# ELF-NEXT:     Access: -32744
# ELF-NEXT:     Initial: 0x[[V1]]

# "v1 GOT entry address" - _gp
# exe: 0x30018 - 0x38000 = -0x7fe8 == 0x8018 == 32792
# dso: 0x20018 - 0x28000 = -0x7fe8 == 0x8018 == 32792
# DIS:  {{.*}}  lui $2, 32792
