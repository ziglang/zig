# REQUIRES: x86, shell

# Test that we don't erroneously replace \ with / on UNIX, as it's
# legal for a filename to contain backslashes.
# RUN: llvm-mc %s -o %T/foo\\.o -filetype=obj -triple=x86_64-pc-linux
# RUN: ld.lld %T/foo\\.o --reproduce %T/repro.tar -o /dev/null
# RUN: tar tf %T/repro.tar | FileCheck %s

# CHECK: repro/{{.*}}/foo\\.o
