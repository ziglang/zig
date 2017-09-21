# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: echo "SECTIONS { \
# RUN:  . = SIZEOF_HEADERS; \
# RUN:  abc : { foo = .; } \
# RUN:  . = ALIGN(0x1000); \
# RUN:  bar : { *(bar) } \
# RUN: }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t -shared
# RUN: llvm-objdump -section-headers -t %t1 | FileCheck %s
# CHECK:      Sections:
# CHECK-NEXT: Idx Name          Size      Address
# CHECK-NEXT:   0               00000000 0000000000000000
# CHECK:          abc           00000000 [[ADDR:[0-9a-f]*]] DATA
# CHECK-NEXT:     bar           00000000 0000000000001000 DATA

# CHECK: SYMBOL TABLE:
# CHECK:     [[ADDR]]         abc                00000000 foo

.section bar, "a"
