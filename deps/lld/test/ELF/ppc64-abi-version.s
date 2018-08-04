# REQUIRES: ppc

# RUN: echo '.abiversion 1' | llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux - -o %t1.o
# RUN: not ld.lld -o /dev/null %t1.o 2>&1 | FileCheck -check-prefix=ERR1 %s

# ERR1: ABI version 1 is not supported

# RUN: echo '.abiversion 3' | llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux - -o %t1.o
# RUN: not ld.lld -o /dev/null %t1.o 2>&1 | FileCheck -check-prefix=ERR2 %s

# ERR2: unrecognized e_flags: 3
