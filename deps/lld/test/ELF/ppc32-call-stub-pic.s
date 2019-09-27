# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc %s -o %t.o
# RUN: echo '.globl f, g, h; f: g: h:' | llvm-mc -filetype=obj -triple=powerpc - -o %t1.o
# RUN: ld.lld -shared %t1.o -soname t1.so -o %t1.so
# RUN: echo 'bl f+0x8000@plt' | llvm-mc -filetype=obj -triple=powerpc - -o %t2.o

## Check we can create PLT entries for -fPIE or -fpie executable.
# RUN: ld.lld -pie %t.o %t1.so %t2.o -o %t
# RUN: llvm-readobj -r %t | FileCheck --check-prefix=RELOC %s
# RUN: llvm-readobj -d %t | FileCheck --check-prefix=DYN %s
# RUN: llvm-readelf -S %t | FileCheck --check-prefix=SEC %s
# RUN: llvm-readelf -x .plt %t | FileCheck --check-prefix=HEX %s
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefixes=CHECK,PIE %s

## Check we can create PLT entries for -fPIC or -fpic DSO.
# RUN: ld.lld -shared %t.o %t1.so %t2.o -o %t
# RUN: llvm-readobj -r %t | FileCheck --check-prefix=RELOC %s
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefixes=CHECK,SHARED %s

# RELOC:      .rela.dyn {
# RELOC-NEXT:   R_PPC_ADDR32 f 0x0
# RELOC-NEXT:   R_PPC_ADDR32 g 0x0
# RELOC-NEXT:   R_PPC_ADDR32 h 0x0
# RELOC-NEXT: }
# RELOC-NEXT: .rela.plt {
# RELOC-NEXT:   R_PPC_JMP_SLOT f 0x0
# RELOC-NEXT:   R_PPC_JMP_SLOT g 0x0
# RELOC-NEXT:   R_PPC_JMP_SLOT h 0x0
# RELOC-NEXT: }

# SEC: .got PROGBITS 00020088
# DYN: PPC_GOT 0x20088

## .got2+0x8000-0x10004 = 0x30000+0x8000-0x10004 = 65536*2+32764
# CHECK-LABEL: _start:
# CHECK-NEXT:    bcl 20, 31, .+4
# CHECK-NEXT:  10004: mflr 30
# CHECK-NEXT:    addis 30, 30, 2
# CHECK-NEXT:    addi 30, 30, 32764

## Two bl 00008000.got2.plt_pic32.f
# CHECK-NEXT:    bl .+40
# CHECK-NEXT:    bl .+36
## Two bl 00008000.got2.plt_pic32.g
# CHECK-NEXT:    bl .+48
# CHECK-NEXT:    bl .+44
## Two bl 00008000.got2.plt_pic32.h
# CHECK-NEXT:    bl .+56
# CHECK-NEXT:    bl .+52
# CHECK-NEXT:    addis 30, 30, {{.*}}
# CHECK-NEXT:    addi 30, 30, {{.*}}
## bl 00008000.plt_pic32.f
# CHECK-NEXT:    bl .+56
## bl 00008000.plt_pic32.f
# CHECK-NEXT:    bl .+68
# CHECK-EMPTY:

## -fPIC call stubs of f and g.
# CHECK-NEXT:  00008000.got2.plt_pic32.f:
# CHECK-NEXT:    lwz 11, 32760(30)
# CHECK-NEXT:    mtctr 11
# CHECK-NEXT:    bctr
# CHECK-NEXT:    nop
# CHECK-EMPTY:
# CHECK-NEXT:  00008000.got2.plt_pic32.g:
# CHECK-NEXT:    lwz 11, 32764(30)
# CHECK-NEXT:    mtctr 11
# CHECK-NEXT:    bctr
# CHECK-NEXT:    nop
# CHECK-EMPTY:

## The -fPIC call stub of h needs two instructions addis+lwz to represent the offset 65536*1-32768.
# CHECK-NEXT:  00008000.got2.plt_pic32.h:
# CHECK-NEXT:    addis 11, 30, 1
# CHECK-NEXT:    lwz 11, -32768(11)
# CHECK-NEXT:    mtctr 11
# CHECK-NEXT:    bctr
# CHECK-EMPTY:

## -fpic call stub of f.
# CHECK-NEXT:  00000000.plt_pic32.f:
# CHECK-NEXT:    addis 11, 30, 2
# PIE-NEXT:      lwz 11, -144(11)
# SHARED-NEXT:   lwz 11, -136(11)
# CHECK-NEXT:    mtctr 11
# CHECK-NEXT:    bctr
# CHECK-EMPTY:

## Another -fPIC call stub of f from another object file %t2.o
## .got2 may have different addresses in different object files,
## so the call stub cannot be shared.
# CHECK-NEXT:  00008000.got2.plt_pic32.f:

## In Secure PLT ABI, .plt stores function pointers to first instructions of .glink
# HEX: 0x0003fff8 00010090 00010094 00010098

## These instructions are referenced by .plt entries.
# CHECK: 00010090 .glink:
# CHECK-NEXT: b .+12
# CHECK-NEXT: b .+8
# CHECK-NEXT: b .+4

## PLTresolve
## Operand of addi: 0x100a8-.glink = 24
# CHECK-NEXT: addis 11, 11, 0
# CHECK-NEXT: mflr 0
# CHECK-NEXT: bcl 20, 31, .+4
# CHECK-NEXT: 100a8: addi 11, 11, 24

# CHECK-NEXT: mflr 12
# CHECK-NEXT: mtlr 0
# CHECK-NEXT: subf 11, 12, 11

## Operand of lwz in -pie mode: &.got[1] - 0x100a8 = 0x20088+4 - 0x100a8 = 65536*1-28
# CHECK-NEXT: addis 12, 12, 1
# PIE-NEXT:   lwz 0, -28(12)
# SHARED-NEXT: lwz 0, -36(12)

# PIE-NEXT:   lwz 12, -24(12)
# SHARED-NEXT: lwz 12, -32(12)
# CHECK-NEXT: mtctr 0
# CHECK-NEXT: add 0, 11, 11
# CHECK-NEXT: add 11, 0, 11
# CHECK-NEXT: bctr

.section .got2,"aw"
.space 65516
.long f
.long g
.long h

.text
.globl _start
_start:
  bcl 20,31,.L
.L:
  mflr 30
  addis 30, 30, .got2+0x8000-.L@ha
  addi 30, 30, .got2+0x8000-.L@l
  bl f+0x8000@plt
  bl f+0x8000@plt
  bl g+0x8000@plt
  bl g+0x8000@plt
  bl h+0x8000@plt
  bl h+0x8000@plt

## An addend of 0 indicates r30 is stored in _GLOBAL_OFFSET_TABLE_.
## The existing thunk is incompatible, thus it cannot be reused.
  addis 30, 30, _GLOBAL_OFFSET_TABLE_-.L@ha
  addi 30, 30, _GLOBAL_OFFSET_TABLE_-.L@l
  bl f@plt
