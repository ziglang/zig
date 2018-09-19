# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: not ld.lld %t.o -shared -o /dev/null 2>&1 | FileCheck %s

# CHECK: relocation R_X86_64_8 cannot be used against symbol foo; recompile with -fPIC
# CHECK: relocation R_X86_64_16 cannot be used against symbol foo; recompile with -fPIC
# CHECK: relocation R_X86_64_PC8 cannot be used against symbol foo; recompile with -fPIC
# CHECK: relocation R_X86_64_PC16 cannot be used against symbol foo; recompile with -fPIC

.global foo

.data
.byte foo       # R_X86_64_8
.short foo      # R_X86_64_16
.byte foo - .   # R_X86_64_PC8
.short foo - .  # R_X86_64_PC16
