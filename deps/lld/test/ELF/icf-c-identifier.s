# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o /dev/null --icf=all --print-icf-sections | count 0

.section foo,"ax",@progbits,unique,0
.byte 42

.section foo,"ax",@progbits,unique,1
.byte 42
