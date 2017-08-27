# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
# RUN:   %S/Inputs/relocatable-tls.s -o %t2.o

# RUN: ld.lld -r %t2.o -o %t3.r
# RUN: llvm-objdump -t %t3.r | FileCheck --check-prefix=RELOCATABLE %s
# RELOCATABLE: SYMBOL TABLE:
# RELOCATABLE: 0000000000000000 *UND* 00000000 __tls_get_addr

# RUN: ld.lld -shared %t2.o %t3.r -o %t4.out
# RUN: llvm-objdump -t %t4.out | FileCheck --check-prefix=DSO %s
# DSO: SYMBOL TABLE:
# DSO: 0000000000000000 *UND* 00000000 __tls_get_addr

callq __tls_get_addr@PLT
