# Check microMIPS thunk generation.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mattr=micromips %s -o %t-eb.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -position-independent -mattr=micromips \
# RUN:         %S/Inputs/mips-micro.s -o %t-eb-pic.o
# RUN: ld.lld -o %t-eb.exe %t-eb.o %t-eb-pic.o
# RUN: llvm-objdump -d -mattr=+micromips %t-eb.exe \
# RUN:   | FileCheck --check-prefix=EB %s

# RUN: llvm-mc -filetype=obj -triple=mipsel-unknown-linux \
# RUN:         -mattr=micromips %s -o %t-el.o
# RUN: llvm-mc -filetype=obj -triple=mipsel-unknown-linux \
# RUN:         -position-independent -mattr=micromips \
# RUN:         %S/Inputs/mips-micro.s -o %t-el-pic.o
# RUN: ld.lld -o %t-el.exe %t-el.o %t-el-pic.o
# RUN: llvm-objdump -d -mattr=+micromips %t-el.exe \
# RUN:   | FileCheck --check-prefix=EL %s

# REQUIRES: mips

# EB: __start:
# EB-NEXT:    20000:       f4 01 00 04     jal     131080 <__microLA25Thunk_foo>
# EB-NEXT:    20004:       00 00 00 00     nop

# EB: __microLA25Thunk_foo:
# EB-NEXT:    20008:       41 b9 00 02     lui     $25, 2
# EB-NEXT:    2000c:       d4 01 00 10     j       131104
# EB-NEXT:    20010:       33 39 00 21     addiu   $25, $25, 33
# EB-NEXT:    20014:       0c 00           nop

# EL: __start:
# EL-NEXT:    20000:       01 f4 04 00     jal     131080 <__microLA25Thunk_foo>
# EL-NEXT:    20004:       00 00 00 00     nop

# EL: __microLA25Thunk_foo:
# EL-NEXT:    20008:       b9 41 02 00     lui     $25, 2
# EL-NEXT:    2000c:       01 d4 10 00     j       131104
# EL-NEXT:    20010:       39 33 21 00     addiu   $25, $25, 33
# EL-NEXT:    20014:       00 0c           nop

  .text
  .set micromips
  .global __start
__start:
  jal foo
