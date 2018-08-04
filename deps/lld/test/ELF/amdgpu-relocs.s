# REQUIRES: amdgpu
# RUN: llvm-mc -filetype=obj -triple=amdgcn--amdhsa -mcpu=fiji %s -o %t.o
# RUN: ld.lld --hash-style=sysv -shared %t.o -o %t.so
# RUN: llvm-readobj -r %t.so | FileCheck %s
# RUN: llvm-objdump -s %t.so | FileCheck %s --check-prefix=OBJDUMP

.text

kernel0:
  s_mov_b32 s0, common_var0@GOTPCREL+4
  s_mov_b32 s0, common_var1@gotpcrel32@lo+4
  s_mov_b32 s0, common_var2@gotpcrel32@hi+4

  s_mov_b32 s0, global_var0@GOTPCREL+4
  s_mov_b32 s0, global_var1@gotpcrel32@lo+4
  s_mov_b32 s0, global_var2@gotpcrel32@hi+4

  s_mov_b32 s0, extern_var0@GOTPCREL+4
  s_mov_b32 s0, extern_var1@gotpcrel32@lo+4
  s_mov_b32 s0, extern_var2@gotpcrel32@hi+4

  s_mov_b32 s0, weak_var0@GOTPCREL+4
  s_mov_b32 s0, weak_var1@gotpcrel32@lo+4
  s_mov_b32 s0, weak_var2@gotpcrel32@hi+4

  s_mov_b32 s0, weakref_var0@GOTPCREL+4
  s_mov_b32 s0, weakref_var1@gotpcrel32@lo+4
  s_mov_b32 s0, weakref_var2@gotpcrel32@hi+4

  s_mov_b32 s0, local_var0+4
  s_mov_b32 s0, local_var1@rel32@lo+4
  s_mov_b32 s0, local_var2@rel32@hi+4

  s_endpgm

  .comm    common_var0,1024,4
  .comm    common_var1,1024,4
  .comm    common_var2,1024,4
  .globl   global_var0
  .globl   global_var1
  .globl   global_var1
  .weak    weak_var0
  .weak    weak_var1
  .weak    weak_var2
  .weakref weakref_var0, weakref_alias_var0
  .weakref weakref_var1, weakref_alias_var1
  .weakref weakref_var2, weakref_alias_var2
  .local   local_var0
  .local   local_var1
  .local   local_var2

# R_AMDGPU_ABS32:
.section nonalloc, "w", @progbits
  .long var0, common_var2+4
  .long var1, common_var1+8
  .long var2, common_var0+12

# R_AMDGPU_ABS64:
.type ptr, @object
.data
  .globl ptr
  .p2align 3
ptr:
  .quad temp
  .size ptr, 8

# R_AMDGPU_RELATIVE64:
  .type temp2, @object
  .local temp2
  .size temp2, 4

  .type ptr2, @object
  .globl ptr2
  .size ptr2, 8
  .p2align 3
ptr2:
  .quad temp2

# R_AMDGPU_REL64:
.type foo, @object
.rodata
  .globl foo
  .p2align 3
foo:
  .quad temp2@rel64
  .size foo, 8

# The relocation for local_var{0, 1, 2} and var should be resolved by the
# linker.
# CHECK: Relocations [
# CHECK: .rela.dyn {
# CHECK-NEXT: R_AMDGPU_RELATIVE64 - 0x0
# CHECK-NEXT: R_AMDGPU_ABS64 common_var0 0x0
# CHECK-NEXT: R_AMDGPU_ABS64 common_var1 0x0
# CHECK-NEXT: R_AMDGPU_ABS64 common_var2 0x0
# CHECK-NEXT: R_AMDGPU_ABS64 extern_var0 0x0
# CHECK-NEXT: R_AMDGPU_ABS64 extern_var1 0x0
# CHECK-NEXT: R_AMDGPU_ABS64 extern_var2 0x0
# CHECK-NEXT: R_AMDGPU_ABS64 global_var0 0x0
# CHECK-NEXT: R_AMDGPU_ABS64 global_var1 0x0
# CHECK-NEXT: R_AMDGPU_ABS64 global_var2 0x0
# CHECK-NEXT: R_AMDGPU_ABS64 temp 0x0
# CHECK-NEXT: R_AMDGPU_ABS64 weak_var0 0x0
# CHECK-NEXT: R_AMDGPU_ABS64 weak_var1 0x0
# CHECK-NEXT: R_AMDGPU_ABS64 weak_var2 0x0
# CHECK-NEXT: R_AMDGPU_ABS64 weakref_alias_var0 0x0
# CHECK-NEXT: R_AMDGPU_ABS64 weakref_alias_var1 0x0
# CHECK-NEXT: R_AMDGPU_ABS64 weakref_alias_var2 0x0
# CHECK-NEXT: }
# CHECK-NEXT: ]

# OBJDUMP: Contents of section .rodata:
# OBJDUMP: d0f8ffff ffffffff

# OBJDUMP: Contents of section nonalloc:
# OBJDUMP-NEXT: 0000 00000000 04480000 00000000 08440000
# OBJDUMP-NEXT: 00000000 0c400000
