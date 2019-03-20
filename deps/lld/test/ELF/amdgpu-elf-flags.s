# REQUIRES: amdgpu
# RUN: llvm-mc -triple amdgcn-amd-amdhsa -mcpu=gfx803 -mattr=-code-object-v3 -filetype=obj %S/Inputs/amdgpu-kernel-0.s -o %t-0.o
# RUN: llvm-mc -triple amdgcn-amd-amdhsa -mcpu=gfx803 -mattr=-code-object-v3 -filetype=obj %S/Inputs/amdgpu-kernel-1.s -o %t-1.o
# RUN: ld.lld -shared %t-0.o %t-1.o -o %t.so
# RUN: llvm-readobj -file-headers %t.so | FileCheck %s

# CHECK: Flags [
# CHECK:   EF_AMDGPU_MACH_AMDGCN_GFX803 (0x2A)
# CHECK: ]
