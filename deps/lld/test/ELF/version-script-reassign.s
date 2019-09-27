# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o
# RUN: echo '{ local: foo; };' > %tl.ver
# RUN: echo '{ global: foo; local: *; };' > %tg.ver
# RUN: echo 'V1 { global: foo; };' > %t1.ver
# RUN: echo 'V2 { global: foo; };' > %t2.ver
# RUN: echo 'V2 { global: notexist; local: f*; };' > %t2w.ver

## Note, ld.bfd errors on the two cases.
# RUN: ld.lld -shared %t.o --version-script %tl.ver --version-script %t1.ver \
# RUN:   -o %t.so 2>&1 | FileCheck --check-prefix=LOCAL %s
# RUN: llvm-readelf --dyn-syms %t.so | FileCheck --check-prefix=LOCAL-SYM %s
# RUN: ld.lld -shared %t.o --version-script %tg.ver --version-script %t1.ver \
# RUN:   -o %t.so 2>&1 | FileCheck --check-prefix=GLOBAL %s
# RUN: llvm-readelf --dyn-syms %t.so | FileCheck --check-prefix=GLOBAL-SYM %s

## Note, ld.bfd silently accepts this case.
# RUN: ld.lld -shared %t.o --version-script %t1.ver --version-script %t2.ver \
# RUN:   -o %t.so 2>&1 | FileCheck --check-prefix=V1-WARN %s
# RUN: llvm-readelf --dyn-syms %t.so | FileCheck --check-prefix=V1-SYM %s

# RUN: ld.lld -shared %t.o --version-script %t1.ver --version-script %t2w.ver \
# RUN:   -o %t.so --fatal-warnings
# RUN: llvm-readelf --dyn-syms %t.so | FileCheck --check-prefix=V1-SYM %s

# LOCAL: warning: attempt to reassign symbol 'foo' of VER_NDX_LOCAL to version 'V1'
# LOCAL-SYM-NOT: foo

# GLOBAL: warning: attempt to reassign symbol 'foo' of VER_NDX_GLOBAL to version 'V1'
# GLOBAL-SYM: foo{{$}}

# V1-WARN: warning: attempt to reassign symbol 'foo' of version 'V1' to version 'V2'
# V1-SYM: foo@@V1

.globl foo
foo:
