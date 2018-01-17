# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: not ld.lld -z notext -shared %t.o -o %t 2>&1 | FileCheck %s
# CHECK: relocation R_X86_64_32 cannot be used against shared object; recompile with -fPIC

# RUN: ld.lld -z notext %t.o -o %t
# RUN: llvm-readobj -r %t | FileCheck %s --check-prefix=EXE
# EXE:      Relocations [
# EXE-NEXT: ]

.text
.global foo
.weak foo

_start:
mov $foo,%eax
