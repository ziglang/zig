# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/version-script-weak.s -o %tmp.o
# RUN: rm -f %t.a
# RUN: llvm-ar rcs %t.a %tmp.o
# RUN: echo "{ local: *; };" > %t.script
# RUN: ld.lld -shared --version-script %t.script %t.o %t.a -o %t.so
# RUN: llvm-readobj -dyn-symbols -r %t.so | FileCheck %s

# CHECK:      Relocations [
# CHECK-NEXT:   Section ({{.*}}) .rela.plt {
# CHECK-NEXT:     0x2018 R_X86_64_JUMP_SLOT foo
# CHECK-NEXT:   }
# CHECK-NEXT: ]
# CHECK:      Symbol {
# CHECK:        Name: foo
# CHECK-NEXT:   Value: 0x0
# CHECK-NEXT:   Size: 0
# CHECK-NEXT:   Binding: Weak
# CHECK-NEXT:   Type: None
# CHECK-NEXT:   Other: 0
# CHECK-NEXT:   Section: Undefined
# CHECK-NEXT: }

.text
 callq foo@PLT
.weak foo
