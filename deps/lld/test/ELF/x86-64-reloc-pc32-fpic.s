# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: not ld.lld -shared %t.o -o %t.so 2>&1 | FileCheck %s

# CHECK: relocation R_X86_64_PC32 cannot be used against shared object; recompile with -fPIC
# CHECK: >>> defined in {{.*}}
# CHECK: >>> referenced by {{.*}}:(.data+0x1)

.data
call _shared
