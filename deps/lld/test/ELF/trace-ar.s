# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.foo.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/trace-ar1.s -o %t.obj1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/trace-ar2.s -o %t.obj2.o
# RUN: rm -f %t.boo.a
# RUN: llvm-ar rcs %t.boo.a %t.obj1.o %t.obj2.o

## Check how -t works with achieves
# RUN: ld.lld %t.foo.o %t.boo.a -o %t.out -t 2>&1 | FileCheck %s
# CHECK:      {{.*}}.foo.o
# CHECK-NEXT: {{.*}}.boo.a({{.*}}.obj1.o)
# CHECK-NOT:  {{.*}}.boo.a({{.*}}.obj2.o)

## Test output with --start-lib
# RUN: ld.lld %t.foo.o --start-lib %t.obj1.o %t.obj2.o -o %t.out -t 2>&1 | FileCheck --check-prefix=STARTLIB %s
# STARTLIB:      {{.*}}.foo.o
# STARTLIB-NEXT: {{.*}}.obj1.o
# STARTLIB-NOT:  {{.*}}.obj2.o

.globl _start, _used
_start:
 call _used
