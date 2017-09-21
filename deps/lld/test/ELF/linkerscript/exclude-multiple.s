# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %tfile1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/exclude-multiple1.s -o %tfile2.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/exclude-multiple2.s -o %tfile3.o
# RUN: echo "SECTIONS { \
# RUN:   .foo : { *(.foo.1 EXCLUDE_FILE (*file1.o) .foo.2 EXCLUDE_FILE (*file2.o) .foo.3) } \
# RUN:  }" > %t1.script
# RUN: ld.lld -script %t1.script %tfile1.o %tfile2.o %tfile3.o -o %t1.o
# RUN: llvm-objdump -s %t1.o | FileCheck %s

# CHECK:      Contents of section .foo:
# CHECK-NEXT:  01000000 00000000 04000000 00000000
# CHECK-NEXT:  07000000 00000000 05000000 00000000
# CHECK-NEXT:  08000000 00000000 03000000 00000000
# CHECK-NEXT:  09000000 00000000
# CHECK-NEXT: Contents of section .foo.2:
# CHECK-NEXT:  02000000 00000000
# CHECK-NEXT: Contents of section .foo.3:
# CHECK-NEXT:  06000000 00000000

# RUN: echo "SECTIONS { .foo : { *(EXCLUDE_FILE (*file1.o) EXCLUDE_FILE (*file2.o) .foo.3) } }" > %t2.script
# RUN: not ld.lld -script %t2.script %tfile1.o %tfile2.o %tfile3.o -o %t2.o 2>&1 | \
# RUN:   FileCheck %s --check-prefix=ERR
# ERR: section pattern is expected

# RUN: echo "SECTIONS { .foo : { *(EXCLUDE_FILE (*file1.o)) } }" > %t3.script
# RUN: not ld.lld -script %t3.script %tfile1.o %tfile2.o %tfile3.o -o %t2.o 2>&1 | \
# RUN:   FileCheck %s --check-prefix=ERR

.section .foo.1,"a"
 .quad 1

.section .foo.2,"a"
 .quad 2

.section .foo.3,"a"
 .quad 3
