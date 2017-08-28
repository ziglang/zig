# REQUIRES: x86

## too-short.elf file is a truncated ELF.
# RUN: not ld.lld %S/Inputs/too-short.elf -o %t 2>&1 | FileCheck %s
# CHECK: file is too short
