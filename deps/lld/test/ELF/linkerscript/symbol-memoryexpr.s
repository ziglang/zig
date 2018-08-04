# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: echo "MEMORY { \
# RUN:   ram (rwx)  : ORIGIN = 0x8000, LENGTH = 256K \
# RUN: } \
# RUN: SECTIONS { \
# RUN:         origin = ORIGIN(ram); \
# RUN:         length = LENGTH(ram); \
# RUN:         end    = ORIGIN(ram) + LENGTH(ram); \
# RUN:       }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck %s

# CHECK:      SYMBOL TABLE:
# CHECK-NEXT: 0000000000000000 *UND* 00000000
# CHECK-NEXT: 0000000000008000 .text 00000000 _start
# CHECK-NEXT: 0000000000008000 *ABS* 00000000 origin
# CHECK-NEXT: 0000000000040000 *ABS* 00000000 length
# CHECK-NEXT: 0000000000048000 *ABS* 00000000 end

# RUN: echo "SECTIONS { \
# RUN:         no_exist_origin = ORIGIN(ram); \
# RUN:         no_exist_length = LENGTH(ram); \
# RUN:       }" > %t2.script
# RUN: not ld.lld -o /dev/null --script %t2.script %t 2>&1 \
# RUN:  | FileCheck -check-prefix=ERR %s
# ERR: {{.*}}.script:1: memory region not defined: ram


.global _start
_start:
 nop
