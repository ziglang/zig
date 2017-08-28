# REQUIRES: x86
# RUN: echo "OUTPUT_ARCH(All data written here is ignored)" > %t.script
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-freebsd %s -o %t1
# RUN: ld.lld -shared -o %t2 %t1 %t.script
