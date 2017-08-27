# REQUIRES: x86

## common-symbol-alignment.elf contains common symbol with zero alignment.
# RUN: not ld.lld %S/Inputs/common-symbol-alignment.elf \
# RUN:   -o %t 2>&1 | FileCheck %s
# CHECK: common symbol 'bar' has invalid alignment: 0

## common-symbol-alignment2.elf contains common symbol alignment greater
## than UINT32_MAX.
# RUN: not ld.lld %S/Inputs/common-symbol-alignment2.elf \
# RUN:   -o %t 2>&1 | FileCheck %s --check-prefix=BIG
# BIG: common symbol 'bar' has invalid alignment: 271644049215
