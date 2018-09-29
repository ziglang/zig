# REQUIRES: x86

# RUN: echo '.globl foo; .type foo, @function; foo:' | \
# RUN:   llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %t1.o
# RUN: ld.lld -shared -o %t1.so -soname libfoo %t1.o

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t2.o
# RUN: ld.lld -o %t.exe %t2.o --as-needed %t1.so
# RUN: llvm-readelf -dynamic-table -dyn-symbols %t.exe | FileCheck %s

# CHECK-NOT: libfoo

# CHECK:      Symbol table of .hash for image:
# CHECK-NEXT: Num Buc:    Value          Size   Type   Bind Vis      Ndx Name
# CHECK-NEXT:   1   1: 0000000000000000     0 FUNC    WEAK   DEFAULT UND foo@

.globl _start
.weak foo

_start:
  mov $foo, %eax
  callq foo
