# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t1.exe -Ttext=0x10000

# RUN: ld.lld -just-symbols=%t1.exe -o %t2.exe
# RUN: llvm-readelf -symbols %t2.exe | FileCheck %s

# CHECK: 0000000000011000    40 OBJECT  GLOBAL DEFAULT  ABS bar
# CHECK: 0000000000010000     0 NOTYPE  GLOBAL DEFAULT  ABS foo

.globl foo, bar
foo:
  ret

.section .data
.type bar, @object
.size bar, 40
bar:
  .zero 40
