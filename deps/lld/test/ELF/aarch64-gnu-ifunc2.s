# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux-gnu %s -o %t.o
# RUN: ld.lld -static %t.o -o %tout
# RUN: llvm-objdump -D %tout | FileCheck %s
# RUN: llvm-readobj -r %tout | FileCheck %s --check-prefix=RELOC

# CHECK:      Disassembly of section .text:
# CHECK-NEXT: myfunc:
# CHECK-NEXT:   210000:

# CHECK:      main:
# adrp x8, 0x230000, 0x230000 == address in .got
# CHECK-NEXT:   210004: {{.*}} adrp    x8, #131072
# CHECK-NEXT:   210008: {{.*}} ldr     x8, [x8]
# CHECK-NEXT:   21000c: {{.*}} ret

# CHECK:      Disassembly of section .plt:
# CHECK-NEXT: .plt:
# adrp x16, 0x220000, 0x220000 == address in .got.plt
# CHECK-NEXT:   210010: {{.*}} adrp    x16, #65536
# CHECK-NEXT:   210014: {{.*}} ldr     x17, [x16]
# CHECK-NEXT:   210018: {{.*}} add     x16, x16, #0
# CHECK-NEXT:   21001c: {{.*}} br      x17

# CHECK:      Disassembly of section .got.plt:
# CHECK-NEXT: .got.plt:
# CHECK-NEXT:   220000:

# CHECK:      Disassembly of section .got:
# CHECK-NEXT: .got:
# 0x210010 == address in .plt
# CHECK-NEXT:   230000: 10 00 21 00

# RELOC:      Relocations [
# RELOC-NEXT:   Section {{.*}} .rela.plt {
# RELOC-NEXT:     0x220000 R_AARCH64_IRELATIVE - 0x210000
# RELOC-NEXT:   }
# RELOC-NEXT: ]

.text
.globl myfunc
.type myfunc,@gnu_indirect_function
myfunc:
 ret

.text
.globl main
.type main,@function
main:
 adrp x8, :got:myfunc
 ldr  x8, [x8, :got_lo12:myfunc]
 ret
