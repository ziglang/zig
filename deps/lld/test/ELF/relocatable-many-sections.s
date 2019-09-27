# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple x86_64-pc-linux-gnu %s -o %t.o
# RUN: ld.lld -r %t.o -o %t

## Check we are able to link against relocatable file produced.
# RUN: ld.lld %t -o %t.out

## Check we emit a valid ELF header when
## sections amount is greater than SHN_LORESERVE.
# RUN: llvm-readobj --file-headers %t | FileCheck %s --check-prefix=HDR
# HDR:      ElfHeader {
# HDR:        SectionHeaderCount: 0 (65544)
# HDR-NEXT:   StringTableSectionIndex: 65535 (65542)

## Check that:
## 1) 65541 is the index of .shstrtab section.
## 2) .symtab_shndx is linked with .symtab.
## 3) .symtab_shndx entry size and alignment == 4.
## 4) .symtab_shndx has size equal to
##    (sizeof(.symtab) / entsize(.symtab)) * entsize(.symtab_shndx) = 0x4 * 0x180078 / 0x18 == 0x040014

# RUN: llvm-readelf -sections -symbols %t | FileCheck %s
#        [Nr] Name              Type            Address          Off    Size   ES Flg Lk Inf Al
# CHECK: [65539] .note.GNU-stack PROGBITS       0000000000000000 000040 000000 00      0   0  1
# CHECK: [65540] .symtab        SYMTAB          0000000000000000 000040 180078 18     65543 65539  8
# CHECK: [65541] .symtab_shndx  SYMTAB SECTION INDICES 0000000000000000 1800b8 040014 04     65540   0  4
# CHECK: [65542] .shstrtab      STRTAB          0000000000000000 1c00cc 0f0044 00      0   0  1
# CHECK: [65543] .strtab        STRTAB          0000000000000000 2b0110 00000c 00      0   0  1

# 5) Check we are able to represent symbol foo with section (.bar) index  > 0xFF00 (SHN_LORESERVE).
# CHECK: GLOBAL DEFAULT  65538 foo

.macro gen_sections4 x
  .section a\x
  .section b\x
  .section c\x
  .section d\x
.endm

.macro gen_sections8 x
  gen_sections4 a\x
  gen_sections4 b\x
.endm

.macro gen_sections16 x
  gen_sections8 a\x
  gen_sections8 b\x
.endm

.macro gen_sections32 x
  gen_sections16 a\x
  gen_sections16 b\x
.endm

.macro gen_sections64 x
  gen_sections32 a\x
  gen_sections32 b\x
.endm

.macro gen_sections128 x
  gen_sections64 a\x
  gen_sections64 b\x
.endm

.macro gen_sections256 x
  gen_sections128 a\x
  gen_sections128 b\x
.endm

.macro gen_sections512 x
  gen_sections256 a\x
  gen_sections256 b\x
.endm

.macro gen_sections1024 x
  gen_sections512 a\x
  gen_sections512 b\x
.endm

.macro gen_sections2048 x
  gen_sections1024 a\x
  gen_sections1024 b\x
.endm

.macro gen_sections4096 x
  gen_sections2048 a\x
  gen_sections2048 b\x
.endm

.macro gen_sections8192 x
  gen_sections4096 a\x
  gen_sections4096 b\x
.endm

.macro gen_sections16384 x
  gen_sections8192 a\x
  gen_sections8192 b\x
.endm

gen_sections16384 a
gen_sections16384 b
gen_sections16384 c
gen_sections16384 d

.section .bar
.global foo
foo:

.section .text, "ax"
.global _start
_start:
