# REQUIRES: amdgpu
# RUN: llvm-mc -filetype=obj -triple amdgcn--amdhsa -mcpu=kaveri -mattr=-code-object-v3 %s -o %t.o
# RUN: ld.lld -shared %t.o -o %t
# RUN: llvm-readobj --sections --symbols -l %t | FileCheck %s

.hsa_code_object_version 1,0
.hsa_code_object_isa 7,0,0,"AMD","AMDGPU"

.text
.globl kernel0
.align 256
.amdgpu_hsa_kernel kernel0
kernel0:
  s_endpgm
.Lfunc_end0:
  .size kernel0, .Lfunc_end0-kernel0

.globl kernel1
.align 256
.amdgpu_hsa_kernel kernel1
kernel1:
  s_endpgm
  s_endpgm
.Lfunc_end1:
  .size kernel1, .Lfunc_end1-kernel1


# CHECK: Section {
# CHECK: Name: .text
# CHECK: Type: SHT_PROGBITS
# CHECK: Flags [ (0x6)
# CHECK: SHF_ALLOC (0x2)
# CHECK: SHF_EXECINSTR (0x4)
# CHECK: ]
# CHECK: }

# CHECK: Symbol {
# CHECK: Name: kernel0
# CHECK: Value:
# CHECK: Size: 4
# CHECK: Binding: Global
# CHECK: Type: AMDGPU_HSA_KERNEL
# CHECK: Section: .text
# CHECK: }

# CHECK: Symbol {
# CHECK: Name: kernel1
# CHECK: Value:
# CHECK: Size: 8
# CHECK: Binding: Global
# CHECK: Type: AMDGPU_HSA_KERNEL
# CHECK: Section: .text
# CHECK: }

# CHECK: ProgramHeader {
# CHECK: Type: PT_LOAD
# CHECK: VirtualAddress:
# CHECK: }
