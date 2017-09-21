## Spec says that "If a file has no section header table, e_shnum holds the value zero.", though
## in this test case it holds non-zero and lld used to crash.
# RUN: ld.lld %p/Inputs/invalid-e_shnum.elf -o %t2
