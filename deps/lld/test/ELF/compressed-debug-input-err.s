# REQUIRES: zlib, x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: not ld.lld %t.o -o %t.so -shared 2>&1 | FileCheck %s

## Check we are able to report zlib uncompress errors.
# CHECK: error: {{.*}}.o:(.debug_str): uncompress failed: zlib error: Z_DATA_ERROR

.section .zdebug_str,"MS",@progbits,1
 .ascii "ZLIB"
 .byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x1
