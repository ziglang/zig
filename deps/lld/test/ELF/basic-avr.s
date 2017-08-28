# REQUIRES: avr
# RUN: llvm-mc -filetype=obj -triple=avr-unknown-linux -mcpu=atmega328p %s -o %t.o
# RUN: ld.lld %t.o -o %t.exe -Ttext=0
# RUN: llvm-objdump -d %t.exe | FileCheck %s

main:
  call foo
foo:
  jmp foo

# CHECK:      main:
# CHECK-NEXT:   0: 0e 94 02 00 <unknown>
# CHECK:      foo:
# CHECK-NEXT:   4: 0c 94 02 00 <unknown>
