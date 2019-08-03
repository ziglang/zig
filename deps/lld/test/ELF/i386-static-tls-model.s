# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %S/Inputs/i386-static-tls-model1.s -o %t.o
# RUN: ld.lld %t.o -o %t1 -shared
# RUN: llvm-readobj --dynamic-table %t1 | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %S/Inputs/i386-static-tls-model2.s -o %t.o
# RUN: ld.lld %t.o -o %t2 -shared
# RUN: llvm-readobj --dynamic-table %t2 | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %S/Inputs/i386-static-tls-model3.s -o %t.o
# RUN: ld.lld %t.o -o %t3 -shared
# RUN: llvm-readobj --dynamic-table %t3 | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %S/Inputs/i386-static-tls-model4.s -o %t.o
# RUN: ld.lld %t.o -o %t4 -shared
# RUN: llvm-readobj --dynamic-table %t4 | FileCheck %s

# CHECK: DynamicSection [
# CHECK: FLAGS STATIC_TLS
