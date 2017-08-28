# REQUIRES: system-windows, x86

# Test that a response.txt file always uses / instead of \.
# RUN: rm -rf %t.dir
# RUN: mkdir -p %t.dir/build
# RUN: llvm-mc %s -o %t.dir/build/foo.o -filetype=obj -triple=x86_64-pc-linux
# RUN: cd %t.dir
# RUN: ld.lld build/foo.o --reproduce repro.tar
# RUN: tar -O -x -f repro.tar repro/response.txt | FileCheck %s
# CHECK: {{.*}}/build/foo.o
