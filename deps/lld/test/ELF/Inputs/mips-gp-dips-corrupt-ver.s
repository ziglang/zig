# Source file for mips-gp-dips-corrupt-ver.so
#
# % cat gpdisp.ver
# LLD_1.0.0 { global: foo; };
#
# % as mips-gp-dips-corrupt-ver.s -o mips-gp-dips-corrupt-ver.o
# % ld -shared -o mips-gp-dips-corrupt-ver.so \
#      --version-script gpdisp.ver mips-gp-dips-corrupt-ver.o

  .global foo
  .text
foo:
  lui    $t0, %hi(_gp_disp)
  addi   $t0, $t0, %lo(_gp_disp)
