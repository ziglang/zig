# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux-gnu %s -o %t.o

# RUN: ld.lld %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s --check-prefix=PDE
# RUN: llvm-readobj -r %t | FileCheck %s --check-prefix=PDE-RELOC

# RUN: ld.lld -pie %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s --check-prefix=PIE
# RUN: llvm-readobj -r %t | FileCheck %s --check-prefix=PIE-RELOC

## When compiling with -fno-PIE or -fPIE, if the ifunc is in the same
## translation unit as the address taker, the compiler knows that ifunc is not
## defined in a shared library so it can use a non GOT generating relative reference.
.text
.globl myfunc
.type myfunc,@gnu_indirect_function
myfunc:
.globl myfunc_resolver
.type myfunc_resolver,@function
myfunc_resolver:
 ret

.text
.globl main
.type main,@function
main:
 adrp x8, myfunc
 add  x8, x8, :lo12: myfunc
 ret

## The address of myfunc is the address of the PLT entry for myfunc.
# PDE:      myfunc_resolver:
# PDE-NEXT:   210000:   ret
# PDE:      main:
# PDE-NEXT:   210004:   adrp    x8, #0
# PDE-NEXT:   210008:   add     x8, x8, #16
# PDE-NEXT:   21000c:   ret
# PDE-EMPTY:
# PDE-NEXT: Disassembly of section .plt:
# PDE-EMPTY:
# PDE-NEXT: myfunc:
## page(.got.plt) - page(0x210010) = 65536
# PDE-NEXT:   210010: adrp    x16, #65536
# PDE-NEXT:   210014: ldr     x17, [x16]
# PDE-NEXT:   210018: add     x16, x16, #0
# PDE-NEXT:   21001c: br      x17

## The adrp to myfunc should generate a PLT entry and a GOT entry with an
## irelative relocation.
# PDE-RELOC:      .rela.plt {
# PDE-RELOC-NEXT:   0x220000 R_AARCH64_IRELATIVE - 0x210000
# PDE-RELOC-NEXT: }

# PIE:      myfunc_resolver:
# PIE-NEXT:    10000: ret
# PIE:      main:
# PIE-NEXT:    10004: adrp    x8, #0
# PIE-NEXT:    10008: add     x8, x8, #16
# PIE-NEXT:    1000c: ret
# PIE-EMPTY:
# PIE-NEXT: Disassembly of section .plt:
# PIE-EMPTY:
# PIE-NEXT: myfunc:
# PIE-NEXT:    10010: adrp    x16, #131072
# PIE-NEXT:    10014: ldr     x17, [x16]
# PIE-NEXT:    10018: add     x16, x16, #0
# PIE-NEXT:    1001c: br      x17

# PIE-RELOC:      .rela.plt {
# PIE-RELOC-NEXT:   0x30000 R_AARCH64_IRELATIVE - 0x10000
# PIE-RELOC-NEXT: }
