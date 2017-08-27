# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t.out
# RUN: llvm-objdump -s %t.out| FileCheck %s --check-prefix=BEFORE

# BEFORE:      Contents of section .foo:
# BEFORE-NEXT:  201000 11223344 5566

# RUN: echo "_foo4  " > %t_order.txt
# RUN: echo "  _foo3" >> %t_order.txt
# RUN: echo "_foo5" >> %t_order.txt
# RUN: echo "_foo2" >> %t_order.txt
# RUN: echo " " >> %t_order.txt
# RUN: echo "_foo4" >> %t_order.txt
# RUN: echo "_bar1" >> %t_order.txt
# RUN: echo "_foo1" >> %t_order.txt

# RUN: ld.lld --symbol-ordering-file %t_order.txt %t.o -o %t2.out
# RUN: llvm-objdump -s %t2.out| FileCheck %s --check-prefix=AFTER

# AFTER:      Contents of section .foo:
# AFTER-NEXT:  201000 44335566 2211

.section .foo,"ax",@progbits,unique,1
_foo1:
 .byte 0x11

.section .foo,"ax",@progbits,unique,2
_foo2:
 .byte 0x22

.section .foo,"ax",@progbits,unique,3
_foo3:
 .byte 0x33

.section .foo,"ax",@progbits,unique,4
_foo4:
 .byte 0x44

.section .foo,"ax",@progbits,unique,5
_foo5:
 .byte 0x55
_bar1:
 .byte 0x66
