# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: not ld.lld %t.o -shared -o /dev/null 2>&1 | FileCheck %s

# CHECK: relocation R_X86_64_TPOFF32 cannot be used against symbol var; recompile with -fPIC
# CHECK: >>> defined in {{.*}}.o
# CHECK: >>> referenced by {{.*}}.o:(.tdata+0xC)

.section ".tdata", "awT", @progbits
.globl var
var:

movq %fs:0, %rax
leaq var@TPOFF(%rax),%rax
