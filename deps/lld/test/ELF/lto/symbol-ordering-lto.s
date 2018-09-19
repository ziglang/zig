# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-scei-ps4 %s -o %t.o
# RUN: llvm-as %p/Inputs/symbol-ordering-lto.ll -o %t.bc

# Set up the symbol file
# RUN: echo "tin  " > %t_order_lto.txt
# RUN: echo "_start " >> %t_order_lto.txt
# RUN: echo "pat " >> %t_order_lto.txt

# RUN: ld.lld --symbol-ordering-file %t_order_lto.txt %t.o %t.bc -o %t2.out
# RUN: llvm-readelf -t %t2.out| FileCheck %s

# Check that the order is tin -> _start -> pat.

# CHECK: Symbol table '.symtab' contains 5 entries:
# CHECK-NEXT:   Num:    Value          Size Type    Bind   Vis      Ndx Name
# CHECK-NEXT:     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND
# CHECK-NEXT:     1: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS {{.*}}.o
# CHECK-NEXT:     2: 0000000000201008     0 NOTYPE  GLOBAL DEFAULT    1 _start
# CHECK-NEXT:     3: 0000000000201020     6 FUNC    GLOBAL DEFAULT    1 pat
# CHECK-NEXT:     4: 0000000000201000     6 FUNC    GLOBAL DEFAULT    1 tin

.globl _start
_start:
  call pat
  call tin
