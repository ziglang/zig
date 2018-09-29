# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-objdump -t -section-headers %t | FileCheck %s

## This checks that:
## 1) Address of _etext is the first location after the last read-only loadable segment.
## 2) Address of _edata points to the end of the last non SHT_NOBITS section.
##    That is how gold/bfd do. At the same time specs says: "If the address of _edata is
##    greater than the address of _etext, the address of _end is same as the address
##    of _edata." (https://docs.oracle.com/cd/E53394_01/html/E54766/u-etext-3c.html).
## 3) Address of _end is different from _edata because of 2.
## 4) Addresses of _edata == edata, _end == end and _etext == etext.
# CHECK:      Sections:
# CHECK-NEXT:  Idx Name          Size      Address          Type
# CHECK-NEXT:    0               00000000 0000000000000000
# CHECK-NEXT:    1 .text         00000001 0000000000201000 TEXT
# CHECK-NEXT:    2 .data         00000002 0000000000202000 DATA
# CHECK-NEXT:    3 .bss          00000006 0000000000202004 BSS
# CHECK:      SYMBOL TABLE:
# CHECK-NEXT:  0000000000000000         *UND* 00000000
# CHECK-NEXT:  0000000000202002         .data 00000000 _edata
# CHECK-NEXT:  000000000020200a         .bss  00000000 _end
# CHECK-NEXT:  0000000000201001         .text 00000000 _etext
# CHECK-NEXT:  0000000000201000         .text 00000000 _start
# CHECK-NEXT:  0000000000202002         .data 00000000 edata
# CHECK-NEXT:  000000000020200a         .bss  00000000 end
# CHECK-NEXT:  0000000000201001         .text 00000000 etext

# RUN: ld.lld -r %t.o -o %t2
# RUN: llvm-objdump -t %t2 | FileCheck %s --check-prefix=RELOCATABLE
# RELOCATABLE:       0000000000000000 *UND* 00000000 _edata
# RELOCATABLE-NEXT:  0000000000000000 *UND* 00000000 _end
# RELOCATABLE-NEXT:  0000000000000000 *UND* 00000000 _etext

.global _start,_end,_etext,_edata,end,etext,edata
.text
_start:
  nop
.data
  .word 1
.bss
  .align 4
  .space 6
