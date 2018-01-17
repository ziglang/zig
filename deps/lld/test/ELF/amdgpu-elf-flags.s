# RUN: llvm-mc -triple amdgcn-amd-amdhsa -mcpu=gfx803 -filetype=obj %S/Inputs/amdgpu-kernel-0.s -o %t-0.o
# RUN: llvm-mc -triple amdgcn-amd-amdhsa -mcpu=gfx803 -filetype=obj %S/Inputs/amdgpu-kernel-1.s -o %t-1.o
# RUN: ld.lld -shared %t-0.o %t-1.o -o %t.so
# RUN: llvm-readobj -file-headers %t.so | FileCheck %s

# REQUIRES: amdgpu

# CHECK: Flags [ (0x2)
# CHECK:   EF_AMDGPU_ARCH_GCN (0x2)
# CHECK: ]
