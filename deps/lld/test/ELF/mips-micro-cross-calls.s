# REQUIRES: mips
# Check various cases of microMIPS - regular code cross-calls.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mattr=micromips %s -o %t-eb.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -position-independent -mattr=micromips \
# RUN:         %S/Inputs/mips-micro.s -o %t-eb-pic.o
# RUN: ld.lld -o %t-eb.exe %t-eb.o %t-eb-pic.o
# RUN: llvm-objdump -d -mattr=-micromips %t-eb.exe \
# RUN:   | FileCheck --check-prefix=REG %s
# RUN: llvm-objdump -d -mattr=+micromips %t-eb.exe \
# RUN:   | FileCheck --check-prefix=MICRO %s

# REG:        __start:
# REG-NEXT:      20000:       74 00 80 04     jalx 131088 <micro>
# REG-NEXT:      20004:       00 00 00 00     nop
# REG-NEXT:      20008:       74 00 80 08     jalx 131104 <__microLA25Thunk_foo>

# REG:        __LA25Thunk_bar:
# REG-NEXT:      20030:       3c 19 00 02     lui     $25, 2
# REG-NEXT:      20034:       08 00 80 11     j       131140 <bar>

# MICRO:      micro:
# MICRO-NEXT:    20010:       f0 00 80 00     jalx 65536
# MICRO-NEXT:    20014:       00 00 00 00     nop
# MICRO-NEXT:    20018:       f0 00 80 0c     jalx 65560

# MICRO:      __microLA25Thunk_foo:
# MICRO-NEXT:    20020:       41 b9 00 02     lui     $25, 2
# MICRO-NEXT:    20024:       d4 01 00 20     j       131136

  .text
  .set nomicromips
  .global __start
__start:
  jal micro
  jal foo

  .set micromips
  .global micro
micro:
  jal __start
  jal bar
