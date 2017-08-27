# REQUIRES: x86

# Test that we don't error on undefined versions when static linking.
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: echo "DEFINED { global: *; };" > %t.map
# RUN: ld.lld %t.o --version-script %t.map -o %t

.global _start
.global bar
.symver _start, bar@@UNDEFINED
_start:
