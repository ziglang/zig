# REQUIRES: mips
# Check MIPS R_MIPS_TLS_DTPREL_HI16/LO16 and R_MIPS_TLS_TPREL_HI16/LO16
# relocations handling.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t.exe
# RUN: llvm-objdump -d -t %t.exe | FileCheck -check-prefix=DIS %s
# RUN: llvm-readobj -r -mips-plt-got %t.exe | FileCheck %s

# RUN: ld.lld %t.o -shared -o %t.so
# RUN: llvm-readobj -r -mips-plt-got %t.so | FileCheck -check-prefix=SO %s

# DIS:      __start:
# DIS-NEXT:    20000:   24 62 00 00   addiu   $2, $3, 0
#                       %hi(loc0 - .tdata - 0x8000) --^
# DIS-NEXT:    20004:   24 62 80 00   addiu   $2, $3, -32768
#                       %lo(loc0 - .tdata - 0x8000) --^
# DIS-NEXT:    20008:   24 62 00 00   addiu   $2, $3, 0
#                       %hi(loc0 - .tdata - 0x7000) --^
# DIS-NEXT:    2000c:   24 62 90 00   addiu   $2, $3, -28672
#                       %lo(loc0 - .tdata - 0x7000) --^

# DIS: 00000000 l       .tdata          00000000 loc0

# CHECK:      Relocations [
# CHECK-NEXT: ]
# CHECK-NOT:  Primary GOT

# SO:      Relocations [
# SO-NEXT: ]
# SO:      Primary GOT {
# SO:        Local entries [
# SO-NEXT:   ]
# SO-NEXT:   Global entries [
# SO-NEXT:   ]
# SO-NEXT:   Number of TLS and multi-GOT entries: 0
# SO-NEXT: }

  .text
  .globl  __start
  .type __start,@function
__start:
  addiu $2, $3, %dtprel_hi(loc0)  # R_MIPS_TLS_DTPREL_HI16
  addiu $2, $3, %dtprel_lo(loc0)  # R_MIPS_TLS_DTPREL_LO16
  addiu $2, $3, %tprel_hi(loc0)   # R_MIPS_TLS_TPREL_HI16
  addiu $2, $3, %tprel_lo(loc0)   # R_MIPS_TLS_TPREL_LO16

 .section .tdata,"awT",%progbits
loc0:
 .word 0
