# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: not ld.lld -shared %t.o -o %t.so 2>&1 | FileCheck %s

# On some targets the location of the _GLOBAL_OFFSET_TABLE_ symbol table can
# matter for the correctness of some relocations. Follow the example of ld.gold
# and give a multiple definition error if input objects attempt to redefine it.

# CHECK: ld.lld: error: {{.*o}} cannot redefine linker defined symbol '_GLOBAL_OFFSET_TABLE_'

.data
.global _GLOBAL_OFFSET_TABLE_
_GLOBAL_OFFSET_TABLE_:
.word 0
