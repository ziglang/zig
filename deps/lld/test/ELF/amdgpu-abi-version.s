# REQUIRES: amdgpu
# RUN: llvm-mc -triple amdgcn-amd-amdhsa -mcpu=gfx900 -filetype=obj %s -o %t.o
# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-readobj --file-headers %t.so | FileCheck %s

# CHECK: OS/ABI: AMDGPU_HSA (0x40)
# CHECK: ABIVersion: 1

.text
  s_nop 0x0
  s_endpgm
