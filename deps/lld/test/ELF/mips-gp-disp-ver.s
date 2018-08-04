# REQUIRES: mips
# MIPS BFD linker puts _gp_disp symbol into DSO files and assigns zero
# version definition index to it. This value means 'unversioned local symbol'
# while _gp_disp is a section global symbol. We have to handle this bug
# in the LLD because BFD linker is used for building MIPS toolchain
# libraries. This test checks such handling.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o %S/Inputs/mips-gp-dips-corrupt-ver.so

  .global __start
  .text
__start:
  lw     $t0, %got(foo)($gp)
