# REQUIRES: x86, shell

# Test that we don't erroneously replace \ with / on UNIX, as it's
# legal for a filename to contain backslashes.
# RUN: llvm-mc %s -o foo\\.o -filetype=obj -triple=x86_64-pc-linux
# RUN: ld.lld foo\\.o --reproduce repro.tar
# RUN: tar tf repro.tar | FileCheck %s

# CHECK: repro/{{.*}}/foo\\.o
