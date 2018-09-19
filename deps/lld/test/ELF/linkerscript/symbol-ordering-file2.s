# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

## Check we do not crash when trying to order linker script symbol.

# RUN: echo "bar" > %t.ord
# RUN: echo "SECTIONS { bar = 1; }" > %t.script
# RUN: ld.lld --symbol-ordering-file %t.ord %t.o --script %t.script \
# RUN:   -o %t.out 2>&1 | FileCheck %s
# CHECK: warning: <internal>: unable to order absolute symbol: bar

## Check we do not crash when trying to order --defsym symbol.

# RUN: echo "bar" > %t.ord
# RUN: ld.lld --symbol-ordering-file %t.ord %t.o -defsym=bar=1 \
# RUN:   -o %t.out 2>&1 | FileCheck %s
