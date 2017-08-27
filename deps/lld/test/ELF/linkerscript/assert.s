# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o

# RUN: echo "SECTIONS { ASSERT(1, fail) }" > %t1.script
# RUN: ld.lld -shared -o %t1 --script %t1.script %t1.o
# RUN: llvm-readobj %t1 > /dev/null

# RUN: echo "SECTIONS { ASSERT(0, fail) }" > %t3.script
# RUN: not ld.lld -shared -o %t3 --script %t3.script %t1.o > %t.log 2>&1
# RUN: FileCheck %s -check-prefix=FAIL < %t.log
# FAIL: fail

# RUN: echo "SECTIONS { . = ASSERT(0x1000, fail); }" > %t4.script
# RUN: ld.lld -shared -o %t4 --script %t4.script %t1.o
# RUN: llvm-readobj %t4 > /dev/null

# RUN: echo "SECTIONS { .foo : { *(.foo) } }" > %t5.script
# RUN: echo "ASSERT(SIZEOF(.foo) == 8, fail);" >> %t5.script
# RUN: ld.lld -shared -o %t5 --script %t5.script %t1.o
# RUN: llvm-readobj %t5 > /dev/null

## Even without SECTIONS block we still use section names
## in expressions
# RUN: echo "ASSERT(SIZEOF(.foo) == 8, fail);" > %t5.script
# RUN: ld.lld -shared -o %t5 --script %t5.script %t1.o
# RUN: llvm-readobj %t5 > /dev/null

## Test assertions inside of output section decriptions.
# RUN: echo "SECTIONS { .foo : { *(.foo) ASSERT(SIZEOF(.foo) == 8, \"true\"); } }" > %t6.script
# RUN: ld.lld -shared -o %t6 --script %t6.script %t1.o
# RUN: llvm-readobj %t6 > /dev/null

# RUN: echo "SECTIONS { .foo : { ASSERT(1, \"true\") } }" > %t7.script
# RUN: not ld.lld -shared -o %t7 --script %t7.script %t1.o > %t.log 2>&1
# RUN: FileCheck %s -check-prefix=CHECK-SEMI < %t.log
# CHECK-SEMI: error: {{.*}}.script:1: ; expected, but got }

.section .foo, "a"
 .quad 0
