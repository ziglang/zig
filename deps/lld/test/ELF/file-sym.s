# Check that we do not keep STT_FILE symbols in the symbol table

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -shared -o %t.so
# RUN: llvm-readobj -symbols %t.so | FileCheck %s

# REQUIRES: x86

# CHECK-NOT: xxx

.file "xxx"
.file ""
