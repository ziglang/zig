# REQUIRES: x86

# Test that we can parse multiple externs.

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

# RUN: echo '{ \
# RUN:         extern "C" { \
# RUN:           foo; \
# RUN:         }; \
# RUN:         extern "C++" { \
# RUN:           bar; \
# RUN:         }; \
# RUN:       };' > %t.list
# RUN: ld.lld --dynamic-list %t.list %t.o -shared -o %t.so
