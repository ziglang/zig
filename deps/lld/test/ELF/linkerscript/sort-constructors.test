# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux /dev/null -o %t1.o
# RUN: ld.lld -shared -o %t1 --script %s %t1.o
# RUN: llvm-readobj %t1 > /dev/null

SECTIONS {
 .aaa : { SORT(CONSTRUCTORS) } 
}
