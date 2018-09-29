# REQUIRES: x86
# Check that we fall back to search paths if a version script was not found
# This behaviour matches ld.bfd.

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: mkdir -p %T/searchpath
# RUN: echo '{};' > %T/searchpath/%basename_t.script
# RUN: ld.lld -L%T/searchpath --version-script=%basename_t.script %t.o -o /dev/null
# RUN: not ld.lld --version-script=%basename_t.script %t.o 2>&1 | FileCheck -check-prefix ERROR %s
# ERROR: error: cannot find version script
