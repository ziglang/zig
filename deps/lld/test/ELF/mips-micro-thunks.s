# REQUIRES: mips
# Check microMIPS thunk generation.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mcpu=mips32r2 -mattr=micromips %s -o %t-eb.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -position-independent -mcpu=mips32r2 -mattr=micromips \
# RUN:         %S/Inputs/mips-micro.s -o %t-eb-pic.o
# RUN: ld.lld -o %t-eb.exe %t-eb.o %t-eb-pic.o
# RUN: llvm-objdump -d -mattr=+micromips %t-eb.exe \
# RUN:   | FileCheck --check-prefix=EB-R2 %s

# RUN: llvm-mc -filetype=obj -triple=mipsel-unknown-linux \
# RUN:         -mcpu=mips32r2 -mattr=micromips %s -o %t-el.o
# RUN: llvm-mc -filetype=obj -triple=mipsel-unknown-linux \
# RUN:         -position-independent -mcpu=mips32r2 -mattr=micromips \
# RUN:         %S/Inputs/mips-micro.s -o %t-el-pic.o
# RUN: ld.lld -o %t-el.exe %t-el.o %t-el-pic.o
# RUN: llvm-objdump -d -mattr=+micromips %t-el.exe \
# RUN:   | FileCheck --check-prefix=EL-R2 %s

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mcpu=mips32r6 -mattr=micromips %s -o %t-eb-r6.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -position-independent -mcpu=mips32r6 -mattr=micromips \
# RUN:         %S/Inputs/mips-micro.s -o %t-eb-pic-r6.o
# RUN: ld.lld -o %t-eb-r6.exe %t-eb-r6.o %t-eb-pic-r6.o
# RUN: llvm-objdump -d -mattr=+micromips %t-eb-r6.exe \
# RUN:   | FileCheck --check-prefix=EB-R6 %s

# RUN: llvm-mc -filetype=obj -triple=mipsel-unknown-linux \
# RUN:         -mcpu=mips32r6 -mattr=micromips %s -o %t-el-r6.o
# RUN: llvm-mc -filetype=obj -triple=mipsel-unknown-linux \
# RUN:         -position-independent -mcpu=mips32r6 -mattr=micromips \
# RUN:         %S/Inputs/mips-micro.s -o %t-el-pic-r6.o
# RUN: ld.lld -o %t-el-r6.exe %t-el-r6.o %t-el-pic-r6.o
# RUN: llvm-objdump -d -mattr=+micromips %t-el-r6.exe \
# RUN:   | FileCheck --check-prefix=EL-R6 %s

# EB-R2: __start:
# EB-R2-NEXT:    20000:       f4 01 00 04  jal   131080 <__microLA25Thunk_foo>
# EB-R2-NEXT:    20004:       00 00 00 00  nop

# EB-R2: __microLA25Thunk_foo:
# EB-R2-NEXT:    20008:       41 b9 00 02  lui   $25, 2
# EB-R2-NEXT:    2000c:       d4 01 00 10  j     131104
# EB-R2-NEXT:    20010:       33 39 00 21  addiu $25, $25, 33
# EB-R2-NEXT:    20014:       0c 00        nop

# EL-R2: __start:
# EL-R2-NEXT:    20000:       01 f4 04 00  jal   131080 <__microLA25Thunk_foo>
# EL-R2-NEXT:    20004:       00 00 00 00  nop

# EL-R2: __microLA25Thunk_foo:
# EL-R2-NEXT:    20008:       b9 41 02 00  lui   $25, 2
# EL-R2-NEXT:    2000c:       01 d4 10 00  j     131104
# EL-R2-NEXT:    20010:       39 33 21 00  addiu $25, $25, 33
# EL-R2-NEXT:    20014:       00 0c        nop

# EB-R6: __start:
# EB-R6-NEXT:    20000:       b4 00 00 00  balc  0 <__start>

# EB-R6: __microLA25Thunk_foo:
# EB-R6-NEXT:    20004:       13 20 00 02  lui   $25, 2
# EB-R6-NEXT:    20008:       33 39 00 11  addiu $25, $25, 17
# EB-R6-NEXT:    2000c:       94 00 00 00  bc    0 <__microLA25Thunk_foo+0x8>

# EL-R6: __start:
# EL-R6-NEXT:    20000:       00 b4 00 00  balc  0 <__start>

# EL-R6: __microLA25Thunk_foo:
# EL-R6-NEXT:    20004:       20 13 02 00  lui   $25, 2
# EL-R6-NEXT:    20008:       39 33 11 00  addiu $25, $25, 17
# EL-R6-NEXT:    2000c:       00 94 00 00  bc    0 <__microLA25Thunk_foo+0x8>

  .text
  .set micromips
  .global __start
__start:
  jal foo
