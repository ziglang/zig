# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/ztext.s -o %t2.o
# RUN: ld.lld %t2.o -o %t2.so -shared

# RUN: ld.lld -z notext %t.o %t2.so -o %t -shared
# RUN: llvm-readobj  -dynamic-table -r %t | FileCheck %s
# RUN: ld.lld -z notext %t.o %t2.so -o %t2 -pie
# RUN: llvm-readobj  -dynamic-table -r %t2 | FileCheck %s
# RUN: ld.lld -z notext %t.o %t2.so -o %t3
# RUN: llvm-readobj  -dynamic-table -r %t3 | FileCheck --check-prefix=STATIC %s

# RUN: not ld.lld %t.o %t2.so -o %t -shared 2>&1 | FileCheck --check-prefix=ERR %s
# RUN: not ld.lld -z text %t.o %t2.so -o %t -shared 2>&1 | FileCheck --check-prefix=ERR %s
# ERR: error: can't create dynamic relocation

# If the preference is to have text relocations, don't create plt of copy relocations.

# CHECK:      Relocations [
# CHECK-NEXT:   Section {{.*}} .rela.dyn {
# CHECK-NEXT:     0x1000 R_X86_64_RELATIVE - 0x1000
# CHECK-NEXT:     0x1008 R_X86_64_64 bar 0x0
# CHECK-NEXT:     0x1010 R_X86_64_PC64 zed 0x0
# CHECK-NEXT:   }
# CHECK-NEXT: ]

# CHECK: DynamicSection [
# CHECK:   FLAGS TEXTREL
# CHECK:   TEXTREL 0x0

# STATIC:      Relocations [
# STATIC-NEXT:   Section {{.*}} .rela.dyn {
# STATIC-NEXT:     0x201008 R_X86_64_64 bar 0x0
# STATIC-NEXT:     0x201010 R_X86_64_PC64 zed 0x0
# STATIC-NEXT:   }
# STATIC-NEXT: ]

# STATIC: DynamicSection [
# STATIC:   FLAGS TEXTREL
# STATIC:   TEXTREL 0x0

foo:
.quad foo
.quad bar
.quad zed - .
