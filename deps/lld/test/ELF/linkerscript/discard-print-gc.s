# REQUIRES: x86

# RUN: llvm-mc -triple x86_64-pc-linux %s -o %t.o -filetype=obj
# RUN: ld.lld -o %t.so --gc-sections %t.o --print-gc-sections -shared 2>&1 | \
# RUN:   FileCheck -check-prefix=CHECK %s

# RUN: echo "SECTIONS { /DISCARD/ : { *(.foo) } }" > %t.script
# RUN: ld.lld -o %t.so -T %t.script %t.o --print-gc-sections -shared 2>&1 | \
# RUN:   FileCheck -check-prefix=QUIET --allow-empty %s

# RUN: echo "SECTIONS { .foo : { *(.foo) } }" > %t2.script
# RUN: ld.lld -o %t.so -T %t2.script --gc-sections %t.o --print-gc-sections -shared 2>&1 | \
# RUN:   FileCheck -check-prefix=CHECK %s

.section .foo,"a"
.quad 0

# CHECK: removing unused section from '.foo'
# QUIET-NOT: removing unused section from '.foo'
