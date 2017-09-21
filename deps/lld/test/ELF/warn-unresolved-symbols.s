# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o

## The link should fail with an undef error by default
# RUN: not ld.lld %t1.o -o %t3 2>&1 | \
# RUN: FileCheck -check-prefix=ERRUND %s

## --error-unresolved-symbols should generate an error
# RUN: not ld.lld %t1.o -o %t4 --error-unresolved-symbols 2>&1 | \
# RUN: FileCheck -check-prefix=ERRUND %s

## --warn-unresolved-symbols should generate a warning
# RUN: ld.lld %t1.o -o %t5 --warn-unresolved-symbols 2>&1 | \
# RUN: FileCheck -check-prefix=WARNUND %s

## Test that the last option wins
# RUN: ld.lld %t1.o -o %t5 --error-unresolved-symbols --warn-unresolved-symbols 2>&1 | \
# RUN:  FileCheck -check-prefix=WARNUND %s
# RUN: not ld.lld %t1.o -o %t6 --warn-unresolved-symbols --error-unresolved-symbols 2>&1 | \
# RUN:  FileCheck -check-prefix=ERRUND %s

## Do not report undefines if linking relocatable or shared.
## And while we're at it, check that we can accept single -
## variants of these options.
# RUN: ld.lld -r %t1.o -o %t7 -error-unresolved-symbols 2>&1 | \
# RUN:  FileCheck -allow-empty -check-prefix=NOERR %s
# RUN: ld.lld -shared %t1.o -o %t8.so --error-unresolved-symbols 2>&1 | \
# RUN:  FileCheck -allow-empty -check-prefix=NOERR %s
# RUN: ld.lld -r %t1.o -o %t9 -warn-unresolved-symbols 2>&1 | \
# RUN:  FileCheck -allow-empty -check-prefix=NOWARN %s
# RUN: ld.lld -shared %t1.o -o %t10.so --warn-unresolved-symbols 2>&1 | \
# RUN:  FileCheck -allow-empty -check-prefix=NOWARN %s

# ERRUND: error: undefined symbol: undef
# ERRUND: >>> referenced by {{.*}}:(.text+0x1)

# WARNUND: warning: undefined symbol: undef
# WARNUND: >>> referenced by {{.*}}:(.text+0x1)

# NOERR-NOT: error: undefined symbol: undef
# NOERR-NOT: >>> referenced by {{.*}}:(.text+0x1)

# NOWARN-NOT: warning: undefined symbol: undef
# NOWARN-NOT: >>> referenced by {{.*}}:(.text+0x1)

.globl _start
_start:

.globl _shared
_shared:
 callq undef@PLT
