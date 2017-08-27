# REQUIRES: mips
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -shared -o %t.so
# RUN: ld.lld %t.so -shared -o %t2.so
# RUN: llvm-readobj %t2.so > /dev/null 2>&1
