# REQUIRES: x86

## symbol-name-offset.elf contains symbol with invalid (too large)
## st_name value.
# RUN: not ld.lld %S/Inputs/symbol-name-offset.elf \
# RUN:   -o /dev/null 2>&1 | FileCheck %s
# CHECK: invalid symbol name offset
