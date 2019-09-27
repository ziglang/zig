# REQUIRES: amdgpu
# RUN: llvm-mc -filetype=obj -triple amdgcn--amdhsa -mcpu=kaveri %s -o %t.o
# RUN: ld.lld -shared %t.o -o %t
# RUN: llvm-readobj --sections --symbols -l %t | FileCheck %s

.type glob0, @object
.data
  .globl glob0
glob0:
  .long 1
  .size glob0, 4

.type glob1, @object
.section .rodata, #alloc
  .globl glob1
glob1:
  .long 2
  .size glob1, 4

# CHECK: Section {
# CHECK:   Name: .rodata
# CHECK:   Type: SHT_PROGBITS
# CHECK:   Flags [ (0x2)
# CHECK:     SHF_ALLOC (0x2)
# CHECK:   ]
# CHECK:   Address: [[RODATA_ADDR:[0-9xa-f]+]]
# CHECK: }

# CHECK: Section {
# CHECK:   Name: .data
# CHECK:   Type: SHT_PROGBITS
# CHECK:   Flags [ (0x3)
# CHECK:     SHF_ALLOC (0x2)
# CHECK:     SHF_WRITE (0x1)
# CHECK:   ]
# CHECK:   Address: [[DATA_ADDR:[0-9xa-f]+]]
# CHECK: }

# CHECK: Symbol {
# CHECK:   Name: glob0
# CHECK:   Value: [[DATA_ADDR]]
# CHECK:   Size: 4
# CHECK:   Type: Object
# CHECK:   Section: .data
# CHECK: }

# CHECK: Symbol {
# CHECK:   Name: glob1
# CHECK:   Value: [[RODATA_ADDR]]
# CHECK:   Size: 4
# CHECK:   Type: Object
# CHECK:   Section: .rodata
# CHECK: }

# CHECK: ProgramHeader {
# CHECK: Type: PT_LOAD
# CHECK: VirtualAddress:
# CHECK: }

# CHECK: ProgramHeader {
# CHECK: Type: PT_LOAD
# CHECK: VirtualAddress:
# CHECK: }
