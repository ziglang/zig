# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "zed" > %t.order
# RUN: echo "bar" >> %t.order
# RUN: echo "foo" >> %t.order
# RUN: ld.lld --icf=all --symbol-ordering-file %t.order -shared %t.o -o %t.so
# RUN: llvm-nm %t.so | FileCheck %s

## Check that after ICF merges 'foo' and 'zed' we still
## place them before 'bar', in according to ordering file.
# CHECK-DAG: 0000000000001000 T foo
# CHECK-DAG: 0000000000001000 T zed
# CHECK-DAG: 0000000000001004 T bar

.section .text.foo,"ax",@progbits
.align 4
.global foo
foo:
  retq

.section .text.bar,"ax",@progbits
.align 4
.global bar
bar:
  nop
  retq

.section .text.zed,"ax",@progbits
.align 4
.global zed
zed:
  retq
