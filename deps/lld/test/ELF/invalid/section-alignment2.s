## section-alignment-notpow2.elf has section alignment
## 0xFFFFFFFF which is not a power of 2.
# RUN: not ld.lld %p/Inputs/section-alignment-notpow2.elf -o %t2 2>&1 | \
# RUN:   FileCheck %s
# CHECK: section sh_addralign is not a power of 2
