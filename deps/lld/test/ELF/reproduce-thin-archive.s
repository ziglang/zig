# REQUIRES: x86, shell

# RUN: rm -rf %t.dir
# RUN: mkdir -p %t.dir
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.dir/foo.o
# RUN: cd %t.dir
# RUN: llvm-ar --format=gnu rcT foo.a foo.o
# RUN: ld.lld -m elf_x86_64 foo.a -o bar --reproduce repro.tar
# RUN: tar xf repro.tar
# RUN: diff foo.a repro/%:t.dir/foo.a
# RUN: diff foo.o repro/%:t.dir/foo.o

.globl _start
_start:
  nop
