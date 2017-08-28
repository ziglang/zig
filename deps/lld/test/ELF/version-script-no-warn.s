# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/shared.s -o %t2.o
# RUN: ld.lld -shared %t2.o -soname shared -o %t2.so

# RUN: echo "foo { global: bar;  local: *; };" > %t.script
# RUN: ld.lld --fatal-warnings --shared --version-script %t.script %t.o %t2.so

.global bar
bar:
        nop
