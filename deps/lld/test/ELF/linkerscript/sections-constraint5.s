# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { \
# RUN:         bar : ONLY_IF_RO { sym1 = .; *(foo*) } \
# RUN:         bar : ONLY_IF_RW { sym2 = .; *(foo*) } \
# RUN:       }" > %t.script

# RUN: ld.lld -o %t -T %t.script %t.o
# RUN: llvm-readobj -s -t %t | FileCheck %s

# CHECK: Sections [
# CHECK:      Name: bar
# CHECK-NEXT: Type: SHT_PROGBITS
# CHECK-NEXT: Flags [
# CHECK-NEXT:   SHF_ALLOC
# CHECK-NEXT:   SHF_WRITE
# CHECK-NEXT: ]
# CHECK-NEXT: Address:
# CHECK-NEXT: Offset:
# CHECK-NEXT: Size: 2

# CHECK: Symbols [
# CHECK-NOT: sym1
# CHECK:     sym2
# CHECK-NOT: sym1

.section foo1,"a"
.byte 0

.section foo2,"aw"
.byte 0

