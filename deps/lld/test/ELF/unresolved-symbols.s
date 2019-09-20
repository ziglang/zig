# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/unresolved-symbols.s -o %t2.o
# RUN: ld.lld -shared %t2.o -o %t.so

## Check that %t2.o contains undefined symbol undef.
# RUN: not ld.lld %t1.o %t2.o -o %t 2>&1 | \
# RUN:   FileCheck -check-prefix=UNDCHECK %s
# UNDCHECK: error: undefined symbol: undef
# UNDCHECK: >>> referenced by {{.*}}2.o:(.text+0x1)

## Error out if unknown option value was set.
# RUN: not ld.lld %t1.o %t2.o -o %t --unresolved-symbols=xxx 2>&1 | \
# RUN:   FileCheck -check-prefix=ERR1 %s
# ERR1: unknown --unresolved-symbols value: xxx
## Check alias.
# RUN: not ld.lld %t1.o %t2.o -o %t --unresolved-symbols xxx 2>&1 | \
# RUN:   FileCheck -check-prefix=ERR1 %s

## Ignore all should not produce error for symbols from object except
## case when --no-undefined specified.
# RUN: ld.lld %t2.o -o %t1_1 --unresolved-symbols=ignore-all
# RUN: llvm-readobj %t1_1 > /dev/null 2>&1
# RUN: not ld.lld %t2.o -o /dev/null --unresolved-symbols=ignore-all --no-undefined 2>&1 | \
# RUN:   FileCheck -check-prefix=ERRUND %s
# ERRUND: error: undefined symbol: undef
# ERRUND: >>> referenced by {{.*}}:(.text+0x1)

## Also ignore all should not produce error for symbols from DSOs.
# RUN: ld.lld %t1.o %t.so -o %t1_3 --allow-shlib-undefined --unresolved-symbols=ignore-all
# RUN: llvm-readobj %t1_3 > /dev/null 2>&1

## Ignoring undefines in objects should not produce error for symbol from object.
# RUN: ld.lld %t1.o %t2.o -o %t2 --unresolved-symbols=ignore-in-object-files
# RUN: llvm-readobj %t2 > /dev/null 2>&1
## And still should not should produce for undefines from DSOs.
# RUN: ld.lld %t1.o %t.so -o /dev/null --allow-shlib-undefined --unresolved-symbols=ignore-in-object-files
# RUN: llvm-readobj %t2 > /dev/null 2>&1

## Ignoring undefines in shared should produce error for symbol from object.
# RUN: not ld.lld %t2.o -o /dev/null --unresolved-symbols=ignore-in-shared-libs 2>&1 | \
# RUN:   FileCheck -check-prefix=ERRUND %s
## And should not produce errors for symbols from DSO.
# RUN: ld.lld %t1.o %t.so -o %t3_1 --allow-shlib-undefined --unresolved-symbols=ignore-in-shared-libs
# RUN: llvm-readobj %t3_1 > /dev/null 2>&1

## Ignoring undefines in shared libs should not produce error for symbol from object
## if we are linking DSO.
# RUN: ld.lld -shared %t1.o -o %t4 --unresolved-symbols=ignore-in-shared-libs
# RUN: llvm-readobj %t4 > /dev/null 2>&1

## Do not report undefines if linking relocatable.
# RUN: ld.lld -r %t1.o %t2.o -o %t5 --unresolved-symbols=report-all
# RUN: llvm-readobj %t5 > /dev/null 2>&1

## report-all is the default one. Check that we do not report
## undefines from DSO and do report undefines from object. With
## report-all specified and without.
# RUN: ld.lld -shared %t1.o %t.so -o %t6 --unresolved-symbols=report-all
# RUN: llvm-readobj %t6 > /dev/null 2>&1
# RUN: ld.lld -shared %t1.o %t.so -o %t6_1
# RUN: llvm-readobj %t6_1 > /dev/null 2>&1
# RUN: not ld.lld %t2.o -o /dev/null --unresolved-symbols=report-all 2>&1 | \
# RUN:   FileCheck -check-prefix=ERRUND %s
# RUN: not ld.lld %t2.o -o /dev/null 2>&1 | FileCheck -check-prefix=ERRUND %s

.globl _start
_start:
