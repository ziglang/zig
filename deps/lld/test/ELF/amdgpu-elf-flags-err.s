# REQUIRES: amdgpu
# RUN: llvm-mc -triple amdgcn-amd-amdhsa -mcpu=gfx802 -mattr=-code-object-v3 -filetype=obj %S/Inputs/amdgpu-kernel-0.s -o %t-0.o
# RUN: llvm-mc -triple amdgcn-amd-amdhsa -mcpu=gfx803 -mattr=-code-object-v3 -filetype=obj %S/Inputs/amdgpu-kernel-1.s -o %t-1.o
# RUN: not ld.lld -shared %t-0.o %t-1.o -o /dev/null 2>&1 | FileCheck %s

# CHECK: error: incompatible e_flags: {{.*}}-1.o
