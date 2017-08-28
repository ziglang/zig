# REQUIRES: x86
# RUN: echo "OUTPUT_FORMAT(x, y, z)" > %t.script
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-freebsd %s -o %t1
# RUN: ld.lld -shared -o %t2 %t1 %t.script
# RUN: llvm-readobj %t2 > /dev/null

# RUN: echo "OUTPUT_FORMAT(x, y)" > %t.script
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-freebsd %s -o %t1
# RUN: not ld.lld -shared -o %t2 %t1 %t.script
