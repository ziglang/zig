# REQUIRES: amdgpu
# RUN: llvm-mc -filetype=obj -triple=amdgcn--amdhsa -mcpu=fiji %s -o %t.o
# RUN: ld.lld --hash-style=sysv -shared %t.o -o %t.so
# RUN: llvm-readobj -r %t.so | FileCheck %s
# RUN: llvm-nm %t.so | FileCheck %s --check-prefix=NM
# RUN: llvm-readelf -x .rodata -x nonalloc %t.so | FileCheck %s --check-prefix=HEX

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
  local_var0:
  local_var1:
  local_var2:

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
  temp2:

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
# CHECK-NEXT: R_AMDGPU_RELATIVE64 - 0x3008
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

# NM: 0000000000003010 B common_var0
# NM: 0000000000003410 B common_var1
# NM: 0000000000003810 B common_var2
# NM: 0000000000003008 d temp2

# temp2 - foo = 0x3008-0x768 = 0x28a0
# HEX:      section '.rodata':
# HEX-NEXT: 0x00000768 a0280000 00000000

# common_var2+4, common_var1+8, and common_var0+12.
# HEX:      section 'nonalloc':
# HEX-NEXT: 0x00000000 00000000 14380000 00000000 18340000
# HEX-NEXT: 0x00000010 00000000 1c300000
