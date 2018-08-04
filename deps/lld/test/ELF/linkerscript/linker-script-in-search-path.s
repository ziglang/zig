# REQUIRES: x86
# Check that we fall back to search paths if a linker script was not found
# This behaviour matches ld.bfd and various projects appear to rely on this

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: mkdir -p %T/searchpath
# RUN: echo 'OUTPUT("%t.out")' > %T/searchpath/%basename_t.script
# RUN: ld.lld -T%T/searchpath/%basename_t.script %t.o
# RUN: llvm-readobj %t.out | FileCheck %s
# CHECK: Format: ELF64-x86-64

# If the linker script specified with -T is missing we should emit an error
# RUN: not ld.lld -T%basename_t.script %t.o 2>&1 | FileCheck %s -check-prefix ERROR
# ERROR: error: cannot find linker script {{.*}}.script

# But if it exists in the search path we should fall back to that instead:
# RUN: rm %t.out
# RUN: ld.lld -L %T/searchpath -T%basename_t.script %t.o
# RUN: llvm-readobj %t.out | FileCheck %s
