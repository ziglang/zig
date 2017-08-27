# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo  > %t.retain
# RUN: echo "{ local: *; }; " > %t.script
# RUN: ld.lld -shared --version-script %t.script %t.o -o %t1.so
# RUN: ld.lld -shared --retain-symbols-file %t.retain %t.o -o %t2.so
# RUN: llvm-readobj -r %t1.so | FileCheck %s
# RUN: llvm-readobj -r %t2.so | FileCheck %s

# CHECK:      Relocations [
# CHECK-NEXT:   Section ({{.*}}) .rela.dyn {
# CHECK-NEXT:     0x{{.*}} R_X86_64_64 foo 0x0
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.data
.quad foo
.weak foo
