# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux-gnu %s -o %t.o
# RUN: ld.lld -static %t.o -o %tout
# RUN: llvm-objdump -D %tout | FileCheck %s
# RUN: llvm-readobj -r %tout | FileCheck %s --check-prefix=RELOC

# The address of myfunc is the address of the PLT entry for myfunc.
# The adrp to myfunc should generate a PLT entry and a got entry with an
# irelative relocation.
.text
.globl myfunc
.type myfunc,@gnu_indirect_function
myfunc:
 ret

.text
.globl _start
.type _start,@function
_start:
 adrp x8, myfunc
 add  x8, x8, :lo12:myfunc
 ret

# CHECK: Disassembly of section .text:
# CHECK-NEXT: myfunc:
# CHECK-NEXT:   210000:	c0 03 5f d6 	ret
# CHECK: _start:
# adrp x8, 0x210000 + 0x10 from add == .plt entry
# CHECK-NEXT:   210004:	08 00 00 90 	adrp	x8, #0
# CHECK-NEXT:   210008:	08 41 00 91 	add	x8, x8, #16
# CHECK-NEXT:   21000c:	c0 03 5f d6 	ret
# CHECK-NEXT: Disassembly of section .plt:
# CHECK-NEXT: .plt:
# adrp x16, 0x220000, 0x220000 == address in .got.plt
# CHECK-NEXT:   210010:	90 00 00 90 	adrp	x16, #65536
# CHECK-NEXT:   210014:	11 02 40 f9 	ldr	x17, [x16]
# CHECK-NEXT:   210018:	10 02 00 91 	add	x16, x16, #0
# CHECK-NEXT:   21001c:	20 02 1f d6 	br	x17
# CHECK-NEXT: Disassembly of section .got.plt:
# CHECK-NEXT: .got.plt:
# 0x210010 == address in .plt
# CHECK-NEXT:   220000:	10 00 21 00
# CHECK-NEXT:   220004:	00 00 00 00

# RELOC: Relocations [
# RELOC-NEXT:  Section (1) .rela.plt {
# RELOC-NEXT:    0x220000 R_AARCH64_IRELATIVE - 0x210000
# RELOC-NEXT:  }
# RELOC-NEXT: ]
