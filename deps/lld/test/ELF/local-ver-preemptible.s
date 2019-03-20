# REQUIRES: x86
# RUN: echo '.global foo; .type foo, @function; foo:' | \
# RUN:   llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %t.so.o
# RUN: ld.lld %t.so.o -o %t.so -shared

# RUN: echo "{ global: main; local: *; };" > %t.script

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o %t.so -o %t -version-script %t.script
# RUN: llvm-readelf -r --symbols %t | FileCheck %s

# CHECK:      Relocation section '.rela.plt' at offset {{.*}} contains 1 entries:
# CHECK:        R_X86_64_JUMP_SLOT 0000000000201020 foo + 0

# CHECK:      Symbol table '.dynsym' contains 2 entries:
# CHECK-NEXT:   Num:    Value          Size Type    Bind   Vis      Ndx Name
# CHECK-NEXT:     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND
# CHECK-NEXT:     1: 0000000000201020     0 FUNC    GLOBAL DEFAULT  UND foo

.globl _start
_start:
  movl $foo - ., %eax
