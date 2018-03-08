# REQUIRES: x86

# RUN: echo ".global foo; .type foo, @object; .size foo, 4; foo:; .long 0" > %t.s
# RUN: echo ".global bar; .type bar, @object; .size bar, 4; bar:; .long 0" >> %t.s
# RUN: echo ".global zed; .type zed, @function; zed:" >> %t.s
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %t.s -o %t1.o
# RUN: ld.lld %t1.o -o %t1.so -shared

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t2.o
# RUN: ld.lld --hash-style=gnu %t2.o %t1.so -o %t2

# RUN: llvm-readelf --symbols --gnu-hash-table %t2 | FileCheck %s

# CHECK:      Symbol table '.dynsym' contains 4 entries:
# CHECK-NEXT:    Num:    Value          Size Type    Bind   Vis      Ndx   Name
# CHECK-NEXT:      0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND   @
# CHECK-NEXT:      1: 0000000000000000     0 OBJECT  GLOBAL DEFAULT  UND   foo@
# CHECK-DAG:        : {{.*}}               4 OBJECT  GLOBAL DEFAULT {{.*}} bar@
# CHECK-DAG:        : {{.*}}               0 FUNC    GLOBAL DEFAULT  UND   zed@

# CHECK: First Hashed Symbol Index: 2

.global _start
_start:

.quad bar
.quad zed

.data
.quad foo
