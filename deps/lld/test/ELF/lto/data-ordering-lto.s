# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-scei-ps4 %s -o %t.o
# RUN: llvm-as %p/Inputs/data-ordering-lto.ll -o %t.bc

# Set up the symbol file
# RUN: echo "tin  " > %t_order_lto.txt
# RUN: echo "dipsy " >> %t_order_lto.txt
# RUN: echo "pat " >> %t_order_lto.txt

# RUN: ld.lld --symbol-ordering-file %t_order_lto.txt %t.o %t.bc -o %t2.out
# RUN: llvm-readelf --symbols %t2.out| FileCheck %s

# Check that the order is tin -> dipsy -> pat.

# CHECK: Symbol table '.symtab' contains 6 entries:
# CHECK-NEXT:    Num:    Value          Size Type    Bind   Vis      Ndx Name
# CHECK-NEXT:      0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND
# CHECK-NEXT:      1: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS {{.*}}.o
# CHECK-NEXT:      2: 0000000000201000     0 NOTYPE  GLOBAL DEFAULT    1 _start
# CHECK-NEXT:      3: 0000000000202004     4 OBJECT  GLOBAL DEFAULT    2 dipsy
# CHECK-NEXT:      4: 0000000000202008     4 OBJECT  GLOBAL DEFAULT    2 pat
# CHECK-NEXT:      5: 0000000000202000     4 OBJECT  GLOBAL DEFAULT    2 tin

.globl _start
_start:
  movl $pat, %ecx
  movl $dipsy, %ebx
  movl $tin, %eax
