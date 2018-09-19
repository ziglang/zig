# REQUIRES: x86

# Test that we can parse multiple externs.

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

# RUN: echo '{ extern "C" { foo; }; extern "C++" { bar; }; };' > %t.list
# RUN: ld.lld --dynamic-list %t.list %t.o -shared -o %t.so

# RUN: echo '{ extern "C" { foo }; extern "C++" { bar }; };' > %t.list
# RUN: ld.lld --dynamic-list %t.list %t.o -shared -o %t.so
