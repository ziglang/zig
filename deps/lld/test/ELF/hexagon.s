# REQUIRES: hexagon
# RUN: llvm-mc -filetype=obj -triple=hexagon-unknown-elf %s -o %t
# RUN: llvm-mc -filetype=obj -triple=hexagon-unknown-elf %S/Inputs/hexagon.s -o %t2
# RUN: ld.lld %t2 %t  -o %t3
# RUN: llvm-objdump -d  %t3 | FileCheck %s

# Note: 69632 == 0x11000
# R_HEX_32_6_X
# R_HEX_12_X
if (p0) r0 = ##_start
# CHECK: immext(#69632)
# CHECK: if (p0) r0 = ##69632

# R_HEX_B15_PCREL
if (p0) jump:nt #_start
# CHECK: if (p0) jump:nt 0x11000

# R_HEX_B32_PCREL_X
# R_HEX_B15_PCREL_X
if (p0) jump:nt ##_start
# CHECK: if (p0) jump:nt 0x11000

# R_HEX_B22_PCREL
call #_start
# CHECK: call 0x11000

# R_HEX_B32_PCREL_X
# R_HEX_B22_PCREL_X
call ##_start
# CHECK: immext(#4294967232)
# CHECK: call 0x11000
