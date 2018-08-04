# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t1.exe -Ttext=0x10000

# RUN: ld.lld -just-symbols=%t1.exe -o %t2.exe -cref | FileCheck %s

# CHECK:      Symbol      File
# CHECK-NEXT: bar         {{.*exe}}
# CHECK-NEXT: foo         {{.*exe}}

.globl foo, bar
foo:
  ret

.section .data
.type bar, @object
.size bar, 40
bar:
  .zero 40
