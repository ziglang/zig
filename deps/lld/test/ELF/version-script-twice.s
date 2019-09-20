# REQUIRES: x86

# RUN: echo "FBSD_1.1 {}; FBSD_1.2 {};" > %t.ver
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld -shared %t.o -o %t.so --version-script=%t.ver
# RUN: llvm-readelf --dyn-symbols %t.so | FileCheck %s

        .weak	openat
openat:

        .global openat@FBSD_1.1
openat@FBSD_1.1 = openat

         .global openat@@FBSD_1.2
openat@@FBSD_1.2 = openat

# CHECK-DAG: openat@FBSD_1.1
# CHECK-DAG: openat@@FBSD_1.2
