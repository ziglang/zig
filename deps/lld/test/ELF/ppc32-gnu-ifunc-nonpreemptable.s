# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-readobj -r %t | FileCheck --check-prefix=RELOC %s
# RUN: llvm-readelf -s %t | FileCheck --check-prefix=SYM %s
# RUN: llvm-readelf -x .got2 %t | FileCheck --check-prefix=HEX %s
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s

# RELOC:      .rela.plt {
# RELOC-NEXT:   0x10020004 R_PPC_IRELATIVE - 0x10010000
# RELOC-NEXT: }

# SYM: 10010020 0 FUNC GLOBAL DEFAULT {{.*}} func
# HEX: 0x10020000 10010020

.section .got2,"aw"
.long func

# CHECK:      func_resolver:
# CHECK-NEXT: 10010000: blr
# CHECK:      _start:
# CHECK-NEXT:   bl .+12
# CHECK-NEXT:   lis 9, 4097
# CHECK-NEXT:   addi 9, 9, 32
# CHECK-EMPTY:
# CHECK-NEXT: 00000000.plt_call32.func:
## 10020004 = 65536*4098+4
# CHECK-NEXT:   lis 11, 4098
# CHECK-NEXT:   lwz 11, 4(11)

.text
.globl func
.type func, @gnu_indirect_function
func:
.globl func_resolver
.type func_resolver, @function
func_resolver:
  blr

.globl _start
_start:
  bl func

  lis 9, func@ha
  la 9, func@l(9)
