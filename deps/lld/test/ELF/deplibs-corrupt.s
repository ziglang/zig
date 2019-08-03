# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: not ld.lld %t.o -o /dev/null -L %t.dir 2>&1 | FileCheck %s -DOBJ=%t.o
# CHECK: error: [[OBJ]]: corrupted dependent libraries section (unterminated string): .deplibs

.section ".deplibs","MS",@llvm_dependent_libraries,1
    .ascii  ":foo.a"
